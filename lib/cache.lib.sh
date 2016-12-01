# Zaf cache related functions

zaf_cache_init(){
	if [ -z "$ZAF_CACHE_DIR" ] || [ "$ZAF_CACHE_DIR" = "/tmp/zafc" ]; then
		ZAF_CACHE_DIR=${ZAF_TMP_DIR}/zafc
		mkdir -p $ZAF_CACHE_DIR
		chown $ZAF_FILES_UID $ZAF_CACHE_DIR >/dev/null 2>/dev/null
	fi
	if [ -w $ZAF_CACHE_DIR ]; then
		zaf_trc "Cache: Removing stale entries"
		(cd $ZAF_CACHE_DIR && find ./ -type f -name '*.info' -mmin +1 2>/dev/null | \
		while read line ; do
			rm -f $line $(basename $line .info)
		done 
		)
	else
		zaf_dbg "Cache dir $ZAF_CACHE_DIR is not accessible! Disabling cache."
	fi
}

zaf_cache_clean(){
	if [ -n "$ZAF_CACHE_DIR" ]; then
		zaf_wrn "Removing cache entries"
		(cd $ZAF_CACHE_DIR && find ./ -type f -name '*.info' 2>/dev/null | \
		while read line ; do
			rm -f $line $(basename $line .info)
		done 
		)
	else
		zaf_dbg "Cache dir not set. Disabling cache."
	fi
	zaf_cache_init
}

# Get cache key from requested param
zaf_cache_key(){
	echo "$1" | (md5sum - ||md5) 2>/dev/null | cut -d ' ' -f 1
}

# Put object into cache
# $1 key
# $2 value
# $3 lifetime in seconds
zaf_tocache(){
	! [ -w $ZAF_CACHE_DIR ] && return 1
	local key
	local value
	local expiry
	local lockfile
	local infofile
	local datafile

	key=$(zaf_cache_key "$1")
	datafile=$ZAF_CACHE_DIR/$key
	lockfile=$ZAF_CACHE_DIR/${key}.lock
	infofile=$ZAF_CACHE_DIR/${key}.info

	[ -f $lockfile ] && return 1	# Key is locked, return
	touch $lockfile
	rm -f $datafile $infofile
	echo "$2" >$datafile
	echo "$1" >$infofile
	expiry=$(zaf_date_add "$3")
	zaf_trc "Cache: Saving entry $1[$key,expiry=$expiry]"
	touch -m -d "$expiry" $infofile
	rm -f $lockfile
}

# Put object into cache from stdin and copy to stdout
# $1 key
# $2 lifetime in seconds
zaf_tocache_stdin(){
	! [ -w $ZAF_CACHE_DIR ] && { cat; return 1; }
	local key
	local expiry
	local lockfile
	local infofile
	local datafile

	key=$(zaf_cache_key "$1")
	datafile=$ZAF_CACHE_DIR/$key
	lockfile=$ZAF_CACHE_DIR/${key}.lock
	infofile=$ZAF_CACHE_DIR/${key}.info

	[ -f $lockfile ] && return 1	# Key is locked, return
	touch $lockfile

	rm -f $datafile $infofile
	cat >$datafile
	if [ -s $datafile ]; then
		expiry="$(zaf_date_add $2)"
		echo "$1 [key=$key,expiry=$expiry]" >$infofile
		zaf_trc "Cache: Saving entry $1[key=$key,expiry=$expiry]"
		touch -m -d "$expiry" $infofile
		cat $datafile
		rm -f $lockfile
	else
		rm -f "$datafile"
	fi
}

# Remove entry from cache
# $1 key
zaf_cache_delentry(){
	! [ -w $ZAF_CACHE_DIR ] && return 1
	local key
	key=$(zaf_cache_key "$1")
	zaf_trc "Cache: removing $1($key) from cache"
	rm -f "$ZAF_CACHE_DIR/$key*"
}

# List entries in cache
zaf_cache_list(){
	local i
	ls $ZAF_CACHE_DIR/*info >/dev/null 2>/dev/null || return 1
	local key
	for i in $ZAF_CACHE_DIR/*info; do
		cat $i
	done
}

# Get object from cache
# $1 key
zaf_fromcache(){
	! [ -r $ZAF_CACHE_DIR ] || [ -n "$ZAF_NOCACHE" ] && return 1
	local key
	local value
	local infofile
	local datafile

	key=$(zaf_cache_key "$1")
	datafile=$ZAF_CACHE_DIR/$key
	infofile=$ZAF_CACHE_DIR/${key}.info

	if [ -f $datafile ]; then
		! [ -f "$infofile" ] && { return 3; }
		if [ "$infofile" -nt "$datafile" ]; then
			zaf_trc "Cache: serving $1($key) from cache"
			cat $datafile
		else
			zaf_trc "Cache: removing old entry $1"
			rm -f "$ZAF_CACHE_DIR/$key*"
			return 2
		fi
	else
		zaf_trc "Cache: missing entry $1($key)"
		return 1
	fi
}


