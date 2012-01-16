#!/bin/bash

#import math functions
. math.sh

#function
#disk
function get_detail_info
{
    local disk=$1
    local unit=$2
    parted $disk unit $unit print
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

#check 4 primaries.
#primary,extended,type
function primarycheck4
{
    local primary_nums=$1
    local extended_nums=$2
    local ptype=$3
    #check extended.
    if [ $ptype = e ] && [ $extended_nums != 0 ];then
	#error
	echo "there is already a extended."
	exit 2
    fi
    #check 4 primaries.
    if [ $primary_nums -eq 4 ]; then
	#error
	echo "4 primaries,no more."
	exit 3
    fi
}

#disk,ptype,pnum,pstart,psize
function new_partition
{
local start=0
local end=`expr $sectors - 1`
local estart=-1
local eend=-1
local istart=0
local iend=0

local disk=$1
local ptype0=$2
local pstart0=${3:-$start}
local pend0=${4:-$end}
local psize0=$5

local primary_nums=`echo ${partitions[@]}|tr ' ' '\n'|awk 'BEGIN{n=0;}($0=="primary"||$0=="extended"){n++;}END{printf("%d",n);}'`
local extended_nums=`echo ${partitions[@]}|tr ' ' '\n'|awk 'BEGIN{n=0;}($0=="extended"){n++;}END{printf("%d",n);}'`
primary_nums=${primary_nums:-0}
extended_nums=${extended_nums:-0}

local pspace=()
local lspace=()
#get spaces between primaries and extended
pspace[0]=`expr $start + $mbr_sectors`
for ((i=0;i<$total;i++));do
    if [ ${partitions[$[$i*5+4]]} = "primary" ] || [ ${partitions[$[$i*5+4]]} = "extended" ]; then
	pspace[${#pspace[@]}]=${partitions[$[$i*5+1]]}
	pspace[${#pspace[@]}]=`expr ${partitions[$[$i*5+2]]} + 1`
    fi
done
pspace[${#pspace[@]}]=`expr $end + 1`
#get spaces between logicals
for ((i=0;i<$total;i++));do
    if [ ${partitions[$[$i*5+4]]} = "extended" ]; then
	estart=${partitions[$[$i*5+1]]}
	eend=${partitions[$[$i*5+2]]}
    fi
done

lspace[0]=$estart
for ((i=0;i<$total;i++));do
    if [ ${partitions[$[$i*5+4]]} = "logical" ]; then
	lspace[${#lspace[@]}]=${partitions[$[$i*5+1]]}
	lspace[${#lspace[@]}]=`expr ${partitions[$[$i*5+2]]} + 1`
    fi
done
lspace[${#lspace[@]}]=`expr $eend + 1`

local ptype=${ptype0}
local pstart=${pstart0}
local pend=${pend0}
local psize=${psize0}
	
#size first.
#if specify size, whatever start.end.,meet size.
if [ x${psize0} != x ];then
    #get sectors
    psize0=$(skmgtp $psize0 s)
    psize=$psize0

    maxspace=0
    maxstart=0
    pmaxspace=0
    pmaxstart=0
    lmaxspace=0
    lmaxstart=0
    #get max space between primaries.
    for ((i=0;i<$[${#pspace[@]}/2];i++));do
	space=`expr ${pspace[$[$i*2+1]]} - ${pspace[$[$i*2+0]]}`
	if [ $space -gt $pmaxspace ];then
	    pmaxspace=$space
	    pmaxstart=${pspace[$[$i*2+0]]}
	fi
    done
    #get max space between logicals.
    for ((i=0;i<$[${#lspace[@]}/2];i++));do
	space=`expr ${lspace[$[$i*2+1]]} - ${lspace[$[$i*2+0]]} - $mbr_sectors`
	if [ $space -gt $lmaxspace ];then
	    lmaxspace=$space
	    lmaxstart=`expr ${lspace[$[$i*2+0]]} + $mbr_sectors`
	fi
    done

    #any type.
    if [ $ptype = a ];then
	if [ $extended_nums -lt 1 ] && [ $primary_nums -ge 4 ];then
	    #error
	    echo "no more primaries, and no extended to create a logial"
	    exit 1
	else
	    if [ $pmaxspace -gt $lmaxspace ] && [ $primary_nums -lt 4 ];then
		ptype=p
	    elif [ $pmaxspace -gt $lmaxspace ] && [ $primary_nums -ge 4 ];then
		ptype=l
	    elif [ $pmaxspace -le $lmaxspace ];then
		if [ $extended_nums -ge 1 ];then
		    ptype=l;
		else
		    ptype=p;
		fi
	    fi
	fi
##	if [ $pmaxspace -gt $lmaxspace ] && [ $primary_nums -lt 4 ];then
##	    ptype=p
##	elif [ $pmaxspace -gt $lmaxspace ] && [ $primary_nums -ge 4 ];then
##	    if [ $extended_nums -ge 1 ];then
##		ptype=l
##	    else
##		#error
##		echo "no more primaries, and no extended to create a logial"
##		exit 1
##	    fi
##	elif [ $pmaxspace -le $lmaxspace ];then
##	    if [ $extended_nums -ge 1 ];then
##		ptype=l
##	    else
##		if [ $primary_nums -lt 4 ];then
##		    ptype=p
##		else
##		    #error
##		    echo "no more primaries, and no extended to create a logial"
##		    exit 1
##		fi
##	    fi
##	fi
    fi
    #add a new logical partition.
    if [ $ptype = l ];then
	#check.
	if [ $extended_nums -eq 0 ];then
	    #error
	    echo "you must create a extended first."
	    exit 1
	fi
	maxspace=$lmaxspace
	maxstart=$lmaxstart
    #add a new primary or extended partition.
    elif [ $ptype = p ] || [ $ptype = e ];then
	#check numbs.
	primarycheck4 $primary_nums $extended_nums $ptype
	maxspace=$pmaxspace
	maxstart=$pmaxstart
    fi

    if [ $maxspace -gt 0 ];then
	pstart=$maxstart
	if [ $maxspace -lt $psize ];then
	    psize=$maxspace
	fi
	pend=`expr $pstart + $psize - 1`
    else
	#error
	echo "not enough space."
	exit 1
    fi
#then strart.end.
else
    #not specify type.
    if [ $ptype = a ];then
	if [ $extended_nums -lt 1 ];then
	    ptype=e
	else
	    ptype=l
	fi
    fi

    #new logical partition.
    if [ $ptype = l ];then
	if [ $extended_nums -eq 0 ];then
	    #error
	    echo "you must create a extended first."
	    exit 1
	fi
	istart=$estart
	iend=$eend
	#check global range.
	if [ $pstart -lt $(expr $istart + $mbr_sectors) ]; then
	    pstart=`expr $istart + $mbr_sectors`
	fi
	if [ $pend -gt $iend ]; then
	    pend=$iend
	fi
	#check other ranges.
	for ((i=0; i<$total; i++)); do
	    if [ ${partitions[$[$i*5+4]]} = "logical" ];then
		istart=`expr ${partitions[$[$i*5+1]]} - $mbr_sectors`
		iend=`expr ${partitions[$[$i*5+2]]} + $mbr_sectors`
		if [ $pstart -lt $istart ];then
		    if [ $pend -ge $istart ];then
			pend=`expr $istart - 1`
		    fi
		    break
		elif [ $pstart -ge $istart ] && [ $pstart -le $iend ];then
		    pstart=`expr $iend + 1`
		    pend=$eend
		fi
	    fi
	done
    fi
    #如果没指定type，且分配logical分区不行，则尝试分配主分区
    if [ $ptype0 = a ] && [ $pstart -gt $pend ];then
	if [ $primary_nums -lt 4 ];then
	    ptype=p
	fi
    fi
    #new primary or extended  partition.
    if [ $ptype = p ] || [ $ptype = e ];then
	#check primary 4 limit.
	primarycheck4 $primary_nums $extended_nums $ptype
	istart=$start
	iend=$end
	#check global range.
	if [ $pstart -lt $(expr $istart + $mbr_sectors) ]; then
	    pstart=`expr $istart + $mbr_sectors`
	fi
	if [ $pend -gt $iend ]; then
	    pend=$iend
	fi
	#check other ranges.
	for ((i=0; i<$total; i++)); do
	    if [ ${partitions[$[$i*5+4]]} = "extended" ] || [ ${partitions[$[$i*5+4]]} = "primary" ]; then
		istart=${partitions[$[$i*5+1]]}
		iend=${partitions[$[$i*5+2]]}
		if [ $pstart -lt $istart ];then
		    if [ $pend -ge $istart ];then
			pend=`expr $istart - 1`
		    fi
		    break
		elif [ $pstart -ge $istart ] && [ $pstart -le $iend ];then
		    pstart=`expr $iend + 1`
		    pend=$end
		fi
	    fi
	done
    fi
#start.end.
fi

##检查结果
if [ $pstart -gt $pend ];then
    #error
    echo "no more space."
    exit 1
fi

if [ x$psize != x$psize0 ] || [ $pstart != $pstart0 ] || [ $pend != $pend0 ];then
    if [ $force -ne 1 ];then
	#error
	echo "(${pstart0},${pend0},${psize},${ptype0})=>($pstart,$pend,$psize,$ptype)"
	echo "range error!"
	echo "use ./xpart disk -I -us to get more detail."
	exit 1
    fi
fi

if [ $execute = 1 ];then
    parted $disk mkpart $ptype ${pstart}s ${pend}s >/dev/null 2>&1
else
    echo "start: ${pstart}s, end: ${pend}s, size: `expr ${pend} - ${pstart} + 1`s, type: ${ptype}"
fi

#what have been created.
if [ $verbose -eq 1 ];then
    echo "$pstart0,$pend0=>$pstart,$pend"
    parted $disk unit s p|grep '^Number'
    parted $disk unit s p|grep "${pstart}s"
fi
}

