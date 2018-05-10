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
VERSION=0.94

# check OS type
OS=$(uname -s)
if [ $OS == "Darwin" ] || [ $OS == "FreeBSD" ]; then
	OS="BSD"
fi


#
#	Expands IPv6 quibble to 4 digits with leading zeros e.g. db8 -> 0db8
#
#	Returns string with expanded quibble (modified for MAC addresses)

function expand_quibble() {
	addr=$1
	# create array of quibbles
	addr_array=(${addr//:/ })
	addr_array_len=${#addr_array[@]}
	# step thru quibbles
	for ((i=0; i< $addr_array_len ; i++ ))
	do
		quibble=${addr_array[$i]}
		quibble_len=${#quibble}
		case $quibble_len in
			1) quibble="0$quibble";;
			2) quibble="$quibble";;
			3) quibble="$quibble";;
		esac
		addr_array[$i]=$quibble	
	done
	# reconstruct addr from quibbles
	return_str=${addr_array[*]}
	return_str="${return_str// /:}"
	echo $return_str
}

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
			result=$(ifconfig $dev | egrep "$inet_opt|ether" );;
		"link" )
			result=$(ifconfig $dev | egrep 'flags|ether'| tr '\n' '|' | sed  's/1500|//g' | tr '|' '\n' | awk '{print "1: "$1 " " $2 "\n" $4 " " $5 " " $6 " " $7}' );;
		"neigh" )
			if [ "$OS" != "Linux" ]; then
				# OS is BSD
				if [ "$neigh_cmd" == "ndp" ]; then 
					result=''
					result_list=$($neigh_cmd -an | awk '{print $1 "|dev|" $3 "|lladdr|" $2}')
					for line in $result_list 
					do
						# expand last field (MAC addr)
						bsd_mac=$(echo $line | cut -f 5 -d '|' )
						bsd_mac=$(expand_quibble $bsd_mac)
						# collect first part of line
						result_line=$(echo $line | cut -f 1-4 -d '|' )
						# append last field back on
						result_line="$result_line|$bsd_mac"
						result="$result@$result_line"
					done
					# fix the formatting of result
					#result=$(echo $result | tr ' ' '@')
					result=$(echo $result | tr '|' ' ')
					result=$(echo $result | tr '@' '\n')
					
				fi
				if [ "$neigh_cmd" == "arp" ]; then 
					result=''
					result_list=$($neigh_cmd -an | tr -d '()' | awk '{print $2 "|dev|" $6 "|lladdr|" $4}')
					for line in $result_list 
					do
						# expand last field (MAC addr)
						bsd_mac=$(echo $line | cut -f 5 -d '|' )
						bsd_mac=$(expand_quibble $bsd_mac)
						# collect first part of line
						result_line=$(echo $line | cut -f 1-4 -d '|' )
						# append last field back on
						result_line="$result_line|$bsd_mac"
						result="$result@$result_line"
					done
					#result=$(echo $result | tr ' ' '@')
					result=$(echo $result | tr '|' ' ')
					result=$(echo $result | tr '@' '\n')
					
				fi
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
	# get self test interface 
	INTF=$(netstat -i | tail -1 |  awk '{print $1}')
	if [ -n "$2" ]; then
		INTF=$2
	fi
	if [ "$1" == "test" ]; then

		echo "Running self test"
		echo "---- ip addr"

		ip addr
		echo "---- ip link"
		ip link
		echo "---- ip link show dev $INTF | grep ether | awk '{print $2}'"
		ip link show dev $INTF | grep ether | awk '{print $2}'
		echo "---- ip link long"
		ip link | egrep -i '(state up|multicast,up|up,)' | grep -v -i no-carrier | cut -d ":" -f 2 | cut -d "@" -f 1
		
		
		echo "---- ip addr show dev $INTF"
		ip addr show dev $INTF
		echo "---- ip -6 addr show dev $INTF"
		ip -6 addr show dev $INTF
		echo "---- ip -4 addr show dev $INTF"
		ip -4 addr show dev $INTF
		echo "---- ip really long"
		ip addr show dev $INTF | grep -v temp | grep inet6 | grep -v fe80 | awk '{print $2}' | cut -d "/" -f 1 
		echo "---- ip -6 neigh"
		ip -6 neigh
		echo "---- ip -4 neigh"
		ip -4 neigh
		echo "---- ip -4 route"
		ip -4 route

		echo "---- ip -6 neigh | grep -v FAILED | grep "$host"  | cut -d " " -f 5 "
		ip -6 neigh | grep -v FAILED  | cut -d " " -f 5 


	fi
fi




