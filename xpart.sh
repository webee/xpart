#!/bin/bash

#check permission
#must be root
if [ "`whoami`" != "root" ];then
    #error
    echo "you must be root to run this script."
    exit 1
fi

#import the lib.
. ./partlib.sh

#default
version="xpart 0.6.0"
#num start end size type
#type:primary,extended,logical
declare -a partitions
#1MB
mbr_sectors=2048
total=0
sectors=0
direction=l
unit=m
force=0
verbose=0
execute=1

function usage
{
echo 'xparse device [[-d]device] [action..] [options..]'
cat <<EOF

    -d|--device: the device to operate
actions:
    -I|--info, get disk info.
    -e|--empty: create a empty msdos partition table
    -n|--new: create a new partition
    -r|--remove: remove a partition,-r1:remove partition #1
options:
    -D|--direction: l/h, scan direction, default:low.
    -t|--type: partition type,p:primary,e:extend,l:logical
    -S|--start: the start sector
    -E|--end: the end sector
    -s|--size: size in sector
    -F|--format: format the new partition
    -f|--force: force correct the input error.
    -v|--verbose: output operation detail.
    -x|--donot_execute: do not execute,preview result.
others:
    -u|--unit: display unit,s/k/m/g/t/p
    -h|--help: show help list.
    -V|--version: show version.
readme.txt include more details.
EOF
echo $version
}

#parse option and arguments.
ARGS=`getopt -o d:Ienr:D:t:S:E:s:F:fvxu:hV --long device:,info,empty,new:,remove:,direction,type:,start:,end:,size:,format,force,verbose,donot_execute,unit:,help,version -- "$@"`

if [ $? != 0 ]; then echo "Terminating...";exit 1;fi

eval set -- "${ARGS}"

while true
do
    case "$1" in
        -d|--device)
            disk=$2
            shift 2
            ;;
        -I|--info)
            action=Info
            shift
            ;;
        -e|--empty)
            action=empty
            shift
            ;;
        -n|--new)
            action=new
            shift
            ;;
        -r|--remove)
            action=remove
            pnum=$2
            shift 2
            ;;
        -D|--direction)
            direction=$2
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
        -F|--format)
            fs=$2
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
        -x|--donot_execute)
            execute=0
            shift
            ;;
        -u|--unit)
            unit=$2
            shift 2
            ;;
        -h|--help)
            help=y
            shift 2
            break
            ;;
        -V|--version)
            Ver=y
            shift 2
            break
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

#handle help&&version
if [ "$help" == "y" ]; then
    usage
    exit 0;
fi
if [ "$Ver" == "y" ]; then
    echo $version
    exit 0;
fi

#get disk name
if [ -z "$disk" ]; then
    disk=$1
fi

if [ -e "$disk" ]; then
    #get the partions
    sectors=`parted $disk unit s p|sed -n '2{s/.* \([0-9]\+\)s/\1/;p}'`
    partitions=(`parted $disk unit s p|grep '^ [0-9]\+'|sed 's/\([0-9]\+\)s/\1/g'|sort -k2n|awk '{printf("%s %s %s %s %s ", $1,$2,$3,$4,$5)}'`)
    total=$[${#partitions[@]}/5]

	#check
	#unit
	if [ `expr $unit : [skmgtp]` != `expr length $unit` ];then
		#error
		echo "invalid unit: $unit"
		exit 1
	fi
    case "$action" in
        Info)
            get_detail_info $disk $unit
            ;;
        empty)
            create_partition_table $disk
            ;;
        new)
			#check
			#type
			if [ x$type != x ];then
				if [ $type != p ] && [ $type != e ] && [ $type != l ];then
					#error
					echo "invalid partition type: $type"
					exit 1
				fi
			fi
			#start,end,size
			check_size "$start"
			check_size "$end"
			check_size "$size"
			#direction
			if [ $direction != l ] && [ $direction != h ];then
				echo "invalid direction: $direction."
				exit 1
			fi
            new_partition $disk "$type" "${start}" "${end}" "$size" $unit
            ;;
        remove)
			#check
			if [ `expr $pnum : [1-9][0-9]\*` != `expr length $pnum` ];then
				#error
				echo "invalid partition number: $pnum"
				exit 1
			fi
            remove_partition $disk $pnum
            ;;
        *)
            usage
            exit 1
            ;;
    esac
else
    echo "$disk not exist."
fi
