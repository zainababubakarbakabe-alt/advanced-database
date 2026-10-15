-- Demo F: OPTIMISTIC concurrency control with a version column (no locks held while the user edits).
-- Scenario: two sellers' staff edit the same product price in the admin page.
SET search_path = shop;
ALTER TABLE product ADD COLUMN IF NOT EXISTS version INT NOT NULL DEFAULT 1;
UPDATE product SET price = 50000, version = 1 WHERE product_id = 601;

\echo '--- both editors load the product (each sees version 1)'
SELECT product_id, price, version FROM product WHERE product_id = 601;

\echo '--- editor A saves: UPDATE ... WHERE version = 1  -> 1 row, version becomes 2'
UPDATE product SET price = 52000, version = version + 1 WHERE product_id = 601 AND version = 1;

\echo '--- editor B saves with the STALE version 1 -> 0 rows: the app must reload and tell the user'
UPDATE product SET price = 48000, version = version + 1 WHERE product_id = 601 AND version = 1;

SELECT product_id, price, version FROM product WHERE product_id = 601;
