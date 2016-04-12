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
zaf_cachekey(){
	echo $1 | md5sum - | cut -d ' ' -f 1
}

# Put object into cache
# $1 key
# $2 value
# $3 lifetime in seconds
zaf_tocache(){
	local key
	local value
	local lifetime
	key=$(zaf_cachekey $1)
	echo "$2" >$ZAF_CACHE_DIR/$key
	touch -m -d "$3 seconds" $ZAF_CACHE_DIR/$key.tme
	zaf_trc "Cache: Saving entry $1($key)"
}

# Put object into cache from stdin and copy to stdout
# $1 key
# $2 lifetime in seconds
zaf_tocache_stdin(){
	local key
	local lifetime

	key=$(zaf_cachekey $1)
	cat >$ZAF_CACHE_DIR/$key
	touch -m -d "$3 seconds" $ZAF_CACHE_DIR/$key.tme
	zaf_trc "Cache: Saving entry $1($key)"
	cat $ZAF_CACHE_DIR/$key
}

# Get object from cache
# $1 key
zaf_fromcache(){
	local key
	local value
	key=$(zaf_cachekey $1)
	if [ -f $ZAF_CACHE_DIR/$key ]; then
		if [ "$ZAF_CACHE_DIR/$key.tme" -nt "$ZAF_CACHE_DIR/$key" ]; then
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

