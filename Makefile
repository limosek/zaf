# Zabbix agent framework makefile

CONTROLFILES=$(foreach p,$(PLUGINS),$(p)/control.zaf)
ZAF_EXPORT_OPTS=$(foreach o,$(ZAF_OPTIONS),$(shell echo $(o)|cut -d '=' -f 1))
DEBIAN_DIR=tmp/deb
DEBIAN_CTRL=$(DEBIAN_DIR)/DEBIAN
DEBIAN_PKG=out/zaf.deb

all: help

help:
	@echo make '{deb|ipk|rpm}' '[PLUGINS="/dir/plg1 /dir/plg2] [ZAF_OPTIONS="ZAF_cfg=val ..."] [AGENT_OPTIONS="Z_Server=host ..."]'

deb:	deb-clean deb-init deb-deps deb-control deb-scripts deb-cp deb-package

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
	zaf_far '{ZAF_VERSION}' "0.1" <files/control.template | zaf_far '{ZAF_DEPENDS}' "$$DEPENDS" >$(DEBIAN_CTRL)/control

deb-scripts:
ifneq ($(PLUGINS),)
	@. lib/zaf.lib.sh; \
	. lib/ctrl.lib.sh; \
	for p in $(PLUGINS); do \
		plugins="$$plugins "$$(zaf_ctrl_get_global_option $$p/control.zaf Plugin) ; \
	done; \
	cat files/postinst.template | zaf_far '{PLUGINS}' "$$plugins" | zaf_far '{ZAF_LIB_DIR}' "/usr/lib/zaf" >$(DEBIAN_CTRL)/postinst
	@chmod +x $(DEBIAN_CTRL)/postinst
	@cp files/preinst.template $(DEBIAN_CTRL)/preinst
	@chmod +x $(DEBIAN_CTRL)/preinst
	@cp files/prerm.template $(DEBIAN_CTRL)/prerm
	@chmod +x $(DEBIAN_CTRL)/prerm
endif

deb-cp:
	@mkdir -p $(DEBIAN_DIR)
	@set -e; INSTALL_PREFIX=$(DEBIAN_DIR) ZAF_DEBUG=0 ./install.sh auto $(ZAF_OPTIONS) $(AGENT_OPTIONS)
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

deb-changelog:
	@cp files/changelog.template $(DEBIAN_CTRL)/changelog

deb-package:
	@dpkg-deb -b $(DEBIAN_DIR) $(DEBIAN_PKG)
	@echo "\nCheck configuration:"
	@cat $(DEBIAN_DIR)/etc/zaf.conf
	@echo

	
