
# Hardcoded variables
ZAF_VERSION="1.2"
ZAF_GITBRANCH="master"
ZAF_URL="https://github.com/limosek/zaf"
ZAF_RAW_URL="https://raw.githubusercontent.com/limosek/zaf"

############################################ Common routines

zaf_msg() {
	echo $@
}
zaf_trc() {
	[ "$ZAF_DEBUG" -ge "3" ] && logger -s -t zaf -- $@
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
	local out
	
	if zaf_fromcache "$1"; then
		return
	fi
	scheme=$(echo $1|cut -d ':' -f 1)
	uri=$(echo $1|cut -d '/' -f 3-)
	if [ "$1" = "$scheme" ]; then
		cat "$1"
	fi
	case $scheme in
	http|https|ftp|file)
		[ "$scheme" != "file" ] && [ -n "$ZAF_OFFLINE" ] && zaf_err "Cannot download $1 in offline mode!"
		[ "${ZAF_CURL_INSECURE}" = "1" ] && insecure="-k"
		zaf_dbg curl $insecure -f -s -L -o - $1
		curl $insecure -f -s -L -o - "$1" | zaf_tocache_stdin "$1" 120
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

# Limit concurrent processes or continue
zaf_bglimit(){
    local maxbg
    local maxnumber
    local cnumber
    [ -z "$BASH_VERSION" ] && { zaf_dbg "Job server not available. Use bash!"; return 1; }
    if [ $# -eq 0 ] ; then
            maxbg=5
    else
	    maxbg=$1
    fi
    maxnumber=$((0 + ${1:-0}))
    while true; do
            cnumber=$(jobs | wc -l)
            if [ $cnumber -lt $maxnumber ]; then
                    break
            fi
	    zaf_dbg "Limiting next job due to $maxbg limit of bg jobs"
            sleep 1
    done
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
	${ZAF_AGENT_RESTART} || zaf_err "Cannot restart Zabbix agent (${ZAF_AGENT_RESTART}). Try $ZAF_AGENT_BIN -f !";
}

# Check if zaf.version item is populated
zaf_check_agent_config() {
	zaf_restart_agent
	${ZAF_AGENT_BIN} -t zaf.version
}

# Update repo
zaf_update_repo() {
	[ "$ZAF_GIT" != 1 ] && { zaf_err "Git is disabled or is not installed. Exiting."; }
	if [ -z "${ZAF_REPO_GITURL}" ] || [ -z "${ZAF_REPO_DIR}" ]; then
		zaf_err "This system is not configured for git repository."
	else
		[ ! -d "${ZAF_REPO_DIR}" ] && git clone "${ZAF_REPO_GITURL}" "${ZAF_REPO_DIR}"
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
				if [ -n "${ZAF_PREPACKAGED_DIR}" ] &&  [ -d "${ZAF_PREPACKAGED_DIR}/$1" ]; then
					url="${ZAF_PREPACKAGED_DIR}/$1"
				else
					if [ -n "${ZAF_REPO_URL}" ]; then
						url="${ZAF_REPO_URL}/$1" 
					else
						zaf_err "Cannot find plugin $1"
					fi
				fi
			fi
		fi
	fi
	echo $url
}

# $1 - control
zaf_plugin_info() {
	local control="$1"

	! [ -f "$control" ] && zaf_err "Control file $control not found."
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
	if zaf_is_plugin "$(basename $plugin)"; then
		echo -n "Defined items: "; zaf_list_plugin_items $plugin
		echo -n "Test items: "; zaf_list_plugin_items $plugin test
		echo -n "Precache items: "; zaf_list_plugin_items $plugin precache
	else
		echo "Items: $pitems"
	fi
	echo
}

# Prepare plugin into dir 
# $1 is url, directory or plugin name (will be searched in default plugin dir). 
# $2 is directory to prepare. 
zaf_prepare_plugin() {
	local url
	local plugindir
	local control

	url=$(zaf_get_plugin_url "$1")/control.zaf || exit $?
	plugindir="$2"
	control=${plugindir}/control.zaf
	zaf_install_dir "$plugindir"
	zaf_dbg "Fetching control file from $url ..."
	if zaf_fetch_url "$url" >"${control}"; then
		zaf_ctrl_check_deps "${control}"
	else
		zaf_err "prepare_plugin: Cannot fetch or write control file $control from url $url!"
	fi
}

zaf_install_plugin() {
	local url
	local plugin
	local plugindir
	local control
	local version

	if zaf_prepare_plugin "$1" "${ZAF_TMP_DIR}/plugin"; then
		url=$(zaf_get_plugin_url "$1")
		control="${ZAF_TMP_DIR}/plugin/control.zaf"
                plugin=$(zaf_ctrl_get_global_option $control Plugin)
		version=$(zaf_ctrl_get_global_option $control Version)
		plugindir="${ZAF_PLUGINS_DIR}"/$plugin
		if [ -n "$plugin" ] && zaf_prepare_plugin "$1" $plugindir; then
			zaf_wrn "Installing plugin $plugin version $version"
			zaf_dbg "Source url: $url, Destination dir: $plugindir"
			control=${plugindir}/control.zaf
			[ "$ZAF_DEBUG" -gt 1 ] && zaf_plugin_info "${control}"
			zaf_ctrl_check_deps "${control}"
			zaf_ctrl_install "$url" "${control}" "${plugindir}"
			zaf_ctrl_sudo "$plugin" "${control}" "${plugindir}"
			zaf_ctrl_cron "$plugin" "${control}" "${plugindir}"
			zaf_ctrl_generate_cfg "${control}" "${plugin}" \
			  | zaf_far '{PLUGINDIR}' "${plugindir}" >${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf
			zaf_dbg "Generated ${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf"
		else
			zaf_err "Cannot install plugin '$plugin' to $plugindir!"
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

# $1 plugin
# $2 ctrl_option
zaf_plugin_option() {
	local plugindir
	local cfile

	if [ -z "$1" ]; then
		zaf_err "Missing plugin name.";
	fi
	if zaf_is_plugin "$1"; then
		plugindir="${ZAF_PLUGINS_DIR}/$1"
		cfile="$plugindir/control.zaf"
		zaf_ctrl_get_global_option $cfile $2
	else
		zaf_err "Plugin $1 not installed."
	fi
}

zaf_plugin_version() {
	zaf_plugin_option "$1" Version
}
zaf_plugin_maintainer() {
	zaf_plugin_option "$1" Maintainer
}
zaf_plugin_url() {
	zaf_plugin_option "$1" Url
}
zaf_plugin_web() {
	zaf_plugin_option "$1" Web
}
zaf_plugin_template_url() {
	echo $(zaf_plugin_option "$1" Url)/template.xml
}

# $1 plugin
# $2 test to get test items, precache to get items to precache
zaf_list_plugin_items() {
	local items
	local i
	local p
	local key
	local testparms
	local precache

	if ! zaf_is_plugin "$1"; then
		zaf_err "Missing plugin name or plugin $1 unknown. ";
	fi
	plugindir="${ZAF_PLUGINS_DIR}/$1"
	cfile="$plugindir/control.zaf"
	items=$(zaf_ctrl_get_items <$cfile)
	for i in $items; do
		p=$(zaf_ctrl_get_item_option $cfile $i "Parameters")
		testparms=$(zaf_ctrl_get_item_option $cfile $i "Testparameters")
		precache=$(zaf_ctrl_get_item_option $cfile $i "Precache")
		if [ -n "$p" ]; then
			if [ -n "$testparms" ] && [ "$2" = "test" ]; then
				for tp in $testparms; do
					echo -n "$1.$i[$tp] "
				done
			else
				if [ -n "$precache" ] && [ "$2" = "precache" ]; then
					for tp in $precache; do
						echo -n "$1.$i[$tp] "
					done
				fi
				[ "$2" != "test" ] && key="$1.$i[]"
			fi
		else
			key="$1.$i"
		fi
		[ "$2" != "precache" ] && echo -n "$key "
	done
	echo
}

zaf_list_items() {
	for p in $(zaf_list_plugins); do
		echo $p: $(zaf_list_plugin_items $p)
	done
}

zaf_get_item() {
	if which zabbix_get >/dev/null; then
		zabbix_get -s localhost -k "$1" || zaf_wrn "Cannot reach agent on localhost. Please localhost to Server list."
		return 11
	else
		zaf_wrn "Please install zabbix_get binary to check items over network."
		return 11
	fi
}

zaf_test_item() {
	$ZAF_AGENT_BIN -t "$1"
}

zaf_precache_item() {
	cmd=$(grep "^UserParameter=$item" $ZAF_AGENT_CONFIGD/zaf*.conf  | cut -d ',' -f 2- | sed -e "s/_cache/_nocache/")
	zaf_wrn "Precaching item $item[$(echo $*| tr ' ' ',')] ($cmd)"
	eval $cmd
}

zaf_remove_plugin() {
	! zaf_is_plugin $1 && { zaf_err "Plugin $1 not installed!"; }
	zaf_wrn "Removing plugin $1 (version $(zaf_plugin_version $1))"
	rm -rf ${ZAF_PLUGINS_DIR}/$1
	rm -f ${ZAF_AGENT_CONFIGD}/zaf_$1.conf ${ZAF_CROND}/zaf_$1 ${ZAF_SUDOERSD}/zaf_$1
}

zaf_tolower() {
	tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz'
}

zaf_toupper() {
	tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
}

# Return simplified key with discarded special chars.
zaf_stripctrl() {
	echo $1 | tr '[]*&;:.-' '________'
}

# Unescape string on stdin
# $1 - list of chars to unescape
zaf_strunescape() {
	 sed -e 's#\\\(['"$1"']\)#\1#g'
}


# Escape string on stdin
# $1 - list of chars to escape
zaf_strescape() {
	 sed -e 's#\(['"$1"']\)#\\\1#g'
}

