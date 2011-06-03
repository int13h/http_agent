# httpry_agent - A HTTP request agent for Sguil


## Description

This agent adds HTTP events to Sguil


## Requirements

Sguil: [http://sguil.sourceforge.net/](http://sguil.sourceforge.net/)
httpry : [http://dumpsterventures.com/jason/httpry/](http://dumpsterventures.com/jason/httpry/)


## Install

1) Fetch the tarball or checkout the repository onto your sensor.

2) Install and configure httpry:

  - [I used version 0.1.5](http://dumpsterventures.com/jason/httpry/httpry-0.1.5.tar.gz)
  - If your sensor is not set to UTC you will need make a change to httpry.c on line 353,
    swap "localtime()" with "gmtime()" and recompile.
  - you need to start httpry with the following format structure (-f):
    timestamp,source-ip,dest-ip,method,host,request-uri,referer,user-agent

## Usage

Soon.
