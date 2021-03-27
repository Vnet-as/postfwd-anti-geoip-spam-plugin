#!/usr/bin/env sh

set -eo pipefail

# If command starts with an option, prepend postfwd3
if [ "${1:0:1}" = '-' ]; then
  set -- postfwd3 "$@"
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

if [ "$1" = "postfwd3" ] && [ -z "$want_help" ]; then
  chmod -R 644 /etc/postfwd/*
  chown -R postfw:postfw /etc/postfwd
fi

exec "$@"
