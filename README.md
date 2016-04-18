# Zabbix (Agent) Framework

This tool is used to maintain external zabbix checks in *one place*. There are lot of places where it is possible to download many external checks. 
But there is problem with installation, update and centralised management. This tool should do all of this in easy steps. In future it can be *starting point* to
install and configure zabbix agent on systems with one step. Primary goal is not to make all plugins available here but to be able to use any plugin and decentralized development.
If you are maintainer of some external check, it is enough to create zaf file in  your repo and use zaf installer everywhere. 

Next to this, this tool can even communicate with Zabbix API with *NO dependencies* to high level languages. Shell, sed and awk only.

## Motivation

Did you install lot of zabbix agents and try to setup similar common user parameters? Do you want to setup them all? Do you want to change some zabbix agent options on lot of system? Do you want to write your own simple check or discovery rule for zabbix and it is nightmare to deploy same script on more zabbix agents? Are you tired searching some system specific agent check and setup them individualy? Do you want to auto simple backup all hosts in your zabbix to xml files? Or do you want to do some scripting on host depending on Zabbix server configuration?
So zaf is here for you :)

## Features

* Minimal dependencies. At this time, only sh, sed, awk and curl
* Minimal code (less than 50kb of code)
* Minimal runtime version to fit on different systems (openwrt, debian, ubuntu, ...)
* Modular. Zaf module can be maintained externaly from this framework
* Sharing code. Many zabbix external checks share common shell functions. 
* Simplification of userparameter functions (does not have to be one-line long code)
* Zabbix discovery simplification. Creating zabbix item for discovery is not so easy in shell based system and result is not nice. But you can use framework function to do so.
* Zabbix agent autoinstallation and autoconfiguration suitable to use in puppet or another tool 
* OS packaging support
* Zabbix API support

## Installing Zaf
You need to be root and you must have curl installed on your system. Depending on your system, github certificates may not be available so you have to use *-k* option for curl (insecure). Default installation type is silent. So there will be no questions and everything will be autodetected. This simple command should be used on most systems:
```
curl -k https://raw.githubusercontent.com/limosek/zaf/1.2/install.sh | sh
```

### Install options and autoconfiguration
General parameters for install.sh on any system (simplest way how to install)
```
curl -k https://raw.githubusercontent.com/limosek/zaf/1.2/install.sh | \
   sh -s {auto|interactive|debug-auto|debug-interactive} [Agent-Options] [Zaf-Options]
```
or use git version:
```
git clone https://github.com/limosek/zaf.git; cd zaf; git checkout 1.2
./install.sh {auto|interactive|debug-auto|debug-interactive} [Agent-Options] [Zaf-Options]
 Agent-Options: Z_Option=value [...]
 Zaf-Options: ZAF_OPT=value [...]
 To unset Agent-Option use Z_Option=''
```

So you can pass ANY configuration of your zabbix agent directly to installer prefixing it with *Z_*. Please note that options are *Case Sensitive*! 
Next to this, you can pass ANY zaf config options by *ZAF_* prefix. Interresting ZAF options:
```
 # If we want to use GIT and local GIT repository
 ZAF_GIT='1'# Default

 # Git repository. Can be your local version
 ZAF_REPO_GITURL='https://github.com/limosek/zaf-plugins.git'

 # Where to install plugins
 ZAF_PLUGINS_DIR='/usr/lib/zaf/plugins'

 # Plugins can be downloaded from http[s] too
 ZAF_REPO_URL='https://raw.githubusercontent.com/limosek/zaf-plugins/master/'

```

Installer will try to autoguess suitable config options for your system.
Now everything was tested on Debian and OpenWrt. If somebody is interrested in, you can help and test with some rpm specific functions. Remember that on some systems, default zabbix agent config is empty so you *need to* enter essential config options as parameters.

### Example
Suppose you want to autoinstall agent on clean system. You need only curl installed. Everything else is one-cmd process.
This command will install zaf, install zabbix-agent if necessary and sets zabbix variables on agent to reach server. This command can be automatized by puppet or another deploying system.
```
curl -k https://raw.githubusercontent.com/limosek/zaf/1.2/install.sh | sh -s auto \
  Z_Server=zabbix.server.local \
  Z_ServerActive=zabbix.server.local \
  Z_HostnameItem=system.hostname Z_RefreshActiveChecks=60 \
  ZAF_REPO_GITURL="git://gitserver.local"
```

### Packaged version
You can make your own deb package with preconfigured option. It is up to you to put it to right APT repository and install. 
```
git clone https://github.com/limosek/zaf.git \
 && cd zaf \
 && git checkout 1.2 \
 && git clone https://github.com/limosek/zaf-plugins.git \
 && make deb PLUGINS="./zaf-plugins/fsx" IPLUGINS="zaf" ZAF_OPTIONS="ZAF_GIT=0" AGENT_OPTIONS="Z_Server=zabbix.server Z_ServerActive=zabbix.server Z_StartAgents=8"
sudo dpkg -i out/zaf-1.2.deb
```
General usage:
```
make {deb|ipk|rpm} [PLUGINS="/dir/plg1 [/dir2]...] [IPLUGINS="plg1 [plg2]..."] [ZAF_OPTIONS="ZAF_cfg=val ..."] [AGENT_OPTIONS="Z_Server=host ..."]
PLUGINS are embedded into package. Has to be local directories accessible during build.
IPLUGINS will be downloaded and installed after package is installed. Can be name or url accessible after package installation.
```

## Zaf plugin
Zaf plugin is set of configuration options and binaries which are needed for specific checks. For example, to monitor postfix, we need some cron job which is automaticaly run and next ti this, some external items which has to be configured. Do not mix zaf plugin and zabbix plugin. While zaf plugin is set of scripts or binaries external to zabbix agent, zabbix plugin is internal zabbix lodadable module.

### Control file
Control file is main part of zaf plugin. It describes how to install plugin and defines all checks. In fact, simple control file can be enough to create zaf plugin because scripts can be embeded within. There are two kind of options: global and per item. Each option can be singleline:
```
Plugin: pluginname
```
or multiline:
```
Description::
  Zaf plugin for monitoring fail2ban with LLD
 Credits
  2014 dron, jiri.slezka@slu.cz
  2016 limo, lukas.macura@slu.cz
::
```
Items are enclosed like this:
```
Item some_item:
Description::
     Returns number of currently banned IPs for jail
::
Parameters: jail
Cmd: sudo fail2ban-client status $1 | grep "Currently banned:" | grep -o -E "[0-9]*"
/Item
```
During plugin installation, zaf will check all dependencies, do install binaries and generates apropriate zabbix.conf.d entries.  Look into https://github.com/limosek/zaf-plugins repository for more examples.

## Zaf utility
Zaf binary can be installed on any system from openwrt to big system. It has minimal dependencies and is shell based. Is has minimal size (up to 50kb of code). It can be used for installing, removing and testing zaf plugin items. Zaf should be run as root.
```
./zaf 
./zaf Version 1.2. Please use some of this commands:
./zaf Cmd [ZAF_OPTION=value] [ZAF_CTRL_Option=value] [ZAF_CTRLI_Item_Option=value] ...
Plugin manipulation commands:
./zaf update                            To update repo (not plugins, similar to apt-get update)                         
./zaf upgrade                           To upgrade installed plugins from repo                                          
./zaf install plugin                    To install plugin                                                               
./zaf remove plugin                     To remove plugin                                                                

Plugin info commands:
./zaf plugins                           To list installed plugins                                                       
./zaf show [plugin]                     To show installed plugins or plugin info                                        
./zaf items [plugin]                    To list all suported items [for plugin]                                         

Plugin diagnostic commands:
./zaf test [plugin[.item]]              To test [all] suported items by zabbix_agentd [for plugin]                      
./zaf get [plugin[.item]]               To test [all] suported items by zabbix_get [for plugin]                         
./zaf precache [plugin[.item]]          To precache [all] suported items                                                

Zabbix API commands:
./zaf api                               To zabbix API functions. See ./zaf api for more info.                           

Agent config info commands:
./zaf userparms                         See userparms generated from zaf on stdout                                      
./zaf agent-config                      Reconfigure zabbix userparms in /etc/zabbix/zabbix_agentd.d                     

Zaf related commands:
./zaf self-upgrade                      To self-upgrade zaf                                                             
./zaf self-remove                       To self-remove zaf and its config                                               
./zaf cache-clean                       To remove all entries from cache                                                
```

Zaf can even communicate with zabbix server using its API.  If you set ZAF_ZBXAPI_URL, ZAF_ZBXAPI_USER and ZAF_ZBXAPI_PASS in /etc/zaf.conf, you can use it:
```
./zaf api command [parameters]
get-host-id host                        Get host id                                                                     
get-byid-host id [property]             Get host property from id. Leave empty property for JSON                        
get-template-id template                Get template id                                                                 
get-byid-template id [property]         Get template property from id. Leave empty property for JSON                    
get-map-id map                          Get map id                                                                      
get-byid-map id [property]              Get map property from id. Leave empty property for JSON                         
get-inventory host [fields]             Get inventory fields [or all fields]                                            
export-hosts dir [hg]                   Backup all hosts [in group hg] (get their config from zabbix and save to dir/hostname.xml)
export-host host                        Backup host (get config from zabbix to stdout)                                  
import-template {plugin|file}           Import template for plugin or from file                                         
export-template name                    Export template to stdout                                                       
export-templates dir                    Export all templates to dir
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



