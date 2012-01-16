#!/bin/sh
disk=$1
. ./partlib.sh

#default
#num start end size type
#type:primary,extended,logical
declare -a partitions
#1MB
boot_sectors=2048
total=0
sectors=0
type=p
unit=MiB
force=0
verbose=0

function usage
{
echo 'xparse device [-d device] [action..] [options..]'
cat <<EOF

    -d|--device: the device to operate
actions:
    -I|--info, get disk info.
    -o|--create_ptable: create a new msdos partition table, -t
    -n|--new: create a new partition
    -r|--remove: remove a partition,-r1:remove partition #1
options:
    -t|--type: partition type,p:primary,e:extend,l:logical
    -S|--start, the start sector
    -E|--end, the end sector
    -s|--size: size in sector
    -f|--force,force correct the input error.
    -v|--verbose,output operation detail.
others:
    -u|--unit, display unit,eg.MiB,GiB,MB,GB, TiB,TB, s->sector
EOF
}

#parse option and arguments.
ARGS=`getopt -o d:Ionr:t:S:E:s:u:fvh --long device:,info,create_ptable,new:,remove:,type:,start:,end:,size:,unit:,force,verbose,help -- "$@"`

if [ $? != 0 ]; then echo "Terminating...";exit 1;fi

eval set -- "${ARGS}"

while true
do
    case "$1" in
	-h|help)
	    help=y
	    shift 2
	    break
	    ;;
	-d|--device)
	    disk=$2
	    shift 2
	    ;;
	-I|--info)
	    action=I
	    shift
	    ;;
	-o|--create_ptable)
	    action=o
	    shift
	    ;;
	-n|--new)
	    action=n
	    shift
	    ;;
	-r|--remove)
	    action=r
	    pnum=$2
	    shift 2
	    ;;
	-t|--type)
	    type=$2
	    shift 2
	    ;;
	-S|--start)
	    start=$2
	    shift 2
	    ;;
	-E|--end)
	    end=$2
	    shift 2
	    ;;
	-s|--size)
	    size=$2
	    shift 2
	    ;;
	-u|--unit)
	    unit=$2
	    shift 2
	    ;;
	-f|--force)
	    force=1
	    shift
	    ;;
	-v|--verbose)
	    verbose=1
	    shift
	    ;;
	--)
	    shift
	    break
	    ;;
	*)
	    echo "Internal error!"
	    exit 1;;
    esac
done

#handle help
if [ "$help" == "y" ]; then
    usage
    exit 0;
fi

#get disk name
if [ -z "$disk" ]; then
    disk=$1
fi

if [ -n "$disk" ]; then
    #get the partions
    sectors=`parted $disk unit s p|sed -n '2{s/.* \([0-9]\+\)s/\1/;p}'`
    partitions=(`parted $disk unit s p|grep '^ [0-9]\+'|sed 's/\([0-9]\+\)s/\1/g'|sort -k2n|awk '{printf("%s %s %s %s %s ", $1,$2,$3,$4,$5)}'`)
    total=$[${#partitions[@]}/5]
    #for (( i=0; i<$total; i++));do
#	for (( j=0; j<5; j++));do
#	    echo -n "${partions[$[$i*5+$j]]} "
#	done
#	echo ""
#    done
    #handel actions
    case "$action" in
	I)
	    get_detail_info $disk $unit
	    ;;
	o)
	    create_partition_table $disk
	    ;;
	n)
	    new_partition $disk $type "${start}" "${end}" "$size" $force $verbose
	    ;;
	r)
	    remove_partition $disk $pnum
	    ;;
	*)
	    usage
	    exit 1
	    ;;
    esac
else
    usage
fi