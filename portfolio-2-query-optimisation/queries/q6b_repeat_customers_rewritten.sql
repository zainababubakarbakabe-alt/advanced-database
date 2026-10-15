-- Q6b: rewrite of Q6 - total each order once, then group per customer with COUNT(*) (no COUNT(DISTINCT), no big sort)
WITH order_totals AS (
  SELECT o.customer_id, o.order_id, SUM(oi.quantity*oi.unit_price) AS total
  FROM shop.orders o JOIN shop.order_item oi ON oi.order_id = o.order_id
  WHERE o.status = 'DELIVERED'
  GROUP BY o.customer_id, o.order_id
), spend AS (
  SELECT customer_id, COUNT(*) AS orders, SUM(total) AS lifetime_value
  FROM order_totals GROUP BY customer_id HAVING COUNT(*) >= 5
)
SELECT c.customer_id, c.full_name, s.orders, s.lifetime_value
FROM spend s JOIN shop.customer c ON c.customer_id = s.customer_id
ORDER BY s.lifetime_value DESC
LIMIT 10;
