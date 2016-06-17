# Arch linux specific definitions

ARCH_DIR=tmp/archlinux

ifeq ($(ARCH_PKG),)
 ARCH_PKG=$(shell . lib/zaf.lib.sh; echo out/zaf-$$ZAF_VERSION.arch)
endif

$(ARCH_PKG):	clean arch-init arch-build

arch-init:
	@mkdir -p tmp out $(ARCH_DIR)
	@. lib/zaf.lib.sh; \
	. lib/ctrl.lib.sh; \
	cat files/archlinux/PKGBUILD |  zaf_far '{PLUGINS}' "$(PLUGINS)"  | zaf_far "{IPLUGINS}" "$(IPLUGINS)" | \
		zaf_far "{ZAF_OPTIONS}" "$(ZAF_OPTIONS)" | zaf_far "{AGENT_OPTIONS}" "$(AGENT_OPTIONS)" \
		>$(ARCH_DIR)/PKGBUILD

arch-build:
	@cd $(ARCH_DIR) && makepkg -f


