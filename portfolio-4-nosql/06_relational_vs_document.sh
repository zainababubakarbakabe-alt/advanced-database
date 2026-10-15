#!/usr/bin/env bash
# Suitability test: loading ONE product page (product + category + seller + latest reviews).
# Relational = joins + a sub-query on review; Document = one primary-key read of a JSONB document.
export PGPASSWORD=${PGPASSWORD:-dbadmin}
P="psql -h localhost -U dbadmin -d shopnaija -X -q"
REL="SELECT p.product_id, p.name, p.price, c.name AS category, s.business_name,
       (SELECT json_agg(r) FROM (SELECT rating, comment FROM shop.review WHERE product_id = p.product_id LIMIT 3) r) AS reviews
     FROM shop.product p JOIN shop.category c ON c.category_id = p.category_id JOIN shop.seller s ON s.seller_id = p.seller_id
     WHERE p.product_id = 1234"
DOC="SELECT doc FROM shop.product_catalog WHERE product_id = 1234"
echo "=== relational product page"; $P -c "EXPLAIN (ANALYZE, COSTS OFF) $REL" | grep -E "Scan|Join|Execution Time|SubPlan"
echo; echo "=== document product page"; $P -c "EXPLAIN (ANALYZE, COSTS OFF) $DOC" | grep -E "Scan|Execution Time"
echo; echo "=== 2,000 random product pages each way (id chosen first so each page is an index lookup; length(...::text) forces every value to be fully read)"
$P -c "\timing on" -c "DO \$\$ DECLARE pid int; BEGIN PERFORM setseed(0.1); FOR i IN 1..2000 LOOP pid := 1 + (random()*19999)::int;
        PERFORM length(p.name || c.name || s.business_name ||
        (SELECT json_agg(r) FROM (SELECT rating, comment FROM shop.review WHERE product_id = p.product_id LIMIT 3) r)::text)
      FROM shop.product p JOIN shop.category c USING (category_id) JOIN shop.seller s USING (seller_id)
      WHERE p.product_id = pid; END LOOP; END \$\$;" | grep -E "^Time" | sed 's/^/relational: /'
$P -c "\timing on" -c "DO \$\$ DECLARE pid int; BEGIN PERFORM setseed(0.1); FOR i IN 1..2000 LOOP pid := 1 + (random()*19999)::int;
        PERFORM length(doc::text) FROM shop.product_catalog WHERE product_id = pid; END LOOP; END \$\$;" | grep -E "^Time" | sed 's/^/document:   /'
