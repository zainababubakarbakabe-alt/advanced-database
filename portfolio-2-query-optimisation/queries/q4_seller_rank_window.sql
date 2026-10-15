-- Q4: window function - rank sellers by units sold inside each leaf category
SELECT *
FROM (
  SELECT c.name AS category, s.business_name,
         SUM(oi.quantity) AS units,
         RANK() OVER (PARTITION BY c.name ORDER BY SUM(oi.quantity) DESC) AS rnk
  FROM shop.order_item oi
  JOIN shop.product p  ON p.product_id = oi.product_id
  JOIN shop.seller s   ON s.seller_id  = p.seller_id
  JOIN shop.category c ON c.category_id = p.category_id
  GROUP BY c.name, s.business_name
) ranked
WHERE rnk <= 3
ORDER BY category, rnk;
