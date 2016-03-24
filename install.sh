#!/bin/sh

if ! [ "$(basename $0)" = "install.sh" ]; then
	# We are runing from stdin
	set -e
	mkdir -p /tmp/zaf-installer \
	&& cd /tmp/zaf-installer \
	&& curl -f -k -s -L -o - https://raw.githubusercontent.com/limosek/zaf/master/install.sh >install.sh \
	&& chmod +x install.sh \
	&& exec ./install.sh defconf
fi

ZAF_CFG_FILE=/etc/zaf.conf

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

zaf_detect_pkg() {
	if which dpkg >/dev/null; then
		ZAF_PKG="dpkg"
		ZAF_CURL_INSECURE=0
		return
	fi
	if which opkg >/dev/null; then
		ZAF_PKG="opkg"
		ZAF_AGENT_RESTART="/etc/init.d/zabbix_agentd restart"
		ZAF_AGENT_CONFIGD="/var/run/zabbix_agentd.conf.d/"
		ZAF_AGENT_CONFIG="/etc/zabbix_agentd.conf"
		ZAF_CURL_INSECURE=1
		return
	fi
	if which rpm >/dev/null; then
		ZAF_PKG="rpm"
		ZAF_CURL_INSECURE=0
		return
	fi
}

zaf_no_perms(){
	echo "No permissions! to $1! Please become root or give perms. Exiting."
	exit 2
}

zaf_configure(){

	[ "$1" = "user" ] && ZAF_DEBUG=1
	zaf_detect_pkg ZAF_PKG "Packaging system to use" "$(zaf_detect_pkg)" "$1"
	zaf_get_option ZAF_CURL_INSECURE "Insecure curl (accept all certificates)" "1" "$1"
	zaf_get_option ZAF_TMP_BASE "Tmp directory prefix (\$USER will be added)" "/tmp/zaf" "$1"
	zaf_get_option ZAF_LIB_DIR "Libraries directory" "/usr/lib/zaf" "$1"
	zaf_get_option ZAF_PLUGINS_DIR "Plugins directory" "${ZAF_LIB_DIR}/plugins" "$1"
	zaf_get_option ZAF_PLUGINS_REPO "Plugins reposiory" "https://raw.githubusercontent.com/limosek/zaf-plugins/master/" "$1"
	zaf_get_option ZAF_REPO_DIR "Plugins directory" "${ZAF_LIB_DIR}/repo" "$1"
	zaf_get_option ZAF_AGENT_CONFIG "Zabbix agent config" "/etc/zabbix/zabbix_agentd.conf" "$1"
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
reconf)
	zaf_configure user
	$0 install
	;;
defconf)
	zaf_configure silent
	$0 install
	;;
*)
	zaf_configure
	rm -rif ${ZAF_TMP_DIR}
	mkdir -p ${ZAF_TMP_DIR}
	mkdir -p ${ZAF_LIB_DIR}
	mkdir -p ${ZAF_PLUGINS_DIR}
	zaf_install $(zaf_getrest lib/zaf.lib.sh) ${ZAF_LIB_DIR}/zaf.lib.sh
	zaf_install $(zaf_getrest lib/jshn.sh) ${ZAF_LIB_DIR}/jshn.sh
	zaf_install_exe $(zaf_getrest lib/zaflock) ${ZAF_LIB_DIR}/zaflock
	mkdir -p ${ZAF_TMP_DIR}/p/zaf
	zaf_install $(zaf_getrest control) ${ZAF_TMP_DIR}/p/zaf/
	zaf_install $(zaf_getrest template.xml) ${ZAF_TMP_DIR}/p/zaf/
	mkdir -p ${ZAF_PLUGINS_DIR}
	zaf_install_exe $(zaf_getrest zaf) /usr/bin/zaf
	/usr/bin/zaf install ${ZAF_TMP_DIR}/p/zaf/
	if  ! /usr/bin/zaf check-agent-config; then
		echo "Something is wrong with zabbix agent config."
		echo "Ensure that zabbix_agentd reads ${ZAF_AGENT_CONFIG}"
		echo "and there is Include=${ZAF_AGENT_CONFIGD} directive inside."
		echo "Does ${ZAF_AGENT_RESTART} work?"
		exit 1
	fi
	rm -rif ${ZAF_TMP_DIR}
	echo "Install OK. Use 'zaf' without parameters to continue."
	;;
esac



