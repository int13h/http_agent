# http_agent - HTTP request agent for Sguil


## Description

This agent adds HTTP events to Sguil. This agent can process httpry, Suricata(http) and Bro(http) output.


## Requirements

* Sguil: [http://sguil.sourceforge.net/](http://sguil.sourceforge.net/)

* httpry: [http://dumpsterventures.com/jason/httpry/](http://dumpsterventures.com/jason/httpry/)

* Suricata: [http://www.openinfosecfoundation.org/index.php/downloads](http://www.openinfosecfoundation.org/index.php/downloads)

* Bro: [http://bro-ids.org/](http://bro-ids.org/)


## Install

1) Download http_agent: 

`git clone https://github.com/int13h/http_agent.git`

2) Install and configure 

  a) httpry:

  - You can find it here (versions < 0.1.5 wont work): [http://dumpsterventures.com/jason/httpry/httpry-0.1.5.tar.gz](http://dumpsterventures.com/jason/httpry/httpry-0.1.5.tar.gz)
  - If your sensor is not set to UTC you will need make a change to httpry.c on line 353,
    swap "localtime()" with "gmtime()" and recompile.
  - you need to start httpry with the following format structure (-f):
    timestamp,source-ip,source-port,dest-ip,dest-port,method,host,request-uri,referer,user-agent

  b) Suricata:

  - Edit suricata.yaml and under "- http-log:" set "enabled: yes"
  - You will need to patch log-httplog.c with the following [patch](https://redmine.openinfosecfoundation.org/attachments/588/log-httplog.c.patch)
  

3) I made a little [shell script](https://github.com/int13h/http_agent/blob/master/http_job.sh) that will make httpry's output a 
little easier to manage. The script is intended to be called by cron each day at midnight. When it runs it will create a new daily 
directory and start a new httpry process; spooling to this directory. Once complete, it terminates the old process. 
My bash sucks but it should be enough to get you going. 

## Operation

The agent tails the output of the specified log file and feeds matching lines to Sguild.

The log format is set via http_agent.conf (last line):

"LOG_FORMAT httpry" OR "LOG_FORMAT suricata" OR "LOG_FORMAT bro"

You need to start httpry with the following format string:

`httpry -f timestamp,source-ip,source-port,dest-ip,dest-port,method,host,request-uri,referer,user-agent -i bce0 -d -o /nsm/httpry/url.log`

There is an exclusions file which can be used in one of two ways:

1) If INVERT_MATCH is set to 0 in http_agent.conf anything that matches an entry in
   http_agent.exclude will be ignored.

2) If INVERT_MATCH is set to 1 in http_agent.conf anything that matches an entry in
   http_agent.exclude will be sent to Sguild.

**Example 1: Match everything from the following TLD's (INVERT_MATCH set to 1)**

	*.ua
	*.ru
	*.cn
	*.lv


**Example 2: Ignore everything from the following FQDN's (INVERT_MATCH set to 0)**

	*.facebook.com
	*.dropbox.com
	*.twitter.com

## Notes

1) Unless you are doing extensive or very specific filtering (*.ca, *.com, *.net, *.org...) then you will want 
   Sguild to autocat these events. These events are prefixed with "URL" so something like this will do:

   none||ANY||ANY||ANY||ANY||ANY||ANY||%%REGEXP%%^URL||1

2) The events use a signature ID of 420042, event class "misc-activity"

3) Filtering needs work (features) payload for example

4) This is beta. It might break things.


## Observations

1) I dont think that the exclusions mechanism is very efficient (big surprise) I need to re-write it. I currently have the
   agent processing a little under 6 Million requests a day and the agent fluctuates between 16-28% CPU utilization.

2) It would be really nice if there was another column in Sguil's event table to put the URI instead of blobbing it in the 
   data table.
