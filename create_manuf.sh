#!/bin/bash
#
#	wireshark manuf file creator for use by v6disc.sh by Craig Miller
#	5 June 2025
#


#
# Pulls IEEE OUT files directly from IEEE
#	Parses OUI and Manufacturer, reduces string size, and compresses
#


VERSION="0.90"


TMPPATH="/tmp/"
DEBUG=0

# IEEE URLs to OUI files
ieee_url[1]="https://standards-oui.ieee.org/oui/oui.csv"
ieee_url[2]="https://standards-oui.ieee.org/cid/cid.csv"
ieee_url[3]="https://standards-oui.ieee.org/iab/iab.csv"
ieee_url[4]="https://standards-oui.ieee.org/oui28/mam.csv"
ieee_url[5]="https://standards-oui.ieee.org/oui36/oui36.csv"


OUTPUT_FILE=wireshark_oui


usage() {
           echo "	$0 - Create manuf file "
	       echo "	e.g. $0 -h "
	       echo "	-d  debug"
	       #echo "	-n <pod number>  Override Pod number in pod.conf"
	       echo "	"
	       echo " By Craig Miller - Version: $VERSION"
	       exit 1
           }

# Parse CLI Options
while getopts "?hdt" opt; do
    case "$opt" in
        d)  DEBUG=1
            ;;
    	z)  PODNO=$((OPTARG))
		    PODNAME="pod$PODNO"
            ;;
        t)  TEST=1
            ;;
        h)  usage
            ;;

        *)
            echo  "Invalid command option " 
			usage
            ;;
    esac
done
shift "$((OPTIND -1))"


#check for curl
which /usr/bin/curl
result=$?

if [ $result -ne 0 ]; then
	echo "curl not found"
	usage
fi


# get 24 bit OUIs
i=1
for i in `seq 1 3`
do
	echo "Getting file: $i"
	curl ${ieee_url[$i]} | cut -d ',' -f 2,3 | tr -d ' ' |  tr -d ',' | tr -d '"' | cut -c  '-14' > $TMPPATH/ieee$i
done

# get 28 bit OUI e.g. '0CEFAF700000/28Syntrans'
i=4
echo "Getting file: $i"
curl ${ieee_url[$i]} | cut -d ',' -f 2,3 | sed -r 's;([0-9A-F]{7});\100000/28;' | tr -d ' ' |  tr -d ',' | tr -d '"' | cut -c  '-23' > $TMPPATH/ieee$i

# get 34 bit OUI e.g. '0CEFAF700000/28Syntrans'
i=5
echo "Getting file: $i"
curl ${ieee_url[$i]} | cut -d ',' -f 2,3 | sed -r 's;([0-9A-F]{9});\1000/36;' | tr -d ' ' |  tr -d ',' | tr -d '"' | cut -c  '-23' > $TMPPATH/ieee$i

# Cat all the files together & compress
rm $TMPPATH/$OUTPUT_FILE 2> /dev/null
i=1
for i in `seq 1 5`
do
	cat $TMPPATH/ieee$i >> $TMPPATH/$OUTPUT_FILE
done

echo "Created file is: $TMPPATH/${OUTPUT_FILE}.gz"
gzip -f $TMPPATH/$OUTPUT_FILE


echo "Pau"


