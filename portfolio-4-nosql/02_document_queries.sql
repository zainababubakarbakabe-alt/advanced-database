SET search_path = shop;
\echo '--- Q-doc1: phones with exactly 8GB RAM and 128GB storage (no GIN index: sequential scan)'
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF) SELECT product_id, doc->>'name' FROM product_catalog
 WHERE doc @> '{"category":"Phones","attributes":{"ram_gb":8,"storage_gb":128}}';

CREATE INDEX idx_catalog_doc_gin ON product_catalog USING GIN (doc jsonb_path_ops);
ANALYZE product_catalog;

\echo '--- same query with GIN index'
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF) SELECT product_id, doc->>'name' FROM product_catalog
 WHERE doc @> '{"category":"Phones","attributes":{"ram_gb":8,"storage_gb":128}}';

\echo '--- result sample'
SELECT product_id, doc->>'name' AS name, doc->'attributes' AS attrs FROM product_catalog
 WHERE doc @> '{"category":"Phones","attributes":{"ram_gb":8,"storage_gb":128}}' ORDER BY product_id LIMIT 3;

\echo '--- Q-doc2: average rating inside embedded reviews for laptops with 16GB RAM'
SELECT round(avg((r->>'rating')::int),2) AS avg_embedded_rating, count(*) AS laptops
FROM product_catalog, jsonb_array_elements(doc->'recent_reviews') r
WHERE doc @> '{"category":"Laptops","attributes":{"ram_gb":16}}';
