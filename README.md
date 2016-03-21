# zaf
Zabbix Agent Framework

This tool is used to maintain external zabbix checks in *one place*. There are lot of places where it is possible to download many external checks. 
But there is problem with installation, update and centralised management. This tool should do all of this in easy steps. 

## Example
Best way how to explain everything is example. Supposing we are working on debian-like system.
```
sudo apt-get install software-properties-common
sudo add-apt-repository xxx/zaf
sudo apt-get update
sudo apt-get install zaf
sudo zaf add-repository http://some.other.project/
sudo zaf update
sudo zaf install process-discovery
sudo zaf upgrade
zaf make-deb
zaf make-opkg
zaf make-rpm
zaf self-upgrade
```

## Zaf APT repository
Zaf APT repository is for easier installation of zaf itself. It can be skipped or zaf can be installed directly.

## Zaf repository
Zaf repository is place where zaf plugins are located. There can be lot of repositories. In fact, every zaf plugin can have its own repo.

## Zaf plugin
Zaf plugin is set of configuration options and binaries which are needed for specific checks. For example, to monitor postfix, we need some cron job which is automaticaly run and next ti this, some external items which has to be configured.

## How it works
There is central zaf reposirory on github. There are basic checks and zaf code itself. Next to this, each project can have its own zaf structure. Adding url of plugin to zaf will make it useable and updatable. 

## Zaf repository structure
Each zaf repository url MUST have this items:
```
/zaf.md                # Documentation
/zaf.plugins	       # List of plugins, one plugin per line
```

## Zaf plugin structure
Each zaf plugin url MUST have this items:
```
/plugin/README.md	# Documentation
/plugin/control		# Control file	
```

## Zaf control file



