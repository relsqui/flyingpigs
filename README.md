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
  LOAD_THRESHOLD=5
```

### example ###
```
[finnre@rita flyingpigs]$ flyingpigs `netgrouplist linux-login-sys ece-secure-sys cs-secure-sys | cut -d . -f 1`
CPU_THRESHOLD=10
MEM_THRESHOLD=5
LOAD_THRESHOLD=5
Checking 43 systems.
Enter passphrase for /u/finnre/.ssh/id_rsa:
Identity added: /u/finnre/.ssh/id_rsa (/u/finnre/.ssh/id_rsa)
Searching ........................................... done.

No systems under heavy load.

SYSTEM   PID    USER     TTY     %CPU  %MEM  NI  COMMAND
emerald  13441  root     ?       19.0  0.1   0   sshd: finnre [priv]
emerald  13447  finnre   ?       16.0  0.0   0   ps -e -o pid= -o user= -o tty=
ruby     31298  root     ?       12.9  2.7   0   puppet agent: applying configur
ruby     32339  root     ?       21.0  0.0   0   sh -c apt-show-versions -u open
ruby     32341  root     ?       74.0  2.4   0   /usr/bin/perl -w /usr/bin/apt-s
eve      8946   yuswang  pts/13  1.3   23.4  0   /pkgs/matlab/2012b/bin/glnxa64/```
