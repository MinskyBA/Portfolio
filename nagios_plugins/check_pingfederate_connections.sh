#!/bin/bash
#============================================================================================
#
#          FILE:        check_pingfederate_connections.sh
# 
USAGE="USAGE: ./check_pingfederate_connections.sh -w <##> -c <##>"
# 
#   DESCRIPTION:        This script compares the number of established java connections
#			against warning	and critical values passed via arguments. The
#			output is for nagios, including performance data.
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

CONNECTIONS=`netstat -anp --tcp | grep -i EST | grep java | wc -l`

#########################################################################################################
#########################################################################################################
####################################                                 ####################################
####################################     | Main Body of Script |     ####################################
####################################     v vvvvvvvvvvvvvvvvvvv v     ####################################
#########################################################################################################
#########################################################################################################



if [[ $CONNECTIONS -lt $WARNING ]] ; then
	echo "OK - $CONNECTIONS established connections | 'Established connections'=$CONNECTIONS;$WARNING;$CRITICAL;;"
	exit $STATE_OK
elif [[ $CONNECTIONS -lt $CRITICAL ]] ; then
	echo "WARNING - $CONNECTIONS established connections | 'Established connections'=$CONNECTIONS;$WARNING;$CRITICAL;;"
	exit $STATE_WARN
else
	echo "CRITICAL - $CONNECTIONS established connections | 'Established connections'=$CONNECTIONS;$WARNING;$CRITICAL;;"
	exit $STATE_CRIT
fi

