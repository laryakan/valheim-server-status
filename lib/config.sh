#!/bin/bash

vss_validate_server_name() {
  [[ "${1:-}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] &&
    [[ "$1" != *..* ]]
}

vss_find_server_pid() {
  if [ -n "${VALSERVERPID:-}" ] && ps -p "$VALSERVERPID" >/dev/null 2>&1; then
    printf '%s\n' "$VALSERVERPID"
    return 0
  fi

  [ -n "${VHSERVERWORLD:-}" ] || return 1
  ps -eo pid=,args= 2>/dev/null |
    awk -v needle="-world ${VHSERVERWORLD}" '$0 !~ /awk/ && index($0, needle) { print $1; exit }'
}

vss_load_config() {
  local root="${1:?VSS root directory is required}"
  local config_file="${VSS_ENV_FILE:-}"
  local config_name=""
  local verify_world_name=0

  if [ "${VSS_CONFIG_LOADED:-0}" = "1" ] && [ -n "${VSS_SERVER_NAME:-}" ]; then
    return 0
  fi

  if [ -n "$config_file" ]; then
    [ -z "${VSS_SERVER_NAME:-}" ] || verify_world_name=1
    case "$config_file" in
      /*) ;;
      *) config_file="$root/$config_file" ;;
    esac
    case "$(basename "$config_file")" in
      .env.*)
        config_name="${config_file##*.env.}"
        if [ "$config_name" != "test" ]; then
          if [ -n "${VSS_SERVER_NAME:-}" ] && [ "$VSS_SERVER_NAME" != "$config_name" ]; then
            printf 'VSS_ENV_FILE profile "%s" does not match VSS_SERVER_NAME "%s".\n' \
              "$config_name" "$VSS_SERVER_NAME" >&2
            return 1
          fi
          verify_world_name=1
          VSS_SERVER_NAME="${VSS_SERVER_NAME:-$config_name}"
        fi
        ;;
    esac
  elif [ -n "${VSS_SERVER_NAME:-}" ]; then
    if ! vss_validate_server_name "$VSS_SERVER_NAME"; then
      printf 'Invalid VSS server name: %s\n' "$VSS_SERVER_NAME" >&2
      return 1
    fi
    config_file="$root/.env.$VSS_SERVER_NAME"
    verify_world_name=1
  else
    printf 'Select a server with VSS_SERVER_NAME or provide VSS_ENV_FILE.\n' >&2
    return 1
  fi

  if [ -n "${VSS_SERVER_NAME:-}" ] && ! vss_validate_server_name "$VSS_SERVER_NAME"; then
    printf 'Invalid VSS server name: %s\n' "$VSS_SERVER_NAME" >&2
    return 1
  fi

  if [ ! -r "$config_file" ]; then
    printf 'VSS configuration is not readable: %s\n' "$config_file" >&2
    return 1
  fi

  VSS_ENV_FILE="$config_file"
  export VSS_ENV_FILE
  if ! source "$VSS_ENV_FILE"; then
    printf 'Failed to load VSS configuration: %s\n' "$VSS_ENV_FILE" >&2
    return 1
  fi

  if [ -z "${VSS_SERVER_NAME:-}" ]; then
    VSS_SERVER_NAME="${VHSERVERWORLD:-}"
  fi
  if ! vss_validate_server_name "$VSS_SERVER_NAME"; then
    printf 'Invalid or missing VHSERVERWORLD in %s\n' "$VSS_ENV_FILE" >&2
    return 1
  fi
  if [ "$verify_world_name" -eq 1 ] && [ "${VHSERVERWORLD:-}" != "$VSS_SERVER_NAME" ]; then
    printf 'Profile name "%s" does not match VHSERVERWORLD "%s" in %s\n' \
      "$VSS_SERVER_NAME" "${VHSERVERWORLD:-}" "$VSS_ENV_FILE" >&2
    return 1
  fi

  export VSS_SERVER_NAME
  VSS_CONFIG_LOADED=1
  export VSS_CONFIG_LOADED
}
