#!/bin/sh

if [ -z "$ZAF_URL" ]; then
	# Runing as standalone install.sh. We have to download rest of files first.
	[ -z "$ZAF_VERSION" ] && ZAF_VERSION=master
	ZAF_URL="https://github.com/limosek/zaf/"
fi

# Lite version of zaf_fetch_url, full version will be loaded later
zaf_fetch_url(){
	if [ -z "$ZAF_OFFLINE" ]; then
		echo  curl -f -k -s -L -o - "$1" >&2; curl -f -k -s -L -o - "$1"
	else
		echo "Offline mode wants to download $1. Exiting." >&2
		exit 2
	fi
}

# Download tgz and extract to /tmp/zaf-installer
zaf_download_files() {
	rm -rf /tmp/zaf-installer
	zaf_fetch_url $ZAF_URL/archive/$ZAF_VERSION.tar.gz | tar -C /tmp -zx && mv /tmp/zaf-$ZAF_VERSION /tmp/zaf-installer
}

if ! [ -f README.md ]; then
	# We are runing from stdin	
	if ! which curl >/dev/null;
	then
		zaf_err "Curl not found. Cannot continue. Please install it."
	fi
	echo "Installing from url $url..."
	[ -z "$*" ] && auto=auto
	zaf_download_files && cd /tmp/zaf-installer && exec ./install.sh $auto "$@"
	echo "Error downloading and runing installer!" >&2
	exit 2
fi

if ! type zaf_version >/dev/null; then
. lib/zaf.lib.sh
. lib/os.lib.sh
. lib/ctrl.lib.sh 
fi

# Read options as config for ZAF
for pair in "$@"; do
    echo $pair | grep -q '^ZAF\_' || continue
    option=$(echo $pair|cut -d '=' -f 1)
    value=$(echo $pair|cut -d '=' -f 2-)
    eval "C_${option}='$value'"
    zaf_wrn "Overriding $option from cmdline."
done

[ -z "$ZAF_CFG_FILE" ] && ZAF_CFG_FILE=$INSTALL_PREFIX/etc/zaf.conf
[ -n "$C_ZAF_DEBUG" ] && ZAF_DEBUG=$C_ZAF_DEBUG
[ -z "$ZAF_DEBUG" ] && ZAF_DEBUG=1

# Read option. If it is already set in zaf.conf, it is skipped. If env variable is set, it is used instead of default
# It sets global variable name on result.
# $1 - option name
# $2 - option description
# $3 - default
# $4 - if $4="auto" , use autoconf. if $4="user", force asking.
zaf_get_option(){
	local opt

        eval opt=\$C_$1
	if [ -n "$opt" ]; then
            eval "$1='$opt'"
            zaf_dbg "Got '$2' <$1> from CLI: $opt"
            return
        fi
	eval opt=\$$1
	if [ -n "$opt" ] && ! [ "$4" = "user" ]; then
		eval "$1='$opt'"
		zaf_dbg "Got '$2' <$1> from ENV: $opt"
		return
	else
		opt="$3"
	fi
	if ! [ "$4" = "auto" ]; then
		echo -n "$2 <$1> [$opt]: "
		read opt
	else
		opt=""
	fi
	if [ -z "$opt" ]; then
		opt="$3"
		zaf_dbg "Got '$2' <$1> from Defaults: $opt" >&2
	else
		zaf_dbg "Got '$2' <$1> from USER: $opt"
	fi
	eval "$1='$opt'"
}

# Sets option to zaf.conf
# $1 option name
# $2 option value
zaf_set_option(){
	local description
	if ! grep -q "^$1=" ${ZAF_CFG_FILE}; then
		echo "$1='$2'" >>${ZAF_CFG_FILE}
		zaf_dbg "Saving $1 to $2 in ${ZAF_CFG_FILE}" >&2
	else
		zaf_wrn "Preserving $1 to $2 in ${ZAF_CFG_FILE}" >&2
	fi
}

# Set config option in zabbix agent config file
# $1 option
# $2 value
zaf_set_agent_option() {
	local option="$1"
	local value="$2"
	if grep ^$option\= $ZAF_AGENT_CONFIG; then
		zaf_dbg "Setting option $option in $ZAF_AGENT_CONFIG."
		sed -i "s/$option=(.*)/$option=$2/" $ZAF_AGENT_CONFIG
	fi
}

# Add config option in zabbix agent  config file
# $1 option
# $2 value
zaf_add_agent_option() {
	local option="$1"
	local value="$2"
	if ! grep -q "^$1=$2" $ZAF_AGENT_CONFIG; then
		zaf_dbg "Adding option $option to $ZAF_AGENT_CONFIG."
		echo "$option=$value" >>$ZAF_AGENT_CONFIG
	fi
}

# Move config option fron zabbix agent config file to zaf options file and set value
# $1 option
# $2 value
zaf_move_agent_option() {
	local option="$1"
	local value="$2"
	if grep ^$option\= $ZAF_AGENT_CONFIG; then
		zaf_dbg "Moving option $option from $ZAF_AGENT_CONFIG to ."
		sed -i "s/$option=(.*)/$option=$2/" $ZAF_AGENT_CONFIG
	fi
	[ -n "$value" ] && echo "$option=$value" >> "$ZAF_AGENT_CONFIGD/zaf_options.conf"
}

# Automaticaly configure agent if supported
# Parameters are in format Z_zabbixconfvar=value
zaf_configure_agent() {
	local pair
	local option
	local value
	local options

        zaf_install_dir "$ZAF_AGENT_CONFIGD"
	echo -n >"$ZAF_AGENT_CONFIGD/zaf_options.conf" || zaf_err "Cannot access $ZAF_AGENT_CONFIGD/zaf_options.conf"
	! [ -f "$ZAF_AGENT_CONFIG" ] && zaf_install "$ZAF_AGENT_CONFIG"
	for pair in "$@"; do
		echo $pair | grep -q '^Z\_' || continue # Skip non Z_ vars
		option=$(echo $pair|cut -d '=' -f 1|cut -d '_' -f 2)
		value=$(echo $pair|cut -d '=' -f 2-)
		zaf_set_agent_option "$option" "$value"
		options="$options Z_$option='$value'"
	done
	zaf_set_option ZAF_AGENT_OPTIONS "${options}"
}

zaf_configure(){

	zaf_detect_system 
        zaf_os_specific zaf_configure_os
        if ! zaf_is_root; then
            [ -z "$INSTALL_PREFIX" ] && zaf_err "We are not root. Use INSTALL_PREFIX or become root."
        fi
	zaf_get_option ZAF_PKG "Packaging system to use" "$ZAF_PKG" "$1"
	zaf_get_option ZAF_OS "Operating system to use" "$ZAF_OS" "$1"
	zaf_get_option ZAF_OS_CODENAME "Operating system codename" "$ZAF_OS_CODENAME" "$1"
	zaf_get_option ZAF_AGENT_PKG "Zabbix agent package" "$ZAF_AGENT_PKG" "$1"
	zaf_get_option ZAF_AGENT_OPTIONS "Zabbix options to set in cfg" "$ZAF_AGENT_OPTIONS" "$1"
	if zaf_is_root && [ -n "$ZAF_AGENT_PKG" ]; then
		if ! zaf_os_specific zaf_check_deps "$ZAF_AGENT_PKG"; then
			if [ "$1" = "auto" ]; then
				zaf_os_specific zaf_install_agent
			fi
		fi
	fi
	if which git >/dev/null; then
		ZAF_GIT=1
	else
		ZAF_GIT=0
	fi
	zaf_get_option ZAF_GIT "Git is installed" "$ZAF_GIT" "$1"
	zaf_get_option ZAF_CURL_INSECURE "Insecure curl (accept all certificates)" "1" "$1"
	zaf_get_option ZAF_TMP_BASE "Tmp directory prefix (\$USER will be added)" "/tmp/zaf" "$1"
	zaf_get_option ZAF_LIB_DIR "Libraries directory" "/usr/lib/zaf" "$1"
        zaf_get_option ZAF_BIN_DIR "Directory to put binaries" "/usr/bin" "$1"
	zaf_get_option ZAF_PLUGINS_DIR "Plugins directory" "${ZAF_LIB_DIR}/plugins" "$1"
	[ "${ZAF_GIT}" = 1 ] && zaf_get_option ZAF_PLUGINS_GITURL "Git plugins repository" "https://github.com/limosek/zaf-plugins.git" "$1"
	zaf_get_option ZAF_PLUGINS_URL "Plugins http[s] repository" "https://raw.githubusercontent.com/limosek/zaf-plugins/master/" "$1"
	zaf_get_option ZAF_REPO_DIR "Plugins directory" "${ZAF_LIB_DIR}/repo" "$1"
	zaf_get_option ZAF_AGENT_CONFIG "Zabbix agent config" "/etc/zabbix/zabbix_agentd.conf" "$1"
	! [ -d "${ZAF_AGENT_CONFIGD}" ] && [ -d "/etc/zabbix/zabbix_agentd.d" ] && ZAF_AGENT_CONFIGD="/etc/zabbix/zabbix_agentd.d"
	zaf_get_option ZAF_AGENT_CONFIGD "Zabbix agent config.d" "/etc/zabbix/zabbix_agentd.conf.d/" "$1"
	zaf_get_option ZAF_AGENT_BIN "Zabbix agent binary" "/usr/sbin/zabbix_agentd" "$1"
	zaf_get_option ZAF_AGENT_RESTART "Zabbix agent restart cmd" "service zabbix-agent restart" "$1"
	
	if zaf_is_root && ! [ -x $ZAF_AGENT_BIN ]; then
		zaf_err "Zabbix agent ($ZAF_AGENT_BIN) not installed? Use ZAF_AGENT_BIN env variable to specify location. Exiting."
	fi

        [ -n "$INSTALL_PREFIX" ] && zaf_install_dir "/etc"
	if ! [ -f "${ZAF_CFG_FILE}" ]; then
		touch "${ZAF_CFG_FILE}" || zaf_err "No permissions to ${ZAF_CFG_FILE}"
	fi
	
	zaf_set_option ZAF_PKG "${ZAF_PKG}"
	zaf_set_option ZAF_OS "${ZAF_OS}"
	zaf_set_option ZAF_OS_CODENAME "${ZAF_OS_CODENAME}"
	zaf_set_option ZAF_AGENT_PKG "${ZAF_AGENT_PKG}"
	zaf_set_option ZAF_GIT "${ZAF_GIT}"
	zaf_set_option ZAF_CURL_INSECURE "${ZAF_CURL_INSECURE}"
	zaf_set_option ZAF_TMP_BASE "$ZAF_TMP_BASE"
	zaf_set_option ZAF_LIB_DIR "$ZAF_LIB_DIR"
        zaf_set_option ZAF_BIN_DIR "$ZAF_BIN_DIR"
	zaf_set_option ZAF_PLUGINS_DIR "$ZAF_PLUGINS_DIR"
	zaf_set_option ZAF_PLUGINS_URL "$ZAF_PLUGINS_URL"
	[ "${ZAF_GIT}" = 1 ] && zaf_set_option ZAF_PLUGINS_GITURL "$ZAF_PLUGINS_GITURL"
	zaf_set_option ZAF_REPO_DIR "$ZAF_REPO_DIR"
	zaf_set_option ZAF_AGENT_CONFIG "$ZAF_AGENT_CONFIG"
	zaf_set_option ZAF_AGENT_CONFIGD "$ZAF_AGENT_CONFIGD"
	zaf_set_option ZAF_AGENT_BIN "$ZAF_AGENT_BIN"
	zaf_set_option ZAF_AGENT_RESTART "$ZAF_AGENT_RESTART"
	[ -n "$ZAF_PREPACKAGED_DIR" ] && zaf_set_option ZAF_PREPACKAGED_DIR "$ZAF_PREPACKAGED_DIR"
	ZAF_TMP_DIR="${ZAF_TMP_BASE}-${USER}-$$"

	if zaf_is_root; then
        	zaf_configure_agent $ZAF_AGENT_OPTIONS "$@"
		zaf_add_agent_option "Include" "$ZAF_AGENT_CONFIGD"
	fi
}

zaf_install_all() {
	rm -rif ${ZAF_TMP_DIR}
	mkdir -p ${ZAF_TMP_DIR}
	zaf_install_dir ${ZAF_LIB_DIR}
	for i in lib/zaf.lib.sh lib/os.lib.sh lib/ctrl.lib.sh README.md; do
		zaf_install $i ${ZAF_LIB_DIR}/
	done
	for i in lib/zaflock lib/preload.sh; do
		zaf_install_bin $i ${ZAF_LIB_DIR}/
	done
	zaf_install_dir ${ZAF_BIN_DIR}
	for i in zaf; do
		zaf_install_bin $i ${ZAF_BIN_DIR}/
	done
	zaf_install_dir ${ZAF_PLUGINS_DIR}
	zaf_install_dir ${ZAF_TMP_DIR}/p/zaf
	zaf_install_dir ${ZAF_PLUGINS_DIR}
        zaf_install_dir ${ZAF_BIN_DIR}
        export INSTALL_PREFIX ZAF_CFG_FILE ZAF_DEBUG
        if zaf_is_root; then
	    [ "${ZAF_GIT}" = 1 ] && ${INSTALL_PREFIX}/${ZAF_BIN_DIR}/zaf update
            ${INSTALL_PREFIX}/${ZAF_BIN_DIR}/zaf reinstall zaf || zaf_err "Error installing zaf plugin."
            if zaf_is_root && ! zaf_test_item zaf.framework_version; then
		echo "Something is wrong with zabbix agent config."
		echo "Ensure that zabbix_agentd reads ${ZAF_AGENT_CONFIG}"
		echo "and there is Include=${ZAF_AGENT_CONFIGD} directive inside."
		echo "Does ${ZAF_AGENT_RESTART} work?"
		exit 1
            fi
	else
	    [ "${ZAF_GIT}" = 1 ] && [ -n  "${INSTALL_PREFIX}" ] && git clone "${ZAF_PLUGINS_GITURL}" "${INSTALL_PREFIX}/${ZAF_REPO_DIR}"
        fi
	rm -rif ${ZAF_TMP_DIR}
	echo "Install OK. Use 'zaf' without parameters to continue."
}

if [ -f "${ZAF_CFG_FILE}" ]; then
	. "${ZAF_CFG_FILE}"
fi
ZAF_TMP_DIR="${ZAF_TMP_BASE-/tmp/zaf}-${USER}-$$"

case $1 in
interactive)
        shift
	zaf_configure interactive
	zaf_install_all
	;;
auto)
        shift
	zaf_configure auto
        zaf_install_all
        ;;
debug-auto)
        shift;
	ZAF_DEBUG=4
        zaf_configure auto
	zaf_install_all
        ;;
debug-interactive)
        shift;
        ZAF_DEBUG=4
	zaf_configure interactive
	zaf_install_all
        ;;
debug)
        shift;
        ZAF_DEBUG=4
	zaf_configure auto
	zaf_install_all
        ;;
reconf)
        shift;
        rm -f $ZAF_CFG_FILE
	zaf_configure auto
        ;;
install)
        zaf_configure auto
	zaf_install_all
	;;
*)
	echo
	echo "Please specify how to install."
	echo "install.sh {auto|interactive|debug-auto|debug-interactive|reconf} [Agent-Options] [Zaf-Options]"
        echo "scratch means that config file will be created from scratch"
        echo " Agent-Options: A_Option=value [...]"
        echo " Zaf-Options: ZAF_OPT=value [...]"
        echo 
	echo "Example 1 (default install): install.sh auto"
	echo 'Example 2 (preconfigure agent options): install.sh auto A_Server=zabbix.server A_ServerActive=zabbix.server A_Hostname=$(hostname)'
	echo "Example 3 (preconfigure zaf packaging system to use): install.sh auto ZAF_PKG=opkg"
	echo "Example 4 (interactive): install.sh interactive"
	echo
	exit 1
esac



