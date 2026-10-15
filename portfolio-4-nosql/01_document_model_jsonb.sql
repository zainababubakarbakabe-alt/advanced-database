-- Document model for the PRODUCT CATALOGUE. Phones, laptops and clothes have different attributes,
-- which in a relational schema needs EAV tables or many NULL columns. A document stores them naturally.
SET search_path = shop;
DROP TABLE IF EXISTS product_catalog;
CREATE TABLE product_catalog (
  product_id BIGINT PRIMARY KEY REFERENCES product(product_id),
  doc        JSONB NOT NULL
);

-- Build documents for 20,000 products with category-specific attributes and embedded reviews
INSERT INTO product_catalog(product_id, doc)
SELECT p.product_id,
  jsonb_build_object(
    'name', p.name, 'price', p.price, 'category', c.name,
    'attributes', CASE c.name
        WHEN 'Phones'   THEN jsonb_build_object('ram_gb', (ARRAY[4,6,8,12])[1 + (p.product_id / 6) % 4], 'storage_gb', (ARRAY[64,128,256])[1 + (p.product_id / 6) % 3], 'dual_sim', true)
        WHEN 'Laptops'  THEN jsonb_build_object('cpu', (ARRAY['i5','i7','Ryzen 5'])[1 + (p.product_id / 6) % 3], 'ram_gb', (ARRAY[8,16,32])[1 + (p.product_id / 6) % 3])
        WHEN 'Cookware' THEN jsonb_build_object('material', 'stainless steel', 'pieces', 1 + (p.product_id / 6) % 12)
        ELSE jsonb_build_object('size', (ARRAY['S','M','L','XL'])[1 + (p.product_id / 6) % 4], 'colour', (ARRAY['black','white','blue'])[1 + (p.product_id / 6) % 3])
    END,
    'tags', jsonb_build_array('naijacart', lower(c.name)),
    'recent_reviews', COALESCE((SELECT jsonb_agg(jsonb_build_object('rating', r.rating, 'comment', r.comment))
                                FROM (SELECT rating, comment FROM review WHERE product_id = p.product_id LIMIT 3) r), '[]'::jsonb)
  )
FROM product p JOIN category c ON c.category_id = p.category_id;
ANALYZE product_catalog;

\echo '--- one sample document'
SELECT jsonb_pretty(doc) FROM product_catalog WHERE product_id = 6;   -- product 6 is in the Phones category
