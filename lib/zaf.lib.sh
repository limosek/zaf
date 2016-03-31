
############################################ Common routines

zaf_msg() {
	echo $@
}
zaf_dbg() {
	[ "$ZAF_DEBUG" -ge "3" ] && logger -s -t zaf $@
}
zaf_wrn() {
	[ "$ZAF_DEBUG" -ge "2" ] && logger -s -t zaf $@
}
zaf_err() {
	logger -s -t zaf $@
        logger -s -t zaf "Exiting with error!"
        exit 1
}

# Fetch url to stdout 
# $1 url
# It supports real file, file:// and other schemes known by curl
zaf_fetch_url() {
	local scheme
	local uri
	local insecure
	
	scheme=$(echo $1|cut -d ':' -f 1)
	uri=$(echo $1|cut -d '/' -f 3-)
	if [ "$1" = "$scheme" ]; then
		cat "$1"
	fi
	case $scheme in
	http|https|ftp|file)
		[ "${ZAF_CURL_INSECURE}" = "1" ] && insecure="-k"
		zaf_msg curl $insecure -f -s -L -o - "$1"
		curl $insecure -f -s -L -o - "$1"
	;;
	esac 
}

# Find and replace string
zaf_far(){
   local f
   local t
        local sedcmd="sed"
        i=1
        while [ "$i" -lt "$#" ];
        do
                eval f=\$${i}
                i=$(expr $i + 1)
                eval t=\$${i}
                i=$(expr $i + 1)
                sedcmd="$sedcmd -e 's~$f~$t~g'"
        done
   eval $sedcmd
}

# Initialises discovery function
zaf_discovery_init(){
  json_init
  json_add_array data
}

# Add row(s) to discovery data
zaf_discovery_add_row(){
  json_add_object "obj"
  while [ -n "$1" ]; do
    json_add_string "$1" "$2"
    shift
    shift
  done
  json_close_object
}

# Dumps json object
zaf_discovery_dump(){
 json_close_array
 json_dump
}

# Read standard input as discovery data. Columns are divided by space.
# Arguments are name of variables to discovery.
# Dumps json to stdout
zaf_discovery(){
  local a b c d e f g h i j;
  zaf_discovery_init
  while read a b c d e f g h i j; do
    zaf_discovery_add_row "$1" "${1:+${a}}" "$2" "${2:+${b}}" "$3" "${3:+${c}}" "$4" "${4:+${d}}" "$5" "${5:+${e}}" "$6" "${6:+${f}}" "$7" "${7:+${g}}" "$8" "${8:+${h}}" "$9" "${9:+${i}}"
  done
  zaf_discovery_dump
}

############################################ Zaf internal routines

zaf_version() {
	echo master
}

# Restart zabbix agent
zaf_restart_agent() {
	${ZAF_AGENT_RESTART} || zaf_err "Cannot restart Zabbix agent (${ZAF_AGENT_RESTART})!"
}

# Check if zaf.version item is populated
zaf_check_agent_config() {
	zaf_restart_agent
	${ZAF_AGENT_BIN} -t zaf.version
}

# Update repo
zaf_update_repo() {
	[ "$ZAF_GIT" != 1 ] && { echo "Git is not installed."; return 1; }
	! [ -d ${ZAF_REPO_DIR} ] &&  git clone "${ZAF_PLUGINS_REPO}" "${ZAF_REPO_DIR}"
	[ -n "${ZAF_PLUGINS_REPO}" ] && cd ${ZAF_REPO_DIR} && git pull
}

# Construct url from plugin name
# It can be http[s]://url
# /path (from file)
# name (to try from repo)
zaf_get_plugin_url() {
	local url
	if echo "$1" | grep -q '/'; then
		url="$1" 		# plugin with path - installing from directory
	else
		if echo "$1" | grep -q ^http; then
			url="$1"	# plugin with http[s] url 
		else
			if [ -d "${ZAF_REPO_DIR}/$1" ]; then
				url="${ZAF_REPO_DIR}/$1"
			else
				url="${ZAF_PLUGINS_REPO}/$1";
			fi
		fi
	fi
	echo $url
}

# $1 - control
# $2 - if nonempty, show informarions instead of setting env
zaf_plugin_info() {
	local control="$1"

	plugin=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_option Plugin)
	pdescription=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_moption Description)
	pmaintainer=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_option Maintainer)
	pversion=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_option Version)
	purl=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_option Url)
	phome=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_option Home)
	pitems=$(zaf_ctrl_get_items <"${control}")
	[ -z "$2" ] && return
	echo
	echo -n "Plugin $plugin "; [ -n "$version" ] && echo -n "version ${pversion}"; echo ":"
	echo "$pdescription"; echo
	[ -n "$pmaintainer" ] && echo "Maintainer: $pmaintainer"
	[ -n "$purl" ] && echo "Url: $purl"
	[ -n "$phome" ] && echo "Home: $phome"
	echo
	echo "Items: $pitems"
	echo
}

# Prepare plugin into tmp dir 
# $1 is url, directory or plugin name (will be searched in default plugin dir). 
# $2 is directory to prepare. 
# $3 plugin name 
zaf_prepare_plugin() {
	url=$(zaf_get_plugin_url "$1")/control.zaf
	plugindir="$2"
	control=${plugindir}/control.zaf
	zaf_dbg "Fetching control file from $url ..."
	if zaf_fetch_url "$url" >"${control}"; then
		zaf_plugin_info "${control}"
		zaf_ctrl_check_deps "${control}"
	else
		zaf_err "Cannot fetch or write control file!"
	fi
}

zaf_install_plugin() {
	mkdir "${ZAF_TMP_DIR}/plugin"
	if zaf_prepare_plugin "$1" "${ZAF_TMP_DIR}/plugin"; then
                plugin=$(zaf_ctrl_get_global_block <"${ZAF_TMP_DIR}/plugin/control.zaf" | zaf_block_get_option Plugin)
		plugindir="${ZAF_PLUGINS_DIR}"/$plugin
		if zaf_prepare_plugin "$1" $plugindir; then
			zaf_ctrl_check_deps "${control}"
			zaf_ctrl_install "${control}" "${plugin}" 
			zaf_ctrl_generate_cfg "${control}" "${plugin}" 
			exit;
	#| \
				zaf_far '{PLUGINDIR}' "$plugindir" | \
				zaf_far '{ZAFLIBDIR}' "${ZAF_LIB_DIR}" | \
				zaf_far '{ZAFLOCK}' "${ZAF_LIB_DIR}/zaflock '$plugin' " \
				>$plugindir/zabbix.conf
		else
			zaf_err "Cannot install plugin $plugin to $plugindir!"
		fi
        else
            return 1
	fi

}

# List installed plugins
# $1 - plugin
zaf_list_plugins() {
	local cfile
	local plugin
	cd ${ZAF_PLUGINS_DIR}; ls -1 
}

zaf_discovery_plugins() {
	zaf_list_plugins | zaf_discovery '{#PLUGIN}'
}

zaf_plugin_version() {
	if [ -z "$1" ]; then
		echo "Missing plugin name";
		exit 1
	fi
	plugindir="${ZAF_PLUGINS_DIR}/$1"
	cfile="$plugindir/control"
	if [ -d "$plugindir" ] ; then
		zaf_ctrl_get_option "$cfile" Version
	else
		echo "Plugin $1 not installed" 
	fi
}

zaf_list_plugin_items() {
	if [ -z "$1" ]; then
		echo "Missing plugin name";
		exit 1
	fi
	plugindir="${ZAF_PLUGINS_DIR}/$1"
	cfile="$plugindir/control"
	if [ -d "$plugindir" ] ; then
		zaf_ctrl_get_option "$cfile" Item
	else
		echo "Plugin $1 not installed" 
	fi
}

zaf_list_items() {
	for p in $(zaf_list_plugins); do
		zaf_list_plugin_items $p
	done
}

zaf_remove_plugin() {
	! [ -d ${ZAF_PLUGINS_DIR}/$1 ] && { echo "Plugin $1 not installed!"; exit 2; }
	rm -rf ${ZAF_PLUGINS_DIR}/$1
	rm -f ${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf
}


