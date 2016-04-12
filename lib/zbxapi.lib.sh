# Call api function 
# $1 - query string
zaf_zbxapi_do() {
	local result
	if ! zaf_fromcache "$1"; then
		zaf_trc "Zabbix API: $1"
		result=$(curl -s -f -L -X POST -H 'Content-Type: application/json-rpc' -d "$1" "$ZAF_ZBXAPI_URL")
		if [ $? = 0 ] && echo $result | grep -q '"result":'; then
			zaf_tocache "$1" "$result" 60		
			echo $result
		else
			zaf_err "Error processing API request. ($?,$result)"
		fi
	fi
}

# Extract result from JSON response
zaf_zbxapi_getresult() {
	sed -e 's/\({"jsonrpc":"2.0","result":\)\(.*\),\("id":.*\)/\2/g' | sed -e 's/^\[\]$//'
}

# Extract XML result from JSON response
zaf_zbxapi_getxml() {
	zaf_zbxapi_getresult | sed -e 's/{"jsonrpc":"2.0","result":"//' | sed -e 's/","id"\:1}//' | sed -e 's#\\\([<">/]\)#\1#g'
}

# Extract string from JSON response result
zaf_zbxapi_getstring() {
	 sed -e 's/^"//'  -e 's/"$//' -e 's/\\n/'\\n'/g'
}

# Extract value from JSON response result
# $1 key
zaf_zbxapi_getvalue() {
	 tr ',' '\n' | grep "\"$1\":" | cut -d '"' -f 4
}

# Zabbix API related functions
# Parameters in global variables ZAF_ZBX_API_*
# returns auth on stdout or false
zaf_zbxapi_login(){
 local authstr
 local user
 local pass
 local result

 [ -z "$ZAF_ZBXAPI_URL" ] || [ -z "$ZAF_ZBXAPI_USER" ] || [ -z "$ZAF_ZBXAPI_PASS" ] && zaf_err "Zabbix Api parameters not set!"
 authstr='{
   "method" : "user.login",
   "params" : {
      "password" : "'$ZAF_ZBXAPI_PASS'",
      "user" : "'$ZAF_ZBXAPI_USER'"
   },
   "id" : 0,
   "jsonrpc" : "2.0"
 }'
 
 if [ "$ZAF_ZBXAPI_AUTHTYPE" = "http" ] ; then
    ZAF_ZBXAPI_URL=$(echo $ZAF_ZBXAPI_URL | cut -d '/' -f 1)//$ZAF_ZBXAPI_USER:$ZAF_ZBXAPI_PASS@$(echo $ZAF_ZBXAPI_URL | cut -d '/' -f 3-)
 fi
 result=$(zaf_zbxapi_do "$authstr")
 ZAF_ZBXAPI_AUTH=$(echo $result |zaf_zbxapi_getresult| zaf_zbxapi_getstring)
 zaf_dbg "Logged into zabbix API ($ZAF_ZBXAPI_AUTH)"
}

# $1 hostgroup name
zaf_zbxapi_gethostgroupid() {
 local hstr
 local filter
 local gfilter
 
 hstr='{
    "method": "hostgroup.get",
    "jsonrpc": "2.0",
    "auth": "'$ZAF_ZBXAPI_AUTH'",
    "params": {
	"filter": {
	 "name": ["'$1'"]
	},
	"output": "shorten"
    },
    "id": 1
 }'
 zaf_zbxapi_do "$hstr" | zaf_zbxapi_getresult | tr ',' '\n' | cut -d '"' -f 4
}

# $1 hostname
zaf_zbxapi_gethostid() {
 local hstr
 local host
 local groupid
 local filter
 local gfilter
 
 host="$1"
 if [ -n "$host" ] ; then
   filter='"filter": { "host": [ "'$host'" ] },'
 fi
 hstr='{
    "method": "host.get",
    "jsonrpc": "2.0",
    "auth": "'$ZAF_ZBXAPI_AUTH'",
    "params": {
	'$filter'
	"output": "shorten"
    },
    "id": 1
 }'
 zaf_zbxapi_do "$hstr" | zaf_zbxapi_getresult | tr ',' '\n' | cut -d '"' -f 4
}

# $1 hostid
zaf_zbxapi_gethost() {
 local hstr
 local host
 local groupid
 local filter
 local gfilter
 
 hostid="$1"
 if [ -n "$hostid" ] ; then
   filter='"hostids": [ "'$hostid'" ],'
 fi
 hstr='{
    "method": "host.get",
    "jsonrpc": "2.0",
    "auth": "'$ZAF_ZBXAPI_AUTH'",
    "params": {
	'$filter'
	"output": "extend"
    },
    "id": 1
 }'
 zaf_zbxapi_do "$hstr" | zaf_zbxapi_getresult | zaf_zbxapi_getvalue host
}

# $1 hostgroupid
zaf_zbxapi_gethostsingroup() {
 local hstr
 local host
 local groupid
 local filter
 local gfilter

 groupid="$1"
 if [ -n "$groupid" ]; then
   gfilter='"groupids": [ "'$groupid'" ],'
 fi

 hstr='{
    "method": "host.get",
    "jsonrpc": "2.0",
    "auth": "'$ZAF_ZBXAPI_AUTH'",
    "params": {
	'$gfilter'
	'$filter'
	"output": "shorten"
    },
    "id": 1
 }'
 zaf_zbxapi_do "$hstr" | zaf_zbxapi_getresult | tr ',' '\n' | cut -d '"' -f 4
}

# Host backup
# $1 hostid
zaf_zbxapi_backuphost(){
 local bkpstr
 
 host="$1"
 bkpstr='
 {
    "method": "configuration.export",
    "jsonrpc": "2.0",
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
 zaf_zbxapi_do "$bkpstr" | zaf_zbxapi_getxml
}


