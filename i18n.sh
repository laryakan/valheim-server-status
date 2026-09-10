# Translation helper for Discord webhook content.
# Set VSS_LANG to en or fr in .env.

case "${VSS_LANG:-en}" in
  fr)
    T_SERVER_STATUS_TITLE="Statut du serveur Valheim"
    T_ONLINE="ONLINE"
    T_OFFLINE="OFFLINE"
    T_LAST_CHECK="Dernière vérification"
    T_LAST_START="Dernier démarrage"
    T_LAST_SAVE="Dernière sauvegarde"
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
    T_FIRST_CONNECTION="Première connexion"
    T_PLAYER_DIED="Mort du joueur"
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
      "Le feu du foyer gronde, et \"\$PLAYER_NAME\" est chaud comme la braise !"
      "Dans ce royaume, la bière est forte, mais \"\$PLAYER_NAME\" a un foie en béton."
      "\"\$PLAYER_NAME\" a juré de chassé du troll. On va voir s'il tient parole !"
    )
    T_EVENT_LINES_DISCONNECT=(
      "\"\$PLAYER_NAME\" a pris la fuite comme un couard devant un simple Greyling."
      "Le courage de \"\$PLAYER_NAME\" a déserté avant que la première hache ne soit lancée."
      "\"\$PLAYER_NAME\" s'est sauvé... et il n'y avait même pas de trolls à l'horizon !"
      "On a vu \"\$PLAYER_NAME\" partir en courant comme un lâche ! Les valkyries qui l'ont ammené en Valheim doivent s'en mordre les doigts !"
      "\"\$PLAYER_NAME\" a préféré la fuite au combat... Il faut dire que les nains avait des cure-dents."
    )
    T_EVENT_LINES_FIRST_JOIN=(
      "\"\$PLAYER_NAME\" arrive par Corbeau Airlines. On espère qu'il a ramené la bière !"
      "Odin a refusé le Valhalla à un nouveau guerrier : \"\$PLAYER_NAME\". Il faudra se contenter de Valheim."
      "\"\$PLAYER_NAME\" débarque pour la première fois sur les rives de Valheim, et son inventaire est vide !"
    )
    T_EVENT_LINES_DEATH=(
      "\"\$PLAYER_NAME\" a connu la mort, laissé un nom dans la neige, sous le tronc d'arbre qui lui est tombé dessus."
      "Un dernier souffle, puis \"\$PLAYER_NAME\" tombe sous les coups de l'ennemi... ou alors il est tombé de trop haut."
      "\"\$PLAYER_NAME\" a été arraché au combat et sa poussière s'est dispersée. Ce feu de camp était bien trop chaud pour lui."
    )
    ;;
  *)
    VSS_LANG="en"
    T_SERVER_STATUS_TITLE="Valheim server status"
    T_ONLINE="ONLINE"
    T_OFFLINE="OFFLINE"
    T_LAST_CHECK="Last Check"
    T_LAST_START="Last start"
    T_LAST_SAVE="Last save"
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
    T_FIRST_CONNECTION="First connection"
    T_PLAYER_DIED="Player died"
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
      "\"\$PLAYER_NAME\" really dislikes trolls, and plans to prove it with a lot of unnecessary confidence."
      "A dwarf, a troll and \"\$PLAYER_NAME\" walk into a tavern, but only one will gets the ale."
      "The fire crackles, and \"\$PLAYER_NAME\" is already warm enough to start something very stupid."
      "In this realm, the ale is strong, but \"\$PLAYER_NAME\" has a liver built like a war shield."
      "\"\$PLAYER_NAME\" has sworn to hunt a troll. Let's see if the courage survives the first snack break."
    )
    T_EVENT_LINES_DISCONNECT=(
      "\"\$PLAYER_NAME\" ran off like a coward in front of a single Greyling."
      "The courage in \"\$PLAYER_NAME\" vanished before the first axe had a chance to be dramatic."
      "\"\$PLAYER_NAME\" fled... and there were no trolls in sight, which only makes the sprint more suspicious."
      "\"\$PLAYER_NAME\" left in a sprint like a coward. Even the Valkyries must have rolled their eyes."
      "\"\$PLAYER_NAME\" chose flight over combat. To be fair, the dwarves had toothpicks."
    )
    T_EVENT_LINES_FIRST_JOIN=(
      "\"\$PLAYER_NAME\" arrives by Raven Airlines. Let's hope the beer survived the journey."
      "Odin refused Valhalla to a fresh warrior: \"\$PLAYER_NAME\". Valheim will have to do."
      "\"\$PLAYER_NAME\" arrives on the shores of Valheim for the first time, and there is no gift in their inventory."
    )
    T_EVENT_LINES_DEATH=(
      "\"\$PLAYER_NAME\" met death, left a name in the snow, and then got outdone by the tree that fell on them."
      "One last gasp, then \"\$PLAYER_NAME\" falls under enemy blows... or maybe just from climbing too high."
      "\"\$PLAYER_NAME\" was torn from the fight and the campfire dust drifted away. The fire was much too warm for that kind of drama."
    )
    ;;
esac

T_RANDOM_EVENT_LINE() {
  local kind="${1:-connect}"
  local -a lines=()
  case "$kind" in
    connect) lines=("${T_EVENT_LINES_CONNECT[@]}") ;;
    disconnect) lines=("${T_EVENT_LINES_DISCONNECT[@]}") ;;
    first_join) lines=("${T_EVENT_LINES_FIRST_JOIN[@]}") ;;
    death) lines=("${T_EVENT_LINES_DEATH[@]}") ;;
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
    last_start) echo "$T_LAST_START" ;;
    last_save) echo "$T_LAST_SAVE" ;;
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
    first_connection) echo "$T_FIRST_CONNECTION" ;;
    player_died) echo "$T_PLAYER_DIED" ;;
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
