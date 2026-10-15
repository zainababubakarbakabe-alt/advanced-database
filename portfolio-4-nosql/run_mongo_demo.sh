#!/usr/bin/env bash
# Runs 04_mongodb_design.js against a fresh naijacart database (evidence for the report).
# Uses mongod/mongosh from PATH, else the tarball installs in ~/mongodb. Starts mongod if it is not already up.
set -uo pipefail
MONGOD=$(command -v mongod || echo ~/mongodb/mongodb-macos-aarch64-7.0.14/bin/mongod)
MONGOSH=$(command -v mongosh || echo ~/mongodb/mongosh-2.3.1-darwin-arm64/bin/mongosh)

if ! "$MONGOSH" --quiet --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1; then
  mkdir -p ~/mongodb/data ~/mongodb/logs
  "$MONGOD" --dbpath ~/mongodb/data --logpath ~/mongodb/logs/mongod.log --bind_ip 127.0.0.1 --port 27017 --fork >/dev/null
fi

"$MONGOSH" --quiet naijacart --eval 'db.dropDatabase()' >/dev/null   # products use fixed _ids, so a rerun would collide
"$MONGOSH" --quiet --file 04_mongodb_design.js
