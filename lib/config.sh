#!/bin/bash

vss_validate_server_name() {
  [[ "${1:-}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] &&
    [[ "$1" != *..* ]]
}

vss_is_common_config() {
  [ -f "${1:-}" ] && grep -Fxq 'VSS_COMMON_CONFIG_VERSION=3' "$1"
}

vss_find_server_pid() {
  local server_pid

  if [ -n "${VALSERVERPID:-}" ] && ps -p "$VALSERVERPID" >/dev/null 2>&1; then
    printf '%s\n' "$VALSERVERPID"
    return 0
  fi

  [ -n "${VHSERVERWORLD:-}" ] || return 1
  server_pid="$(ps -eo pid=,args= 2>/dev/null |
    awk -v needle="-world ${VHSERVERWORLD}" '$0 !~ /awk/ && index($0, needle) { print $1; exit }'
  )"
  [ -n "$server_pid" ] || return 1
  printf '%s\n' "$server_pid"
}

vss_server_state() (
  local open_time='' service_start='' info line systemctl_status
  local unit load_state='' active_state='' started=''
  local VALSERVERLASTOPEN=''

  if ! source "$VSS_ENV_FILE"; then
    printf 'Could not read server status for profile %s.\n' "$VSS_SERVER_NAME" >&2
    return 1
  fi
  unit="${VHSERVERSERVICENAME:-valheim-server.$VSS_SERVER_NAME.service}"
  if info="$(LC_ALL=C systemctl show "$unit" --property=LoadState --property=ActiveState --property=ActiveEnterTimestamp)"; then
    :
  else
    systemctl_status=$?
    if [ "$systemctl_status" -eq 4 ] || [[ "$info" == *$'\nLoadState=not-found'* || "$info" == LoadState=not-found* ]]; then
      printf 'offline'
      return
    fi
    printf 'Could not inspect service %s.\n' "$unit" >&2
    printf 'offline'
    return
  fi
  while IFS= read -r line; do
    case "$line" in
      LoadState=*) load_state="${line#*=}" ;;
      ActiveState=*) active_state="${line#*=}" ;;
      ActiveEnterTimestamp=*) started="${line#*=}" ;;
    esac
  done <<< "$info"
  if [ "$load_state" = 'not-found' ]; then
    printf 'offline'
    return
  fi
  if [ "$load_state" != 'loaded' ] || [ -z "$active_state" ]; then
    printf 'Could not determine state of service %s.\n' "$unit" >&2
    printf 'offline'
    return
  fi
  case "$active_state" in
    activating) printf 'starting'; return ;;
    inactive|failed|deactivating) printf 'offline'; return ;;
    active|reloading|refreshing) ;;
    *)
      printf 'Unexpected state for service %s: %s.\n' "$unit" "$active_state" >&2
      printf 'offline'
      return ;;
  esac
  if [ -z "$started" ] || ! service_start="$(LC_ALL=C date -d "$started" +%s)"; then
    printf 'Could not determine start time of service %s.\n' "$unit" >&2
    printf 'offline'
    return
  fi
  if [ -n "$VALSERVERLASTOPEN" ] && ! open_time="$(date -d "$VALSERVERLASTOPEN" +%s)"; then
    printf 'Invalid server opening timestamp for profile %s.\n' "$VSS_SERVER_NAME" >&2
    open_time=''
  fi
  if [ -n "$open_time" ] && (( open_time >= service_start )); then
    printf 'online'
  else
    printf 'starting'
  fi
)

vss_load_config() {
  local root="${1:?VSS root directory is required}"
  local config_file="${VSS_ENV_FILE:-}"
  local config_name=""
  local config_basename=""
  local expected_server_name="${VSS_SERVER_NAME:-}"
  local common_file
  local profile_log_dir
  local profile_log_path
  local profile_public_ip
  local profile_status_url
  local default_status_url
  local default_log_path
  local state_key
  local state_path
  local configured_state_path
  local index
  local -a state_keys=(CONNECTEDPLAYERSFILE OFFLINEPLAYERSFILE STEAMIDMAPFILE LASTWORLDSAVEFILE)
  local -a state_names=(online-players offline-players steamid-player-map last-world-save)

  root="$(cd "$root" 2>/dev/null && pwd)" || {
    printf 'VSS root directory is not accessible: %s\n' "$1" >&2
    return 1
  }
  common_file="$root/.env"
  VSSDIR="$root"
  export VSSDIR

  if [ "${VSS_CONFIG_LOADED:-0}" = "1" ] && [ -n "${VSS_SERVER_NAME:-}" ]; then
    return 0
  fi

  if [ -n "$config_file" ]; then
    case "$config_file" in
      /*) ;;
      *) config_file="$root/$config_file" ;;
    esac
    config_basename="$(basename "$config_file")"
    case "$config_basename" in
      .env.*)
        config_name="${config_basename#.env.}"
        if ! vss_validate_server_name "$config_name"; then
          printf 'Invalid server profile name in VSS_ENV_FILE: %s\n' "$config_name" >&2
          return 1
        fi
        if [ -n "$expected_server_name" ] && [ "$expected_server_name" != "$config_name" ]; then
          printf 'VSS_ENV_FILE profile "%s" does not match VSS_SERVER_NAME "%s".\n' \
            "$config_name" "$expected_server_name" >&2
          return 1
        fi
        expected_server_name="$config_name"
        VSS_SERVER_NAME="$config_name"
        ;;
    esac
  elif [ -n "${VSS_SERVER_NAME:-}" ]; then
    if ! vss_validate_server_name "$expected_server_name"; then
      printf 'Invalid VSS server name: %s\n' "$expected_server_name" >&2
      return 1
    fi
    config_file="$root/.env.$expected_server_name"
  else
    printf 'Select a server with VSS_SERVER_NAME or provide VSS_ENV_FILE.\n' >&2
    return 1
  fi

  if [ ! -r "$config_file" ]; then
    printf 'VSS configuration is not readable: %s\n' "$config_file" >&2
    return 1
  fi

  VSS_ENV_FILE="$config_file"
  export VSS_ENV_FILE
  unset CONNECTEDPLAYERSFILE OFFLINEPLAYERSFILE STEAMIDMAPFILE LASTWORLDSAVEFILE
  if ! source "$VSS_ENV_FILE"; then
    printf 'Failed to load VSS configuration: %s\n' "$VSS_ENV_FILE" >&2
    return 1
  fi

  if [ -n "$expected_server_name" ]; then
    if [ -n "${VSS_SERVER_NAME:-}" ] && [ "$VSS_SERVER_NAME" != "$expected_server_name" ]; then
      printf 'Profile file "%s" sets VSS_SERVER_NAME to "%s", expected "%s".\n' \
        "$VSS_ENV_FILE" "$VSS_SERVER_NAME" "$expected_server_name" >&2
      return 1
    fi
    VSS_SERVER_NAME="$expected_server_name"
  fi
  if [ -z "${VSS_SERVER_NAME:-}" ]; then
    VSS_SERVER_NAME="${VHSERVERWORLD:-}"
  fi
  if ! vss_validate_server_name "$VSS_SERVER_NAME"; then
    printf 'Invalid or missing VHSERVERWORLD in %s\n' "$VSS_ENV_FILE" >&2
    return 1
  fi
  if [ "${VHSERVERWORLD:-}" != "$VSS_SERVER_NAME" ]; then
    printf 'Profile name "%s" does not match VHSERVERWORLD "%s" in %s\n' \
      "$VSS_SERVER_NAME" "${VHSERVERWORLD:-}" "$VSS_ENV_FILE" >&2
    return 1
  fi

  profile_log_dir="${VALHEIMSERVERLOGDIR:-}"
  profile_log_path="${VALHEIMSERVERLOGPATH:-}"
  profile_public_ip="${PUBLICIP:-}"
  profile_status_url="${STATUSURL:-}"
  if [ -f "$common_file" ]; then
    if ! vss_is_common_config "$common_file"; then
      printf 'A legacy .env was found. Run ./migrate-v2-to-v3 before using VSS.\n' >&2
      return 1
    fi
    if ! source "$common_file"; then
      printf 'Failed to load shared VSS configuration: %s\n' "$common_file" >&2
      return 1
    fi
  fi

  if [ -z "${STEAMCMDPATH:-}" ]; then
    STEAMCMDPATH="${STEAMCMD:-$(command -v steamcmd || true)}"
  fi
  if [ -z "${VALHEIMSERVERLOGDIR:-}" ]; then
    VALHEIMSERVERLOGDIR="$root/valheim-logs.d"
  fi
  default_log_path="$profile_log_dir/*.$VSS_SERVER_NAME.*.log"
  if [ -z "$profile_log_path" ] || [ "$profile_log_path" = "$default_log_path" ]; then
    VALHEIMSERVERLOGPATH="$VALHEIMSERVERLOGDIR/*.$VSS_SERVER_NAME.*.log"
  else
    VALHEIMSERVERLOGPATH="$profile_log_path"
  fi
  if [ -n "$profile_public_ip" ]; then
    default_status_url="http://$profile_public_ip:${STATUSPORT:-8181}/"
  else
    default_status_url="https://www.valheimgame.com:443/"
  fi
  if [ -z "$profile_status_url" ] || [ "$profile_status_url" = "$default_status_url" ]; then
    if [ -n "${PUBLICIP:-}" ]; then
      STATUSURL="http://$PUBLICIP:${STATUSPORT:-8181}/"
    else
      STATUSURL="https://www.valheimgame.com:443/"
    fi
  else
    STATUSURL="$profile_status_url"
  fi

  for index in "${!state_keys[@]}"; do
    state_key="${state_keys[$index]}"
    state_path="$root/data/${state_names[$index]}.$VSS_SERVER_NAME"
    configured_state_path="${!state_key:-}"
    if [ -n "$configured_state_path" ] && [ "$configured_state_path" != "$state_path" ] &&
       { [ -e "$configured_state_path" ] || [ -L "$configured_state_path" ]; }; then
      printf '%s is fixed at %s; move the existing state file from %s before starting this profile.\n' \
        "$state_key" "$state_path" "$configured_state_path" >&2
      return 1
    fi
    printf -v "$state_key" '%s' "$state_path"
    export "$state_key"
  done

  local default_bepinex_dir="$root/bepinex/profiles/$VSS_SERVER_NAME"
  local default_bepinex_log="$default_bepinex_dir/BepInEx/LogOutput.log"
  case "${VSSBEPINEXDIR:-}" in
    ''|"$root/bepinex/current"|"$root/bepinex/current/")
      VSSBEPINEXDIR="$default_bepinex_dir"
      ;;
  esac
  case "${VSSBEPINEXLOGOUTPUT:-}" in
    ''|"$root/bepinex/current/BepInEx/LogOutput.log"|"$root/bepinex/current//BepInEx/LogOutput.log")
      VSSBEPINEXLOGOUTPUT="$default_bepinex_log"
      ;;
  esac
  export VSSBEPINEXDIR VSSBEPINEXLOGOUTPUT

  export VSS_SERVER_NAME
  VSS_CONFIG_LOADED=1
  export VSS_CONFIG_LOADED
}
