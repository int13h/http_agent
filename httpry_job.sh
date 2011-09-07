#!/usr/local/bin/bash

# network interface
interface="bce1"

# httpry location
httpry="/usr/local/bin/httpry" 

# httpry flags
flags="-f timestamp,source-ip,source-port,dest-ip,dest-port,method,host,request-uri,referer,user-agent -i $interface -d"

# httpry_agent base location
httpry_agent="/usr/local/etc/nsm/httpry_agent"

# base log directory
root="/nsm/httpry"

## STOP EDITS ##

# directory structure will be: $root/year/year-month/year-month-day.txt
year=`date "+%Y"`
month=`date "+%m"`
day=`date "+%d"`

# Check dirs
if [ ! -e $root/$year ]; then
    mkdir $root/$year
fi

if [ ! -e $root/$year/$year-$month ]; then
    mkdir $root/$year/$year-$month
fi;

# httpry process
h=`ps auxwww | grep "httpry $flags" | grep -v grep | awk '{print $2}'`

# httpry_agent process
a=`ps auxww | grep "httpry_agent" | grep -v grep | awk '{print $2}'`

# httpry_agent tail process
t=`ps auxww | grep "tail -n 0 -f $root" | grep -v grep | awk '{print $2}'`

pids="$h $a $t"

if [ -n "$pids" ]; then

    $httpry $flags -o $root/$year/$year-$month/$year-$month-$day.txt
    $httpry_agent/httpry_agent.tcl \
    -c $httpry_agent/httpry_agent.conf \
    -e $httpry_agent/httpry_agent.exclude \
    -f $root/$year/$year-$month/$year-$month-$day.txt \
    -D

    for x in $pids; do
        /bin/kill $x
    done; 

else

    $httpry $flags -o $root/$year/$year-$month/$year-$month-$day.txt
    $httpry_agent/httpry_agent.tcl \
    -c $httpry_agent/httpry_agent.conf \
    -e $httpry_agent/httpry_agent.exclude \
    -f $root/$year/$year-$month/$year-$month-$day.txt \
    -D

fi;
