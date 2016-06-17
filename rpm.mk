# Makefile for generating rpm packages
# Contrinutions welcome :)

ifeq ($(RPM_PKG),)
 RPM_PKG=$(shell . lib/zaf.lib.sh; echo out/zaf-$$ZAF_VERSION.rpm)
endif

$(RPM_PKG):
	@echo "Not supported yet. Contributions welcomed! :) "; exit 2

