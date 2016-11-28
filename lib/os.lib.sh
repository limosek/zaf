# Os related functions

zaf_preconfigure_os_openwrt() {
    ZAF_AGENT_RESTART="zaf agent-config ; /etc/init.d/zabbix_agentd restart"
    ZAF_AGENT_CONFIGD="/var/run/zabbix_agentd.conf.d/"
    ZAF_AGENT_CONFIG="/etc/zabbix_agentd.conf"
    ZAF_AGENT_PKG="zabbix-agentd"
    ZAF_CURL_INSECURE=1
}
zaf_preconfigure_os_beesip() {
   zaf_preconfigure_os_openwrt
} 

zaf_preconfigure_os_freebsd() {
    ZAF_AGENT_PKG="zabbix3-agent"
    ZAF_AGENT_CONFIG="/usr/local/etc/zabbix3/zabbix_agentd.conf"
    ZAF_AGENT_CONFIGD="/usr/local/etc/zabbix3/zabbix_agentd.conf.d/"
    ZAF_AGENT_BIN="/usr/local/sbin/zabbix_agentd"
    ZAF_AGENT_RESTART="service zabbix_agentd restart"
    ZAF_SUDOERSD="/usr/local/etc/sudoers.d"
}

zaf_postconfigure_os_openwrt() {
	if ! grep -q "zaf agent-config" /etc/init.d/zabbix_agentd; then
		sed -i 's/uci2config $NAME/uci2config $NAME; zaf agent-config/' /etc/init.d/zabbix_agentd
	fi
}

zaf_postconfigure_os_beesip() {
	zaf_postconfigure_os_openwrt
}

zaf_which() {
	if which >/dev/null 2>/dev/null; then
		which "$1"
	else
		for i in /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin; do
			[ -x $i/$1 ] && { echo $i/$1; return; }
		done
		return 1
	fi
}

zaf_detect_system() {
	ZAF_FILES_UID=zabbix
	ZAF_FILES_GID=zabbix
	ZAF_FILES_UMASK=0770
	if zaf_which dpkg >/dev/null; then
		ZAF_PKG=dpkg
		ZAF_OS=$(lsb_release -is|zaf_tolower)
		ZAF_OS_CODENAME=$(lsb_release -cs|zaf_tolower)
		ZAF_CURL_INSECURE=0
		ZAF_AGENT_PKG="zabbix-agent"
		return
	else if zaf_which rpm >/dev/null; then
		ZAF_PKG="rpm"
		ZAF_OS=$(lsb_release -is|zaf_tolower)
		ZAF_OS_CODENAME=$(lsb_release -cs|zaf_tolower)
		ZAF_CURL_INSECURE=0
		ZAF_AGENT_PKG="zabbix-agent"
		return
	else if zaf_which opkg >/dev/null; then
		ZAF_PKG="opkg"
		. /etc/openwrt_release
		ZAF_OS="$(echo $DISTRIB_ID|zaf_tolower)"
		ZAF_OS_CODENAME="$(echo $DISTRIB_CODENAME|zaf_tolower)"
		return	
	else if zaf_which pkg >/dev/null; then
		ZAF_PKG="pkg"
		ZAF_OS="freebsd"
		ZAF_OS_CODENAME="$(freebsd-version|cut -d '-' -f 1)"
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
    [ "$USER" = "root" ] || [ "$EUID" = "0" ] || [ -n "$ZAF_ISROOT" ]
}

# Install file, bin or directory and respect install prefix 
# $1 - src file
# $2 - directory
zaf_install(){
    zaf_dbg "Install file $1 to $INSTALL_PREFIX/$2/$(basename $1)"
    $ZAF_DO cp "$1" "$INSTALL_PREFIX/$2/$(basename $1)" || zaf_err "Cannot create file $INSTALL_PREFIX/$2/$(basename $1)!"
}
# $1 - src file
# $2 - directory
zaf_install_bin(){
    zaf_dbg "Install binary $1 to $INSTALL_PREFIX/$2/$(basename $1)"
    $ZAF_DO cp "$1" "$INSTALL_PREFIX/$2/$(basename $1)" || zaf_err "Cannot create binary $INSTALL_PREFIX/$2/$(basename $1)!"
    $ZAF_DO chmod +x "$INSTALL_PREFIX/$2/$(basename $1)"
}
# $1 - directory
zaf_install_dir(){
    zaf_dbg "Install directory $1 to $INSTALL_PREFIX/$1"
    $ZAF_DO mkdir -p "$INSTALL_PREFIX/$1" || zaf_err "Cannot create directory $INSTALL_PREFIX/$1!"
}
# $1 - file
zaf_touch(){
    zaf_dbg "Touch $INSTALL_PREFIX/$1"
    $ZAF_DO touch "$INSTALL_PREFIX/$1"
}
# $1 - directory
zaf_uninstall(){
    if [ -n "$INSTALL_PREFIX" ]; then
    	zaf_dbg "Removing $INSTALL_PREFIX/$1"
	$ZAF_DO rm -rf "$INSTALL_PREFIX/$1"
    else
	zaf_dbg "Removing $1"
	$ZAF_DO rm -rf "$1"
    fi
}

# Automaticaly install agent on debian
# For another os, create similar function (install_zabbix_centos)
zaf_install_agent_debian() {
    zaf_fetch_url "http://repo.zabbix.com/zabbix/3.0/debian/pool/main/z/zabbix-release/zabbix-release_3.0-1+${ZAF_OS_CODENAME}_all.deb" >"/tmp/zaf-installer/zabbix-release_3.0-1+${ZAF_OS_CODENAME}_all.deb" \
	&& dpkg -i "/tmp/zaf-installer/zabbix-release_3.0-1+${ZAF_OS_CODENAME}_all.deb" \
	&& apt-get update \
	&& apt-get install -y -q $ZAF_AGENT_PKG
}

zaf_install_agent_opkg() {
    opkg update && \
    opkg install $ZAF_AGENT_PKG
}

# Check if dpkg dependency is met
# $* - packages
zaf_check_deps_dpkg() {
	for i in $*; do
		dpkg-query -f '${db:Status-Status},${Package}\n' -W $* 2>/dev/null | grep -q "^installed" 
	done
}

# Check if dpkg dependency is met
# $* - packages
zaf_check_deps_rpm() {
	for i in $*; do
		rpm --quiet -qi $i | grep -q $i
	done
}

# Check if dpkg dependency is met
# $* - packages
zaf_check_deps_opkg() {
	local p
	for p in $*; do
		opkg info $p | grep -q 'Package:' || { return 1; }
	done
}

# Check if pkg dependency is met
# $* - packages
zaf_check_deps_pkg() {
	local p
	for p in $*; do
		pkg query -x "Package: %n" $p| grep -q 'Package:' || { return 1; }
	done
}


