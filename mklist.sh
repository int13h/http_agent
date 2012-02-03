#!/usr/local/bin/bash
#
# mklist.sh
# paul.halliday@gmail.com
#
#  0    *       *       *       mklist.sh > /dev/null 2>&1
#

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin;
export PATH

# Paths
baseDir="$PWD"
workDir="$baseDir/tmp"
outFile="http_agent.exclude"
excludeFile="$baseDir/domains.exclude"
includeFile="$baseDir/domains.include"
today=`date "+%Y-%m-%d"`

#
# List URLS
#

lists="
           http://mirror1.malwaredomains.com/files/justdomains
           https://zeustracker.abuse.ch/blocklist.php?download=domainblocklist
"
## Stop edits

token=0
go=no
zc=0
touch $workDir/$outFile.tmp

# Begin processing

for list in $lists; do

    wget --no-check-certificate -O $workDir/00_$zc.tmp $list

    if [ -e $workDir/00_$zc.tmp ]; then
        cat $workDir/00_$zc.tmp | sed 's/.//g' | grep -v ^# >> $workDir/$outFile.tmp
        cat $workDir/$outFile.tmp | sed 's/^[ \t]*//;s/[ \t]*$//;/^$/d' | sort | uniq > $workDir/$outFile 
    fi

    let zc=$zc+1

done

# Delete temps
rm -f $workDir/*.tmp

# See if we got something
if [ -e $workDir/$outFile ]; then
    go="yes"
else
    eMsg="Warning: No file to work with."
    token=3
fi

# Check for an existing file and look for additions/removals
if [ $go = "yes" ]; then
    if [ !$baseDir/$outFile ]; then
        touch $baseDir/$outFile

        # Remove any exclusions before we perform the comparison
        if [ -e $excludeFile ]; then
            excludeList=`cat $excludeFile | grep -v ^#`

            for domain in $excludeList; do
                sed -i '' "/^$domain$/d" $workDir/$outFile
            done
        fi

        theDiff=`diff $baseDir/$outFile $workDir/$outFile`
            
        if [ -z "$theDiff" ]; then
            go="no"
            rm -f $workDir/$outFile
            eMsg="Notice: No updates available."
            token=2
        fi
    fi
fi

if [ $go = "yes" ]; then
    cp $workDir/$outFile $workDir/$outFile.$today
    mv $workDir/$outFile $baseDir
    eMsg="Notice: Changes found! A new file has been generated"
fi

echo $eMsg
