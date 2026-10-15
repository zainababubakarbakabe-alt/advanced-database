#!/usr/bin/env bash
# Demo G: MVCC - readers never wait for writers, and PostgreSQL never shows uncommitted data
# (READ UNCOMMITTED behaves as READ COMMITTED). xmin = id of the transaction that created the row version.
export PGPASSWORD=${PGPASSWORD:-dbadmin}
P="psql -h localhost -U dbadmin -d shopnaija -X -q -t -A"
$P -c "UPDATE shop.product SET price = 70000 WHERE product_id = 701"
$P -c "SELECT 'before: price=' || price || ' xmin=' || xmin FROM shop.product WHERE product_id = 701"
$P <<SQL &
BEGIN;
UPDATE shop.product SET price = 75000 WHERE product_id = 701;
SELECT 'writer (uncommitted): price=75000, holds row lock for 2 s';
SELECT pg_sleep(2);
COMMIT;
SQL
sleep 0.5
start=$(date +%s%N)
$P -c "BEGIN ISOLATION LEVEL READ UNCOMMITTED; SELECT 'reader during write (READ UNCOMMITTED): price=' || price FROM shop.product WHERE product_id = 701; COMMIT;"
echo "reader waited $(( ($(date +%s%N) - start) / 1000000 )) ms (no blocking)"
wait
$P -c "SELECT 'after commit: price=' || price || ' xmin=' || xmin || ' (new row version)' FROM shop.product WHERE product_id = 701"
