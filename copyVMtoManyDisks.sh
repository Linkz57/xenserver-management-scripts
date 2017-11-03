#!/bin/bash
##
## copyVMtoManyDisks.sh
## version 0.4
##
## Faced with failing disks and zero money,
## let's make frequent copies of important VMs
## on the local disk of each Xen hypervisor
##
## $1 is the VM name you want to backup. Incomplete strings and regex allowed. 

## TODO: make sure the VM isn't running when I delete it and its disks



#########
# Setup #
#########

usage()
{
cat <<EOF
Copy specified VM to all local disks.
	Usage: $0 [VMname]
	Call this program and include part of a VM name
	to search for and then backup.
	For example: "$0 landscape"
	will find both Linux Manager 4 -Landscape
	and landscape-auto1 and copy them both to all local disks.
	
	Spaces are not currently supported in arguments.
	Anything after a space will be ignored.
	For example: "$0 landscape" and
	"$0 landscape machine what with the webserver and all"
	will both do the exact same thing.
EOF
}

if [ $# -lt 1 ]; then
	usage
	exit 1
fi

IFS=$'\n'      ## change the default delimiter from spaces to newlines, for building the following array.






################
#    Delete    #
#  old copies  #
#   created    #
#  previously  #
################

clear
echo " ~ ~ ~ ~ ~    I'm about to permanently delete the following VMs    ~ ~ ~ ~ ~"
sleep 5
arrayLocalStorage=($(
  xe sr-list name-label="Local storage" |      ## list all storage repos named Local Storage
  grep -B 1 "Local storage" |                  ## show only the line containing Local Storage and 1 line above which should contain the UUID
  grep "uuid ( RO)" |                          ## Show only the line containing the label uuid
  awk -F': ' '{print $2}'                      ## AWK out the labels and only keep the values of UUID
)) || exit 1                                   ## Store the results in an array, or error out.


for i in ${arrayLocalStorage[@]}; do    ## As many elements as exist in the array, do a thing that many times.
  arrayLocalDisk=($(
    xe vdi-list sr-uuid=$i |               ## List all VHDs saved to local disks
    grep "uuid ( RO)" |                    ## show only the UUID of the VHDs
    awk -F': ' '{print $2}'                ## AWK out the labels and only keep the values of UUID
  )) || exit 1                             ## Store the results in an array, or error out.
  
  ## Aggregate output from many iterations of previous command for later use.
  arrayDisksToDelete+=($(echo "$arrayLocalDisk"))
  
  
  
  ## Now with a list of local disks, find out which VMs they're attached to.
  arrayLocalVM+=($(
    xe vbd-list params=vm-uuid vdi-uuid=$arrayLocalDisk |    ## Show the connections this VHD has, namely which VM uses it.
    grep "vm-uuid" |                                         ## remove everything except the vm-uuid. Should only remove empty lines
    awk -F': ' '{print $2}'                                  ## AWK out the labels and only keep the values of VM-UUID
  )) || exit 1                                               ## Store the results in an array, or error out.
  
  
  ## List VM names and storage repos to inform human of danger
  echo "Name:    $(xe vbd-list params=vm-name-label vdi-uuid=$arrayLocalDisk | grep vm-name-label)"
  echo "Location:"
  xe sr-list uuid=$(xe vdi-list uuid=$arrayLocalDisk params=sr-uuid | grep sr-uuid | awk -F': ' '{print $2}') | grep "name-label\|host"
  printf "\n\n"
    
#  echo "${arrayLocalVM[*]}"
done

sleep 10

## Actually delete found VMs
for i in ${arrayLocalVM[@]}; do    ## For each element in this array, delete a VM matching that UUID
#  xe vm-uninstall force=true vm=$i
done


# TODO actually delete things found






#################
# Create fresh  #
#   VM copies   #
# for Disasters #
#################

## find VMs matching name supplied on command line
arrayVms=($(
  xe vm-list |                ## list all VMs
  grep -i -A 1 -B 1 $1 |      ## show only the line matching your $1 search term, 1 line above, and 1 line below.
  awk -F': ' '{print $2}'     ## AWK out the labels and only keep the values of UUID, name, and power-state. 
)) || exit 1                  ## Store the results in an array or error out.


# TODO actually create copied from search results
