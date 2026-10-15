-- Q2: top 10 best-selling products in the last 90 days (excludes cancelled orders)
SELECT p.product_id, p.name, SUM(oi.quantity) AS units_sold
FROM shop.orders o
JOIN shop.order_item oi ON oi.order_id = o.order_id
JOIN shop.product p     ON p.product_id = oi.product_id
WHERE o.order_date >= now() - interval '90 days'
  AND o.status <> 'CANCELLED'
GROUP BY p.product_id, p.name
ORDER BY units_sold DESC
LIMIT 10;
