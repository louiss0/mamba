#!/bin/sh
set -eu

if ! command -v bash >/dev/null 2>&1; then
  echo '::error::Bash 4 or newer is required; bash was not found on PATH.' >&2
  exit 1
fi

if ! major=$(bash --noprofile --norc -c 'printf "%s\n" "${BASH_VERSINFO[0]}"'); then
  echo '::error::Bash 4 or newer is required; the selected bash could not run.' >&2
  exit 1
fi
case "$major" in
  ''|*[!0-9]*)
    echo "::error::Bash 4 or newer is required; unreadable major version: $major" >&2
    exit 1
    ;;
esac
if [ "$major" -lt 4 ]; then
  echo "::error::Bash 4 or newer is required; found Bash $major." >&2
  exit 1
fi

printf 'Using Bash %s at %s\n' "$major" "$(command -v bash)"
bash --version
