#!/usr/bin/env bash
# Demo B: LOST UPDATE (READ COMMITTED) then the fixes. Two concurrent sessions buy product 201 (stock = 1).
export PGPASSWORD=${PGPASSWORD:-dbadmin}
P="psql -h localhost -U dbadmin -d shopnaija -X -q -t -A"
$P -c "UPDATE shop.product SET stock_qty = 1 WHERE product_id = 201"

echo "=== B1. BROKEN pattern: read stock in app, then write back (read-modify-write)"
session_bad() {  # $1 = label
  $P <<SQL
BEGIN;
SELECT 'session $1 read stock = ' || stock_qty FROM shop.product WHERE product_id = 201;
SELECT pg_sleep(1);    -- both sessions have now read stock=1
UPDATE shop.product SET stock_qty = 0 WHERE product_id = 201;   -- app computed 1-1 = 0
INSERT INTO shop.stock_log(product_id,change_qty,reason) VALUES (201,-1,'session $1 sold last unit');
COMMIT;
SQL
}
session_bad A & session_bad B & wait
$P -c "SELECT 'units sold (stock_log) = ' || count(*) || ', stock now = ' || (SELECT stock_qty FROM shop.product WHERE product_id=201) FROM shop.stock_log WHERE product_id=201 AND reason LIKE 'session % sold last unit'"
echo "-> 2 customers were told they bought the last unit: OVERSOLD (lost update)."

$P -c "UPDATE shop.product SET stock_qty = 1 WHERE product_id = 201; DELETE FROM shop.stock_log WHERE product_id=201;"
echo; echo "=== B2. FIX 1: pessimistic locking with SELECT ... FOR UPDATE"
session_fu() {
  $P <<SQL
BEGIN;
SELECT 'session $1 got lock, stock = ' || stock_qty FROM shop.product WHERE product_id = 201 FOR UPDATE;
SELECT pg_sleep(1);
WITH u AS (UPDATE shop.product SET stock_qty = stock_qty - 1 WHERE product_id = 201 AND stock_qty >= 1 RETURNING 1)
SELECT 'session $1 units sold: ' || count(*) FROM u;
COMMIT;
SQL
}
session_fu A & sleep 0.2; session_fu B & wait
$P -c "SELECT 'final stock = ' || stock_qty FROM shop.product WHERE product_id = 201"

$P -c "UPDATE shop.product SET stock_qty = 1 WHERE product_id = 201"
echo; echo "=== B3. FIX 2: atomic conditional UPDATE + CHECK constraint (no explicit lock needed)"
session_atomic() {
  $P -c "WITH u AS (UPDATE shop.product SET stock_qty = stock_qty - 1 WHERE product_id = 201 AND stock_qty >= 1 RETURNING 1) SELECT 'session $1 units sold: ' || count(*) FROM u;"
}
session_atomic A & session_atomic B & wait
$P -c "SELECT 'final stock = ' || stock_qty FROM shop.product WHERE product_id = 201"
