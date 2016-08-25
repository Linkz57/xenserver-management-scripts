# I stole version 1.1 of a script from Rahul Kumar at
# http://tecadmin.net/backup-running-virtual-machine-in-xenserver/
# and I made some minor edits to make it work for my setup
# I also added the following lines right after his mounting 
# and right before he declaires the BACKUPPATH variable. 
#
# I mount my backup share at /vmbackup


if mount | grep /vmbackup > /dev/null; then
        echo "mount exists, will continue"
else
        echo "Mount failed. Make sure the FreeNAS box is on and sharing via CIFS. I'm gonna quit now without backing anything up." > backup_failed_$DATE.log
        exit 0
fi


# That bit in the middle ("mount failed. Make sure...." > foo.txt) 
# is the handoff to xenbackup_checkup.sh scheduled to run on another server
#
#
# Version 1.2 of Mr. Rahul Kumar's scipt doesn't seem any different than the version 1.1 that I'm using,
# so you should be able to plug my lines anywhere in between his lines 23 and 35.



# At the very end of Mr. Rahul Kumar's script I have added the line

\rm backup_failed*.log

# which should clean up all failure reports after a single successful backup.
