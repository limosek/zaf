
# Fetch url to stdout 
# $1 url
# It supports real file, file:// and other schemes known by curl
zaf_fetch_url() {
	local scheme
	local uri
	
	scheme=$(echo $1|cut -d ':' -f 1)
	uri=$(echo $1|cut -d '/' -f 3-)
	if [ "$1" = "$scheme" ]; then
		cat "$1"
	fi
	case $scheme in
	http|https|ftp|file)
		curl -f -s -L -o - "$1";
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
	[ -n "${ZAF_PLUGINS_REPO}" ] && cd ${ZAF_REPO_DIR} && git pull
}

# List installed plugins
zaf_list_installed_plugins() {
	cd ${ZAF_PLUGINS_DIR}; ls --hide '.'
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
	grep -E '^(.*): ' "$1" | grep -F "$2:" | cut -d ' ' -f 2-
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
	items=$(zaf_ctrl_get_option "$1" Item)
	for i in $items; do
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

	if echo "$1" | grep -qv '/'; then
		url="${ZAF_REPO_DIR}/$1"
	else
		url="$1"
	fi
	plugin=$(basename "$url")
	echo Installing plugin $plugin from $url...
	rm -rf ${ZAF_TMP_DIR}/${plugin}
	control=${ZAF_TMP_DIR}/${plugin}/control
	plugindir="${ZAF_PLUGINS_DIR}/${plugin}"
	mkdir -p "${ZAF_TMP_DIR}/${plugin}"
	if zaf_plugin_fetch_control "$url" "${control}"; then
		set -e
		zaf_ctrl_binary_deps "${control}"
		mkdir -p $plugindir
		zaf_ctrl_install_bin "${control}" "${plugin}" 
		zaf_ctrl_generate_cfg "${control}" "${plugin}" | zaf_far '{PLUGINDIR}' "$plugindir" >${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf
		zaf_restart_agent
		cp $control "$plugindir"/
		zaf_fetch_url $url/template.xml >"$plugindir"/template.xml
	else
		echo "Cannot fetch control file!"
		exit 4
	fi
}

zaf_plugin_info() {
	local items
	local plugindir

	plugindir="${ZAF_PLUGINS_DIR}/$1"
	if [ -d "$plugindir" ]; then
		items=$(zaf_ctrl_get_option "$plugindir/control" Item)
		echo "Items supported:"
		echo "$items"
	else
		echo "Plugin $1 not installed" 
	fi
}

zaf_remove_plugin() {
	rm -rf ${ZAF_PLUGINS_DIR}/$1
	rm -f ${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf
}



