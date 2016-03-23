#!/bin/sh

readopt(){
	echo -n "$1 [$2]: "
	read opt
	[ -z "$opt" ] && opt="$2"
}

getrest(){
	if [ -f "$(dirname $0)/$1" ]; then
		echo "$(dirname $0)/$1"
	else
		wget https://raw.githubusercontent.com/limosek/zaf/master/$1 -O- >${ZAF_TMP_DIR}/$(basename $1)
		echo ${ZAF_TMP_DIR}/$(basename $1)
	fi
}

preconf(){
  echo "Zabbix Agent Framework installer."
  if ! which zabbix_agentd >/dev/null; then
	echo "Zabbix agent not installed? Exiting."
	exit 3
  fi
  if ! [ -f "/etc/zaf.conf" ] || [ -n "$1" ]; then
	readopt "Tmp directory" "/tmp/zaf"
	ZAF_TMP_DIR="$opt"

	readopt "Libraries directory" "/usr/lib/zaf"
	ZAF_LIB_DIR="$opt"

	readopt "Plugins directory" "${ZAF_LIB_DIR}/plugins"
	ZAF_PLUGINS_DIR="$opt"

	readopt "Git plugins directory" "${ZAF_LIB_DIR}/repo"
	ZAF_REPO_DIR="$opt"

	readopt "Plugins repository" "https://github.com/limosek/zaf.git/plugins"
	ZAF_PLUGINS_REPO="$opt"

	readopt "Default plugins to install" "process-info"
	ZAF_DEFAULT_PLUGINS="$opt"

	readopt "Zabbix agent config" "/etc/zabbix/zabbix_agentd.conf"
	ZAF_AGENT_CONFIG="$opt"

	readopt "Zabbix agent restart cmd" "service zabbix-agent restart"
	ZAF_AGENT_RESTART="$opt"

	if which sudo >/dev/null; then
		sudo=1
	else
		sudo=0
	fi
	readopt "Use sudo" "$sudo"
	ZAF_SUDO="$opt"
  else
	echo "Skipping configuration. Config file /etc/zaf.conf already exists."
	. /etc/zaf.conf
  fi
  if [ "$USERNAME" = "root" ]; then
	echo "We are root. That is OK."
  else
	if [ "$ZAF_SUDO" = 1 ] && ! which sudo >/dev/null; then
		echo "We are not root and sudo is not installed. Cannot continue."
		exit 2
	fi
	echo "We are not root. Assuming we have enough privileges."
  fi
  echo "ZAF_LIB_DIR='$ZAF_LIB_DIR'" >/etc/zaf.conf || { echo "Not enough privileges. Please become root!"; exit 2; }
  echo "ZAF_TMP_DIR='$ZAF_TMP_DIR'" >>/etc/zaf.conf
  echo "ZAF_PLUGINS_DIR='$ZAF_PLUGINS_DIR'" >>/etc/zaf.conf
  echo "ZAF_REPO_DIR='$ZAF_REPO_DIR'" >>/etc/zaf.conf
  echo "ZAF_PLUGINS_REPO='$ZAF_PLUGINS_REPO'" >>/etc/zaf.conf
  echo "ZAF_AGENT_RESTART='$ZAF_AGENT_RESTART'" >>/etc/zaf.conf
  echo "ZAF_AGENT_CONFIG='$ZAF_AGENT_CONFIG'" >>/etc/zaf.conf
  echo "ZAF_SUDO='$ZAF_SUDO'" >>/etc/zaf.conf
}

case $1 in
reconf)
	preconf force
	export ZAF_DEFAULT_PLUGINS
	$0 install
	;;
*)
	preconf
	rm -rif ${ZAF_TMP_DIR}
	install -d ${ZAF_TMP_DIR}
	install -d ${ZAF_LIB_DIR}
	install -d ${ZAF_PLUGINS_DIR}
	if [ -n "${ZAF_PLUGINS_REPO}" ]; then
		if ! [ -d "${ZAF_REPO_DIR}" ]; then
			git clone  "${ZAF_PLUGINS_REPO}" "${ZAF_REPO_DIR}"
		else
			(cd "${ZAF_REPO_DIR}" && git pull)
		fi
	fi
	install $(getrest lib/zaf.lib.sh) ${ZAF_LIB_DIR}/
	mkdir -p ${ZAF_PLUGINS_DIR}
	install $(getrest zaf) /usr/bin 
	echo "Install OK. Installing plugins (${ZAF_DEFAULT_PLUGINS})."
	for plugin in ${ZAF_DEFAULT_PLUGINS}; do
		/usr/bin/zaf install $plugin || exit $?
	done
	echo "Done"
	;;
esac



