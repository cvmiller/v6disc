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
#		only ipv4 cidr /21, /22, /23, /24, 25 supported
#
#
#	Wireshark OUT database - https://code.wireshark.org/review/gitweb?p=wireshark.git;a=blob_plain;f=manuf
#


function usage {
               echo "	$0 - auto discover IPv4 hosts "
	       echo "	e.g. $0  <-i interface>"
	       echo "	-i  use this interface"
	       echo "	-q  quiet, just print discovered hosts"
	       echo "	"
	       echo " By Craig Miller - Version: $VERSION"
	       exit 1
           }

VERSION=0.99.3

#
# Sourc in IP command emulator (uses ifconfig, hense more portable)
#
OS=""
# check OS type
OS=$(uname -s)
if [ $OS == "Darwin" ]; then
	# MacOS X compatibility
	source ip_em.sh
fi



# initialize some vars
hostlist=""
INTERFACE=""
LINK_LOCAL=0
PING=1
DEBUG=0
QUIET=0
V6=0
HTML=0

#OUI_FILE=oui.gz
OUI_FILE=wireshark_oui.gz

# commands needed for this script
ip="ip"

DEBUG=0

while getopts "?dPqi:L6H" options; do
  case $options in
    P ) PING=0
    	let numopts+=1;;
    q ) QUIET=1
    	let numopts+=1;;
    L ) LINK_LOCAL=1
    	let numopts+=1;;
    H ) HTML=1
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


# check for zgrep (openwrt does NOT have zgrep, but does have zcat)
zgrep=$(which zgrep)


function log {
	# echo string if not quiet
	if (( $QUIET == 0 )); then echo $1; fi
}

#from Stack Overflow - https://stackoverflow.com/questions/13908360/extracting-netmask-from-ifconfig-output-and-printing-it-in-cidr-format
# Modified by Craig Miller for BSD

function bitCountForMask {
    local -i count=0
	# strip 0x from mask
    local mask="${1##0x}"
    local digit

    while [ "$mask" != "" ]; do
        digit="${mask:0:1}"
        mask="${mask:1}"
        case "$digit" in
            [fF]) count=count+4 ;;
            [eE]) count=count+3 ;;
            [cC]) count=count+2 ;;
            8) count=count+1 ;;
            0) ;;
            *)
                echo 1>&2 "error: illegal digit $digit in netmask"
                return 1
                ;;
        esac
    done
	# return mask in CIDR notation
    echo $count
}


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


# get broadcast address
log "-- Detecting subnet address space"
this_addr=$($ip addr show dev $INTERFACE | grep 'inet ' | cut -d " " -f 6 | cut -d "/" -f 1 )
root_subnet=$(echo $this_addr | cut -d "." -f 1,2)
subnet_4=$(echo $this_addr | cut -d "." -f 4)
subnet_3=$(echo $this_addr | cut -d "." -f 3)

#this_subnet=$(ip -4 route | grep "$root_subnet" | cut -d "/" -f 1)


if [ "$OS" != "Linux" ]; then
	# OS is BSD
	net_mask=$($ip addr show dev $INTERFACE | grep 'inet ' | awk '{print $4}' | sort -u)
	net_mask=$(bitCountForMask $net_mask)
else
	net_mask=$($ip addr show dev $INTERFACE | grep 'inet ' | cut -d " " -f 6 | cut -d "/" -f 2 | sort -u)
fi
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
	22) 
		let subnet_3=0
		START=1
		# make end max-2 or it will scan begining of next subnet
		END=1022
		;;
	21) 
		let subnet_3=0
		START=1
		# make end max-2 or it will scan begining of next subnet
		END=2046
		;;
	20) 
		let subnet_3=0
		START=1
		# make end max-2 or it will scan begining of next subnet
		END=4094
		;;
	19) 
		let subnet_3=0
		START=1
		# make end max-2 or it will scan begining of next subnet
		END=8048
		echo "Whoa, a /19, this could take a while" | egrep --color ".*"
		;;
	*) # unsupported IPv4 subnet size
		if [ $QUIET -eq 0 ]; then echo "WARN: Unsupported subnet netmask: $net_mask"; fi
		exit 1
		;;
esac

if (( $DEBUG == 1 )); then echo "DEBUG: start=$START  end=$END"; fi


# fill arp table
log "-- Pinging Subnet Addresses"


#exit 1

# 
# Broadcast ping does not completely fill arp table with entires
# Use loop to initiate pings, IPv4 subnets are small
#
i=$subnet_3
j=$START
for (( k=$START; k<$END; k++ ))
do
	# cover /23 
	if (( $j >= 255 )); then 
		let i=i+1
		#let j=k-255
		let j=0
	else
		let j=j+1
	fi
	
	#z=$(ping -c 1 10.1.1.$k  2>/dev/null &)
	if (( $DEBUG == 0 )); then
		ping -c 1 $root_subnet.$i.$j  1>/dev/null 2>/dev/null &
	else
		echo $root_subnet.$i.$j
		#ping -c 1 $root_subnet.$i.$j  2>/dev/null &
	fi

done



# wait for pings to finish
sleep 1


# get own IP address and MAC, since it won't be in the ARP table
my_addr=$($ip addr show dev $INTERFACE | grep 'inet ' | cut -d " " -f 6  | cut -d "/" -f 1)
my_mac=$($ip addr show dev $INTERFACE | grep 'link/ether' | cut -d " " -f 6 )

# show arp table
log "-- ARP table"
arp_table=$($ip -4 neigh | egrep -i -v '(INCOMPLETE|FAILED)' | cut -d " " -f 1,5 | sort -n)
# add my_addr to arp_table
arp_table="$arp_table"$'\n'"$my_addr $my_mac"

oui_table=""
# resolve OUI manufactorers
if [ -f "$OUI_FILE" ]; then
	i=0
	m=0
	for f in $arp_table
	do
		m=$(expr $i % 2 )
		if [ $m -eq 0 ]; then
			addr=$f
		else
			mac=$f
			#expand MAC (BSD suppresses zeros)
			bsd_mac=$(expand_quibble $mac)
			
			mac_oui=$(echo $bsd_mac | tr -d ":" | cut -c '-6' | tr 'abcdef' 'ABCDEF')
			if [ "$mac_oui" == "70B3D5" ]; then
				# IEEE Registered 36 bit OUI address
				mac_oui=$(echo $bsd_mac | tr -d ":" | cut -c '-9' | tr 'abcdef' 'ABCDEF')
			fi
			if [ $zgrep == "" ]; then
				oui=$(zcat "$OUI_FILE" | grep "^$mac_oui" | cut -c '7-')
			else
				oui=$($zgrep "^$mac_oui" "$OUI_FILE" | cut -c '7-')
			fi
			
			
			#echo "$addr $mac $mac_oui $oui $i"
			if [ "$oui_table" == "" ]; then
				oui_table="$addr $mac $oui"
			else
				oui_table="$oui_table"$'\n'"$addr $mac $oui"
			fi
		fi
		let "i++"
	done
	#echo "$oui_table" | awk '{printf "%-20s %-20s %s\n",$1,$2,$3}' 
	arp_table=$oui_table
fi

if [ $V6 -eq 0 ] && [ $HTML -eq 0 ]; then
	# normal text output
	echo "$arp_table" | awk '{printf "%-20s %-20s %s\n",$1,$2,$3}' 
elif [ $V6 -eq 1 ]; then
	# feed output to v6disc
	echo "$arp_table" | tr ' ' '|' 
elif [ $HTML -eq 1 ]; then
	echo "<table>"
	echo "$arp_table" | awk '{printf "<tr><td><a href=\"http://%s/\">%s</a></td>	<td>%s</td>	<td>%s</td></tr>\n",$1,$1,$2,$3}' 
	echo "</table>"
fi


#all pau
if [ $QUIET -eq 0 ]; then echo "-- Pau"; fi

