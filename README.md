# simulterm

This bash script takes a command and runs it in multiple terminal panes interactively using tmux, replacing a "####" token with a series of strings (which can be IP addresses, domains, or anything at all) passed as arguments to the script.

Through the -l flag, the script can gather the destination addresses automatically by discovering IPv6 hosts on the link-local network. This makes it very useful for example during the configuration of multiple network devices whose IP is not known or configured yet, but RFC4862 autoconfiguration has been performed. The resulting sessions are fully interactive and accept keyboard input from the user.


### Usage

Pass the destinations as arguments to the script, and then enter the command to be executed with \"####\" as a placeholder for the addresses.
For example:
```
./simulterm.sh 192.0.2.1 192.0.2.3 host.example.com 2001:db8::1
ssh admin@####
```
will open interactive ssh sessions towards all the selected destinations:
```
ssh admin@192.0.2.1
ssh admin@192.0.2.3
ssh admin@host.example.com
ssh admin@2001:db8::1
```

The #### placeholder can be used one or more times in the initial command. The interactive session can then be navigated with regular tmux shortcuts, for example:
```
# Disable multi-input
CTRL-B
:setw synchronize-panes
# Select different pane with arrow keys
CTRL-B
# Expand pane
CTRL-B
z
# Kill session
CTRL-B
:kill-session
```
### Reading from file

Run the script with the -f flag to pass a TSV file as argument to the script and read destinations from it, as well as 2 optional values that can be pasted into the terminals using CTRL-V and CTRL-T shortcuts (after the tmux prefix shortcut). E.g.:
```	
192.0.2.1	foo	bar
192.0.2.2	baz	cat
192.0.2.3	dog	bird
```
Pane 1:
```
CTRL+B
CTRL+V
  foo
CTRL+B
CTRL+T
  bar
```
Pane 2:
```
CTRL+B
CTRL+V
  baz
CTRL+B
CTRL+T
  cat
```
Pane 3:
```
CTRL+B
CTRL+V
  dog
CTRL+B
CTRL+T
  bird
```
If the -l flag is also set, destinations will be autodiscovered and the first column will be ignored. Values will be assigned randomly to the discovered IPs and up to exhaustion.

### Autodiscovery

Run the script with the -l flag to run IPv6 autodiscovery on the local link and contact those addresses instead (the hosts must have fe80 addresses and respond to pings for this feature to work).

### Prerequisites

* tmux
* iproute2

### License

This project is licensed under the [MIT License](LICENSE).
