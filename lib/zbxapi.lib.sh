#!/bin/sh

# Zabbix API related functions
# Parameters in global variables ZAF_ZBX_API_*
# returns auth on stdout or false
zaf_zbxapi_login(){
 local authstr
 local user
 local pass

 [ -z "$ZAF_ZBXAPI_URL" ] || [ -z "$ZAF_ZBXAPI_USER" ] || [ -z "$ZAF_ZBXAPI_PASS" ] && zaf_err "Zabbix Api parameters not set!"
 authstr='{
   "params" : {
      "password" : "'$ZAF_ZBXAPI_PASS'",
      "user" : "'$ZAF_ZBXAPI_USER'"
   },
   "id" : 0,
   "jsonrpc" : "2.0",
   "method" : "user.login"
 }'
 zaf_dbg "Zabbix API login: $authstr"
 ZAF_ZBXAPI_AUTH=$(curl -s -f -L -X POST -H 'Content-Type: application/json-rpc' -d "$authstr" "$ZAF_ZBXAPI_URL" | json_pp | grep result | cut -d ':' -f 2 | tr -d '", ') || { zaf_err "Bad zabbix API parameters, cannot login."; }
 zaf_dbg "Logged into zabbix API ($ZAF_ZBXAPI_AUTH)"
}

zaf_zbxapi_getxml() {
	sed -e 's/\({"jsonrpc":"2.0","result":\)"\(.*\)",\("id":.*\)/\n\2\n/g' | sed -r 's/\\([/"])/\1/g'
}

# $1 host group or empty
zaf_zbxapi_gethosts() {
 local hstr
 local hgroup
 local filter
 
 hgroup="$1"
 [ -n "$hgroup" ] && filter='"filter": { "hostgroup": [ "'$hgroup'" ] },'
 hstr='{
    "jsonrpc": "2.0",
    "method": "host.get",
    "auth": "'$ZAF_ZBXAPI_AUTH'",
    '$filter'
    "id": 2
 }'
 zaf_dbg "Zabbix Get hosts: $hstr"
 curl -s -f -L -X POST -H 'Content-Type: application/json-rpc' -d "$hstr" "$ZAF_ZBXAPI_URL" |  tr ',' '\n' | grep hostid | cut -d '"' -f 4
}

# Host backup
# $1 hostid
zaf_zbxapi_backuphost(){
 local bkpstr
 
 host="$1"
 bkpstr='
 {
    "jsonrpc": "2.0",
    "method": "configuration.export",
    "params": {
        "options": {
            "hosts": [
                "'$host'"
            ]
        },
        "format": "xml"
    },
    "auth": "'$ZAF_ZBXAPI_AUTH'",
    "id": 1
}'
 zaf_dbg "Zabbix API backup host: $bkpstr"
 curl -s -f -L -X POST -H 'Content-Type: application/json-rpc' -d "$bkpstr" "$ZAF_ZBXAPI_URL" | zaf_zbxapi_getxml 
}


