# Translation helper for Discord webhook content.
# Set VSS_LANG to en or fr in .env.

case "${VSS_LANG:-en}" in
  fr)
    T_SERVER_STATUS_TITLE="Statut du serveur Valheim"
    T_ONLINE="en ligne"
    T_OFFLINE="hors ligne"
    T_LAST_CHECK="Dernière vérification"
    T_CPU="CPU"
    T_RAM="RAM"
    T_VERSION="Version"
    T_VERSION_UPDATED="Version mise à jour"
    T_EVENT_TIME="Heure de l'événement"
    T_PLAYER="Joueur"
    T_STATUS="Statut"
    T_EVENT_TITLE="Événement serveur Valheim"
    T_PLAYER_CONNECTED="Joueur connecté"
    T_PLAYER_DISCONNECTED="Joueur déconnecté"
    T_PLAYER_JOINED="a rejoint le serveur."
    T_PLAYER_LEFT="a quitté le serveur."
    T_EVENT="Événement"
    T_CONNECTION_INFO_TITLE="Informations de connexion"
    T_SERVER_INFO_TITLE="Informations du serveur Valheim"
    T_IP="IP"
    T_SERVER_NAME="Nom du serveur"
    T_PASSWORD="Mot de passe"
    T_LAST_LOGS="Derniers journaux"
    T_NO_LOG_TO_SEND="aucun journal à envoyer"
    T_STATUS_MESSAGE_DELETED="Le message de statut a été supprimé du serveur, un nouveau message sera envoyé, veuillez remplir le fichier .env"
    T_PATCH_FAILED="Échec de la requête PATCH Discord avec HTTP %s ; le message existant est conservé sans en créer un nouveau."
    T_USAGE="usage:\njson_to_send | ./script <--status|message_id>"
    T_EVENT_LINES_CONNECT=(
      "\"\$PLAYER_NAME\" n'aime vraiment pas les trolls, et compte le démontrer !"
      "Un nain, un troll et \"\$PLAYER_NAME\" entre dans une taverne, mais un seul aura droit à sa chope !"
      "Le feu du foyer gronde, et \"\$PLAYER_NAME\" semble déjà prêt à repartir au combat."
      "Dans ce royaume, la bière est forte, mais la volonté de \"\$PLAYER_NAME\" l'est encore plus."
      "\"\$PLAYER_NAME\" a juré de faire du raid, et les trolls peuvent commencer à courir."
    )
    T_EVENT_LINES_DISCONNECT=(
      "\"\$PLAYER_NAME\" a pris la fuite comme un lâche devant la horde."
      "Le courage de \"\$PLAYER_NAME\" a déserté dès le premier bruit de combat."
      "\"\$PLAYER_NAME\" s'est sauvé avant même que le premier troll ne se mette en colère."
      "On a vu \"\$PLAYER_NAME\" partir en courant comme un lâche !"
      "\"\$PLAYER_NAME\" a préféré la fuite au combat, et c'est un peu trop facile à deviner."
    )
    ;;
  *)
    VSS_LANG="en"
    T_SERVER_STATUS_TITLE="Valheim server status"
    T_ONLINE="online"
    T_OFFLINE="offline"
    T_LAST_CHECK="Last Check"
    T_CPU="CPU"
    T_RAM="RAM"
    T_VERSION="Version"
    T_VERSION_UPDATED="Version Updated"
    T_EVENT_TIME="Event Time"
    T_PLAYER="Player"
    T_STATUS="Status"
    T_EVENT_TITLE="Valheim server event"
    T_PLAYER_CONNECTED="Player connected"
    T_PLAYER_DISCONNECTED="Player disconnected"
    T_PLAYER_JOINED="joined the server."
    T_PLAYER_LEFT="left the server."
    T_EVENT="Event"
    T_CONNECTION_INFO_TITLE="Connection"
    T_SERVER_INFO_TITLE="Valheim server information"
    T_IP="IP"
    T_SERVER_NAME="Server name"
    T_PASSWORD="Password"
    T_LAST_LOGS="Last Logs"
    T_NO_LOG_TO_SEND="no log to send"
    T_STATUS_MESSAGE_DELETED="Status message has been deleted from the server, a new message will be sent, please fill the .env file"
    T_PATCH_FAILED="Discord PATCH failed with HTTP %s; keeping existing message without creating a new one."
    T_USAGE="usage:\njson_to_send | ./script <--status|message_id>"
    T_EVENT_LINES_CONNECT=(
      "\"\$PLAYER_NAME\" really dislikes trolls, and plans to prove it."
      "A dwarf, a troll and \"\$PLAYER_NAME\" walk into a tavern, but only one gets to keep the ale."
      "The fire crackles, and \"\$PLAYER_NAME\" looks ready for another run into the wild."
      "In this realm, the ale is strong, but \"\$PLAYER_NAME\" is stronger."
      "\"\$PLAYER_NAME\" has sworn to raid, and the trolls can start running now."
    )
    T_EVENT_LINES_DISCONNECT=(
      "\"\$PLAYER_NAME\" ran off like a coward the moment the horde showed up."
      "The courage in \"\$PLAYER_NAME\" vanished the second the first troll appeared."
      "\"\$PLAYER_NAME\" fled before the first axe ever swung."
      "\"\$PLAYER_NAME\" left like a deserter who feared the fight more than the frost."
      "As soon as the chaos started, \"\$PLAYER_NAME\" chose the road of shame."
    )
    ;;
esac

T_RANDOM_EVENT_LINE() {
  local kind="${1:-connect}"
  local -a lines=()
  case "$kind" in
    connect) lines=("${T_EVENT_LINES_CONNECT[@]}") ;;
    disconnect) lines=("${T_EVENT_LINES_DISCONNECT[@]}") ;;
    *) lines=("${T_EVENT_LINES_CONNECT[@]}") ;;
  esac

  local count=${#lines[@]}
  if [ "$count" -le 0 ]
  then
    echo "$(T event)"
    return 0
  fi

  local index=$(( RANDOM % count ))
  local line="${lines[$index]}"
  if [ -n "${PLAYER_NAME:-}" ]
  then
    line="${line//\$PLAYER_NAME/$PLAYER_NAME}"
  else
    line="${line//\$PLAYER_NAME/$(T player)}"
  fi
  printf '%s' "$line"
}

T() {
  case "$1" in
    server_status_title) echo "$T_SERVER_STATUS_TITLE" ;;
    online) echo "$T_ONLINE" ;;
    offline) echo "$T_OFFLINE" ;;
    last_check) echo "$T_LAST_CHECK" ;;
    cpu) echo "$T_CPU" ;;
    ram) echo "$T_RAM" ;;
    version) echo "$T_VERSION" ;;
    version_updated) echo "$T_VERSION_UPDATED" ;;
    event_time) echo "$T_EVENT_TIME" ;;
    player) echo "$T_PLAYER" ;;
    status) echo "$T_STATUS" ;;
    event_title) echo "$T_EVENT_TITLE" ;;
    player_connected) echo "$T_PLAYER_CONNECTED" ;;
    player_disconnected) echo "$T_PLAYER_DISCONNECTED" ;;
    player_joined) echo "$T_PLAYER_JOINED" ;;
    player_left) echo "$T_PLAYER_LEFT" ;;
    event) echo "$T_EVENT" ;;
    connection_info_title) echo "$T_CONNECTION_INFO_TITLE" ;;
    server_info_title) echo "$T_SERVER_INFO_TITLE" ;;
    ip) echo "$T_IP" ;;
    server_name) echo "$T_SERVER_NAME" ;;
    password) echo "$T_PASSWORD" ;;
    last_logs) echo "$T_LAST_LOGS" ;;
    no_log_to_send) echo "$T_NO_LOG_TO_SEND" ;;
    status_message_deleted) echo "$T_STATUS_MESSAGE_DELETED" ;;
    patch_failed)
      if [ -n "${2:-}" ]; then
        printf "%s" "$T_PATCH_FAILED" | sed "s/%s/$2/"
      else
        echo "$T_PATCH_FAILED"
      fi
      ;;
    event_line)
      T_RANDOM_EVENT_LINE "${2:-connect}"
      ;;
    usage) echo -e "$T_USAGE" ;;
    *) echo "$1" ;;
  esac
}
