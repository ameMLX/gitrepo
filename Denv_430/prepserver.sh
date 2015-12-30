#!/bin/bash
# This script will prepare the DMZ server for the initial syncs
# It will create the needed directory structures on the DMZ server.
# Revision 1.0.0
# Date: 17 Sept 2015
# ------------------------------------------------------------------
while read rdir; do
	if [ ! -d $rdir ]; then
		mkdir -p $rdir
	fi
done <dir.cfg