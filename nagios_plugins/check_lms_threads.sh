#!/bin/bash
#============================================================================================
#
#          FILE:        check_apache_threads.sh
# 
USAGE="USAGE: ./check_lms_threads.sh -w <##> -c <##> -i <#>"
# 
#   DESCRIPTION:        This script counts the number of LMS threads per instance provided
#
#  REQUIREMENTS:        warning and critical thresholds, instance 
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
	-i | --instance)
		shift
		INSTANCE=$1
		;;
	*)  echo "Invalid argument: $1"
		print_help
		exit $STATE_WARN
		;;
	esac
shift
done

#### Instance 1 is blank, eg: tc-lms
[[ $INSTANCE == 1 ]] && INSTANCE=''

COUNT=`ps uH $(pgrep -f tc-lms${INSTANCE}/) | wc -l`

#########################################################################################################
#########################################################################################################
####################################                                 ####################################
####################################     | Main Body of Script |     ####################################
####################################     v vvvvvvvvvvvvvvvvvvv v     ####################################
#########################################################################################################
#########################################################################################################

if [[ $COUNT -gt $CRITICAL ]]; then
	echo "CRITICAL - $COUNT threads running. | 'LMS threads running'=$COUNT;$WARNING;$CRITICAL;; "
	exit $STATE_CRIT
elif [[ $COUNT -gt $WARNING ]]; then
	echo "WARNING - $COUNT threads running. | 'LMS threads running'=$COUNT;$WARNING;$CRITICAL;; "
	exit $STATE_WARN
else
	echo "OK - $COUNT threads running. | 'LMS threads running'=$COUNT;$WARNING;$CRITICAL;; "
	exit $STATE_OK
fi
