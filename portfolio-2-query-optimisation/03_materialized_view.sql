-- Q3 reads ~all payments/items, so an index cannot help. Pre-aggregate instead (trade-off: data is as fresh as the last REFRESH).
SET search_path = shop;
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_category_revenue;
CREATE MATERIALIZED VIEW mv_monthly_category_revenue AS
SELECT parent.name AS category, date_trunc('month', pay.paid_at) AS month, SUM(pay.amount) AS revenue
FROM payment pay
JOIN order_item oi ON oi.order_id = pay.order_id
JOIN product p     ON p.product_id = oi.product_id
JOIN category c    ON c.category_id = p.category_id
JOIN category parent ON parent.category_id = c.parent_id
WHERE pay.status = 'SUCCESS'
GROUP BY parent.name, date_trunc('month', pay.paid_at);
CREATE UNIQUE INDEX ux_mv_cat_month ON mv_monthly_category_revenue (category, month); -- enables REFRESH ... CONCURRENTLY
-- REFRESH MATERIALIZED VIEW CONCURRENTLY shop.mv_monthly_category_revenue;   -- schedule nightly (pg_cron / cron)
