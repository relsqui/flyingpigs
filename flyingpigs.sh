#!/bin/sh

check_on() {
    # what to do on each server we connect to
    echo -n "." >&2
    ssh $1 "uname -a" >> "$tempdir/unames"
    echo $1 >> $tempdir/done
    if [ `cat $tempdir/done | wc -l` -eq $server_count ]; then
        # this is the last one
        touch $tempdir/ready
    fi
}


# set up some temporary workspace
tempdir=`mktemp -dt "flyingpigs-XXXXXX"`

# collect and count the servers
servers=`netgrouplist linux-login-sys ece-secure-sys cs-secure-sys`
server_count=`echo "$servers" | wc -w`
export checked_count=0

# initialize ssh authentication
eval `ssh-agent` >/dev/null
ssh-add


# connect in parallel to speed things up
echo -n "Checking servers " >&2
for server in $servers; do
    check_on $server &
done

# stall until all the servers have reported back
while [ ! -e $tempdir/ready ]; do sleep .1; done
echo " done." >&2


# handle the collected data
cat $tempdir/unames


# clean up
rm -rf $tempdir
