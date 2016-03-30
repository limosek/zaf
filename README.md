# Zabbix Agent Framework

This tool is used to maintain external zabbix checks in *one place*. There are lot of places where it is possible to download many external checks. 
But there is problem with installation, update and centralised management. This tool should do all of this in easy steps. In future it can be *starting point* to
install and configure zabbix agent on systems with one step. Primary goal is not to make all plugins available here but to be able to use any plugin and decentralized development.
If you are maintainer of some external check, it is enough to create zaf file in  your repo and use zaf installer everywhere.

## Features

* Minimal dependencies. At this time, only sh, sed, awk and curl
* Minimal runtime version to fit on different systems (openwrt, debian, ubuntu, ...)
* Modular. Zaf module can be maintained externaly from this framework
* Sharing code. Many zabbix external checks share common shell functions. 
* Zabbix discovery simplification. Creating zabbix item for discovery is not so easy in shell based system and result is not nice. But you can use framework function to do so.
* OS packaging support. 

## Installing Zaf
You need to be root and you must have curl installed on your system. Depending on your system, github certificates may not be available so you have to use *-k* option for curl (insecure). Default installation type is silent. So there will be no questions and everything will be autodetected. This command should be used on most systems:
```
curl https://raw.githubusercontent.com/limosek/zaf/master/install.sh | sh
```
but in openwrt, you should use this:
```
curl -k https://raw.githubusercontent.com/limosek/zaf/master/install.sh | sh
```

## Example
Best way how to explain everything is example. Supposing we are working on debian-like system.
```
curl https://raw.githubusercontent.com/limosek/zaf/master/install.sh | sudo sh
sudo zaf install process-info
sudo zaf install http://other.check.domain/check/
zaf make-deb
zaf make-opkg
zaf make-rpm
zaf self-upgrade
```

## Zaf plugin
Zaf plugin is set of configuration options and binaries which are needed for specific checks. For example, to monitor postfix, we need some cron job which is automaticaly run and next ti this, some external items which has to be configured.

## How it works
There is central zaf reposirory on github. There are basic checks and zaf code itself. Next to this, each project can have its own zaf structure. Adding url of plugin to zaf will make it useable and updatable. 

## Zaf plugin structure
Each zaf plugin url MUST have this items:
```
/plugin/README.md	# Documentation
/plugin/control		# Control file	
/plugin/template.xml	# Template for Zabbix

```

## Zaf control file 
Control files are similar to Debian Control files
```
will be explained

```


