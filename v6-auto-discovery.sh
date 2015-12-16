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
#		
#


function usage {
               echo "	$0 - auto discover IPv6 hosts "
	       echo "	e.g. $0 <-P> <-i interface>"
	       echo "	-P  suppress pinging discovered hosts"
	       echo "	-i  use this interface"
	       echo "	-L  show link-local only"
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
PING=1
DEBUG=0
QUIET=0

# commands needed for this script
ip="ip"

DEBUG=0

while getopts "?dPqi:L" options; do
  case $options in
    P ) PING=0
    	let numopts+=1;;
    q ) QUIET=1
    	let numopts+=1;;
    L ) LINK_LOCAL=1
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

# if -i <intf> is set, then don't detect interfaces, just go with user input
intf_list=$INTERFACE
if [ "$INTERFACE" == "" ]; then
	# check interface(s) are up
	if [ $QUIET -eq 0 ]; then echo "-- Searching for interface(s)"; fi
	intf_list=""
	intf_list=$($ip link | egrep -i '(state up|multicast,up)' | grep -v -i no-carrier | cut -d ":" -f 2 | paste -sd" " -)
	if [ $DEBUG -eq 1 ]; then
		echo "DEBUG: listing interfaces $($ip link | egrep '^[0-9]+:')"
	fi


	if [ "$intf_list" == "" ]; then
		echo "ERROR interface not found, sheeplessly quiting"
		exit 1
	else
		if [ $QUIET -eq 0 ]; then echo "Found interface(s): $intf_list"; fi
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
	if [ $QUIET -eq 0 ]; then echo "-- INT:$intf	prefixs:$prefix_list"; fi


	# detect router, won't have a SLAAC address
	router_ll=$($ip -6 route | grep default | grep -v unreachable | cut -d ' ' -f 3 )
	#router_ll=$($ip -6 route | grep default | grep -v unreachable  )
	if [ $DEBUG -eq 1 ]; then echo "Router $router_ll"; fi


	# detect hosts on link
	if [ $QUIET -eq 0 ]; then echo "-- Detected hosts on link"; fi
	for intf in $intf_list
	do
		i=$(echo "$intf" | tr -d " ")
		host_list=$(ping6 -c 2 ff02::1%$i | grep icmp | sort -u  | sed -r 's;.*:(:\S+): .*;\1;' | sort -u)
		if [ "$host_list" == "" ]; then
			echo "Host detection not working, is this an old OS? Exiting."
			exit 1
		fi
		for h in $host_list
		do
			if [ $QUIET -eq 0 ]; then echo "fe80:$h"; fi
		done
	done

	# ping the SLAAC addresses
	if [ $QUIET -eq 0 ]; then
		if [ $PING -eq 1 ]; then
			echo "-- Pinging discovered hosts"
		else
			echo "-- Discovered hosts"
		fi
	fi
	for prefix in $prefix_list
	do
		for host in $host_list
		do
			# adjust $host if it is a router
			if [ "fe80:$host" == "$router_ll" ]; then
				# try route at :1
				host="::1"
				if [ $DEBUG -eq 1 ]; then echo "DEBUG found the router entry"; fi
			fi
			if [ $PING -eq 1 ]; then
				# ping6 hosts discovered
				if [ $QUIET -eq 0 ]; then
					echo " "
					echo "-- HOST:$prefix$host"
				fi
				ping6 -c1 $prefix$host
			else
				# list hosts found
				echo "$prefix$host"
			fi

		done
	done
	
#nd for intf_list
done

#all pau
if [ $QUIET -eq 0 ]; then echo "-- Pau"; fi

