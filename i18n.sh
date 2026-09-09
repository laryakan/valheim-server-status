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
    T_WORLD="Monde"
    T_PASSWORD="Mot de passe"
    T_LAST_LOGS="Derniers journaux"
    T_NO_LOG_TO_SEND="aucun journal à envoyer"
    T_STATUS_MESSAGE_DELETED="Le message de statut a été supprimé du serveur, un nouveau message sera envoyé, veuillez remplir le fichier .env"
    T_PATCH_FAILED="Échec de la requête PATCH Discord avec HTTP %s ; le message existant est conservé sans en créer un nouveau."
    T_USAGE="usage:\njson_to_send | ./script <--status|message_id>"
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
    T_WORLD="World"
    T_PASSWORD="Password"
    T_LAST_LOGS="Last Logs"
    T_NO_LOG_TO_SEND="no log to send"
    T_STATUS_MESSAGE_DELETED="Status message has been deleted from the server, a new message will be sent, please fill the .env file"
    T_PATCH_FAILED="Discord PATCH failed with HTTP %s; keeping existing message without creating a new one."
    T_USAGE="usage:\njson_to_send | ./script <--status|message_id>"
    ;;
esac

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
    world) echo "$T_WORLD" ;;
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
    usage) echo -e "$T_USAGE" ;;
    *) echo "$1" ;;
  esac
}
