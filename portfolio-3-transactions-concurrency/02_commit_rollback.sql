-- Demo A: COMMIT and ROLLBACK (atomicity). Product 101 is set to stock 5 for the demo.
SET search_path = shop;
UPDATE product SET stock_qty = 5 WHERE product_id = 101;
\echo '--- stock before'
SELECT product_id, stock_qty FROM product WHERE product_id = 101;

\echo '--- 1) successful order of 2 units: COMMIT'
BEGIN;
SELECT place_order(1, 1, ARRAY[101], ARRAY[2], 'CARD') AS new_order;
COMMIT;
SELECT product_id, stock_qty FROM product WHERE product_id = 101;

\echo '--- 2) order of 10 units (only 3 left): fails, whole transaction rolled back'
BEGIN;
SELECT count(*) AS orders_before FROM orders;
SELECT place_order(1, 1, ARRAY[101], ARRAY[10], 'CARD');
ROLLBACK;                         -- (transaction is already aborted; ROLLBACK ends it)
SELECT count(*) AS orders_after FROM orders;                    -- unchanged: no orphan order row
SELECT product_id, stock_qty FROM product WHERE product_id = 101;  -- still 3

\echo '--- 3) explicit SAVEPOINT: undo only the second item (102 and 103 both start at 50)'
UPDATE product SET stock_qty = 50 WHERE product_id IN (102,103);
BEGIN;
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 102;
SAVEPOINT after_first_item;
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 103;
ROLLBACK TO SAVEPOINT after_first_item;
COMMIT;
SELECT product_id, stock_qty FROM product WHERE product_id IN (102,103) ORDER BY 1;
