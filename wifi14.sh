#!/bin/bash

# Wireless interface name
interface="wlan0"
is_connected="COMPLETED"
# Path to the wpa_supplicant configuration file
wpa_supplicant_conf="/home/gensong/connect-ap/wpa_supplicant.conf"
killall wpa_supplicant
sleep 2
killall wpa_supplicant

# SSID of the network to connect to
target_ssid="DST"
ifconfig $interface up 
sleep 1

ip_address=$(ifconfig $interface | awk '/inet / {sub(/^.*addr:/, ""); print $1}')
echo "[$(date +%Y-%m-%d\ %H:%M:%S)] IP Address: $ip_address"
wpa_supplicant -B -i "$interface" -c "$wpa_supplicant_conf" &
sleep 3
# Scan and get all available wireless networks
wpa_cli -i $interface -p /var/run/wpa_supplicant scan
sleep 0.1
scan_results=$(wpa_cli -i $interface -p /var/run/wpa_supplicant scan_results)
# Parse scan results and get BSSID and signal strength
bssid=($(echo "$scan_results" | awk '{print $1}'))
ssid=($(echo "$scan_results" | awk '{print $5}'))
#signal_strength=($(echo "$scan_results" | grep "signal level" | awk -F'/ ' '{print $3}'))
signal_strength=($(echo "$scan_results" | grep -v "frequency" | awk '{print $3}'))
# Connect to the network with the specified SSID and strongest signal strength
connect_to_network() {
  local previous_bssid="$1"
  #sleep 0.1
  killall wpa_supplicant
  sleep 1
  echo "###################################"
  # Update BSSID in the wpa_supplicant configuration file
  sed -i "s/bssid=.*/bssid=$previous_bssid/g" "$wpa_supplicant_conf"
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] Replaced new BSSID: $previous_bssid"
  
  # Run wpa_supplicant to connect to the network using the updated configuration file
  sudo wpa_supplicant -B -i "$interface" -c "$wpa_supplicant_conf" &
  # Obtain an IP address from the network's DHCP server
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] Successfully connected to the network with SSID $previous_bssid"
}

# Initialize the target BSSID and strongest signal variables
previous_bssid=""
previous_signal_strength=-1000

# Continuously monitor signal strengths and switch to the strongest network
while true; do
  # Scan and get the latest signal strengths
  #wpa_cli -i $interface -p /var/run/wpa_supplicant scan
  scan_value=$(wpa_cli -i $interface -p /var/run/wpa_supplicant scan)
  sleep 2
  if [[ "$scan_value" == *"FAIL-BUSY"* ]]; then
      echo "[$(date +%Y-%m-%d\ %H:%M:%S)] busy  scan_value is : $scan_value"
      continue
  fi
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] no busy  scan_value is : $scan_value"
  scan_results=$(wpa_cli -i $interface -p /var/run/wpa_supplicant scan_results)
  signal_strength=($(echo "$scan_results" | grep -v "frequency" | awk '{print $3}'))
  # Find the network with the specified SSID and strongest signal strength
  #echo "[$(date +%Y-%m-%d\ %H:%M:%S)] signal_strength is : $signal_strength"
  #sleep 1
  bssid=($(echo "$scan_results" | grep -v "bssid" | awk '{print $1}'))
  sleep 1
  #echo "[$(date +%Y-%m-%d\ %H:%M:%S)] bssid is : $bssid"
#  ssid=($(echo "$scan_results" | grep -v "ssid" | awk '{print $5}'))
 # sleep 1
 

  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] ssid is :"
  ssid=()
  while IFS= read -r line; do
    ssid0=$(echo "$line" | awk -F'\t' '{print $5}')
    ssid+=("$ssid0")
    echo "$ssid0"
  done < <(echo "$scan_results" | grep -v "ssid")

  #echo "[$(date +%Y-%m-%d\ %H:%M:%S)] ssid is : $ssid"
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] bssid0 is : ${bssid[0]} ssid0 is ${ssid[0]}"
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] bssid1 is : ${bssid[1]} ssid1 is ${ssid[1]}"
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] bssid2 is : ${bssid[2]} ssid2 is ${ssid[2]}"
  new_target_bssid=""
  new_strongest_signal=-1000
  
  for i in "${!bssid[@]}"; do
    current_bssid="${bssid[$i]}"
    current_ssid="${ssid[$i]}"
    current_signal="${signal_strength[$i]}"
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] Current BSSID: $current_bssid"
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] Current SSID: $current_ssid"
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] Ccurrent_signal: $current_signal"

    if [ "$current_ssid" == "$target_ssid" ] && [ "$current_signal" -gt "$new_strongest_signal" ] && [ "$new_strongest_signal" != "" ]; then
      new_strongest_signal="$current_signal"
      new_target_bssid="$current_bssid"
      echo "[$(date +%Y-%m-%d\ %H:%M:%S)] New strongest signal: $new_strongest_signal"
      echo "[$(date +%Y-%m-%d\ %H:%M:%S)] New target BSSID: $new_target_bssid"
    fi
  done
  

  connection_status=$(wpa_cli -i $interface -p /var/run/wpa_supplicant status | grep -oP 'wpa_state=\K\w+')
  #connection_status=$(nmcli -t -f GENERAL.STATE dev show $interface)
  #connection_status=$(nmcli device | grep $interface | awk '{print $3}')
  sleep 2
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] connection_status is : $connection_status"
  if [ "${connection_status}" = "COMPLETED" ]; then
  #if [[ $connection_status == "connected" ]]; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] Previous network with BSSID $previous_bssid is  still connected"  
  else
    if [ -n "$new_target_bssid" ]; then
      echo "[$(date +%Y-%m-%d\ %H:%M:%S)] Switching to network with BSSID: $new_target_bssid"
      previous_bssid="$new_target_bssid"
      previous_signal_strength="$new_strongest_signal"
      connect_to_network "$new_target_bssid"
      sleep 10 
    fi    
  fi

  # Wait for some time before the next scan
  sleep 5
  ifconfig $interface 192.168.0.12 netmask 255.255.254.0
  route add default gw 192.168.1.1
done
