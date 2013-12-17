#!/bin/sh

# what to do for each server we're checking on
check_on() {
    echo -n "." >&2

    # get the fields we want and no headers in a portable way
    ssh $1 'ps -e -o pid= -o user= -o tty= -o pcpu= -o pmem= -o nice= -o args=' > $tempdir/servers/$1

    # prepend the server name to each process and collect them
    while read proc; do
        if [ -n "$proc" ]; then
            echo $1 $proc >> $tempdir/processes
        fi
    done < $tempdir/servers/$1

    # mark server as complete, end waiting loop if this is the last one
    echo $1 >> $tempdir/done
    if [ `cat $tempdir/done | wc -l` -eq $server_count ]; then
        touch $tempdir/ready
    fi
}


# set up some temporary workspace
tempdir=`mktemp -dt "flyingpigs-XXXXXX"`
mkdir $tempdir/servers

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
echo `cat $tempdir/processes | wc -l` processes found.


# clean up
rm -rf $tempdir
