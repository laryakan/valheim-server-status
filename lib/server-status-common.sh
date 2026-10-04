#!/bin/bash

SERVER_STATUS_LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
STATUS_ROOT="${STATUS_ROOT:-${VSSDIR:-$(dirname "$SERVER_STATUS_LIB_DIR")}}"

if [ "${VSS_STATUS_ENV_LOADED:-0}" != 1 ]; then
	source "$STATUS_ROOT/.env"
	VSS_STATUS_ENV_LOADED=1
fi

STATUS_ROOT="${VSSDIR:-$STATUS_ROOT}"
if [ "${VSS_STATUS_I18N_LOADED:-0}" != 1 ]; then
	source "$STATUS_ROOT/i18n.sh"
	VSS_STATUS_I18N_LOADED=1
fi