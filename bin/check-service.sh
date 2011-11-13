#!/bin/bash
#
# Process control
#
# This shell-script watch that <process> doesn't pass the <limit> of % cpu usage
# If it does, the script kills that process and finish
#
# For linux kernel 2.6.x
# v.0.1 sept-2007
#
# Author: Miguel Ángel Molina Molina
# Licence: GPL v.2

# Parameter check
# [debug] parameter is optional and can be anything. If it exists, the script produces output to the screen for debugging purposes.
if [ $# -lt 2 -o $# -gt 3 ];
then
  echo "Usage: `basename $0` <process> <limit> [debug]"
  exit -1
fi

# [debug] exists?
if [ $# -eq 3 ];
then
  debug="yes"
else
  debug=""
fi

date

procpid=`pidof $1`
typeset -i limit=$2

# process existence check
if [ -z "$procpid" ];
then
  echo "Process: $1 doesn't exists - starting $1 ... "
  logger "Process: $1 doesn't exists - starting $1 ... "
  service $1 start
  echo "Done."
  exit -1
fi

# limit check
if [ $limit -lt 1 -o $limit -gt 99 ];
then
  echo "Limit must be between 1 and 99"
  exit -1
fi

typeset -i hits=0

while [ 1 ]
do
  # Get usage cpu time
  typeset -i cputime=`cat /proc/uptime | cut -f1 -d " " | sed 's/\.//'`
  # process pid check
  if [ ! -f /proc/${procpid}/stat ];
  then
    echo "Process doesn't exists: ${procpid}"
    exit -1
  fi
  # Get process usage cpu time
  typeset -i proctime=`cat /proc/${procpid}/stat | awk '{t = $14 + $15;print t}'`
  # wait 3 seconds
  sleep 3
  # get usage cpu time, again
  typeset -i cputime2=`cat /proc/uptime | cut -f1 -d " " | sed 's/\.//'`
  # get process usage cpu time, again
  typeset -i proctime2=`cat /proc/${procpid}/stat | awk '{t = $14 + $15;print t}'`
  # calculate process usage cpu time over total usage cpu time as percentage
  typeset -i cpu=$((($proctime2-$proctime)*100/($cputime2-$cputime)))
  [ ! -z $debug ] && echo "Process $1, with pid: $procpid, is wasting: $cpu% of cpu"
  [ ! -z $debug ] && logger "Process $1, with pid: $procpid, is wasting: $cpu% of cpu"
  # limit exceed check
  if [ $cpu -gt $limit ];
  then
    # Count the excess
    let hits+=1
    if [ $hits = 1 ];
    then
      times="time"
    else
      times="times"
    fi
    [ ! -z $debug ] && echo "Process $1 has exceeded the limit: $limit ($cpu) $hits $times ..."
    [ ! -z $debug ] && logger "Process $1 has exceeded the limit: $limit ($cpu) $hits $times ..."
    # If hits are greater than 3, kill the process
    if [ $hits -gt 3 ];
    then
      echo -n "Stopping service: $1 ... "
      logger "Stopping service: $1 ... "
      service $1 stop
      # check if process has died
      if [ -z "`pidof $1`" ];
      then
        echo "Stopped."
      else
        echo "Can't stop service $1."

        echo -n "Killing process: $procpid ... "
        logger "Killing process: $procpid ... "
        kill $procpid
        # wait until process die
        sleep 1
        # check if process has died
        if [ -z "`pidof $1`" ];
        then
          echo "Done."
        else
          echo "Can't kill the process."
        fi
      fi

      echo -n "Starting service: $1 ... "
      service $1 start
      echo "Done."
      exit 0
    fi
  else
   # if no limit exceed, reset hit counter
   #let hits=0
   exit 0
  fi
done

