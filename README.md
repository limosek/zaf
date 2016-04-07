# Zabbix Agent Framework

This tool is used to maintain external zabbix checks in *one place*. There are lot of places where it is possible to download many external checks. 
But there is problem with installation, update and centralised management. This tool should do all of this in easy steps. In future it can be *starting point* to
install and configure zabbix agent on systems with one step. Primary goal is not to make all plugins available here but to be able to use any plugin and decentralized development.
If you are maintainer of some external check, it is enough to create zaf file in  your repo and use zaf installer everywhere.

## Motivation

Did you install lot of zabbix agents and try to setup similar common user parameters? Do you want to setup them all? Do you want to change some zabbix agent options on lot of system? Do you want to write your own simple check or discovery rule for zabbix and it is nightmare to deploy same script on more zabbix agents? Are you tired searching some system specific agent check and setup them individualy?
So zaf is here for you :)

## Features

* Minimal dependencies. At this time, only sh, sed, awk and curl
* Minimal code (less than 50kb of code)
* Minimal runtime version to fit on different systems (openwrt, debian, ubuntu, ...)
* Modular. Zaf module can be maintained externaly from this framework
* Sharing code. Many zabbix external checks share common shell functions. 
* Simplification of userparameter functions (does not have to be one-line long code)
* Zabbix discovery simplification. Creating zabbix item for discovery is not so easy in shell based system and result is not nice. But you can use framework function to do so.
* OS packaging support (in future).
* Zabbix agent autoinstallation and autoconfiguration suitable to use in puppet or another tool 
* OS packaging support

## Installing Zaf
You need to be root and you must have curl installed on your system. Depending on your system, github certificates may not be available so you have to use *-k* option for curl (insecure). Default installation type is silent. So there will be no questions and everything will be autodetected. This simple command should be used on most systems:
```
curl -k https://raw.githubusercontent.com/limosek/zaf/1.0/install.sh | sh
```

### Install options and autoconfiguration
General parameters for install.sh on any system (simplest way how to install)
```
curl -k https://raw.githubusercontent.com/limosek/zaf/1.0/install.sh | \
   sh -s {auto|interactive|debug-auto|debug-interactive} [Agent-Options] [Zaf-Options]
```
or use git version:
```
git clone https://github.com/limosek/zaf.git; cd zaf; git checkout 1.0
./install.sh {auto|interactive|debug-auto|debug-interactive} [Agent-Options] [Zaf-Options]
 Agent-Options: A_Option=value [...]
 Zaf-Options: ZAF_OPT=value [...]
```

So you can pass ANY configuration of your zabbix agent directly to installer prefixing it with *Z_*. Please note that options are *Case Sensitive*! 
Next to this, you can pass ANY zaf config options by *ZAF_* prefix. Yes, we need some more documentation of ZAF options. Please look at least here: https://github.com/limosek/zaf/blob/master/install.sh#L160
Installer will try to autoguess suitable config options for your system.
Now everything was tested on Debian and OpenWrt. If somebody is interrested in, you can help and test with some rpm specific functions.

### Example
Suppose you want to autoinstall agent on clean system. You need only curl installed. Everything else is one-cmd process.
This command will install zaf, install zabbix-agent if necessary and sets zabbix variables on agent to reach server. This command can be automatized by puppet or another deploying system.
```
curl -k https://raw.githubusercontent.com/limosek/zaf/1.0/install.sh | sh -s auto \
  Z_Server=zabbix.server.local \
  Z_ServerActive=zabbix.server.local \
  Z_HostnameItem=system.hostname Z_RefreshActiveChecks=60 \
  ZAF_PLUGINS_GITURL="git://gitserver.local"
```

### Packaged version
You can make your own deb package with preconfigured option. It is up to you to put it to right APT repository and install. 
```
git clone https://github.com/limosek/zaf.git; cd zaf; git checkout 1.0; cd ..
git clone https://github.com/limosek/zaf-plugins.git
cd zaf && make deb PLUGINS="$PWD/../zaf-plugins/zaf $PWD/../zaf-plugins/fsx" ZAF_OPTIONS="ZAF_GIT=0" AGENT_OPTIONS="Z_Server=zabbix.server Z_ServerActive=zabbix.server Z_StartAgents=8"
sudo dpkg -i out/zaf.deb
```

## Zaf plugin
Zaf plugin is set of configuration options and binaries which are needed for specific checks. For example, to monitor postfix, we need some cron job which is automaticaly run and next ti this, some external items which has to be configured. Do not mix zaf plugin and zabbix plugin. While zaf plugin is set of scripts or binaries external to zabbix agent, zabbix plugin is internal zabbix lodadable module.

## Zaf utility
Zaf binary can be installed on any system from openwrt to big system. It has minimal dependencies and is shell based. Is has minimal size (up to 50kb of code). It can be used for installing, removing and testing zaf plugin items. Zaf should be run as root.
```
zaf
/usr/bin/zaf Version trunk. Please use some of this commands:
/usr/bin/zaf update			To update repo
/usr/bin/zaf plugins		To list installed plugins
/usr/bin/zaf show [plugin]		To show installed plugins or plugin info
/usr/bin/zaf items [plugin]		To list all suported items [for plugin]
/usr/bin/zaf test [plugin[.item]]	To test all suported items [for plugin]
/usr/bin/zaf install plugin		To install plugin
/usr/bin/zaf remove plugin		To remove plugin
/usr/bin/zaf self-upgrade		To self-upgrade zaf
/usr/bin/zaf self-remove		To self-remove zaf and its config

```

### Installing plugin
To install plugin from common repository. If git is available, local git repo is tried first. If not, remote https repo is tried second.
```
zaf install zaf
```
To install plugin from external source, external plugin has to be "zafable". This means that its maitainer will create control.zaf file located at http://some.project/plugin/control.zaf. Nothing else.
```
zaf install http://some.project/plugin
```
To install plugin from local directory:
```
zaf install /some/plugin
```
Installer will look into control file, run setup task defined there, fetch binaries and scripts needed for specific plugin and test system dependencies for that plugin. If everything is OK, zaf_plugin.conf is created in zabbix_agentd.d conf directory and userparameters are automaticaly added.

## How it works
Zaf installer will do most of actions needed to monitor some specific plugin items. Configuration of plugin is very simple and text readable. Anybody can write its own plugin or make its plugin "zafable". It is enough to create *control.zaf" file. For example, look into https://github.com/limosek/zaf-plugins repository. This is default repository for zaf. 

## I want to make my own plugin!
Great! Look into https://github.com/limosek/zaf-plugins repository, look to control files and try to create your own. It is easy! You can contact me for help.

## I want to help with zaf!
Great! I have no time for testing on systems and writing system specific hacks. Next to this, templates should be optimized and tested for basic plugins. 



