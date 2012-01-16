#!/bin/bash

#import math functions
. math.sh

#function
#disk,unit
function get_detail_info
{
    local disk=$1
    local unit=$2
    parted $disk unit $unit print 2>/dev/null
    if [ $? != 0 ]; then
	fdisk $disk -l
    fi
}

#function
#disk
function create_partition_table
{
local disk=$1

fdisk $disk >/dev/null 2>&1 <<END &
o
w
END
}

#function
#disk,pnum
function remove_partition
{
local disk=$1
local pnum=$2
local valid=0

#check if request partitions exist.
for (( i=0; i<$total; i++)); do
    if [ ${partitions[$[$i*5+0]]} -eq $pnum ]; then
	valid=1
	break
    fi
done

if [ $valid -eq 0 ]; then
    echo "no partion #$pnum"
    exit 1
fi

fdisk $disk >/dev/null 2>&1 <<END &
d
$pnum
w
END
}

#disk,ptype,pnum,pstart,psize
function new_partition
{
local start=0
local end=`expr $sectors - 1`

local disk=$1
local ptype=$2
local pstart0=${3:-$start}
local pend0=${4:-$end}
local psize=$5
local force=$6
local verbose=$7
local primary_nums=`echo ${partitions[@]}|tr ' ' '\n'|awk 'BEGIN{n=0;}($0=="primary"||$0=="extended"){n++;}END{printf("%d",n);}'`
local extend_nums=`echo ${partitions[@]}|tr ' ' '\n'|awk 'BEGIN{n=0;}($0=="extended"){n++;}END{printf("%d",n);}'`
primary_nums=${primary_nums:-0}
extend_nums=${extend_nums:-0}

#size first.
if [ x$psize != x ];then
    #get sectors
    psize=$(skmgtp $psize s)
    if [ $ptype = l ];then
	echo
    elif [ $ptype = p ] || [ $ptype = e ];then
	echo
    fi
#then strart.end.
else
    local pstart=${pstart0}
    local pend=${pend0}
	
    #don't specify the type
    if [ x$ptype = x ];then
    #new logical partition.
    elif [ $ptype = l ];then
	if [ $extend_nums -eq 0 ];then
	    echo "you must create a extended first."
	    #no extended partition.
	    exit 1
	fi
	for ((i=0; i<$total; i++)); do
	    if [ ${partitions[$[$i*5+4]]} = "extended" ]; then
		start=${partitions[$[$i*5+1]]}
		end=${partitions[$[$i*5+2]]}
		#check global range.
		if [ $(mcmp $pstart $(expr $start + $boot_sectors)) -eq 1 ]; then
		    pstart=`expr $start + $boot_sectors`
		fi
		if [ $(mcmp $pend $end) -eq 3 ]; then
		    pend=$end
		fi
	    fi

	    if [ ${partitions[$[$i*5+4]]} = "logical" ];then
		start=`expr ${partitions[$[$i*5+1]]} - $boot_sectors`
		end=`expr ${partitions[$[$i*5+2]]} + $boot_sectors`
		if [ $(mcmp $pstart $start) -eq 1 ];then
		    if [ $pend -ge $start ];then
			pend=`expr $start - 1`
		    fi
		    break
		elif [ $pstart -ge $start ] && [ $pstart -le $end ];then
		    pstart=`expr $end + 1`
		fi
	    fi
	done
    #new primary or extended  partition.
    elif [ $ptype = p ] || [ $ptype = e ];then
	#check extended.
	if [ $ptype = e ] && [ $extend_nums != 0 ];then
	    echo "there is already an extended."
	    #no more extend.
	    exit 2
	fi
	#check 4 primaries.
	if [ $primary_nums -eq 4 ]; then
	    echo "4 primaries,no more."
	    #no more primary partitions.
	    exit 3
	fi
	#check global range.
	if [ $(mcmp $pstart $(expr $start + $boot_sectors)) -eq 1 ]; then
	    pstart=`expr $start + $boot_sectors`
	fi
	if [ $(mcmp $pend $end) -eq 3 ]; then
	    pend=$end
	fi
	#check other ranges.
	for ((i=0; i<$total; i++)); do
	    if [ ${partitions[$[$i*5+4]]} = "extended" ] || [ ${partitions[$[$i*5+4]]} = "primary" ]; then
		start=${partitions[$[$i*5+1]]}
		end=${partitions[$[$i*5+2]]}
		if [ $(mcmp $pstart $start) -eq 1 ];then
		    if [ $pend -ge $start ];then
			pend=`expr $start - 1`
		    fi
		    break
		elif [ $pstart -ge $start ] && [ $pstart -le $end ];then
		    pstart=`expr $end + 1`
		fi
	    fi
	done
    fi
#start.end.
fi

#adjust pstart<=pend<end
if [ $pend -lt $pstart ];then
    pend=$pstart
fi

if [ $pend -ge `expr $sectors - 1` ];then
    pend=`expr $sectors - 1`
fi

if ! [ $pstart -eq $pstart0 ] || ! [ $pend -eq $pend0 ];then
    if ! [ $force -eq 1 ];then
	echo "${pstart0},${pend0}=>$pstart,$pend"
	echo "range error!"
	echo "use ./xpart disk -I -us to get more detail."
	#range error.
	exit 4
    fi
fi

parted $disk mkpart $ptype ${pstart}s ${pend}s >/dev/null 2>&1

#what have been created.
if [ $verbose -eq 1 ];then
    echo "$pstart0,$pend0=>$pstart,$pend"
    parted $disk unit s p|grep '^Number'
    parted $disk unit s p|grep "${pstart}s"
fi
}

