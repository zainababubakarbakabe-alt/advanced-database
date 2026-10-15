-- Database users and least-privilege access (the "users of the database" in the case study statement).
SET search_path = shop;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='naijacart_app')     THEN CREATE ROLE naijacart_app NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='naijacart_analyst') THEN CREATE ROLE naijacart_analyst NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='naijacart_finance') THEN CREATE ROLE naijacart_finance NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='analyst_ada')       THEN CREATE ROLE analyst_ada LOGIN PASSWORD 'ada' IN ROLE naijacart_analyst; END IF;
END $$;

REVOKE ALL ON SCHEMA shop FROM PUBLIC;
GRANT USAGE ON SCHEMA shop TO naijacart_app, naijacart_analyst, naijacart_finance;

-- Web application: reads catalogue, writes orders; may not delete orders or payments (audit trail).
GRANT SELECT ON ALL TABLES IN SCHEMA shop TO naijacart_app;
GRANT INSERT, UPDATE ON customer, address, orders, order_item, payment, delivery, review, stock_log TO naijacart_app;
GRANT UPDATE (stock_qty) ON product TO naijacart_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA shop TO naijacart_app;

-- Analyst: read-only, and only through a view without personal data (NDPA 2023 data minimisation).
CREATE OR REPLACE VIEW v_sales_anonymised AS
SELECT o.order_id, o.order_date, o.status, a.state AS delivery_state,
       oi.product_id, oi.quantity, oi.unit_price
FROM orders o JOIN order_item oi USING (order_id) JOIN address a ON a.address_id = o.address_id;
GRANT SELECT ON v_sales_anonymised, product, category, seller TO naijacart_analyst;

-- Finance: payments and orders only.
GRANT SELECT ON payment, orders TO naijacart_finance;
