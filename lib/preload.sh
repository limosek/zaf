#!/bin/sh

. /etc/zaf.conf

[ -z "$ZAF_TMP_BASE" ] && ZAF_TMP_BASE=/tmp/zaf
ZAF_TMP_DIR="${ZAF_TMP_BASE}-${USER}"
[ -z "$ZAF_CACHE_DIR" ] && ZAF_CACHE_DIR=${ZAF_TMP_BASE}-${USER}c

#trap "rm -rif ${ZAF_TMP_DIR}" EXIT
! [ -d "${ZAF_TMP_DIR}" ] && mkdir "${ZAF_TMP_DIR}"
! [ -d "${ZAF_CACHE_DIR}" ] && mkdir "${ZAF_CACHE_DIR}"
[ -z "$ZAF_DEBUG" ] && ZAF_DEBUG=1

. ${ZAF_LIB_DIR}/zaf.lib.sh
. ${ZAF_LIB_DIR}/ctrl.lib.sh
. ${ZAF_LIB_DIR}/os.lib.sh
. ${ZAF_LIB_DIR}/zbxapi.lib.sh
. ${ZAF_LIB_DIR}/cache.lib.sh

export ZAF_LIB_DIR
export ZAF_TMP_DIR
export ZAF_PLUGINS_DIR

if [ "$1" = "_cache" ]; then
	shift
	seconds=$1
	shift
	parms=$(echo $*|tr -d ' ')
	if ! zaf_fromcache $parms; then
		([ "$(basename $0)" = "preload.sh" ] && [ -n "$*" ] && $@ ) | zaf_tocache_stdin $parms $seconds
	fi
else
	[ "$(basename $0)" = "preload.sh" ] && [ -n "$*" ] && $@
fi


