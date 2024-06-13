#!/bin/bash

# Wireless interface name
interface="wlan0"

# Path to the wpa_supplicant configuration file
wpa_supplicant_conf="/root/connect-ap/wpa_supplicant.conf"

# SSID of the network to connect to
target_ssid="GS-office"

# Scan and get all available wireless networks
scan_results=$(sudo iwlist $interface scanning)

# Parse scan results and get BSSID and signal strength
#bssid=$(echo "$scan_results" | grep "Cell" | awk '{print $5}')
bssid=($(echo "$scan_results" | awk '/Cell/ {print $5}'))

#ssid=$(echo "$scan_results" | grep "ESSID" | awk -F\" '{print $2}')
ssid=($(echo "$scan_results" | awk -F\" '/ESSID/ {print $2}'))
signal_strength=$(echo "$scan_results" | grep "Signal level" | awk '{print $3}' | cut -d= -f2)
signal_strength=$(echo "$signal_strength" | awk -F '[: ]' '{print $2}')

#echo "bssid is: $bssid"
#echo "scan_results is: $scan_results"
#echo "##########00000222signal_strength is :$signal_strength"
# Find the network with the specified SSID and strongest signal strength
target_bssid=""
strongest_signal=-1000




for i in "${!bssid[@]}"; do
  current_bssid="${bssid[$i]}" 
  current_ssid="${ssid[$i]}"
  echo "1current_bssid is: $current_bssid"
  current_signal=$(echo "$signal_strength" | sed -n "${i}p")
  echo "1current_ssid is :$current_ssid"
  echo "##########22current_signal is :$current_signal"
  if [ "$current_ssid" == "$target_ssid" ] && [ "$current_signal" -gt "$strongest_signal" ]; then
    strongest_signal=$current_signal
    #target_bssid=$(echo "$bssid" | sed -n "${i}p")
    target_bssid=$current_bssid
    echo "##########22strongest_signal is :$strongest_signal"
    echo "2target_bssid is :$target_bssid"

  fi
  echo "2##########i is :$i"
done

if [ -z "$target_bssid" ]; then
  echo "Could not find a network with SSID $target_ssid"
  exit 1
fi

# Connect to the network with the specified SSID and strongest signal strength
connect_to_network() {
  # Run wpa_supplicant to connect to the network using the existing configuration file
  sed -i "s/bssid=.*/bssid=$target_bssid/g" "$wpa_supplicant_conf"
  echo "replaced new bssid is $target_bssid"
  sudo wpa_supplicant -B -i "$interface" -c "$wpa_supplicant_conf"

  # Obtain an IP address from the network's DHCP server
  sudo dhclient "$interface"

  echo "Successfully connected to the network with SSID $target_ssid"
}

connect_to_network

