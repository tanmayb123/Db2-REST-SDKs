import re
import requests
import json

REST_CONNECTION = {
    "hostname": "http://IP:PORT",
    "db2": {
        "dbHost": "HOST",
        "dbName": "DATABASE",
        "dbPort": 50000,
        "isSSLConnection": False,
        "password": "PASSWORD",
        "username": "USERNAME"
    }
}
JSON_TYPE_MAPPING = {
    "CHARACTER": "string",
    "VARCHAR": "string",
    "DATE": "string",
    "SMALLINT": "integer",
    "INTEGER": "integer",
    "BIGINT": "integer",
}

def get_auth_token(hostname, db2_connection):
    req_json = {
        "dbParms": db2_connection,
        "expiryTime": "1h"
    }
    response = requests.post(f"{hostname}/v1/auth", json=req_json, verify=False).text
    result = json.loads(response)
    return result["token"]

def get_services(hostname, token):
    headers = {
        "Authorization": token,
        "Content-Type": "application/json"
    }
    result = json.loads(requests.get(f"{hostname}/v1/services", headers=headers, verify=False).text)
    return result["Db2Services"]

def describe_service(hostname, token, service_name, service_version):
    headers = {
        "Authorization": token,
        "Content-Type": "application/json"
    }
    response = requests.get(f"{hostname}/v1/services/{service_name}/{service_version}", headers=headers, verify=False).text
    result = json.loads(response)
    return result

def get_service_statement(hostname, token, proc_schema, proc_name, input_params):
    stmt = "SELECT CAST(TEXT AS VARCHAR) STMT FROM SYSCAT.PROCEDURES WHERE PROCSCHEMA=? AND PROCNAME=?"
    req_json = {
        "isQuery": True,
        "parameters": {
            "1": proc_schema,
            "2": proc_name
        },
        "sqlStatement": stmt,
        "sync": True
    }
    headers = {
        "Authorization": token,
        "Content-Type": "application/json"
    }
    response = requests.post(f"{hostname}/v1/services/execsql", headers=headers, json=req_json, verify=False).text
    stmt = json.loads(response)["resultSet"][0]["STMT"]
    result = re.findall(r"(?m)-- BEGIN SQL STATEMENT\n(.*?);\n-- END SQL STATEMENT", stmt)
    if len(result) == 0:
        result = re.findall(r"BEGIN\n(.*);\n", stmt)
    stmt = result[0]
    for i in input_params:
        stmt = stmt.replace(i, "NULL")
    return stmt

def describe_statement_output(hostname, token, statement):
    stmt = f"CALL SYSPROC.ADMIN_CMD('DESCRIBE OUTPUT {statement}')"
    req_json = {
        "isQuery": True,
        "parameters": {},
        "sqlStatement": stmt,
        "sync": True
    }
    headers = {
        "Authorization": token,
        "Content-Type": "application/json"
    }
    response = requests.post(f"{hostname}/v1/services/execsql", headers=headers, json=req_json, verify=False).text
    result = json.loads(response)["resultSet"]
    r = {}
    for i in result:
        r[i["SQLNAME_DATA"]] = i["SQLTYPE_ID"] % 2 == 1
    return r

def camelcaseify(snakecase, upperfirst=False):
    snakecase = list(snakecase.lower())
    i = 0
    while i < len(snakecase):
        if snakecase[i] == "_":
            del snakecase[i]
            snakecase[i] = snakecase[i].upper()
        else:
            i += 1
    if upperfirst:
        snakecase[0] = snakecase[0].upper()
    return "".join(snakecase)

def get_input_for_service(hostname, token, service):
    final_service = {
        "formal_name": service["serviceName"],
        "formal_version": service["version"],
    }

    print(f'Service {service["serviceName"]}:')

    is_query = input("Generate as query? (y/n): ") == "y"

    code_name = camelcaseify(service["serviceName"])
    new_code_name = input(f"Generated function name ({code_name}): ")
    code_name = new_code_name if new_code_name != "" else code_name
    final_service["request_name"] = code_name

    if is_query:
        result_name = camelcaseify(service["serviceName"], True)
        result_name += "Response"
        new_result_name = input(f"Generated result name ({result_name}): ")
        result_name = new_result_name if new_result_name != "" else result_name
        final_service["response_name"] = result_name

    parameters = []
    for field in service["inputParameters"]:
        if field["mode"] != "IN":
            continue

        name = camelcaseify(field["name"][1:])
        new_name = input(f'Name of parameter field {field["name"][1:]} ({name}): ')
        name = new_name if new_name != "" else name
        parameters.append({
            "formal_name": field["name"],
            "name": name,
            "json_type": JSON_TYPE_MAPPING[field["type"]],
            "sql_type": field["type"],
            "nullable": True
        })
    final_service["parameters"] = parameters

    if is_query:
        statement = get_service_statement(hostname, token, service["procSchema"], service["procName"], [x["name"] for x in service["inputParameters"]])
        described_returns = describe_statement_output(hostname, token, statement)
        return_fields = []
        for field in service["resultSetFields"]:
            name = camelcaseify(field["name"])
            new_name = input(f'Name of result field {field["name"]} ({name}): ')
            name = new_name if new_name != "" else name
            return_fields.append({
                "formal_name": field["name"],
                "name": name,
                "json_type": field["jsonType"],
                "sql_type": field["type"],
                "nullable": described_returns[field["name"]]
            })
        final_service["columns"] = return_fields

    return {
        "type": "query" if is_query else "statement",
        "json": json.dumps(final_service)
    }

if __name__ == "__main__":
    rest_hostname = REST_CONNECTION["hostname"]
    db2_connection = REST_CONNECTION["db2"]

    token = get_auth_token(rest_hostname, db2_connection)
    services = get_services(rest_hostname, token)
    services = [describe_service(rest_hostname, token, x["serviceName"], x["version"]) for x in services]
    exported_services = []
    for service in services:
        exported_services.append(get_input_for_service(rest_hostname, token, service))
        print("")

    f = open("codegen.json", "w")
    f.write(json.dumps(exported_services))
    f.close()
