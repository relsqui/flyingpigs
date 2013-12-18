#!/bin/sh

# parse command-line switches and respond accordingly
args=`getopt -o c:m:r:h -l cpu:,mem:,memory:,res:,resource:,help -- $*`
set -- $args

for arg; do
    case "$arg" in
        -h|--help)
            name=`basename $0`
            cat <<EOF
usage: $name [-h] [-c CPU] [-m MEMORY] [-r RESOURCE] SERVER [SERVER ...]

Shows processes on each SERVER whose CPU or memory percentage usage exceeds the
settings given. You can also export the CPU_THRESHOLD, MEM_THRESHOLD, and
RES_THRESHOLD variables directly if you prefer.

positional arguments:
  SERVER            addresses of servers to ssh into and check for runaways

optional arguments:
  -h, --help        show this help message and exit
  -c, --cpu         set the minimum %CPU usage to detect (default: 10)
  -m, --mem[ory]    set the minimum %memory usage to detect (default: 5)
  -r, --res[ource]  set default for both CPU and memory thresholds
EOF
            exit
        ;;
        -c|--cpu)
            CPU_THRESHOLD=`echo "$2" | sed "s/'//g"`
            shift; shift
        ;;
        -m|--mem|--memory)
            MEM_THRESHOLD=`echo "$2" | sed "s/'//g"`
            shift; shift
        ;;
        -r|--res|--resource)
            RES_THRESHOLD=`echo "$2" | sed "s/'//g"`
            shift; shift
        ;;
        --)
            shift
            servers=`echo "$*" | sed "s/'//g"`
        ;;
    esac
done


# what to do for each server we're checking on
check_on() {
    # get the fields we want, and no headers, in a portable way
    ssh $1 'ps -e -o pid= -o user= -o tty= -o pcpu= -o pmem= -o nice= -o args=' > $tempdir/servers/$1

    short_name=`echo $1 | sed 's/.pdx.edu$//'`
    while read proc; do
        if [ -n "$proc" ]; then
            echo $proc | while read pid user tty cpu mem nice command; do
                # truncate numbers so bash can compare them
                intcpu=`echo $cpu | cut -d '.' -f 1`
                intmem=`echo $mem | cut -d '.' -f 1`

                # check memory and cpu usage and record if necessary
                if [ $intcpu -ge $CPU_THRESHOLD -o\
                     $intmem -ge $MEM_THRESHOLD ]; then
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


# apply default threshold variables if necessary
if [ -z "$RESOURCE_THRESHOLD" ]; then
    cpu_default=10
    mem_default=5
else
    cpu_default=$RESOURCE_THRESHOLD
    mem_default=$RESOURCE_THRESHOLD
fi
if [ -z "$CPU_THRESHOLD" ]; then
    CPU_THRESHOLD=$cpu_default
fi
if [ -z "$MEM_THRESHOLD" ]; then
    MEM_THRESHOLD=$mem_default
fi
echo CPU_THRESHOLD=$CPU_THRESHOLD >&2
echo MEM_THRESHOLD=$MEM_THRESHOLD >&2

# set up some temporary workspace
tempdir=`mktemp -dt "flyingpigs-XXXXXX"`
mkdir $tempdir/servers
touch $tempdir/processes
echo "SERVER	PID	USER	TTY	%CPU	%MEM	NI	COMMAND" > $tempdir/header

# collect and count the servers
server_count=`echo "$servers" | wc -w`

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
candidates=`cat $tempdir/processes | wc -l`
if [ $candidates -eq 0 ]; then
    echo "Found no potential runaways." >&2
else
    echo "Found $candidates potential runaways." >&2
    echo >&2
    cat $tempdir/header $tempdir/processes | column -nts "	" |\
        cut -c 1-`tput cols` > $tempdir/formatted
    # output headers on stderr, content on stdout
    head -n 1 $tempdir/formatted >&2
    tail -n +2 $tempdir/formatted
fi

# clean up
rm -r $tempdir


# modeline to tell vim not to expand the tabs in this file
# vim: set noexpandtab
