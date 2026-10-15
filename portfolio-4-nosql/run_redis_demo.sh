#!/usr/bin/env bash
# Runs 03_redis_keyvalue.redis line by line, printing each command followed by its reply (evidence for the report).
# Cross-platform PATH: support macOS Homebrew, Linux, and Windows Git Bash
[ -d "/opt/homebrew/bin" ] && export PATH="/opt/homebrew/bin:$PATH"
[ -d "/usr/local/bin" ] && export PATH="/usr/local/bin:$PATH"
for pg in /c/"Program Files"/PostgreSQL/*/bin; do [ -d "$pg" ] && export PATH="$pg:$PATH"; done
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while IFS= read -r line; do
  case "$line" in
    "#"*) echo; echo "$line" ;;
    "")   ;;
    *)    echo "127.0.0.1:6379> $line"; eval redis-cli $line | sed 's/^/    /' ;;
  esac
done < "$DIR/03_redis_keyvalue.redis"
