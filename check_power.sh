#!/bin/bash

# poor's man smart UPS shutdown
# pings multiple devices NOT on ups and if found all dead for a specific time , the server will shutdown

# Installation on all servers that you need to powerdown
# mkdir -p /opt/scripts
# git clone https://github.com/leonardoxc/poor-mans-smart-ups.git
# crontab -e 

# add this crontab entry:
# * * * * * /opt/scripts/poor-mans-smart-ups/check_power.sh  -i "192.168.1.60,192.168.1.61,192.168.1.62"  -c 5 -s 180
# This checks every 5 secs the 3 ips, if all of them are dead for 180 secs, the server is shutdown

####################################################
# default config values
####################################################

# check every check_interval all devices (devices are not protected by UPS)
check_interval=5

# shutdown server when all pings fails for shutdown_limit secs
shutdown_limit=30

# device to checks
IPLIST=(1.1.122.1 1.1.123.1)

#log
log_file=/var/log/ups.log

#debug
debug=0

####################################################

# check if running already and bail out
if [[ `pgrep -f $0` != "$$" ]]; then
        echo "Another instance of shell already exist! Exiting"
        exit
fi

log() {
    echo $(date '+%Y-%m-%d %H:%M:%S') $1 >> $log_file
}

debug() {
    if [ $debug -eq 1 ]; then
       echo $(date '+%Y-%m-%d %H:%M:%S') $1 >> $log_file
    fi
}


print_usage() {
  echo "Usage: check_power.sh  [-c check interval in secs]  [-s shutdown limit in secs] [-i comma seperated ips enclosed in double quotes] [-vh]"
  echo "Example ./check_power.sh  -i \"22.22.22.22,22.22.22.23,22.22.22.24\"  -c 5 -s 180"
  echo "Checks every 5 secs the 3 ips, if all of them are dead for 180 secs, the server is shutdown"
}

while getopts 'hvs:c:i:' flag; do
  case "${flag}" in
    v) debug=1 ;;
    s) shutdown_limit="${OPTARG}" ;;
    c) check_interval="${OPTARG}" ;;
    i) IPLIST=(`echo $OPTARG| sed 's/,/\n/g'`) ;;
    h) print_usage
       exit 1 ;;
  esac
done

log "Starting power check"
log "Check interval: $check_interval secs"
log "Shutdown limit: $shutdown_limit secs"
log "IPS to check  : ${IPLIST[*]}"
log "Debug         : $debug"


outage_duration=0

while [ 1 == 1 ]; do
    passed=0
    failed=0
    for ip in "${IPLIST[@]}"
    do
        debug $ip
        ping $ip -c 1 -W 1 -w 1 &> /dev/null
        if [ $? -ne 0 ]; then
           log "$ip ping failed"
           let failed=failed+1
        else
           passed=1
        fi
    done

    debug $passed
    debug $failed

    if [ $passed -eq 0 ]; then
        debug "failed, incr counter"
        let outage_duration=outage_duration+check_interval
        log "outage_duration is $outage_duration secs"
    else
        # even if one passed , we are ok
        debug "All is ok reseting outage_duration"
        outage_duration=0
    fi

    if [ $outage_duration -gt $shutdown_limit ]; then
        log "SHUTTING DOWN SERVER!!!!"
        shutdown -h now
        exit
    fi

    # sleep correct time
    let sleepTime=check_interval-failed
    debug "Will sleep $sleepTime"
    sleep $sleepTime

done
