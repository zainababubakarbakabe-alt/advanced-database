# Portfolio 5 - Distributed and Cloud Database Exercise

Same case study. Goals for NaijaCart: **survive a server failure, scale reads for browsing, scale writes as orders grow, and stay close to Nigerian users.** Two parts: a *hands-on* demonstration on two PostgreSQL servers, and a *cloud deployment design*.

## Part A - Replication and failover (executed) - `01_replication_demo.sh`
Setup: primary on port 5432, hot-standby replica on 5433, built with `pg_basebackup -R -X stream` (physical streaming replication). Output: `results/01_replication_output.txt`.

| Step | Result |
|---|---|
| `pg_stat_replication` | state `streaming`, sync_state **async**, sent_lsn = replay_lsn |
| Write on primary (`price = 99999`) | Visible on replica |
| Write attempted on replica | `ERROR: cannot execute UPDATE in a read-only transaction` |
| 10,000-row bulk insert | Replica replay delay about 0.1 s; all 10,000 rows visible after 1 s |
| Switched to **synchronous** replication (`synchronous_standby_names = '*'`) | sync_state `sync`; a commit with the standby up returned in about 50 ms |
| Standby stopped while synchronous | The next commit **blocked**: after 3 s it was still `active` with `wait_event = SyncRep` |
| That waiting commit cancelled | `WARNING: canceling wait for synchronous replication` - committed locally, **not** confirmed on any standby |
| Primary stopped (`-m immediate`), replica promoted | `pg_is_in_recovery() = false`; writes accepted; service continued |

**Availability vs consistency (CAP/PACELC), demonstrated rather than only described.**
* *Asynchronous* (default): the primary does not wait for the replica, so commits are fast and the primary stays writable if the replica dies. Cost: replicas can be briefly stale (about 0.1 s measured), and on a crash the last transactions not yet shipped are lost.
* *Synchronous*: each commit waits for the standby to confirm, so a failover loses nothing. The test proved the cost: with the only synchronous standby down, **writes stopped**. That is CAP's choice of consistency over availability during a partition, and PACELC's latency cost even when healthy.
* **NaijaCart decision:** synchronous replication to **at least one of two** standbys (`synchronous_standby_names = 'ANY 1 (s1, s2)'`) for the order/payment database, so one standby can fail without blocking checkout; asynchronous replicas for catalogue browsing and reports, where slightly stale reads are acceptable.

## Part B - Sharding (executed) - `02_sharding_demo.sql`, `02a_shard_node_b.sql`
Orders are partitioned by `HASH(customer_id)` into two shards: shard 1 = local partition on node A, shard 2 = foreign table on node B through `postgres_fdw`.
* 20,000 orders inserted through the parent table were routed automatically: **10,098 on node A, 9,902 on node B** (even spread).
* `WHERE customer_id = 4242` -> plan touches **only** `orders_s1` (partition pruning): one shard, one network hop at most.
* `GROUP BY status` across all customers -> `Append` over `Seq Scan orders_s1` **and** `Foreign Scan orders_s2` (scatter-gather).
* Why `customer_id` as shard key: the most frequent queries (order history, cart, checkout) are per-customer, so they hit one shard. Cost: cross-customer analytics must contact all shards, and a hot seller or a re-sharding event is harder. Foreign keys cannot span shards, so integrity across shards moves to the application.
* Demo limitation: both "nodes" run on one machine and the second node was the promoted replica. Production would use separate hosts or a purpose-built distributed SQL system (Citus, CockroachDB, YugabyteDB).

## Part C - Cloud deployment design (discussion, not deployed)
```
Users (Nigeria) -> CDN + WAF -> Load balancer -> App servers (autoscaled)
                                   |-- Managed PostgreSQL: Multi-AZ primary + 2 read replicas   (orders, payments, stock)
                                   |-- Managed Redis (cache, carts, sessions, flash sale)
                                   |-- MongoDB Atlas / document store (catalogue)   [optional]
                                   `-- Object storage (product images) + nightly backups, point-in-time recovery
```
| Concern | Design choice |
|---|---|
| Region / latency | Closest cloud region to Nigerian users (for example AWS Africa (Cape Town) or Azure South Africa North) plus a CDN, or a Lagos colocation data centre; verify current regions and prices before deciding |
| Data protection (NDPA 2023) | Customer personal data leaving Nigeria counts as a cross-border transfer and needs a lawful basis and safeguards; keeping the primary database in Nigeria simplifies compliance. Analytics replicas receive the anonymised view only (Portfolio 1 roles) |
| High availability | Multi-AZ managed PostgreSQL with automatic failover (same idea as Part A, but automated) |
| Read scaling | Route catalogue/search/reporting to read replicas; accept replica lag |
| Write scaling | Vertical scale first, then shard by `customer_id` when a single primary is the bottleneck |
| Consistency | Strong (synchronous) for payments/stock; eventual for reviews, recommendations, counters |
| Backup / DR | Daily snapshots + continuous WAL archiving (point-in-time recovery); cross-region copy; test restores |
| Security | Private subnets, TLS in transit, encryption at rest, least-privilege roles; card data left to the payment gateway (PCI-DSS scope) |
| Cost | Reserved instances for the primary, autoscaling for stateless app tier, replicas only where load justifies them |

`docker-compose.yml` (repository root) starts PostgreSQL + Redis (+ MongoDB) so the exercises are reproducible on any laptop.
