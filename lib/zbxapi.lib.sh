
# Call api function and use cache
# $1 - query string
zaf_zbxapi_do() {
	local result
	local query
	local tmpfile

	tmpfile=$ZAF_TMP_DIR/zapi$$
	query="$1"
	zaf_trc "Zabbix API: $query"
	curl -s -f -L -X POST -H 'Content-Type: application/json-rpc' -d "$query" "$ZAF_ZBXAPI_URL" >$tmpfile
	if [ $? = 0 ] &&	$ZAF_LIB_DIR/JSON.sh -b <$tmpfile | grep -q '"result"'; then
		zaf_trc "API OK"
		cat $tmpfile
		rm -f $tmpfile
	else
		zaf_err "Error processing API request. ($?,$tmpfile)"
	fi
}
# Call api function and cache results 
# $1 - query string
zaf_zbxapi_do_cache() {
	local result
	local tmpfile
	local query

	query="$(echo $1 | tr '\n' ' ')"
	tmpfile=$ZAF_TMP_DIR/zcapi$$
	if ! zaf_fromcache "$1"; then
		zaf_zbxapi_do "$1" >$tmpfile
		[ -s "$tmpfile" ] && cat $tmpfile | zaf_tocache_stdin "$query" 60
		rm -f $tmpfile
	fi
}

# Extract one result from JSON response
zaf_zbxapi_getresult() {
	$ZAF_LIB_DIR/JSON.sh -b | grep '\["result"\]' | tr '\t' ' ' | cut -d ' ' -f 2-
}

# Extract XML result from JSON response
zaf_zbxapi_getxml() {
	zaf_zbxapi_getstring | zaf_strunescape '</">' | zaf_far '\\n' "\n"
}

# Extract string from JSON response result
zaf_zbxapi_getstring() {
	 zaf_zbxapi_getresult | sed -e 's/^"//' -e 's/"$//'
}

# Extract value from JSON response result
# $1 key
zaf_zbxapi_getvalues() {
	 $ZAF_LIB_DIR/JSON.sh -b | grep '\["result",.*,"'$1'"]'	 | tr '\t' ' ' | cut -d ' ' -f 2- | sed -e 's/^"//' -e 's/"$//'
}

# Zabbix API related functions
# Parameters in global variables ZAF_ZBX_API_*
# returns auth on stdout or false
zaf_zbxapi_login(){
 local authstr
 local user
 local pass
 local result

 [ -z "$ZAF_ZBXAPI_URL" ] || [ -z "$ZAF_ZBXAPI_USER" ] || [ -z "$ZAF_ZBXAPI_PASS" ] && zaf_err "Zabbix Api parameters not set! Set ZAF_ZBXAPI_URL, ZAF_ZBXAPI_USER and ZAF_ZBXAPI_PASS and try again."
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
 ZAF_ZBXAPI_AUTH=$(echo $result |zaf_zbxapi_getstring)
 [ -z "$ZAF_ZBXAPI_AUTH" ] && zaf_err "Cannot login into API"
 zaf_dbg "Logged into zabbix API ($ZAF_ZBXAPI_AUTH)"
}

# Get object from zabbix API
# $1 object_type
# $2 filter
# $3 params
# $4 output
# $5 id
zaf_zbxapi_get_object() {
	local obj
	local filter
	local params
	local str
	local output
	local id
	local result

	obj=$1
	filter=$2
	params=$3
	output=$4
	id=$5
	[ -z "$id" ] && id=1
	[ -n "$filter" ] && filter='"filter": {'$filter'},';
	[ -z "$output" ] && output="shorten";
	if [ -n "$params" ]; then
		params='"params": {'$params', '$filter' "output":"'$output'"}';
	else
		params='"params": {'$filter' "output":"'$output'"}';
	fi
	str='{ "method": "'$obj'.get", "jsonrpc": "2.0", "auth": "'$ZAF_ZBXAPI_AUTH'",'$params', "id": "'$id'" }'
	result=$(zaf_zbxapi_do_cache "$str")
	[ -z "$result" ] && zaf_dbg "API call result empty or error! ($str)"
	echo $result
}

# $1 hostgroup name
zaf_zbxapi_gethostgroupid() {
	local result

	result=$(zaf_zbxapi_get_object "hostgroup" '"name": ["'$1'"]')
	[ -z "$result" ] && zaf_err "HostGroup $1 not found!"
	echo $result |zaf_zbxapi_getvalues groupid
}

# $1 hostid
# $2 property or null for all
zaf_zbxapi_gethost() {
	local result

	result=$(zaf_zbxapi_get_object "host" '' '"hostids": ["'$1'"]' 'extend')
	[ -z "$result" ] && zaf_err "Hostid $1 not found!"
	if [ -z "$2" ]; then
		echo $result
	else
		echo $result |zaf_zbxapi_getvalues $2
	fi
}

# $1 hostname
zaf_zbxapi_gethostid() {
	local result

	result=$(zaf_zbxapi_get_object "host" '"host": ["'$1'"]')
	[ -z "$result" ] && zaf_err "Host $1 not found!"
	echo $result |zaf_zbxapi_getvalues hostid
}

# $1 hostname
# $2 inv field or empty for json
zaf_zbxapi_gethostinventory() {
	local result

	result=$(zaf_zbxapi_get_object "host" '"host": ["'$1'"]' '"withInventory": "true", "selectInventory": "extend"')
	[ -z "$result" ] && zaf_err "Host $1 not found!"
	if [ -z "$2" ]; then
		echo $result 
	else
		echo $result |zaf_zbxapi_getvalues $2
	fi
}

# $1 hostname
zaf_zbxapi_gettemplateid() {
	local result

	result=$(zaf_zbxapi_get_object "template" '"host": ["'$1'"]')
	[ -z "$result" ] && zaf_err "Template $1 not found!"
	echo $result |zaf_zbxapi_getvalues templateid
}

# $1 templateid
# $2 property or null for all
zaf_zbxapi_gettemplate() {
	local result

	result=$(zaf_zbxapi_get_object "template" '' '"templateids": ["'$1'"]' 'extend')
	[ -z "$result" ] && zaf_err "Templateid $1 not found!"
	if [ -z "$2" ]; then
		echo $result
	else
		echo $result |zaf_zbxapi_getvalues $2
	fi
}

# $1 hostgroupid 
zaf_zbxapi_gethostsingroup() {
	local result

	result=$(zaf_zbxapi_get_object "host" '' '"groupids": ["'$1'"]')
	[ -z "$result" ] && zaf_wrn "No hosts in groupid '$1'"
	echo $result | zaf_zbxapi_getvalues "hostid"
}

# Get all hostids in system
zaf_zbxapi_gethostids() {
	local result

	result=$(zaf_zbxapi_get_object "host")
	echo $result | zaf_zbxapi_getvalues "hostid"
}

# Get all templateids in system
zaf_zbxapi_gettemplateids() {
	local result

	result=$(zaf_zbxapi_get_object "template")
	echo $result | zaf_zbxapi_getvalues "templateid"
}

# $1 hostgroupid 
zaf_zbxapi_gettemplatesingroup() {
	local result

	result=$(zaf_zbxapi_get_object "template" '' '"groupids": ["'$1'"]')
	[ -z "$result" ] && zaf_wrn "No templates in groupid '$1'"
	echo $result | zaf_zbxapi_getvalues "templateid"
}

# $1 map or null for all
zaf_zbxapi_getmapid() {
	local result

	if [ -n "$1" ]; then
		result=$(zaf_zbxapi_get_object "map" '"name": ["'$1'"]')
	else
		result=$(zaf_zbxapi_get_object "map")
	fi
	[ -z "$result" ] && zaf_err "Map $1 not found"
	echo $result | zaf_zbxapi_getvalues "sysmapid"
}

# $1 mapid
# $2 property or null for all
zaf_zbxapi_getmap() {
	local result

	result=$(zaf_zbxapi_get_object "map" '' '"sysmapids": ["'$1'"]' 'extend')
	[ -z "$result" ] && zaf_err "Mapid $1 not found"
	if [ -z "$2" ]; then
		echo $result
	else
		echo $result |zaf_zbxapi_getvalues $2
	fi
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


