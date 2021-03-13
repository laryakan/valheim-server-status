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

# env conf value changing function
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

# Setup cron
function set_cron() {
	# Check a and old cron exists
	$OLDLINE="$( crontab -l | grep "$WEBHOOKUPDATE" )"
	if [ ! -z "$OLDLINE" ]
	then
		if [ $CRONTABWEBHOOKFREQ -eq 0 ]
		then
			# remove line
			crontab -l 2>/dev/null | grep -v "$OLDLINE" | crontab -
		else 
			# remove line, add new one
			(crontab -l 2>/dev/null | grep -v "$OLDLINE" ; echo "*/$CRONTABWEBHOOKFREQ * * * * $WEBHOOKUPDATE") | crontab -
		fi
	else
		if [ $CRONTABWEBHOOKFREQ -gt 0 ]
		then
			# add new one
			(crontab -l 2>/dev/null ; echo "*/$CRONTABWEBHOOKFREQ * * * * $WEBHOOKUPDATE") | crontab -
		fi
	fi
	echo "crontab updated, you can check it with *crontab -l*, edit with *crontab -e*"
}

# Setup service with conf values
function set_service(){
	// TODO
}

# Setup service with conf values
function set_logrotate(){
	// TODO
}

# Show actual conf
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

service_menu(){
clear
echo -ne "
---------------------------------------
=== Valheim Server Monitoring - VSM ===
*** Service menu ***
$(ColorGreen '1)') setup a user for executing services
$(ColorGreen '2)') setup Valheim server launcher (recommended to user default custom launcher)

=> Advanced options <=
$(ColorGreen '10)') $(ColorRed 'sudo required'), activate logrotate on Valheim server logs
$(ColorGreen '11)') $(ColorRed 'sudo required'), desactivate logrotate on Valheim server logs
$(ColorGreen '20)') $(ColorRed 'sudo required'), update and activate valheim-server.service
$(ColorGreen '21)') $(ColorRed 'sudo required'), update and activate vsm.http.service (server status over HTTP)

$(ColorGreen '0)') return to previous menu
$(ColorBlue 'choose an option:') "
mkdir "$CWD/systemd"
        read a
        case $a in
	        1) setup_value_prompt 'whats the user you want to execute service ?' 'VALHEIMSERVERLOGSDIR' ; service_menu ;;
			2) setup_value_prompt 'which launcher do you want to use ? remember to put server output on valheim-logs.filter stdin' 'VHSERVERLAUNCHER' ; service_menu ;;
			10) set_logrotate 1 ; service_menu ;;
			11) set_logrotate 0 ; service_menu ;;
			20) set_service 'valheim-server.service'; service_menu ;;
			21) set_service 'vsm.http.service'; service_menu ;;

		0) menu ;;
		*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

menu(){
clear
echo -ne "
---------------------------------------
=== Valheim Server Monitoring - VSM ===
$(ColorBlue 'If it\'s a new install, follow steps in order. If you have setted things manually for version <2, please reset your server state')
$(ColorRed 'Please, pipe your valheim server start script (launcher) on ./valheim-logs.filter or use my launcher, starting at 10)')
$(ColorGreen '1)') setup $(ColorCyan 'wanted') Valheim server logs directory
$(ColorGreen '2)') setup $(ColorCyan 'wanted') Valheim server status over HTTP port
$(ColorBlue 'You can find the script to launch VSM HTTP in status directory, or create a service in service menu')

=> Setting up $(ColorMagenta 'Discord') webhook <==
$(ColorRed 'Remember to first create your webhook on Discord and activate developer mode (appereance menu)')
$(ColorGreen '3)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook URL
$(ColorGreen '4)') setup 'how many' $(ColorCyan 'wanted') last logs on your $(ColorMagenta 'Discord') channel
$(ColorGreen '5)') force $(ColorMagenta 'Discord') webhook update
$(ColorGreen '6)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook status message id
$(ColorGreen '7)') setup $(ColorYellow 'current') $(ColorMagenta 'Discord') webhook last logs message id

=> Setting up custom launcher <==
$(ColorGreen '10)') setup $(ColorYellow 'current') Valheim server directory
$(ColorGreen '11)') setup $(ColorCyan 'wanted') Valheim server listening port
$(ColorGreen '12)') setup $(ColorCyan 'wanted') Valheim server name
$(ColorGreen '13)') setup $(ColorCyan 'wanted') Valheim server world name
$(ColorGreen '14)') setup $(ColorCyan 'wanted') Valheim server password
$(ColorBlue 'You can find the launcher inside "launcher" directory, or create a service')

=> Advanced options <==
$(ColorGreen '20)') setup $(ColorMagenta 'Discord') webhook update cron frequency
$(ColorGreen '30)') $(ColorRed 'sudo required'), service menu

$(ColorGreen '0)') quit
$(ColorBlue 'choose an option:') "
        read a
        case $a in
	        1) setup_value_prompt 'where do you want to put logs ?' 'VALHEIMSERVERLOGSDIR' ; menu ;;
	        2) setup_value_prompt 'on which port do you want to provide your server status ?' 'STATUSPORT' ; menu ;;
			3) setup_value_prompt "what's your $(ColorMagenta 'Discord') webhook url ?" 'WEBHOOKURL' ; menu ;;
	        4) setup_value_prompt "how many logs do you want on your $(ColorMagenta 'Discord') ? set '0' if you dont want any" 'SENDLASTLOGS' ; menu ;;
	        5) $CWD/discord/update ; menu ;;
	        6) setup_value_prompt "what's the $(ColorMagenta 'Discord') webhook status message id ?" 'STATUSMESSAGEID' ; menu ;;
	        7) setup_value_prompt "what's the $(ColorMagenta 'Discord') webhook 'last logs' message id ?" 'LASTLOGMESSAGEID' ; menu ;;
	        10) setup_value_prompt 'where is located your dedicated server ?' 'VHSERVERDIR' ; menu ;;
	        11) setup_value_prompt 'on which port do you want your server to listen (default: 2456) ?' 'VHSERVERPORT' ; menu ;;
	        12) setup_value_prompt 'what is your $(ColorYellow 'current') or $(ColorCyan 'wanted')  Valheim server name ?' 'VHSERVERNAME' ; menu ;;
	        13) setup_value_prompt "what is your Valheim World name ? $(ColorRed 'If you already have a server, put its World name here')" 'VHSERVERWORLD' ; menu ;;
	        14) setup_value_prompt 'what is your $(ColorYellow 'current') or $(ColorCyan 'wanted')  Valheim server password ?' 'VHSERVERPASSWD' ; menu ;;
	        20) setup_value_prompt "at which frequency do you want your $(ColorMagenta 'Discord') webhook to send message (in minutes) ? set '0' if you dont want an auto-update cron" 'CRONTABWEBHOOKFREQ' ; set_cron ; menu ;;
	        30) service_menu ;;
		0) exit 0 ;;
		*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

# Call the menu function
menu