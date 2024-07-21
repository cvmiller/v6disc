#!/usr/bin/env bash

##################################################################################
#
#  Copyright (C) 2018 Craig Miller
#
#  See the file "LICENSE" for information on usage and redistribution
#  of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#  Distributed under GPLv2 License
#
##################################################################################


#
#	Script approsimate the functionality of the linux IP command 
#		Designed to be more portable (e.g. BSD, MacOS X) than linux IP command
#
#	by Craig Miller		5 May 2018

#	
#	Assumptions:
#		All prefixes are assumed /64
#
#
#	TODO: 
#		
#		
#
# Moved self test netstat command within the self test block - 20 July 2024
		
VERSION=0.98

# check OS type
OS=$(uname -s)
if [ "$OS" == "Darwin" ] || [ "$OS" == "FreeBSD" ]; then
	OS="BSD"
fi

#
# IP command emulator function - returns status similar to the linux IP command
#
function ip {

	# set up default warning message - terminal colours - http://wiki.bash-hackers.org/scripting/terminalcodes
	result=$(echo -e "\033[1;91m WARNING: function not implemented: ip $* \033[00m")
	# set up -6 or -4 option
	inet_opt="inet"
	if (( "$1" == "-6")) || (( "$1" == "-4" )); then 
		if (( $1 == "-6" )); then
			inet_opt="inet6"
			neigh_cmd="ndp"
		else
			inet_opt="inet "
			neigh_cmd="arp"
		fi
		# move arguemnts down 1
		shift
	fi

	# Parse dev from 'ip addr show dev eth0'
	if [ -n "$2" ]; then 
		# parse dev
		dev=""
		if (( "$2" == "show" )); then
			if [ -n "$4" ]; then
				dev="$4"
			fi
		fi
	fi
	
	case $1 in
		"addr" )
			result=$(ifconfig $dev | grep -E "$inet_opt|ether" );;
		"link" )
			result=$(ifconfig $dev | grep -E 'flags|ether'| tr '\n' '|' | sed  's/1500|//g' |sed 's/0 mtu//g' | tr '|' '\n' | awk '{print "1: "$1 " " $2 "\n" $4 " " $5 " " $6 " " $7}' );;
		"neigh" )
			if [ "$OS" != "Linux" ]; then
				# OS is BSD
				if [ "$neigh_cmd" == "ndp" ]; then 
					result=$($neigh_cmd -an | awk '{print $1 " dev " $3 " lladdr " $2}'); fi
				if [ "$neigh_cmd" == "arp" ]; then 
					result=$($neigh_cmd -an | tr -d '()' | awk '{print $2 " dev " $6 " lladdr " $4}'); fi
			else
				# can't get Linux neigh table without IP command 
				if [ "$neigh_cmd" == "ndp" ]; then result=$(/usr/bin/env ip -6 neigh); fi
				if [ "$neigh_cmd" == "arp" ]; then result=$(/usr/bin/env ip -4 neigh); fi
			fi
			;;
			
	esac
	
	echo "$result"
}

# self test section
if [ -n "$1" ]; then

	if [ "$1" == "test" ]; then
		if [ "$2" != "" ]; then
			INTF="$2"
		fi

		# get self test interface 
		INTF=$(netstat -i | tail -1 |  awk '{print $1}')
		
		echo "Running self test"
		echo "---- ip addr"

		ip addr
		echo "---- ip link"
		ip link
		echo "---- ip link show dev $INTF | grep ether | awk '{print $2}'"
		ip link show dev "$INTF" | grep ether | awk '{print $2}'
		
		
		echo "---- ip link long (show interfaces)"
		ip link | grep -E -i '(state up|multicast,up|up,)' | grep -v -i no-carrier | cut -d ":" -f 2 | cut -d "@" -f 1
		
		
		echo "---- ip addr show dev $INTF"
		ip addr show dev "$INTF"
		echo "---- ip -6 addr show dev $INTF"
		ip -6 addr show dev "$INTF"
		echo "---- ip -4 addr show dev $INTF"
		ip -4 addr show dev "$INTF"
		echo "---- ip really long (show GUAs)"
		ip addr show dev "$INTF" | grep -v temp | grep inet6 | grep -v fe80 | awk '{print $2}' | cut -d "/" -f 1 
		echo "---- ip -6 neigh"
		ip -6 neigh
		echo "---- ip -4 neigh"
		ip -4 neigh
		echo "---- ip -4 route"
		ip -4 route

		echo "---- ip addr show dev $INTF | grep 'inet ' | awk '{print $4}' | sort -u (show netmask)"
		ip addr show dev $INTF | grep 'inet ' | awk '{print $4}' | sort -u
	fi
fi




