-- Indexes chosen from the BEFORE plans (see results/). PostgreSQL does not auto-index foreign keys.
SET search_path = shop;
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date DESC);   -- Q1 (equality + sort)
CREATE INDEX idx_orders_date          ON orders (order_date) WHERE status <> 'CANCELLED'; -- Q2 (partial index)
CREATE INDEX idx_order_item_product   ON order_item (product_id);                  -- Q2/Q4 join on product
CREATE INDEX idx_product_cat_stock    ON product (category_id, stock_qty) INCLUDE (name); -- Q5 covering index
CREATE INDEX idx_orders_delivered     ON orders (customer_id) WHERE status = 'DELIVERED';   -- Q6 partial
ANALYZE;
