
# Call api function and use cache
# $1 - query string
zaf_zbxapi_do() {
	local result
	zaf_trc "Zabbix API: $1"
	result=$(curl -s -f -L -X POST -H 'Content-Type: application/json-rpc' -d "$1" "$ZAF_ZBXAPI_URL")
	if [ $? = 0 ] && echo $result | grep -q '"result":'; then
		zaf_trc "API OK"
		echo $result
	else
		zaf_err "Error processing API request. ($?,$result)"
	fi
}
# Call api function and cache results 
# $1 - query string
zaf_zbxapi_do_cache() {
	local result
	if ! zaf_fromcache "$1"; then
		result=$(zaf_zbxapi_do "$1")
		[ -n "$result" ] && zaf_tocache "$1" "$result" 60
		echo $result
	fi
}

# Extract result from JSON response
zaf_zbxapi_getresult() {
	sed -e 's/\({"jsonrpc":"2.0","result":\)\(.*\),\("id":.*\)/\2/g' | sed -e 's/^\[\]$//'
}

# Extract XML result from JSON response
zaf_zbxapi_getxml() {
	zaf_zbxapi_getresult | sed -e 's/{"jsonrpc":"2.0","result":"//' | sed -e 's/","id"\:1}//' | zaf_zbxapi_getstring | zaf_strunescape '<">/'
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
 result=$(zaf_zbxapi_do_cache "$authstr")
 ZAF_ZBXAPI_AUTH=$(echo $result |zaf_zbxapi_getresult| zaf_zbxapi_getstring)
 [ -z "$ZAF_ZBXAPI_AUTH" ] && zaf_err "Cannot login into API"
 zaf_dbg "Logged into zabbix API ($ZAF_ZBXAPI_AUTH)"
}

# $1 hostgroup name
zaf_zbxapi_gethostgroupid() {
 local hstr
 local filter
 local gfilter
 local result
 
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
 result=$(zaf_zbxapi_do_cache "$hstr" | zaf_zbxapi_getresult | tr ',' '\n' | cut -d '"' -f 4)
 [ -z "$result" ] && zaf_err "HostGroup $1 not found!"
 echo $result
}

# $1 hostname
zaf_zbxapi_gethostid() {
 local hstr
 local host
 local groupid
 local filter
 local gfilter
 local result
 
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
 result=$(zaf_zbxapi_do_cache "$hstr" | zaf_zbxapi_getresult | tr ',' '\n' | cut -d '"' -f 4)
 [ -z "$result" ] && zaf_err "Host $1 not found!"
 echo $result
}

# $1 hostname
zaf_zbxapi_gettemplateid() {
 local hstr
 local host
 local groupid
 local filter
 local gfilter
 local result
 
 host="$1"
 if [ -n "$host" ] ; then
   filter='"filter": { "host": [ "'$host'" ] },'
 fi
 hstr='{
    "method": "template.get",
    "jsonrpc": "2.0",
    "auth": "'$ZAF_ZBXAPI_AUTH'",
    "params": {
	'$filter'
	"output": "shorten"
    },
    "id": 1
 }'
 result=$(zaf_zbxapi_do_cache "$hstr" | zaf_zbxapi_getresult | tr ',' '\n' | cut -d '"' -f 4)
 [ -z "$result" ] && zaf_err "Template $1 not found!"
 echo $result
}

# $1 hostid
zaf_zbxapi_gethost() {
 local hstr
 local host
 local groupid
 local filter
 local gfilter
 local result
 
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
 result=$(zaf_zbxapi_do_cache "$hstr" | zaf_zbxapi_getresult | zaf_zbxapi_getvalue host)
 [ -z "$result" ] && zaf_err "Hostid $1 not found!"
 echo $result
}

# $1 templateid
zaf_zbxapi_gettemplate() {
 local hstr
 local host
 local groupid
 local filter
 local gfilter
 local result
 
 hostid="$1"
 if [ -n "$hostid" ] ; then
   filter='"templateids": [ "'$hostid'" ],'
 fi
 hstr='{
    "method": "template.get",
    "jsonrpc": "2.0",
    "auth": "'$ZAF_ZBXAPI_AUTH'",
    "params": {
	'$filter'
	"output": "extend"
    },
    "id": 1
 }'
 result=$(zaf_zbxapi_do_cache "$hstr" | zaf_zbxapi_getresult | zaf_zbxapi_getvalue host)
 [ -z "$result" ] && zaf_err "Templateid $1 not found!"
 echo $result
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
 zaf_zbxapi_do_cache "$hstr" | zaf_zbxapi_getresult | tr ',' '\n' | cut -d '"' -f 4
}

# Object backup
# $1 object
# $2 id
zaf_zbxapi_export_object(){
 local bkpstr
 local obj
 local id
 
 obj="$1"
 id="$2"

 bkpstr='
 {
    "method": "configuration.export",
    "jsonrpc": "2.0",
    "params": {
        "options": {
            "'$obj'": [
                "'$id'"
            ]
        },
        "format": "xml"
    },
    "auth": "'$ZAF_ZBXAPI_AUTH'",
    "id": 1
}'
 zaf_zbxapi_do_cache "$bkpstr" | zaf_zbxapi_getxml
}


# Host backup
# $1 hostid
zaf_zbxapi_export_host(){
 zaf_zbxapi_export_object hosts "$1"
}

# Template backup
# $1 templateid
zaf_zbxapi_export_template(){
 zaf_zbxapi_export_object templates "$1"
}

# Map backup
# $1 mapid
zaf_zbxapi_export_map(){
 zaf_zbxapi_export_object maps "$1"
}

# Import template into zabbix
# $1 template file or stdin
zaf_zbxapi_import_config(){
 local xmlstr
 local impstr

 if [ -z "$1" ]; then
   xmlstr=$(zaf_strescape '"')
 else
   ! [ -f "$1" ] && return 1
   xmlstr=$(zaf_strescape '"\n\r' <$1)
 fi
 impstr='
 {
    "method": "configuration.import",
    "jsonrpc": "2.0",
    "params": {
        "format": "xml",
        "rules": {
	    "applications": {
                "createMissing": true,
                "updateExisting": true
            },
            "discoveryRules": {
                "createMissing": true,
                "updateExisting": true
            },
	    "graphs": {
                "createMissing": true,
                "updateExisting": true
            },
            "hosts": {
                "createMissing": true,
                "updateExisting": true
            },
            "items": {
                "createMissing": true,
                "updateExisting": true
            },
	    "templates": {
                "createMissing": true,
                "updateExisting": true
            },
            "triggers": {
                "createMissing": true,
                "updateExisting": true
            },
	    "maps": {
                "createMissing": true,
                "updateExisting": true
            },
	    "screens": {
                "createMissing": true,
                "updateExisting": true
            },
            "items": {
                "createMissing": true,
                "updateExisting": true
            },
	    "valueMaps": {
                "createMissing": true,
                "updateExisting": true
            }
        },
	"source": "'$xmlstr'"
    },
    "auth": "'$ZAF_ZBXAPI_AUTH'",
    "id": 3
}'
 zaf_zbxapi_do "$impstr" | zaf_zbxapi_getresult | grep -q true
}


