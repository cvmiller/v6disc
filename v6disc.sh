#!/bin/bash

#
#	Script auto discovers IPv6 hosts on interface, and ping6 them
#
#	by Craig Miller		15 Dec 2015

#	
#	Assumptions:
#		All prefixes are assumed /64
#		Discovers _only_ SLAAC addresses
#
#
#	TODO: print only hosts validated with ping
#		Add nmap option
#		


function usage {
               echo "	$0 - auto discover IPv6 hosts "
	       echo "	e.g. $0 -D -P "
	       echo "	-P  suppress pinging discovered hosts"
	       echo "	-i  use this interface"
	       echo "	-L  show link-local only"
	       echo "	-D  Dual Stack, show IPv4 addresses"
	       echo "	-q  quiet, just print discovered hosts"
	       echo "	"
	       echo " By Craig Miller - Version: $VERSION"
	       exit 1
           }

VERSION=0.90

# initialize some vars
hostlist=""
INTERFACE=""
LINK_LOCAL=0
DUAL_STACK=0
PING=1
DEBUG=0
QUIET=0

# commands needed for this script
ip="ip"
v4="./v4disc.sh"

DEBUG=0

while getopts "?dPqi:LD" options; do
  case $options in
    P ) PING=0
    	let numopts+=1;;
    q ) QUIET=1
    	let numopts+=1;;
    L ) LINK_LOCAL=1
    	let numopts+=1;;
    D ) DUAL_STACK=1
    	let numopts+=1;;
    i ) INTERFACE=$OPTARG
    	let numopts+=2;;
    d ) DEBUG=1
    	let numopts+=1;;
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


#======== Actual work performed by script ============


function log {
	if [ $QUIET -eq 0 ]; then
		# echo string if not quiet
		if [ "$2" == "tab" ]; then
			echo $1 | tr ' ' '\t'
		else
			echo $1
		fi
	fi
}

function 62mac {
	host=$1
	#v6_mac=$(echo $host | cut -d ':' -f 5 )
	v6_mac=$(echo $host | sed -r 's;.*:(\S+);\1;' )
	# return v6_mac value
	echo $v6_mac
}

function router_addr {
	# adjust $host if it is a router
	host=$1	
	if [ "fe80:$host" == "$router_ll" ]; then
		# try route at :1
		host="::1"
		if [ $DEBUG -eq 1 ]; then echo "DEBUG found the router entry"; fi
	fi
	echo $host
}

# if -i <intf> is set, then don't detect interfaces, just go with user input
intf_list=$INTERFACE
if [ "$INTERFACE" == "" ]; then
	# check interface(s) are up
	log "-- Searching for interface(s)"
	intf_list=""
	intf_list=$($ip link | egrep -i '(state up|multicast,up)' | grep -v -i no-carrier | cut -d ":" -f 2 | paste -sd" " -)
	if [ $DEBUG -eq 1 ]; then
		echo "DEBUG: listing interfaces $($ip link | egrep '^[0-9]+:')"
	fi


	if [ "$intf_list" == "" ]; then
		echo "ERROR interface not found, sheeplessly quiting"
		exit 1
	else
		log "Found interface(s): $intf_list"
	fi
fi

# get prefix(s)
for intf in $intf_list
do
	prefix_list=$(ip addr show dev $intf | grep -v temp | grep inet6 | grep -v fe80 | sed -r 's;(inet6|scope|global|dynamic|/64);;g' | tr -d '\n' )
	plist=""
	for prefix in $prefix_list
	do
		p=$(echo $prefix | cut -d ':' -f 1,2,3,4  )
		# fix if double colon prefixes
		p=$(echo $p | sed -r 's;(\w+:):\S+;\1;' )
		plist="$plist $p"
		if [ $DEBUG -eq 1 ]; then
			echo "DEBUG: $plist"
		fi
	done
	prefix_list=$plist
	# exit if no IPv6 prefixes on net
	if [ "$prefix_list" == "" ]; then
		echo "No prefixes found. Exiting."
		if [ $LINK_LOCAL -eq 0 ]; then exit 1; fi
	fi
	log "-- INT:$intf	prefixs:$prefix_list"


	# detect router, won't have a SLAAC address
	router_ll=$($ip -6 route | grep default | grep -v unreachable | cut -d ' ' -f 3 )
	#router_ll=$($ip -6 route | grep default | grep -v unreachable  )
	if [ $DEBUG -eq 1 ]; then echo "Router $router_ll"; fi


	# detect hosts on link
	log "-- Detected hosts on link"
	for intf in $intf_list
	do
		i=$(echo "$intf" | tr -d " ")
		#host_list=$(ping6 -c 2 ff02::1%$i | grep icmp | sort -u  | sed -r 's;.*:(:\S+): .*;\1;' | sort -u)
		host_list=$(ping6 -c 2 ff02::1%$i | grep icmp | sort -u  | sed -r 's;.*:(:\S+): .*;\1;' | sort -u)
		if [ "$host_list" == "" ]; then
			echo "Host detection not working, is this an old OS? Exiting."
			exit 1
		fi
		# Dual stack
		if [ $DUAL_STACK -eq 1 ]; then
			v4_hosts=$($v4  -6 -q -i $intf)
			#v6_hosts=$($ip -6 neigh | grep fe80 | sort -n | cut -d " " -f1,5 | tr ' ' '|' )
			v6_hosts=$host_list
			for h in $v6_hosts
			do
				#unpack mac address
				#v6_mac=$(echo $h | cut -d ':' -f 5 | sed -r 's;(\S)(\S)(\S)(\S);\1\2:\3\4;' )
				v6_mac=$(62mac $h)
				#echo $v6_mac
				# match mac address
				v4_host=$(echo $v4_hosts | tr ' ' '\n' | tr -d ':' | grep -- $v6_mac |  cut -d '|' -f 1)
				v6_host=$(echo $h | cut -d '|' -f 1)
				log "fe80:$v6_host  $v4_host" "tab"
			done
		else
			for h in $host_list
			do
				log "fe80:$h"
			done		
		fi
	done


	# ping the SLAAC addresses
	if [ $PING -eq 1 ]; then
		log "-- Ping6ing discovered hosts"
	else
		log "-- Discovered hosts"
	fi
	
	for prefix in $prefix_list
	do
		for host in $host_list
		do
			if [ $PING -eq 1 ]; then
				# ping6 hosts discovered
				log " "
				log "-- HOST:$prefix$host"
				ping6 -c1 $prefix$(router_addr $host)
			else
				# list hosts found
				if [ $DUAL_STACK -eq 1 ]; then
					#v6_mac=$(echo $host | cut -d ':' -f 5 )
					v6_mac=$(62mac $host)

					v4_host=$(echo $v4_hosts | tr ' ' '\n' | tr -d ':' | grep -- $v6_mac | cut -d '|' -f 1 )
					echo "$prefix$(router_addr $host)	$v4_host"
				else
					echo "$prefix$(router_addr $host)"
				fi
			fi

		done
	done
	
#nd for intf_list
done

#all pau
if [ $QUIET -eq 0 ]; then echo "-- Pau"; fi

