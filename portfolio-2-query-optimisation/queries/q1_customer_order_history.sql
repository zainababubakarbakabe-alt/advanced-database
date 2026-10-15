-- Q1: order history for one customer (most frequent customer-facing query)
SELECT o.order_id, o.order_date, o.status, SUM(oi.quantity*oi.unit_price) AS order_total
FROM shop.orders o
JOIN shop.order_item oi ON oi.order_id = o.order_id
WHERE o.customer_id = 4242
GROUP BY o.order_id, o.order_date, o.status
ORDER BY o.order_date DESC;
