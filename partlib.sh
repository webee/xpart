#!/bin/bash

#import math functions lib
. math.sh

#function
#position+unit
function check_size
{
	local size=$1
	if [ x$size != x ];then
		if [ `expr $size : "[0-9]\+[skmgtp]"` != `expr length $size` ];then
			#error
			echo "invalid size: $size"
			exit 1
		fi
	fi
}

#function
#disk
function get_detail_info
{
    local disk=$1
    local unit=$2
    if [ $unit != s ];then
        unit=${unit}ib
    fi
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
local x
local f=$force

if [ $f != 1 ];then
    echo -n "are you sure?(y/n)"
    read x
    if [ $x != y ];then
        exit 0
    fi
fi
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
    exit 1
    fi
    #check 4 primaries.
    if [ $primary_nums -eq 4 ]; then
    #error
    echo "4 primaries,no more."
    exit 1
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
local pstart0=$3
local pend0=$4
local psize0=$5
local unit=$6

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

#单位统一到sector
pstart0=$(skmgtp "$pstart0" s)
pend0=$(skmgtp "$pend0" s)
psize0=$(skmgtp "$psize0" s)


#初始化
local ptype=${ptype0:-a}
local pstart=${pstart0}
local pend=${pend0}
local psize=${psize0}

#指定参数情况
local xyz=000

#没有指定start.end
#如果没有指定size，则当size=0处理
if [ x${pstart0} = x ] && [ x${pend0} = x ];then
    #这种情况会寻找第一个区间
    psize=${psize0:-0}
    xyz=00
fi

#指定了开始.结束
if [ x${pstart0} != x ] && [ x${pend0} != x ];then
    if [ x${psize0} != x ];then
        psize=${psize}
        xyz=111
    else
        pstart=${pstart0}
        pend=${pend0}
        xyz=110
    fi
fi
    
#只指定了开始
if [ x${pstart0} != x ] && [ x${pend0} = x ];then
    pstart=${pstart0}
    if [ x${psize0} != x ];then
        pend=`expr ${pstart0} + ${psize0} - 1 `
        xyz=101
    else
        pend=$end
        xyz=100
    fi
fi

#只指定结束，大小
if [ x${pstart0} = x ] && [ x${pend0} != x ];then
    pend=${pend0}
    if [ x${psize0} != x ];then
        pstart=`expr ${pend0} - ${psize0} + 1 `
        xyz=011
    else
        pstart=$start
        xyz=010
    fi
fi

#strart.end.
if [ $xyz != 00 ] && [ $xyz != 111 ];then
    #not specify type.
    if [ $ptype = a ];then
        if [ $primary_nums -lt 4 ];then
            ptype=p
        elif [ $extended_nums -ge 1 ];then
            ptype=l
        else
            #error
            echo "no more primaries, and no extended to create a logial"
            exit 1
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
        #把start.end规范到相应大区间
        if [ $pstart -lt $(expr $istart + $mbr_sectors) ]; then
            pstart=`expr $istart + $mbr_sectors`
        fi
        if [ $pend -gt $iend ]; then
            pend=$iend
        fi
        #check other ranges.
        #在大区间中寻找最匹配最接近的小区间
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
                    if [ $pstart -gt $pend ];then
                        pend=$eend
                    fi
                fi
            fi
        done
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
                    if [ $pstart -gt $pend ];then
                        pend=$end
                    fi
                fi
            fi
        done
    fi
fi

#先满足大小，再满足位置
#如果位置无法满足，考虑大小
if [ $xyz = 011 ];then
    if [ $pend != $pend0 ] || [ `expr $pend - $pstart + 1` -ne $psize ];then
        xyz=111
    fi
fi
if [ $xyz = 101 ];then
    if [ $pstart != $pstart0 ] || [ `expr $pend - $pstart + 1` -ne $psize ];then
        xyz=111
    fi
fi

#size
if [ $xyz = 00 ] || [ $xyz = 111 ];then
    local maxspace=0
    local maxstart=0
    local pmaxspace=0
    local pmaxstart=0
    local lmaxspace=0
    local lmaxstart=0
    local havespace=0
    #寻找满足条件的区间
    #选择满足大小的第一个（根据方向）区间，没有满足的则先最大区间
    #主分区中的满足空间
    for ((i=0;i<$[${#pspace[@]}/2];i++));do
        space=`expr ${pspace[$[$i*2+1]]} - ${pspace[$[$i*2+0]]}`
        if [ $space -eq 0 ];then
            continue
        fi
        #优先判断是否大于size，其次再保存最大空间
        if [ $space -ge $psize ];then
            havespace=1
            pmaxspace=$space
            pmaxstart=${pspace[$[$i*2+0]]}
            #方向为从低到高，则取第一个满足的空间
            if [ ${direction} = l ];then
                break;
            #方向为从高到低，则取最后一个满足的空间
            else
                if [ $psize -ne 0 ];then
                    pmaxstart=`expr ${pspace[$[$i*2+1]]} - ${psize}`
                fi
            fi
        elif [ $havespace -eq 0 ] && [ $space -gt $pmaxspace ];then
            pmaxspace=$space
            pmaxstart=${pspace[$[$i*2+0]]}
        fi
    done
    havespace=0
    #逻辑分区中的满足空间
    for ((i=0;i<$[${#lspace[@]}/2];i++));do
        space=`expr ${lspace[$[$i*2+1]]} - ${lspace[$[$i*2+0]]} - $mbr_sectors`
        if [ $space -eq 0 ];then
            continue
        fi
        #优先判断是否大于size，其次再保存最大空间
        if [ $space -ge $psize ];then
            havespace=1
            lmaxspace=$space
            lmaxstart=`expr ${lspace[$[$i*2+0]]} + $mbr_sectors`
            #方向为从低到高，则取第一个满足的空间
            if [ $direction = l ];then
                break;
            #方向为从高到低，则取最后一个满足的空间
            else
                if [ $psize -ne 0 ];then
                    lmaxstart=`expr ${lspace[$[$i*2+1]]} - $mbr_sectors - ${psize}`
                fi
            fi
        elif [ $havespace -eq 0 ] && [ $space -gt $lmaxspace ];then
            lmaxspace=$space
            lmaxstart=`expr ${lspace[$[$i*2+0]]} + $mbr_sectors`
        fi
    done

    #any type.
    #没有指定type时
    #优先建逻辑分区
    #p>l,n<4:p
    #p>l,n=4:
    #   e=1:l
    #   e=0:error
    #p<=l:
    #   e=1:l
    #   e=0:
    #       n<4:p
    #       n=4:error
    if [ $ptype = a ];then
        if [ $extended_nums -lt 1 ] && [ $primary_nums -ge 4 ];then
            #error
            echo "no more primaries, and no extended to create a logial"
            exit 1
        else
            #在大小都满足psize的情况下优先主分区
            #否则选择分区大的
            if [ $pmaxspace -ge $psize ] && [ $primary_nums -lt 4 ];then
                ptype=p
            elif [ $lmaxspace -ge $psize ] && [ $extended_nums -ge 1 ];then
                ptype=l
            elif [ $pmaxspace -gt $lmaxspace ] && [ $primary_nums -lt 4 ];then
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

    #psize=0是种特殊情况
    if [ $psize -eq 0 ];then
        psize=$maxspace
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
fi

##检查结果
if [ $pstart -gt $pend ];then
    #error
    echo "no more space."
    exit 1
fi

if [ x$psize != x$psize0 ] || [ x$pstart != x$pstart0 ] || [ x$pend != x$pend0 ];then
    if [ $force -ne 1 ];then
        #error
        echo "($(skmgtp ${pstart0}s ${unit})${unit},$(skmgtp ${pend0}s ${unit})${unit},$(skmgtp ${psize0}s ${unit})${unit},${ptype0})=>($(skmgtp ${pstart}s ${unit})${unit},$(skmgtp ${pend}s ${unit})${unit},$(skmgtp ${psize}s ${unit})${unit},${ptype})"
        echo "use \"./xpart disk -I -us\" to get more detail."
        exit 1
    fi
fi

if [ $execute = 1 ];then
parted $disk mkpart $ptype ${pstart}s ${pend}s >/dev/null 2>&1 <<EOF
I
Y
EOF
else
    echo "start: $(skmgtp ${pstart}s ${unit})${unit}, end: $(skmgtp ${pend}s ${unit})${unit}, size: $(skmgtp `expr ${pend} - ${pstart} + 1`s ${unit})${unit}, type: ${ptype}"
	exit 0
fi

#格式化
local num=`parted $disk unit s p|grep "${pstart}s"|cut -d' ' -f2`
local format_stat
if [ x$fs != x ];then
    if [ -e ${disk}${num} ];then
        if mkfs -t $fs ${disk}${num} >/dev/null 2>&1;then
            format_stat="successfully formatted partition ${disk}${num} to $fs."
        else
            format_stat="format error."
        fi
    else
        echo "format error: file not exist."
        echo "maybe ${disk} is not a block device."
    fi
fi

#what have been created.
if [ $verbose -eq 1 ];then
    local vunit
    if [ $unit != s ];then
        vunit=${unit}ib
    fi

    parted $disk unit ${vunit} p|grep '^Number'
    parted $disk unit ${vunit} p|grep -i "^ ${num}"
    echo $format_stat

fi
}

