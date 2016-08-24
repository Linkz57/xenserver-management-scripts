#!/bin/bash
#
# Written by Tyler Francis
# on 2016-08-24
# Website: github.com/linkz57
#
# Version 0.1
#
# The idea is to make sure xenbackup is working.
# No one likes silent failures for their backups
# so this will watch for errors created by xenbackup.sh




# Thanks to Christopher Neylan for the following statement using grep's exit code for if conditional
# https://stackoverflow.com/questions/9422461/check-if-directory-mounted-with-bash

if ssh root@OMITTED "ls -laFh /root/backup*" | grep failed > xenbackup_fail.mail; then
	echo "Failure report found"
	cat xenbackup_fail.mail | mail -s "XenBackup ran and failed now or in the past" tyler.francis@jelec.com
else
	echo "XenBackup has not reported failure. This is either good or really bad"
fi
