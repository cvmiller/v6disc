#!/usr/bin/env bash

##################################################################################
#
#  Copyright (C) 2015-2018 Craig Miller
#
#  See the file "LICENSE" for information on usage and redistribution
#  of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#  Distributed under GPLv2 License
#
##################################################################################


#
#	Script auto discovers IPv6 hosts on interface, and ping6 them
#
#	by Craig Miller		15 Dec 2015

#	
#	Assumptions:
#		All prefixes are assumed /64
#		Discovers RFC 4862 SLAAC addresses (MAC-based), DHCPv6 & RFC 7217 (Opaque Addr)
#
#
#	TODO: 
#		deal with multiple default routes on the same interface
#		
#		

#
# Source in IP command emulator (uses ifconfig, hense more portable)
#
OS=""
# check OS type
OS=$(uname -s)
if [ "$OS" == "Darwin" ] || [ "$OS" == "FreeBSD" ]; then
	# MacOS X/BSD compatibility
	source ip_em.sh
fi

function usage {
               echo "	$0 - auto discover IPv6 hosts "
	       echo "	e.g. $0 -D -p "
	       echo "	-p  Ping discovered hosts"
	       echo "	-i  use this interface"
	       echo "	-L  show link-local only"
	       echo "	-D  Dual Stack, show IPv4 addresses"
	       echo "	-N  Scan with nmap -6 -sT"
	       echo "	-n  disable neighbour table detection"
	       echo "	-q  quiet, just print discovered hosts"
	       echo "	"
	       echo " By Craig Miller - Version: $VERSION"
	       exit 1
           }

VERSION=2.3.2

# initialize some vars
INTERFACE=""
LINK_LOCAL=0
DUAL_STACK=0
NMAP=0
PING=0
DEBUG=0
QUIET=0
OUI_CHECK=0
# neighbour table detection, enabled by default
HOST_NEIGHBOURS=1
host_list=""
local_host_list=""
interface_count=0
OUI_FILE=wireshark_oui.gz
SED_OPT=""
PING6_CMD="ping6"
PING6_OPT=""

# is avahi/bonjour available?
AVAHI=0

# commands needed for this script
v4="./v4disc.sh"
nmap="nmap"
nmap_options=" -6 -sT -F "

avahi="avahi-browse"
avahi_resolve="avahi-resolve-host-name"


DEBUG=0

while getopts "?hdpqi:LDNn" options; do
  case $options in
    p ) PING=1
    	(( numopts++));;
    q ) QUIET=1
    	(( numopts++));;
    L ) LINK_LOCAL=1
    	(( numopts++));;
    N ) NMAP=1
    	(( numopts++));;
    D ) DUAL_STACK=1
    	(( numopts++));;
    n ) HOST_NEIGHBOURS=0
    	(( numopts++));;
    i ) INTERFACE=$OPTARG
    	numopts=$(( numopts + 2));;
    d ) DEBUG=1
    	(( numopts++));;
    h ) usage;;
    \? ) usage	# show usage with flag and no value
         exit 1;;
    * ) usage		# show usage with unknown flag
    	 exit 1;;
  esac
done
# remove the options as cli arguments
shift $numopts

# check that there are no arguments left to process
if [ $# -ne 0 ]; then
	usage
	exit 1
fi

# detect if linux system is using ping or ping6
ping6_detect=$(which ping6 2>/dev/null)
if [ $? -ne 0 ]; then
	# Modern Linux which has a unified ping command
	PING6_CMD="ping"
fi



# check for nmap
if (( NMAP == 1 )); then
	check=$(command -v $nmap)
	if (( $? == 1 )); then
		echo "ERROR: nmap not found, disabling nmap option"
		NMAP=0
	else
		# get nnap version, need 6+ to do OS ID
		nmap_version=$($nmap --version | tr -d '\n' | sed -r 's;Nmap version ([0-9]).*;\1;' )
		if (( nmap_version > 5 )); then
			# add OS check if root - OS ID requires root
			root_check=$(id | sed -r 's;uid=([0-9]+).*;\1;')
			if (( "$root_check" == 0 )); then
				nmap_options="$nmap_options -O "
			fi
		fi; #version
		if (( DEBUG == 1 )); then echo "DEBUG: nmap version:$nmap_version options:$nmap_options"; fi
	fi; #which nmap
fi

#check for OUI file - resolve OUI manufactorers (later)
if [ -f "$OUI_FILE" ]; then
	OUI_CHECK=1
fi

# check for zgrep (openwrt does NOT have zgrep, but does have zcat)
zgrep=$(command -v zgrep)

# check version of ping6 (GNU inetutils does not support -I interface option)
int_opt=$($PING6_CMD -h 2>&1 | grep -- '-I')
if [ $? -ne 0 ]; then
	echo "Error: ping6 does not support -I <interface>, please install iputils-ping package"
	echo
	usage
	exit 1
fi


function log {
	#
	#	Common print function which doesn't print when QUIET == 1
	#
	str=$(echo "$*" | tr '\n' ' ' )
	if (( QUIET == 0 )); then
		# echo string if not quiet
		str_begin=$(echo "$str" | cut -d " " -f 1)
		# print headings
		if [ "$str_begin" == "--" ]; then
			# check if output is to terminal
			if [ -t 1 ]; then 
				# use colour for headings
				echo -e "\033[1;34m$str\033[00m" 
			else
				# no colour
				echo -e "$str"
			fi
		else
			# exapnd tabs as needed
			# echo -e "$str" | tr ' ' '\t'
			echo -e "$str"
		fi
	fi
}

# Awk comparison of real numbers - https://stackoverflow.com/questions/8654051/how-can-i-compare-two-floating-point-numbers-in-bash
numCompare() {
   awk -v n1="$1" -v n2="$2" 'BEGIN {printf "%s " (n1<n2?"<":">=") " %s\n", n1, n2}'
}



#check for avahi/bonjour
check=$(command -v $avahi)
	if (( $? == 1 )); then
		log "WARN: avahi utils not found, skipping mDNS check"
		AVAHI=0
	else
		AVAHI=1
		# check version of avahi
		avahi_ver=$($avahi -V | awk '{print $2}' )
		if (( DEBUG == 1 )); then echo "DEBUG:  avahi version: $avahi_ver";fi
	fi

# let user know BSD compatibility is being used
# initialize flags based on $OS
if [ "$OS" == "BSD" ]; then
	# MacOS X/BSD compatibility
	SED_OPT="-E"
	PING6_OPT="-X"
	log "-- using BSD Compatibility"
else
	# use linux flags
	SED_OPT="-r"
	PING6_OPT="-W"
fi



#======== Actual work performed by script ============




function print_cols {
	#
	#	Print values in columnar format, else send to log function
	#
	str=$(echo "$*" | tr '\n' ' ' )
	str_begin=$(echo "$str" | cut -d " " -f 1)
	
	# print headings
	if [ "$str_begin" == "--" ]; then
		log "$1"
	else
		# supports upto 3 columns
		if [ -z "$4" ]; then 
			echo "$str" |  awk '{printf "%-40s %-20s %s\n",$1,$2,$3}'
		else
			# support 4 columns
			echo "$str" |  awk '{printf "%-60s %-40s %-20s %s\n",$1,$2,$3,$4}'
		fi
	fi
}

function 62mac {
	#
	#	Returns MAC address from neighbour cache
	#
	# uses global var: PING6_OPT
	
	host=$1
	local_intf_mac=$2 
	
	# populate neighbour cache with a ping
	if (( LINK_LOCAL == 1 )); then
		z=$($PING6_CMD -I "$intf" $PING6_OPT 1 -c 1 "$host"  2>/dev/null &)
	else
		z=$($PING6_CMD $PING6_OPT 1 -c 1 $host  2>/dev/null &)
	fi
	#this_v6_mac=$(ip -6 neigh | grep -v FAILED | grep "$host"  | cut -d " " -f 5 | sort -u )
	# ip -6 neigh number of fields change (if router), therefore detect MAC directly
	this_v6_mac=$(ip -6 neigh | grep -v FAILED | grep "$host "  | grep -E -o '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | sort -u )
		
#	if (( DEBUG == 1 )); then
#		echo "DEBUG 62mac: $host | $local_intf_mac | $this_v6_mac" > /dev/stderr
#	fi
	
	# return this_v6_mac value
	if [ "$this_v6_mac" != "" ]; then
		echo "$this_v6_mac"
	else
		# is this address a local IPv6 address?		
		local_mac_num=$(ip addr | grep -E "$host|$local_intf_mac" | wc -l)
		if (( local_mac_num == 2 )); then
			echo "$local_intf_mac"
		else
			# didn't find mac
			echo "none"
		fi
	fi
}


function expand_mac () {
	# adds leading zeros to MAC address for OUI match (BSD trims leading zeros)
	new_mac=""
	mac="$1"
	#mac_list=$(echo "$mac" | tr ":" " " | awk '{print $1 " " $2 " " $3 " " }' )
	mac_list=$(echo "$mac" | tr ":" " " )
	for m in $mac_list
	do
		if (( ${#m} == 1 )); then
			m="0$m"
		fi
		new_mac="$new_mac$m:"
	done
	echo "$new_mac"
}


function rtn_oui_man {
	mac=$1
	full_mac=$1
	
	#FIXME: only expand MAC if using BSD
	#expand MAC (BSD suppresses zeros)
	bsd_mac=$(expand_mac "$mac")
	full_mac=$bsd_mac
	
	#if ((DEBUG == 1 )); then echo "DEBUG:FullMAC:$full_mac"; fi
	
	mac_oui=$(echo "$bsd_mac" | tr -d ":" | cut -c '-6' | tr 'abcdef' 'ABCDEF')
	if [ "$mac_oui" == "70B3D5" ]; then
		# IEEE Registered 36 bit OUI address
		mac_oui=$(echo "$bsd_mac" | tr -d ":" | cut -c '-9' | tr 'abcdef' 'ABCDEF')
	fi

	# zgrep is faster than zcat | grep
	if [ "$zgrep" == "" ]; then
		oui=$(zcat "$OUI_FILE" | grep "^$mac_oui" | cut -c '7-')
	else
		oui=$($zgrep "^$mac_oui" "$OUI_FILE" | cut -c '7-')
	fi
	
	# determine if this is a "special" non-24-bit OUI
	ieeeoui=$(echo "$oui" | grep -E -o  '/[0-9][0-9]' | tr -d '\n'| cut -c '1-3'   )
	#if ((DEBUG == 1 )); then echo -n "DEBUG:ieeeoui:$ieeeoui##"; fi

	# ieee OUIs aren't all first 24 bits, there is 28 and 36 bit OUIs as well	
	if [ "$ieeeoui" != "" ]; then
		case $ieeeoui in
		  "/28") OUICUT=7;;
		  "/36") OUICUT=9;;
		  * )  OUICUT=6;;
		esac
		if ((DEBUG == 1 )); then echo "DEBUG:ieeeoui: $ieeeoui|OUICUT:$OUICUT"; fi
		mac_oui=$(echo "$full_mac" | tr -d ":" | cut -c "1-$OUICUT" | tr 'abcdef' 'ABCDEF')
		# look at oui database again
		# zgrep is faster than zcat | grep
		if [ "$zgrep" == "" ]; then
			oui=$(zcat "$OUI_FILE" | grep "^$mac_oui" | grep -E -o '[A-Z][A-Za-z]+')
		else
			oui=$($zgrep "^$mac_oui" "$OUI_FILE" | grep -E -o '[A-Z][A-Za-z]+' )
		fi
		
	fi
	
	#echo "$addr $mac $mac_oui $oui $i"
	if [ "$oui" != "" ]; then
		echo "$oui"
	fi

}


# if -i <intf> is set, then don't detect interfaces, just go with user input
intf_list=$INTERFACE
if [ "$INTERFACE" == "" ]; then
	# check interface(s) are up
	log "-- Searching for interface(s)"
	intf_list=""
	# Get a list of Interfaces which are UP
	intf_list=$(ip link | grep -E -i '(state up|multicast,up|up,)' | grep -E -v 'lo.?:' |grep -v -i no-carrier | cut -d ":" -f 2 | cut -d "@" -f 1 )

	# get count of interfaces - to be used by neighbour cache later
	interface_count=$(echo "$intf_list"  | wc -w)	

	if (( DEBUG == 1 )); then
		echo "DEBUG: listing interfaces $(ip link | grep -E '^[0-9]+:')"
		echo "DEBUG: count interface: $interface_count"
	fi
	
	# if no UP interfaces found, quit
	if [ "$intf_list" == "" ]; then
		echo "ERROR interface not found, sheeplessly quiting"
		exit 1
	else
		log "-- Found interface(s): $intf_list"
	fi
fi


#
#	Repeat foreach interface found
#

for intf in $intf_list
do
	# get list of prefixes on intf, filter out temp addresses
	addr_list=$(ip addr show dev "$intf" | grep -v temp | grep inet6 | grep -v fe80 | awk '{print $2}' | cut -d "/" -f 1 )
	plist=""
	# 
	#	Massage prefix list to only the first 64 bits of each prefix found
	#
	for prefix in $addr_list
	do
		p=$(echo "$prefix" | cut -d ':' -f 1,2,3,4  )
		# fix if double colon prefixes
		if [ "$OS" == "BSD" ]; then
			p=$(echo "$p" | sed -E 's;(\w+:):[!-z]+;\1;' )
		else
			p=$(echo "$p" | sed -r 's;(\w+:):[!-z]+;\1;' )
		fi
		plist="$plist $p"
		if (( DEBUG == 1 )); then
			echo "DEBUG: $plist"
		fi
	done
	# remove duplicate prefixes
	prefix_list=$(echo "$plist" | tr ' ' '\n' | grep -v deprecated | sort -u )
	
	log "-- INT:$intf	prefixs:$prefix_list"
	
	# exit this interface, if no IPv6 prefixes 
	if [ "$prefix_list" == "" ]; then
		log "No prefixes found."
		if (( LINK_LOCAL == 0 )); then 
			log "Continuing to next interface..."
			continue
		else
			# no prefix, use link-local if LINK_LOCAL is set
			prefix_list="fe80::"
		fi
	fi

	# determine MAC of this interface
	intf_mac=$(ip link show dev "$intf" | grep ether | awk '{print $2}')

	# detect hosts on link
	log "-- Detecting hosts on $intf link"

	# trim any spaces on interface name
	i=$(echo "$intf" | tr -d " ")

	# set rtn code to pipefail (in case ping6 fails)
	set -o pipefail
	# clear list
	local_host_list=""
	# ping6 all_nodes address, which will return a list of link-locals on the interface
	#FIXME: try to consolidate the if into a single long pipe

	# always ping the link-locals to fill the neighbour cache
	# May get ping warning "Warning: source address might be selected on device other than: <intf>"
	local_host_list=$($PING6_CMD -c 1  -I "$i" ff02::1 | grep -E 'icmp|seq=' |grep 'fe80' | sort -u  |  awk '{print $4}' | sed $SED_OPT 's;(.*):$;\1;' | sort -u)
	if ((DEBUG == 1 )); then echo "DEBUG:ping6 error:$?"; fi
	
	if (( LINK_LOCAL == 1 )); then 
		local_host_list=$($PING6_CMD  -c 2  -I "$i" ff02::1 | grep -E 'icmp|seq=' |grep 'fe80' | sort -u  |  awk '{print $4}' | sed $SED_OPT 's;(.*)[:,]$;\1;' | sed $SED_OPT 's;(.*)%[a-z0-9]+$;\1;' | sort -u)
	else
		
		#there may be multiple GUAs on an interface
		for a in $addr_list
		do		
			# using BSD?
			if [ "$OS" == "BSD" ]; then
				local_host_list="$local_host_list $($PING6_CMD -c 2  -I "$i" -S "$a" ff02::1%"$i" | grep -E 'icmp|seq=' | sort -u  | awk '{print $4}' | sed $SED_OPT 's;(.*),;\1;' | sort -u)"
			
			else
				local_host_list="$local_host_list $($PING6_CMD -c 2  -I  "$a" ff02::1%"$i" | grep -E 'icmp|seq=' | sort -u  | awk '{print $4}' | sed $SED_OPT 's;(.*):;\1;' | sort -u)"
			fi
		done
	fi
	
	#clean up host list (for duplicates, and muliples on the same line)
	local_host_list=$(echo "$local_host_list" | tr ' ' '\n' | sort -u | tr -d ',')
	
	return_code=$?
	
	
	
	#
	#	Check ping6 output, if empty, something is wrong
	#
	if [ "$local_host_list" == "" ] || [ $return_code -ne 0 ]; then
		echo -e "Oops! Host detection not working.\\n  Is IPv6 enabled on $intf?\\n  ip6tables blocking ping6?"
	else
		# Dual stack
		if (( DUAL_STACK == 1 )); then
			#
			# Detect IPv6 addresses by ipv4 pinging subnet
			#
			v4_hosts=$($v4  -6 -q -i "$intf")
			if (( DEBUG == 1 )); then
				echo "DEBUG: v4_host_list: $v4_hosts"
			fi
			v6_hosts=$local_host_list
			#

			for h in $v6_hosts
			do
				#resolve MAC addresses
				v6_mac=$(62mac "$h" "$intf_mac")
				# match mac address
				#
				#	Dual stack correlates IPv6 and IPv4 addresses by having a common MAC address
				#

				v4_host=$(echo "$v4_hosts" | tr ' ' '\n' | grep -- "$v6_mac" |  cut -d '|' -f 1)
				v4_eui=$(echo "$v4_hosts" | tr ' ' '\n' | grep -- "$v6_mac" |  cut -d '|' -f 3)
				#v6_host=$(echo "$h" | cut -d '|' -f 1)
				# create a tab delimited output
				if (( DEBUG == 1 )); then echo "DEBUG:  $h	 $v6_mac	$v4_eui	 $v4_host" ; fi
				#print_cols "$v6_host  $v4_host $v6_mac"
			done
		fi; #end of dual stack

	fi; #end if host list blank

	# only query link-local addresses if set
	if (( LINK_LOCAL == 1 )); then
		prefix_list="fe80:"
	fi

	# don't display discovered hosts, if there is no prefix
	if [ "$prefix_list" != "" ]; then

		# ping the SLAAC addresses
		if (( PING == 1 )); then
			log "-- Ping6ing discovered hosts"
		fi

		# flag hoststr if ping or nmap
		options_sum=$(( PING + NMAP ))
		if (( options_sum > 0 )); then
			hoststr="-- HOST:"
		else
			hoststr=""
		fi


		for prefix in $prefix_list
		do
			log "-- Discovered hosts for prefix: $prefix on $intf"
			
			#
			# Check IPv6 neighbours, catches hosts that don't respond to "ff02::1" (like Windows) 
			#
			if (( HOST_NEIGHBOURS == 1 )); then 
				#ne_host_list=$(ip -6 neigh | grep -v "FAIL" | awk '{print $1}' | grep -E "^$prefix" )
				ne_host_list=$(ip -6 neigh | awk '{print $1}' | grep  -E "^$prefix" | sort -u )
				#if (( DEBUG == 1 )); then echo "DEBUG: NEhostlist: $ne_host_list"; fi
				#if (( DEBUG == 1 )); then echo "DEBUG: LOCALhostlist: $local_host_list"; fi
				
				# append lists, and remove duplicates
				host_list+=" $ne_host_list"
				host_list=$(echo "$host_list" | sort -u )
			else
				host_list=$local_host_list
			fi
			
			 
			if (( DEBUG == 1 )); then echo "DEBUG: hostlist: $host_list"; fi
			
			#
			# Resolve MAC addresses in host_list
			#
			for host in $host_list
			do	
				# print spacer
				if (( options_sum != 0 )); then
					log " "
				fi	
				# is host in this prefix?
				prefix_match=$(echo "$host" | grep -i "$prefix" )
				if [ "$prefix_match" != "" ]; then
										
					# list hosts found
					if (( DUAL_STACK == 1 )); then
						# pull MAC from IPv6 address
						v6_mac=$(62mac "$host" "$intf_mac")
						#echo "v6MAC: $v6_mac"
						# compare with IPv4 list (which includes MACs)
						#v4_host=$(echo "$v4_hosts" | tr ' ' '\n' | tr -d ':' | grep -- "$v6_mac" | cut -d '|' -f 1 )
						#echo "--->$v4_hosts"
						v4_host=$(echo "$v4_hosts" | tr ' ' '\n'  | grep -- "$v6_mac" | cut -d '|' -f 1 )
						print_cols "$hoststr $host	$v4_host"
					elif (( OUI_CHECK == 1 )) && (( QUIET == 0 )); then
						# pull MAC from IPv6 address
						v6_mac=$(62mac "$host" "$intf_mac")
						if [ "$v6_mac" != "none" ]; then
							# resolve OUI manufacture
							v6_oui=$(rtn_oui_man "$v6_mac" )
							# fix column when mac is not found
							if [ "$v6_mac" == "INCOMPLETE" ]; then v6_mac="EXPIRED"; fi

							print_cols "$hoststr $host $v6_mac $v6_oui"
						else
							# resolve OUI manufacture
							v6_oui=$(rtn_oui_man "$intf_mac" )
							print_cols "$hoststr $host $intf_mac $v6_oui"
						fi
					else
						# just show the discovered host
						print_cols "$hoststr $host"
						#echo "$hostaddr"
					fi

					if (( PING == 1 )); then
						# ping6 hosts discovered
						$PING6_CMD $PING6_OPT 1 -c1  "$host"
					fi
					if (( NMAP == 1 )); then
						# scanning hosts discovered with nmap
						if (( LINK_LOCAL == 0 )); then 
							$nmap "$nmap_options" "$host"
						else
							$nmap "$nmap_options" "$host%$intf"
						fi
					fi
				fi; #prefix_match
			done; #for host
		done; #for prefix
		#
		# Do avahi/bonjour mDNS discovery
		#
		if (( AVAHI == 1 )); then
			log "-- Displaying avahi discovered hosts"
			# compare real numbers using awk
			if awk "BEGIN {exit !($avahi_ver < 0.8)}"; then			
				avahi_list=$($avahi -at 2>/dev/null | grep IPv6 | awk '{print $4}'  | grep -v 'Fail' | sort -u )
			else
				avahi_list=$($avahi  -atrp  2>/dev/null | grep IPv6 | cut -d ";" -f 7  | sort -u )
			fi
			if (( DEBUG == 1 )); then echo "DEBUG: avahi_list: $avahi_list"; fi
			# setup filter for only Link Local, if LINK_LOCAL is set
			if (( LINK_LOCAL == 0 )); then 
				ll_filter="."
			else
				ll_filter="fe80::"
			fi
			
			# show avahi discovered list
			for ahost in $avahi_list
			do
				avahi_host=$($avahi_resolve -6n "$ahost" 2>/dev/null)
				if [ "$avahi_host" != "" ]; then
					if (( DEBUG == 1 )); then echo "DEBUG: avahi_host: $avahi_host"; fi
					if (( QUIET == 0 )); then
						# format address then hostname
						echo "$avahi_host" | grep -- $ll_filter | awk '{printf "%-40s %s\n",$2,$1}'
					else
						echo "$avahi_host" | grep -- $ll_filter | awk '{print $2}'
					fi
				fi ; # blank avahi_host
			done ; #for ahost
		fi
	fi; # if prefix_list not empty
#nd for intf_list
done

#all pau
log "-- Pau"

