
############################################ Init part
# Get all config variables and initialise TMP

! [ -f /etc/zaf.conf ] && { echo "Config file /etc/zaf.conf does not exists! Exiting."; exit 2; }
. /etc/zaf.conf
. ${ZAF_LIB_DIR}/jshn.sh
ZAF_TMP_DIR="${ZAF_TMP_BASE}-${USER}-$$"
trap "rm -rif ${ZAF_TMP_DIR}" EXIT
! [ -d "${ZAF_TMP_DIR}" ] && mkdir "${ZAF_TMP_DIR}"

############################################ Common routines

zaf_msg() {
	[ "$ZAF_DEBUG" = "1" ] && echo $@
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
		curl $insecure -f -s -L -o - "$1";
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
	${ZAF_AGENT_RESTART}
}

# Check if zaf.version item is populated
zaf_check_agent_config() {
	zaf_restart_agent
	zabbix_agentd -t zaf.version
}

# Update repo
zaf_update_repo() {
	[ "$ZAF_GIT" != 1 ] && { echo "Git is not installed."; return 1; }
	! [ -d ${ZAF_REPO_DIR} ] &&  git clone "${ZAF_PLUGINS_REPO}" "${ZAF_REPO_DIR}"
	[ -n "${ZAF_PLUGINS_REPO}" ] && cd ${ZAF_REPO_DIR} && git pull
}

# Check plugin url
# $1 plugin uri
# $2 local file to fetch
zaf_plugin_fetch_control() {
	[ -z "$1" ] && return -1
	local name=$(basename "$1")
	zaf_fetch_url "$1/control" >"$2"
}

# Get option from control file
# $1 control file
# $2 option
zaf_ctrl_get_option() {
	awk 'BEGIN { FS=": "; }; /^'$2': / { printf $2$3$4$5"\n"; }' <$1
}

# Get description from control file
# $1 control file
# $2 option
zaf_ctrl_get_description() {
	awk \
	"/^$2/"' { i=1;
     		while (1) {
        		getline; if (substr($0,0,1) != " ") exit;
        		printf $0"\n";
      		}
     	}' <$1
}

zaf_ctrl_binary_deps() {
	local deps
	deps=$(zaf_ctrl_get_option "$1" Binary-Depends)
	for cmd in $deps; do
		if ! which $cmd >/dev/null; then
			echo "Missing binary dependency $cmd. Please install it first."
			exit 5
		fi
	done
}

zaf_ctrl_install_bin() {
	local binaries
	local pdir
	binaries=$(zaf_ctrl_get_option "$1" Install-bin)
	pdir="${ZAF_PLUGINS_DIR}/${2}/"
	for b in $binaries; do
		zaf_fetch_url "$url/$b" >"$pdir/$b"
		chmod +x "$pdir/$b"
	done
}

# Generates zabbix cfg from control file
# $1 control
# $2 pluginname
zaf_ctrl_generate_cfg() {
	local items
	local cmd
	local ilock

	items=$(zaf_ctrl_get_option "$1" Item)
	for i in $items; do
		ilock=$(echo $i | tr -d '[]*&;:')
		cmd=$(zaf_ctrl_get_option "$1" "Item-cmd-$i")
		echo "UserParameter=$2.${i},$cmd"
	done
}

# Install plugin. 
# Parameter is url, directory or plugin name (will be searched in default plugin dir)
zaf_install_plugin() {
	local url
	local control
	local plugin
	local plugindir

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
	plugin="plug$$"
	rm -rf ${ZAF_TMP_DIR}/${plugin}
	control=${ZAF_TMP_DIR}/${plugin}/control
	mkdir -p "${ZAF_TMP_DIR}/${plugin}"
	if zaf_plugin_fetch_control "$url" "${control}"; then
		set -e
		plugin=$(zaf_ctrl_get_option "${control}" Plugin)
		if [ -n "$plugin" ]; then
			echo Installing plugin $plugin from $url...
			plugindir="${ZAF_PLUGINS_DIR}/${plugin}"
			zaf_ctrl_binary_deps "${control}"
			mkdir -p $plugindir
			zaf_ctrl_install_bin "${control}" "${plugin}" 
			zaf_ctrl_generate_cfg "${control}" "${plugin}" | \
				zaf_far '{PLUGINDIR}' "$plugindir" | \
				zaf_far '{ZAFLIB}' ". ${ZAF_LIB_DIR}/zaf.lib.sh; . " | \
				zaf_far '{ZAFFUNC}' ". ${ZAF_LIB_DIR}/zaf.lib.sh; " | \
				zaf_far '{ZAFLOCK}' "${ZAF_LIB_DIR}/zaflock '$plugin' " \
				>${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf
			zaf_restart_agent
			cp $control "$plugindir"/
			zaf_fetch_url $url/template.xml >"$plugindir"/template.xml
		else
			echo "Bad control file $control ($url)!"
			cat $control
			exit 4
		fi
	else
		echo "Cannot fetch control file!"
		exit 4
	fi
}

# Show installed plugins (human readable)
# $1 - plugin
zaf_show_installed_plugins() {
	local cfile
	local plugin
	cd ${ZAF_PLUGINS_DIR}; ls --hide '.' -1 | while read plugin; do
		cfile=${ZAF_PLUGINS_DIR}/$plugin/control
		echo Plugin $plugin:
		zaf_ctrl_get_description $cfile Plugin:
		echo "Homepage:" $(zaf_ctrl_get_option $cfile Web)
		echo "Maintainer:" $(zaf_ctrl_get_option $cfile Maintainer)
		echo
	done
}

# List installed plugins
# $1 - plugin
zaf_list_plugins() {
	local cfile
	local plugin
	cd ${ZAF_PLUGINS_DIR}; ls -1 
}

zaf_show_plugin() {
	local items
	local plugindir
	local cfile
	local tst

	if [ -z "$1" ]; then
		echo "Missing plugin name";
		exit 1
	fi
	[ -n "$2" ] && tst=1
	plugindir="${ZAF_PLUGINS_DIR}/$1"
	cfile="$plugindir/control"
	if [ -d "$plugindir" ] ; then
		echo "Plugin $1:"
		zaf_ctrl_get_description "$cfile" "Plugin:"
		echo "Homepage:" $(zaf_ctrl_get_option $cfile Web)
		echo "Maintainer:" $(zaf_ctrl_get_option $cfile Maintainer)	
		items=$(zaf_list_plugin_items $1)
		echo 
		echo "Supported items:"
		for i in $items; do
			if [ -n "$tst" ]; then
			  ${ZAF_AGENT_BIN} -t "$1.$i"
			else
			  echo -n "$1.$i: "
			fi
			echo
			zaf_ctrl_get_description "$cfile" "Item: $i";
			echo
		done
	else
		echo "Plugin $1 not installed" 
	fi
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


