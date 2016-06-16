# Zabbix agent framework makefile

CONTROLFILES=$(foreach p,$(PLUGINS),$(p)/control.zaf)
ZAF_EXPORT_OPTS=$(foreach o,$(ZAF_OPTIONS),$(shell echo $(o)|cut -d '=' -f 1))
DEBIAN_DIR=tmp/deb
DEBIAN_CTRL=$(DEBIAN_DIR)/DEBIAN
DEBIAN_PKG=$(shell . lib/zaf.lib.sh; echo out/zaf-$$ZAF_VERSION.deb)
ARCH_DIR=archlinux
ifeq ($(ZAF_DEBUG),)
 ZAF_DEBUG=0
endif

ifeq ($(ZAF_OPTIONS),)
 ZAF_OPTIONS = ZAF_GIT=0
endif
ifeq ($(IPLUGINS),)
 IPLUGINS = zaf
endif

all: help

help:
	@echo make '{deb|ipk|rpm}' '[PLUGINS="/dir/plg1 [/dir2]...] [IPLUGINS="plg1 [plg2]..."] [ZAF_OPTIONS="ZAF_cfg=val ..."] [AGENT_OPTIONS="Z_Server=host ..."]'
	@echo PLUGINS are embedded into package. Has to be local directories accessible during build.
	@echo IPLUGINS will be downloaded and installed after package is installed. Can be name or url accessible after package installation.
	@echo

deb:
	$(DEBIAN_PKG)

arch:
	$(ARCH_PKG)

$(DEBIAN_PKG):	deb-clean deb-init deb-deps deb-control deb-scripts deb-cp deb-package
$(ARCH_PKG):	arch-clean arch-build

clean:
	@rm -rf tmp/* out/*

deb-clean:
	@rm -rf $(DEBIAN_DIR) $(DEBIAN_PKG)

deb-init:
	@mkdir -p tmp out $(DEBIAN_DIR)

deb-deps: $(CONTROLFILES)
	@which dpkg >/dev/null && which dpkg-buildpackage >/dev/null && which dch >/dev/null || { echo "You need essential debian developer tools. Please install them:\nsudo apt-get install build-essential devscripts debhelper"; exit 2; }

deb-control:
	@mkdir -p $(DEBIAN_CTRL)
	@. lib/zaf.lib.sh; \
	. lib/ctrl.lib.sh; \
	for p in $(PLUGINS); do \
	  	DEPENDS="$$DEPENDS,$$(zaf_ctrl_get_global_option $$p/control.zaf Depends-dpkg | tr ' ' ',')"; \
	done; \
	[ "$$ZAF_GITBRANCH" = "master" ] && master=master; \
	zaf_far '{ZAF_VERSION}' "$${ZAF_VERSION}$$master" <files/control.template | zaf_far '{ZAF_DEPENDS}' "$$DEPENDS" >$(DEBIAN_CTRL)/control

deb-scripts:
	@. lib/zaf.lib.sh; \
	. lib/ctrl.lib.sh; \
	cat files/postinst.template | zaf_far '{PLUGINS}' "$(PLUGINS)"  | zaf_far "{IPLUGINS}" "$(IPLUGINS)" | zaf_far '{ZAF_LIB_DIR}' "/usr/lib/zaf" >$(DEBIAN_CTRL)/postinst
	@chmod +x $(DEBIAN_CTRL)/postinst
	@cp files/preinst.template $(DEBIAN_CTRL)/preinst
	@chmod +x $(DEBIAN_CTRL)/preinst
	@cp files/prerm.template $(DEBIAN_CTRL)/prerm
	@chmod +x $(DEBIAN_CTRL)/prerm

deb-cp:
	@mkdir -p $(DEBIAN_DIR)
	@set -e; INSTALL_PREFIX=$(DEBIAN_DIR) ZAF_DEBUG=$(ZAF_DEBUG) ./install.sh auto $(ZAF_OPTIONS) $(AGENT_OPTIONS)
	@. lib/zaf.lib.sh; \
	. lib/ctrl.lib.sh; \
	for p in $(PLUGINS); do \
		plugin=$$(zaf_ctrl_get_global_option $$p/control.zaf Plugin) ; \
		mkdir -p $(DEBIAN_DIR)/usr/lib/zaf/prepackaged/$$plugin/; \
	  	cp -R $$p/* $(DEBIAN_DIR)/usr/lib/zaf/prepackaged/$$plugin/; \
	done
	@cat lib/*lib.sh install.sh >$(DEBIAN_DIR)/usr/lib/zaf/install.sh
	@chmod +x $(DEBIAN_DIR)/usr/lib/zaf/install.sh
	@rm -rf $(DEBIAN_DIR)/tmp
	@cp $(DEBIAN_DIR)/etc/zaf.conf tmp/zaf.conf
	@grep -E "$$(echo $(ZAF_EXPORT_OPTS) | tr ' ' '|')=" tmp/zaf.conf  >$(DEBIAN_DIR)/etc/zaf.conf
	@echo "ZAF_PREPACKAGED_DIR=\"/usr/lib/zaf/prepackaged\"" >>$(DEBIAN_DIR)/etc/zaf.conf
ifneq ($(AGENT_OPTIONS),)
	@echo "ZAF_AGENT_OPTIONS=\"$(AGENT_OPTIONS)\"" >>$(DEBIAN_DIR)/etc/zaf.conf
endif

deb-package:
	@dpkg-deb -b $(DEBIAN_DIR) $(DEBIAN_PKG)
	@echo "\nCheck configuration:"
	@cat $(DEBIAN_DIR)/etc/zaf.conf
	@echo PLUGINS embedded: $(PLUGINS)
	@echo PLUGINS in postinst: $(IPLUGINS)
	@echo

arch-clean:
	@cd $(ARCH_DIR)
	git clean -ffdx

arch-build:
	@cd $(ARCH_DIR) && makepkg -f
