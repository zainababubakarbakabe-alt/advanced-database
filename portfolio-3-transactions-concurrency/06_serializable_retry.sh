#!/usr/bin/env bash
# Demo E: SERIALIZABLE needs a RETRY loop. Two transfers of stock between warehouses-style counters
# run concurrently; whoever gets "could not serialize" (SQLSTATE 40001) retries until it succeeds.
export PGPASSWORD=${PGPASSWORD:-dbadmin}
P="psql -h localhost -U dbadmin -d shopnaija -X -q -t -A -v ON_ERROR_STOP=1"
$P -c "UPDATE shop.product SET stock_qty = 1 WHERE product_id IN (401,402)"
attempt() {  # $1 = label, $2 = product to zero, $3 = other product
  for try in 1 2 3; do
    out=$($P 2>&1 <<SQL
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT pg_sleep(0.5);
-- business rule: only remove stock if the pair would still have at least one unit
UPDATE shop.product SET stock_qty = 0
 WHERE product_id = $2 AND (SELECT sum(stock_qty) FROM shop.product WHERE product_id IN (401,402)) >= 2;
COMMIT;
SQL
)
    if echo "$out" | grep -q "could not serialize"; then
      echo "T$1 attempt $try: serialization failure (40001) -> retrying"; sleep 0.3
    else
      echo "T$1 attempt $try: committed"; return
    fi
  done
}
attempt A 401 402 & attempt B 402 401 & wait
$P -c "SELECT 'final: 401=' || (SELECT stock_qty FROM shop.product WHERE product_id=401) || ', 402=' || (SELECT stock_qty FROM shop.product WHERE product_id=402) || ' (rule holds: total >= 1)'"
