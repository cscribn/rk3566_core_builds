#!/bin/bash

#Copyright 2023 Christian_Haitian
#
#Permission is hereby granted, free of charge, to any person 
#obtaining a copy of this software and associated documentation
#files (the “Software”), to deal in the Software without 
#restriction, including without limitation the rights to use,
#copy, modify, merge, publish, distribute, sublicense, and/or
#sell copies of the Software, and to permit persons to whom
#the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included 
#in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
#EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
#DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
#OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
#THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#
# Local NetPlay Setup
#

sudo chmod 666 /dev/tty1
printf "\033c" > /dev/tty1

# hide cursor
#printf "\e[?25l" > /dev/tty1
dialog --clear

if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
  sudo setfont /usr/share/consolefonts/Lat7-TerminusBold28x14.psf.gz
fi

height="15"
width="55"

if test ! -z "$(cat /home/ark/.config/.DEVICE | grep RG503 | tr -d '\0')"
then
  height="20"
  width="60"
fi

ExitCode="0"

export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
  sudo setfont /usr/share/consolefonts/Lat7-TerminusBold20x10.psf.gz
fi

pgrep -f gptokeyb | sudo xargs kill -9
pgrep -f osk.py | sudo xargs kill -9
printf "\033c" > /dev/tty1
printf "Starting Local Netplay Session Manager.  Please wait..." > /dev/tty1
old_ifs="$IFS"

ExitMenu() {
  printf "\033c" > /dev/tty1
  if [[ ! -z $(pgrep -f gptokeyb) ]]; then
    pgrep -f gptokeyb | sudo xargs kill -9
  fi
  if [[ ! -z $(pgrep -f gptokeyb) ]]; then
    pgrep -f gptokeyb | sudo xargs kill -9
  fi
  exit ${ExitCode}
}

Select() {
  KEYBOARD="osk"

  pgrep -f gptokeyb | sudo xargs kill -9
  # get password from input
  if [[ "$1" == *"ArkOS_"* ]]; then
   PASS="Ark0s11o52o23"
  else
    pgrep -f gptokeyb | sudo xargs kill -9
    PASS=`$KEYBOARD "Enter the local netplay session password for $1" | tail -n 1`
    /opt/inttools/gptokeyb -1 "netplay.sh" -c "/opt/inttools/keys.gptk" & > /dev/null
  fi

  dialog --infobox "\nConnecting to local network named $1..." 5 $width > /dev/tty1
  clist2=`sudo nmcli -f ALL --mode tabular --terse --fields IN-USE,SSID,CHAN,SIGNAL,SECURITY dev wifi`
  WPA3=`echo "$clist2" | grep "$1" | grep "WPA3"`

  # try to connect
  output=`nmcli con delete "$1"`
  if [[ "$WPA3" != *"WPA3"* ]]; then
    output=`nmcli device wifi connect "$1" password "$PASS"`
  else
    #workaround for wpa2/wpa3 connectivity
    output=`nmcli device wifi connect "$1" password "$PASS"`
    sudo sed -i '/key-mgmt\=sae/s//key-mgmt\=wpa-psk/' /etc/NetworkManager/system-connections/"$1".nmconnection
    sudo systemctl restart NetworkManager
    sleep 5
    output=`nmcli con up "$1"`
  fi
  success=`echo "$output" | grep successfully`

  if [ -z "$success" ] && [[ "$PASS" == "Ark0s11o52o23" ]]; then
    pgrep -f gptokeyb | sudo xargs kill -9
    PASS=`$KEYBOARD "Enter the local netplay session password for $1" | tail -n 1`
    /opt/inttools/gptokeyb -1 "netplay.sh" -c "/opt/inttools/keys.gptk" & > /dev/null
    dialog --infobox "\nConnecting to local network named $1..." 5 $width > /dev/tty1
    clist2=`sudo nmcli -f ALL --mode tabular --terse --fields IN-USE,SSID,CHAN,SIGNAL,SECURITY dev wifi`
    WPA3=`echo "$clist2" | grep "$1" | grep "WPA3"`

    # try to connect
    output=`nmcli con delete "$1"`
    if [[ "$WPA3" != *"WPA3"* ]]; then
      output=`nmcli device wifi connect "$1" password "$PASS"`
    else
      #workaround for wpa2/wpa3 connectivity
      output=`nmcli device wifi connect "$1" password "$PASS"`
      sudo sed -i '/key-mgmt\=sae/s//key-mgmt\=wpa-psk/' /etc/NetworkManager/system-connections/"$1".nmconnection
      sudo systemctl restart NetworkManager
      sleep 5
      output=`nmcli con up "$1"`
    fi
    success=`echo "$output" | grep successfully`
    if [ -z "$success" ]; then
      output="Activation failed: Secrets were required, but not provided ..."
      sudo rm -f /etc/NetworkManager/system-connections/"$1".nmconnection
      MainMenu
    else
      output="Device successfully activated and connected $1 ..."
      sudo rm -f /etc/NetworkManager/system-connections/"$1".nmconnection
    fi
  elif [ -z "$success" ]; then
    output="Activation failed: Secrets were required, but not provided ..."
    sudo rm -f /etc/NetworkManager/system-connections/"$1".nmconnection
    MainMenu
  else
    output="Device successfully activated and connected $1 ..."
    sudo rm -f /etc/NetworkManager/system-connections/"$1".nmconnection
  fi

  dialog --infobox "\n$output" 6 $width > /dev/tty1
  sleep 3
  ExitCode="138"
  ExitMenu
}

Host() {

  dialog --infobox "\nSetting up local netplay session ..." 5 $width > /dev/tty1

  sleep 1

  output=`arkos_ap_mode.sh Enable $1`

  success=`echo "$output" | grep Success`

  if [ -z "$success" ]; then
    output="Failed setting up hosting for the local netplay session."
    MainMenu
  else
    output="Host setup for local netplay session is now ready!"
    ExitCode="250"
  fi

  dialog --infobox "\n$output" 6 $width > /dev/tty1
  sleep 3
  ExitMenu
}

StopHost() {

  dialog --infobox "\nDisabling local hosting of netplay session ..." 5 $width > /dev/tty1

  sleep 1

  output=`arkos_ap_mode.sh Disable`

  success=`echo "$output" | grep Success`

  if [ -z "$success" ]; then
    output="Failed disabling hosting for the local netplay session."
  else
    output="Hosting for the local netplay session is now disabled!"
  fi

  dialog --infobox "\n$output" 6 $width > /dev/tty1
  sleep 3
  MainMenu
}

Client() {

  dialog --infobox "\nLooking for $1 ArkOS NetPlay session ..." 5 $width > /dev/tty1
  sleep 1
  clist=`sudo nmcli -f ALL --mode tabular --terse --fields IN-USE,SSID,CHAN,SIGNAL,SECURITY dev wifi`
  if [ -z "$clist" ]; then
    clist=`sudo nmcli -f ALL --mode tabular --terse --fields IN-USE,SSID,CHAN,SIGNAL,SECURITY dev wifi`
  fi

  if [ -z "$(echo $clist | grep $1)" ]; then
    dialog --infobox "\nCould not find the $1 ArkOS NetPlay session" 5 $width > /dev/tty1
    sleep 3
    MainMenu
  else
    Select ArkOS_AP_"$1"
  fi
  # Set colon as the delimiter
  #IFS=':'
  #unset coptions
  #while IFS= read -r clist; do
    # Read the split words into an array based on colon delimiter
  #  read -a strarr <<< "$clist"

  #  INUSE=`printf '%-5s' "${strarr[0]}"`
  #  SSID="${strarr[1]}"
  #  CHAN=`printf '%-5s' "${strarr[2]}"`
  #  SIGNAL=`printf '%-5s' "${strarr[3]}%"`
  #  SECURITY="${strarr[4]}"

  #  coptions+=("$SSID" "$INUSE $CHAN $SIGNAL $SECURITY")
  #done <<< "$clist"

  #while true; do
  #  cselection=(dialog \
  # 	--backtitle "Available Connections" \
  # 	--title "SSID  IN-USE  CHANNEL  SIGNAL  SECURITY" \
  # 	--no-collapse \
  # 	--clear \
  #     --cancel-label "Back" \
  #     --menu "" $height $width 15)

  #  cchoices=$("${cselection[@]}" "${coptions[@]}" 2>&1 > /dev/tty1) || MainMenu

  #  for cchoice in $cchoices; do
  #    case $cchoice in
  #      *) Select $cchoice ;;
  #    esac
  #  done
  #done
}

LessBusyChannel() {
  if [[ ! -z $(cat /etc/hostapd/hostapd.conf | grep "hw_mode=g") ]]; then
    AvailChannels=( "2412" "2437" "2462" )
    Channels=( "Channel1" "Channel6" "Channel11" )
    AreaChannels=`timeout 6s sudo iw dev wlan0 scan | grep -E '24(12|37|62)'`
    i=0
    for ChannelCheck in ${AvailChannels[@]}
    do
       Channels[$i]=$(echo "$AreaChannels" | grep -o "$ChannelCheck" | wc -l)
       let i++
    done

    Position=$(echo "${Channels[@]}" | tr -s ' ' '\n' | awk '{print($0" "NR)}' | sort -g -k1,1 | head -1 | cut -f2 -d' ')
    case $Position in
       1) BestChannel=1
       ;;
       2) BestChannel=6
       ;;
       3) BestChannel=11
       ;;
       *) BestChannel=6
       ;;
    esac
  else
    AvailChannels=( "5180" "5220" "5745" "5765" "5785" )
    Channels=( "Channel36" "Channel44" "Channel149" "Channel153" "Channel157" )
    AreaChannels=`timeout 6s sudo iw dev wlan0 scan | grep -E '5(180|220|745|765|785)'`
    i=0
    for ChannelCheck in ${AvailChannels[@]}
    do
       Channels[$i]=$(echo "$AreaChannels" | grep -o "$ChannelCheck" | wc -l)
       let i++
    done

    Position=$(echo "${Channels[@]}" | tr -s ' ' '\n' | awk '{print($0" "NR)}' | sort -g -k1,1 | head -1 | cut -f2 -d' ')
    case $Position in
       1) BestChannel=36
       ;;
       2) BestChannel=44
       ;;
       3) BestChannel=149
       ;;
       4) BestChannel=153
       ;;
       5) BestChannel=157
       ;;
       *) BestChannel=44
       ;;
    esac
  fi
}

Settings() {
  if [[ ! -z $(cat /etc/hostapd/hostapd.conf | grep "hw_mode=a") ]]; then
    local curapmodecfg="Switch to 2.4Ghz AP Mode"
    local curapmode="5"
  else
    local curapmodecfg="Switch to 5Ghz AP Mode"
    local curapmode="2.4"
  fi

  local settingsoptions=( 1 "$curapmodecfg" 2 "Set less busy channel for AP Mode" 3 "Go Back" )

  while true; do
    settingsselection=(dialog \
    --backtitle "NetPlay Session: Current AP Mode: ${curapmode}Ghz | Current Channel: $(cat /etc/hostapd/hostapd.conf | grep -oP "(?<=channel=).*")" \
    --title "[ Settings Menu ]" \
    --no-collapse \
    --clear \
    --cancel-label "Select + Start to Exit" \
    --menu "What do you want to do?" $height $width 15)

  settingschoices=$("${settingsselection[@]}" "${settingsoptions[@]}" 2>&1 > /dev/tty1) || TopLevel

    for choice in $settingschoices; do
      case $choice in
        1) if [[ $curapmodecfg == "Switch to 2.4Ghz AP Mode" ]]; then
             sudo sed -i "/hw_mode\=/c\hw_mode\=g" /etc/hostapd/hostapd.conf
             dialog --infobox "\nSwitching to 2.4Ghz AP Mode..." 5 $width > /dev/tty1
             LessBusyChannel
             sudo sed -i "/channel\=/c\channel\=$BestChannel" /etc/hostapd/hostapd.conf
             systemctl is-active --quiet hostapd.service && sudo systemctl restart hostapd.service
             dialog --clear --backtitle "AP Mode has been set to 2.4Ghz" --title "[ Settings Menu ]" --clear --msgbox "\n\nAP Mode has been set to 2.4Ghz" $height $width 2>&1 > ${CUR_TTY}
           else
             sudo sed -i "/hw_mode\=/c\hw_mode\=a" /etc/hostapd/hostapd.conf
             dialog --infobox "\nSwitching to 5Ghz AP Mode..." 5 $width > /dev/tty1
             LessBusyChannel
             sudo sed -i "/channel\=/c\channel\=$BestChannel" /etc/hostapd/hostapd.conf
             systemctl is-active --quiet hostapd.service && sudo systemctl restart hostapd.service
             dialog --clear --backtitle "AP Mode has been set to 5Ghz" --title "[ Settings Menu ]" --clear --msgbox "\n\nAP Mode has been set to 5Ghz" $height $width 2>&1 > ${CUR_TTY}
           fi
           Settings
        ;;
        2)dialog --infobox "\nFinding a less busy wireless channel in your current area..." 5 $width > /dev/tty1
          LessBusyChannel
          sudo sed -i "/channel\=/c\channel\=$BestChannel" /etc/hostapd/hostapd.conf
          dialog --infobox "\nAP Mode channel has now been set to $BestChannel" 5 $width > /dev/tty1
          sleep 3
          Settings
        ;;
        3) MainMenu
        ;;
        esac
      done
    done
}

MainMenu() {
  mainoptions=( 1 "Host a local Netplay Session" 2 "Stop hosting a local Netplay Session" 3 "Connect to a local Netplay Session" 4 "Settings" 5 "Exit" )
  IFS="$old_ifs"
  while true; do
    mainselection=(dialog \
   	--backtitle "Netplay Session: $1" \
   	--title "Main Menu" \
   	--no-collapse \
   	--clear \
	--cancel-label "Select + Start to Exit" \
	--menu "Please make your selection" $height $width 15)

	mainchoices=$("${mainselection[@]}" "${mainoptions[@]}" 2>&1 > /dev/tty1)

    for mchoice in $mainchoices; do
      case $mchoice in
	1) Host $1 ;;
	2) StopHost ;;
	3) Client $1 ;;
	4) Settings ;;
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
/opt/inttools/gptokeyb -1 "netplay.sh" -c "/opt/inttools/keys.gptk" &
printf "\033c" > /dev/tty1
dialog --clear

if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
  sudo setfont /usr/share/consolefonts/Lat7-TerminusBold20x10.psf.gz
fi

MainMenu $1
