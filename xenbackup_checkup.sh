#!/bin/bash
#
# Written by Tyler Francis
# on 2016-08-24
# Website: github.com/linkz57
#
# Version 1.1
#
# The idea is to make sure xenbackup is working.
# No one likes silent failures for their backups
# so this will watch for errors.

SCRIPTPATH=`pwd -P`/xenbackup_checkup.sh
hostname=`hostname`
alertEmail="me@jelec.com"
## How long since a successful backup should you be concerned? My backups happen on weekdays, 
## so 3 days since a success sounds like a reasonable cause for alarm.
## This is measured in seconds.
tooLong=259200

rm -f xenbackup_fail.mail


## Check for errors left by xenbackup.sh

## Thanks to Christopher Neylan for the following statement using grep's exit code for if conditional
## https://stackoverflow.com/questions/9422461/check-if-directory-mounted-with-bash

if ssh root@OMITTED "ls -laFh /root/backup*" | grep failed >> xenbackup_fail.mail; then
	echo "Failure report found"
	cat xenbackup_fail.mail | mail -s "XenBackup ran and failed now or in the past.     If I'm wrong or wasting your attention, feel free to edit me at $SCRIPTPATH on $hostname" $alertEmail
else
	echo "XenBackup has not reported failure. This is either good or really bad"
fi




## Check for errors left by XenServer
if ssh root@OMITTED "cat /var/log/SMlog" | grep -i chain >> xenbackup_fail.mail; then
	cat xenbackup_fail.mail | mail -s "Your snapshots are failing, probably your backups too!     If I'm wrong or wasting your attention, feel free to edit me at $SCRIPTPATH on $hostname" $alertEmail
fi




## Check for success of xenbackup.sh
ssh root@OMITTED "cat success.log" > success.log
read first < success.log
now=`\date +%s`
if [[ $(($now - $first)) > $tooLong ]] ; then
	## if this is true, then it's been too long since you've had a successful backup.
	printf "It's been more than `echo "$tooLong / 86400" | bc` days since your XenServer VMs have successfully been backed up.\nYou should probably look into this.\n\nIf I'm wrong or wasting your attention, feel free to edit me at $SCRIPTPATH on $hostname" | mail -s "Your XenServer backups haven't run in a while" $alertEmail
fi



## on Debian, I set up the mailer with
##   apt install exim4-daemon-light mailutils && dpkg-reconfigure exim4-config
## now I can pipe things to "mail" and it works great.

## to get ssh working automatically (not requiring a password)
## use ssh-keygen and ssh-copy-id
## I followed a guide here: http://www.thegeekstuff.com/2008/11/3-steps-to-perform-ssh-login-without-password-using-ssh-keygen-ssh-copy-id
