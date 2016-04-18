#!/bin/sh

. lib/zaf.lib.sh

! [ -d plugins ] && git clone https://github.com/limosek/zaf-plugins.git plugins

make deb DEBIAN_PKG="out/zaf-$ZAF_VERSION-git.deb" \
  ZAF_OPTIONS="ZAF_GIT=1 ZAF_REPO_GITURL='https://github.com/limosek/zaf-plugins.git'"

make deb DEBIAN_PKG="out/zaf-$ZAF_VERSION.deb" \
  ZAF_OPTIONS="ZAF_GIT=0"

make deb DEBIAN_PKG="out/zaf-$ZAF_VERSION-all.deb" ZAF_OPTIONS="ZAF_GIT=0" \
  PLUGINS="./plugins/fsx ./plugins/openssh ./plugins/psx ./plugins/tcqos ./plugins/zaf ./plugins/fail2ban"

