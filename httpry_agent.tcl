#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# httpry agent for Sguil - Based on "example_agent.tcl"
# Portions Copyright (C) 2011 Paul Halliday <paul.halliday@gmail.com>
#
#
# Copyright (C) 2002-2008 Robert (Bamm) Visscher <bamm@sguil.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# Make sure you define the version this agent will work with. 
set VERSION "SGUIL-0.8.0"

# Define the agent type here. It will be used to register the agent with sguild.
# The template also prepends the agent type in all caps to all event messages.
set AGENT_TYPE "httpry"

# The generator ID is a unique id for a generic agent.
# If you don't use 10001, then you will not be able to
# display detail in the client.
set GEN_ID 10001

# Used internally, you shouldn't need to edit these.
set CONNECTED 0

proc DisplayUsage { cmdName } {

    puts "Usage: $cmdName \[-D\] \[-o\] \[-c <config filename>\] \[-f <httpry filename>\] \[-e <exclusions filename>\]"
    puts "  -c <filename>: PATH to config (httpry_agent.conf) file."
    puts "  -f <filename>: PATH to httpry file to monitor."
    puts "  -e <filename>: PATH to exclusions (httpry_agent.exclude) file."
    puts "  -D Runs sensor_agent in daemon mode."
    exit

}

# bgerror: This is a generic error catching proc. You shouldn't need to change it.
proc bgerror { errorMsg } {

    global errorInfo sguildSocketID

    # Catch SSL errors, close the channel, and reconnect.
    # else write the error and exit.
    if { [regexp {^SSL channel "(.*)":} $errorMsg match socketID] } {

        catch { close $sguildSocketID } tmpError
        ConnectToSguilServer

    } else {

        puts "Error: $errorMsg"
        if { [info exists errorInfo] } {
            puts $errorInfo
        }
        exit

    }

}

# InitAgent: Use this proc to initialize your specific agent.
# Open a file to monitor or even a socket to receive data from.
proc InitAgent {} {

    global DEBUG FILENAME

    if { ![info exists FILENAME] } { 
        # Default file is /nsm/httpry/url.log
        set FILENAME /nsm/httpry/url.log
    }
    if { ![file readable $FILENAME] } {
        puts "Error: Unable to read $FILENAME"
        exit 1
    }
    
    if [catch {open "| tail -n 0 -f $FILENAME" r} fileID] {
        puts "Error opening $FILENAME : $fileID"
        exit 1
    }

    fconfigure $fileID -buffering line
    # Proc ReadFile will be called as new lines are appended.
    fileevent $fileID readable [list ReadFile $fileID]

}

#
# ReadFile: Read and process each new line.
#
proc ReadFile { fileID } {

    if { [eof $fileID] || [catch {gets $fileID line} tmpError] } {
    
        puts "Error processing file."
        if { [info exits tmpError] } { puts "$tmpError" }
        catch {close $fileID} 
        exit 1

    } else {
            
        # I prefer to process the data in a different proc.
        ProcessData $line

    }

}

#
# ProcessData: Here we actually process the line
#
proc ProcessData { line } {

    global HOSTNAME AGENT_ID NEXT_EVENT_ID AGENT_TYPE GEN_ID
    global sguildSocketID DEBUG
    global INVERT_MATCH EMPTY_HOST HAYSTACK

    # Grab lines that match our regexp. 
    # timestamp,source-ip,dest-ip,method,host,request-uri,referer,user-agent

    if { [regexp -expanded {

        ^(\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d)\s+        # timestamp
        (\d+\.\d+\.\d+\.\d+)\s+                         # src ip
        (\d+)\s+					# src port
        (\d+\.\d+\.\d+\.\d+)\s+                         # dst ip
        (\d+)\s+                                        # dst port 
        (\S+)\s+                                        # method
        (\S+)\s+                                        # host
        (\S+)\s+                                        # request_uri
        (\S+)\s+                                        # referer
        (.*$)                                           # user_agent


            } $line match timestamp src_ip src_port dst_ip dst_port method host request_uri referer user_agent] } {

        if { $DEBUG } {
            puts "\nMatch:\n"
            puts "$timestamp\n"
            puts "$src_ip\n"
            puts "$src_port\n"
            puts "$dst_ip\n"
            puts "$dst_port\n"
            puts "$method\n"
            puts "$host\n"
            puts "$request_uri\n"
            puts "$referer\n"
            puts "$user_agent\n"
        }
        
        # Strip protocol and break the FQDN down
        regsub {^http://} $host "" host
        regsub {:.*$} $host "" cleanHost
        set domParts [lreverse [split $cleanHost "."] ]
        set partCount [llength $domParts]
        set pHits 0
        set rList ""
        set fList ""

        # Run through each segment and see if we match anything
        for { set i 0 } { $i <= $partCount } { incr i } {

            lappend rList [lindex $domParts $i]
            set fList [lreverse $rList]
            set theNeedle [join $fList "."]
            # Check for a broad hit in our haystack
            set stackHit [lsearch $HAYSTACK *$theNeedle]

            if { $stackHit != -1 } {

                set absHit [lsearch -exact $HAYSTACK *.$theNeedle]

                # See if this was an exact hit
                if { $absHit != -1 } {

                    set i $partCount
                    set pHits $partCount

                } else {

                    incr pHits
      
                }

            }
            # If we didn't hit here, there is no match
            if { $i == 1 && $stackHit == -1 } {

                set i $partCount

            }

        }

        # When the loop is finished, if these match we got a hit
        if { $pHits == $partCount } {

            set aMatch 1

        } else {

            set aMatch 0

        }
        

        # If we missed our stack, we add the entry
        if { $aMatch == 0 && $INVERT_MATCH != 1 } {
        
            if { $EMPTY_HOST == 1 && $host == "-" } {

                set addEntry 0   
                    
            } else {
                
                set addEntry 1
                    
            }

        # If we hit
        } else {
            
            if { $aMatch == 1 && $INVERT_MATCH == 1 } {
        
                set addEntry 1
        
            } else {
        
                set addEntry 0
        
            }
    
        }
 
        if { $addEntry == 1 } {

            set message "URL $host"
            set sig_id "420042"
            set rev "1"
            set priority 3
            set class "misc-activity"
            set proto 6
            set detail "$method || $host$request_uri || $referer || $user_agent"

            # Convert date to YY-MM-DD HH:MM:SS format
            set nDate [clock format [clock scan "$timestamp" -gmt true] -gmt true -f "%Y-%m-%d %T"]
    
            # Build the event to send
            set event [list GenericEvent 0 $priority $class $HOSTNAME $nDate $AGENT_ID $NEXT_EVENT_ID \
                       $NEXT_EVENT_ID [string2hex $message] $src_ip $dst_ip $proto $src_port $dst_port \
                       $GEN_ID $sig_id $rev [string2hex $detail]]
    
            # Send the event to sguild
            if { $DEBUG } { puts "Sending: $event" }
                while { [catch {puts $sguildSocketID $event} tmpError] } {
    
                # Send to sguild failed
                if { $DEBUG } { puts "Send Failed: $tmpError" }
    
                # Close open socket
                catch {close $sguildSocketID}
            
                # Reconnect loop
                while { ![ConnectToSguild] } { after 15000 }

            }
    
            # Sguild response should be "ConfirmEvent eventID"
            if { [catch {gets $sguildSocketID response} readError] } {
    
                # Error getting a response. This one is fatal.
                puts "Fatal error: $readError"
                exit 1
    
            }

            if {$DEBUG} { puts "Received: $response" }
    
            if { [llength $response] != 2 || [lindex $response 0] != "ConfirmEvent" || [lindex $response 1] != $NEXT_EVENT_ID } {
    
               # Send to sguild failed
               if { $DEBUG } { puts "Recv Failed" }

               # Close open socket
               catch {close $sguildSocketID}

               # Reconnect loop
               while { ![ConnectToSguilServer] } { after 15000 }
               return 0                
    
            }
    
            # Success! Increment the next event id
            incr NEXT_EVENT_ID
    
        }
    
    }

}

# Initialize connection to sguild
proc ConnectToSguilServer {} {

    global sguildSocketID HOSTNAME CONNECTED
    global SERVER_HOST SERVER_PORT DEBUG VERSION
    global AGENT_ID NEXT_EVENT_ID
    global AGENT_TYPE NET_GROUP

    # Connect
    if {[catch {set sguildSocketID [socket $SERVER_HOST $SERVER_PORT]}] > 0} {

        # Connection failed #

        set CONNECTED 0
        if {$DEBUG} {puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT."}

    } else {

        # Connection Successful #
        fconfigure $sguildSocketID -buffering line

        # Version checks
        set tmpVERSION "$VERSION OPENSSL ENABLED"

        if [catch {gets $sguildSocketID} serverVersion] {
            puts "ERROR: $serverVersion"
            catch {close $sguildSocketID}
            exit 1
         }

        if { $serverVersion == "Connection Refused." } {

            puts $serverVersion
            catch {close $sguildSocketID}
            exit 1

        } elseif { $serverVersion != $tmpVERSION } {

            catch {close $sguildSocketID}
            puts "Mismatched versions.\nSERVER: ($serverVersion)\nAGENT: ($tmpVERSION)"
            return 0

        }

        if [catch {puts $sguildSocketID [list VersionInfo $tmpVERSION]} tmpError] {
            catch {close $sguildSocketID}
            puts "Unable to send version string: $tmpError"
            return 0
        }

        catch { flush $sguildSocketID }
        tls::import $sguildSocketID

        set CONNECTED 1
        if {$DEBUG} {puts "Connected to $SERVER_HOST"}

    }

    # Register the agent with sguild.
    set msg [list RegisterAgent $AGENT_TYPE $HOSTNAME $NET_GROUP]
    if { $DEBUG } { puts "Sending: $msg" }
    if { [catch { puts $sguildSocketID $msg } tmpError] } { 
 
        # Send failed
        puts "Error: $tmpError"
        catch {close $sguildSocketID} 
        return 0
    
    }

    # Read reply from sguild.
    if { [eof $sguildSocketID] || [catch {gets $sguildSocketID data}] } {
 
        # Read failed.
        catch {close $sockID} 
        return 0

    }
    if { $DEBUG } { puts "Received: $data" }

    # Process agent info returned from sguild
    # Should return:  AgentInfo sensorName agentType netName sensorID maxCid
    if { [lindex $data 0] != "AgentInfo" } {

        # This isn't what we were expecting
        catch {close $sguildSocketID}
        return 0

    }

    # AgentInfo    { AgentInfo [lindex $data 1] [lindex $data 2] [lindex $data 3] [lindex $data 4] [lindex $data 5]}
    set AGENT_ID [lindex $data 4]
    set NEXT_EVENT_ID [expr [lindex $data 5] + 1]

    return 1
    
}

proc Daemonize {} {

    global PID_FILE DEBUG

    # We need extended tcl to run in the background
    # Load extended tcl
    if [catch {package require Tclx} tclxVersion] {

        puts "ERROR: The tclx extension does NOT appear to be installed on this sysem."
        puts "Extended tcl (tclx) contains the 'fork' function needed to daemonize this"
        puts "process.  Install tclx or background the process manually.  Extended tcl"
        puts "(tclx) is available as a port/package for most linux and BSD systems."
        exit 1

    }

    set DEBUG 0
    set childPID [fork]
    # Parent exits.
    if { $childPID == 0 } { exit }
    id process group set
    if {[fork]} {exit 0}
    set PID [id process]
    if { ![info exists PID_FILE] } { set PID_FILE "/var/run/sensor_agent.pid" }
    set PID_DIR [file dirname $PID_FILE]

    if { ![file exists $PID_DIR] || ![file isdirectory $PID_DIR] || ![file writable $PID_DIR] } {

        puts "ERROR: Directory $PID_DIR does not exists or is not writable."
        puts "Process ID will not be written to file."

    } else {

        set pidFileID [open $PID_FILE w]
        puts $pidFileID $PID
        close $pidFileID

    }

}
#
# CheckLineFormat - Parses CONF_FILE lines to make sure they are formatted
#                   correctly (set varName value). Returns 1 if good.
#
proc CheckLineFormat { line } {

    set RETURN 1
    # Right now we just check the length and for "set".
    if { [llength $line] != 3 || [lindex $line 0] != "set" } { set RETURN 0 }
    return $RETURN

}

#
# A simple proc to return the current time in 'YYYY-MM-DD HH:MM:SS' format
#
proc GetCurrentTimeStamp {} {

    set timestamp [clock format [clock seconds] -gmt true -f "%Y-%m-%d %T"]
    return $timestamp

}

#
# Converts strings to hex
#
proc string2hex { s } {

    set i 0
    set r {}
    while { $i < [string length $s] } {

        scan [string index $s $i] "%c" tmp
        append r [format "%02X" $tmp]
        incr i

    }

    return $r

}


################### MAIN ###########################

# Standard options are below. If you need to add more switches,
# put them here. 
# 
# GetOpts
set state flag
foreach arg $argv {

    switch -- $state {

        flag {

            switch -glob -- $arg {

                -- { set state flag }
                -D { set DAEMON_CONF_OVERRIDE 1 }
                -c { set state conf }
                -O { set state sslpath }
                -f { set state filename }
                -e { set state exclude }
                default { DisplayUsage $argv0 }

            }

        }

        conf     { set CONF_FILE $arg; set state flag }
        sslpath  { set TLS_PATH $arg; set state flag }
        filename { set FILENAME $arg; set state flag }
        exclude  { set EXCLUDE $arg; set state flag }
        default { DisplayUsage $argv0 }

    }

}

# Parse the config file here. Make sure you define the default config file location
if { ![info exists CONF_FILE] } {

    # No conf file specified check the defaults
    if { [file exists /etc/httpry_agent.conf] } {

        set CONF_FILE /etc/httpry_agent.conf

    } elseif { [file exists ./httpry_agent.conf] } {

        set CONF_FILE ./httpry_agent.conf

    } else {

        puts "Couldn't determine where the httpry_agent.tcl config file is"
        puts "Looked for /etc/httpry_agent.conf and ./httpry_agent.conf."
        DisplayUsage $argv0

    }

}

set i 0
if { [info exists CONF_FILE] } {

    # Parse the config file. Currently the only option is to
    # create a variable using 'set varName value'
    set confFileID [open $CONF_FILE r]
    while { [gets $confFileID line] >= 0 } {

        incr i
        if { ![regexp ^# $line] && ![regexp ^$ $line] } {

            if { [CheckLineFormat $line] } {

                if { [catch {eval $line} evalError] } {

                    puts "Error at line $i in $CONF_FILE: $line"
                    exit 1

                }

            } else {

                puts "Error at line $i in $CONF_FILE: $line"
                exit 1

            }

        }

    }

    close $confFileID

} else {

    DisplayUsage $argv0

}

# Check for exclusions list
if { ![info exists EXCLUDE] } {

    # No exclude file specified check the defaults
    if { [file exists /etc/httpry_agent.exclude] } {

        set EXCLUDE /etc/httpry_agent.exclude

    } elseif { [file exists ./httpry_agent.exclude] } {

        set EXCLUDE ./httpry_agent.exclude

    } else {

        puts "Couldn't determine where the httpry_agent.tcl exclusions file is"
        puts "Looked for /etc/httpry_agent.exclude and ./httpry_agent.exclude."
        DisplayUsage $argv0

    }

}

if { [info exists EXCLUDE] } {

    set efp [open $EXCLUDE r]
    set HAYSTACK ""

    while { [gets $efp line] >= 0 } {

        if { ![regexp ^# $line] && ![regexp ^$ $line] } {

            lappend HAYSTACK $line

        }

    }

    close $efp

}

# Command line overrides the conf file.
if {[info exists DAEMON_CONF_OVERRIDE] && $DAEMON_CONF_OVERRIDE} { set DAEMON 1}
if {[info exists DAEMON] && $DAEMON} {Daemonize}

# OpenSSL is required
# Need path?
if { [info exists TLS_PATH] } {

    if [catch {load $TLS_PATH} tlsError] {

        puts "ERROR: Unable to load tls libs ($TLS_PATH): $tlsError"
        DisplayUsage $argv0

    }

}

if { [catch {package require tls} tmpError] }  {

    puts "ERROR: Unable to load tls package: $tmpError"
    DisplayUsage $argv0

}

# Connect to sguild
while { ![ConnectToSguilServer] } {

    # Wait 15 secs before reconnecting
    after 15000
}

# Intialize the Agent
InitAgent

# This causes tcl to go to it's event loop
vwait FOREVER
