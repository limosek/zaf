# Zabbix Agent Framework

This tool is used to maintain external zabbix checks in *one place*. There are lot of places where it is possible to download many external checks. 
But there is problem with installation, update and centralised management. This tool should do all of this in easy steps. Today is is in devel stage and not everything works.
I will try to make it working :) 

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


