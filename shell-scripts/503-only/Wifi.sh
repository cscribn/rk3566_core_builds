#!/bin/bash
#sudo nmui

# Copyright (c) 2021
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA
#
# Authored by: Kris Henriksen <krishenriksen.work@gmail.com>
# Thanks to Quack for modifications to account for SSIDs with spaces
#
# Wi-Fi-dialog
#

sudo chmod 666 /dev/tty1
printf "\033c" > /dev/tty1

# hide cursor
printf "\e[?25l" > /dev/tty1
dialog --clear

height="15"
width="55"

if test ! -z "$(cat /home/ark/.config/.DEVICE | grep RG503 | tr -d '\0')"
then
  height="20"
  width="60"
fi

export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
  sudo setfont /usr/share/consolefonts/Lat7-TerminusBold20x10.psf.gz
fi

pgrep -f gptokeyb | sudo xargs kill -9
pgrep -f osk.py | sudo xargs kill -9
printf "\033c" > /dev/tty1
printf "Starting Wifi Manager.  Please wait..." > /dev/tty1
#sudo systemctl stop networkwatchdaemon
#sudo systemctl start NetworkManager

#cur_ap=`iw dev wlan0 info | grep ssid | cut -c 7-30`
old_ifs="$IFS"

ExitMenu() {
  printf "\033c" > /dev/tty1
  if [[ ! -z $(pgrep -f gptokeyb) ]]; then
    pgrep -f gptokeyb | sudo xargs kill -9
  fi
  if [[ ! -z $(pgrep -f gptokeyb) ]]; then
    pgrep -f gptokeyb | sudo xargs kill -9
  fi
#  unset SDL_GAMECONTROLLERCONFIG_FILE
  exit 0
}

DeleteConnect() {
  cur_ap=`iw dev wlan0 info | grep ssid | cut -c 7-30`
  dialog --clear --backtitle "Delete Connection: Currently connected to $cur_ap" --title "Removing $1" --clear \
  --yesno "\nWould you like to continue to remove this connection?" $height $width 2>&1 > /dev/tty1

  case $? in
     0) sudo rm -f "/etc/NetworkManager/system-connections/$1.nmconnection" ;;
  esac

  Delete
}

Activate() {

  cur_ap=`iw dev wlan0 info | grep ssid | cut -c 7-30`

  declare aoptions=()
  while IFS= read -r -d $'\n' ssid; do
    aoptions+=("$ssid" ".")
  done < <(ls -1 /etc/NetworkManager/system-connections/ | rev | cut -c 14- | rev | sed -e 's/$//')

  while true; do
    aselection=(dialog \
   	--backtitle "Existing Connections: Currently connected to $cur_ap" \
   	--title "Which existing connection would you like to connect to?" \
   	--no-collapse \
   	--clear \
	--cancel-label "Back" \
    --menu "" $height $width 15)

    achoice=$("${aselection[@]}" "${aoptions[@]}" 2>&1 > /dev/tty1) || MainMenu

    # There is only one choice possible
    ConnectExisting "$achoice"
  done  

}

Select() {
  KEYBOARD="osk"

  pgrep -f gptokeyb | sudo xargs kill -9
  # get password from input
  PASS=`$KEYBOARD "Enter Wi-Fi password for $1" | tail -n 1`
  /opt/inttools/gptokeyb -1 "Wifi.sh" -c "/opt/inttools/keys.gptk" & > /dev/null

  dialog --infobox "\nConnecting to Wi-Fi $1 ..." 5 $width > /dev/tty1
  clist2=`sudo nmcli -f ALL --mode tabular --terse --fields IN-USE,SSID,CHAN,SIGNAL,SECURITY dev wifi`
  WPA3=`echo "$clist2" | grep "$1" | grep "WPA3"`

  # try to connect
  output=`nmcli con delete "$1"`
  if [[ "$WPA3" != *"WPA3"* ]]; then
    output=`nmcli device wifi connect "$1" password "$PASS"`
  else
    #workaround for wpa2/wpa3 connectivity
    output=`nmcli device wifi connect "$1" password "$PASS"`
    #sudo sed -i '/psk=/a sae-password='"$PASS"'\nieee80211w=1' /etc/NetworkManager/system-connections/"$1".nmconnection
    sudo sed -i '/key-mgmt\=sae/s//key-mgmt\=wpa-psk/' /etc/NetworkManager/system-connections/"$1".nmconnection
    sudo systemctl restart NetworkManager
    sleep 5
    output=`nmcli con up "$1"`
  fi
  success=`echo "$output" | grep successfully`

  if [ -z "$success" ]; then
    output="Activation failed: Secrets were required, but not provided ..."
    sudo rm -f /etc/NetworkManager/system-connections/"$1".nmconnection
  else
    output="Device successfully activated and connected to Wi-Fi ..."
    cur_ap=`iw dev wlan0 info | grep ssid | cut -c 7-30`
  fi
  
  dialog --infobox "\n$output" 6 $width > /dev/tty1
  sleep 3
  Connect
}

ConnectExisting() {
  cur_ap=`iw dev wlan0 info | grep ssid | cut -c 7-30`

  dialog --infobox "\nConnecting to Wi-Fi $1 ..." 5 $width > /dev/tty1

  nmcli con down "$cur_ap" >> /dev/null
  sleep 1

  output=`nmcli con up "$1"`

  success=`echo "$output" | grep successfully`

  if [ -z "$success" ]; then
    output="Failed to connect to $1"
  else
    output="Device successfully activated and connected to $1"
	cur_ap=`iw dev wlan0 info | grep ssid | cut -c 7-30`
  fi
  
  dialog --infobox "\n$output" 6 $width > /dev/tty1
  sleep 3
  Activate
}

Connect() {
  dialog --infobox "\nScanning available Wi-Fi access points ..." 5 $width > /dev/tty1
  sleep 1
  clist=`sudo nmcli -f ALL --mode tabular --terse --fields IN-USE,SSID,CHAN,SIGNAL,SECURITY dev wifi`
  if [ -z "$clist" ]; then
    clist=`sudo nmcli -f ALL --mode tabular --terse --fields IN-USE,SSID,CHAN,SIGNAL,SECURITY dev wifi`
  fi
  cur_ap=`iw dev wlan0 info | grep ssid | cut -c 7-30`

  # Set colon as the delimiter
  IFS=':'
  unset coptions
  while IFS= read -r clist; do
    # Read the split words into an array based on colon delimiter
    read -a strarr <<< "$clist"

    INUSE=`printf '%-5s' "${strarr[0]}"`
    SSID="${strarr[1]}"
    CHAN=`printf '%-5s' "${strarr[2]}"`
    SIGNAL=`printf '%-5s' "${strarr[3]}%"`
    SECURITY="${strarr[4]}"

    coptions+=("$SSID" "$INUSE $CHAN $SIGNAL $SECURITY")
  done <<< "$clist"

  while true; do
    cselection=(dialog \
   	--backtitle "Available Connections: Currently connected to $cur_ap" \
   	--title "SSID  IN-USE  CHANNEL  SIGNAL  SECURITY" \
   	--no-collapse \
   	--clear \
	--cancel-label "Back" \
    --menu "" $height $width 15)

    cchoices=$("${cselection[@]}" "${coptions[@]}" 2>&1 > /dev/tty1) || MainMenu

    for cchoice in $cchoices; do
      case $cchoice in
        *) Select $cchoice ;;
      esac
    done
  done
}

Delete() {
  #deloptions=( $(ls -1 /etc/NetworkManager/system-connections/ | rev | cut -c 14- | rev | sed 's/^/"/;s/$/"/' | sed -e 's/$/ ./') )
  declare deloptions=()
  while IFS= read -r -d $'\n' ssid; do
    deloptions+=("$ssid" ".")
  done < <(ls -1 /etc/NetworkManager/system-connections/ | rev | cut -c 14- | rev | sed -e 's/$//')

  cur_ap=`iw dev wlan0 info | grep ssid | cut -c 7-30`

  while true; do
    delselection=(dialog \
   	--backtitle "Existing Connections: Currently connected to $cur_ap" \
   	--title "Which connection would you like to delete?" \
   	--no-collapse \
   	--clear \
	--cancel-label "Back" \
    --menu "" $height $width 15)

    # There is only a single choice possible
    delchoice=$("${delselection[@]}" "${deloptions[@]}" 2>&1 > /dev/tty1) || MainMenu
    DeleteConnect "$delchoice"
  done  
}

NetworkInfo() {

  gateway=`ip r | grep default | awk '{print $3}'`
  currentip=`ip -f inet addr show wlan0 | sed -En -e 's/.*inet ([0-9.]+).*/\1/p'`
  currentssid=`iw dev wlan0 info | grep ssid | cut -c 7-30`
  currentdns=`( nmcli dev list || nmcli dev show ) 2>/dev/null | grep DNS | awk '{print $2}'`

  dialog --clear --backtitle "Your Network Information" --title "" --clear \
  --msgbox "\n\nSSID: $cur_ap\nIP: $currentip\nGateway: $gateway\nDNS: $currentdns" $height $width 2>&1 > /dev/tty1
}

MainMenu() {
  mainoptions=( 1 "Connect to new Wifi connection" 2 "Activate existing Wifi Connection" 3 "Delete exiting connections" 4 "Current Network Info" 5 "Exit" )
  cur_ap=`iw dev wlan0 info | grep ssid | cut -c 7-30`
  IFS="$old_ifs"
  while true; do
    mainselection=(dialog \
   	--backtitle "Wifi Manager: Currently connected to $cur_ap" \
   	--title "Main Menu" \
   	--no-collapse \
   	--clear \
	--cancel-label "Select + Start to Exit" \
    --menu "Please make your selection" $height $width 15)
	
	mainchoices=$("${mainselection[@]}" "${mainoptions[@]}" 2>&1 > /dev/tty1)

    for mchoice in $mainchoices; do
      case $mchoice in
        1) Connect ;;
		2) Activate ;;
		3) Delete ;;
		4) NetworkInfo ;;
		5) ExitMenu ;;
      esac
    done
  done
}

#
# Joystick controls
#
# only one instance

sudo chmod 666 /dev/uinput
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
if [[ ! -z $(pgrep -f gptokeyb) ]]; then
  pgrep -f gptokeyb | sudo xargs kill -9
fi
/opt/inttools/gptokeyb -1 "Wifi.sh" -c "/opt/inttools/keys.gptk" &
printf "\033c" > /dev/tty1
dialog --clear

MainMenu
