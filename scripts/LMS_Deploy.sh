#!/bin/bash
#============================================================================================
#
#          FILE:	LMS_Deploy
# 
#         USAGE:	./LMS_Deploy.sh DP-XXXXX
# 
#   DESCRIPTION:	This script is designed to manage LMS deployments across platforms.
#			Most functions can be performed separately:
#				DL Jira-ticket attachments
#				Extract steps from body of ticket
#				DL Maven deployment files
#				DL Maven QA deployment files
#				List files to be changed in prod/QA
#				Backup files to be changed in prod/QA
#				Create deploy script
#
#			FEATURES TO ADD:
#       			put Nagios into downtime
#       			create shutdown/startup scripts
#       			Log confirmation scripts
#				Option to input all choices as flags and skip the questions
#				Save md5sums from QA, verify during prod to catch illegal changes
#				qa_lms_messages.properties should be test{1..6}_lms_messages.properties
#					for TEST{1..6}
#				account for lack of deploy to /data/content, or .war, or .tar
#
#       OPTIONS:	TO BE ADDED
#  REQUIREMENTS:	Jira ticket number
#			/home/apache/.jira_password must exist and contain jira credentials
#          BUGS:	Attachments with spaces in the name will fail
#			only works for maven files ending in .war, .tar, or .zip, NOT .gz
#         NOTES:
#        AUTHOR:	Brian Minsky
#			        portions taken from download_jira_attachments.sh by Troy Gooch
#       COMPANY:	K12 Inc.
#       VERSION:	2.0
#       CREATED:	Nov,Dec 2014
#
#==============================================================================================
###############################################################################################

[[ $(whoami) = "root" ]] && { echo "Root's dangerous! Please run as *apache*"; exit 1; }
[[ $(whoami) != "apache" ]] && { echo "Nice try n00b, please run as *apache*"; exit 1; }


##################################
##   Variables   #################
##################################

source /home/apache/.jira_password

TICKNUM=$1
TICKDIR=/var/DEPLOYMENTS/$TICKNUM
LOGDIR=$TICKDIR/log
DOWNLOADDIR=$TICKDIR/download
JIRASH=/data/app/jira-cli/jira.sh
JIRA="$JIRASH --server https://jira.k12.com --user $JUser --password $JPass"


#####################################################################
#####################################################################
##################                                 ##################
##################         |  Functions |          ##################
##################         v  vvvvvvvvv v          ##################
#####################################################################
#####################################################################

##############################################
##  moves DP directory if it already exists
##############################################
moveit(){ {
	if [ -d "$@" ] || [ -f "$@" ]; then			# If $TICKETDIR is a directory or regular file
		echo "############################################"
		echo "##  Ticket directory exists, renaming...  ##"
		echo "############################################"
		echo ""
		mv -i -v ${@%/}{,.$(date "+%Y%m%d-%H%M%S")};	# Move and rename with date
		echo ""
	else
		echo "ERROR: $@ does NOT exist" && return 1;
	fi
} 2>&1 | tee -a $LOGDIR/master.log
}

##############################################
##  Write comment to Jira ticket
##############################################
addcomment(){
    $JIRA --action addComment --comment "$COMMENT" --issue $TICKNUM
}

##############################################
##  DL all attachments from ticket
##############################################
getattachments(){ {
	mkdir $DOWNLOADDIR/Jira-attachments
	cd $TICKDIR
	echo ""
	echo "##############################################"
	echo "##  Generating the list of attachments ...  ##"
	echo "##############################################"
	echo ""
	$JIRA -a getAttachmentList --issue "$TICKNUM" 2>&1 |  grep '"[0-9]' | cut -d\, -f 2 | sed 's|"\(.*\)"|\1|' | grep -vi sql | grep -vi "test[0-9]" | grep -vi tst[0-9] | grep -vi pdc$ | grep -vi rpd$ | grep -v pdf$ | grep -vi stg | grep -vi Staging | grep -vi qa[0-9]* | grep -v xml$ | grep -v '_dev_' | grep -v log$ | grep -v out$ | grep -vi ddl | grep -v docx$ | tee -a $LOGDIR/attachmentlist
	echo ""
	echo "#############################################################"
	echo "##  Saved as $LOGDIR/attachmentlist  ##"
	echo "#############################################################"
	echo ""
	echo ""
	echo "###############################################################################################"
	echo "##  Downloading the attachment files to $DOWNLOADDIR/Jira-attachments  ##"
	echo "###############################################################################################"
	cd $DOWNLOADDIR/Jira-attachments
	cat $LOGDIR/attachmentlist | while read file; do
		echo ""
		echo fetching $file
		echo ""
		$JIRA -a getAttachment --issue $TICKNUM --file "$file" -v && { echo; echo -n "md5sum: "; md5sum $file; echo; } || { echo ERROR; exit 1; }
	done
	echo >> $LOGDIR/attachmentlist
	cat $LOGDIR/download-jira.log | grep md5sum >>$LOGDIR/attachmentlist
	echo
} 2>&1 | tee -a $LOGDIR/download-jira.log | tee -a $LOGDIR/master.log
}

########################################################
##  Extracts steps from ticket into separate txt files
########################################################
extractsteps(){ {
	cd $TICKDIR
	echo "###############################"
	echo "##  Reading ticket text ...  ##"
	echo "###############################"
	echo ""
	$JIRA -a getIssue --issue "$TICKNUM" 2>&1 | tee -a TicketText.txt | grep Error --color
	cat TicketText.txt | sed -n -e '/^QA-Specific Deployment Steps/,/^Rank/p' | sed '$d' >0-QA-Specific-Deployment-Steps.txt
	cat TicketText.txt | sed -n -e '/^Pre-Deployment Steps/,/^Production Release Date/p' | sed '$d' >1-Pre-Deployment-Steps.txt
	cat TicketText.txt | sed -n -e '/^Splash Pages Needed/,/^Testing Status/p' | sed '$d' >2-Splash-Pages-Needed.txt
	cat TicketText.txt | sed -n -e '/^Deployment Steps/,/^Deployment Window Requested/p' | sed '$d' >3-Deployment-Steps.txt
	cat TicketText.txt | sed -n -e '/^Post Deployment Steps/,/^Pre-Deployment Steps/p' | sed '$d' >4-Post-Deployment-Steps.txt
} 2>&1 | tee -a $LOGDIR/master.log
}

########################################################
##  DL Maven files listed in Deployment Steps
########################################################
dlmavendeployment(){ {
	echo "########################################################"
	echo "##  Downloading prod deployment files from Maven ...  ##"
	echo "########################################################"
	echo ""
	cd $DOWNLOADDIR
	mkdir -p Deployment-Files/servers Deployment-Files/content Deployment-Files/war Deployment-Files/tar

# DL files to be deployed to /data/servers
	for i in $(grep maven $TICKDIR/3-Deployment-Steps.txt | grep '\.zip' | grep -vi sql |grep '\/data\/servers' | sed -e 's|.*\(http://.*.zip\).*|\1|' | sort -u); 
		do echo $i; wget -P $DOWNLOADDIR/Deployment-Files/servers/ ${i} && echo "Completed" || echo "Failed"; echo; 
	done

# DL files to be deployed to /data/batch
        for i in $(grep maven $TICKDIR/3-Deployment-Steps.txt | grep '\.zip' | grep -vi sql |grep '\/data\/batch' | sed -e 's|.*\(http://.*.zip\).*|\1|' | sort -u);
                do echo $i; wget -P $DOWNLOADDIR/Deployment-Files/batch/ ${i} && echo "Completed" || echo "Failed"; echo;
        done

# DL files to be deployed to /data/content/static.k12.com
	for i in $(grep maven $TICKDIR/3-Deployment-Steps.txt | grep '\.zip' | grep -vi sql |grep '\/data\/content' | sed -e 's|.*\(http://.*.zip\).*|\1|' | sort -u);
		do echo $i; wget -P $DOWNLOADDIR/Deployment-Files/content/ ${i} && echo "Completed" || echo "Failed"; echo; 
	done

# DL war files
	for i in $(grep maven $TICKDIR/3-Deployment-Steps.txt | grep '\.war' | grep -vi sql | sed -e 's|.*\(http://.*.war\).*|\1|' | sort -u);
		do echo $i; wget -P $DOWNLOADDIR/Deployment-Files/war/ ${i} && echo "Completed" || echo "Failed"; echo;
	done

# DL tar files
	for i in $(grep maven $TICKDIR/3-Deployment-Steps.txt | grep '\.tar' | grep -vi sql | sed -e 's|.*\(http://.*.tar\).*|\1|' | sort -u);
                do echo $i; wget -P $DOWNLOADDIR/Deployment-Files/tar/ ${i} && echo "Completed" || echo "Failed"; echo;
	done
} | tee -a $LOGDIR/download-maven.log | tee -a $LOGDIR/master.log
}

###########################################################
##  DL Maven files listed in QA-Specific Deployment Steps
###########################################################
dlmavenqa(){ {
	echo "######################################################"
	echo "##  Downloading QA deployment files from Maven ...  ##"
	echo "######################################################"
	echo ""
	cd $DOWNLOADDIR
	mkdir -p QA-Specific-Deployment-Files/servers QA-Specific-Deployment-Files/content QA-Specific-Deployment-Files/war QA-Specific-Deployment-Files/tar QA-Specific-Deployment-Files/sql

# DL files to be deployed to /data/servers
    for i in $(grep maven $TICKDIR/0-QA-Specific-Deployment-Steps.txt | grep '\.zip' | grep -vi sql |grep '\/data\/servers' | sed -e 's|.*\(http://.*.zip\).*|\1|' | sort -u);
        do echo $i; wget -P $DOWNLOADDIR/QA-Specific-Deployment-Files/servers/ ${i} && echo "Completed" || echo "Failed"; echo;
    done

# DL files to be deployed to /data/batch
    for i in $(grep maven $TICKDIR/0-QA-Specific-Deployment-Steps.txt | grep '\.zip' | grep -vi sql |grep '\/data\/batch' | sed -e 's|.*\(http://.*.zip\).*|\1|' | sort -u);
        do echo $i; wget -P $DOWNLOADDIR/QA-Specific-Deployment-Files/batch/ ${i} && echo "Completed" || echo "Failed"; echo;
    done

# DL files to be deployed to /data/content/static.k12.com
    for i in $(grep maven $TICKDIR/0-QA-Specific-Deployment-Steps.txt | grep '\.zip' | grep -vi sql |grep '\/data\/content' | sed -e 's|.*\(http://.*.zip\).*|\1|' | sort -u);
        do echo $i; wget -P $DOWNLOADDIR/QA-Specific-Deployment-Files/content/ ${i} && echo "Completed" || echo "Failed"; echo;
    done

# DL war files
    for i in $(grep maven $TICKDIR/0-QA-Specific-Deployment-Steps.txt | grep '\.war' | grep -vi sql | sed -e 's|.*\(http://.*.war\).*|\1|' | sort -u);
        do echo $i; wget -P $DOWNLOADDIR/QA-Specific-Deployment-Files/war/ ${i} && echo "Completed" || echo "Failed"; echo;
    done

# DL tar files
    for i in $(grep maven $TICKDIR/0-QA-Specific-Deployment-Steps.txt | grep '\.tar' | grep -vi sql | sed -e 's|.*\(http://.*.tar\).*|\1|' | sort -u);
        do echo $i; wget -P $DOWNLOADDIR/QA-Specific-Deployment-Files/tar/ ${i} && echo "Completed" || echo "Failed"; echo;
    done

# DL sql files
    for i in $(grep maven $TICKDIR/0-QA-Specific-Deployment-Steps.txt | grep 'sql\.zip' | sed -e 's|.*\(http://.*sql\.zip\).*|\1|' | sort -u);
        do echo $i; wget -P $DOWNLOADDIR/QA-Specific-Deployment-Files/sql/ ${i} && echo "Completed" || echo "Failed"; echo;
    done
} | tee -a $LOGDIR/download-maven-QA.log | tee -a $LOGDIR/master.log
}

##########################################################
## Create a list of files to be deployed to prod
## Also creates Deploy-to-prod.sh
##########################################################
listprodchanges(){ {
	echo "############################################"
	echo "##  Listing files to be deployed to prod  ##"
	echo "##         &                              ##"
	echo "##  Creating Deploy-to-prod.sh ...	##"
	echo "############################################"
	echo ""

	touch $TICKDIR/Deploy-to-prod.sh
	echo "#!/bin/bash"								>> $TICKDIR/Deploy-to-prod.sh
	echo "#" 									>> $TICKDIR/Deploy-to-prod.sh
	echo "#" 									>> $TICKDIR/Deploy-to-prod.sh
	echo "# Created by the listprodchanges function within LMS_Deploy.sh script" 	>> $TICKDIR/Deploy-to-prod.sh
	echo "" 									>> $TICKDIR/Deploy-to-prod.sh
	echo '[[ $(whoami) != "apache" ]] && { echo "**MUST BE APACHE**"; exit 1; }' 	>> $TICKDIR/Deploy-to-prod.sh
	echo ""										>> $TICKDIR/Deploy-to-prod.sh

	cd $DOWNLOADDIR/Deployment-Files/servers
#	rm -f $DOWNLOADDIR/Deployment-Files.servers.changes
	echo "# Files to be deployed to /data/servers/ :" >> $TICKDIR/Deploy-to-prod.sh						##  Writes to Deploy-to-prod.sh
	for LSTPRDCHG in *.zip
		do					## This loop lists files to be deployed to /data/servers
		unzip -l $LSTPRDCHG | tail -n+4 | head -n-2 | awk '{print $4}' | sed -e '/\/$/d' | sed -e 's/\.\///g' | sed 's/^/\/data\/servers\//g' >> $DOWNLOADDIR/Deployment-Files.servers.changes;
		echo "unzip -o $DOWNLOADDIR/Deployment-Files/servers/$LSTPRDCHG -d /data/servers" >> $TICKDIR/Deploy-to-prod.sh	##  Writes to Deploy-to-prod.sh
	done;

        cd $DOWNLOADDIR/Deployment-Files/batch
#       rm -f $DOWNLOADDIR/Deployment-Files.batch.changes
        echo "# Files to be deployed to /data/batch/ :" >> $TICKDIR/Deploy-to-prod.sh                                         ##  Writes to Deploy-to-prod.sh
        for LSTPRDCHG in *.zip
                do                                      ## This loop lists files to be deployed to /data/batch
                unzip -l $LSTPRDCHG | tail -n+4 | head -n-2 | awk '{print $4}' | sed -e '/\/$/d' | sed -e 's/\.\///g' | sed 's/^/\/data\/batch\//g' >> $DOWNLOADDIR/Deployment-Files.batch.changes;
                echo "unzip -o $DOWNLOADDIR/Deployment-Files/batch/$LSTPRDCHG -d /data/batch" >> $TICKDIR/Deploy-to-prod.sh ##  Writes to Deploy-to-prod.sh
        done;

	cd $DOWNLOADDIR/Deployment-Files/content
#	rm -f $DOWNLOADDIR/Deployment-Files.content.changes
        echo "" >> $TICKDIR/Deploy-to-prod.sh											##  Writes to Deploy-to-prod.sh
        echo "# Files to be deployed to /data/content/static.k12.com/ :" >> $TICKDIR/Deploy-to-prod.sh				##  Writes to Deploy-to-prod.sh
        for LSTPRDCHG in *.zip
        	do                                      ## This loop lists files to be deployed to /data/content/static.k12.com
		CURRENTPATH=`grep $LSTPRDCHG $TICKDIR/3-Deployment-Steps.txt |sed -e 's/^.* to //g'` 
                unzip -l $LSTPRDCHG | tail -n+4 | head -n-2 | awk '{print $4}' | sed -e '/\/$/d' | sed -e 's/\.\///g'|sed "s:^:$CURRENTPATH/:g"  >> $DOWNLOADDIR/Deployment-Files.content.changes;
		echo "mkdir -p $CURRENTPATH" >> $TICKDIR/Deploy-to-prod.sh							##  Writes to Deploy-to-prod.sh
		echo "unzip -o $DOWNLOADDIR/Deployment-Files/content/$LSTPRDCHG -d $CURRENTPATH" >> $TICKDIR/Deploy-to-prod.sh	##  Writes to Deploy-to-prod.sh
        done;

	cd $DOWNLOADDIR/Deployment-Files/war
#       rm -f $DOWNLOADDIR/Deployment-Files.war.changes
	echo "" >> $TICKDIR/Deploy-to-prod.sh											##  Writes to Deploy-to-prod.sh
        echo "# war files to be extracted:" >> $TICKDIR/Deploy-to-prod.sh							##  Writes to Deploy-to-prod.sh
        for LSTPRDCHG in *.war
        	do                                      ## This loop lists changes made from war files
                CURRENTPATH=`grep $LSTPRDCHG $TICKDIR/3-Deployment-Steps.txt |sed -e 's/^.* to //g'`
                unzip -l $LSTPRDCHG | tail -n+4 | head -n-2 | awk '{print $4}' | sed -e '/\/$/d' | sed -e 's/\.\///g'|sed "s:^:$CURRENTPATH/:g"  >> $DOWNLOADDIR/Deployment-Files.war.changes;
		echo "mkdir -p $CURRENTPATH" >> $TICKDIR/Deploy-to-prod.sh                                                      ##  Writes to Deploy-to-prod.sh
		echo "unzip -o $DOWNLOADDIR/Deployment-Files/war/$LSTPRDCHG -d $CURRENTPATH" >> $TICKDIR/Deploy-to-prod.sh	##  Writes to Deploy-to-prod.sh
        done;

	cd $DOWNLOADDIR/Deployment-Files/tar
#	rm -f $DOWNLOADDIR/Deployment-Files.tar.changes
        echo "" >> $TICKDIR/Deploy-to-prod.sh                                                                                   ##  Writes to Deploy-to-prod.sh
        echo "# tar files to be extracted:" >> $TICKDIR/Deploy-to-prod.sh                                                       ##  Writes to Deploy-to-prod.sh
        for LSTPRDCHG in *.tar
	        do                                      ## This loop lists changes made from tar files
                CURRENTPATH=`grep $LSTPRDCHG $TICKDIR/3-Deployment-Steps.txt |sed -e 's/^.* to //g'`
                tar -tf $LSTPRDCHG | sed -e '/\/$/d' |sed "s:^:$CURRENTPATH/:g"  >> $DOWNLOADDIR/Deployment-Files.tar.changes;
		echo "mkdir -p $CURRENTPATH" >> $TICKDIR/Deploy-to-prod.sh                                                      ##  Writes to Deploy-to-prod.sh
		echo "tar -xvf $DOWNLOADDIR/Deployment-Files/tar/$LSTPRDCHG -C $CURRENTPATH" >> $TICKDIR/Deploy-to-prod.sh	##  Writes to Deploy-to-prod.sh
        done;
} 2>&1 | tee -a $LOGDIR/master.log
}

################################################
## Create a list of files to be deployed to QA
## Also creates Deploy-to-QA.sh
################################################
listqachanges(){ {
	echo "##########################################"
	echo "##  Listing files to be deployed to QA  ##"
	echo "##         &                            ##"
	echo "##  Creating Deploy-to-QA.sh ...        ##"
	echo "##########################################"
	echo ""

	touch $TICKDIR/Deploy-to-QA.sh
	echo "#!/bin/bash" 								>> $TICKDIR/Deploy-to-QA.sh
	echo "#" 									>> $TICKDIR/Deploy-to-QA.sh
	echo "#" 									>> $TICKDIR/Deploy-to-QA.sh
	echo "# Created by the listqachanges function within LMS_Deploy.sh script" 	>> $TICKDIR/Deploy-to-QA.sh
	echo "" 									>> $TICKDIR/Deploy-to-QA.sh
	echo '[[ $(whoami) != "apache" ]] && { echo "**MUST BE APACHE**"; exit 1; }'    >> $TICKDIR/Deploy-to-QA.sh
	echo ""										>> $TICKDIR/Deploy-to-QA.sh

	cd $DOWNLOADDIR/QA-Specific-Deployment-Files/servers
#	rm -f $DOWNLOADDIR/QA-Specific-Deployment-Files.servers.changes
        for LSTPRDCHG in *.zip
                do                                      ## This loop lists files to be deployed to /data/servers
                unzip -l $LSTPRDCHG | tail -n+4 | head -n-2 | awk '{print $4}' | sed -e '/\/$/d' | sed -e 's/\.\///g' | sed "s/^/\/$DATA\/servers\//g" >> $DOWNLOADDIR/QA-Specific-Deployment-Files.servers.changes;
                echo "unzip -o $DOWNLOADDIR/QA-Specific-Deployment-Files/servers/$LSTPRDCHG -d /$DATA/servers" >> $TICKDIR/Deploy-to-QA.sh	##  Writes to Deploy-to-QA.sh
        done;

        cd $DOWNLOADDIR/QA-Specific-Deployment-Files/batch
#       rm -f $DOWNLOADDIR/QA-Specific-Deployment-Files.batch.changes
        for LSTPRDCHG in *.zip
                do                                      ## This loop lists files to be deployed to /data/batch
                unzip -l $LSTPRDCHG | tail -n+4 | head -n-2 | awk '{print $4}' | sed -e '/\/$/d' | sed -e 's/\.\///g' | sed "s/^/\/$DATA\/batch\//g" >> $DOWNLOADDIR/QA-Specific-Deployment-Files.batch.changes;
                echo "unzip -o $DOWNLOADDIR/QA-Specific-Deployment-Files/batch/$LSTPRDCHG -d /$DATA/batch" >> $TICKDIR/Deploy-to-QA.sh      ##  Writes to Deploy-to-QA.sh
        done;


        cd $DOWNLOADDIR/QA-Specific-Deployment-Files/content
#	rm -f $DOWNLOADDIR/QA-Specific-Deployment-Files.content.changes
        echo "" >> $TICKDIR/Deploy-to-QA.sh													##  Writes to Deploy-to-QA.sh
        echo "# Files to be deployed to /$DATA/content/static.k12.com/ :" >> $TICKDIR/Deploy-to-QA.sh						##  Writes to Deploy-to-QA.sh
        for LSTPRDCHG in *.zip
                do                                      ## This loop lists files to be deployed to /$DATA/content/static.k12.com
                CURRENTPATH=`grep $LSTPRDCHG $TICKDIR/0-QA-Specific-Deployment-Steps.txt |sed -e 's/^.* to //g' | sed -e "s/data/$DATA/g"`
                unzip -l $LSTPRDCHG | tail -n+4 | head -n-2 | awk '{print $4}' | sed -e '/\/$/d' | sed -e 's/\.\///g'|sed "s:^:$CURRENTPATH/:g"  >> $DOWNLOADDIR/QA-Specific-Deployment-Files.content.changes;
		echo "mkdir -p $CURRENTPATH" >> $TICKDIR/Deploy-to-QA.sh									##  Writes to Deploy-to-QA.sh
                echo "unzip -o $DOWNLOADDIR/QA-Specific-Deployment-Files/content/$LSTPRDCHG -d $CURRENTPATH" >> $TICKDIR/Deploy-to-QA.sh	##  Writes to Deploy-to-QA.sh
        done;

        cd $DOWNLOADDIR/QA-Specific-Deployment-Files/war
#	rm -f $DOWNLOADDIR/QA-Specific-Deployment-Files.war.changes
        echo "" >> $TICKDIR/Deploy-to-QA.sh                                                                                                     ##  Writes to Deploy-to-QA.sh
        echo "# war files to be extracted:" >> $TICKDIR/Deploy-to-QA.sh										##  Writes to Deploy-to-QA.sh
        for LSTPRDCHG in *.war
                do                                      ## This loop lists changes made from war files
                CURRENTPATH=`grep $LSTPRDCHG $TICKDIR/0-QA-Specific-Deployment-Steps.txt |sed -e 's/^.* to //g' | sed -e "s/data/$DATA/g"`
                unzip -l $LSTPRDCHG | tail -n+4 | head -n-2 | awk '{print $4}' | sed -e '/\/$/d' | sed -e 's/\.\///g'|sed "s:^:$CURRENTPATH/:g"  >> $DOWNLOADDIR/QA-Specific-Deployment-Files.war.changes;
		echo "mkdir -p $CURRENTPATH" >> $TICKDIR/Deploy-to-QA.sh                                                                        ##  Writes to Deploy-to-QA.sh
                echo "unzip -o $DOWNLOADDIR/QA-Specific-Deployment-Files/war/$LSTPRDCHG -d $CURRENTPATH" >> $TICKDIR/Deploy-to-QA.sh		##  Writes to Deploy-to-QA.sh
        done;

        cd $DOWNLOADDIR/QA-Specific-Deployment-Files/tar
#	rm -f $DOWNLOADDIR/QA-Specific-Deployment-Files.tar.changes
	echo "" >> $TICKDIR/Deploy-to-QA.sh                                                                                                     ##  Writes to Deploy-to-QA.sh
        echo "# tar files to be extracted:" >> $TICKDIR/Deploy-to-QA.sh                                                                         ##  Writes to Deploy-to-QA.sh
        for LSTPRDCHG in *.tar
                do                                      ## This loop lists changes made from tar files
                CURRENTPATH=`grep $LSTPRDCHG $TICKDIR/0-QA-Specific-Deployment-Steps.txt |sed -e 's/^.* to //g' | sed -e "s/data/$DATA/g"`
                tar -tf $LSTPRDCHG | sed -e '/\/$/d' |sed "s:^:$CURRENTPATH/:g"  >> $DOWNLOADDIR/QA-Specific-Deployment-Files.tar.changes;
		echo "mkdir -p $CURRENTPATH" >> $TICKDIR/Deploy-to-QA.sh                                                                        ##  Writes to Deploy-to-QA.sh
                echo "tar -xvf $DOWNLOADDIR/QA-Specific-Deployment-Files/tar/$LSTPRDCHG -C $CURRENTPATH" >> $TICKDIR/Deploy-to-QA.sh		##  Writes to Deploy-to-QA.sh
        done;
} 2>&1 | tee -a $LOGDIR/master.log	
}

################################################
## Verify md5 sums
################################################
md5verify(){ {
	echo ""
	echo "##############################"
	echo "##  Verifying MD5 sums ...  ##"
	echo "##############################"
	echo ""

	cd $LOGDIR
	mkdir FAILED_md5_prod
	mkdir FAILED_md5_QA

#### PROD ####
	for i in $(cat $LOGDIR/download-maven.log | grep http);
	        do
	        wget $i.md5;
	        LOCALFILE=${i##*/};			## removes everything up to the last /
	        LOCALMD5=$(md5sum $DOWNLOADDIR/Deployment-Files/*/$LOCALFILE| cut -d ' ' -f 1);
	        CORRECTMD5=$(cat $LOCALFILE.md5);
	        if [ $LOCALMD5 = $CORRECTMD5 ];
	        then
	                rm $LOCALFILE.md5
	                echo "$LOCALFILE md5 VERIFIED"
	        else
	                echo "$LOCALFILE **FAILED** md5sum check" | tee -a $LOGDIR/md5_FAILED_prod.log
	                mv $LOCALFILE.md5 $LOGDIR/FAILED_md5_prod/
	        fi
	done | tee -a $LOGDIR/md5_prod_check.log


#### QA ####
        for i in $(cat $LOGDIR/download-maven-QA.log | grep http);
                do
                wget $i.md5;
                LOCALFILE=${i##*/};			## removes everything up to the last /
                LOCALMD5=$(md5sum $DOWNLOADDIR/QA-Specific-Deployment-Files/*/$LOCALFILE| cut -d ' ' -f 1);
                CORRECTMD5=$(cat $LOCALFILE.md5);
                if [ $LOCALMD5 = $CORRECTMD5 ];
                then
                        rm $LOCALFILE.md5
                        echo "$LOCALFILE md5 VERIFIED"
                else
                        echo "$LOCALFILE **FAILED** md5sum check" | tee -a $LOGDIR/md5_FAILED_QA.log
                        mv $LOCALFILE.md5 $LOGDIR/FAILED_md5_QA/
                fi
        done | tee -a $LOGDIR/md5_QA_check.log

#### Notify of failures ####

	if  [ -s $LOGDIR/md5_FAILED_prod.log ];		#### If file exists and is non-zero
	then
		echo ""
		echo "#######################################################################################"
		echo "##  FILES FAILED MD5 - PLEASE SEE $LOGDIR/md5_FAILED_prod.log  ##"
		echo "#######################################################################################"
	elif  [ -s $LOGDIR/md5_FAILED_QA.log ];		#### If file exists and is non-zero
	then
		echo ""
		echo "#####################################################################################"
		echo "##  FILES FAILED MD5 - PLEASE SEE $LOGDIR/md5_FAILED_QA.log  ##"
		echo "#####################################################################################"
	else
		echo ""
		echo "#############################"
		echo "##  All MD5 sums verified  ##"
		echo "#############################"
	fi	
} 2>&1 | tee -a $LOGDIR/master.log
}

##################################################
## Backup only files that will be deployed,
## as listed in listprodchanges
##################################################
backupchanges(){ {
	cd $TICKDIR/BAK
	echo ""
	echo "####################################"
	echo "##  Backing up files in prod ...  ##"
	echo "####################################"

		## If .changes file exists, create backup
	[[ -s "$DOWNLOADDIR/Deployment-Files.servers.changes" ]] && { tar -czvf servers.BAK.tar.gz `cat $DOWNLOADDIR/Deployment-Files.servers.changes`; }
        [[ -s "$DOWNLOADDIR/Deployment-Files.batch.changes" ]] && { tar -czvf batch.BAK.tar.gz `cat $DOWNLOADDIR/Deployment-Files.batch.changes`; }
	[[ -s "$DOWNLOADDIR/Deployment-Files.content.changes" ]] && { tar -czvf content.BAK.tar.gz `cat $DOWNLOADDIR/Deployment-Files.content.changes`; }
	[[ -s "$DOWNLOADDIR/Deployment-Files.war.changes" ]] && { tar -czvf war.BAK.tar.gz `cat $DOWNLOADDIR/Deployment-Files.war.changes`; }
	[[ -s "$DOWNLOADDIR/Deployment-Files.tar.changes" ]] && { tar -czvf tar.BAK.tar.gz `cat $DOWNLOADDIR/Deployment-Files.tar.changes`; }

} 2>&1 | tee -a $LOGDIR/backup_prod.log | tee -a $LOGDIR/master.log
}

##################################################
## Backup only files that will be deployed,
## as listed in listqachanges
##################################################
backupQAchanges(){ {
	cd $TICKDIR/BAK
	echo ""
	echo "##################################"
	echo "##  Backing up files in QA ...  ##"
	echo "##################################"

		## If .changes file exists, create backup
	[[ -s "$DOWNLOADDIR/QA-Specific-Deployment-Files.servers.changes" ]] && { tar -czvf servers.QA.BAK.tar.gz `cat $DOWNLOADDIR/QA-Specific-Deployment-Files.servers.changes`; }
        [[ -s "$DOWNLOADDIR/QA-Specific-Deployment-Files.batch.changes" ]] && { tar -czvf batch.QA.BAK.tar.gz `cat $DOWNLOADDIR/QA-Specific-Deployment-Files.batch.changes`; }
	[[ -s "$DOWNLOADDIR/QA-Specific-Deployment-Files.content.changes" ]] && { tar -czvf content.QA.BAK.tar.gz `cat $DOWNLOADDIR/QA-Specific-Deployment-Files.content.changes`; }
	[[ -s "$DOWNLOADDIR/QA-Specific-Deployment-Files.war.changes" ]] && { tar -czvf war.QA.BAK.tar.gz `cat $DOWNLOADDIR/QA-Specific-Deployment-Files.war.changes`; }
	[[ -s "$DOWNLOADDIR/QA-Specific-Deployment-Files.tar.changes" ]] && { tar -czvf tar.QA.BAK.tar.gz `cat $DOWNLOADDIR/QA-Specific-Deployment-Files.tar.changes`; }

} 2>&1 | tee -a $LOGDIR/backup_QA.log | tee -a $LOGDIR/master.log
}

##################################################
## Insert separator/header
##################################################
separator(){ {
	echo "   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _    "
	echo "II/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \II "
	echo "II\_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/II "
	echo "II/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \II "
	echo "II\_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/II "
	echo "                                                                            "
} | tee -a $LOGDIR/master.log
}


#####################################################################
##   ^ ^^^^^^^^^^^^^^^^ ^   #########################################
##   | End of Functions |   #########################################
#####################################################################
#####################################################################

#########################################################################################################
#########################################################################################################
####################################                                 ####################################
####################################     | Main Body of Script |     ####################################
####################################     v vvvvvvvvvvvvvvvvvvv v     ####################################
#########################################################################################################
#########################################################################################################


#################################
##   Logic   ####################
#################################

echo ""
if test "$TICKNUM" = "" ; then
        echo ""
        echo "Usage: $0  <JIRA_Ticket>"
        echo "Example: $0  DP-3222"
        echo ""
        exit
fi

# If the ticket-directory exists, rename it with the date
[[ -d $TICKDIR ]] && moveit $TICKDIR
[[ ! -d $LOGDIR ]] && mkdir -pv $LOGDIR
[[ ! -d $DOWNLOADDIR ]] && mkdir -pv $DOWNLOADDIR
[[ ! -d $TICKDIR/BAK ]] && mkdir -pv $TICKDIR/BAK

echo ""
echo "#####################################################"
echo "##  Saving logs to $LOGDIR/  ##"
echo "#####################################################"

##############################################
##   Choices
##############################################

separator

echo ""
echo "###############################################"
echo "##  Which environment are you working with?  ##"
echo "###############################################"

select env in "prod" "test1" "test2" "test3" "test4" "test5" "test6" "performance"; do
   	case $env in
		prod)		DATA=data;		DLM=prod; BAKUP=prod; break;;
		test1)		DATA=TEST1-data; 	DLM=qa;	BAKUP=qa; break;;
		test2)		DATA=TEST2-data;        DLM=qa; BAKUP=qa; break;;
		test3)		DATA=TEST3-data;        DLM=qa; BAKUP=qa; break;;
		test4)		DATA=TEST4-data;        DLM=qa; BAKUP=qa; break;;
		test5)		DATA=TEST5-data;        DLM=qa; BAKUP=qa; break;;
		test6)		DATA=TEST6-data;        DLM=qa; BAKUP=qa; break;;
		performance)	DATA=PERF-data;		DLM=perf; BAKUP=perf; break;;
	esac
done


echo ""
echo "#############################"
echo "##  Download attachments?  ##"
echo "#############################"

select attch in "Yes" "No"; do
	case $attch in
		Yes)	ATTACH=yes; break;;	# getattachments; break;;
		No)	ATTACH=no; break;;	# break;;
	esac
done


echo ""
echo "############################"
echo "##  Download Maven URLs?  ##"
echo "############################"

select dlmv in "Yes" "No";do
	case $dlmv in
		Yes)	break;;		# DLM variable set by environment choice
		No)	DLM=no; break;;
	esac
done


echo ""
echo "#######################"
echo "##  Create Backups?  ##"
echo "#######################"

select bkup in "Yes" "No"; do
	case $bkup in
		Yes)	break;;		# BAKUP variable set by environment choice
		No)	BAKUP=no; break;;
	esac
done


echo ""
echo "############################################################"
echo "############################################################"
echo "##                                                        ##"
echo "##  That's it! Go get a beer, this could take a few min.  ##"
echo "##                                                        ##"
echo "############################################################"
echo "############################################################"
echo ""
echo ""

##############################################
##   Execute choices
##############################################

extractsteps    			# Copy ticket steps to txt files.

[ $ATTACH = "yes" ] 	&& getattachments

[ $DLM = "prod" ] 	&& { dlmavendeployment; listprodchanges; md5verify; }
[ $DLM = "qa" ] 	&& { dlmavenqa; listqachanges; md5verify; }
[ $DLM = "perf" ] 	&& { dlmavenqa; listqachanges; md5verify; }

[ $BAKUP = "prod" ] 	&& backupchanges
[ $BAKUP = "qa" ] 	&& backupQAchanges
[ $BAKUP = "perf" ] 	&& backupQAchanges


##############################################
##   END
##############################################

#separator
echo "############################################################"
echo "##  Your ticket is saved under $TICKDIR  ##"
echo "############################################################"
#separator
