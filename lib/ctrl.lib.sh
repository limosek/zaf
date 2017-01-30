# Control file related functions

# Get item list from control on stdin
zaf_ctrl_get_items() {
	grep '^Item ' | cut -d ' ' -f 2 | cut -d ':' -f 1 | tr '\r\n' ' '
}

# Get external item list from control on stdin
zaf_ctrl_get_extitems() {
	grep '^ExtItem ' | cut -d ' ' -f 2 | cut -d ':' -f 1 | tr '\r\n' ' '
}

# Get external item body from stdin
# $1 itemname
zaf_ctrl_get_extitem_block() {
	grep -v '^#' | awk '/^ExtItem '$1'/ { i=0;
	while (i==0) {
		getline;
		if (/^\/ExtItem/) exit;
		print $0;
	}};
	END {
		exit i==0;
	}'
}

# Get item body from stdin
# $1 itemname
zaf_ctrl_get_item_block() {
	grep -vE '^#[a-zA-Z ]' | awk '/^Item '$1'/ { i=0;
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
	grep -vE '^#[a-zA-Z ]' | awk '{ i=0; print $0;
	while (i==0) {
		getline;
		if (/^(Item |ExtItem)/) exit;
		print $0;
	}}'
}

# Get item multiline option
# $1 optionname
zaf_block_get_moption() {
	awk '/^'$1'::$/ { i=0; if (!/::/) print $0;
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

# Get external item specific option (single or multiline)
# $1 - control file
# $2 - item name
# $3 - option name
zaf_ctrl_get_extitem_option() {
	local ctrlvar
	local ctrlopt

	ctrlopt="ZAF_CTRLI_$(zaf_stripctrl $2)_$(zaf_stripctrl $3)"
	eval ctrlvar=\$$ctrlopt
	if [ -n "$ctrlvar" ]; then
		zaf_dbg "Overriding item control field $2/$3 from env $ctrlopt($ctrlvar)"
		echo $ctrlopt
	else
		zaf_ctrl_get_extitem_block <$1 "$2" | zaf_block_get_moption "$3" \
		|| zaf_ctrl_get_extitem_block <$1 "$2" | zaf_block_get_option "$3"
	fi
}

# Check dependencies based on control file
zaf_ctrl_check_deps() {
	local deps
	if [ -n "$ZAF_PKG" ]; then
		deps=$(zaf_ctrl_get_global_block <$1 | zaf_block_get_option "Depends-${ZAF_PKG}" )

		if ! zaf_os_specific zaf_check_deps $deps; then
			zaf_err "Missing one of dependend system packages: $deps"
		fi
	fi
	deps=$(zaf_ctrl_get_global_block <$1 | zaf_block_get_option "Depends-bin" )
	for cmd in $deps; do
		if ! zaf_which $cmd >/dev/null; then
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
	sudo=$(zaf_ctrl_get_global_option $2 "Sudo" | zaf_far '{PLUGINDIR}' "${plugindir}")
	[ -z "$sudo" ] || [ -z "$ZAF_SUDOERSD" ] && return
	! [ -d "$ZAF_SUDOERSD" ] && { zaf_wrn "$ZAF_SUDOERSD nonexistent! Skipping sudo install!"; return 1; }
	zaf_dbg "Installing sudoers entry $ZAF_SUDOERSD/zaf_$plugin"
	
	[ -z "$sudo" ] && return	# Nothing to install
	if ! zaf_which sudo >/dev/null; then
		zaf_wrn "Sudo needed bud not installed?"
	fi
	cmd=$(echo $sudo | cut -d ' ' -f 1)
	parms=$(echo $sudo | cut -d ' ' -f 2-)
	if zaf_which $cmd >/dev/null ; then
		(echo "zabbix ALL=NOPASSWD:SETENV: $(zaf_which $cmd) $(echo $parms | tr '%' '*')";echo) >$ZAF_SUDOERSD/zaf_$plugin || zaf_err "Error during zaf_ctrl_sudo"
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
	cron=$(zaf_ctrl_get_global_option $2 "Cron")
	[ -z "$cron" ]	|| [ -z "$ZAF_CROND" ] && return
	! [ -d "$ZAF_CROND" ] && { zaf_wrn "$ZAF_CROND nonexistent! Skipping cron install!"; return 1; }
	zaf_dbg "Installing cron entry $ZAF_CROND/zaf_$plugin"
	[ -z "$cron" ] && return # Nothing to install
	zaf_ctrl_get_global_option $2 "Cron" | zaf_far '{PLUGINDIR}' "${plugindir}" >$ZAF_CROND/zaf_$plugin || zaf_err "Error during zaf_ctrl_cron"
}

# Install files defined to be installed in control to plugin directory
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
	binaries=$(zaf_ctrl_get_global_option $2 "Install-bin")" "$(zaf_ctrl_get_global_option $2 "Install-cmd")
	for b in $binaries; do
		zaf_fetch_url "$1/$b" >"${ZAF_TMP_DIR}/$b"
		zaf_install_bin "${ZAF_TMP_DIR}/$b" "$pdir"
	done
	files=$(zaf_ctrl_get_global_option $2 "Install-files")
	for f in $files; do
		zaf_fetch_url "$1/$f" >"${ZAF_TMP_DIR}/$f"
		zaf_install "${ZAF_TMP_DIR}/$f" "$pdir"
	done
	true
	) || zaf_err "Error during zaf_ctrl_install"
}

# Generates zabbix items cfg from control file
# $1 control
# $2 pluginname
# $3 if set, no script will be created
# $4 if set, cmd is set always to $4
zaf_ctrl_generate_items_cfg() {
	local items
	local cmd
	local iscript
	local ikey
	local lock
	local cache
	local tmpfile
	local pname
	local pdefault
	local pregex
	local prest
	local zafparms

	items=$(zaf_ctrl_get_items <"$1")
	tmpfile=$(zaf_tmpfile genparms)
	(set -e
	for i in $items; do
		iscript=$(zaf_stripctrl $i)
		zaf_ctrl_get_item_option $1 $i "Parameters" >$tmpfile
		echo >>$tmpfile
		zafparams="";
		if [ -s "$tmpfile" ]; then
			ikey="$2.$i[*]"
			args=""
			apos=1;
			while read pname pdefault pregex prest; do
				[ -z "$pname" ] && continue
				zaf_trc "Adding param $pname ($pdefault $pregex) to $i"
				zafparams="$zafparams value=\"\$$apos\"; zaf_agentparm $pname $pdefault $pregex; export $pname; "
				args="$args \$$apos"
				apos=$(expr $apos + 1)
			done <$tmpfile
		else
			ikey="$2.$i"
			zafparams=""
			args=""
		fi
		env="export ITEM_KEY='$ikey'; export PLUGIN='$2'; export PATH=${ZAF_PLUGINS_DIR}/$2:$ZAF_LIB_DIR:\$PATH; cd ${ZAF_PLUGINS_DIR}/$2; . $ZAF_LIB_DIR/preload.sh; "
		lock=$(zaf_ctrl_get_item_option $1 $i "Lock")
		if [ -n "$lock" ]; then
			lock="${ZAF_LIB_DIR}/zaflock $lock "
		fi
		cache=$(zaf_ctrl_get_item_option $1 $i "Cache")
		if [ -n "$cache" ]; then
			cache="${ZAF_LIB_DIR}/zafcache '$cache' "
		fi
		ret=$(zaf_ctrl_get_item_option $1 $i "Return")
		retnull=$(zaf_ctrl_get_item_option $1 $i "Return-null")
		reterr=$(zaf_ctrl_get_item_option $1 $i "Return-error")
		if [ -n "$ret" ] || [ -n "$reterr" ] || [ -n "$retnull" ]; then
			retscr=" 1>\${tmpf}o 2>\${tmpf}e; ${ZAF_LIB_DIR}/zafret \${tmpf}o \${tmpf}e \$? '$ret' '$retnull' '$retempty' ";
		else
			retscr="";
		fi
		if [ -z "$4" ]; then
			cmd=$(zaf_ctrl_get_item_option $1 $i "Cmd")
		else
			cmd="$4"
		fi
		if [ -n "$cmd" ]; then
			printf "%s" "UserParameter=$ikey,${env}${zafparams}${preload}${cache}${lock}${cmd}${retscr}"; echo
			continue
		fi
		cmd=$(zaf_ctrl_get_item_option $1 $i "Script")
		if [ -n "$cmd" ]; then
			( echo "#!/bin/sh"
			echo ". $ZAF_LIB_DIR/preload.sh; "
			zaf_ctrl_get_item_option $1 $i "Script"
			) >${ZAF_TMP_DIR}/${iscript}.sh;
			[ -z "$3" ] && zaf_install_bin ${ZAF_TMP_DIR}/${iscript}.sh ${ZAF_PLUGINS_DIR}/$2/
			if [ -z "$4" ]; then
				script="${ZAF_PLUGINS_DIR}/$2/${iscript}.sh"
			else
				script="$4"
			fi
			printf "%s" "UserParameter=$ikey,${env}${preload}${zafparams}${cache}${lock}$script ${args}"; echo
			rm -f ${ZAF_TMP_DIR}/${iscript}.sh
			continue;
		fi
		zaf_err "Item $i declared in control file but has no Cmd, Function or Script!"
	done
	) || zaf_err "Error during zaf_ctrl_generate_items_cfg"
	[ "$ZAF_DEBUG" -lt 4 ] && rm -f $tmpfile
}

# Generates zabbix items cfg from control file
# $1 control
# $2 pluginname
zaf_ctrl_generate_extitems_cfg() {
	local items
	local cmd
	local iscript
	local ikey
	local lock
	local cache
	local tmpfile
	local pname
	local pdefault
	local pregex
	local prest
	local zafparms

	items=$(zaf_ctrl_get_extitems <"$1")
	tmpfile=$(zaf_tmpfile genparms)
	(set -e
	for i in $items; do
		iscript=$(zaf_stripctrl $i)
		(zaf_ctrl_get_extitem_option $1 $i "Parameters"; echo) >$tmpfile
		ikey="$2.$i"
		if [ -s "$tmpfile" ]; then
			args=""
			apos=1;
			while read pname pdefault pregex prest; do
				zafparams="$zafparams value=\"\$$apos\"; zaf_agentparm $pname $pdefault $pregex; export $pname; "
				args="$args \$$apos"
				apos=$(expr $apos + 1)
			done <$tmpfile
		else
			zafparams=""
			args=""
		fi
		env="export ITEM_KEY='$ikey'; export PLUGIN='$2'; export PATH=${ZAF_PLUGINS_DIR}/$2:$ZAF_LIB_DIR:\$PATH; cd ${ZAF_PLUGINS_DIR}/$2; . $ZAF_LIB_DIR/preload.sh; "
		lock=$(zaf_ctrl_get_extitem_option $1 $i "Lock")
		if [ -n "$lock" ]; then
			lock="${ZAF_LIB_DIR}/zaflock $lock "
		fi
		cache=$(zaf_ctrl_get_extitem_option $1 $i "Cache")
		if [ -n "$cache" ]; then
			cache="${ZAF_LIB_DIR}/zafcache '$cache' "
		fi
		ret=$(zaf_ctrl_get_extitem_option $1 $i "Return")
		retnull=$(zaf_ctrl_get_extitem_option $1 $i "Return-null")
		reterr=$(zaf_ctrl_get_extitem_option $1 $i "Return-error")
		if [ -n "$ret" ] || [ -n "$reterr" ] || [ -n "$retnull" ]; then
			retscr=" 1>\${tmpf}o 2>\${tmpf}e; ${ZAF_LIB_DIR}/zafret \${tmpf}o \${tmpf}e \$? '$ret' '$retnull' '$retempty' \$*";
		else
			retscr="";
		fi
		cmd=$(zaf_ctrl_get_extitem_option "$1" "$i" "Cmd")
		if [ -n "$cmd" ]; then
			echo "#!/bin/sh" >"${ZAF_SERVER_EXTSCRIPTS}/$ikey"
			chmod +x "${ZAF_SERVER_EXTSCRIPTS}/$ikey"
			(printf "%s" "${env}${zafparams}${preload}${cache}${lock}${cmd}${retscr}"; echo) >>"${ZAF_SERVER_EXTSCRIPTS}/$ikey"
			continue
		fi
		cmd=$(zaf_ctrl_get_extitem_option "$1" "$i" "Script")
		if [ -n "$cmd" ]; then
			echo "#!/bin/sh" >"${ZAF_SERVER_EXTSCRIPTS}/$ikey"
			chmod +x "${ZAF_SERVER_EXTSCRIPTS}/$ikey"
			(printf "%s" "${env}${zafparams}${preload}${cache}${lock}${cmd}"; echo) >>"${ZAF_SERVER_EXTSCRIPTS}/$ikey"
			continue;
		fi
		zaf_err "External item $i declared in control file but has no Cmd, Function or Script!"
	done
	) || zaf_err "Error during zaf_ctrl_generate_extitems_cfg"
	rm -f $tmpfile
}

