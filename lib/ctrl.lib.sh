# Control file related functions

# Get item list from control on stdin
zaf_ctrl_get_items() {
	grep '^Item ' | cut -d ' ' -f 2 | cut -d ':' -f 1 | tr '\r\n' ' '
}

# Get item body from stdin
# $1 itemname
zaf_ctrl_get_item_block() {
	grep -v '^#' | awk '/^Item '$1'/ { i=0;
	while (i==0) {
		getline;
		if (/^\/Item/) exit;
		print $0;
	}};
	END {
		exit i==0;
	}'
}

# Get global plugin block body from stdin
# $1 itemname
zaf_ctrl_get_global_block() {
	grep -v '^#' | awk '{ i=0;
	while (i==0) {
		getline;
		if (/^Item /) exit;
		print $0;
	}}'
}

# Get item multiline option
# $1 optionname
zaf_block_get_moption() {
	awk '/^'$1'::$/ { i=0;
	while (i==0) {
		getline;
		if (/^::$/) {i=1; continue;};
		print $0;
	}};
	END {
		exit i==0;
	}
	'
}

# Get item singleline option from config block on stdin
# $1 optionname
zaf_block_get_option() {
	grep "^$1:" | cut -d ' ' -f 2- | tr -d '\r\n'
}

# Get global option (single or multiline)
# $1 - control file
# $2 - option name
zaf_ctrl_get_global_option() {
	local ctrlvar
	local ctrlopt

	ctrlopt="ZAF_CTRL_$(zaf_stripctrl $2)"
	eval ctrlvar=\$$ctrlopt
	if [ -n "$ctrlvar" ]; then
		zaf_dbg "Overriding control field $2 from env $ctrlopt($ctrlvar)"
		echo $ctrlopt
	else
		zaf_ctrl_get_global_block <$1 | zaf_block_get_moption "$2" \
		|| zaf_ctrl_get_global_block <$1 | zaf_block_get_option "$2"
	fi
}
# Get item specific option (single or multiline)
# $1 - control file
# $2 - item name
# $3 - option name
zaf_ctrl_get_item_option() {
	local ctrlvar
	local ctrlopt

	ctrlopt="ZAF_CTRLI_$(zaf_stripctrl $2)_$(zaf_stripctrl $3)"
	eval ctrlvar=\$$ctrlopt
	if [ -n "$ctrlvar" ]; then
		zaf_dbg "Overriding item control field $2/$3 from env $ctrlopt($ctrlvar)"
		echo $ctrlopt
	else
		zaf_ctrl_get_item_block <$1 "$2" | zaf_block_get_moption "$3" \
		|| zaf_ctrl_get_item_block <$1 "$2" | zaf_block_get_option "$3"
	fi
}

# Check dependencies based on control file
zaf_ctrl_check_deps() {
	local deps
	deps=$(zaf_ctrl_get_global_block <$1 | zaf_block_get_option "Depends-${ZAF_PKG}" )
	if ! zaf_os_specific zaf_check_deps $deps; then
		zaf_err "Missing one of dependend system packages: $deps"
	fi
	deps=$(zaf_ctrl_get_global_block <$1 | zaf_block_get_option "Depends-bin" )
	for cmd in $deps; do
		if ! which $cmd >/dev/null; then
			zaf_err "Missing binary dependency $cmd. Please install it first."
		fi
	done
}

# Install sudo config from control
# $1 plugin
# $2 control
# $3 plugindir
zaf_ctrl_sudo() {
	local pdir
	local plugin
	local sudo
	local cmd
	local parms

	pdir="$3"
	plugin=$1
	zaf_dbg "Installing sudoers entry $ZAF_SUDOERSD/zaf_$plugin"
	sudo=$(zaf_ctrl_get_global_option $2 "Sudo" | zaf_far '{PLUGINDIR}' "${plugindir}")
	[ -z "$sudo" ] && return  # Nothing to install
	if ! which sudo >/dev/null; then
		zaf_wrn "Sudo needed bud not installed?"
	fi
	cmd=$(echo $sudo | cut -d ' ' -f 1)
	parms=$(echo $sudo | cut -d ' ' -f 2-)
	if which $cmd >/dev/null ; then
		(echo "zabbix ALL=NOPASSWD:SETENV: $(which $cmd) $(echo $parms | tr '%' '*')";echo) >$ZAF_SUDOERSD/zaf_$plugin || zaf_err "Error during zaf_ctrl_sudo"
		chmod 0440 $ZAF_SUDOERSD/zaf_$plugin
	else
		zaf_err "Cannot find binary '$cmd' to put into sudoers."
	fi
}

# Install crontab config from control
# $1 plugin
# $2 control
# $3 plugindir
zaf_ctrl_cron() {
	local pdir
	local plugin
	local cron

	pdir="$3"
	plugin=$1
	zaf_dbg "Installing cron entry $ZAF_CROND/zaf_$plugin"
	cron=$(zaf_ctrl_get_global_option $2 "Cron")
	[ -z "$cron" ] && return # Nothing to install
	zaf_ctrl_get_global_option $2 "Cron" | zaf_far '{PLUGINDIR}' "${plugindir}" >$ZAF_CROND/zaf_$plugin || zaf_err "Error during zaf_ctrl_cron"
}

# Install files defined to be installed in control to plugun directory
# $1 pluginurl
# $2 control
# $3 plugindir
zaf_ctrl_install() {
	local binaries
	local pdir
	local script
	local files
	local f
	local b

	pdir="$3"
	(set -e
	binaries=$(zaf_ctrl_get_global_option $2 "Install-bin")
	for b in $binaries; do
		zaf_fetch_url "$1/$b" >"${ZAF_TMP_DIR}/$b"
                zaf_install_bin "${ZAF_TMP_DIR}/$b" "$pdir"
	done
	files=$(zaf_ctrl_get_global_option $2 "Install-files")
	for f in $files; do
		zaf_fetch_url "$1/$b" >"${ZAF_TMP_DIR}/$b"
                zaf_install "${ZAF_TMP_DIR}/$b" "$pdir"
	done
	script=$(zaf_ctrl_get_global_option $2 "Install-script")
	[ -n "$script" ] && eval "$script"
	true
	) || zaf_err "Error during zaf_ctrl_install"
}

# Generates zabbix cfg from control file
# $1 control
# $2 pluginname
zaf_ctrl_generate_cfg() {
	local items
	local cmd
	local iscript
	local ikey
	local lock
	local cache

	items=$(zaf_ctrl_get_items <"$1")
	(set -e
	for i in $items; do
            iscript=$(zaf_stripctrl $i)
	    params=$(zaf_ctrl_get_item_option $1 $i "Parameters")
	    if [ -n "$params" ]; then
		ikey="$2.$i[*]"
		args=""
		apos=1;
		for p in $params; do
			args="$args \$$apos"
			apos=$(expr $apos + 1)
		done
	    else
		ikey="$2.$i"
	    fi
	    lock=$(zaf_ctrl_get_item_option $1 $i "Lock")
	    if [ -n "$lock" ]; then
		lock="${ZAF_LIB_DIR}/zaflock $lock "
	    fi
	    cache=$(zaf_ctrl_get_item_option $1 $i "Cache")
	    if [ -n "$cache" ]; then
		cache="_cache '$cache' "
	    fi
            cmd=$(zaf_ctrl_get_item_option $1 $i "Cmd")
            if [ -n "$cmd" ]; then
                $(which echo) "UserParameter=$ikey,${ZAF_LIB_DIR}/preload.sh $cache $lock$cmd";
                continue
            fi
            cmd=$(zaf_ctrl_get_item_option $1 $i "Function")
            if [ -n "$cmd" ]; then
                $(which echo) "UserParameter=$ikey,${ZAF_LIB_DIR}/preload.sh $cache $lock$cmd";
                continue;
            fi
            cmd=$(zaf_ctrl_get_item_option $1 $i "Script")
            if [ -n "$cmd" ]; then
                zaf_ctrl_get_item_option $1 $i "Script" >${ZAF_TMP_DIR}/${iscript}.sh;
                zaf_install_bin ${ZAF_TMP_DIR}/${iscript}.sh ${ZAF_PLUGINS_DIR}/$2/
                $(which echo) "UserParameter=$ikey,${ZAF_LIB_DIR}/preload.sh $cache $lock${ZAF_PLUGINS_DIR}/$2/${iscript}.sh $args";
                continue;
            fi
	    zaf_err "Item $i declared in control file but has no Cmd, Function or Script!"
	done
	) || zaf_err "Error during zaf_ctrl_generate_cfg"
}


