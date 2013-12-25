#!/bin/sh

# parse command-line switches and respond accordingly
args=`getopt -o hwsc:m:r:l: \
     -l help,wrap,serial,cpu:,mem:,memory:,res:,resource:,load: -- $*`
set -- $args

WRAP=false
SERIAL=false
for arg; do
    case "$arg" in
        -h|--help)
            name=`basename $0`
            cat <<EOF
usage: $name [-h] [-w] [-s] [-c C] [-m M] [-r R] [-l L] SYS [SYS ...]

Reports processes on each system which may be runaways, as well as any system
which is under high load. You can specify the criteria for these using the
command line arguments, environment variables, or both.

positional arguments:
  SYS                 name or address of a system to check for runaways

optional arguments:
  -h, --help          show this help message and exit
  -w, --wrap          wrap output instead of truncating to fit screen
  -s, --serial        connect to hosts one by one instead of in the background
  -c, --cpu C         set the minimum reported CPU usage to C%
  -m, --mem[ory] M    set the minimum reported memory usage to M%
  -r, --res[ource] R  set default for both CPU and memory thresholds
  -l, --load L        set the minimum reported load average to L

environment variables and defaults:
  CPU_THRESHOLD=10
  MEM_THRESHOLD=5
  RES_THRESHOLD=
  LOAD_THRESHOLD=3
EOF
            exit
        ;;
        -w|--wrap)
            WRAP=true
            shift;
        ;;
        -s|--serial)
            SERIAL=true
            shift;
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
            systems=`echo "$*" | sed "s/'//g"`
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

# what to do for each system we're checking on
check_on() {
    # get the fields we want, and no headers, in a portable way
    nice ssh $1 "ps -e -o pid= -o user= -o tty= -o stime= -o pcpu=\
        -o pmem= -o nice= -o args=; uptime"\
        > $tempdir/systems/$1 2>/dev/null || return

    # copy the uptime line off the end and truncate to just the load numbers
    load=`tail -n 1 $tempdir/systems/$1 | sed 's/.*load average: *//' |\
        tr ',' ' '`

    # read our file of collected processes, ignoring uptime line at the end
    cat $tempdir/systems/$1 | head -n -1 | while read proc; do
        if [ -n "$proc" ]; then
            echo $proc | while read pid user tty stime cpu mem nice command; do
                # truncate numbers so bash can compare them
                intcpu=`int $cpu`
                intmem=`int $mem`

                # check memory and cpu usage and record the process if necessary
                if [ $intcpu -ge $CPU_THRESHOLD -o\
                     $intmem -ge $MEM_THRESHOLD ]; then
                    # these are tab characters, so we can split on them later
                    echo "$1	$pid	$user	$tty	$stime	$cpu	$mem	$nice	$command" >> $tempdir/processes
                fi 2>/dev/null
            done
        fi
    done

    # check 1- 5- and 15-minute load averages against threshold
    echo $load | while read load1 load5 load15; do
        load1=`int $load1`
        load5=`int $load5`
        load15=`int $load15`
        if [ $load1 -ge $LOAD_THRESHOLD -o \
             $load5 -ge $LOAD_THRESHOLD -o \
             $load15 -ge $LOAD_THRESHOLD ]; then
            echo "$1 is under high load: $load" >> $tempdir/load
        fi
    done

    # mark system as complete, and end waiting loop if this is the last one
    echo $1 >> $tempdir/done
    if [ `cat $tempdir/done | wc -l` -eq $system_count ]; then
        touch $tempdir/ready
    fi
    echo -n "." >&2
}


# apply default threshold variables if necessary
if [ -z "$RES_THRESHOLD" ]; then
    cpu_default=10
    mem_default=5
else
    cpu_default=$RES_THRESHOLD
    mem_default=$RES_THRESHOLD
fi

# override those if other values were provided
if [ -z "$CPU_THRESHOLD" ]; then
    CPU_THRESHOLD=$cpu_default
fi
if [ -z "$MEM_THRESHOLD" ]; then
    MEM_THRESHOLD=$mem_default
fi
if [ -z "$LOAD_THRESHOLD" ]; then
    LOAD_THRESHOLD=3
fi

echo CPU_THRESHOLD=$CPU_THRESHOLD >&2
echo MEM_THRESHOLD=$MEM_THRESHOLD >&2
echo LOAD_THRESHOLD=$LOAD_THRESHOLD >&2

# set up some temporary workspace
tempdir=`mktemp -dt "flyingpigs-XXXXXX"`
mkdir $tempdir/systems
touch $tempdir/processes
touch $tempdir/load
echo "SYSTEM	PID	USER	TTY	STIME	%CPU	%MEM	NI	COMMAND"\
    > $tempdir/header

# collect and count the systems
system_count=`echo "$systems" | wc -w`
s=`plural $system_count`
echo "Checking $system_count system$s." >&2
if [ $system_count -eq 0 ]; then
    echo "Nothing to check. Exiting." >&2
    exit
fi

# initialize an ssh agent if necessary
if [ -z "$SSH_AGENT_PID" ]; then
    eval `ssh-agent` >/dev/null
    kill_ssh_agent=true
else
    kill_ssh_agent=false
fi

# add keys, if there aren't any already
if ! ssh-add -l >/dev/null; then
    ssh-add >&2
fi

# still no keys? we'll probably need to authenticate; use serial mode
if ! ssh-add -l >/dev/null; then
    SERIAL=true
fi

echo -n "Collecting information " >&2
for system in $systems; do
    if ! $SERIAL && grep "^$system[, ]" ~/.ssh/known_hosts >/dev/null; then
        # connect in parallel to speed things up
        check_on $system &
    else
        # except for unknown hosts or if serial mode is on
        check_on $system
    fi
done

# stall until all the systems have reported back
while [ ! -e $tempdir/ready ]; do sleep .1; done
echo " done." >&2

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
    if $WRAP; then
        cat $tempdir/header $tempdir/processes |\
            column -nts "	" > $tempdir/formatted
    else
        cat $tempdir/header $tempdir/processes |\
            column -nts "	" | cut -c 1-`tput cols` > $tempdir/formatted
    fi
    # output headers on stderr, content on stdout
    head -n 1 $tempdir/formatted >&2
    tail -n +2 $tempdir/formatted
fi

# clean up
rm -r $tempdir
if [ $kill_ssh_agent ]; then
    eval `ssh-agent -k` >/dev/null
fi


# modeline to tell vim not to expand the tabs in this file
# vim: set noexpandtab
