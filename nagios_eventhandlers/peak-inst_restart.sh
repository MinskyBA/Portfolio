#!/bin/bash
## https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/eventhandlers.html

# usage: peak-inst_restart.sh <SERVICESTATE> <SERVICESTATETYPE> <SERVICEATTEMPT> <SERVER> <INSTANCE>

SERVICE_STATE=$1
SERVICE_STATE_TYPE=$2
SERVICE_ATTEMPT=$3

HOST_DOWNTIME=$4
SERVICE_DOWNTIME=$5

SERVER=$6
INST=$7

## LOGGING CAN BE REMOVED ONCE VERIFIED AS WORKING
LOGFILE=/tmp/peak-inst_restart.log
echo "####" >> $LOGFILE
echo server: $SERVER >> $LOGFILE
echo inst: $INST >> $LOGFILE
echo state: $SERVICE_STATE >> $LOGFILE
echo state_type: $SERVICE_STATE_TYPE >> $LOGFILE
echo attempt: $SERVICE_ATTEMPT >> $LOGFILE
echo host downtime: $HOST_DOWNTIME >> $LOGFILE
echo service downtime: $SERVICE_DOWNTIME >> $LOGFILE
echo $(date) >> $LOGFILE

restart_instance(){
	echo "RESTARTING..." >> $LOGFILE
	ssh apache@eqprodlog1 "/data/app/scripts/control/peak${SERVER}_inst$INST-bounce.sh -f"
	## apache@eqprodlog1 is configured to accept connection from nagios@eqnagiosxi
	echo "Restart complete" >> $LOGFILE
	echo '' >> $LOGFILE
}

notify_slack(){
	echo "Notifying in slack" >> $LOGFILE
	/home/nagios/slack_nagios.pl -field slack_channel=#general -field HOSTALIAS="eqa-peak$SERVER" -field SERVICEDESC="inst$INST" -field SERVICESTATE="$SERVICE_STATE" -field SERVICEOUTPUT="$OUTPUT" >> /dev/null 2>&1
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
	CRITICAL) # Bounce if Critical
		OUTPUT="Auto-bouncing" ; notify_slack
		restart_instance
		exit
		;;
esac

