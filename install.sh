#!/bin/sh

ZAF_CFG_FILE=/etc/zaf.conf

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
		echo "Got $2 <$1> from ENV: $opt" >&2
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
		echo "Got $2 <$1> from Defaults: $opt" >&2
	else
		echo "Got $2 <$1> from USER: $opt"
	fi
	eval "$1='$opt'"	
}

# Sets option to zaf.conf
# $1 option name
# $2 option value
zaf_set_option(){
	if ! grep -q "^$1=" ${ZAF_CFG_FILE}; then
		echo "$1='$2'" >>${ZAF_CFG_FILE}
		echo "Saving $1 to $2 in ${ZAF_CFG_FILE}" >&2
	fi
}

getrest(){
	if [ -f "$(dirname $0)/$1" ]; then
		echo "$(dirname $0)/$1"
	else
		wget https://raw.githubusercontent.com/limosek/zaf/master/$1 -O- >${ZAF_TMP_DIR}/$(basename $1)
		echo ${ZAF_TMP_DIR}/$(basename $1)
	fi
}

zaf_detect_pkg() {
	if which dpkg >/dev/null; then
		ZAF_PKG="dpkg"
		return
	fi
	if which opkg >/dev/null; then
		ZAF_PKG="opkg"
		return
	fi
	if which rpm >/dev/null; then
		ZAF_PKG="rpm"
		return
	fi
}

zaf_no_perms(){
	echo "No permissions! to $1! Please become root or give perms. Exiting."
	exit 2
}

zaf_configure(){

	zaf_detect_pkg ZAF_PKG "Packaging system to use" "$(zaf_detect_pkg)"	
	zaf_get_option ZAF_TMP_DIR "Tmp directory" "/tmp/zaf"
	zaf_get_option ZAF_LIB_DIR "Libraries directory" "/usr/lib/zaf"
	zaf_get_option ZAF_PLUGINS_DIR "Plugins directory" "${ZAF_LIB_DIR}/plugins"
	zaf_get_option ZAF_PLUGINS_REPO "Plugins reposiory" "git://github.com/limosek/zaf-plugins.git"
	zaf_get_option ZAF_AGENT_CONFIG "Zabbix agent config" "/etc/zabbix/zabbix_agentd.conf"
	zaf_get_option ZAF_AGENT_CONFIGD "Zabbix agent config.d" "/etc/zabbix/zabbix_agentd.conf.d/"
	zaf_get_option ZAF_AGENT_BIN "Zabbix agent binary" "/usr/sbin/zabbix_agentd"
	zaf_get_option ZAF_AGENT_RESTART "Zabbix agent restart cmd" "service zabbix-agent restart"
	
	if ! which $ZAF_AGENT_BIN >/dev/null; then
		echo "Zabbix agent not installed? Use ZAF_ZABBIX_AGENT_BIN env variable to specify location. Exiting."
		exit 3
	fi
	if ! [ -f "${ZAF_CFG_FILE}" ]; then
		touch "${ZAF_CFG_FILE}" || zaf_no_perms "${ZAF_CFG_FILE}"
	fi
	
	zaf_set_option ZAF_PKG "${ZAF_PKG}"
	zaf_set_option ZAF_TMP_DIR "$ZAF_TMP_DIR"
	zaf_set_option ZAF_LIB_DIR "$ZAF_LIB_DIR"
	zaf_set_option ZAF_PLUGINS_DIR "$ZAF_PLUGINS_DIR"
	zaf_set_option ZAF_PLUGINS_REPO "$ZAF_PLUGINS_REPO"
	zaf_set_option ZAF_AGENT_CONFIG "$ZAF_AGENT_CONFIG"
	zaf_set_option ZAF_AGENT_CONFIGD "$ZAF_AGENT_CONFIGD"
	zaf_set_option ZAF_AGENT_BIN "$ZAF_AGENT_BIN"
	zaf_set_option ZAF_AGENTRESTART "$ZAF_AGENT_RESTART"
}

if [ -f "${ZAF_CFG_FILE}" ]; then
	. "${ZAF_CFG_FILE}"
fi

case $1 in
*)
	zaf_configure
	rm -rif ${ZAF_TMP_DIR}
	install -d ${ZAF_TMP_DIR}
	install -d ${ZAF_LIB_DIR}
	install -d ${ZAF_PLUGINS_DIR}
	install $(getrest lib/zaf.lib.sh) ${ZAF_LIB_DIR}/
	mkdir -p ${ZAF_PLUGINS_DIR}
	echo "UserParameter=zaf.version,echo master" >${ZAF_AGENT_CONFIGD}/zaf_base.conf
	install $(getrest zaf) /usr/bin 
	echo "Install OK. Installing plugins (${ZAF_DEFAULT_PLUGINS})."
	if  ! /usr/bin/zaf check-agent-config; then
		echo "Something is wrong with zabbix agent config."
		echo "Ensure that zabbix_agentd reads ${ZAF_AGENT_CONFIG}"
		echo "and there is Include=${ZAF_AGENT_CONFIGD} directive inside."
		echo "Does ${ZAF_AGENT_RESTART} work?"
		exit 1
	fi
	for plugin in ${ZAF_DEFAULT_PLUGINS}; do
		/usr/bin/zaf install $plugin || exit $?
	done
	rm -rif ${ZAF_TMP_DIR}
	echo "Done"
	;;
esac



