#!/usr/local/bin/bash
# This script will restart httpry and httpry_agent every 24 hours. 
# Run it with a cron line like this:
# 0       0       *       *       *       httpry_job.sh > /dev/null 2>&1

# network interface
interface="bce1"

# httpry location
httpry="/usr/local/bin/httpry" 

# httpry flags
flags="-f timestamp,source-ip,source-port,dest-ip,dest-port,method,host,request-uri,referer,user-agent -i $interface -d"

# http_agent base location
http_agent="/usr/local/etc/nsm/http_agent"

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

# http_agent process
a=`ps auxww | grep "http_agent" | grep -v grep | awk '{print $2}'`

# http_agent tail process
t=`ps auxww | grep "tail -n 0 -f $root" | grep -v grep | awk '{print $2}'`

pids="$h $a $t"

if [ -n "$pids" ]; then

    $httpry $flags -o $root/$year/$year-$month/$year-$month-$day.txt
    $http_agent/http_agent.tcl \
    -c $http_agent/http_agent.conf \
    -e $http_agent/http_agent.exclude \
    -f $root/$year/$year-$month/$year-$month-$day.txt \
    -D

    for x in $pids; do
        /bin/kill $x
    done; 

else

    $httpry $flags -o $root/$year/$year-$month/$year-$month-$day.txt
    $http_agent/http_agent.tcl \
    -c $http_agent/http_agent.conf \
    -e $http_agent/http_agent.exclude \
    -f $root/$year/$year-$month/$year-$month-$day.txt \
    -D

fi;
