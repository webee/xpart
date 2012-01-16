#!/bin/sh

#function
#disk
function get_detail_info
{
local disk=$1
local unit=$2
parted $disk unit $unit print 2>/dev/null
if [ $? != 0 ]; then
    fdisk $disk -l
fi
#for (( i=0; i<$total; i++));do
#    for (( j=0; j<5; j++));do
#	echo -n -e "${partitions[$[$i*5+$j]]}\t"
#    done
#    echo ""
#done
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

#disk,ptype,pnum,pstart,psize
function new_partition
{
local disk=$1
local ptype=$2
local pstart0=$3
local pend0=$4
local psize=$5
local force=$6
local verbose=$7
local start=0
local end=$[$sectors-1]
local primary_nums=`echo ${partitions[@]}|tr ' ' '\n'|awk 'BEGIN{n=0;}($0=="primary"||$0=="extended"){n++;}END{printf("%d",n);}'`
local extend_nums=`echo ${partitions[@]}|tr ' ' '\n'|awk 'BEGIN{n=0;}($0=="extended"){n++;}END{printf("%d",n);}'`
if [ x$primary_nums = x ];then primary_nums=0;fi
if [ x$extend_nums = x ];then extend_nums=0;fi

pstart0=${pstart0:-$start}
if [ x$pend0 = x ] && [ x$psize != x ];then
    pend0=$[$pstart+$psize]
else
    pend0=${pend0:-$end}
fi
local pstart=${pstart0}
local pend=${pend0}
    
if [ $ptype = l ];then
    if [ $extend_nums -eq 0 ];then
	echo "you must create a extended first."
	#no extended partition.
	exit 1
    fi
    for (( i=0; i<$total; i++)); do
	if [ ${partitions[$[$i*5+4]]} = "extended" ]; then
	    start=${partitions[$[$i*5+1]]}
	    end=${partitions[$[$i*5+2]]}
	    #check global range.
	    if [ $pstart -lt $[$start+$boot_sectors] ]; then
		pstart=$[$start+$boot_sectors]
	    fi
	    if [ $pend -gt $end ]; then
		pend=$end
	    fi
	fi
	if [ ${partitions[$[$i*5+4]]} = "logical" ];then
	    start=$[${partitions[$[$i*5+1]]}-$boot_sectors]
	    end=$[${partitions[$[$i*5+2]]}+$boot_sectors]
	    if [ $pstart -lt $start ];then
		if [ $pend -ge $start ];then
		    pend=$[$start-1]
		fi
		break
	    elif [ $pstart -ge $start ] && [ $pstart -le $end ];then
		pstart=$[$end+1]
		if [ x$psize != x ];then
		    pend=$[$pstart+psize]
		fi
	    fi
	    echo $i,$pstart,$pend
	fi
    done
elif [ $ptype = p ] || [ $ptype = e ];then
    #check extended.
    if [ $ptype = e ] && [ $extend_nums != 0 ];then
	echo "there is already a extended."
	#no more extend.
	exit 3
    fi
    #check 4 primaries.
    if [ $primary_nums -eq 4 ]; then
	echo "4 primaries,no more."
	#no more primary partitions.
	exit 2
    fi
    #check global range.
    if [ $pstart -lt $[$start+$boot_sectors] ]; then
	pstart=$[$start+$boot_sectors]
    fi
    if [ $pend -gt $end ]; then
	pend=$end
    fi
    #check other ranges.
    for (( i=0; i<$total; i++)); do
	if [ ${partitions[$[$i*5+4]]} = "extended" ] || [ ${partitions[$[$i*5+4]]} = "primary" ]; then
	    start=${partitions[$[$i*5+1]]}
	    end=${partitions[$[$i*5+2]]}
	    if [ $pstart -lt $start ];then
		if [ $pend -ge $start ];then
		    pend=$[$start-1]
		fi
		break
	    elif [ $pstart -ge $start ] && [ $pstart -le $end ];then
		pstart=$[$end+1]
		if [ x$psize != x ];then
		    pend=$[$pstart+psize]
		fi
	    fi
	fi
    done
fi
#adjust pstart<=pend<end
if [ $pend -lt $pstart ];then
    pend=$pstart
fi

if [ $pend -ge $[$sectors-1] ];then
    pend=$[$sectors-1]
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
#fdisk $disk <<END &
#fdisk $disk >/dev/null 2>&1 <<END &
#n
#$ptype
#
#$pstart
#$pend
#w
#END

#what have been created.
if [ $verbose -eq 1 ];then
    echo "$pstart0,$pend0=>$pstart,$pend"
    parted $disk unit s p|grep '^Number'
    parted $disk unit s p|grep "${pstart}s"
fi
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
