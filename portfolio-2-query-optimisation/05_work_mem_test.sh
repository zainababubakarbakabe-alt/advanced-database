#!/usr/bin/env bash
# Tests the diagnosis from the Q6 plan ("Sort Method: external merge Disk"): does more work_mem help?
export PGPASSWORD=${PGPASSWORD:-dbadmin}
Q=$(grep -v '^--' queries/q6_cte_repeat_customers.sql | tr '\n' ' ' | sed 's/;\s*$//')
for wm in 4MB 64MB; do
  for i in 1 2 3; do
    psql -h localhost -U dbadmin -d shopnaija -X -q -c "SET max_parallel_workers_per_gather=0" -c "SET work_mem='$wm'" \
      -c "EXPLAIN (ANALYZE) $Q" | grep -E "Sort Method|Execution Time" | sed "s/^/work_mem=$wm run $i: /"
  done
done
