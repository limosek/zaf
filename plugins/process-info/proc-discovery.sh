#!/bin/sh

echo "{\n \"data\":[" ; /bin/ps --no-headers caux | /usr/bin/awk '{ print " { \"{#PSUSER}\":\"" $1 "\", \"{#PSNAME}\":\"" $11 "\" },"}' | /usr/bin/sort | /usr/bin/uniq | /bin/sed -e 's/\//\\\//g' -e '$s/.$//' ; echo " ]\n}"

