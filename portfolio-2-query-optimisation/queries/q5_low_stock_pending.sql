-- Q5: operational query - products in the Phones category running low (restock alert)
SELECT product_id, name, stock_qty
FROM shop.product
WHERE category_id = 5 AND stock_qty < 10
ORDER BY stock_qty, product_id;
