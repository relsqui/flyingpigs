#!/bin/sh

check_on() {
    # get the fields we want, and no headers, in a portable way
    ssh $1 'ps -e -o pid= -o user= -o tty= -o pcpu= -o pmem= -o nice= -o args=' > $tempdir/servers/$1

    short_name=`echo $1 | sed 's/.pdx.edu$//'`
    while read proc; do
        if [ -n "$proc" ]; then
            echo $proc | while read pid user tty cpu mem nice command; do
                # truncate numbers so bash can compare them
                cpu=`echo $cpu | cut -d '.' -f 1`
                mem=`echo $mem | cut -d '.' -f 1`

                # every field should have at least a placeholder
                if [ -z $tty ]; then tty="-"; fi
                if [ -z $cpu ]; then cpu="-"; fi
                if [ -z $mem ]; then mem="-"; fi
                if [ -z $nice ]; then nice="-"; fi

                # check memory and cpu usage and record if necessary
                if [ $cpu -ge 10 -o $mem -ge 10 ]; then
					# these are tab characters, so we can split on them later
                    echo "$short_name	$pid	$user	$tty	$cpu	$mem	$nice	$command" >> $tempdir/processes
                fi 2>/dev/null
            done
        fi
    done < $tempdir/servers/$1

    # mark server as complete, and end waiting loop if this is the last one
    echo $1 >> $tempdir/done
    if [ `cat $tempdir/done | wc -l` -eq $server_count ]; then
        touch $tempdir/ready
    else
        echo -n "." >&2
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
ssh-add >&2

# connect in parallel to speed things up
echo -n "Checking $server_count servers " >&2
for server in $servers; do
    check_on $server &
done

# stall until all the servers have reported back
while [ ! -e $tempdir/ready ]; do sleep .1; done
echo " done." >&2

# display the results, nicely formatted
column -ts "	" $tempdir/processes | cut -c 1-`tput cols`

# clean up
rm -r $tempdir
