#!/bin/sh
loops=$(losetup -a|awk -F: '{printf("%s ",$1);}')
if [ -n "$loops" ]; then
    losetup -d $loops
    echo "$loops deleted!"
else
    echo "no loop device!"
fi
