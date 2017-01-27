#!/bin/bash
#===============================================================================
#
#         FILE: moon.sh
#        USAGE: moon.sh [# of days]
#
#  DESCRIPTION: displays moon cycle from wttr.in
#       AUTHOR: bminsky ()
#      CREATED: 2017-01-27
#===============================================================================

TMP=/tmp/moon
RE='^[0-9]+$'
[[ $1 =~ ${RE} ]] && COUNT=$1 || COUNT=28

i=0
while [ $i -lt $COUNT ] ; do
	printf "\n############################################\n##\n" > ${TMP}
	cal $(date "+%d %m %Y" -d "+$i days")| GREP_COLOR='044' grep --color=always -wEC6 "\b$(date "+%d" -d "+$i days" | sed 's/^0//')" | sed 's/^/##   /g' >> ${TMP}
	echo "" >> ${TMP}
	curl -s http://wttr.in/Moon@$(date +%F -d "+$i days") >> ${TMP}
	sleep .1
	clear
	cat ${TMP}
	let i=$i+1
done

rm ${TMP}
