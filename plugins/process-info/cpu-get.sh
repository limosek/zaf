#!/bin/sh

TOTAL=0
for PROC in $(/bin/ps u -C $1 | /bin/grep -e '^$2' | /usr/bin/awk '{ print $$3 }'); do TOTAL=$(echo "$TOTAL $PROC" | /usr/bin/awk '{print $$1 + $$2}') ; done;
echo $TOTAL

