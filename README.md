# httpry_agent - HTTP request agent for Sguil


## Description

This agent adds HTTP events to Sguil


## Requirements

* Sguil: [http://sguil.sourceforge.net/](http://sguil.sourceforge.net/)

* httpry : [http://dumpsterventures.com/jason/httpry/](http://dumpsterventures.com/jason/httpry/)


## Install

1) Download httpry_agent: 

`git clone https://github.com/int13h/httpry_agent.git`

2) Install and configure httpry:

  - You can find it here (versions < 0.1.5 wont work): [http://dumpsterventures.com/jason/httpry/httpry-0.1.5.tar.gz](http://dumpsterventures.com/jason/httpry/httpry-0.1.5.tar.gz)
  - If your sensor is not set to UTC you will need make a change to httpry.c on line 353,
    swap "localtime()" with "gmtime()" and recompile.
  - you need to start httpry with the following format structure (-f):
    timestamp,source-ip,source-port,dest-ip,dest-port,method,host,request-uri,referer,user-agent

## Operation

The agent tails the output of httpry and feeds matching lines to Sguild.

Start httpry with something like:

`httpry -f timestamp,source-ip,source-port,dest-ip,dest-port,method,host,request-uri,referer,user-agent -i bce0 -d -o /nsm/httpry/url.log`

There is an exclusions file which can be used in one of two ways:

1) If INVERT_MATCH is set to 0 in httpry_agent.conf anything that matches an entry in
   httpry_agent.exclude will be ignored.

2) If INVERT_MATCH is set to 1 in httpry_agent.conf anything that matches an entry in
   httpry_agent.exclude will be sent to Sguild.

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

4) Need to do log management for httpry

5) This is beta. It might break things.

