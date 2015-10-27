#!/bin/bash
## https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/eventhandlers.html

# usage: lms-inst_restart.sh <SERVICESTATE> <SERVICESTATETYPE> <SERVICEATTEMPT> <SERVER_NAME> <SERVER_ADDRESS> <INSTANCE>

SERVICE_STATE=$1
SERVICE_STATE_TYPE=$2
SERVICE_ATTEMPT=$3

SERVER_NAME=$4
SERVER_ADDRESS=$5

HOST_DOWNTIME=$6
SERVICE_DOWNTIME=$7

INST=$8

## LOGGING CAN BE REMOVED ONCE VERIFIED AS WORKING
LOGFILE=/tmp/lms-inst_restart.log
echo "####" >>					$LOGFILE
echo server name: $SERVER_NAME >>		$LOGFILE
echo server address: $SERVER_ADDRESS >>		$LOGFILE
echo inst: $INST >>				$LOGFILE
echo state: $SERVICE_STATE >>			$LOGFILE
echo state_type: $SERVICE_STATE_TYPE >>		$LOGFILE
echo attempt: $SERVICE_ATTEMPT >>		$LOGFILE
echo host downtime: $HOST_DOWNTIME >>		$LOGFILE
echo service downtime: $SERVICE_DOWNTIME >>	$LOGFILE
echo $(date) >>					$LOGFILE

restart_instance(){
	echo "RESTARTING..." >> $LOGFILE
	ssh apache@<MANAGEMENT_SERVER> "/data/app/scripts/control/tc-lms-restart $SERVER_ADDRESS $INST"
	## apache@<MANAGEMENT_SERVER> is configured to accept connection from nagios@eqnagiosxi
	echo "Restart complete" >> $LOGFILE
	echo '' >> $LOGFILE
}

notify_slack(){
	echo "Notifying in slack" >> $LOGFILE
	/home/nagios/slack_nagios.pl -field slack_channel=#general -field HOSTALIAS="$SERVER_NAME" -field SERVICEDESC="tc-lms$INST" -field SERVICESTATE="$SERVICE_STATE" -field SERVICEOUTPUT="$OUTPUT" >> /dev/null 2>&1
}

[[ $HOST_DOWNTIME != 0 ]] || [[ $SERVICE_DOWNTIME != 0 ]] && exit

case "$SERVICE_STATE" in 
	OK) # Notify via slack if OK and first attempt.
		[[ $SERVICE_ATTEMPT != 1 ]] && ( OUTPUT="Recovered" ; notify_slack )
		exit
		;;
	WARNING) # Do nothing if Warning
		exit
		;;
	CRITICAL) # Bounce if cricital on HARD, or 3rd SOFT state
		OUTPUT="Auto-bouncing" ; notify_slack
		restart_instance
		exit
		;;
esac

