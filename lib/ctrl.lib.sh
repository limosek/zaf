# Control file related functions

# Check plugin url
# $1 plugin uri
# $2 local file to fetch
zaf_plugin_fetch_control() {
	[ -z "$1" ] && return -1
	local name=$(basename "$1")
	zaf_fetch_url "$1/control.zaf" >"$2"
}

# Get block from stdin
# $1 option
# $2 name
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
	}}'
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
		if (/^::$/) exit;
		print $0;
	}}'
}

# Get item singleline option
# $1 optionname
zaf_block_get_option() {
	grep "^$1:" | cut -d ' ' -f 2- | tr -d '\r\n'
}

zaf_ctrl_check_deps() {
	local deps
	deps=$(zaf_ctrl_get_global_block <$1 | zaf_block_get_option "Depends-${ZAF_PKG}" )
	zaf_check_deps $deps
	deps=$(zaf_ctrl_get_global_block <$1 | zaf_block_get_option "Depends-bin" )
	for cmd in $deps; do
		if ! which $cmd >/dev/null; then
			echo "Missing binary dependency $cmd. Please install it first."
			return 1
		fi
	done
}

# Install binaries from control
# $1 control
# $2 plugindir
zaf_ctrl_install() {
	local binaries
	local pdir
	local script
	local cmd

	pdir="$2"
	binaries=$(zaf_ctrl_get_global_block <$1 | zaf_block_get_option "Install-bin" | zaf_far '{PLUGINDIR}' "$plugindir" )
	for b in $binaries; do
		zaf_fetch_url "$url/$b" >"$pdir/$b"
		chmod +x "$pdir/$b"
	done
	script=$(zaf_ctrl_get_global_block <$1 | zaf_block_get_moption "Install-script" | zaf_far '{PLUGINDIR}' "$plugindir" )
	[ -n "$script" ] && eval $script
	cmd=$(zaf_ctrl_get_global_block <$1 | zaf_block_get_option "Install-cmd" | zaf_far '{PLUGINDIR}' "$plugindir" )
	[ -n "$cmd" ] && $cmd
}

# Generates zabbix cfg from control file
# $1 control
# $2 pluginname
zaf_ctrl_generate_cfg() {
	local items
	local cmd
	local ilock

	items=$(zaf_ctrl_get_items <"$1")
	for i in $items; do
		block=$(zaf_ctrl_get_item_block <$1 $i)
		ilock=$(echo $i | tr -d '[]*&;:')
		cmd=$(zaf_block_get_option <$1 "Cmd")
		[ -n "$cmd" ] && { echo "UserParameter=$2.${i},$cmd"; continue; }
		cmd=$(zaf_block_get_option <$1 "Function")
		[ -n "$cmd" ] && { echo "UserParameter=$2.${i},${ZAF_LIB_DIR}/preload.sh $cmd"; continue; }
		cmd=$(zaf_block_get_moption <$1 "Script")
		[ -n "$cmd" ] && { zaf_block_get_moption <$1 "Script" >${ZAF_PLUGIN_DIR}/$2/$ilock.sh;  echo "UserParameter=$2.${i},${ZAF_PLUGIN_DIR}/$ilock.sh"; continue; }
	done
}

