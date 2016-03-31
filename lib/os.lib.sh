# Os related functions

zaf_configure_os_openwrt() {
    ZAF_AGENT_RESTART="/etc/init.d/zabbix_agentd restart"
    ZAF_AGENT_CONFIGD="/var/run/zabbix_agentd.conf.d/"
    ZAF_AGENT_CONFIG="/etc/zabbix_agentd.conf"
    ZAF_AGENT_PKG="zabbix-agentd"
    ZAF_CURL_INSECURE=1
}

zaf_detect_system() {
	if which dpkg >/dev/null; then
		ZAF_PKG=dpkg
		ZAF_OS=$(lsb_release -is|tr '[:upper:]' '[:lower:]')
		ZAF_OS_CODENAME=$(lsb_release -cs|tr '[:upper:]' '[:lower:]')
		ZAF_CURL_INSECURE=0
		ZAF_AGENT_PKG="zabbix-agent"
		return
	else if which rpm >/dev/null; then
		ZAF_PKG="rpm"
		ZAF_OS=$(lsb_release -is|tr '[:upper:]' '[:lower:]')
		ZAF_OS_CODENAME=$(lsb_release -cs|tr '[:upper:]' '[:lower:]')
		ZAF_CURL_INSECURE=0
		ZAF_AGENT_PKG="zabbix-agent"
		return
	else if which opkg >/dev/null; then
		ZAF_PKG="opkg"
		. /etc/openwrt_release
		ZAF_OS="$(echo $DISTRIB_ID|tr '[:upper:]' '[:lower:]')"
		ZAF_OS_CODENAME="$(echo $DISTRIB_CODENAME|tr '[:upper:]' '[:lower:]')"
		return	
	else
		ZAF_PKG="unknown"
		ZAF_OS="unknown"
		ZAF_OS_CODENAME="unknown"
		ZAF_AGENT_PKG=""
                return
	  fi
	 fi
	fi
}

# Run OS specific command
# $1 - name of the function.
# all variants will be tested. (name_os_codename, name_os, name_{dpkg|opkg|rpm}, name )
zaf_os_specific(){
    local func="$1"
    
    if type "${func}_${ZAF_OS}_${ZAF_OS_CODENAME}" >/dev/null 2>/dev/null; then
        eval "${func}_${ZAF_OS}_${ZAF_OS_CODENAME} $2 $3 $4 $5 $6"
    else if type "${func}_${ZAF_OS}" >/dev/null 2>/dev/null; then
        eval "${func}_${ZAF_OS} $2 $3 $4 $5 $6" 
    else if type "${func}_${ZAF_PKG}" >/dev/null 2>/dev/null; then
        eval "${func}_${ZAF_PKG} $2 $3 $4 $5 $6"
    else
        zaf_dbg "No OS/packager specific implementation for $1"
      fi
     fi
    fi
}

zaf_is_root(){
    [ "$USER" = "root" ]
}

# Install file, bin or directory and respect install prefix 
# $1 - src file
# $2 - directory
zaf_install(){
    zaf_dbg "Install file $1 to $INSTALL_PREFIX/$2/$(basename $1)"
    cp "$1" "$INSTALL_PREFIX/$2/$(basename $1)"
}
# $1 - src file
# $2 - directory
zaf_install_bin(){
    zaf_dbg "Install binary $1 to $INSTALL_PREFIX/$2/$(basename $1)"
    cp "$1" "$INSTALL_PREFIX/$2/$(basename $1)"
    chmod +x "$INSTALL_PREFIX/$2/$(basename $1)"
}
# $1 - directory
zaf_install_dir(){
    zaf_dbg "Install directory $1 to $INSTALL_PREFIX/$1"
    mkdir -p "$INSTALL_PREFIX/$1"
}
# $1 - file
zaf_touch(){
    zaf_dbg "Touch $INSTALL_PREFIX/$1"
    touch "$INSTALL_PREFIX/$1"
}

# Automaticaly install agent on debian
# For another os, create similar function (install_zabbix_centos)
zaf_install_agent_debian() {
    zaf_fetch_url "http://repo.zabbix.com/zabbix/3.0/debian/pool/main/z/zabbix-release/zabbix-release_3.0-1+${ZAF_CODENAME}_all.deb" >"/tmp/zaf-installer/zabbix-release_3.0-1+${ZAF_CODENAME}_all.deb" \
	&& dpkg -i "/tmp/zaf-installer/zabbix-release_3.0-1+${ZAF_CODENAME}_all.deb" \
	&& apt-get update \
	&& apt-get install $ZAF_AGENT_PKG
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


