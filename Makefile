# Zabbix agent framework makefile

all: help

help:
	@echo make '{deb|arch|ipk|rpm}' '[PLUGINS="/dir/plg1 [/dir2]...] [IPLUGINS="plg1 [plg2]..."] [ZAF_OPTIONS="ZAF_cfg=val ..."] [AGENT_OPTIONS="Z_Server=host ..."]'
	@echo PLUGINS are embedded into package. Has to be local directories accessible during build.
	@echo IPLUGINS will be downloaded and installed after package is installed. Can be name or url accessible after package installation.
	@echo

include deb.mk
include arch.mk
include ipk.mk
include rpm.mk
include tgz.mk

CONTROLFILES=$(foreach p,$(PLUGINS),$(p)/control.zaf)
ZAF_EXPORT_OPTS=$(foreach o,$(ZAF_OPTIONS),$(shell echo $(o)|cut -d '=' -f 1))

ifeq ($(ZAF_DEBUG),)
 ZAF_DEBUG=0
endif

ifeq ($(ZAF_OPTIONS),)
 ZAF_OPTIONS = ZAF_GIT=0
endif
ifeq ($(IPLUGINS),)
 IPLUGINS = zaf
endif

deb:	$(DEBIAN_PKG)

arch:	$(ARCH_PKG)

rpm:	$(RPM_PKG)

ipk:	$(IPK_PKG)

tar:	tgz
tgz:	$(TGZ_PKG)

clean:
	@rm -rf tmp/* out/*


