#!/bin/sh


# ================= #
# === ARGUMENTS === #
# ================= #

# parse command-line switches and respond accordingly
args=`getopt -o hwst:c:m:r:l: \
     -l help,wrap,serial,timeout:,cpu:,mem:,memory:,res:,resource:,load: -- $*`
set -- $args

WRAP=false
SERIAL=false
for arg; do
    case "$arg" in
        -h|--help)
            name=`basename $0`
            cat <<EOF
usage: $name [-h] [-w] [-s] [-t T] [-c C] [-m M] [-r R] [-l L] SYS [SYS...]

Reports processes on each system which may be runaways, as well as any system
which is under high load. You can specify the criteria for these using the
command line arguments, environment variables, or both. Processes waiting
on disk access will also be listed on systems reporting high load.

positional arguments:
  SYS                 name or address of a system to check for runaways

optional arguments:
  -h, --help          show this help message and exit
  -w, --wrap          wrap output instead of truncating to fit screen
  -s, --serial        connect to hosts one by one instead of in the background
  -t, --timeout T     wait T seconds before giving up on an ssh connection
  -c, --cpu C         set the minimum reported CPU usage to C%
  -m, --mem[ory] M    set the minimum reported memory usage to M%
  -r, --res[ource] R  set default for both CPU and memory thresholds
  -l, --load L        set the minimum reported load average to L

environment variables and defaults:
  TIMEOUT=7
  CPU_THRESHOLD=10
  MEM_THRESHOLD=5
  RES_THRESHOLD=
  LOAD_THRESHOLD=3
EOF
            exit
        ;;
        -w|--wrap)
            WRAP=true
            shift
        ;;
        -s|--serial)
            SERIAL=true
            shift
        ;;
        -t|--timeout)
            TIMEOUT=`echo "$2" | sed "s/'//g"`
            shift
            shift
        ;;
        -c|--cpu)
            CPU_THRESHOLD=`echo "$2" | sed "s/'//g"`
            shift
            shift
        ;;
        -m|--mem|--memory)
            MEM_THRESHOLD=`echo "$2" | sed "s/'//g"`
            shift
            shift
        ;;
        -r|--res|--resource)
            RES_THRESHOLD=`echo "$2" | sed "s/'//g"`
            shift
            shift
        ;;
        -l|--load)
            LOAD_THRESHOLD=`echo "$2" | sed "s/'//g"`
            shift
            shift
        ;;
        --)
            shift
            systems=`echo "$*" | sed "s/'//g"`
        ;;
    esac
done


# ================= #
# === FUNCTIONS === #
# ================= #

# utility for making plural nouns display properly
plural() {
    if [ "$1" -eq 1 ]; then
        echo -n ""
    else
        echo -n "s"
    fi
}

# utility for truncating floating-point numbers
int() {
    echo -n $1 | cut -d '.' -f 1
}

# how to clean up after ourselves
cleanup() {
    pkill -P $$
    rm -r $tempdir
    if $kill_ssh_agent; then
        eval `ssh-agent -k` #>/dev/null
    fi
    exit
}

# what to do for each system we're checking on
check_on() {
    # get the fields we want, and no headers, in a portable way
    timeout $TIMEOUT nice ssh $1 "ps -e -o pid= -o user= -o tty= -o stime= \
        -o pcpu= -o pmem= -o s= -o nice= -o args=; uptime"\
        > $tempdir/systems/$1 2>/dev/null
    if [ "$?" -ne 0 ]; then
        echo "Couldn't reach $1!" >> $tempdir/errors
        echo $1 >> $tempdir/finished
        echo -n "x" >&2
    fi

    # copy the uptime line off the end and truncate to just the load numbers
    load=`tail -n 1 $tempdir/systems/$1 | sed 's/.*load average: *//' |\
        tr ',' ' '`

    # check 1- 5- and 15-minute load averages against threshold
    loaded=false
    echo $load | while read load1 load5 load15; do
        load1=`int $load1`
        load5=`int $load5`
        load15=`int $load15`
        if [ "$load1" -ge $LOAD_THRESHOLD -o \
             "$load5" -ge $LOAD_THRESHOLD -o \
             "$load15" -ge $LOAD_THRESHOLD ]; then
            echo "$1 is under high load: $load" >> $tempdir/load
            loaded=true
        fi 2>/dev/null
        if [ "$?" -ne 0 ]; then
            echo "Couldn't get load data for $1." >> $tempdir/errors
        fi
    done

    # read our file of collected processes, ignoring uptime line at the end
    cat $tempdir/systems/$1 | head -n -1 | while read proc; do
        if [ -n "$proc" ]; then
            echo $proc |\
            while read pid user tty stime cpu mem state nice command; do
                # truncate numbers so the shell can compare them
                intcpu=`int $cpu`
                intmem=`int $mem`

                # trade second-level precision for some screen real estate
                stime=`echo $stime | cut -c 1-5`

                # check memory and cpu usage, as well as state if the system
                # is loaded, and record the process if necessary
                if [ "$intcpu" -ge "$CPU_THRESHOLD" -o\
                     "$intmem" -ge "$MEM_THRESHOLD" -o\
                     \("$state" = "D" -a $loaded\) ]; then
                    # these are tabs, not spaces, so we can split on them later
                    echo "$1	$pid	$user	$tty	$stime	$cpu	$mem	$state	$nice	$command" >> $tempdir/processes
                fi
            done 2>/dev/null
        fi
    done

    # mark system as complete
    echo $1 >> $tempdir/finished
    echo -n "o" >&2
}


# ============= #
# === SETUP === #
# ============= #

# collect and count the systems
system_count=`echo "$systems" | wc -w`
s=`plural $system_count`
echo "Checking $system_count system$s." >&2
if [ $system_count -eq 0 ]; then
    echo "Nothing to check. Exiting." >&2
    exit
fi

# set timeout if not provided
if [ -z "$TIMEOUT" ]; then
    TIMEOUT=7
fi

# set default threshold variables
if [ -z "$RES_THRESHOLD" ]; then
    cpu_default=10
    mem_default=5
else
    cpu_default=$RES_THRESHOLD
    mem_default=$RES_THRESHOLD
fi

# apply them only if no values were provided
if [ -z "$CPU_THRESHOLD" ]; then
    CPU_THRESHOLD=$cpu_default
fi
if [ -z "$MEM_THRESHOLD" ]; then
    MEM_THRESHOLD=$mem_default
fi
if [ -z "$LOAD_THRESHOLD" ]; then
    LOAD_THRESHOLD=3
fi

echo TIMEOUT=$TIMEOUT >&2
echo CPU_THRESHOLD=$CPU_THRESHOLD >&2
echo MEM_THRESHOLD=$MEM_THRESHOLD >&2
echo LOAD_THRESHOLD=$LOAD_THRESHOLD >&2
echo SERIAL=$SERIAL >&2

# make sure we exit politely even if interrupted
trap cleanup hup int term quit

# set up some temporary workspace
tempdir=`mktemp -dt "flyingpigs-XXXXXX"`
mkdir $tempdir/systems
touch $tempdir/processes
touch $tempdir/load
touch $tempdir/finished
touch $tempdir/errors
echo "SYSTEM	PID	USER	TTY	STIME	%CPU	%MEM	S	NI	COMMAND"\
    > $tempdir/header

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


# ================== #
# === MAIN LOOPS === #
# ================== #

echo -n "Collecting information " >&2
for system in $systems; do
    if grep "^$system[., ]" ~/.ssh/known_hosts /etc/ssh/*known_hosts* \
        >/dev/null && ! $SERIAL; then
        # if we're not in serial mode and the system is in known_hosts,
        # connect in parallel to speed things up
        check_on $system &
    else
        check_on $system
    fi
done

# kill time until all systems have reported back
while [ `wc -l $tempdir/finished | cut -d " " -f 1` -lt $system_count ]; do
    echo -n "." >&2
    sleep .5
done
echo " done." >&2

echo >&2


# =============== #
# === DISPLAY === #
# =============== #

# display load results, nicely formatted
load=`cat $tempdir/load | wc -l`
if [ $load -eq 0 ]; then
    echo "No systems under heavy load." >&2
else
    cat $tempdir/load
fi

echo >&2

# display runaway results, nicely formatted
if [ `cat $tempdir/processes | wc -l` -eq 0 ]; then
    echo "Found no potential runaways." >&2
else
    # make sure processes on the same system are adjacent
    sort $tempdir/processes > $tempdir/sorted
    if $WRAP; then
        cat $tempdir/header $tempdir/sorted |\
            column -nts "	" | > $tempdir/formatted
    else
        cat $tempdir/header $tempdir/sorted |\
            column -nts "	" | cut -c 1-`tput cols` > $tempdir/formatted
    fi
    # output headers on stderr, content on stdout
    head -n 1 $tempdir/formatted >&2
    tail -n +2 $tempdir/formatted
fi

if [ `cat $tempdir/errors | wc -l` -ne 0 ]; then
    echo >&2
    cat $tempdir/errors >&2
fi

cleanup


# modeline to tell vim not to expand the tabs in this file
# (it's indented with spaces, but we use tabs to split on in some strings)
# vim: set noexpandtab
