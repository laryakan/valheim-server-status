#!/bin/bash

validate_integer() {
  local value="${1:-}"
  [[ "$value" =~ ^[0-9]+$ ]]
}

validate_env_integer() {
  local key="$1"
  local value="${2:-}"

  case "$key" in
    VHSERVERPORT|STATUSPORT|SENDLASTLOGS|SENDSERVERCONNECTIONINFO|CRONTABWEBHOOKFREQ|EVENTREALTIME)
      validate_integer "$value"
      ;;
    *)
      return 0
      ;;
  esac
}
