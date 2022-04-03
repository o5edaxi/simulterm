#!/bin/bash

SHORTCUT_1="C-V"
SHORTCUT_2="C-T"
SCRIPT_1="simulterm-script_1"
SCRIPT_2="simulterm-script_2"
TMUX_LOCATION="/usr/bin/tmux"

usage="The following options are supported:

	-h	Displays instructions
	-f	Read from file
	-l	Link-local mode
	-x	Bash debug

"

help="
Usage:
	Pass the destinations as arguments to the script, and then enter the command to be executed with \"####\" as a placeholder for the addresses. For example:

	./simulterm 192.0.2.1 192.0.2.3 host.example.com 2001:db8::1
	ssh admin@####

	will open interactive ssh sessions towards all the selected destinations:

	ssh admin@192.0.2.1
	ssh admin@192.0.2.3
	ssh admin@host.example.com
	ssh admin@2001:db8::1

	The placeholder can be used one or more times in the command.
	
	Reading from file:
	
	Run the script with the -f flag to pass a TSV file as argument to the script and read destinations from it, as well as 2 optional values that can be pasted into the terminals using CTRL-V and CTRL-T shortcuts (after the prefix shortcut). E.g.:
		
		192.0.2.1	foo	bar
		192.0.2.2	baz	cat
		192.0.2.3	dog	bird
	
	If the -l flag is also set, destinations will be autodiscovered and the first column will be ignored. Values will be assigned randomly to the discovered IPs and up to exhaustion.
	
	Autodiscovery:

	Run the script with the -l flag to run IPv6 autodiscovery on the local link and contact those addresses instead (the hosts must have fe80 addresses and respond to pings for this feature to work).
"

while getopts 'hflx' option; do
  case "$option" in
    h) echo "$help"
       exit
       ;;
	f) FILE_BASED=1
	   ;;
	l) LINK_LOCAL=1
       ;;
	x) DEBUG=1
	   ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done
shift $((OPTIND - 1))

if (( DEBUG == 1 )); then
	set -x
fi

command -v tmux &> /dev/null || { echo "This script requires tmux to run. Try with \"sudo apt install tmux\". Exiting..." ; exit 1; }

if (( FILE_BASED == 1 )); then
	[[ -f "$1" ]] || { echo "-f flag set but no TSV file provided. Exiting..." ; exit 1; }
fi

echo "Type in the command to be replicated, using \"####\" as a placeholder for the address:"
read -r COMMAND

[[ $COMMAND == "" ]] && { echo "No command inserted. Exiting..."; exit 1; }

if (( LINK_LOCAL == 1 )); then

	test -f /proc/net/if_inet6 || { echo "Please enable IPv6 to use link-local mode. Exiting..."; exit 1; }
	command -v ip &> /dev/null || { echo "This mode requires iproute2 to be installed. Try with \"sudo apt install iproute2\". Exiting..." ; exit 1; }
	
	echo "Please input the name of the network interface, eg. eth0:"
	read -r NETWORK_INTERFACE
	
	[[ "$NETWORK_INTERFACE" == "" ]] && { echo "Invalid interface. Exiting..." ; exit 1; }
	
	echo "Please input the maximum number of devices to contact:"
	read -r BATCH_MAX
	
	[[ $BATCH_MAX =~ ^[0-9]+$ ]] || { echo "Invalid amount. Exiting..."; exit 1; }
	
	echo "List MAC address OUI codes separated by a space to only contact devices that match the OUI, otherwise leave blank and press ENTER:"
	read -r OUI_LIST
	
	if [[ $OUI_LIST == "" ]]; then
		OUI_FILTER=0
	else
		OUI_FILTER=1
		if ! [[ $OUI_LIST =~ ^([0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F] )*[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]$ ]]; then
			echo "OUI must be one or more of XX:XX:XX separated by spaces. Exiting..."
			exit 1
		fi
	fi
	
	echo "Beginning autodiscovery..."
	sleep 1
	
	PING6_REPLIES=$(ping6 -L -c 10 ff02::1%"${NETWORK_INTERFACE}") || { echo "Autodiscovery failed, no devices up. Ensure the interface has a valid link-local IPv6 address. Exiting..."; exit 1; }

	PING6_REPLIES=$(echo -e "$PING6_REPLIES" | grep -E "fe80:[a-fA-F0-9:]+" | sed -r "s/^.*(fe80:[^%]+).*\$/\1/g" | sort | uniq)
	
	PING6_REPLIES=($PING6_REPLIES)
	
	if (( OUI_FILTER == 1 )); then
		shopt -s nocasematch
		for i in "${PING6_REPLIES[@]}"
		do
			NDP_ENTRY=$(ip -6 neigh show dev "$NETWORK_INTERFACE" "$i")
			for j in "${OUI_LIST[@]}"
			do
				if [[ "$NDP_ENTRY" =~ $j ]]; then
					TEMP_ARRAY+=( "$i" )
					break
				fi
			done
		done
		PING6_REPLIES=( "${TEMP_ARRAY[@]}" )
		shopt -u nocasematch
	fi
	
	FOUND_ADDRESSES="${#PING6_REPLIES[@]}"
	
	(( FOUND_ADDRESSES < 1 )) && { echo "Autodiscovery failed, no suitable addresses found. Ensure the interface has a valid link-local IPv6 address. Exiting..."; exit 1; }
	(( FOUND_ADDRESSES > BATCH_MAX )) && { echo "The number of discovered addresses is ${FOUND_ADDRESSES}, which exceeds the selected maximum of ${BATCH_MAX}. Exiting..."; exit 1; }
	
	echo "Autodiscovery complete. Found $FOUND_ADDRESSES addresses."
	destinations_list=( "${PING6_REPLIES[@]}" )

elif (( FILE_BASED == 1 )); then
	while IFS=$'\t' read -r -a filedestinations
	do
		destinations_list+=( "${filedestinations[0]}" )
	done < "$1"

else
	[[ $@ == "" ]] && { echo "No destinations listed. Exiting..."; exit 1; }
	destinations_list=( "$@" )
fi

# Generate random name for tmux session
TMUX_NAME="simulterm-tmux-session-$( tr -dc a-z0-9 </dev/urandom | head -c 5 )"

# Generate script files
if (( FILE_BASED == 1 )); then
	> "$SCRIPT_1"
	> "$SCRIPT_2"
	echo "$TMUX_LOCATION" set-option -w -t "$TMUX_NAME" synchronize-panes off >> "$SCRIPT_1"
	echo "$TMUX_LOCATION" set-option -w -t "$TMUX_NAME" synchronize-panes off >> "$SCRIPT_2"
	LINE_NUMBER=0
	while IFS=$'\t' read -r -a userarray
	do
		echo "$TMUX_LOCATION" send-keys -t "$TMUX_NAME"":0.""$LINE_NUMBER" "${userarray[1]}" >> "$SCRIPT_1"
		echo "$TMUX_LOCATION" send-keys -t "$TMUX_NAME"":0.""$LINE_NUMBER" "${userarray[2]}" >> "$SCRIPT_2"
		LINE_NUMBER=$(( LINE_NUMBER + 1 ))
	done < "$1"
	echo "$TMUX_LOCATION" set-option -w -t "$TMUX_NAME" synchronize-panes on >> "$SCRIPT_1"
	echo "$TMUX_LOCATION" set-option -w -t "$TMUX_NAME" synchronize-panes on >> "$SCRIPT_2"
fi

if (( FILE_BASED == 1 )); then
	tmux new-session -d -s "$TMUX_NAME" "${COMMAND//####/"${destinations_list[0]}"}" ';' \
		set-option -w synchronize-panes ';' \
		set-option remain-on-exit on ';' \
		bind-key "$SHORTCUT_1" run-shell './'"$SCRIPT_1" ';' \
		bind-key "$SHORTCUT_2" run-shell './'"$SCRIPT_2"
else
	tmux new-session -d -s "$TMUX_NAME" "${COMMAND//####/"${destinations_list[0]}"}" ';' \
		set-option -w synchronize-panes ';' \
		set-option remain-on-exit on
fi

# All except the first destination
for ssh_entry in "${destinations_list[@]:1}"; do
    tmux split-window -t "$TMUX_NAME" "${COMMAND//####/"$ssh_entry"}"
	# Retile the windows
	tmux select-layout -t "$TMUX_NAME" tiled
done

tmux attach -t "$TMUX_NAME"
