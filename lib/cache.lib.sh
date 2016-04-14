# Zaf cache related functions

zaf_cache_clean(){
	if [ -n "$ZAF_CACHE_DIR" ]; then
		zaf_wrn "Removing cache entries"
		rm -rf "$ZAF_CACHE_DIR"
	else
		zaf_err "Cache dir not set."
	fi
	mkdir -p "$ZAF_CACHE_DIR"
}

# Get cache key from requested param
zaf_cache_key(){
	echo "$1" | md5sum - | cut -d ' ' -f 1
}

# Put object into cache
# $1 key
# $2 value
# $3 lifetime in seconds
zaf_tocache(){
	! [ -w $ZAF_CACHE_DIR ] && return 1
	local key
	local value

	key=$(zaf_cache_key "$1")
	echo "$2" >$ZAF_CACHE_DIR/$key
	echo "$1" >$ZAF_CACHE_DIR/$key.info
	touch -m -d "$3 seconds" $ZAF_CACHE_DIR/$key.info
	zaf_trc "Cache: Saving entry $1($key)"
}

# Put object into cache from stdin and copy to stdout
# $1 key
# $2 lifetime in seconds
zaf_tocache_stdin(){
	! [ -w $ZAF_CACHE_DIR ] && return 1
	local key

	key=$(zaf_cache_key "$1")
	cat >$ZAF_CACHE_DIR/$key
	if [ -s $ZAF_CACHE_DIR/$key ]; then
		zaf_trc "Cache: Saving entry $1($key)"
		echo "$1" >$ZAF_CACHE_DIR/$key.info
		touch -m -d "$2 seconds" $ZAF_CACHE_DIR/$key.info
		cat $ZAF_CACHE_DIR/$key
	else
		rm $ZAF_CACHE_DIR/$key
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

# Get object from cache
# $1 key
zaf_fromcache(){
	! [ -r $ZAF_CACHE_DIR ] || [ -n "$ZAF_NOCACHE" ] && return 1
	local key
	local value
	key=$(zaf_cache_key "$1")
	if [ -f $ZAF_CACHE_DIR/$key ]; then
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

