-- Atomic order placement. Locks product rows in ascending id order (prevents deadlocks),
-- validates stock, writes order + items + payment + stock log. Any error rolls the whole thing back.
SET search_path = shop;
CREATE OR REPLACE FUNCTION place_order(p_customer BIGINT, p_address BIGINT,
                                       p_products BIGINT[], p_qtys INT[], p_method TEXT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_order BIGINT; v_total NUMERIC := 0; r RECORD; i INT;
BEGIN
  INSERT INTO orders(customer_id,address_id,status) VALUES (p_customer,p_address,'PENDING')
  RETURNING order_id INTO v_order;

  FOR r IN SELECT x.pid, x.qty FROM unnest(p_products, p_qtys) AS x(pid, qty) ORDER BY x.pid LOOP
    PERFORM 1 FROM product WHERE product_id = r.pid FOR UPDATE;          -- row lock, consistent order
    UPDATE product SET stock_qty = stock_qty - r.qty WHERE product_id = r.pid;  -- CHECK (stock_qty>=0) guards oversell
    INSERT INTO order_item(order_id,product_id,quantity,unit_price)
      SELECT v_order, r.pid, r.qty, price FROM product WHERE product_id = r.pid;
    INSERT INTO stock_log(product_id,change_qty,reason) VALUES (r.pid, -r.qty, 'ORDER ' || v_order);
    SELECT v_total + price*r.qty INTO v_total FROM product WHERE product_id = r.pid;
  END LOOP;

  INSERT INTO payment(order_id,method,amount,status) VALUES (v_order,p_method,v_total,'SUCCESS');
  UPDATE orders SET status='PAID' WHERE order_id = v_order;
  RETURN v_order;
END $$;
