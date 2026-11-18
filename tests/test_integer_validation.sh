#!/bin/bash
set -u

cd "$(dirname "$0")/.."
export DEBUGMODE=1

source ./lib/validation.sh

if ! validate_integer 42; then
  echo "FAIL: validate_integer(42) should succeed" >&2
  exit 1
fi

if validate_integer 42.5; then
  echo "FAIL: validate_integer(42.5) should fail" >&2
  exit 1
fi

if validate_integer -1; then
  echo "FAIL: validate_integer(-1) should fail for this config" >&2
  exit 1
fi

if ! validate_r2modman_code 01a1eaf3-9be3-9083-b9b4-26768368368e; then
  echo "FAIL: valid R2Modman code was rejected" >&2
  exit 1
fi

if validate_r2modman_code 'not-a-uuid'; then
  echo "FAIL: invalid R2Modman code was accepted" >&2
  exit 1
fi

if ! validate_env_integer VHSERVERPORT 2456; then
  echo "FAIL: validate_env_integer(VHSERVERPORT, 2456) should succeed" >&2
  exit 1
fi

if validate_env_integer CRONTABWEBHOOKFREQ 5.5; then
  echo "FAIL: validate_env_integer(CRONTABWEBHOOKFREQ, 5.5) should fail" >&2
  exit 1
fi

echo "integer validation OK"
