#!/bin/bash

##################################################################################
#
#  Copyright (C) 2015-2016 Craig Miller
#
#  See the file "LICENSE" for information on usage and redistribution
#  of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#  Distributed under GPLv2 License
#
##################################################################################

#
#	Script auto discovers IPv4 hosts on interface
#
#	by Craig Miller		17 Dec 2015

#	
#	Assumptions:
#		Called by v6disc.sh
#
#
#	Limitations: 
#		only ipv4 cidr /23, /24, 25 supported
#



function usage {
               echo "	$0 - auto discover IPv6 hosts "
	       echo "	e.g. $0  <-i interface>"
	       echo "	-i  use this interface"
	       echo "	-q  quiet, just print discovered hosts"
	       echo "	"
	       echo " By Craig Miller - Version: $VERSION"
	       exit 1
           }

VERSION=0.93

# initialize some vars
hostlist=""
INTERFACE=""
LINK_LOCAL=0
PING=1
DEBUG=0
QUIET=0
V6=0

# commands needed for this script
ip="ip"

DEBUG=0

while getopts "?dPqi:L6" options; do
  case $options in
    P ) PING=0
    	let numopts+=1;;
    q ) QUIET=1
    	let numopts+=1;;
    L ) LINK_LOCAL=1
    	let numopts+=1;;
    6 ) V6=1
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

if [ "$INTERFACE" == "" ]; then
	usage
	exit 1
fi

function log {
	# echo string if not quiet
	if (( $QUIET == 0 )); then echo $1; fi
}

# get broadcast address
log "-- Detecting subnet address space"
this_addr=$($ip addr show dev $INTERFACE | grep 'inet ' | cut -d " " -f 6 | cut -d "/" -f 1 )
root_subnet=$(echo $this_addr | cut -d "." -f 1,2)
subnet_4=$(echo $this_addr | cut -d "." -f 4)
subnet_3=$(echo $this_addr | cut -d "." -f 3)

net_mask=$($ip addr show dev $INTERFACE | grep 'inet ' | cut -d " " -f 6 | cut -d "/" -f 2 )
log "INTF:$INTERFACE	ADDR:$this_addr	CIDR=$net_mask"

#default start
start_subnet=1

case $net_mask in
	24) start_subnet=1
		START=1
		END=255
		;;
	25) START=1
		END=127
		if (( $subnet_4 > 128 )); then 
			start_subnet=129
			START=129
			END=255
		fi
		;;
	23) 
		if (( (($subnet_3/2))==1 )); then
			let subnet_3-=1
		fi
		START=1
		END=511
		;;
	*) # unsupported IPv4 subnet size
		if [ $QUIET -eq 0 ]; then echo "WARN: Unsupported subnet netmask: $net_mask"; fi
		exit 1
		;;
esac

if (( $DEBUG == 1 )); then echo "DEBUG: start=$START  end=$END"; fi


# fill arp table
log "-- Pinging Subnet Addresses"

# 
# Broadcast ping does not completely fill arp table with entires
# Use loop to initiate pings, IPv4 subnets are small
#
i=$subnet_3
j=$START
for (( k=$START; k<$END; k++ ))
do
	# cover /23 
	if (( $k > 255 )); then 
		let i=subnet_3+1
		let j=k-255
	else
		let j=$k
	fi
	
	#z=$(ping -c 1 10.1.1.$k  2>/dev/null &)
	if (( $DEBUG == 0 )); then
		ping -c 1 $root_subnet.$i.$j  1>/dev/null 2>/dev/null &
	else
		#echo $root_subnet.$i.$j
		ping -c 1 $root_subnet.$i.$j  2>/dev/null &
	fi

done



# wait for pings to finish
sleep 1


# get own IP address and MAC, since it won't be in the ARP table
my_addr=$($ip addr show dev $INTERFACE | grep 'inet ' | cut -d " " -f 6  | cut -d "/" -f 1)
my_mac=$($ip addr show dev $INTERFACE | grep 'link/ether' | cut -d " " -f 6 )

# show arp table
log "-- ARP table"
arp_table=$($ip -4 neigh | egrep -v '(INCOMPLETE|FAILED)' | cut -d " " -f 1,5 | sort -n)
# add my_addr to arp_table
arp_table="$arp_table"$'\n'"$my_addr $my_mac"
if [ $V6 -eq 0 ]; then
	echo "$arp_table"
else
	echo "$arp_table" | tr ' ' '|' 
fi


#all pau
if [ $QUIET -eq 0 ]; then echo "-- Pau"; fi

