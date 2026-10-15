#!/usr/bin/env bash
# Rebuilds the database and regenerates EVERY file in the results/ folders, in order.
# Needs: PostgreSQL 16 on :5432 (database shopnaija, user dbadmin), Redis on :6379, bash, Graphviz.
# Portfolio 5 additionally needs a streaming replica on :5433 - see portfolio-5-distributed-cloud/README.md.
set -uo pipefail
export PGPASSWORD=${PGPASSWORD:-dbadmin}
P="psql -h localhost -U dbadmin -d shopnaija -X -v ON_ERROR_STOP=1"
ROOT=$(cd "$(dirname "$0")" && pwd)

echo "[P0] remove Portfolio 5 objects from a previous run (foreign tables would break ANALYZE if node B is down)"
$P -q -c "DROP SCHEMA IF EXISTS sharded CASCADE;" -c "DROP SERVER IF EXISTS shard_b CASCADE;" 2>/dev/null

echo "[P1] schema, seed data, roles, ERD"
cd "$ROOT/portfolio-1-database-design"; mkdir -p results
$P -q -f 01_schema.sql 2>/dev/null && $P -q -f 02_seed_data.sql && $P -q -f 03_roles_security.sql
$P -c "SELECT 'customer' AS table_name, count(*) FROM shop.customer UNION ALL SELECT 'product', count(*) FROM shop.product
       UNION ALL SELECT 'orders', count(*) FROM shop.orders UNION ALL SELECT 'order_item', count(*) FROM shop.order_item
       UNION ALL SELECT 'payment', count(*) FROM shop.payment UNION ALL SELECT 'delivery', count(*) FROM shop.delivery
       UNION ALL SELECT 'review', count(*) FROM shop.review" > results/row_counts.txt
./04_test_roles.sh > results/04_roles_output.txt 2>&1
dot -Tpng -Gdpi=130 diagrams/erd.dot -o diagrams/erd.png

echo "[P2] query optimisation"
cd "$ROOT/portfolio-2-query-optimisation"; mkdir -p results; rm -f results/*.txt
$P -Atc "SELECT indexname FROM pg_indexes WHERE schemaname='shop' ORDER BY 1" > results/indexes_before.txt
./run_benchmarks.sh before
$P -q -f 02_indexes.sql
./run_benchmarks.sh after
$P -Atc "SELECT indexname FROM pg_indexes WHERE schemaname='shop' ORDER BY 1" > results/indexes_after.txt
$P -q -f 03_materialized_view.sql 2>/dev/null
$P -q -c "SET max_parallel_workers_per_gather=0" -c "EXPLAIN (ANALYZE, BUFFERS) SELECT category, month, revenue FROM shop.mv_monthly_category_revenue ORDER BY month, category" > results/after_q3_materialized_view.txt
$P -f 04_tradeoffs.sql > results/04_tradeoffs_output.txt 2>&1
./05_work_mem_test.sh > results/05_work_mem_output.txt 2>&1
./06_parallel_query_test.sh > results/06_parallel_query_output.txt 2>&1
./timing_summary.sh > results/timing_summary.txt

echo "[P3] transactions and concurrency"
cd "$ROOT/portfolio-3-transactions-concurrency"; mkdir -p results
$P -q -f 01_place_order_function.sql
psql -h localhost -U dbadmin -d shopnaija -X -f 02_commit_rollback.sql > results/02_commit_rollback_output.txt 2>&1
for s in 03_lost_update 04_isolation_levels 05_deadlock 06_serializable_retry 08_mvcc_visibility; do ./$s.sh > results/${s}_output.txt 2>&1; done
psql -h localhost -U dbadmin -d shopnaija -X -f 07_optimistic_locking.sql > results/07_optimistic_locking_output.txt 2>&1

echo "[P4] NoSQL"
cd "$ROOT/portfolio-4-nosql"; mkdir -p results
$P -q -f 01_document_model_jsonb.sql > results/01_document_model_output.txt 2>&1
$P -q -f 02_document_queries.sql > results/02_document_queries_output.txt 2>&1
./run_redis_demo.sh > results/03_redis_output.txt 2>&1
./06_relational_vs_document.sh > results/06_relational_vs_document_output.txt 2>&1

echo "done. Portfolio 5 is run separately (it stops and promotes servers)."
