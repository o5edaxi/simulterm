# simulterm

This bash script takes a command and runs it in multiple terminal panes interactively using tmux, replacing a "####" token with a series of strings (which can be IP addresses, domains, or anything at all) passed as arguments to the script.

Throught the -l flag, the script can gather the destination addresses automatically by discovering IPv6 hosts on the link-local network. This makes it very useful for example during the configuration of multiple network devices whose IP is not known or configured yet. The resulting sessions are fully interactive and accept keyboard input from the user.

```
Usage:
	Pass the destinations as arguments to the script, and then enter the command to be executed with \"####\" as a placeholder for the addresses.
	For example: ssh admin@####
		192.0.2.1 192.0.2.3 host.example.com 2001:db8::1 192.0.2.2
	will open interactive ssh sessions towards all the selected destinations:
    ssh admin@192.0.2.1
    ssh admin@192.0.2.3
    etc.
    
	Run the script with the -l flag to run IPv6 autodiscovery on the local link and contact those addresses instead (hosts must have fe80 addresses and respond to pings).
```