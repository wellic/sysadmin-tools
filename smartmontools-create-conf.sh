#!/bin/bash
# Outputs device configuration lines to put in /etc/smartd.conf
# Author Henrik Farre <hf@bellcom.dk>
# 
# TODO: should we use -M exec /usr/share/smartmontools/smartd-runner to run the scripts in /etc/smartmontools/run.d

CONF_FILE="/etc/smartd.conf"
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

if [[ -n $HW_RAID ]]; then
  HW_RAID_TYPE='unknown'
  if [[ $HW_RAID == *Adaptec* ]]; then
    HW_RAID_TYPE='adaptec'
  fi

  case $HW_RAID_TYPE in
    adaptec )
      # sg0 is the controller
      rm $CONF_FILE
      for DEVICE in /dev/sg[1-9]; do
        IGNORE=`sg_scan -i $DEVICE | grep -ic "\(virtual\|DVD\|Data\)"`
        if [[ $IGNORE == 0 ]]; then
          echo $DEVICE $CONF_OPTIONS $CONF_SCHEDULE $CONF_EMAIL >> $CONF_FILE
        fi
      done
      ;;
  esac
fi

shopt -s extglob

if [[ -n $SW_RAID ]]; then
  rm $CONF_FILE
  for DEVICE in /dev/disk/by-id/ata!(*part*); do
    echo $DEVICE $CONF_OPTIONS $CONF_SCHEDULE $CONF_EMAIL >> $CONF_FILE
  done
fi
