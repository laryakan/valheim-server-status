#!/bin/bash

SERVER_STATUS_LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SERVER_STATUS_LIB_DIR/server-status-common.sh"

server_status_prepare_bepinex() {
	BEPINEXVERSION_LABEL="Disabled"
	if [ "${VSSBEPINEXENABLED:-0}" -eq 1 ]; then
		BEPINEXVERSION_LABEL="${BEPINEXVERSION} ${BEPINEXLASTUPDATE:-not_installed}"
	fi
}