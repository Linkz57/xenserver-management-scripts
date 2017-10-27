#!/bin/bash
##
## copyVMtoManyDisks.sh
## version 0.1
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
))                           ## Store the results in an array.

arrayLocalStorage=($(
 xe sr-list name-label="Local storage" |          ## list all storage repos named Local Storage
 grep -B 1 "Local storage" |                      ## show only the line containing Local Storage and 1 line above which should contain the UUID
 grep "uuid ( RO)" |                              ## Show only the line containing the label uuid
 awk -F': ' '{print $2}'                          ## AWK out the labels and only keep the values of UUID
))                                                ## Store the results in an array.


for i in ${#arrayLocalStorage[@]}; do       ## As many elements as exist in the array, do a thing that many times.
	
