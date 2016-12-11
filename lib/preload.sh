#!/bin/sh

. /etc/zaf.conf

. ${ZAF_LIB_DIR}/zaf.lib.sh
. ${ZAF_LIB_DIR}/plugin.lib.sh
. ${ZAF_LIB_DIR}/ctrl.lib.sh
. ${ZAF_LIB_DIR}/os.lib.sh
. ${ZAF_LIB_DIR}/zbxapi.lib.sh
. ${ZAF_LIB_DIR}/cache.lib.sh

# Global plugin parameters
[ -f ./params ] && for p in $(cat ./params); do
	var=$p
	value="$(cat ${p}.value)"
	zaf_trc "Global $p parameter $var=$value"
	eval export $var="$value"	
done

# Plugin specific functions if exists
[ -f ./functions.sh ] && . ./functions.sh

if ! type zaf_version >/dev/null; then
	echo "Problem loading libraries?"
	exit 2
fi
zaf_debug_init
zaf_tmp_init
zaf_cache_init

export ZAF_LIB_DIR
export ZAF_TMP_DIR
export ZAF_CACHE_DIR
export ZAF_PLUGINS_DIR
export ZAF_DEBUG
unset ZAF_LOG_STDERR
export PATH

if [ "$(basename $0)" = "preload.sh" ] && [ -n "$*" ]; then
	tmpf=$(zaf_tmpfile preload)
	export tmpf
	$@ 2>$tmpf
	[ -s $tmpf ] && zaf_wrn <$tmpf
else
	tmpf=$(zaf_tmpfile preload)
	export tmpf	
fi


