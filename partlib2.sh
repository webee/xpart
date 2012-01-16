#!/bin/sh

#disk
function get_detail_info
{
local disk=$1
local unit=$2
parted $disk unit $unit print 2>/dev/null
if [ $? != 0 ]; then
    fdisk $disk -l
fi
}

#disk
function create_partition_table
{
local disk=$1
local type="msdos"

parted $disk mklabel $type >/dev/null 2>&1 <<END
Yes
END

if [ $? != 0 ]; then
fdisk $disk >/dev/null 2>&1 <<END &
o
w
END
fi
}

#disk,ptype,pstart,pend,force
function new_partition
{
local disk=$1
local ptype=$2
local pstart=$3
local pend=$4
local force=$5
local unit=$6

echo m$force
parted $disk <<END
unit $unit
mkpart $ptype $pstart $pend
y
i
END
}

#disk,pnum
function remove_partition
{
local disk=$1
local pnum=$2
local unit=$3

parted $disk unit $unit rm $pnum 2>&1
}
