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
	echo -e "current value : ${!2}"
	echo "enter new value ('n' to leave unchanged) :"
	read NEWVALUE
	if [ "$NEWVALUE" = 'n' ];then
	  echo "value unchanged"
	  return
	fi
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
red='\e[31m'
green='\e[32m'
blue='\e[34m'
cyan='\e[36m'
yellow='\e[93m'
magenta='\e[35m'
clear='\e[0m'
ColorRed(){
	echo -ne $red$1$clear
}
ColorGreen(){
	echo -ne $green$1$clear
}
ColorBlue(){
	echo -ne $blue$1$clear
}
ColorCyan(){
	echo -ne $cyan$1$clear
}
ColorYellow(){
	echo -ne $yellow$1$clear
}
ColorMagenta(){
	echo -ne $magenta$1$clear
}

menu(){
echo -ne "
---------------------------------------
=== Valheim Server Monitoring - VSM ===
$(ColorGreen '1)') setup $(ColorYellow 'current') Valheim server directory
$(ColorGreen '2)') setup $(ColorCyan 'wanted') Valheim server logs directory
$(ColorRed 'Please, pipe your valheim server start script on ./valheim-logs.filter or use my launcher')
$(ColorGreen '3)') setup $(ColorCyan 'wanted') Valheim server status over HTTP port
$(ColorGreen '4)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook ID
$(ColorGreen '5)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook token
$(ColorGreen '6)') setup $(ColorCyan 'wanted') last logs on your $(ColorMagenta 'Discord') channel
$(ColorGreen '7)') force $(ColorMagenta 'Discord') webhook update
$(ColorGreen '8)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook status message id
$(ColorGreen '9)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook last logs message id

=== Setting up custom launcher ===
$(ColorGreen '10)') setup $(ColorCyan 'wanted') Valheim server listening port


$(ColorGreen '0)') quit
$(ColorBlue 'choose an option:') "
        read a
        case $a in
	        1) setup_value_prompt 'where is your dedicated server ?' 'VHSERVERDIR' ; menu ;;
	        2) setup_value_prompt 'where do you want to put logs ?' 'VALHEIMSERVERLOGSDIR' ; menu ;;
	        3) setup_value_prompt 'on which port do you want to provide your server status ?' 'STATUSPORT' ; menu ;;
	        4) setup_value_prompt "what's your $(ColorMagenta 'Discord') webhook id ?" 'WEBHOOKID' ; menu ;;
	        5) setup_value_prompt "what's your $(ColorMagenta 'Discord') webhook token ?" 'WEBHOOKTOKEN' ; menu ;;
	        6) setup_value_prompt "how many logs do you want on your $(ColorMagenta 'Discord') ? set '0' if you dont want any" 'SENDLASTLOGS' ; menu ;;
	        7) $CWD/discord/update ; menu ;;
	        8) setup_value_prompt "what's the $(ColorMagenta 'Discord') webhook status message id ?" 'STATUSMESSAGEID' ; menu ;;
	        9) setup_value_prompt "what's the $(ColorMagenta 'Discord') webhook 'last logs' message id ?" 'LASTLOGMESSAGEID' ; menu ;;
		0) exit 0 ;;
		*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

# Call the menu function
menu