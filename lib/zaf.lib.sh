
# Hardcoded variables
ZAF_VERSION="1.3"
ZAF_GITBRANCH="master"
ZAF_URL="https://github.com/limosek/zaf"
ZAF_RAW_URL="https://raw.githubusercontent.com/limosek/zaf"

############################################ Common routines

zaf_msg() {
	echo $@
}
zaf_trc() {
	[ "$ZAF_DEBUG" -ge "3" ] && logger -p user.info ${ZAF_LOG_STDERR} -t zaf-trace -- $@
}
zaf_dbg() {
	[ "$ZAF_DEBUG" -ge "2" ] && logger -p user.debug ${ZAF_LOG_STDERR} -t zaf-debug -- $@
}
zaf_wrn() {
	[ "$ZAF_DEBUG" -ge "1" ] && logger -p user.warn ${ZAF_LOG_STDERR} -t zaf-warning -- $@
}
zaf_err() {
	logger ${ZAF_LOG_STDERR} -p user.err -t zaf-error -- $@
        logger ${ZAF_LOG_STDERR} -p user.err -t zaf-error "Exiting with error!"
        exit 1
}
# Help option
# $1 - key
# $2 - 
zaf_hlp() {
	local kl
	local dl
	local cols

	cols=$COLUMNS
	[ -z "$cols" ] && cols=120
	kl=$(expr $cols / 3)
	dl=$(expr $cols - $kl)
	printf %-${kl}s%-${dl}s%b "$1" "$2" "\n"
}
# $1 if nonempty, log to stderr too
zaf_debug_init() {
	[ -z "$ZAF_DEBUG" ] && ZAF_DEBUG=1
	export ZAF_DEBUG
	[ -n "$1" ] && export ZAF_LOG_STDERR="-s"
}

zaf_tmp_init() {
	[ -z "$ZAF_TMP_DIR" ] && ZAF_TMP_DIR=/tmp/
	! [ -w "$ZAF_TMP_DIR" ] && zaf_err "Tmp dir $ZAF_TMP_DIR is not writable."
}

zaf_version(){
	echo $ZAF_VERSION
}

# Add parameter for agent check
# $1 parameter name (will be set to var)
# $2 if nonempty, it is default value. If empty, parameter is mandatory
# $3 if nonempty, regexp to test
zaf_agentparm(){
	local name
	local default
	local regexp

	name="$1"
	default="$2"
	regexp="$3"
	
	[ -z "$value" ] && [ -z "$default" ] && zaf_err "$ITEM_KEY: Missing mandatory parameter $name."
	if [ -z "$value" ]; then
		value="$default"
	else
		if [ -n "$regexp" ]; then
			echo "$value" | grep -qE "$regexp" ||  zaf_err "$ITEM_KEY: Bad parameter '$name' value '$value' (not in regexp '$regexp')."
		fi
	fi
	eval $name=$value
	zaf_trc "$ITEM_KEY: Param $name set to $value"
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

# Add seconds to current date and return date in YYYY-MM-DD hh:mm:ss
# $1 seconds
zaf_date_add() {
	date -d "$1 seconds" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "$(expr $(date +%s) + $1)" -D %s "+%Y-%m-%d %H:%M:%S"
}

# Create temp file and return its name
# $1 prefix or empty
zaf_tmpfile() {
	echo "$ZAF_TMP_DIR/tmp$1"
}

# return random number
zaf_random() {
	hexdump -n 2 -e '/2 "%u"' /dev/urandom
}

# Emulate sudo
zaf_sudo() {
	if zaf_is_root || ! zaf_which sudo >/dev/null 2>/dev/null; then
		$@
	else
		sudo $@
	fi
}

