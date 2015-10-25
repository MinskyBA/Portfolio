#!/bin/bash
#============================================================================================
#
#          FILE:        check_apache_threads.sh
# 
USAGE="USAGE: ./curl_URL.sh -s <URL> -w <##> -c <##>"
# 
#   DESCRIPTION:        This script checks a site by HTTP '200', and
#			outputs time and performance data
#
#  REQUIREMENTS:        site to curl, warning and critical thresholds
#         NOTES:	
#        AUTHOR:        Brian Minsky
#       COMPANY:        K12 Inc.
#       CREATED:        Oct 2015
REVISION="Revision: 1.0"
#
#==============================================================================================
###############################################################################################

##################################
##   Variables   #################
##################################
LOGFILE="/var/log/curl_URL.log"
STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
#####################################################################
#####################################################################
##################                                 ##################
##################         |  Functions |          ##################
##################         v  vvvvvvvvv v          ##################
#####################################################################
#####################################################################

print_help(){
	echo $USAGE
}

print_revision(){
	echo $REVISION
}

##########################
####  parse arguments ####
##########################

while [ $# -gt 0 ]; do
case "$1" in
	-h | --help)
		print_help
		exit $STATE_OK
		;;
	-v | --version)
		print_revision
		exit $STATE_OK
		;;
	-s | --site)
		shift
		SITE=$1
		;;
	-w | --warning)
		shift
		WARNING=$1
		;;
	-c | --critical)
		shift
		CRITICAL=$1
		;;
	*)  echo "Invalid argument: $1"
		print_help
		exit $STATE_WARN
		;;
	esac
shift
done

#########################################################################################################
#########################################################################################################
####################################                                 ####################################
####################################     | Main Body of Script |     ####################################
####################################     v vvvvvvvvvvvvvvvvvvv v     ####################################
#########################################################################################################
#########################################################################################################


START=$(date +%s.%N)
SITE_STATUS="$(curl $SITE -Is|head -1|sed 's:\r::')"	# <-- the actual curl command
END=$(date +%s.%N)					# curl the site header, take the first line, strip the trailing \r
TIME=$(echo "scale=3; ($END - $START)/1" | bc)
## and set scale=3 to get 3 decimal places

# if header does not return '200'
if (( $(echo "$SITE_STATUS"|grep -q 200;echo $?) )) ; then
	echo "CRITICAL - $SITE_STATUS | 'Response time'=$TIME;$WARNING;$CRITICAL;; "
	exit $STATE_CRIT
#elif TIME is greater than CRITICAL
elif (( $(echo "$TIME > $CRITICAL"|bc -l) )); then
	echo "CRITICAL - response took ${TIME}s | 'Response time'=$TIME;$WARNING;$CRITICAL;; "
	exit $STATE_CRIT
#elif TIME is greater than CRITICAL
elif (( $(echo "$TIME > $WARNING"|bc -l) )); then
	echo "WARNING - response took ${TIME}s | 'Response time'=$TIME;$WARNING;$CRITICAL;; "
	exit $STATE_WARN
else
	echo "OK - $SITE_STATUS | 'Response time'=$TIME;$WARNING;$CRITICAL;; "
	exit $STATE_OK
fi

