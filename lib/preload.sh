#!/bin/sh

. /etc/zaf.conf

[ -z "$ZAF_TMP_BASE" ] && ZAF_TMP_BASE=/tmp/zaf
ZAF_TMP_DIR="${ZAF_TMP_BASE}-${USER}"
trap "rm -rif ${ZAF_TMP_DIR}" EXIT
! [ -d "${ZAF_TMP_DIR}" ] && mkdir "${ZAF_TMP_DIR}"
[ -z "$ZAF_DEBUG" ] && ZAF_DEBUG=1

. ${ZAF_LIB_DIR}/zaf.lib.sh
. ${ZAF_LIB_DIR}/ctrl.lib.sh
. ${ZAF_LIB_DIR}/os.lib.sh

export ZAF_LIB_DIR
export ZAF_TMP_DIR
export ZAF_PLUGINS_DIR

[ -n "$*" ] && $@


