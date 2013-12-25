flyingpigs
==========
tracks down and reports runaway processes which could potentially have a negative impact on the responsiveness of your systems. Just invoke it with the address(es) of one or more hosts you want to check on and authenticate as needed.

### quick reference ###
```
usage: flyingpigs [-h] [-w] [-s] [-c C] [-m M] [-r R] [-l L] SYS [SYS ...]

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
```

### authentication ###
flyingpigs will check for an ssh-agent and create one if it doesn't exist, then check for keys and add them if not present. For best results, set up ssh keys and get all the systems you'll be checking on into your known_hosts ahead of time. Failing that, flyingpigs will attempt to guess when you'll need to authenticate interactively and keep those processes in the foreground (instead of backgrounding them to save time). You can tell it to do this for all systems being checked with --serial.

To specify a different user than your current one to connect as, prepend the username to the hostname using normal ssh syntax: `flyingpigs relsqui@carabiner.peeron.com`.

### options and i/o ###
You can change the criteria for what processes are considered potential runaways by setting the environment variables, specifying them on the command line, or a combination of the two. The specific options take precedence over the environment variables, and both of those take precedence over the general resource threshold option. So one rather overcomplicated way to configure your criteria would be like this:
```
export CPU_THRESHOLD=30
flyingpigs -r 20 apple.example.com banana.example.com cherry.example.com
```
With these settings, flyingpigs would report processes using at least 30% of a CPU (specified explicitly in a variable) or 20% of available memory (falling back on the general resource threshold option), or systems with a load average of at least 3 (the default). Note that --resource applies only to CPU and memory, not to load, since it's measured on a different scale.

flyingpigs will report the thresholds it's using when you run it.

By default, flyingpigs connects to systems in the background and truncates the output to fit into columns on your screen. If you want to keep all the connections in the foreground (and consequently make only one at a time), use --serial. If you want to see more of the output, you can either make your terminal wider or use --wrap to turn off truncation altogether.

flyingpigs ignores stdin. All its important content (load and process messages) goes to stdout, and everything else (labels and information) goes to stderr, so you can safely redirect it to a file for later parsing without a lot of extra clutter. Prompts for authentication will go to the terminal regardless of whether stdout and/or stderr are redirected.

### example ###
```
[finnre@rita flyingpigs]$ flyingpigs `netgrouplist linux-login-sys ece-secure-sys cs-secure-sys | cut -d . -f 1`
CPU_THRESHOLD=10
MEM_THRESHOLD=5
LOAD_THRESHOLD=3
Checking 43 systems.
Enter passphrase for /u/finnre/.ssh/id_rsa:
Identity added: /u/finnre/.ssh/id_rsa (/u/finnre/.ssh/id_rsa)
Collecting information ........................................... done.

No systems under heavy load.

SYSTEM    PID    USER     TTY     STIME  %CPU  %MEM  NI  COMMAND
sapphire  9165   root     ?       02:04  16.8  6.4   0   puppet agent: applying
sapphire  9754   root     ?       02:05  0.0   6.3   0   puppet agent: applying
emerald   32365  root     ?       02:05  18.0  0.1   0   sshd: finnre [priv]
emerald   32371  finnre   ?       02:05  15.0  0.0   0   ps -e -o pid= -o user=
eve       8946   yuswang  pts/13  Dec09  1.3   23.4  0   /pkgs/matlab/2012b/bin/```
