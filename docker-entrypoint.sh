#!/usr/bin/env bash

set -eo pipefail

# If command starts with an option, prepend postfwd2
if [ "${1:0:1}" = '-' ]; then
  set -- postfwd2 "$@"
fi

# Check if help, version or manual arguments were used
want_help=
for arg; do
  case "$arg" in
    --help|-h|--manual|-m|--version|-V)
      want_help=1
      break
      ;;
  esac
done


if [ "$1" = "postfwd1"  ] || [ "$1" = "postfwd2" ] && [ -z "$want_help" ]; then
  if [ ! -f /etc/postfwd/anti-spam.conf ]; then
    echo >&2 'ERROR: Anti-spam plugin configuration file /etc/postfwd/anti-spam.conf was not found. Perhaps you forgot to mount it using "-v </absolute/path/to/anti-spam.conf>:/etc/postfwd/anti-spam.conf".'
    exit 1
  fi
  chmod -R 644 /etc/postfwd/*
  chown -R postfw:postfw /etc/postfwd
fi

exec "$@"
