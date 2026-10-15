#!/usr/bin/env bash
# Demo D: deadlock (opposite lock order) and the fix (consistent lock order).
# Cross-platform PATH: support macOS Homebrew, Linux, and Windows Git Bash
[ -d "/opt/homebrew/bin" ] && export PATH="/opt/homebrew/bin:$PATH"
[ -d "/usr/local/bin" ] && export PATH="/usr/local/bin:$PATH"
for pg in /c/"Program Files"/PostgreSQL/*/bin; do [ -d "$pg" ] && export PATH="$pg:$PATH"; done
export PGPASSWORD=${PGPASSWORD:-dbadmin}
P="psql -h localhost -U dbadmin -d shopnaija -X -q -t -A"
echo "=== D1. Deadlock: T1 locks 501 then 502; T2 locks 502 then 501"
t() { $P <<SQL 2>&1 | sed 's/^psql:.*ERROR:/ERROR:/' | grep -E "ERROR|DETAIL|T[12]" 
BEGIN;
SELECT 'T$1 locking $2' FROM shop.product WHERE product_id = $2 FOR UPDATE;
SELECT pg_sleep(1);
SELECT 'T$1 locking $3' FROM shop.product WHERE product_id = $3 FOR UPDATE;
COMMIT;
SQL
}
t 1 501 502 & t 2 502 501 & wait
echo "-> PostgreSQL's deadlock detector aborted one transaction; the other committed."
echo; echo "=== D2. Fix: every transaction locks in ascending product_id order"
t 1 501 502 & t 2 501 502 & wait
echo "-> No deadlock: T2 simply waited for T1 to finish."
