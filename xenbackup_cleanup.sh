#!/bin/bash
## Written by Tyler Francis for Jelec USA on 2016-11-17
##
## The idea is: the xenbackup.sh script is really good at making backups of XenServer VMs
## it's not so good at deleting the old ones.
## I don't want to just delete the old backups; I want to keep all of the most recent backups,
## and have spottier coverage the further into the past you go. Imagine a Fibonacci sequence of availability after the half-way mark.
## Instead what I wrote is: every-other old backup is deleted, when the backup share is over a certain percentage filled. 
## This should accidentally get some of what I'm looking for, since I expect the "percentage filled" threshold to be passed at irregular intervals.
## That's close enough for now, I guess.
##
## xenbackup_cleanup.sh
## version 0.14


cleanDir=/mnt/vmbackup
## in case you stop liking it in a few years and want to change or disable it.
SCRIPTPATH=~/scripts/xenbackup_cleanup.sh
hostname=`hostname`
## How full is too full? Many say that 80% is the magic number.
fillLine=80
## So let's say that backing up all of your VMs once usually takes between 150 and 200 Gibabytes. 
## If this is true, any backup batch that consumes less than 100 Gibabytes should be suspicious, right?
## I mean, it's possible that this means some VMs failed to backup, or were stopped half way through backing up, or something equally devious.
## Set a threshold here, under which a backup folder COULD be considered suspicious. If this script finds one such folder under this threshold, it will email you and stop.
## My threshold will be one-hundred thirty Gibabytes.
dangerZone=130G
## Where do you want these emails sent? You can put as many addresses as you want between those quotation marks.
myEmail="tyler.francis@jelec.com"

## I'm storing these backups on ZFS and have filesystem-level compression enabled, so we won't REALLY be freeing up as much space as is advertised.
## The amount of compression, according to ZFS, usually floats around:
#compressionAmmount=1.5


## remove the old log, since it was probably already emailed out.
## the leading slash makes sure no goofy aliases of rm are being used.
\rm -f $cleanDir/clean.mail

function clean {
	cd $cleanDir/$1
	
	## Quick check to make sure I'm not about to delete good old folders if bad new folders exist.
	if du -bh --threshold=-$dangerZone $cleanDir/$1 | grep / > /dev/null
		then
			printf "This is potentially terrible. I have found folders containing less than $dangerZone of backups, which you said might mean some backups have failed. I don't want to go deleting old backups if your new backups are bad. I'd recommend you check the following folders in $cleanDir/$1/ to make sure all of your VM backups are there, and that all of them are restorable:\n\n`du -bh --threshold=-$dangerZone $cleanDir/$1 | grep /`\n\nYou said $dangerZone was small enough to merit concern on line 26 of $SCRIPTPATH on $hostname" | mail -s "Your VM backups located in `mount | grep $cleanDir | awk '{ print $1 }'`$1 might be in danger" $myEmail
			exit 0
	fi

	## section header for email
	echo $cleanDir/$1/ >> $cleanDir/clean.mail
	echo "-------------------------------" >> $cleanDir/clean.mail
	echo "Size    Date          Time" >> $cleanDir/clean.mail
	echo "-------------------------------" >> $cleanDir/clean.mail
	## How much space is available now? We'll use this later to find out how much space we've actually freed up.
	previousAvailableSpace=$(( $( df $cleanDir | awk '{ print $4 }' | tail -n 1 ) / 1048576))

	## here is where the actual work happens.
	## ls sorts by age and throws a trailing slash for folders
	## grep removes anything without a slash aka not folders
	## tail is then given a list of folders, and then ignores the top 8 (newest)
	## the output of tail (all except the 8 newest) is then sorted oldest to newest (because my folders are named date +%Y-%m-%d----%H-%M-%S)
	## the alphabetic list of old folders is then culled by every-other item, so only half remain
	## that is finally stored in a text file that will later be used for mailing, 
	## and also because sometimes removing these .xva files will fail, and I'll have to do it a second time.
	ls -tp | grep / | tail -n +9 | sort | awk 'NR % 2 == 1 { print }' > $cleanDir/clean.action
	## Before deleting anything, let's find out how much space we'll save. Humans like to see easily measurable results.
	## Here's the overview of all of the folders we want to delete, and their total size.
	cat $cleanDir/clean.action | xargs du -bhc >> $cleanDir/clean.mail
	echo "" >> $cleanDir/clean.mail

	## Here's the total size that we can estimate will be deleted (after taking compression into account) as measured in Gibabytes.
	## If you don't have some invisible compression happening on your system, then you should comment out this next line, as it's a waste of math for you.
#	echo "$(( $( echo $( cat $cleanDir/clean.action | xargs du -bc | tail -n 1 | awk '{print $1}' )/$compressionAmmount | bc ) / 1073741824 )) Gibabytes have probably been freed up, if we take filesystem-level compression into account" >> $cleanDir/clean.mail

	## now read in the text file you created, and delete them.
#	cat $cleanDir/clean.action | xargs -d '\n' rm -rf --
	sleep 5
	## let's do it again, in case one or two files survived.
#	cat $cleanDir/clean.action | xargs -d '\n' rm -rf --
	sleep 5
	echo "$( echo $( echo $(( $( df $cleanDir | awk '{ print $4 }' | tail -n 1 ) / 1048576 )) - $previousAvailableSpace ) | bc ) Gibabytes have ACTUALLY been cleaned up. It's less than the advertised 'total' size because of ZFS' filesystem-level compression." >> $cleanDir/clean.mail
	echo "" >> $cleanDir/clean.mail
	## What good have we done today?
	printf "$cleanDir used to be $usedSpace percent full,\nbut after cleaning, it's $(df -h $cleanDir | awk '{ print $5 " " $1 }' | cut -d'%' -f1 | tail -n 1) percent full." >> $cleanDir/clean.mail
	## make some room at the end of a section, to make the text file more human-friendly
	echo "" >> $cleanDir/clean.mail
	echo "" >> $cleanDir/clean.mail
	echo "" >> $cleanDir/clean.mail
}

## Right now I only have one folder to run this on, but I can easily see me in the future regularly backing up several pools, so let's write this to grow easily.
## Also, I totally copied my previous cleanup script, disk2vhd_cleanup.sh which needed to be designed to clean multiple repos.

## Thanks to Vivek Gite on
## https://www.cyberciti.biz/tips/shell-script-to-watch-the-disk-space.html
## for the following line:
usedSpace=$(df -h $cleanDir | awk '{ print $5 " " $1 }' | cut -d'%' -f1 | tail -n 1)

## now that the function has been defined, run it using these arguments as folder names to clean.
## but only do so if the backup repo is getting full
if [ $usedSpace -ge $fillLine ]; then
	clean xenserver01
	printf "If this email is wrong or wasting your attention, feel free to make edits at $SCRIPTPATH on $hostname\n$( if crontab -l | grep $SCRIPTPATH > /dev/null; then echo "If you want to change or disable my schedule, log into $hostname as the user `whoami` and run crontab -e\nYou'll find me on line `crontab -l | grep -n $SCRIPTPATH | cut -d":" -f1`" ; fi)" >> $cleanDir/clean.mail

	## now use that text file I was creating during each running of the function as the body of an email.
	cat $cleanDir/clean.mail | mail -s "The VM backup repo is getting full, and I want to delete the Production Party backups from these dates. I haven't, but I want to." $myEmail
fi

exit 0

## on Debian, I set up the mailer with
##   apt install exim4-daemon-light mailutils && dpkg-reconfigure exim4-config
## now I can pipe things to "mail" and it works great.
