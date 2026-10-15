-- Measures the COST side of optimisation: index storage, write slowdown, materialized-view refresh time.
SET search_path = shop;
\timing on
\echo '--- index sizes (storage cost)'
SELECT indexrelname AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes WHERE schemaname='shop' AND relname IN ('orders','order_item','product')
ORDER BY pg_relation_size(indexrelid) DESC;

\echo '--- write cost: insert 20,000 orders into a copy WITHOUT the extra indexes'
CREATE TEMP TABLE orders_noidx (LIKE orders INCLUDING DEFAULTS);
INSERT INTO orders_noidx (order_id, customer_id, address_id, status, order_date)
  SELECT g, 1 + g % 50000, 1 + g % 50000, 'PAID', now() FROM generate_series(1,20000) g;

\echo '--- same insert into a copy WITH the same three orders indexes'
CREATE TEMP TABLE orders_idx (LIKE orders INCLUDING DEFAULTS);
CREATE INDEX ON orders_idx (customer_id, order_date DESC);
CREATE INDEX ON orders_idx (order_date) WHERE status <> 'CANCELLED';
CREATE INDEX ON orders_idx (customer_id) WHERE status = 'DELIVERED';
INSERT INTO orders_idx (order_id, customer_id, address_id, status, order_date)
  SELECT g, 1 + g % 50000, 1 + g % 50000, 'PAID', now() FROM generate_series(1,20000) g;

\echo '--- freshness cost: refreshing the materialized view (without blocking readers)'
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_category_revenue;
