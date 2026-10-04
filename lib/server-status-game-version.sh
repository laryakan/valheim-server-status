#!/bin/bash

SERVER_STATUS_LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SERVER_STATUS_LIB_DIR/server-status-common.sh"

server_status_prepare_game_version() {
	CURRENT_VERSION="${VALSERVERVERSION:-unknown}"
	CURRENT_VERSION_TS="${VALSERVERLASTUPDATE:-unknown}"
	VERSION_LABEL="${CURRENT_VERSION} (${CURRENT_VERSION_TS})"
}