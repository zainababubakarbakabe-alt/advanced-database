#!/usr/bin/env bash
# Full-scan analytics (Q3, Q4, Q6) cannot be helped by indexes - can parallel workers help instead?
export PGPASSWORD=${PGPASSWORD:-dbadmin}
echo "machine CPUs: $(nproc)"
for q in q3_revenue_by_category q4_seller_rank_window q6_cte_repeat_customers; do
  Q=$(grep -v '^--' queries/$q.sql | tr '\n' ' ' | sed 's/;\s*$//')
  for w in 0 2 4; do
    med=$(for i in 1 2 3 4 5; do psql -h localhost -U dbadmin -d shopnaija -X -q -c "SET max_parallel_workers_per_gather = $w" \
          -c "EXPLAIN (ANALYZE) $Q" | awk '/Execution Time/{print $3}'; done | sort -n | sed -n 3p)
    launched=$(psql -h localhost -U dbadmin -d shopnaija -X -q -c "SET max_parallel_workers_per_gather = $w" -c "EXPLAIN (ANALYZE) $Q" | awk '/Workers Launched/{print $3; exit}')
    printf "%-26s workers=%s  launched=%-3s median=%9s ms\n" "$q" "$w" "${launched:-0}" "$med"
  done
done
