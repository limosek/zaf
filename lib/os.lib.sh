# Os related functions

zaf_detect_system() {
	if which dpkg >/dev/null; then
		ZAF_PKG="dpkg"
		ZAF_OS=$(lsb_release -is)
		ZAF_OS_CODENAME=$(lsb_release -cs)
		ZAF_CURL_INSECURE=0
		ZAF_AGENT_PKG="zabbix-agent"
		return
	else if which rpm >/dev/null; then
		ZAF_PKG="rpm"
		ZAF_OS=$(lsb_release -is)
		ZAF_OS_CODENAME=$(lsb_release -cs)
		ZAF_CURL_INSECURE=0
		ZAF_AGENT_PKG="zabbix-agent"
		return
	else if which opkg >/dev/null; then
		ZAF_PKG="opkg"
		. /etc/openwrt_release
		ZAF_OS="$DISTRIB_ID"
		ZAF_OS_CODENAME="$DISTRIB_CODENAME"
		ZAF_AGENT_RESTART="/etc/init.d/zabbix_agentd restart"
		ZAF_AGENT_CONFIGD="/var/run/zabbix_agentd.conf.d/"
		ZAF_AGENT_CONFIG="/etc/zabbix_agentd.conf"
		ZAF_AGENT_PKG="zabbix-agentd"
		ZAF_CURL_INSECURE=1
		return	
	else
		ZAF_PKG="unknown"
		ZAF_OS="unknown"
		ZAF_OS_CODENAME="unknown"
		ZAF_AGENT_PKG=""
	  fi
	 fi
	fi
}

# Check if dpkg dependency is met
# $* - packages
zaf_check_deps_dpkg() {
	dpkg-query -f '${Package}\n' -W $* >/dev/null
}

# Check if dpkg dependency is met
# $* - packages
zaf_check_deps_rpm() {
	 rpm --quiet -qi $*
}

# Check if dpkg dependency is met
# $* - packages
zaf_check_deps_opkg() {
	local p
	for p in $*; do
		opkg info $p | grep -q 'Package:' || { echo "Missing package $p" >&2; return 1; }
	done
}

# Check dependency based on system
zaf_check_deps() {
	case $ZAF_PKG in
	dpkg)	zaf_check_deps_dpkg $*
		;;
	opkg)	zaf_check_deps_opkg $*
		;;
	rpm)	zaf_check_deps_rpm $*
		;;
	*)	return
		;;
	esac
}


