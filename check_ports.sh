#!/bin/sh
# 
# check_ports - Checks if ports are open/closed using nmap
#
# NB: nagios user must have sudoers rights on nmap
# nagios  ALL=NOPASSWD:/usr/bin/nmap
#
# Author: Greg Oriol (greg@gregoriol.net)
#

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

usage () {
	echo "check_ports: Could not parse arguments"
	echo "Usage:"
	echo "check_ports -H <host> [-t <tcp ports>] [-u <udp ports] [-6] -o|-c"
	echo "Parameters:"
	echo "	-H <host>: Host to scan"
	echo "	-t <ports> and/or -u <ports>: TCP and/or UDP ports to scan, comma-separated list, accepts ranges (ex: 21-25,80,139)"
	echo "	-6: IPv6 scanning"
	echo "	-o or -c: Expected result, ports are open or closed"
}

host=
ports=
ipv6=
expected=

while getopts H:t:u:6oc o # s:
do
	case $o in
		H)
			host="$OPTARG"
			;;
		t)
			ports_tcp="$OPTARG"
			;;
		u)
			ports_udp="$OPTARG"
			;;
		6)
			ipv6='-6'
			;;
		o)
			expected='open'
			;;
		c)
			expected='closed'
			;;
		?)
			usage
			exit ${STATE_UNKNOWN}
			;;
	esac
done

scan_types=
if [ -n "$ports_tcp" ]; then
	scan_types="$scan_types -sT"
	ports="${ports}T:$ports_tcp,"
fi
if [ -n "$ports_udp" ]; then
	scan_types="$scan_types -sU"
	ports="${ports}U:$ports_udp,"
fi

# removing last , from the ports string
i=$((${#ports}-1))
ports=${ports:0:$i}

# echo "host: $host"
# echo "scan_types: $scan_types"
# echo "ports: $ports"
# echo "ipv6: $ipv6"
# echo "expected: $expected"

if [ "$host" = '' ] || [ "$ports" = '' ] || [ "$expected" = '' ]; then
	usage
	exit ${STATE_UNKNOWN}
fi

# echo "command: sudo /usr/bin/nmap $scan_types $ipv6 -p $ports $host | grep -E '/(tcp|udp)'"
results=`sudo /usr/bin/nmap $scan_types $ipv6 -p $ports $host | grep -E '/(tcp|udp)'`
# echo "$results"

result_total=`echo "$results" | wc -l`

if [ $result_total -eq 0 ]; then
	echo "UNKNOWN: $result_total ports scanned"
	exit ${STATE_UNKNOWN}
fi

result_open=`echo "$results" | grep -E ' open ' | wc -l`
result_closed=`echo "$results" | grep -E ' closed ' | wc -l`
# echo "open: $result_open"
# echo "closed: $result_closed"
# echo "total: $result_total"

if [ "$expected" = 'open' ]; then
	if [ $result_open -ne $result_total ]; then
		echo "CRITICAL: $result_open ports open / $result_total scanned ($ports)"
		exit ${STATE_CRITICAL}
	else
		echo "OK: $result_open ports open / $result_total scanned ($ports)"
		exit ${STATE_OK}
	fi
elif [ "$expected" = 'closed' ]; then
	if [ $result_closed -ne $result_total ]; then
		echo "CRITICAL: $result_closed ports closed / $result_total scanned ($ports)"
		exit ${STATE_CRITICAL}
	else
		echo "OK: $result_closed ports closed / $result_total scanned ($ports)"
		exit ${STATE_OK}
	fi
fi

echo "UNKNOWN: unexpected"
exit ${STATE_UNKNOWN}
