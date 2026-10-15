#!/usr/bin/env bash
# Demo C: isolation levels. Session 1 reads a product price twice while session 2 changes it in between.
export PGPASSWORD=${PGPASSWORD:-dbadmin}
P="psql -h localhost -U dbadmin -d shopnaija -X -q -t -A"
run() {  # $1 = isolation level
  $P -c "UPDATE shop.product SET price = 10000 WHERE product_id = 301"
  echo "=== Isolation level: $1"
  $P <<SQL &
BEGIN ISOLATION LEVEL $1;
SELECT 'T1 first read  price = ' || price FROM shop.product WHERE product_id = 301;
SELECT pg_sleep(1.5);
SELECT 'T1 second read price = ' || price FROM shop.product WHERE product_id = 301;
COMMIT;
SQL
  sleep 0.5
  $P -c "UPDATE shop.product SET price = 12000 WHERE product_id = 301" && echo "T2 changed price to 12000 and committed"
  wait
}
run "READ COMMITTED"
run "REPEATABLE READ"

echo; echo "=== SERIALIZABLE: write skew prevented (rule: products 401+402 must keep at least one unit in stock)"
$P -c "UPDATE shop.product SET stock_qty = 1 WHERE product_id IN (401,402)"
# Rule: at least one of products 401/402 must remain in stock. Each tx checks the rule then removes one.
tx() {
  $P <<SQL 2>&1 | sed 's/^psql:.*ERROR:/ERROR:/'
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT 'T$1 sees total stock = ' || sum(stock_qty) FROM shop.product WHERE product_id IN (401,402);
SELECT pg_sleep(1);
UPDATE shop.product SET stock_qty = 0 WHERE product_id = $2;
COMMIT;
SQL
}
tx A 401 & tx B 402 & wait
$P -c "SELECT 'final: 401=' || (SELECT stock_qty FROM shop.product WHERE product_id=401) || ' 402=' || (SELECT stock_qty FROM shop.product WHERE product_id=402)"
