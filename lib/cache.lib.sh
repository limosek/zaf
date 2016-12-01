# Zaf cache related functions

zaf_cache_init(){
	local files
	local file

	if [ -z "$ZAF_CACHE_DIR" ] || [ "$ZAF_CACHE_DIR" = "/tmp/zafc/" ]; then
		ZAF_CACHE_DIR=${ZAF_TMP_DIR}/zafc
		mkdir -p $ZAF_CACHE_DIR
		chown $ZAF_FILES_UID $ZAF_CACHE_DIR >/dev/null 2>/dev/null
	fi
	if [ -w $ZAF_CACHE_DIR ]; then
		zaf_trc "Cache: Removing stale entries"
		files=$(find $ZAF_CACHE_DIR/ -type f -name '*.lock' -mmin +1)
		[ -n "$files" ] && rm -f $files
		(cd $ZAF_CACHE_DIR && find ./ -type f -name '*.info' -mmin +1 2>/dev/null | \
		while read line ; do
			 file=$(basename $line .info)
			 [ "$line" -nt "$file" ] && { rm ${file}*; zaf_trc "rm ${file}*"; }
		done
		)
	else
		zaf_dbg "Cache dir $ZAF_CACHE_DIR is not accessible! Disabling cache."
	fi
}

zaf_cache_clean(){
	local files

	if [ -n "$ZAF_CACHE_DIR" ]; then
		zaf_wrn "Removing cache entries"
		files=$(find $ZAF_CACHE_DIR/ -type f)
		[ -n "$files" ] && rm -f $files
	else
		zaf_dbg "Cache dir not set. Disabling cache."
	fi
	zaf_cache_init
}

# Get cache key from requested param
zaf_cache_key(){
	echo "$1" | (md5sum - ||md5) 2>/dev/null | cut -d ' ' -f 1
}

# Wait for lock 
# $1 - key
zaf_cache_lock(){
	local lockfile
	lockfile="${ZAF_CACHE_DIR}/${key}.lock"
	
	[ -f "$lockfile" ] && sleep 1
	[ -f "$lockfile" ] && return 1
	return 0
}

# Unlock cache key
# $1 - key
zaf_cache_unlock(){
	local lockfile
	lockfile="${ZAF_CACHE_DIR}/${key}.lock"
	
	rm -f $lockfile
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
	local infofile
	local datafile

	key=$(zaf_cache_key "$1")
	datafile=${ZAF_CACHE_DIR}/$key
	infofile=${ZAF_CACHE_DIR}/${key}.info

	zaf_cache_lock "$key" || { zaf_wrn "Cache: Entry $1[$key] locked!"; return 1; }

	rm -f $datafile $infofile
	echo "$2" >$datafile
	echo "$1" >$infofile
	expiry=$(zaf_date_add "$3")
	zaf_trc "Cache: Saving entry $1[$key,expiry=$expiry]"
	touch -m -d "$expiry" $infofile
	zaf_cache_unlock $key
}

# Put object into cache from stdin and copy to stdout
# $1 key
# $2 lifetime in seconds
zaf_tocache_stdin(){
	! [ -w $ZAF_CACHE_DIR ] && { cat; return 1; }
	local key
	local expiry
	local infofile
	local datafile

	key=$(zaf_cache_key "$1")
	datafile=${ZAF_CACHE_DIR}/$key
	lockfile=${ZAF_CACHE_DIR}/${key}.lock
	infofile=${ZAF_CACHE_DIR}/${key}.info

	zaf_cache_lock "$key" || { zaf_wrn "Cache: Entry $1[$key] locked!"; return 1; }

	rm -f $datafile $infofile
	cat >$datafile
	expiry="$(zaf_date_add $2)"
	echo "$1 [key=$key,expiry=$expiry]" >$infofile
	zaf_trc "Cache: Saving entry $1[key=$key,expiry=$expiry]"
	touch -m -d "$expiry" $infofile
	zaf_cache_unlock "$key"
	cat $datafile
}

# Remove entry from cache
# $1 key
zaf_cache_delentry(){
	! [ -w $ZAF_CACHE_DIR ] && return 1
	local key
	key=$(zaf_cache_key "$1")
	zaf_trc "Cache: removing $1($key) from cache"
	rm -f "${ZAF_CACHE_DIR}/$key*"
}

# List entries in cache
zaf_cache_list(){
	local i
	ls ${ZAF_CACHE_DIR}/*info >/dev/null 2>/dev/null || return 1
	local key
	for i in ${ZAF_CACHE_DIR}/*info; do
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
	datafile="${ZAF_CACHE_DIR}/${key}"
	infofile="${ZAF_CACHE_DIR}/${key}.info"

	if [ -f $datafile ]; then
		#zaf_cache_lock $key || return 3
		#zaf_cache_unlock $key
		if [ "$infofile" -nt "$datafile" ]; then
			zaf_trc "Cache: serving $1($key) from cache"
			cat "$datafile" || { ls -la "$datafile" >&2; zaf_err "auuu: $1";  }
		else
			#zaf_cache_delentry $key
			return 2
		fi
	else
		zaf_trc "Cache: missing entry $1($key)"
		return 1
	fi
}


