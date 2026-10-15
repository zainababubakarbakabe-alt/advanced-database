#!/usr/bin/env bash
# Runs 03_redis_keyvalue.redis line by line, printing each command followed by its reply (evidence for the report).
while IFS= read -r line; do
  case "$line" in
    "#"*) echo; echo "$line" ;;
    "")   ;;
    *)    echo "127.0.0.1:6379> $line"; eval redis-cli $line | sed 's/^/    /' ;;
  esac
done < 03_redis_keyvalue.redis
