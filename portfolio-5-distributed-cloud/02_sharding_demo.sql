-- Application-level sharding by customer_id using hash partitioning + postgres_fdw.
-- Shard 1 = node A (:5432, local partition); Shard 2 = node B (:5433, foreign partition).
-- Run this file on node A (psql -p 5432). Node B must already have table shard2_orders (see 02a_shard_node_b.sql).
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
DROP SCHEMA IF EXISTS sharded CASCADE;
CREATE SCHEMA sharded;
DROP SERVER IF EXISTS shard_b CASCADE;
CREATE SERVER shard_b FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'localhost', port '5433', dbname 'shopnaija');
CREATE USER MAPPING FOR dbadmin SERVER shard_b OPTIONS (user 'dbadmin', password 'dbadmin');

CREATE TABLE sharded.orders (
  order_id BIGINT NOT NULL, customer_id BIGINT NOT NULL, status VARCHAR(12) NOT NULL, order_date TIMESTAMPTZ NOT NULL, total NUMERIC(14,2) NOT NULL
) PARTITION BY HASH (customer_id);

CREATE TABLE sharded.orders_s1 PARTITION OF sharded.orders FOR VALUES WITH (MODULUS 2, REMAINDER 0);   -- local
CREATE FOREIGN TABLE sharded.orders_s2 PARTITION OF sharded.orders FOR VALUES WITH (MODULUS 2, REMAINDER 1)
  SERVER shard_b OPTIONS (schema_name 'public', table_name 'shard2_orders');                            -- remote

\echo '--- insert 20,000 orders through the parent table: rows are routed by hash(customer_id)'
INSERT INTO sharded.orders
SELECT o.order_id, o.customer_id, o.status, o.order_date, 1000 + o.order_id % 5000
FROM shop.orders o WHERE o.order_id <= 20000;

\echo '--- rows per shard'
SELECT 'shard 1 (node A)' AS shard, count(*) FROM ONLY sharded.orders_s1
UNION ALL SELECT 'shard 2 (node B)', count(*) FROM sharded.orders_s2;

\echo '--- single-customer query: partition pruning sends it to ONE shard'
EXPLAIN (COSTS OFF) SELECT * FROM sharded.orders WHERE customer_id = 4242;

\echo '--- cross-shard analytical query: must contact both shards (scatter-gather)'
EXPLAIN (COSTS OFF) SELECT status, count(*), sum(total) FROM sharded.orders GROUP BY status;
SELECT status, count(*), sum(total) FROM sharded.orders GROUP BY status ORDER BY status;
