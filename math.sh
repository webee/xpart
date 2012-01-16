#!/bin/bash

#math compare
#return:
#3,gt
#2,eq
#1,lt
#mcmp a b
function mcmp
{
    local a=$1
    local b=$2

    if [ `echo "$a > $b"|bc` = 1 ];then
	echo -n 3
    elif [ `echo "$a == $b"|bc` = 1 ];then
	echo -n 2
    else
	echo -n 1
    fi
}

#unit convert
#sector,k,m,g,t,p
#skmgtp xxm s
function skmgtp
{
    local s=*1
    local S=$s
    local k=*2$s
    local K=$k
    local m=*1024$k
    local M=$m
    local g=*1024$m
    local G=$g
    local t=*1024$g
    local T=$t
    local p=*1024$t
    local P=$p

    local num=$1
    local unit=$2
    local result=0
    local expr0=$(echo "$num/1${unit}"|sed -n 's/\([sSkKmMgGtTpP]\)/$\1/g;p')
    local expr1=$(eval echo -n $expr0)
    result=$(echo "${expr1}"|bc)

    echo -n $result
}
