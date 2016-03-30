#!/bin/sh

if ! [ "$(basename $0)" = "install.sh" ]; then
	# We are runing from stdin
	url="https://raw.githubusercontent.com/limosek/zaf/master/"
	if ! which curl >/dev/null;
	then
		echo "Curl not found. Cannot continue. Please install it."
		exit 2
	fi
	echo "Installing from url $url..." >&2
	[ -z "$*" ] && silent=silent
	set -e
	mkdir -p /tmp/zaf-installer \
	&& cd /tmp/zaf-installer \
	&& (for i in lib/zaf.lib.sh lib/os.lib.sh lib/ctrl.lib.sh install.sh ; do curl -f -k -s -L -o - "$url/$i") >install.sh \
	&& chmod +x install.sh \
	&& exec ./install.sh $silent "$@"
	exit
fi

ZAF_CFG_FILE=/etc/zaf.conf
. $(dirname $0)/lib/zaf.lib.sh
. $(dirname $0)/lib/os.lib.sh
. $(dirname $0)/lib/ctrl.lib.sh

zaf_msg() {
	[ "$ZAF_DEBUG" = "1" ] && echo $@
}

# Read option. If it is already set in zaf.conf, it is skipped. If env variable is set, it is used instead of default
# It sets global variable name on result.
# $1 - option name
# $2 - option description
# $3 - default
# $4 - if $4="silent" , use autoconf. if $4="user", force asking.
zaf_get_option(){
	local opt
	eval opt=\$$1
	if [ -n "$opt" ] && ! [ "$4" = "user" ]; then
		eval "$1='$opt'"
		zaf_msg "Got $2 <$1> from ENV: $opt" >&2
		return
	else
		opt="$3"
	fi
	if ! [ "$4" = "silent" ]; then
		echo -n "$2 <$1> [$opt]: "
		read opt
	else
		opt=""
	fi
	if [ -z "$opt" ]; then
		opt="$3"
		zaf_msg "Got $2 <$1> from Defaults: $opt" >&2
	else
		zaf_msg "Got $2 <$1> from USER: $opt"
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
		zaf_msg "Saving $1 to $2 in ${ZAF_CFG_FILE}" >&2
	else
		zaf_msg "Preserving $1 to $2 in ${ZAF_CFG_FILE}" >&2
	fi
}

zaf_getrest(){
	if [ -f "$(dirname $0)/$1" ]; then
		echo "$(dirname $0)/$1"
	else
		curl -f -k -s -L -o - https://raw.githubusercontent.com/limosek/zaf/master/$1 >${ZAF_TMP_DIR}/$(basename $1)
		echo ${ZAF_TMP_DIR}/$(basename $1)
	fi
}

zaf_install(){
	cp "$1" "$2"
}

zaf_install_exe(){
	cp "$1" "$2"
	chmod +x "$2"
}

# Automaticaly install agent if supported
zaf_install_agent() {
	case $ZAF_OS in
	Debian)
		curl "http://repo.zabbix.com/zabbix/3.0/debian/pool/main/z/zabbix-release/zabbix-release_3.0-1+${ZAF_CODENAME}_all.deb" >"/tmp/zaf-installer/zabbix-release_3.0-1+${ZAF_CODENAME}_all.deb" \
		&& dpkg -i "/tmp/zaf-installer/zabbix-release_3.0-1+${ZAF_CODENAME}_all.deb" \
		&& apt-get update \
		&& apt-get install $ZAF_AGENT_PKG
	;;
	esac
}

# Set config option in zabbix agent
# $1 option
# $2 value
zaf_agent_set_option() {
	local option="$1"
	local value="$2"
	if grep ^$option\= $ZAF_AGENT_CONFIG; then
		echo "Moving option $option to zaf config part."
		sed -i "s/$option=/#$option=/" $ZAF_AGENT_CONFIG
	fi
	echo "$option=$value" >> "$ZAF_AGENT_CONFIGD/zaf_options.conf"	
}

# Automaticaly configure agent if supported
# Parameters are in format zabbixconfvar=value
zaf_configure_agent() {
	local pair
	local option
	local value

	touch "$ZAF_AGENT_CONFIGD/zaf_options.conf"
	for pair in "$@"; do
		echo $pair | grep -q '^Z\_' || continue
		option=$(echo $pair|cut -d '=' -f 1|cut -d '_' -f 2)
		value=$(echo $pair|cut -d '=' -f 2-)
		zaf_agent_set_option "$option" "$value"
	done
}

zaf_no_perms(){
	echo "No permissions! to $1! Please become root or give perms. Exiting."
	exit 2
}

zaf_configure(){

	[ "$1" = "interactive" ] && ZAF_DEBUG=1
	zaf_detect_system 
	zaf_get_option ZAF_PKG "Packaging system to use" "$ZAF_PKG" "$1"
	zaf_get_option ZAF_OS "Operating system to use" "$ZAF_OS" "$1"
	zaf_get_option ZAF_OS_CODENAME "Operating system codename" "$ZAF_OS_CODENAME" "$1"
	zaf_get_option ZAF_AGENT_PKG "Zabbix agent package" "$ZAF_AGENT_PKG" "$1"
	if [ -n "$ZAF_AGENT_PKG" ]; then
		if ! zaf_check_deps "$ZAF_AGENT_PKG"; then
			if [ "$1" = "silent" ]; then
				zaf_install_agent
			fi
		fi
	fi
	zaf_get_option ZAF_CURL_INSECURE "Insecure curl (accept all certificates)" "1" "$1"
	zaf_get_option ZAF_TMP_BASE "Tmp directory prefix (\$USER will be added)" "/tmp/zaf" "$1"
	zaf_get_option ZAF_LIB_DIR "Libraries directory" "/usr/lib/zaf" "$1"
	zaf_get_option ZAF_PLUGINS_DIR "Plugins directory" "${ZAF_LIB_DIR}/plugins" "$1"
	zaf_get_option ZAF_PLUGINS_REPO "Plugins reposiory" "https://raw.githubusercontent.com/limosek/zaf-plugins/master/" "$1"
	zaf_get_option ZAF_REPO_DIR "Plugins directory" "${ZAF_LIB_DIR}/repo" "$1"
	zaf_get_option ZAF_AGENT_CONFIG "Zabbix agent config" "/etc/zabbix/zabbix_agentd.conf" "$1"
	! [ -d "${ZAF_AGENT_CONFIGD}" ] && [ -d "/etc/zabbix/zabbix_agentd.d" ] && ZAF_AGENT_CONFIGD="/etc/zabbix/zabbix_agentd.d"
	zaf_get_option ZAF_AGENT_CONFIGD "Zabbix agent config.d" "/etc/zabbix/zabbix_agentd.conf.d/" "$1"
	zaf_get_option ZAF_AGENT_BIN "Zabbix agent binary" "/usr/sbin/zabbix_agentd" "$1"
	zaf_get_option ZAF_AGENT_RESTART "Zabbix agent restart cmd" "service zabbix-agent restart" "$1"
	
	if ! which $ZAF_AGENT_BIN >/dev/null; then
		echo "Zabbix agent not installed? Use ZAF_ZABBIX_AGENT_BIN env variable to specify location. Exiting."
		exit 3
	fi
	if which git >/dev/null; then
		ZAF_GIT=1
	else
		ZAF_GIT=""
	fi

	if ! [ -f "${ZAF_CFG_FILE}" ]; then
		touch "${ZAF_CFG_FILE}" || zaf_no_perms "${ZAF_CFG_FILE}"
	fi
	
	zaf_set_option ZAF_PKG "${ZAF_PKG}"
	zaf_set_option ZAF_OS "${ZAF_OS}"
	zaf_set_option ZAF_OS_CODENAME "${ZAF_OS_CODENAME}"
	zaf_set_option ZAF_AGENT_PKG "${ZAF_AGENT_PKG}"
	zaf_set_option ZAF_GIT "${ZAF_GIT}"
	zaf_set_option ZAF_CURL_INSECURE "${ZAF_CURL_INSECURE}"
	zaf_set_option ZAF_TMP_BASE "$ZAF_TMP_BASE"
	zaf_set_option ZAF_LIB_DIR "$ZAF_LIB_DIR"
	zaf_set_option ZAF_PLUGINS_DIR "$ZAF_PLUGINS_DIR"
	zaf_set_option ZAF_PLUGINS_REPO "$ZAF_PLUGINS_REPO"
	zaf_set_option ZAF_REPO_DIR "$ZAF_REPO_DIR"
	zaf_set_option ZAF_AGENT_CONFIG "$ZAF_AGENT_CONFIG"
	zaf_set_option ZAF_AGENT_CONFIGD "$ZAF_AGENT_CONFIGD"
	zaf_set_option ZAF_AGENT_BIN "$ZAF_AGENT_BIN"
	zaf_set_option ZAF_AGENT_RESTART "$ZAF_AGENT_RESTART"
	ZAF_TMP_DIR="${ZAF_TMP_BASE}-${USER}-$$"
}

if [ -f "${ZAF_CFG_FILE}" ]; then
	. "${ZAF_CFG_FILE}"
fi
ZAF_TMP_DIR="${ZAF_TMP_BASE}-${USER}-$$"

case $1 in
interactive)
	zaf_configure interactive
	$0 install
	;;
silent)
	zaf_configure silent
	zaf_configure_agent "$@"
	rm -rif ${ZAF_TMP_DIR}
	mkdir -p ${ZAF_TMP_DIR}
	mkdir -p ${ZAF_LIB_DIR}
	mkdir -p ${ZAF_PLUGINS_DIR}
	zaf_install $(zaf_getrest lib/zaf.lib.sh) ${ZAF_LIB_DIR}/zaf.lib.sh
	zaf_install $(zaf_getrest lib/jshn.sh) ${ZAF_LIB_DIR}/jshn.sh
	zaf_install_exe $(zaf_getrest lib/zaflock) ${ZAF_LIB_DIR}/zaflock
	mkdir -p ${ZAF_TMP_DIR}/p/zaf
	mkdir -p ${ZAF_PLUGINS_DIR}
	zaf_install_exe $(zaf_getrest zaf) /usr/bin/zaf
	/usr/bin/zaf install zaf
	if  ! zaf_check_agent_config; then
		echo "Something is wrong with zabbix agent config."
		echo "Ensure that zabbix_agentd reads ${ZAF_AGENT_CONFIG}"
		echo "and there is Include=${ZAF_AGENT_CONFIGD} directive inside."
		echo "Does ${ZAF_AGENT_RESTART} work?"
		exit 1
	fi
	rm -rif ${ZAF_TMP_DIR}
	echo "Install OK. Use 'zaf' without parameters to continue."
	;;
*)
	echo
	echo "Please specify how to install."
	echo "ZAF_CONFIG_OPTION=value [...] install.sh {silent|interactive} Z_option=value [...]"
	echo "Example 1 (default install): install.sh silent"
	echo 'Example 2 (preconfigure agent options): install.sh silent Z_Server=zabbix.server Z_ServerActive=zabbix.server Z_Hostname=$(hostname)'
	echo "Example 3 (preconfigure zaf packaging system to use): ZAF_PKG=dpkg install.sh silent"
	echo "Example 4 (interactive): install.sh interactive"
	echo
	exit 1
esac



