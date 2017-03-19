
TGZ_DIR=tmp/tgz

ifeq ($(TGZ_PKG),)
 TGZ_PKG=$(shell . lib/zaf.lib.sh; echo out/zaf-$$ZAF_VERSION.tgz)
endif

$(TGZ_PKG):	clean tgz-init tgz-deps tgz-control tgz-scripts tgz-cp tgz-package

tgz-init:
	@mkdir -p $(TGZ_DIR)

tgz-deps: 
tgz-control:
tgz-scripts:
tgz-cp:
	@mkdir -p $(TGZ_DIR)
	@set -e; INSTALL_PREFIX=$(TGZ_DIR) ZAF_tgzUG=$(ZAF_tgzUG) ./install.sh auto $(ZAF_OPTIONS) ZAF_PLUGINS="$(ZAF_PLUGINS)" $(AGENT_OPTIONS)
	@cat lib/*lib.sh install.sh >$(TGZ_DIR)/usr/lib/zaf/install.sh
	@chmod +x $(TGZ_DIR)/usr/lib/zaf/install.sh
	@rm -rf $(TGZ_DIR)/tmp
	@cp $(TGZ_DIR)/etc/zaf.conf tmp/zaf.conf
	@grep -E "$$(echo $(ZAF_EXPORT_OPTS) | tr ' ' '|')=" tmp/zaf.conf  >$(TGZ_DIR)/etc/zaf.conf
ifneq ($(AGENT_OPTIONS),)
	@echo "ZAF_AGENT_OPTIONS=\"$(AGENT_OPTIONS)\"" >>$(TGZ_DIR)/etc/zaf.conf
endif

tgz-package:
	@tar -czf $(TGZ_PKG) -C $(TGZ_DIR) . 
	@echo PLUGINS embedded: $(ZAF_PLUGINS)
	@echo Result: $(TGZ_PKG)

