# Zaf cache related functions

zaf_cache_init(){
	[ -z "$ZAF_CACHE_DIR" ] && ZAF_CACHE_DIR=${ZAF_TMP_BASE}c
	if [ -n "$ZAF_CACHE_DIR" ]; then
		mkdir -p "$ZAF_CACHE_DIR"
		if zaf_is_root; then
			zaf_trc "Cache: Changing perms to $ZAF_CACHE_DIR (zabbix/$ZAF_ZABBIX_GID/0770)"
			chown $ZAF_FILES_UID "$ZAF_CACHE_DIR"
			chgrp $ZAF_FILES_GID "$ZAF_CACHE_DIR"
			chmod $ZAF_FILES_UMASK "$ZAF_CACHE_DIR"
		fi
		if [ -w $ZAF_CACHE_DIR ]; then
			zaf_trc "Cache: Removing stale entries"
			(cd $ZAF_CACHE_DIR && find ./ -type f -name '*.info' -mmin +1 | \
			while read line ; do
				rm -f $line $(basename $line .info)
			done 
			)
		else
			zaf_err "Cache dir is not accessible! Become root or member of $ZAF_FILES_GID group!"
		fi
	else
		zaf_err "Cache dir not set."
	fi
}

zaf_cache_clean(){
	if [ -n "$ZAF_CACHE_DIR" ]; then
		zaf_wrn "Removing cache entries"
		rm -rf "$ZAF_CACHE_DIR"
	else
		zaf_err "Cache dir not set."
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

	key=$(zaf_cache_key "$1")
	rm -f $ZAF_CACHE_DIR/$key $ZAF_CACHE_DIR/${key}.info
	echo "$2" >$ZAF_CACHE_DIR/$key
	echo "$1" >$ZAF_CACHE_DIR/${key}.info
	expiry=$(zaf_date_add "$3")
	zaf_trc "Cache: Saving entry $1[$key,expiry=$expiry]"
	touch -m -d "$expiry" $ZAF_CACHE_DIR/${key}.info
}

# Put object into cache from stdin and copy to stdout
# $1 key
# $2 lifetime in seconds
zaf_tocache_stdin(){
	! [ -w $ZAF_CACHE_DIR ] && return 1
	local key
	local expiry

	key=$(zaf_cache_key "$1")
	rm -f $ZAF_CACHE_DIR/$key $ZAF_CACHE_DIR/${key}.info
	cat >$ZAF_CACHE_DIR/$key
	if [ -s $ZAF_CACHE_DIR/$key ]; then
		expiry="$(zaf_date_add $2)"
		echo "$1 [key=$key,expiry=$expiry]" >$ZAF_CACHE_DIR/${key}.info
		zaf_trc "Cache: Saving entry $1[key=$key,expiry=$expiry]"
		touch -m -d "$expiry" $ZAF_CACHE_DIR/$key.info
		cat $ZAF_CACHE_DIR/$key
	else
		rm -f "$ZAF_CACHE_DIR/$key"
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
	key=$(zaf_cache_key "$1")
	if [ -f $ZAF_CACHE_DIR/$key ]; then
		! [ -f "$ZAF_CACHE_DIR/$key.info" ] && { return 3; }
		if [ "$ZAF_CACHE_DIR/$key.info" -nt "$ZAF_CACHE_DIR/$key" ]; then
			zaf_trc "Cache: serving $1($key) from cache"
			cat $ZAF_CACHE_DIR/$key
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

