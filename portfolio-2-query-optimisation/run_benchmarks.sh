#!/usr/bin/env bash
# Usage: ./run_benchmarks.sh before|after
# Saves the full EXPLAIN (ANALYZE, BUFFERS) plan of each query, then runs it 5 more times and records the median.
set -euo pipefail
PHASE=${1:?before|after}
# Cross-platform PATH: support macOS Homebrew, Linux, and Windows Git Bash
[ -d "/opt/homebrew/bin" ] && export PATH="/opt/homebrew/bin:$PATH"
[ -d "/usr/local/bin" ] && export PATH="/usr/local/bin:$PATH"
for pg in /c/"Program Files"/PostgreSQL/*/bin; do [ -d "$pg" ] && export PATH="$pg:$PATH"; done
export PGPASSWORD=${PGPASSWORD:-dbadmin}
cd "$(dirname "${BASH_SOURCE[0]}")"
PSQL=(psql -h localhost -U dbadmin -d shopnaija -X -q -v ON_ERROR_STOP=1 -c "SET max_parallel_workers_per_gather = 0")
for f in queries/q*.sql; do
  n=$(basename "$f" .sql); Q=$(grep -v '^--' "$f" | tr '\n' ' ' | sed 's/;\s*$//')
  { echo "-- $n ($PHASE indexing)"; "${PSQL[@]}" -c "EXPLAIN (ANALYZE, BUFFERS) $Q"; } > "results/${PHASE}_${n}.txt"
  med=$(for i in 1 2 3 4 5; do "${PSQL[@]}" -c "EXPLAIN (ANALYZE) $Q" | awk '/Execution Time/{print $3}'; done | sort -n | sed -n 3p)
  echo "-- median of 5 further runs: $med ms" >> "results/${PHASE}_${n}.txt"
done
echo "done: $PHASE"
