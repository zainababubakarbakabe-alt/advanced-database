#!/usr/bin/env bash
# Proves the permissions: analyst can read the anonymised view but not customer personal data.
P="psql -h localhost -U analyst_ada -d shopnaija -X -q -t -A"
export PGPASSWORD=ada
echo "analyst reads anonymised view:"; $P -c "SELECT count(*) || ' rows' FROM shop.v_sales_anonymised" 2>&1
echo "analyst tries customer emails:";  $P -c "SELECT email FROM shop.customer LIMIT 1" 2>&1 | sed 's/^psql:.*ERROR:/ERROR:/'
echo "analyst tries to delete an order:"; $P -c "DELETE FROM shop.orders WHERE order_id = 1" 2>&1 | sed 's/^psql:.*ERROR:/ERROR:/'
