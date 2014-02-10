#!/bin/bash
# Writes device configuration lines to /etc/smartd.conf
#
# WARNING: this script overrides the file /etc/smartd.conf
# Requires: sg_scan (part of sg3-utils on debian) to detect adaptec raid devices
#
# Author Henrik Farre <hf@bellcom.dk>
# 
# TODO: should we use -M exec /usr/share/smartmontools/smartd-runner to run the scripts in /etc/smartmontools/run.d

CONF_FILE=/etc/smartd.conf
DEBUG=n

if [[ -n $1 && $1 == '--debug' ]]; then
  echo "Outputting to stdout, not overriding $CONF_FILE"
  DEBUG=y
else
  exec > $CONF_FILE
fi

function debug {
  if [[ $DEBUG == 'y' ]]; then
    echo $@
  fi
}

# -W Monitor temperature
CONF_OPTIONS="-W 4,45,50"
# Short everyday at 2, Long saturdays at 3
CONF_SCHEDULE="-s (S/../.././02|L/../../6/03)"
CONF_EMAIL="-m sysadmin+disk@bellcom.dk"
#/dev/hdc -a -I 194 -W 4,45,55 -R 5 -m admin@example.com

# Try to detect HW raid controllers
HW_RAID=`lspci | grep -i raid`

# Same for software
SW_RAID=`ls /proc/mdstat 2>/dev/null`

# Identify CD/DVD drive
SKIP_DEVICES="cdrom"
if [[ -f /proc/sys/dev/cdrom/info ]]; then
  DEVICE_NAME=`grep 'drive name' /proc/sys/dev/cdrom/info | cut -f3`
  SKIP_DEVICES="$SKIP_DEVICES|$DEVICE_NAME"
  debug "Adding " $DEVICE_NAME " to SKIP_DEVICES"
fi

if [[ -n $HW_RAID ]]; then
  HW_RAID_TYPE='unknown'
  if [[ $HW_RAID == *Adaptec* ]]; then
    HW_RAID_TYPE='adaptec'
  fi

  case $HW_RAID_TYPE in
    adaptec )
      # sg0 is the controller
      for DEVICE in /dev/sg[1-9]; do
        IGNORE=`sg_scan -i $DEVICE | grep -c "\(Virtual\|DVD\|Adaptec\|TEAC\|ATAPI\)"`
        if [[ $IGNORE == 0 ]]; then
          echo $DEVICE $CONF_OPTIONS $CONF_SCHEDULE $CONF_EMAIL
        fi
      done
      ;;
  esac
fi

shopt -s extglob

if [[ -n $SW_RAID ]]; then
  for DEVICE in /dev/disk/by-id/ata!(*part*); do
    DEVICE_FILE=`readlink -f $DEVICE`
    if [[ `echo $DEVICE_FILE | egrep -c "$SKIP_DEVICES"` == 0 ]]; then
      echo $DEVICE $CONF_OPTIONS $CONF_SCHEDULE $CONF_EMAIL
    else
      debug "Ignored $DEVICE_FILE"
    fi
  done
fi

if [[ -z $HW_RAID && -z $SW_RAID ]]; then
  debug "No hardware or software RAID"

  for DEVICE in /dev/disk/by-id/ata!(*part*); do
    DEVICE_FILE=`readlink -f $DEVICE`
    if [[ `echo $DEVICE_FILE | grep -c $SKIP_DEVICES` == 0 ]]; then
      echo $DEVICE $CONF_OPTIONS $CONF_SCHEDULE $CONF_EMAIL
    else
      debug "Ignored $DEVICE_FILE"
    fi
  done
fi
