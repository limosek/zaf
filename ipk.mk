# Makefile for generating openwrt ipk packages
# Contrinutions welcome :)

ifeq ($(IPK_PKG),)
 IPK_PKG=$(shell . lib/zaf.lib.sh; echo out/zaf-$$ZAF_VERSION.ipk)
endif

$(IPK_PKG):
	@echo "Not supported yet. Contributions welcomed! :) "; exit 2

