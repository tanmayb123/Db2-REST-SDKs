use std::collections::HashMap;
use std::error::Error;
use std::marker::PhantomData;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde::de::DeserializeOwned;
use tokio::time::{sleep, Duration};

#[derive(Serialize, Deserialize)]
struct Auth {
    token: String,
}

#[derive(Clone, Serialize, Default, Deserialize)]
pub struct AuthSettings {
    rest_https: bool,
    hostname: String,
    rest_port: u16,
    database: String,
    db_port: u16,
    ssl_db2: bool,
    password: String,
    username: String,
    expiry_time: String,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DbParms {
    db_host: String,
    db_name: String,
    db_port: u16,
    is_ssl_connection: bool,
    password: String,
    username: String,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AuthBody {
    db_parms: DbParms,
    expiry_time: String,
}

#[derive(Serialize)]
struct QueryParams<T: Serialize> {
    parameters: T,
    sync: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SQLParams<T: Serialize> {
    sql_statement: String,
    parameters: T,
    is_query: bool,
    sync: bool,
}

#[derive(PartialEq)]
enum Status {
    Failed,
    New,
    Running,
    DataAvailable,
    Completed,
    Stopping,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RawResponse<T> {
    job_status: usize,
    result_set: Option<Vec<T>>,
}

pub struct Response<T> {
    status: Status,
    results: Option<Vec<T>>,
}

#[derive(Deserialize)]
struct JobResponse {
    id: String,
}

pub struct Job<T: DeserializeOwned> {
    next_page_url: String,
    stop_url: String,
    auth_token: String,
    phantom: PhantomData<T>
}

pub struct Db2REST {
    auth_settings: AuthSettings,
    auth_token: String,
}

#[derive(Serialize)]
pub struct NoParameters {}

async fn get_db2_auth_token(auth_settings: AuthSettings) -> Result<String, Box<dyn Error>> {
    let auth_url = format!(
        "{}://{}:{}/v1/auth",
        if auth_settings.rest_https { "https" } else { "http" },
        auth_settings.hostname, auth_settings.rest_port
    );

    let body = AuthBody {
        db_parms: DbParms {
            db_host: auth_settings.hostname,
            db_name: auth_settings.database,
            db_port: auth_settings.db_port,
            is_ssl_connection: auth_settings.ssl_db2,
            password: auth_settings.password,
            username: auth_settings.username,
        },
        expiry_time: auth_settings.expiry_time,
    };

    let client = Client::new();
    let response = client
        .post(&auth_url)
        .json(&body)
        .send()
        .await?;

    if response.status().as_u16() == 200 {
        let token = response.json::<Auth>().await?.token;
        Ok(token)
    } else {
        Err(response.text().await?)?;
        unreachable!();
    }
}

impl Status {
    fn from(n: usize) -> Self {
        match n {
            0 => Self::Failed,
            1 => Self::New,
            2 => Self::Running,
            3 => Self::DataAvailable,
            4 => Self::Completed,
            5 => Self::Stopping,
            _ => unreachable!()
        }
    }
}

impl<T> Response<T> {
    fn from(raw: RawResponse<T>) -> Self {
        Self {
            status: Status::from(raw.job_status),
            results: raw.result_set
        }
    }
}

impl<T: DeserializeOwned> Job<T> {
    fn new(job_id: String, auth_settings: &AuthSettings, auth_token: String) -> Self {
        let next_page_url = format!(
            "{}://{}:{}/v1/services/{}",
            if auth_settings.rest_https { "https" } else { "http" },
            auth_settings.hostname, auth_settings.rest_port, job_id
        );
        let stop_url = format!(
            "{}://{}:{}/v1/services/stop/{}",
            if auth_settings.rest_https { "https" } else { "http" },
            auth_settings.hostname, auth_settings.rest_port, job_id
        );
        Job {
            next_page_url,
            stop_url,
            auth_token,
            phantom: PhantomData,
        }
    }

    pub async fn stop_job(&self) -> Result<(), Box<dyn Error>> {
        let client = Client::new();
        let response = client
            .get(&self.stop_url)
            .header("authorization", &self.auth_token)
            .send()
            .await?;

        if response.status().as_u16() == 204 {
            Ok(())
        } else {
            let text = response.text().await?;
            Err(text)?;
            unreachable!();
        }
    }

    async fn current_page(&self, limit: usize) -> Result<Option<Response<T>>, Box<dyn Error>> {
        let mut limithm = HashMap::new();
        limithm.insert("limit", limit);

        let client = Client::new();
        let response = client
            .get(&self.next_page_url)
            .header("authorization", &self.auth_token)
            .json(&limithm)
            .send()
            .await?;

        let status = response.status().as_u16();
        let text = response.text().await?;

        if status == 404 {
            Ok(None)
        } else if status == 200 {
            let raw: RawResponse<T> = serde_json::from_str(&text)?;
            Ok(Some(Response::from(raw)))
        } else {
            Err(text)?;
            unreachable!();
        }
    }

    pub async fn next_page(&self, limit: usize, refresh: Duration) -> Result<Option<Response<T>>, Box<dyn Error>> {
        while let Some(page) = self.current_page(limit).await? {
            if page.status == Status::New || page.status == Status::Running {
                sleep(refresh).await;
                continue
            }
            return Ok(Some(page));
        }
        Ok(None)
    }
}

impl Db2REST {
    pub async fn connect(settings: AuthSettings) -> Result<Self, Box<dyn Error>> {
        let token = get_db2_auth_token(settings.clone()).await?;
        Ok(
            Self {
                auth_settings: settings,
                auth_token: token
            }
        )
    }

    async fn run_service<T, U, G>(&self, service: U, version: G, parameters: T, sync: bool) -> Result<String, Box<dyn Error>> where T: Serialize, U: AsRef<str>, G: AsRef<str> {
        let url = format!(
            "{}://{}:{}/v1/services/{}/{}",
            if self.auth_settings.rest_https { "https" } else { "http" },
            self.auth_settings.hostname, self.auth_settings.rest_port,
            service.as_ref(), version.as_ref()
        );

        let body = QueryParams {
            parameters,
            sync
        };

        let client = Client::new();
        let response = client
            .post(&url)
            .header("authorization", &self.auth_token)
            .json(&body)
            .send()
            .await?;

        let status = response.status().as_u16();
        let text = response.text().await?;

        if status == 200 || status == 202 {
            Ok(text)
        } else {
            Err(text)?;
            unreachable!();
        }
    }

    async fn run_sql<T, U>(&self, statement: U, parameters: T, is_query: bool, sync: bool) -> Result<String, Box<dyn Error>> where T: Serialize, U: AsRef<str> {
        let url = format!(
            "{}://{}:{}/v1/services/execsql",
            if self.auth_settings.rest_https { "https" } else { "http" },
            self.auth_settings.hostname, self.auth_settings.rest_port,
        );

        let body = SQLParams {
            sql_statement: statement.as_ref().to_string(),
            parameters,
            is_query,
            sync
        };

        let client = Client::new();
        let response = client
            .post(&url)
            .header("authorization", &self.auth_token)
            .json(&body)
            .send()
            .await?;

        let status = response.status().as_u16();
        let text = response.text().await?;

        if status == 200 || status == 202 {
            Ok(text)
        } else {
            Err(text)?;
            unreachable!();
        }
    }

    pub async fn run_sync_query_service<T, U, G, K>(&self, service: G, version: K, parameters: T) -> Result<Response<U>, Box<dyn Error>> where T: Serialize, U: DeserializeOwned, G: AsRef<str>, K: AsRef<str> {
        let response = self.run_service(service, version, parameters, true).await?;
        let raw: RawResponse<U> = serde_json::from_str(&response)?;
        Ok(Response::from(raw))
    }

    pub async fn run_sync_query_sql<T, U, G>(&self, statement: G, parameters: T) -> Result<Response<U>, Box<dyn Error>> where T: Serialize, U: DeserializeOwned, G: AsRef<str> {
        let response = self.run_sql(statement, parameters, true, true).await?;
        let raw: RawResponse<U> = serde_json::from_str(&response)?;
        Ok(Response::from(raw))
    }

    pub async fn run_sync_statement_service<T, U, G>(&self, service: U, version: G, parameters: T) -> Result<(), Box<dyn Error>> where T: Serialize, U: AsRef<str>, G: AsRef<str> {
        self.run_service(service, version, parameters, true).await?;
        Ok(())
    }

    pub async fn run_sync_statement_sql<T, U>(&self, statement: U, parameters: T) -> Result<(), Box<dyn Error>> where T: Serialize, U: AsRef<str> {
        self.run_sql(statement, parameters, false, true).await?;
        Ok(())
    }

    pub async fn run_async_service<T, U, G, K>(&self, service: G, version: K, parameters: T) -> Result<Job<U>, Box<dyn Error>> where T: Serialize, U: DeserializeOwned, G: AsRef<str>, K: AsRef<str> {
        let response = self.run_service(service, version, parameters, false).await?;
        let id = serde_json::from_str::<JobResponse>(&response)?.id;
        Ok(Job::<U>::new(id, &self.auth_settings, self.auth_token.clone()))
    }

    pub async fn run_async_sql<T, U, G>(&self, statement: G, parameters: T) -> Result<Job<U>, Box<dyn Error>> where T: Serialize, U: DeserializeOwned, G: AsRef<str> {
        let response = self.run_sql(statement, parameters, true, false).await?;
        let id = serde_json::from_str::<JobResponse>(&response)?.id;
        Ok(Job::<U>::new(id, &self.auth_settings, self.auth_token.clone()))
    }
}
