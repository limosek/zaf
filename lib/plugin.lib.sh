# Plugin related functions

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

	if [ "$(zaf_url_info $1)" = "path" ]; then
		url="$1"		# plugin with path - from directory
	else
		if [ "$(zaf_url_info $1)" = "url" ]; then
			url="$1"	# plugin with http[s] url 
		else
			if [ -n "${ZAF_REPO_URL}" ]; then
					url="${ZAF_REPO_URL}/$1" 
			else
					zaf_err "Cannot find plugin $1"
			fi
		fi
	fi
	echo $url
}

# $1 - control
zaf_plugin_info() {
	local control="$1"
	local items

	! [ -f "$control" ] && zaf_err "Control file $control not found."
	plugin=$(zaf_ctrl_get_global_option "${control}" Plugin)
	pdescription=$(zaf_ctrl_get_global_option "${control}" Description)
	pmaintainer=$(zaf_ctrl_get_global_option "${control}" Maintainer)
	pversion=$(zaf_ctrl_get_global_option "${control}" Version)
	purl=$(zaf_ctrl_get_global_option "${control}" Url)
	phome=$(zaf_ctrl_get_global_option "${control}" Home)
	pitems=$(zaf_ctrl_get_items <"${control}")
	peitems=$(zaf_ctrl_get_extitems <"${control}")
	params=$(zaf_ctrl_get_global_option "${control}" Parameters)
	echo
	echo -n "Plugin '$plugin' "; [ -n "$pversion" ] && echo -n "version ${pversion}"; echo ":"
	echo "$pdescription"; echo
	[ -n "$pmaintainer" ] && echo "Maintainer: $pmaintainer"
	[ -n "$purl" ] && echo "Url: $purl"
	[ -n "$phome" ] && echo "Home: $phome"
	echo 
	if zaf_is_plugin "$(basename $plugin)"; then
		items=$(zaf_list_plugin_items $plugin)
		if [ -n "$params" ]; then
			printf "%b" "Plugin parameters: (name,default,actual value)\n"
			zaf_ctrl_get_global_option "${control}" Parameters | while read param default ; do
				printf "%b" "$param\t$default\t$(zaf_get_plugin_parameter $(dirname $1) $param)\n"
			done
			echo;
		fi 
		[ -n "$items" ] && { echo -n "Defined items: "; echo $items; }
		items=$(zaf_list_plugin_items $plugin test)
		[ -n "$items" ] && { echo -n "Test items: "; echo $items; }
		items=$(zaf_list_plugin_items $plugin precache)
		[ -n "$items" ] && { echo -n "Precache items: "; echo $items; }
		[ -n "$peitems" ] && { echo -n "External check items: "; echo $peitems; }
		
	else
		echo "Items: $pitems"
	fi
	echo
}

# Get global plugin parameters
# $1 plugin
zaf_get_plugin_parameters() {
	zaf_ctrl_get_global_option "${ZAF_PLUGINS_DIR}/${p}/control.zaf" "Parameters" | while read param rest; do echo $param; done
}

# Set plugin global parameter
# $1 plugindir
# $2 parameter
# $3 value
zaf_set_plugin_parameter() {
	printf "%s" "$3" >"${INSTALL_PREFIX}/${1}/${2}.value"
}

# Get plugin global parameter
# $1 plugindir
# $2 parameter
zaf_get_plugin_parameter() {
	[ -f "${1}/${2}.value" ] && cat "${1}/${2}.value"
}

# Prepare plugin into dir 
# $1 is url, directory or plugin name (will be searched in default plugin dir). 
# $2 is directory to prepare. 
zaf_prepare_plugin() {
	local url
	local plugindir
	local control
	local pluginname

	url=$(zaf_get_plugin_url "$1")/control.zaf || exit $?
	plugindir="$2"
	control=${plugindir}/control.zaf
	if [ "$(zaf_url_info $1)" = "path" ] &&  [ "$url" = "$control" ]; then
		zaf_err "prepare_plugin: Cannot install from itself ($url,$control)!"
	fi
	zaf_install_dir "$plugindir"
	zaf_dbg "Fetching control file from $url ..."
	if zaf_fetch_url "$url" >"${INSTALL_PREFIX}/${control}" && [ -s "${INSTALL_PREFIX}/${control}" ]; then
		[ -z "${INSTALL_PREFIX}" ] && zaf_ctrl_check_deps "${control}"
		pluginname=$(zaf_ctrl_get_global_block <"${INSTALL_PREFIX}/${control}" | zaf_block_get_option Plugin)
		[ "$(basename $plugindir)" != "$pluginname" ] && zaf_err "prepare_plugin: Plugin name mismach ($plugindir vs ${INSTALL_PREFIX}/${control})!"
		true
	else
		rm -rf "$plugindir"
		zaf_err "prepare_plugin: Cannot fetch or write control file ${INSTALL_PREFIX}/$control from url $url!"
	fi
}

zaf_install_plugin() {
	local url
	local plugin
	local plugindir
	local tmpplugindir
	local control
	local version
	local eparam
	local param
	local default

	plugin=$(basename "$1")
	plugindir="${ZAF_PLUGINS_DIR}/${plugin}"
	if [ -n "$plugin" ] && zaf_prepare_plugin "$1" $plugindir; then
		url=$(zaf_get_plugin_url "$1")
		zaf_wrn "Installing plugin $plugin"
		zaf_dbg "Source url: $url, Destination dir: $plugindir"
		control=${plugindir}/control.zaf
		[ "$ZAF_DEBUG" -gt 1 ] && zaf_plugin_info "${control}"
		if [ -z "${INSTALL_PREFIX}" ]; then
			zaf_ctrl_check_deps "${control}"
			zaf_ctrl_sudo "$plugin" "${control}" "${plugindir}"
			zaf_ctrl_cron "$plugin" "${control}" "${plugindir}"
			zaf_ctrl_generate_items_cfg "${control}" "${plugin}" \
				| zaf_far '{PLUGINDIR}' "${plugindir}" >${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf
			zaf_dbg "Generated ${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf"
			zaf_ctrl_generate_extitems_cfg "${control}" "${plugin}"
		else
			zaf_touch "${plugindir}/postinst.need"
		fi
		zaf_ctrl_install "$url" "${control}" "${plugindir}"
		rm -f "${plugindir}/params"
		zaf_touch "${plugindir}/params"
		(zaf_ctrl_get_global_option "${control}" "Parameters"; echo) | \
			while read param default; do
				[ -z "$param" ] && continue
				echo $param >>"${plugindir}/params"
				eval eparam=\$ZAF_${plugin}_${param}
				if [ -z "$eparam" ] && ! zaf_get_plugin_parameter "$plugindir" "$param" >/dev/null; then
					zaf_wrn "Do not forget to set parameter $param. Use zaf plugin-set $plugin $param value. Default is $default."
					zaf_set_plugin_parameter "$plugindir" "$param" "$default"
				else
					if [ -n "$eparam" ]; then
						zaf_dbg "Setting $param to $eparam from env."
						zaf_set_plugin_parameter "$plugindir" "$param" "$eparam"
					fi
				fi
			done

	else
		zaf_err "Cannot install plugin '$plugin' to $plugindir!"
	fi
}

zaf_postinstall_plugin() {
	local url
	local plugin
	local plugindir
	local tmpplugindir
	local control
	local version

	plugin=$(basename "$1")
	plugindir="${ZAF_PLUGINS_DIR}/${plugin}"
	control=${plugindir}/control.zaf
	[ "$ZAF_DEBUG" -gt 1 ] && zaf_plugin_info "${control}"
	zaf_ctrl_check_deps "${control}"
	zaf_ctrl_sudo "$plugin" "${control}" "${plugindir}"
	zaf_ctrl_cron "$plugin" "${control}" "${plugindir}"
	zaf_ctrl_generate_items_cfg "${control}" "${plugin}" \
		| zaf_far '{PLUGINDIR}' "${plugindir}" >${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf
	zaf_dbg "Generated ${ZAF_AGENT_CONFIGD}/zaf_${plugin}.conf"
	zaf_ctrl_generate_extitems_cfg "${control}" "${plugin}"
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

zaf_is_item() {
	local plugin
	local item

	plugin=$(echo $1|cut -d '.' -f 1)
	item=$(echo $1|cut -d '.' -f 2)
	[ -z "$plugin" ] || [ -z "$item" ] && return 1
	zaf_is_plugin "$plugin" && zaf_list_plugin_items "$plugin" | grep -qE "\.(${item}\$|${item}\[)"
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
		case $2 in
		test)
			for tp in $testparms; do
				if [ -n "$p" ]; then
					echo -n "$1.$i[$tp] "
				else
					echo -n "$1.$i "
				fi
			done
			;;
		precache)
			for tp in $precache; do
				echo -n "$1.$i[$tp] "
			done
			;;
		*)
			if [ -n "$p" ]; then
				echo -n "$1.$i[] "
			else
				echo -n "$1.$i "
			fi
			;;
		esac
	done
	echo
}

zaf_item_info() {
	local plugin
	local item
	local param
	local tmp

	plugin=$(echo $1 | cut -d '.' -f 1)
	item=$(echo $1 | cut -d '.' -f 2-)
	if zaf_is_plugin $plugin; then
		if zaf_ctrl_get_items <$ZAF_PLUGINS_DIR/$plugin/control.zaf | grep -wq "$item"; then
			printf "%b" "Item $1\n\n"
			tmp=$(zaf_ctrl_get_item_option $ZAF_PLUGINS_DIR/$plugin/control.zaf "$item" "Cache")
			[ -n "$tmp" ] && printf "%b" "Cache: $tmp \n\n"
			tmp=$(zaf_ctrl_get_item_option $ZAF_PLUGINS_DIR/$plugin/control.zaf "$item" "Parameters")
			[ -n "$tmp" ] && printf "%b" "Parameters:\n$tmp\n\n"
			tmp=$(zaf_ctrl_get_item_option $ZAF_PLUGINS_DIR/$plugin/control.zaf "$item" "Return")
			[ -n "$tmp" ] && printf "%b" "Return: $tmp\n\n"
			tmp=$(zaf_ctrl_get_item_option $ZAF_PLUGINS_DIR/$plugin/control.zaf "$item" "Return-null")
			[ -n "$tmp" ] && printf "%b" "Return-null: $tmp\n\n"
			tmp=$(zaf_ctrl_get_item_option $ZAF_PLUGINS_DIR/$plugin/control.zaf "$item" "Return-empty")
			[ -n "$tmp" ] && printf "%b" "Return-empty: $tmp\n\n"
			tmp=$(zaf_ctrl_get_item_option $ZAF_PLUGINS_DIR/$plugin/control.zaf "$item" "Testparameters")
			[ -n "$tmp" ] && printf "%b" "Testparameters: $tmp\n\n"
			tmp=$(zaf_ctrl_get_item_option $ZAF_PLUGINS_DIR/$plugin/control.zaf "$item" "Precache")
			[ -n "$tmp" ] && printf "%b" "Precache: $tmp\n\n"
			grep "UserParameter=$1" $ZAF_AGENT_CONFIGD/zaf_${plugin}.conf
		else
			zaf_err "No such item $item."
		fi	
	else
		zaf_err "No such plugin $plugin."
	fi
}

zaf_list_items() {
	for p in $(zaf_list_plugins); do
		echo $p: $(zaf_list_plugin_items $p)
	done
}

zaf_get_item() {
	if which zabbix_get >/dev/null; then
		zaf_trc zabbix_get -s localhost -k "'$1'"
		(zabbix_get -s localhost -k "$1" | tr '\n' ' '; echo) || zaf_wrn "Cannot reach agent on localhost. Please localhost to Server list."
		return 11
	else
		zaf_wrn "Please install zabbix_get binary to check items over network."
		return 11
	fi
}

zaf_test_item() {
	zaf_trc $ZAF_AGENT_BIN -t "'$1'"
	if $ZAF_AGENT_BIN -t "$1" | grep ZBX_NOTSUPPORTED; then
		return 1
	else
		$ZAF_AGENT_BIN -t "$1" | tr '\n' ' '
		echo
	fi
}

zaf_precache_item() {
	cmd=$(grep "^UserParameter=$item" $ZAF_AGENT_CONFIGD/zaf*.conf	| cut -d ',' -f 2- | sed -e "s/_cache/_nocache/")
	zaf_wrn "Precaching item $item[$(echo $*| tr ' ' ',')] ($cmd)"
	eval $cmd
}

zaf_remove_plugin() {
	! zaf_is_plugin $1 && { zaf_err "Plugin $1 not installed!"; }
	zaf_wrn "Removing plugin $1 (version $(zaf_plugin_version $1))"
	rm -rf ${ZAF_PLUGINS_DIR}/$1
	rm -f ${ZAF_AGENT_CONFIGD}/zaf_$1.conf ${ZAF_CROND}/zaf_$1 ${ZAF_SUDOERSD}/zaf_$1
}

