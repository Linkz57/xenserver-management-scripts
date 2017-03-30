#!/bin/bash
#
# Written by Tyler Francis
# on 2016-08-24
# Website: github.com/linkz57
#
# Version 1.2.6
#
# The idea is to make sure xenbackup is working.
# No one likes silent failures for their backups
# so this will watch for errors.

## Thanks to Paul Schulz for the following cd command
## https://stackoverflow.com/questions/3349105/how-to-set-current-working-directory-to-the-directory-of-the-script
cd "${0%/*}"
SCRIPTPATH=`pwd -P`/xenbackup_checkup.sh
hostname=`hostname`
alertEmail="tyler.francis at jelec.com"
now=`\date +%s`

## Since the pool master has to be involved in every backup, you'd might as well also make it run the backup script.
## What is the address (name or IP or whatever) to this pool master?
xenmaster=127.0.0.1

## How long since a successful backup should you be concerned? My backups happen on weekdays,
## so 3 days since a success sounds like a reasonable cause for alarm.
## This is measured in seconds.
tooLongSinceBackup=259200

## It seems that XenServer will run its logroll at random times in the night.
## I've seen log archives begin at midnight, others at 9am.
## Since I can't depend on the availability of information in /var/log/SMlog at a specific time,
## I'll have to run this script all throughout the night, and schedule emails for 8am. Mail scheduling is easy enough with "at"
## but I don't want to queue up 30 emails all warning about the same error pulled from the same log.
## So instead, I'll create lock files and check them to see if enough time has passed to consider this mail queue request "a new error worth mailing about".
## 12 hours is enough time for me, but you can change it here if you disagree.
tooLongSinceLastRun=43200

## for each occurrence of     echo"`\date +%s`"     look for pre-existing lock files that echo is being saved into
## if any are missing, create one with the value of 0 for math later. This line should only be useful once ever.
## Thanks to "Phil H" for the while loop at https://stackoverflow.com/questions/13402119/how-to-grep-and-execute-a-command-for-every-match
grep 'echo "`\\date +%s`"' $SCRIPTPATH | awk '{ print $5 }' | while read lockFiles ; do if test -e "$lockFiles" ; then true ; else echo 0 > $lockFiles ; fi ; done

rm -f xenbackup_fail.mail



## Alright. Now that the stage is set,
## let us actually check on XenServer.




## Check for errors left by xenbackup.sh

## Thanks to Christopher Neylan for the following statement using grep's exit code for if conditional
## https://stackoverflow.com/questions/9422461/check-if-directory-mounted-with-bash

if ssh root@$xenmaster -o ConnectTimeout=10 -o BatchMode=yes "ls -laFh /root/backup*" 2>/dev/null | grep failed >> xenbackup_fail.mail; then
	read lastEmail < xenBackup_errors.lock
	if [ $(($now - $lastEmail)) -gt $tooLongSinceLastRun ] ; then
		## If this is true, then it's been long enough since the last error was found to schedule another email.
#		echo "Failure report found"
		echo "cat `pwd -P`/xenbackup_fail.mail | mail -s \"XenBackup ran and failed now or in the past.     If I'm wrong or wasting your attention, feel free to edit me at $SCRIPTPATH on $hostname\" $alertEmail" | at 08:00
		echo "`\date +%s`" > xenBackup_errors.lock
	fi
fi




## Check for errors left by XenServer
if ssh root@$xenmaster -o ConnectTimeout=10 -o BatchMode=yes "cat /var/log/SMlog" | grep -i chain >> xenbackup_fail.mail; then
	## If this is true, then I found the word "chain" in the current XenServer log file,
	## which means one of your snapshots probably failed,
	## probably because your XenServer isn't coalescing its VDIs properly.
	## Once you find out which VM failed to backup, try running "xe vdi-list | grep -i -B 5 -A 5 MahBustedVM" on your Pool Master
	## and then pasting those top UUIDs into the end of
	## "xe host-call-plugin host-uuid= plugin=coalesce-leaf fn=leaf-coalesce args:vm_uuid=MahBustedVM_VDI_UUIDs"
	## while keeping your eye on "tail -f /var/log/SMlog" in another window/SSH session.
	## Finally, that log should tell you where to start looking to heal your snapshot chain.
	## Maybe tell it to forget about whatever snapshot its crowing about.
	read lastEmail < xenServer_errors.lock
	if [ $(($now - $lastEmail)) -gt $tooLongSinceLastRun ] ; then
		## If this is true, then it's been long enough since the last error was found to schedule another email.
		echo "cat `pwd -P`/xenbackup_fail.mail | mail -s \"Your snapshots are failing, probably your backups too!     If I'm wrong or wasting your attention, feel free to edit me at $SCRIPTPATH on $hostname\" $alertEmail" | at 08:00
		echo "`\date +%s`" > xenServer_errors.lock
	fi
fi




## Check for success of xenbackup.sh
ssh root@$xenmaster -o ConnectTimeout=10 -o BatchMode=yes "cat success.log" > success.log
if [[ $(find success.log -type f -size +5c 2>/dev/null) ]]; then
	read first < success.log
	if [ $(($now - $first)) -gt $tooLongSinceBackup ] ; then
		## If this is true, then it's been too long since you've had a successful backup.
		read lastEmail < xenBackup_success.lock
		if [ $(($now - $lastEmail)) -gt $tooLongSinceLastRun ] ; then
			## If this is true, then it's been long enough since the last error was found to schedule another email.
			echo $(printf "It's been more than $(echo "$tooLongSinceLastRun / 86400" | bc) days since your XenServer VMs have successfully been backed up.\nYou should probably look into this.\n\nIf I'm wrong or wasting your attention, feel free to edit me at $SCRIPTPATH on $hostname" | mail -s "Your XenServer backups haven't run in a while" $alertEmail) | at 08:00
			echo "`\date +%s`" > xenBackup_success.lock
		fi
	fi
else
	read lastEmail < xenBackup_success.lock
        if [ $(($now - $lastEmail)) -gt $tooLongSinceLastRun ] ; then
		printf "I can't find any proof that any backup has ever occured. Did you change your XenServer backup manager? It used to be the machine at $xenmaster " | mail -s "Your XenServer backups have never run?" $alertEmail | at 08:00
		#Your backup manager used to be at `grep "cat success.log" $SCRIPTPATH | cut -d'@' -f2 | cut -d' ' -f1`
		echo "`\date +%s`" > xenBackup_success.lock
	fi
fi



## on Debian, I set up the mailer with
##   apt install exim4-daemon-light mailutils && dpkg-reconfigure exim4-config
## now I can pipe things to "mail" and it works great.

## to get ssh working automatically (not requiring a password)
## use ssh-keygen and ssh-copy-id
## I followed a guide here: http://www.thegeekstuff.com/2008/11/3-steps-to-perform-ssh-login-without-password-using-ssh-keygen-ssh-copy-id
