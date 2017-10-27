#!/bin/bash
##
## copyVMtoManyDisks.sh
## version 0.2
##
## Faced with failing disks and zero money,
## let's make frequent copies of important VMs
## on the local disk of each Xen hypervisor
##
## $1 is the VM name you want to backup. Incomplete strings and regex allowed. 


IFS=$'\n'      ## change the default delimiter from spaces to newlines, for building the following array.
arrayVms=($(
  xe vm-list |                ## list all VMs
  grep -i -A 1 -B 1 $1 |      ## show only the line matching your $1 search term, 1 line above, and 1 line below.
  awk -F': ' '{print $2}'     ## AWK out the labels and only keep the values of UUID, name, and power-state. 
)) || exit 1                  ## Store the results in an array or error out.

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
  
  ## Now with a list of local disks, find out which VMs they're attached to.
  
  arrayLocalVM=($(
    xe vbd-list params=vm-uuid vdi-uuid=$arrayLocalDisk |    ## Show the connections this VHD has, namely which VM uses it.
    grep "vm-uuid" |                                         ## remove everything except the vm-uuid. Should only remove empty lines
    awk -F': ' '{print $2}'                                  ## AWK out the labels and only keep the values of VM-UUID
  )) || exit 1                                               ## Store the results in an array, or error out.
  
  echo "${arrayLocalVM[*]}"
done
