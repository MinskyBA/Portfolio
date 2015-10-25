#!/bin/bash
#============================================================================================
#
#	  FILE:		master_controller.sh
# 
USAGE="USAGE: ./master_controller.sh -s [service] <type>"
# 
#   DESCRIPTION:	This script will start, stop, bounce, or rolling bounce services.
#			It reads from /data/app/deployments/prod.deployments
#			non-standard configurations are specified
#
#  REQUIREMENTS:	must specify [rolling, up, or down], as well as service
#	 NOTES:
#	AUTHOR:		Brian Minsky
#       COMPANY:	K12 Inc.
#       CREATED:	Oct 2015
REVISION="Revision: 1.0"
#
#==============================================================================================
###############################################################################################


#################################################################
#################################################################
##################			       ##################
##################	 |  Functions |	       ##################
##################	 v  vvvvvvvvv v	       ##################
#################################################################
#################################################################

testing_function(){	## directly call whichever functions needed
	build_servers_array
	build_services_array
}


print_help(){
	echo $USAGE
}

print_revision(){
	echo $REVISION
}

list_services(){
	build_services_array
	echo "###### Available services:"
	for i in ${SERVICE_ARY[@]};do
		echo $i
	done
	
}	

validate_service_name(){
	SVC_TEST=`grep $SERVICE"=" /data/app/deployments/prod.deployments|wc -l`
	[[ $SVC_TEST == 0 ]] && ( echo "service not found" ; exit )
}

build_server_array(){
	SERVER_ARY=(`grep $SERVICE"=" /data/app/deployments/prod.deployments|cut -d'=' -f2|sed 's/[, ]\+/ /g'`)
	echo "###### servers running provided service:"
	echo ${SERVER_ARY[*]}
	#for i in ${SERVER_ARY[@]};do
	#	echo $i
	#done
}

build_services_array(){
	SERVICE_ARY=(`cat /data/app/deployments/prod.deployments|sed 's/=.*$//'`)
}

startup(){		## runs startup proceduce against each server
	$RUN_REM "${SERVER_ARY[*]}" "$STARTUP_CMD; sleep 5; tail -10 $LOG"
}

shutdown(){		## runs shutdown proceduce against each server
	$RUN_REM "${SERVER_ARY[*]}" "$SHUTDOWN_CMD; sleep 2; pgrep -f $SERVICE | xargs kill -9"
	sleep 2
	$RUN_REM "${SERVER_ARY[*]}" "rm -rf $WORK/*"
}

rolling(){		## runs a rolling bounce, one server at a time
	for i in ${SERVER_ARY[@]};
	do
		$RUN_REM "$i" "$SHUTDOWN_CMD; sleep 2; pgrep -f $SERVICE | xargs kill -9"
		sleep 2
		$RUN_REM "$i" "rm -rf $WORK/*"
		sleep 2
		$RUN_REM "$i" "$STARTUP_CMD"
	done
}

rolling_group(){	## runs a rolling bounce in groups
	echo "Nothing here yet"
	# divide into $ROLLING_GROUPS
}

RUN_REM=/home/bminsky/scripts/runremote_FAKE.sh
CNT=0
ROLLING_GROUPS=1

## Master Array ##
srv_lst=(ALL_CALMS tc_accessui tc_accnts tc_accounts_plus_svc tc_amp_ui)

## Group Arrays IN STARTUP ORDER ##
ALL_CALMS=(tc_calms_ui tc_calms_bus_svc tc_dam_bus_svc)

##########################
####  parse arguments ####
##########################

while [ $# -gt 0 ]; do
	case "$1" in
		-t | --testing)
			testing_function
			exit
			;;
		-h | --help)
			print_help
			exit
			;;
		-v | --version)
			print_revision
			exit
			;;
		-l | --list)
			list_services
			exit
			;;
		-s | --service)
			shift
			SERVICE=$1
			;;
		-up | --startup)
			shift
			ACTION=startup
			CNT=$CNT+1
			;;
		-dn | --shutdown)
			shift
			ACTION=shutdown
			CNT=$CNT+1
			;;
		-r | --rolling)
			shift
			ACTION=rolling
			CNT=$CNT+1
			;;
		-g | --groups)
			shift
			ROLLING_GROUPS=$1
			;;
		*)  echo "Invalid argument: $1"
			print_help
			exit
			;;
		esac
	shift
done

echo "service is: $SERVICE"
echo "Action is: $ACTION"

if [[ $CNT -gt 1 ]] || [[ $CNT == 0 ]] ; then
	echo "You must use exactly one of the following options: [-r|--rolling], [-up|--startup], or [-dn|--shutdown]."
	exit
fi

validate_service_name

build_server_array

case "$SERVICE" in	## define standard config files for unique cases, else standard_config 
	tc-special)
		LOG=/unique/location/catalina.out
		WORK=/unique/location/work
		SHUTDOWN_CMD=/unique/location/bin/shut_it_down.sh
		STARTUP_CMD=/unique/location/bin/shart_it_up.sh
		;;
	tc-unique)
		LOG=/special/location/catalina.out
		WORK=/special/location/work
		SHUTDOWN_CMD=/special/location/bin/shut_it_down.sh
		STARTUP_CMD=/special/location/bin/shart_it_up.sh
		;;
	*)
	        LOG=/data/servers/$SERVICE/logs/catalina.out
	        WORK=/data/servers/$SERVICE/work
	        SHUTDOWN_CMD=/data/servers/$SERVICE/bin/shutdown.sh
	        STARTUP_CMD=/data/servers/$SERVICE/bin/startup.sh
		;;
esac

case "$ACTION" in 
	startup)
		startup
		;;
	shutdown)
		shutdown
		;;
	rolling)
		if [[ $ROLLING_GROUPS != 1 ]];then
			rolling
		else
			rolling_group
		fi
		;;
esac
exit

#LOGFILE="/tmp/$SERVICE-$$.log"
#ADDRTO=""
#SUBJECT="**XXX Rolling Restart is Complete**"

#echo "XXX Rolling Restart complete"  >> ${LOGFILE}
#echo ''  >> ${LOGFILE}
#
#
#cat ${LOGFILE} | mail -s "${SUBJECT}" ${ADDRTO}
#
