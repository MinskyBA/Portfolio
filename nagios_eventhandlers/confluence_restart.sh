#!/bin/bash
## https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/eventhandlers.html

# usage: confluence_restart.sh <SERVICESTATE> <SERVICESTATETYPE> <SERVICEATTEMPT>

SERVICE_STATE=$1
SERVICE_STATE_TYPE=$2
SERVICE_ATTEMPT=$3

SERVER=c-conf1

## LOGGING CAN BE REMOVED ONCE VERIFIED AS WORKING
LOGFILE=/tmp/confluence_restart.log
echo "####" >> $LOGFILE
echo server: $SERVER >> $LOGFILE
echo state: $SERVICE_STATE >> $LOGFILE
echo state_type: $SERVICE_STATE_TYPE >> $LOGFILE
echo attempt: $SERVICE_ATTEMPT >> $LOGFILE
echo $(date) >> $LOGFILE

restart_instance(){
	echo RESTARTING >> $LOGFILE
	ssh apache@<MANAGEMENT_SERVER> "/data/app/scripts/control/confluence-hung_restart.sh"
	## apache@<MANAGEMENT_SERVER> is configured to accept connection from nagios@eqnagiosxi
}

notify_slack(){
	echo "Notifying in slack" >> $LOGFILE
	/home/nagios/slack_nagios.pl -field slack_channel=#general -field HOSTALIAS="$SERVER" -field SERVICEDESC="confluence" -field SERVICESTATE="$SERVICE_STATE" -field SERVICEOUTPUT="$OUTPUT" >> /dev/null 2>&1
}

case "$SERVICE_STATE" in 
	OK) # Notify via slack if OK and first attempt.
		[[ $SERVICE_ATTEMPT == 1 ]] && ( OUTPUT="Recovered" ; notify_slack )
		exit
		;;
	WARNING) # Do nothing if Warning
		exit
		;;
	CRITICAL) # Bounce if cricital on HARD, or 3rd SOFT state
		restart_instance
		OUTPUT="Auto-bouncing" ; notify_slack
		exit
		;;
esac

