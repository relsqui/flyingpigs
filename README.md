flyingpigs
==========
tracks down and reports runaway processes which could potentially have a negative impact on people using your systems. For best results, set up ssh key authentication on the remote systems so you don't have to retype a password for each one.

```
usage: flyingpigs [-h] [-c CPU] [-m MEMORY] [-r RESOURCE] SYSTEM [SYSTEM ...]

Shows processes on each SYSTEM which may be runaways, given the criteria
specified either on the command line or in the environment variables.

positional arguments:
  SYSTEM            addresses of systems to ssh into and check for runaways

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
  LOAD_THRESHOLD=3
```

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
