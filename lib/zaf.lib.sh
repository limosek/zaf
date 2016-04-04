
# Hardcoded variables
ZAF_VERSION="trunk"
ZAF_URL="https://raw.githubusercontent.com/limosek/zaf/master/"

############################################ Common routines

zaf_msg() {
	echo $@
}
zaf_dbg() {
	[ "$ZAF_DEBUG" -ge "2" ] && logger -s -t zaf -- $@
}
zaf_wrn() {
	[ "$ZAF_DEBUG" -ge "1" ] && logger -s -t zaf -- $@
}
zaf_err() {
	logger -s -t zaf -- $@
        logger -s -t zaf "Exiting with error!"
        exit 1
}

zaf_version(){
	echo $ZAF_VERSION
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
		zaf_dbg curl $insecure -f -s -L -o - $1
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
zaf_discovery_begin(){
cat <<EOF
{
 "data":[
EOF
}

# Add row(s) to discovery data
zaf_discovery_add_row(){
  local rows
  local row

  rows=$1
  row=$2
  shift;shift
  echo " {"
  while [ -n "$1" ]; do
    echo -n '  "'$1'":"'$2'" '
    shift;shift
    if [ -n "$1" ]; then
	echo ","
    else
	echo ""
    fi
  done
  if [ "$row" -lt "$rows" ]; then
  	echo " },"
  else
	echo " }"
  fi
}

# Dumps json object
zaf_discovery_end(){
cat <<EOF
 ]
}
EOF
}

# Read standard input as discovery data. Columns are divided by space.
# Arguments are name of variables to discovery.
# Dumps json to stdout
zaf_discovery(){
  local tmpfile
  local rows
  local a b c d e f g h i j row

  tmpfile="${ZAF_TMP_DIR}/disc$$"
  cat >$tmpfile
  rows=$(wc -l <$tmpfile)
  local a b c d e f g h i j;
  zaf_discovery_begin
  row=1
  while read a b c d e f g h i j; do
    zaf_discovery_add_row "$rows" "$row" "$1" "${1:+${a}}" "$2" "${2:+${b}}" "$3" "${3:+${c}}" "$4" "${4:+${d}}" "$5" "${5:+${e}}" "$6" "${6:+${f}}" "$7" "${7:+${g}}" "$8" "${8:+${h}}" "$9" "${9:+${i}}"
    row=$(expr $row + 1)
  done <$tmpfile
  zaf_discovery_end
  rm -f $tmpfile
}

############################################ Zaf internal routines

# Restart zabbix agent
zaf_restart_agent() {
	zaf_wrn "Restarting agent (${ZAF_AGENT_RESTART})"
	${ZAF_AGENT_RESTART} || zaf_err "Cannot restart Zabbix agent (${ZAF_AGENT_RESTART})!"
}

# Check if zaf.version item is populated
zaf_check_agent_config() {
	zaf_restart_agent
	${ZAF_AGENT_BIN} -t zaf.version
}

# Update repo
zaf_update_repo() {
	[ "$ZAF_GIT" != 1 ] && { zaf_err "Git is not installed. Exiting."; }
	if [ -z "${ZAF_PLUGINS_GITURL}" ] || [ -z "${ZAF_REPO_DIR}" ]; then
		zaf_err "This system is not configured for git repository."
	else
		[ ! -d "${ZAF_REPO_DIR}" ] && git clone "${ZAF_PLUGINS_GITURL}" "${ZAF_REPO_DIR}"
		(cd ${ZAF_REPO_DIR} && git pull)
	fi
}

# Construct url from plugin name
# It can be http[s]://url
# /path (from file)
# name (to try from repo)
zaf_get_plugin_url() {
	local url
	if echo "$1" | grep -q '/'; then
		url="$1" 		# plugin with path - from directory
	else
		if echo "$1" | grep -q ^http; then
			url="$1"	# plugin with http[s] url 
		else
			if [ -d "${ZAF_REPO_DIR}/$1" ]; then
				url="${ZAF_REPO_DIR}/$1"
			else
				url="${ZAF_PLUGINS_URL}/$1";
			fi
		fi
	fi
	echo $url
}

# $1 - control
zaf_plugin_info() {
	local control="$1"

	plugin=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_option Plugin)
	pdescription=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_moption Description)
	pmaintainer=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_option Maintainer)
	pversion=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_option Version)
	purl=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_option Url)
	phome=$(zaf_ctrl_get_global_block <"${control}" | zaf_block_get_option Home)
	pitems=$(zaf_ctrl_get_items <"${control}")
	echo
	echo -n "Plugin '$plugin' "; [ -n "$pversion" ] && echo -n "version ${pversion}"; echo ":"
	echo "$pdescription"; echo
	[ -n "$pmaintainer" ] && echo "Maintainer: $pmaintainer"
	[ -n "$purl" ] && echo "Url: $purl"
	[ -n "$phome" ] && echo "Home: $phome"
	echo
	echo "Items: $pitems"
	echo
}

# Prepare plugin into dir 
# $1 is url, directory or plugin name (will be searched in default plugin dir). 
# $2 is directory to prepare. 
zaf_prepare_plugin() {
	local url
	local plugindir
	local control

	url=$(zaf_get_plugin_url "$1")/control.zaf
	plugindir="$2"
	control=${plugindir}/control.zaf
	zaf_install_dir "$plugindir"
	zaf_dbg "Fetching control file from $url ..."
	if zaf_fetch_url "$url" >"${control}"; then
		zaf_ctrl_check_deps "${control}"
	else
		zaf_err "Cannot fetch or write control file!"
	fi
}

zaf_install_plugin() {
	local url
	local plugin
	local plugindir
	local control

	if zaf_prepare_plugin "$1" "${ZAF_TMP_DIR}/plugin"; then
		url=$(zaf_get_plugin_url "$1")
                plugin=$(zaf_ctrl_get_global_block <"${ZAF_TMP_DIR}/plugin/control.zaf" | zaf_block_get_option Plugin)
		plugindir="${ZAF_PLUGINS_DIR}"/$plugin
		if zaf_prepare_plugin "$1" $plugindir; then
			control=${plugindir}/control.zaf
			[ "$ZAF_DEBUG" -gt 0 ] && zaf_plugin_info "${control}"
			zaf_ctrl_check_deps "${control}"
			zaf_ctrl_install "$url" "${control}" "${plugindir}"
			zaf_ctrl_generate_cfg "${control}" "${plugin}" \
			  | zaf_far '{PLUGINDIR}' "${plugindir}" >${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf
			zaf_dbg "Generated ${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf"
		else
			zaf_err "Cannot install plugin $plugin to $plugindir!"
		fi
        else
            	zaf_err "Cannot prepare plugin $1"
	fi
}

# List installed plugins
# $1 - plugin
zaf_list_plugins() {
	local cfile
	local plugin
	ls -1 ${ZAF_PLUGINS_DIR} | while read p; do
		zaf_is_plugin "$(basename $p)" && echo $p
	done
}

zaf_is_plugin() {
	[ -d "$ZAF_PLUGINS_DIR/$1" ] && [ -f "$ZAF_PLUGINS_DIR/$1/control.zaf" ] && return
	false
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
	local items
	local i
	local p
	local key

	if ! zaf_is_plugin "$1"; then
		zaf_err "Missing plugin name or plugin $1 unknown. ";
	fi
	plugindir="${ZAF_PLUGINS_DIR}/$1"
	cfile="$plugindir/control.zaf"
	items=$(zaf_ctrl_get_items <$cfile)
	for i in $items; do
		p=$(zaf_ctrl_get_item_option $cfile $i "Parameters")
		if [ -n "$p" ]; then
			key="$1.$i[]"
		else
			key="$1.$i"
		fi
		echo -n "$key "
	done
	echo
}

zaf_list_items() {
	for p in $(zaf_list_plugins); do
		echo $p: $(zaf_list_plugin_items $p)
	done
}

zaf_test_item() {
	$ZAF_AGENT_BIN -t "$1"
}

zaf_remove_plugin() {
	! [ -d ${ZAF_PLUGINS_DIR}/$1 ] && { zaf_err "Plugin $1 not installed!"; }
	zaf_wrn "Removing plugin $1"
	rm -rf ${ZAF_PLUGINS_DIR}/$1
	rm -f ${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf
}


