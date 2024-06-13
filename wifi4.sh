#!/bin/bash

# Wireless interface name
interface="wlan0"
#interface1="wlan1"
# Path to the wpa_supplicant configuration file
wpa_supplicant_conf="/root/connect-ap/wpa_supplicant.conf"

# SSID of the network to connect to
target_ssid="AGV-TSQ-1F"
sleep 1
# Scan and get all available wireless networks
scan_results=$(sudo iwlist $interface scanning)

# Parse scan results and get BSSID and signal strength
bssid=($(echo "$scan_results" | awk '/Cell/ {print $5}'))
ssid=($(echo "$scan_results" | awk -F\" '/ESSID/ {print $2}'))
signal_strength=$(echo "$scan_results" | grep "Signal level" | awk '{print $3}' | cut -d= -f2)
signal_strength=$(echo "$signal_strength" | awk -F '[: ]' '{print $2}')
echo "20 signal_strength is :signal_strength"
# Connect to the network with the specified SSID and strongest signal strength
connect_to_network() {
  local previous_bssid="$1"
  sudo rm /var/run/wpa_supplicant/wlan0
  #sleep 0.1
  killall wpa_supplicant
  #dhclient -v -r $interface
  sleep 1
  echo "###################################"
  # Update BSSID in the wpa_supplicant configuration file
  #sed -i "s/bssid=.*/bssid=\"$target_bssid\"/g" "$wpa_supplicant_conf"
  #sed -i "s/bssid=\"[^\"]*\"/bssid=\"$target_bssid\"/g" "$wpa_supplicant_conf"
  sed -i "s/bssid=.*/bssid=$previous_bssid/g" "$wpa_supplicant_conf"
  echo "Replaced new BSSID: $previous_bssid"
  
  # Run wpa_supplicant to connect to the network using the updated configuration file
  sudo wpa_supplicant -B -i "$interface" -c "$wpa_supplicant_conf"
  #nmcli device wifi connect $target_ssid password gensong123 bssid $target_bssid ifname "$interface"
  # Obtain an IP address from the network's DHCP server
  #sudo dhclient -v "$interface"
  #systemctl restart networking 
  echo "Successfully connected to the network with SSID $previous_bssid"
  # iwlist_pid=$(pgrep -f "iwlist $interface1 scanning")
  # if [ -n "$iwlist_pid" ]; then
  #   echo "iwlist_pid is $iwlist_pid"
  #   pkill -P $iwlist_pid
  #   sudo pkill -P $iwlist_pid
  # fi
}

# Initialize the target BSSID and strongest signal variables
previous_bssid=""
previous_signal_strength=-1000

# Continuously monitor signal strengths and switch to the strongest network
while true; do
  # Scan and get the latest signal strengths
  scan_results=$(sudo iwlist $interface scanning)
  #signal_strength=($(echo "$scan_results" | awk '/Signal level/ {print $4}' | cut -d= -f2))
  #echo "222#########################################scan_results is $scan_results"
  signal_strength=($(echo "$scan_results" | grep "Signal level" | awk '{print $3}' | cut -d= -f2 | awk -F '[: ]' '{print $2}'))
  #echo "2222#########################################signal_strength is $signal_strength"
  #sleep 1
  #signal_strength=$(echo "$signal_strength" | awk -F '[: ]' '{print $2}')
  #echo "1signal_strength is $signal_strength"
  
  # Find the network with the specified SSID and strongest signal strength
  new_target_bssid=""
  new_strongest_signal=-1000
  
  for i in "${!bssid[@]}"; do
    current_bssid="${bssid[$i]}"
    current_ssid="${ssid[$i]}"
    current_signal="${signal_strength[$i]}"
    #current_signal="${signal_strength[$i]}"

    
    #current_signal=$(echo "$signal_strength" | sed -n "${i}p")
    
    echo "Current BSSID: $current_bssid"
    echo "Current SSID: $current_ssid"
    echo "Ccurrent_signal: $current_signal"
    
 
    if [ "$current_ssid" == "$target_ssid" ] && [ "$current_signal" -gt "$new_strongest_signal" ] && [ "$new_strongest_signal" != "" ]; then
    #if [ "$current_ssid" == "$new_target_bssid" ] && [ "$current_signal" -gt "$new_strongest_signal" ]; then
      new_strongest_signal="$current_signal"
      new_target_bssid="$current_bssid"
      echo "New strongest signal: $new_strongest_signal"
      echo "New target BSSID: $new_target_bssid"
    fi
  done
  

  if [ -n "$new_target_bssid" ]; then
    is_connected=$(iw dev $interface link | grep "$previous_bssid")
    if [ "$new_target_bssid" != "$previous_bssid" ]; then
    #if [ -n "$is_connected" ] && [ "$new_strongest_signal" -gt "$previous_signal_strength" ]; then
      echo "Switching to network with BSSID: $new_target_bssid"
      previous_bssid="$new_target_bssid"
      previous_signal_strength="$new_strongest_signal"
      connect_to_network "$new_target_bssid"
    else
      # Check the connection status of the previous BSSID
      is_connected=$(iw dev $interface link | grep "$previous_bssid")
      if [ -z "$is_connected" ]; then
        echo "Previous network with BSSID $previous_bssid is disconnected. Reconnecting..."
        connect_to_network "$previous_bssid"
      fi
    fi
  else
    echo "No stronger network with SSID $target_ssid found"
  fi
  # if [ -n "$new_target_bssid" ] && [ "$new_strongest_signal" -gt "$strongest_signal" ]; then
  # #if [ -n "$new_target_bssid" ] [ -n "$new_strongest_signal" ] && [ "$new_target_bssid" ! = "$target_bssid" ]; then
  #   echo "Switching to network with BSSID: $new_target_bssid"
  #   target_bssid="$new_target_bssid"
  #   strongest_signal="$new_strongest_signal"
  #   connect_to_network "$target_bssid"
  # else
  #   echo "No stronger network with SSID $target_ssid found"
  # fi
  
  # Wait for some time before the next scan
  sleep 8
done
