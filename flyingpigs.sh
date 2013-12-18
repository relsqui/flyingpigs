#!/bin/sh

# parse command-line switches and respond accordingly
args=`getopt -o hc:m:r:l: -l help,cpu:,mem:,memory:,res:,resource:,load: -- $*`
set -- $args

for arg; do
    case "$arg" in
        -h|--help)
            name=`basename $0`
            cat <<EOF
usage: $name [-h] [-c CPU] [-m MEMORY] [-r RESOURCE] SERVER [SERVER ...]

Shows processes on each SERVER which may be a runaway, given the criteria
specified either on the command line or in the environment variables.

positional arguments:
  SERVER            addresses of servers to ssh into and check for runaways

optional arguments:
  -h, --help        show this help message and exit
  -c, --cpu         set the minimum %CPU usage to report
  -m, --mem[ory]    set the minimum %memory usage to report
  -r, --res[ource]  set default for both CPU and memory thresholds
  -l, --load        set the minimum load to report

environment variables and defaults:
  CPU_THRESHOLD=10
  MEM_THRESHOLD=5
  RES_THRESHOLD=
  LOAD_THRESHOLD=5
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
        -l|--load)
            LOAD_THRESHOLD=`echo "$2" | sed "s/'//g"`
            shift; shift
        ;;
        --)
            shift
            servers=`echo "$*" | sed "s/'//g"`
        ;;
    esac
done


# utility for making plural nouns display properly
plural() {
    if [ "$1" -eq 1 ]; then
        echo -n ""
        return 1
    else
        echo -n "s"
        return 0
    fi
}

# utility for truncating floating-point numbers
int() {
    echo -n $1 | cut -d '.' -f 1
}

# what to do for each server we're checking on
check_on() {
    short_name=`echo $1 | sed 's/.pdx.edu$//'`

    # get the fields we want, and no headers, in a portable way
    nice ssh $1 "ps -e -o pid= -o user= -o tty= -o pcpu= -o pmem= -o nice= -o args=; uptime" > $tempdir/servers/$1
    load=`tail -n 1 $tempdir/servers/$1 | sed 's/.*load average: *//' |\
        tr ',' ' '`

    cat $tempdir/servers/$1 | head -n -1 | while read proc; do
        if [ -n "$proc" ]; then
            echo $proc | while read pid user tty cpu mem nice command; do
                # truncate numbers so bash can compare them
                intcpu=`int $cpu`
                intmem=`int $mem`

                # check memory and cpu usage and record if necessary
                if [ $intcpu -ge $CPU_THRESHOLD -o\
                     $intmem -ge $MEM_THRESHOLD ]; then
					# these are tab characters, so we can split on them later
                    echo "$short_name	$pid	$user	$tty	$cpu	$mem	$nice	$command" >> $tempdir/processes
                fi 2>/dev/null
            done
        fi
    done
    echo $load | while read load1 load5 load15; do
        load1=`int $load1`
        load5=`int $load5`
        load15=`int $load15`
        if [ $load1 -ge $LOAD_THRESHOLD -o \
             $load5 -ge $LOAD_THRESHOLD -o \
             $load15 -ge $LOAD_THRESHOLD ]; then
            echo "$short_name is under high load: $load" >> $tempdir/load
        fi
    done

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
if [ -z "$LOAD_THRESHOLD" ]; then
    LOAD_THRESHOLD=5
fi
echo CPU_THRESHOLD=$CPU_THRESHOLD >&2
echo MEM_THRESHOLD=$MEM_THRESHOLD >&2
echo LOAD_THRESHOLD=$LOAD_THRESHOLD >&2

# set up some temporary workspace
tempdir=`mktemp -dt "flyingpigs-XXXXXX"`
mkdir $tempdir/servers
touch $tempdir/processes
touch $tempdir/load
echo "SERVER	PID	USER	TTY	%CPU	%MEM	NI	COMMAND" > $tempdir/header

# collect and count the servers
server_count=`echo "$servers" | wc -w`
s=`plural $server_count`
echo "Checking $server_count server$s." >&2

# initialize ssh authentication
eval `ssh-agent` >/dev/null
ssh-add >&2

# connect in parallel to speed things up
echo -n "Searching " >&2
for server in $servers; do
    check_on $server &
done

# stall until all the servers have reported back
while [ ! -e $tempdir/ready ]; do sleep .1; done
echo ". done." >&2

echo >&2

# display load results, nicely formatted
load=`cat $tempdir/load | wc -l`
if [ $load -eq 0 ]; then
    echo "No systems under heavy load." >&2
else
    cat $tempdir/load
fi

echo >&2

# display runaway results, nicely formatted
candidates=`cat $tempdir/processes | wc -l`
if [ $candidates -eq 0 ]; then
    echo "Found no potential runaways." >&2
else
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
