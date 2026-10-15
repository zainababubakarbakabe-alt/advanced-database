-- Run on node B (psql -p 5433): storage for the second shard.
CREATE TABLE IF NOT EXISTS public.shard2_orders (
  order_id BIGINT NOT NULL, customer_id BIGINT NOT NULL, status VARCHAR(12) NOT NULL, order_date TIMESTAMPTZ NOT NULL, total NUMERIC(14,2) NOT NULL);
TRUNCATE public.shard2_orders;
