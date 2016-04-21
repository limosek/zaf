#!/bin/sh

. /etc/zaf.conf

. ${ZAF_LIB_DIR}/zaf.lib.sh
. ${ZAF_LIB_DIR}/plugin.lib.sh
. ${ZAF_LIB_DIR}/ctrl.lib.sh
. ${ZAF_LIB_DIR}/os.lib.sh
. ${ZAF_LIB_DIR}/zbxapi.lib.sh
. ${ZAF_LIB_DIR}/cache.lib.sh

[ -z "$ZAF_TMP_BASE" ] && ZAF_TMP_BASE=/tmp/zaf
[ -z "$ZAF_TMP_DIR" ] && ZAF_TMP_DIR="${ZAF_TMP_BASE}-$(zaf_random)"
[ -z "$ZAF_CACHE_DIR" ] && ZAF_CACHE_DIR=${ZAF_TMP_BASE}c

rm -rf "${ZAF_TMP_DIR}"

if ! [ -d "${ZAF_TMP_DIR}" ]; then
	mkdir "${ZAF_TMP_DIR}"
fi

! [ -d "${ZAF_CACHE_DIR}" ] && mkdir "${ZAF_CACHE_DIR}"
[ -z "$ZAF_DEBUG" ] && ZAF_DEBUG=1

if [ "$ZAF_DEBUG" -le 3 ]; then
	trap "rm -rf ${ZAF_TMP_DIR}" EXIT
else
	trap 'zaf_wrn "Leaving $ZAF_TMP_DIR" contents due to ZAF_DEBUG.' EXIT
fi

#trap 'touch /tmp/aaaa' ALARM

export ZAF_LIB_DIR
export ZAF_TMP_DIR
export ZAF_CACHE_DIR
export ZAF_PLUGINS_DIR
export ZAF_DEBUG
unset ZAF_LOG_STDERR
export PATH=$ZAF_LIB_DIR:$ZAF_BIN_DIR:$PATH

if [ "$(basename $0)" = "preload.sh" ] && [ -n "$*" ]; then
	tmpf=$(zaf_tmpfile preload)
	$@ 2>$tmpf
	[ -s $tmpf ] && zaf_wrn <$tmpf
fi


