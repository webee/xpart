#!/bin/sh
disk=$1
if [ -n "$disk" ]; then
echo -e "fdisk ${disk} now..."
dd if=/dev/zero of=$disk bs=1M count=1 conv=notrunc &>/dev/null
#fdisk $disk <<EOF
fdisk $disk >/dev/null 2>&1 <<EOF &
n
p


+32M

n
p


+64M

n
e




w
EOF

echo -e "done"

else
    echo -e "usage: $0 disk"
fi
