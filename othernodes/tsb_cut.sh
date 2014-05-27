#!/bin/bash

rm testbed.sh

wget https://www.dropbox.com/s/jj7cvi77xwjn8dp/testbed.sh

MANAGMENT_IP=$( ip -4 addr show dev eth0 | grep -m 1 "inet " | awk '{print $2}' | cut -d "/" -f 1 )

START_END=( $(grep -F "$MANAGMENT_IP" testbed.sh -n | cut -d ":" -f 1) )

sed "${START_END[0]},${START_END[1]}!d" testbed.sh > tbs.sh

mv tbs.sh testbed.sh
