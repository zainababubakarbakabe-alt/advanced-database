-- Q3: revenue per parent category per month for successful payments (analytical query)
SELECT parent.name AS category, date_trunc('month', pay.paid_at) AS month,
       SUM(pay.amount) AS revenue
FROM shop.payment pay
JOIN shop.order_item oi ON oi.order_id = pay.order_id
JOIN shop.product p     ON p.product_id = oi.product_id
JOIN shop.category c    ON c.category_id = p.category_id
JOIN shop.category parent ON parent.category_id = c.parent_id
WHERE pay.status = 'SUCCESS'
GROUP BY parent.name, date_trunc('month', pay.paid_at)
ORDER BY month, category;
