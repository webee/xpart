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
function init_disk
{
local disk=$1

fdisk $disk >/dev/null 2>&1 <<END &
o
n
e



w
END
}

#function
#disk
function xpart_check
{
    local disk=$1
    #get the partions
    sectors=`parted $disk unit s p|sed -n '2{s/.* \([0-9]\+\)s/\1/;p}'`
    partitions=(`parted $disk unit s p|grep '^ [0-9]\+'|sed 's/\([0-9]\+\)s/\1/g'|sort -k2n|awk '{printf("%s %s %s %s %s ", $1,$2,$3,$4,$5)}'`)
    total=$[${#partitions[@]}/5]

    local expected=(1 $boot_sectors `expr $sectors - 1` `expr $sectors - $boot_sectors` "extended")
    for ((i=0;i<5;i++));do
	if [ x${partitions[$i]} != x${expected[$i]} ];then
	    isXpart=0
	    break
	fi
    done
}


#function
#disk,pnum
function remove_partition
{
local disk=$1
local pnum=$2
local valid=0

#check if request partitions exist.
for ((i=1; i<$total; i++)); do
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
local start=`expr ${partitions[$0*5+1]} + $boot_sectors`
local end=${partitions[$0*5+1]}

local disk=$1
local pstart0=${2:-$start}
local pend0=${3:-$end}
local psize=$4
local force=$5
local verbose=$6

local pstart=${pstart0}
local pend=${pend0}

local max_space=0
local max_start=pstart

#size first.
if [ x$psize != x ];then
    #get sectors
    psize=$(skmgtp $psize s)

    for ((i=1;i<$total;i++));do
	space=`expr $pstart - ${partitions[$[$i*5+1]]} - $boot_sectors`
	if [ $(mcmp $space $psize) -ge 2 ];then
	    pend=`expr $pstart + $psize`
	    break
	else
	    if [ $(mcmp $space $max_space) -eq 3 ];then
		max_space=$space
		max_start=$pstart
	    fi
	    pstart=`expr ${partitions[$[$i*5+2]]} + $boot_sectors`
	fi
    done
    space=`expr $pstart - $end`
#then strart.end.
else
    if [ $ptype = l ];then
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

