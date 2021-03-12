#!/bin/bash
# author: laryakan, date 2021/03/12
# Basic env init
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$CWD/env.sh"
# VSM Setup menu
function setup_vhserverdir() {
  echo ""
	echo '**Valheim Server Directory**'
	echo "example : /home/steam/vhserver"
	echo "current value : $VHSERVERDIR"
	read VHSERVERDIR
	echo $VHSERVERDIR
	echo ""
}

function show_config() {
  // TODO
}

##
# Colors
##
green='\e[32m'
blue='\e[34m'
clear='\e[0m'
ColorGreen(){
	echo -ne $green$1$clear
}
ColorBlue(){
	echo -ne $blue$1$clear
}

menu(){
echo -ne "
---------------------------------
=== Valheim Server Monitoring ===
$(ColorGreen '1)') Setup Valheim Server Directory
$(ColorGreen '0)') Quit
$(ColorBlue 'Choose an option:') "
        read a
        case $a in
	        1) setup_vhserverdir ; menu ;;
		0) exit 0 ;;
		*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

# Call the menu function
menu