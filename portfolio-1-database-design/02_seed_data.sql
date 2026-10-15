-- Synthetic data (generate_series + random) so query plans are meaningful.
SET search_path = shop;
DO $$ BEGIN PERFORM setseed(0.42); END $$;   -- fixed seed: the same data (and the same plans) on every run

INSERT INTO category(name,parent_id) VALUES
 ('Electronics',NULL),('Fashion',NULL),('Home & Kitchen',NULL),('Groceries',NULL);
INSERT INTO category(name,parent_id) VALUES
 ('Phones',1),('Laptops',1),('Men''s Wear',2),('Women''s Wear',2),('Cookware',3),('Staples',4);

INSERT INTO seller(business_name,rating)
 SELECT 'Seller ' || g, round((3 + random()*2)::numeric,1) FROM generate_series(1,200) g;

-- 50,000 customers, one default address each
INSERT INTO customer(full_name,email,phone)
 SELECT 'Customer ' || g, 'user' || g || '@mail.ng', '080' || lpad((10000000 + g)::text,8,'0')
 FROM generate_series(1,50000) g;

INSERT INTO address(customer_id,street,city,state,is_default)
 SELECT g, g || ' Main Street',
        (ARRAY['Abuja','Lagos','Port Harcourt','Kano','Ibadan','Enugu'])[1 + g % 6],
        (ARRAY['FCT','Lagos','Rivers','Kano','Oyo','Enugu'])[1 + g % 6], TRUE
 FROM generate_series(1,50000) g;

-- 20,000 products (categories 5..10 are the leaf categories)
INSERT INTO product(seller_id,category_id,name,price,stock_qty)
 SELECT 1 + g % 200, 5 + g % 6, 'Product ' || g,
        round((1000 + random()*499000)::numeric,2), (random()*500)::int
 FROM generate_series(1,20000) g;

-- 200,000 orders over the last two years (address = the customer's own default address)
INSERT INTO orders(customer_id,address_id,status,order_date)
 SELECT c, c,
        (ARRAY['PENDING','PAID','SHIPPED','DELIVERED','DELIVERED','DELIVERED','CANCELLED'])[1 + (random()*6)::int],
        now() - (random()*730 || ' days')::interval
 FROM (SELECT 1 + (random()*49999)::int AS c FROM generate_series(1,200000)) s;

-- 3 distinct products per order
INSERT INTO order_item(order_id,product_id,quantity,unit_price)
 SELECT o.order_id, p.product_id, 1 + (random()*3)::int, p.price
 FROM orders o
 CROSS JOIN LATERAL (
   SELECT product_id, price FROM product
   WHERE product_id BETWEEN 1 + (o.order_id % 19000) AND 1 + (o.order_id % 19000) + 2
 ) p;

INSERT INTO payment(order_id,method,amount,status,paid_at)
 SELECT o.order_id,
        (ARRAY['CARD','TRANSFER','USSD','WALLET'])[1 + (random()*3)::int],
        sum(oi.quantity*oi.unit_price),
        CASE WHEN o.status='CANCELLED' THEN 'REFUNDED' WHEN o.status='PENDING' THEN 'FAILED' ELSE 'SUCCESS' END,
        o.order_date
 FROM orders o JOIN order_item oi USING(order_id) GROUP BY o.order_id, o.status, o.order_date;

INSERT INTO delivery(order_id,courier,status)
 SELECT order_id, (ARRAY['GIG Logistics','Kwik','DHL'])[1 + order_id % 3],
        CASE status WHEN 'DELIVERED' THEN 'DELIVERED' WHEN 'SHIPPED' THEN 'IN_TRANSIT' ELSE 'PROCESSING' END
 FROM orders WHERE status IN ('SHIPPED','DELIVERED','PAID');

INSERT INTO review(product_id,customer_id,rating,comment)
 SELECT DISTINCT ON (product_id, customer_id) product_id, customer_id, 1 + (random()*4)::int, 'Sample review'
 FROM (SELECT 1 + (random()*19999)::int AS product_id, 1 + (random()*49999)::int AS customer_id
       FROM generate_series(1,60000)) r;

ANALYZE;
