#!/bin/bash

# -*- coding: UTF-8 -*-
#export LANG=en_US.UTF-8
#export LC_ALL=en_US.UTF-8
interface="wlan0"

scan_results=$(sudo iwlist $interface scanning)

bssid=$(echo "$scan_results" | grep "Cell" | awk '{print $5}')
echo "bssid is: $bssid"
echo "scan_results is: $scan_results"
#signal_strength=$(echo "$scan_results" | grep "Signal level" | awk '{print $3}' | cut -d= -f2)
#signal_strength=$(echo "$scan_results" | grep "Signal level" | awk '{print $1}')
#signal_strength=$(echo "$scan_results" | grep "Signal level" | awk '{print $4}')

#signal_strength=$(echo "$scan_results" | grep "Signal level" | awk -F ':' '{print $3}' | cut -d= -f2)
#signal_strength=$(echo "$scan_results" | grep "Signal level" | awk '{print $3}' | cut -d= -f2)
#signal_strength=$(echo "$scan_results" | grep "Signal level" | awk -F '[: ]' '{print $4}')
#echo "##########00000signal_strength is :$signal_strength"
#signal_strength=$(echo "$scan_results" | grep -o 'Signal level:-[0-9]\+ dBm' | grep -o '-[0-9]\+')
signal_strength=$(echo "$scan_results" | grep "Signal level" | awk '{print $3}' | cut -d= -f2)
signal_strength=$(echo "$signal_strength" | awk -F '[: ]' '{print $2}')
echo "##########00000222signal_strength is :$signal_strength"
strongest_bssid=""
strongest_signal=-1000
for i in $(seq 1 ${#bssid[@]}); do
    echo "strongest_signal is :$strongest_signal"
    echo "222signal_strength list: $signal_strength"
    current_signal=$(echo "$signal_strength" | sed -n "${i}p")
    echo "current_signal is: $current_signal"
    echo "signal_strength is: $signal_strength"
    echo "i is: $i"
    if [ $current_signal -gt $strongest_signal ]; then
        strongest_signal=$current_signal
        strongest_bssid=$(echo "$bssid" | sed -n "${i}p")
    fi
done

if [ -n "$strongest_bssid" ]; then
    sudo iwconfig $interface essid "$strongest_bssid"
    echo "succeed connect BSSID which network $strongest_bssid"	
else
    echo "no available network found"
fi

sleep 5
sudo iwconfig $interface essid off
echo "Disconnected from the network with BSSID"
while true; do
    scan_results=$(sudo iwlist $interface scanning)
    signal_strength=$(echo "$scan_results" | grep "Signal level" | awk '{print $3}' | cut -d= -f2)
    signal_strength=$(echo "$signal_strength" | awk -F '[: ]' '{print $2}')
    current_strongest_bssid=$strongest_bssid
    strongest_bssid=""
    strongest_signal=-1000
    for i in $(seq 1 ${#bssid[@]}); do
        current_signal=$(echo "$signal_strength" | sed -n "${i}p")
        if [ $current_signal -gt $strongest_signal ]; then
            strongest_signal=$current_signal
            strongest_bssid=$(echo "$bssid" | sed -n "${i}p")
        fi
    done

    if [ "$current_strongest_bssid" != "$strongest_bssid" ]; then
        if [ -n "$strongest_bssid" ]; then
            connect_to_network "$strongest_bssid"
            echo "connect new  BSSID which network $strongest_bssid"
        fi
    fi

    sleep 5
done
