#!/bin/bash

#math compare
#return:
#3,gt
#2,eq
#1,lt
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
