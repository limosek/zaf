# Debian specific config

DEBIAN_DIR=tmp/deb
DEBIAN_CTRL=$(DEBIAN_DIR)/DEBIAN

ifeq ($(DEBIAN_PKG),)
 DEBIAN_PKG=$(shell . lib/zaf.lib.sh; echo out/zaf-$$ZAF_VERSION.deb)
endif

$(DEBIAN_PKG):	clean deb-init deb-deps deb-control deb-scripts deb-cp deb-package

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
	zaf_far '{ZAF_VERSION}' "$${ZAF_VERSION}$$master" <files/debian/control.template | zaf_far '{ZAF_DEPENDS}' "$$DEPENDS" >$(DEBIAN_CTRL)/control

deb-scripts:
	@. lib/zaf.lib.sh; \
	. lib/ctrl.lib.sh; \
	cat files/debian/postinst.template >$(DEBIAN_CTRL)/postinst
	@chmod +x $(DEBIAN_CTRL)/postinst
	@cp files/debian/preinst.template $(DEBIAN_CTRL)/preinst
	@chmod +x $(DEBIAN_CTRL)/preinst
	@cp files/debian/prerm.template $(DEBIAN_CTRL)/prerm
	@chmod +x $(DEBIAN_CTRL)/prerm

deb-cp:
	@mkdir -p $(DEBIAN_DIR)
	@set -e; INSTALL_PREFIX=$(DEBIAN_DIR) ZAF_DEBUG=$(ZAF_DEBUG) ./install.sh auto $(ZAF_OPTIONS) ZAF_PLUGINS="$(ZAF_PLUGINS)" $(AGENT_OPTIONS)
	@cat lib/*lib.sh install.sh >$(DEBIAN_DIR)/usr/lib/zaf/install.sh
	@chmod +x $(DEBIAN_DIR)/usr/lib/zaf/install.sh
	@rm -rf $(DEBIAN_DIR)/tmp
	@cp $(DEBIAN_DIR)/etc/zaf.conf tmp/zaf.conf
	@grep -E "$$(echo $(ZAF_EXPORT_OPTS) | tr ' ' '|')=" tmp/zaf.conf  >$(DEBIAN_DIR)/etc/zaf.conf
ifneq ($(AGENT_OPTIONS),)
	@echo "ZAF_AGENT_OPTIONS=\"$(AGENT_OPTIONS)\"" >>$(DEBIAN_DIR)/etc/zaf.conf
endif

deb-package:
	@dpkg-deb -b $(DEBIAN_DIR) $(DEBIAN_PKG)
	@echo "\nCheck configuration:"
	@cat $(DEBIAN_DIR)/etc/zaf.conf
	@echo PLUGINS embedded: $(ZAF_PLUGINS)
	@echo


