#!/bin/bash
#============================================================================================
#
#          FILE:        check_apache_threads.sh
# 
USAGE="USAGE: ./check_apache_threads.sh -w <##> -c <##>"
# 
#   DESCRIPTION:        This script compares the number of httpd threads running against
#			warning	and critical values passed via arguments. The output is for
#			nagios, including performance data.
#
#  REQUIREMENTS:        warning and critical thresholds
#         NOTES:
#        AUTHOR:        Brian Minsky
#       COMPANY:        K12 Inc.
#       CREATED:        Sept 2015
REVISION="Revision: 1.0"
#
#==============================================================================================
###############################################################################################

##################################
##   Variables   #################
##################################


LOGFILE="/var/log/apache_processes.log"
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

NUMHTTPD=`ps aux | grep httpd | grep -v "\(root\|grep\)" | wc -l`
echo "`date +'%Y-%m-%d %H:%M:%S %Z'` - $NUMHTTPD" >> $LOGFILE

#########################################################################################################
#########################################################################################################
####################################                                 ####################################
####################################     | Main Body of Script |     ####################################
####################################     v vvvvvvvvvvvvvvvvvvv v     ####################################
#########################################################################################################
#########################################################################################################



if [[ $NUMHTTPD -gt $CRITICAL ]]; then
	echo "CRITICAL - $NUMHTTPD threads running. | 'HTTPD threads running'=$NUMHTTPD;$WARNING;$CRITICAL;; "
	exit $STATE_CRIT
elif [[ $NUMHTTPD -gt $WARNING ]]; then
	echo "WARNING - $NUMHTTPD threads running. | 'HTTPD threads running'=$NUMHTTPD;$WARNING;$CRITICAL;; "
	exit $STATE_WARN
else
	echo "OK - $NUMHTTPD threads running. | 'HTTPD threads running'=$NUMHTTPD;$WARNING;$CRITICAL;; "
	exit $STATE_OK
fi

