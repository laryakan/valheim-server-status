#!/bin/bash

LIBDIR="${LIBDIR:-$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )}"
if [ -z "${VSSDIR:-}" ]; then
	CWD="$(dirname "$LIBDIR")"
	source "$CWD/.env"
else
	CWD="$VSSDIR"
fi

LIBDIR="${LIBDIR:-$VSSDIR/lib}"
if ! declare -F T >/dev/null; then
	source "$CWD/i18n.sh"
fi