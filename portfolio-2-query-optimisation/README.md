# Portfolio 2 - Query Processing and Optimisation

PostgreSQL 16 on 200,000 orders / 600,000 order items (identical data every run, fixed seed).

**Method.** For each query: capture the full `EXPLAIN (ANALYZE, BUFFERS)` plan, then run it 5 more times and take the **median** (single timings vary about 10-20%). Do this with no extra indexes (`before`), add indexes chosen *from the plans*, repeat (`after`). Parallel query is switched off for the main comparison (`max_parallel_workers_per_gather = 0`) so plans are comparable, then tested separately. Raw evidence in `results/`.

```bash
./run_benchmarks.sh before && psql -d shopnaija -f 02_indexes.sql && ./run_benchmarks.sh after && ./timing_summary.sh
```

## Queries
| # | Business question | SQL features |
|---|---|---|
| Q1 | A customer's order history with totals | JOIN, GROUP BY, ORDER BY |
| Q2 | Top 10 products in the last 90 days | 3-table JOIN, date filter, aggregation, LIMIT |
| Q3 | Revenue per parent category per month | 5-table JOIN incl. self-join on category tree |
| Q4 | Top 3 sellers in each category | Window function `RANK() OVER (PARTITION BY ...)` |
| Q5 | Phones with fewer than 10 units (restock alert) | Selective filter |
| Q6 / Q6b | Customers with 5+ delivered orders and lifetime value | CTEs, `COUNT(DISTINCT)`; Q6b is a rewrite |

## Results (`results/timing_summary.txt`, medians of 5)
| Query | Before (ms) | After indexes (ms) | Speed-up | Why (from the plans) |
|---|---:|---:|---:|---|
| Q1 | 12.0 | 0.31 | **38.6x** | Seq Scan over 200k orders replaced by Bitmap Index Scan on `(customer_id, order_date DESC)` - 2 rows needed |
| Q2 | 196.0 | 161.9 | 1.2x | Partial index on `order_date` removes the orders scan, but ~22k orders x 3 items still have to be joined and aggregated |
| Q3 | 952.1 | 959.5 | 1.0x | Reads almost every payment and item: nothing for an index to skip |
| Q4 | 457.3 | 446.8 | 1.0x | Reads all 600k items: same reason |
| Q5 | 1.35 | 0.26 | **5.1x** | Covering index `(category_id, stock_qty) INCLUDE (name)` |
| Q6 | 429.0 | 432.7 | 1.0x | Full scan of delivered orders; see work_mem test |
| Q6b | 424.1 | 435.2 | 1.0x | Rewrite did not change the dominant cost |

## Fixing the queries that indexes could not help
| Technique | Query | Result | Evidence |
|---|---|---|---|
| **Materialized view** (pre-aggregation) | Q3 | 952 ms -> **0.09 ms** read; refresh costs **567 ms** | `after_q3_materialized_view.txt`, `04_tradeoffs_output.txt` |
| **Parallel query** (2 CPUs) | Q3 | 1062 -> **606 ms** (1.8x) | `06_parallel_query_output.txt` |
| | Q4 | 435 -> **239 ms** (1.8x) | same |
| | Q6 | no workers launched | planner will not parallelise `COUNT(DISTINCT)` |
| **More `work_mem`** (4 MB -> 64 MB) | Q6 | Sort moved from **disk** (11 MB external merge) to **memory** (quicksort), but time did **not** improve (438-610 ms vs 480-555 ms) | `05_work_mem_output.txt` |

**Interpretation.** The Q6 plan pointed at the disk sort, but fixing it proved the sort was not the bottleneck: the hash join and aggregation over ~300k rows are. This is why diagnoses must be tested, not assumed. Q4 and Q3 scale with CPUs because their work divides cleanly across workers; with only 2 CPUs, asking for 4 workers still launched 2.

## The cost side (`04_tradeoffs.sql`)
| Cost | Measurement |
|---|---|
| Storage | The 5 new indexes use about **16.7 MB** (largest: `idx_orders_customer_date` 6.0 MB) |
| Write speed | Inserting 20,000 orders: **15.3 ms** without the three orders indexes vs **42.3 ms** with them (**2.8x slower**) |
| Freshness | The materialized view is only as current as its last refresh; `REFRESH ... CONCURRENTLY` took **567 ms** without blocking readers |

**Decision.** Keep indexes that serve frequent, selective, customer-facing queries (Q1, Q5). Do not add indexes for full-scan analytics: use the materialized view refreshed nightly (Q3), parallel workers, and in production run reports on a read replica (Portfolio 5) so they never compete with checkout.

## Files
`queries/` (7 queries), `02_indexes.sql`, `03_materialized_view.sql`, `04_tradeoffs.sql`, `05_work_mem_test.sh`, `06_parallel_query_test.sh`, `run_benchmarks.sh`, `timing_summary.sh`, `results/` (plans and outputs).
