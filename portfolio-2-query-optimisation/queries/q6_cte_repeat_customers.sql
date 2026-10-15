-- Q6: CTE - customers with 5+ delivered orders and their lifetime spend
WITH delivered AS (
  SELECT o.customer_id, o.order_id
  FROM shop.orders o WHERE o.status = 'DELIVERED'
), spend AS (
  SELECT d.customer_id, COUNT(DISTINCT d.order_id) AS orders, SUM(oi.quantity*oi.unit_price) AS lifetime_value
  FROM delivered d JOIN shop.order_item oi ON oi.order_id = d.order_id
  GROUP BY d.customer_id
)
SELECT c.customer_id, c.full_name, s.orders, s.lifetime_value
FROM spend s JOIN shop.customer c ON c.customer_id = s.customer_id
WHERE s.orders >= 5
ORDER BY s.lifetime_value DESC
LIMIT 10;
