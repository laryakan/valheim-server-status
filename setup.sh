#!/bin/bash
# author: laryakan, date 2021/03/12
# Basic env init
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ ! -f "$CWD/.env" ]
then
  cp "$CWD/.env.dist" "$CWD/.env"
fi
source "$CWD/.env"
# VSM Setup menu
function replace_env_value() {
  cat "$CWD/.env"|grep "$1="|xargs -I {} -t sed -i "s~{}~$1=\"$2\"~ig" "$CWD/.env"
  source "$CWD/.env"
}

# param1=value_label, param2=value_variable_in_.env
function setup_value_prompt() {
  echo ""
	echo "**$1**"
	echo "current value : ${!2}"
	echo "enter new value :"
	read NEWVALUE
	replace_env_value "$2" "$NEWVALUE"
	echo "new value set : ${!2}"
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
	        1) setup_value_prompt 'Valheim Server Directory' 'VHSERVERDIR' ; menu ;;
		0) exit 0 ;;
		*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

# Call the menu function
menu