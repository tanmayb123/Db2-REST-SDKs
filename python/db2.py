import asyncio
import aiohttp
import json

class AuthSettings:
    def __init__(self, rest_https, hostname, rest_port, database, db_port, ssl_db2, password, username, expiry_time):
        self.rest_https = rest_https
        self.hostname = hostname
        self.rest_port = rest_port
        self.database = database
        self.db_port = db_port
        self.ssl_db2 = ssl_db2
        self.password = password
        self.username = username
        self.expiry_time = expiry_time

async def get_db2_auth_token(auth_settings):
    auth_url = f"{'https' if auth_settings.rest_https else 'http'}://{auth_settings.hostname}:{auth_settings.rest_port}/v1/auth"
    body = {
        "dbParms": {
            "dbHost": auth_settings.hostname,
            "dbName": auth_settings.database,
            "dbPort": auth_settings.db_port,
            "isSSLConnection": auth_settings.ssl_db2,
            "password": auth_settings.password,
            "username": auth_settings.username,
        },
        "expiryTime": auth_settings.expiry_time,
    }
    async with aiohttp.ClientSession() as session:
        async with session.post(auth_url, json=body) as response:
            if response.status == 200:
                return (await response.json())["token"]
            else:
                raise Exception(await response.text())

class Db2REST:
    @classmethod
    async def connect(cls, auth_settings):
        self = Db2REST()
        self.auth_settings = auth_settings
        self.auth_token = await get_db2_auth_token(auth_settings)
        return self

    async def run_service(self, service, version, parameters, sync):
        url = f"{'https' if self.auth_settings.rest_https else 'http'}://{self.auth_settings.hostname}:{self.auth_settings.rest_port}/v1/services/{service}/{version}"
        body = {
            "parameters": parameters,
            "sync": sync,
        }
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=body, headers={"authorization": self.auth_token}) as response:
                if response.status == 200 or response.status == 202:
                    return await response.text()
                else:
                    raise Exception(await response.text())

    async def run_sql(self, statement, parameters, is_query, sync):
        url = f"{'https' if self.auth_settings.rest_https else 'http'}://{self.auth_settings.hostname}:{self.auth_settings.rest_port}/v1/services/execsql"
        body = {
            "sqlStatement": statement,
            "parameters": parameters,
            "isQuery": is_query,
            "sync": sync,
        }
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=body, headers={"authorization": self.auth_token}) as response:
                if response.status == 200 or response.status == 202:
                    return await response.text()
                else:
                    raise Exception(await response.text())

    async def run_sync_query_service(self, service, version, parameters):
        response = await self.run_service(service, version, parameters, True)
        return json.loads(response)

    async def run_sync_query_sql(self, statement, parameters):
        response = await self.run_sql(statement, parameters, True, True)
        return json.loads(response)

    async def run_sync_statement_service(self, service, version, parameters):
        await self.run_service(service, version, parameters, True)

    async def run_sync_statement_sql(self, statement, parameters):
        await self.run_sql(statement, parameters, False, True)

    async def run_async_service(self, service, version, parameters):
        response = await self.run_service(service, version, parameters, False)
        job_id = json.loads(response)["id"]
        return Job(job_id, self.auth_settings, self.auth_token)

    async def run_async_sql(self, statement, parameters):
        response = await self.run_sql(statement, parameters, True, False)
        job_id = json.loads(response)["id"]
        return Job(job_id, self.auth_settings, self.auth_token)

class Job:
    def __init__(self, job_id, auth_settings, auth_token):
        self.next_page_url = f"{'https' if auth_settings.rest_https else 'http'}://{auth_settings.hostname}:{auth_settings.rest_port}/v1/services/{job_id}"
        self.stop_url = f"{'https' if auth_settings.rest_https else 'http'}://{auth_settings.hostname}:{auth_settings.rest_port}/v1/services/stop/{job_id}"
        self.auth_token = auth_token

    async def stop_job(self):
        async with aiohttp.ClientSession() as session:
            async with session.get(self.stop_url, headers={"authorization": self.auth_token}) as response:
                if response.status == 204:
                    return
                else:
                    raise Exception(await response.text())

    async def current_page(self, limit):
        async with aiohttp.ClientSession() as session:
            async with session.get(self.next_page_url, json={"limit": limit}, headers={"authorization": self.auth_token}) as response:
                if response.status == 404:
                    return None
                elif response.status == 200:
                    return json.loads(await response.text())
                else:
                    raise Exception(await response.text())

    async def next_page(self, limit, refresh):
        while True:
            page = await self.current_page(limit)
            if page is None:
                return None
            if page["jobStatus"] == 1 or page["jobStatus"] == 2:
                await asyncio.sleep(refresh)
                continue
            return page
