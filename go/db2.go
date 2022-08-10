package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"time"
)

type Auth struct {
	Token string `json:"token"`
}

type AuthSettings struct {
	RestHttps bool
	Hostname  string
	RestPort  int
	Database  string
	DbPort    int
	SslDb2    bool
	Password  string
	Username  string
	Expiry    string
}

type DbParms struct {
	DbHost          string `json:"dbHost"`
	DbName          string `json:"dbName"`
	DbPort          int    `json:"dbPort"`
	IsSSLConnection bool   `json:"isSSLConnection"`
	Password        string `json:"password"`
	Username        string `json:"username"`
}

type AuthBody struct {
	DbParms    DbParms `json:"dbParms"`
	ExpiryTime string  `json:"expiryTime"`
}

type QueryParams[T any] struct {
	Parameters T    `json:"parameters"`
	Sync       bool `json:"sync"`
}

type SQLParams[T any] struct {
	SQLStatement string `json:"sqlStatement"`
	Parameters   T      `json:"parameters"`
	IsQuery      bool   `json:"isQuery"`
	Sync         bool   `json:"sync"`
}

type Status int

const (
	Failed Status = iota
	New
	Running
	DataAvailable
	Completed
	Stopping
)

type RawResponse[T any] struct {
	JobStatus int `json:"jobStatus"`
	ResultSet []T `json:"resultSet"`
}

type Response[T any] struct {
	Status  Status
	Results []T
}

type JobResponse struct {
	Id string `json:"id"`
}

type Job[T any] struct {
	NextPageUrl string
	StopUrl     string
	authToken   string
}

type Db2REST struct {
	AuthSettings AuthSettings
	authToken    string
}

func GetDb2AuthToken(authSettings AuthSettings) (string, error) {
	method := "https"
	if !authSettings.RestHttps {
		method = "http"
	}
	authUrl := fmt.Sprintf("%s://%s:%d/v1/auth",
		method, authSettings.Hostname, authSettings.RestPort)

	body := AuthBody{
		DbParms: DbParms{
			DbHost:          authSettings.Hostname,
			DbName:          authSettings.Database,
			DbPort:          authSettings.DbPort,
			IsSSLConnection: authSettings.SslDb2,
			Password:        authSettings.Password,
			Username:        authSettings.Username,
		},
		ExpiryTime: authSettings.Expiry,
	}

	client := &http.Client{}
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", authUrl, bytes.NewBuffer(jsonBody))
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}

	defer resp.Body.Close()
	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	if resp.StatusCode == 200 {
		var auth Auth
		err = json.Unmarshal(respBody, &auth)
		if err != nil {
			return "", err
		}

		return auth.Token, nil
	} else {
		return "", errors.New(string(respBody))
	}
}

func toStatus(n int) Status {
	switch n {
	case 0:
		return Failed
	case 1:
		return New
	case 2:
		return Running
	case 3:
		return DataAvailable
	case 4:
		return Completed
	case 5:
		return Stopping
	default:
		panic("unreachable")
	}
}

func toResponse[T any](raw RawResponse[T]) Response[T] {
	return Response[T]{
		Status:  toStatus(raw.JobStatus),
		Results: raw.ResultSet,
	}
}

func Connect(settings AuthSettings) (Db2REST, error) {
	token, err := GetDb2AuthToken(settings)
	if err != nil {
		return Db2REST{}, err
	}

	return Db2REST{
		AuthSettings: settings,
		authToken:    token,
	}, nil
}

func RunService[T any](db2 *Db2REST, service string, version string, parameters T, sync bool) (string, error) {
	method := "https"
	if !db2.AuthSettings.RestHttps {
		method = "http"
	}
	url := fmt.Sprintf("%s://%s:%d/v1/services/%s/%s",
		method, db2.AuthSettings.Hostname, db2.AuthSettings.RestPort,
		service, version)

	body := QueryParams[T]{
		Parameters: parameters,
		Sync:       sync,
	}

	client := &http.Client{}
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("authorization", db2.authToken)
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}

	defer resp.Body.Close()
	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	if resp.StatusCode == 200 || resp.StatusCode == 202 {
		return string(respBody), nil
	} else {
		return "", errors.New(string(respBody))
	}
}

func RunSQL[T any](db2 *Db2REST, statement string, parameters T, isQuery bool, sync bool) (string, error) {
	method := "https"
	if !db2.AuthSettings.RestHttps {
		method = "http"
	}
	url := fmt.Sprintf("%s://%s:%d/v1/services/execsql",
		method, db2.AuthSettings.Hostname, db2.AuthSettings.RestPort)

	body := SQLParams[T]{
		SQLStatement: statement,
		Parameters:   parameters,
		IsQuery:      isQuery,
		Sync:         sync,
	}

	client := &http.Client{}
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("authorization", db2.authToken)
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}

	defer resp.Body.Close()
	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	if resp.StatusCode == 200 || resp.StatusCode == 202 {
		return string(respBody), nil
	} else {
		return "", errors.New(string(respBody))
	}
}

func RunSyncQueryService[T any, U any](db2 *Db2REST, service string, version string, parameters T) (Response[U], error) {
	response, err := RunService[T](db2, service, version, parameters, true)
	if err != nil {
		return Response[U]{}, err
	}

	var raw RawResponse[U]
	err = json.Unmarshal([]byte(response), &raw)
	if err != nil {
		return Response[U]{}, err
	}

	return toResponse[U](raw), nil
}

func RunSyncQuerySQL[T any, U any](db2 *Db2REST, statement string, parameters T) (Response[U], error) {
	response, err := RunSQL[T](db2, statement, parameters, true, true)
	if err != nil {
		return Response[U]{}, err
	}

	var raw RawResponse[U]
	err = json.Unmarshal([]byte(response), &raw)
	if err != nil {
		return Response[U]{}, err
	}

	return toResponse[U](raw), nil
}

func RunSyncStatementService[T any](db2 *Db2REST, service string, version string, parameters T) error {
	_, err := RunService[T](db2, service, version, parameters, true)
	if err != nil {
		return err
	}

	return nil
}

func RunSyncStatementSQL[T any](db2 *Db2REST, statement string, parameters T) error {
	_, err := RunSQL[T](db2, statement, parameters, false, true)
	if err != nil {
		return err
	}

	return nil
}

func RunAsyncService[T any, U any](db2 *Db2REST, service string, version string, parameters T) (Job[U], error) {
	response, err := RunService[T](db2, service, version, parameters, false)
	if err != nil {
		return Job[U]{}, err
	}

	var jobId JobResponse
	err = json.Unmarshal([]byte(response), &jobId)
	if err != nil {
		return Job[U]{}, err
	}

	return NewJob[U](jobId.Id, &db2.AuthSettings, db2.authToken), nil
}

func RunAsyncSQL[T any, U any](db2 *Db2REST, statement string, parameters T) (Job[U], error) {
	response, err := RunSQL[T](db2, statement, parameters, true, false)
	if err != nil {
		return Job[U]{}, err
	}

	var jobId JobResponse
	err = json.Unmarshal([]byte(response), &jobId)
	if err != nil {
		return Job[U]{}, err
	}

	return NewJob[U](jobId.Id, &db2.AuthSettings, db2.authToken), nil
}

func NewJob[T any](jobId string, authSettings *AuthSettings, authToken string) Job[T] {
	method := "https"
	if !authSettings.RestHttps {
		method = "http"
	}
	nextPageUrl := fmt.Sprintf("%s://%s:%d/v1/services/%s",
		method, authSettings.Hostname, authSettings.RestPort, jobId)
	stopUrl := fmt.Sprintf("%s://%s:%d/v1/services/stop/%s",
		method, authSettings.Hostname, authSettings.RestPort, jobId)

	return Job[T]{
		NextPageUrl: nextPageUrl,
		StopUrl:     stopUrl,
		authToken:   authToken,
	}
}

func (job *Job[T]) StopJob() error {
	client := &http.Client{}
	req, err := http.NewRequest("GET", job.StopUrl, nil)
	if err != nil {
		return err
	}

	req.Header.Set("authorization", job.authToken)
	resp, err := client.Do(req)
	if err != nil {
		return err
	}

	defer resp.Body.Close()
	if resp.StatusCode == 204 {
		return nil
	} else {
		respBody, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return err
		}

		return errors.New(string(respBody))
	}
}

func (job *Job[T]) CurrentPage(limit int) (*Response[T], error) {
	limithm := map[string]int{
		"limit": limit,
	}

	client := &http.Client{}
	jsonBody, err := json.Marshal(limithm)
	if err != nil {
		return &Response[T]{}, err
	}

	req, err := http.NewRequest("GET", job.NextPageUrl, bytes.NewBuffer(jsonBody))
	if err != nil {
		return &Response[T]{}, err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("authorization", job.authToken)
	resp, err := client.Do(req)
	if err != nil {
		return &Response[T]{}, err
	}

	defer resp.Body.Close()
	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return &Response[T]{}, err
	}

	if resp.StatusCode == 404 {
		return nil, nil
	} else if resp.StatusCode == 200 {
		var raw RawResponse[T]
		err = json.Unmarshal(respBody, &raw)
		if err != nil {
			return &Response[T]{}, err
		}

		r := toResponse[T](raw)
		return &r, nil
	} else {
		return &Response[T]{}, errors.New(string(respBody))
	}
}

func (job *Job[T]) NextPage(limit int, refresh time.Duration) (*Response[T], error) {
	for {
		page, err := job.CurrentPage(limit)
		if err != nil {
			return &Response[T]{}, err
		}

		if page == nil {
			return nil, nil
		}

		if page.Status == New || page.Status == Running {
			<-time.After(refresh)
			continue
		}

		return page, nil
	}
}
