flyingpigs
==========
tracks down and reports runaway processes which could potentially have a negative impact on the responsiveness of your systems. Just invoke it with the address(es) of one or more hosts you want to check on and authenticate as needed.

### quick reference ###
```
usage: flyingpigs [-h] [-w] [-s] [-t T] [-c C] [-m M] [-r R] [-l L] SYS [SYS...]

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
```

### what's a runaway? ###
You can change the criteria for what processes are considered potential runaways by setting the environment variables, specifying them on the command line, or a combination of the two. The specific options take precedence over the environment variables, and both of those take precedence over the general resource threshold option. So one rather overcomplicated way to configure your criteria would be like this:
```
export CPU_THRESHOLD=30
flyingpigs -r 20 apple.example.com banana.example.com cherry.example.com
```
With these settings, flyingpigs would report processes using at least 30% of a CPU (specified explicitly in a variable) or 20% of available memory (falling back on the general resource threshold option), or systems with a load average of at least 3 (the default). (Note that --resource applies only to CPU and memory, not to load, since it's measured on a different scale.) It would also report any process which is waiting for disk access on a system which is over the load threshold, regardless of the resource usage of that process.

flyingpigs will list the thresholds it's using when you run it.

### other options and i/o ###
By default, flyingpigs connects to systems in the background and truncates the output to fit into columns on your screen. If you want to keep all the connections in the foreground (and consequently make only one at a time), use --serial. If you want to see more of the output, you can either make your terminal wider or use --wrap to turn off truncation altogether.

If an ssh connection to one of the systems cannot be made, flyingpigs will report it as a failure. If the ssh connection is accepted but cannot be completed, flyingpigs will wait a specified number of seconds before giving up. You can change the timeout with --timeout.

flyingpigs ignores stdin. All its important content (load and process messages) goes to stdout, and everything else (labels and information) goes to stderr, so you can safely redirect it to a file for later parsing without a lot of extra clutter. Prompts for authentication will go to the terminal regardless of whether stdout and/or stderr are redirected.

### authentication ###
flyingpigs will check for an ssh-agent and create one if it doesn't exist, then check for keys and add them if not present. For best results, set up ssh keys and get all the systems you'll be checking on into your known_hosts ahead of time. Failing that, flyingpigs will attempt to guess when you'll need to authenticate interactively and keep those processes in the foreground (instead of backgrounding them to save time). You can tell it to do this for all systems being checked with --serial.

To specify a different user than your current one to connect as, prepend the username to the hostname using normal ssh syntax: `flyingpigs relsqui@carabiner.peeron.com`.

### example ###
```
[finnre@rita flyingpigs]$ ssh-agent bash

[finnre@rita flyingpigs]$ ssh-add
Enter passphrase for /u/finnre/.ssh/id_rsa: 
Identity added: /u/finnre/.ssh/id_rsa (/u/finnre/.ssh/id_rsa)
Enter passphrase for /u/finnre/.ssh/id_dsa: 

[finnre@rita flyingpigs]$ flyingpigs `netgrouplist linux-login-sys ece-secure-sys cs-secure-sys | cut -d . -f 1`
TIMEOUT=7
CPU_THRESHOLD=10  
MEM_THRESHOLD=5  
LOAD_THRESHOLD=3  
Checking 64 systems.  
Collecting information ...........o....o.o.oooo..o.ooo.oooooooooo.oooooo.ooooooooooooooooooooooooooooo.ooooo...o..o.o done.  
  
rita is under high load: 14.36  16.75  15.84  
  
SYSTEM         PID    USER    TTY  STIME  %CPU  %MEM  S  NI  COMMAND  
emerald        6823   root    ?    14:46  13.0  0.1   S  0   sshd: finnre [priv]
emerald        6829   finnre  ?    14:46  16.0  0.0   R  0   ps -e -o pid= -o us
eve            12108  avahi   ?    Dec19  30.2  0.0   S  0   avahi-daemon: runni
fab04          57     root    ?    Dec19  0.0   0.0   D  0   [kworker/u:4]  
little         32109  root    ?    14:46  12.5  0.6   S  0   puppet agent: apply
rita           20241  jag     ?    Dec27  0.0   0.1   D  0   /usr/lib/gnome-sett
rita           20278  jag     ?    Dec27  5.7   0.0   D  0   /usr/lib/dconf/dcon
rita           20284  jag     ?    Dec27  0.0   0.1   D  0   nautilus -n  
rita           20311  jag     ?    Dec27  0.0   0.0   D  0   /usr/lib/indicator-
rita           20380  jag     ?    Dec27  0.0   0.0   D  0   /usr/lib/gnome-disk
rita           20403  jag     ?    Dec27  0.0   0.0   D  0   telepathy-indicator
rita           20404  jag     ?    Dec27  0.0   0.0   D  0   /usr/lib/gnome-user
rita           20432  jag     ?    Dec27  0.0   0.0   D  0   gnome-screensaver  
rita           20683  jag     ?    Dec27  0.0   0.0   D  0   update-notifier  
rita           20945  jag     ?    Dec27  0.0   0.0   D  0   /usr/lib/deja-dup/d
rita           21887  jag     ?    Dec27  0.0   0.0   D  0   nautilus computer:/
rita           22042  jag     ?    Dec27  0.0   0.0   D  0   gnome-terminal  
rita           5192   avahi   ?    Dec27  36.2  0.0   S  0   avahi-daemon: runni
ruby           3063   root    ?    14:46  86.5  1.5   S  0   puppet agent: apply
ruby           7498   avahi   ?    Dec20  34.8  0.0   S  0   avahi-daemon: runni
sapphire       2872   avahi   ?    Dec19  33.8  0.0   S  0   avahi-daemon: runni
walle          9643   avahi   ?    Dec19  30.5  0.0   S  0   avahi-daemon: runni
white-flipper  14498  root    ?    14:46  11.1  0.6   S  0   puppet agent: apply
```
