#!/bin/sh
base=*1
k=*1024$base
K=$k
m=*1024$k
M=$m
g=*1024$m
G=$g
t=*1024$g
T=$t
p=*1024$t
P=$p

while getopts "e:fo:" arg
do
    case $arg in
	e)
	    exp0=$OPTARG
	    ;;
	f)
	    f=f
	    ;;
	o)
	    ou=$OPTARG
	    ;;
	?)
	    echo "unkown argument"
	    exit 1
	    ;;
    esac
done

#check the output unit.
case $ou in
    k|m|g|t|p|K|M|G|T|P)
	eval "output_unit=\$$ou"
	;;
    *)
	if [ "x$f" = "xf" ];then
	    output_unit=$b
	    ou=
	else
	    echo "unkown unit."
	    exit 1
	fi
	;;
esac

#start calc
exp1=`echo ${exp0}|sed 's/k/$k/g;s/m/$m/g;s/g/$g/g;'`
eval "exp2=`echo -n $exp1`"

result=$(echo $exp2|bc)

#echo "scale=4;$result/(1$output_unit)"
result=$(echo "scale=4;$result/(1$output_unit)"|bc)$ou
echo $result
