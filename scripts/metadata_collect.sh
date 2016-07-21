#!/bin/bash - 
#===============================================================================
#
#         FILE:	metadata_collect.sh
# 
#        USAGE:	./metadata_collect.sh 
# 
#  DESCRIPTION:	This script is designed to be run daily as root on every production server.
#		It collects metadata from select files and commands and stores 
#		it in a centra location formatted for easy retrieval.  
# 
# REQUIREMENTS:	---
#         BUGS:	---
#        NOTES:	---
#       AUTHOR:	bminsky as root (), 
# ORGANIZATION:	
#      CREATED:	08/03/2015 14:18
#     REVISION: 	---
#===============================================================================
set -o nounset			# Treat unset variables as an error

META_DIR=/data/metadata/data
TIME=$(date +%Y-%m-%d_%H-%M-%S)
HOST=`hostname -s`

HOST_DIR=$META_DIR/$HOST	# /data/metadata/data/eqprodtc36
PREFIX=$HOST_DIR/$HOST		# /data/metadata/data/eqprodtc36/eqprodtc36
#===============================================================================


# Inform SAND that this is Running.
#### curl --connect-timeout 2 --max-time 10 http://sand.<COMPANY>.int/SAND/NODES/job_status.php?script=$0\&host=$HOST\&status=Running



# directory creation, move previous data
if [ -d $HOST_DIR ]				# if the host directory exists
then						# then
	rm -rf $HOST_DIR/.previous/*		# clear the previous data
	mv $HOST_DIR/$HOST* $HOST_DIR/.previous	# move current data to previous
else						# else
	mkdir -p $HOST_DIR/.previous		# make the directories
fi





#####################################################################
#####################################################################
##################                                 ##################
##################         |  Functions |          ##################
##################         v  vvvvvvvvv v          ##################
#####################################################################
#####################################################################
# test if files added
# test if files removed
#difference(){
#	echo $TIME >> $PREFIX.CHANGES
#	#DIF=$(diff -rq $HOST_DIR $HOST_DIR/.previous/ --exclude .previous --exclude *.uptime) 
#	#if DIF is not blank, write $TIME and $DIF to $PREFIX.CHANGES
#}

# test if files changed



#####################################################################
##   ^ ^^^^^^^^^^^^^^^^ ^   #########################################
##   | End of Functions |   #########################################
#####################################################################
#####################################################################





# compare existing metada file to file in prod. If different, copy new and echo name/date to date.changed file.
# move all files to YESTERDAY dir
# compare new files to backup/tmp
# note differences
#


###############
#### FILES ####
###############
cp /etc/sysconfig/network		$PREFIX.network
cp /etc/k12/services.txt		$PREFIX.services.txt
cp /etc/nagios/nrpe.cfg			$PREFIX.nrpe.cfg
cp /etc/sudoers				$PREFIX.sudoers
cp /etc/fstab				$PREFIX.fstab
cp /etc/hosts				$PREFIX.hosts
cp /var/cfengine/inputs/cfagent.conf	$PREFIX.cfagent.conf
cp /etc/resolv.conf			$PREFIX.resolv.conf
cp /etc/profile				$PREFIX.profile
cp /etc/ssh/sshd_config			$PREFIX.sshd_config
cp /etc/ntp.conf			$PREFIX.ntp.conf


## bash* -?
# worth collecting?



## ifcfg-eth*
cd /etc/sysconfig/network-scripts/
for eth in $(ls ifcfg-*)
do
	cp $eth $PREFIX.$eth
done

## route-eth*
cd /etc/sysconfig/network-scripts/
for route in $(ls route-*)
do
	cp $route $PREFIX.$route
done

## crontabs
cd /var/spool/cron/
for tab in $(ls)
do
	cp $tab $PREFIX.crontab.$tab
done

# system crontabs
cd /etc/
for systab in cron*
do
	if [[ -d $systab ]]	## if directory
	then			## tail all (full) files to single flat file - this may not be the best solution
		tail -n +1 $systab/* >> $PREFIX.$systab.multiple_files
	else
		cp $systab $PREFIX.$systab
	fi
done


##################
#### commands ####
##################
/sbin/ifconfig -a | grep -e 'Link\|addr\|^$' > 		$PREFIX.ifconfig_a
/sbin/route >						$PREFIX.route
/bin/netstat -rn >					$PREFIX.netstat_rn
/bin/uname -a >						$PREFIX.uname_a
/usr/bin/uptime >					$PREFIX.uptime
/usr/sbin/dmidecode | sed -n '/System Info/,/^$/p' >	$PREFIX.dmidecode.SysInfo
/usr/bin/yum list installed > 				$PREFIX.yum.list.installed
md5sum /etc/shadow >					$PREFIX.shadow.md5


###############
#### CLEAN ####
###############

# remove any blank files
cd $HOST_DIR
for i in $(ls)
do
	[ ! -s $i ] && rm $i
done


#################
#### CHANGES ####
#################
#
# test if files added
# test if files removed
#difference
# test if files changed





# set all files to r/w for root:root only
chmod -R 660 $HOST_DIR/*

# Inform SAND that this has Completed.
#### curl --connect-timeout 2 --max-time 10 http://sand.<COMPANY>.int/SAND/NODES/job_status.php?script=$0\&host=$HOST\&status=Completed

