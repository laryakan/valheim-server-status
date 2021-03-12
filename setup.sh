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
$(ColorRed 'Please, pipe your valheim server start script on ./valheim-logs.filter or use my launcher, starting at 10)')
$(ColorGreen '1)') setup $(ColorCyan 'wanted') Valheim server logs directory
$(ColorGreen '2)') setup $(ColorCyan 'wanted') Valheim server status over HTTP port

=> Setting up $(ColorMagenta 'Discord') webhook <==
$(ColorRed 'Remember to first create your webhook on Discord and activate developer mode (appereance menu)')
$(ColorGreen '3)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook ID
$(ColorGreen '4)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook token
$(ColorGreen '5)') setup 'how many' $(ColorCyan 'wanted') last logs on your $(ColorMagenta 'Discord') channel
$(ColorGreen '6)') force $(ColorMagenta 'Discord') webhook update
$(ColorGreen '7)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook status message id
$(ColorGreen '8)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook last logs message id

=> Setting up custom launcher <==
$(ColorGreen '10)') setup $(ColorYellow 'current') Valheim server directory
$(ColorGreen '11)') setup $(ColorCyan 'wanted') Valheim server listening port
$(ColorGreen '12)') setup $(ColorCyan 'wanted') Valheim server name
$(ColorGreen '13)') setup $(ColorCyan 'wanted') Valheim server world name
$(ColorGreen '14)') setup $(ColorCyan 'wanted') Valheim server password
$(ColorBlue 'You can find the launcher inside "launcher" directory or create a service')

=> Advanced options, may require sudo <==
$(ColorGreen '20)') setup $(ColorMagenta 'Discord') webhook update cron
$(ColorGreen '21)') setup a a logrotate
$(ColorGreen '22)') setup a Valheim server systemd service
$(ColorGreen '23)') setup a Valheim server status over HTTP systemd service

$(ColorGreen '0)') quit
$(ColorBlue 'choose an option:') "
        read a
        case $a in
	        1) setup_value_prompt 'where do you want to put logs ?' 'VALHEIMSERVERLOGSDIR' ; menu ;;
	        2) setup_value_prompt 'on which port do you want to provide your server status ?' 'STATUSPORT' ; menu ;;
	        3) setup_value_prompt "what's your $(ColorMagenta 'Discord') webhook id ?" 'WEBHOOKID' ; menu ;;
	        4) setup_value_prompt "what's your $(ColorMagenta 'Discord') webhook token ?" 'WEBHOOKTOKEN' ; menu ;;
	        5) setup_value_prompt "how many logs do you want on your $(ColorMagenta 'Discord') ? set '0' if you dont want any" 'SENDLASTLOGS' ; menu ;;
	        6) $CWD/discord/update ; menu ;;
	        7) setup_value_prompt "what's the $(ColorMagenta 'Discord') webhook status message id ?" 'STATUSMESSAGEID' ; menu ;;
	        8) setup_value_prompt "what's the $(ColorMagenta 'Discord') webhook 'last logs' message id ?" 'LASTLOGMESSAGEID' ; menu ;;
	        10) setup_value_prompt 'where is located your dedicated server ?' 'VHSERVERDIR' ; menu ;;
	        11) setup_value_prompt 'on which port do you want your server to listen (default: 2456) ?' 'VHSERVERPORT' ; menu ;;
	        12) setup_value_prompt 'what is your $(ColorYellow 'current') or $(ColorCyan 'wanted')  Valheim server name ?' 'VHSERVERNAME' ; menu ;;
	        13) setup_value_prompt "what is your Valheim World name ? $(ColorRed 'If you already have a server, put its World name here')" 'VHSERVERWORLD' ; menu ;;
	        14) setup_value_prompt 'what is your $(ColorYellow 'current') or $(ColorCyan 'wanted')  Valheim server password ?' 'VHSERVERPASSWD' ; menu ;;
	        20) echo "not yet implemented, you can add it manually with \e[1mcrontab -e\e[21" ; menu ;;
	        21) echo "not yet implemented, you can find examples in the example directory" ; menu ;;
	        22) echo "not yet implemented, you can find examples in the example directory" ; menu ;;
	        23) echo "not yet implemented, you can find examples in the example directory" ; menu ;;
		0) exit 0 ;;
		*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

# Call the menu function
menu