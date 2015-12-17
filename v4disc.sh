#!/bin/bash

#
#	Script auto discovers IPv4 hosts on interface
#
#	by Craig Miller		17 Dec 2015

#	
#	Assumptions:
#		IPv4 subnet starts with .1
#
#
#	TODO: 
#
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

VERSION=0.90

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
	if [ $QUIET -eq 0 ]; then echo $1; fi
}

# get broadcast address
log "-- Detecting broadcast address"
broadcast_addr=$($ip addr show dev $INTERFACE | grep 'inet ' | cut -d " " -f 8 )
b_subnet=$(echo $broadcast_addr | cut -d "." -f 1,2,3)
e_subnet=$(echo $broadcast_addr | cut -d "." -f 4)
log "INTF:$INTERFACE	BRD:$broadcast_addr	"


# fill arp table
log "-- Pinging Subnet Addresses"

# 
# Broadcast ping does not completely fill arp table with entires
# Use loop to initiate pings, IPv4 subnets are small
#
START=1
END=$e_subnet
for (( j=$START; j<$END; j++ ))
do
	#z=$(ping -c 1 10.1.1.$j  2>/dev/null &)
	#if [ $DEBUG -eq 0 ]; then echo $z; fi
	if [ $DEBUG -eq 0 ]; then
		ping -c 1 $b_subnet.$j  1>/dev/null 2>/dev/null &
	else
		ping -c 1 $b_subnet.$j  2>/dev/null &
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

