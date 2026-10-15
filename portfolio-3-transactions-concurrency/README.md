# Portfolio 3 - Transactions and Concurrency

Business problem: **never sell stock we do not have**, even when many customers buy the same product at the same moment. All output below is real (see `results/`). Concurrency is produced by running two `psql` sessions in parallel with `pg_sleep()` to force an unlucky interleaving.

| Script | Demonstrates | Evidence |
|---|---|---|
| `01_place_order_function.sql` | One ACID unit of work: create order, lock + decrement stock, items, payment, stock log | - |
| `02_commit_rollback.sql` | COMMIT, ROLLBACK (atomicity), SAVEPOINT | `results/02_commit_rollback_output.txt` |
| `03_lost_update.sh` | Lost update bug and two fixes | `results/03_lost_update_output.txt` |
| `04_isolation_levels.sh` | READ COMMITTED vs REPEATABLE READ vs SERIALIZABLE | `results/04_isolation_levels_output.txt` |
| `05_deadlock.sh` | Deadlock and its prevention | `results/05_deadlock_output.txt` |
| `06_serializable_retry.sh` | SERIALIZABLE with an application retry loop | `results/06_serializable_retry_output.txt` |
| `07_optimistic_locking.sql` | Optimistic concurrency control (version column) | `results/07_optimistic_locking_output.txt` |
| `08_mvcc_visibility.sh` | MVCC: readers do not block, no dirty reads | `results/08_mvcc_visibility_output.txt` |

## A. Commit, rollback, savepoint (atomicity)
* Product 101 had 5 units. Order of **2** units -> `COMMIT` -> stock 3, order 200001 created.
* Order of **10** units -> the `CHECK (stock_qty >= 0)` constraint fails inside the function -> the *whole* transaction rolls back. Evidence: order count stays 200,001 (no orphan order row) and stock stays 3.
* `SAVEPOINT` + `ROLLBACK TO SAVEPOINT`: products 102 and 103 start at 50; after undoing only the second update and committing, 102 = 49 and 103 = 50.

## B. Concurrency problem: lost update (READ COMMITTED)
Two buyers each want the last unit (stock = 1).
* **Broken pattern** (app reads stock, computes `stock - 1`, writes back): both sessions read `1`, both write `0`. Result: **2 units sold, stock 0 -> oversold**. This is the classic read-modify-write race.
* **Fix 1 - pessimistic lock** `SELECT ... FOR UPDATE`: session A locks the row; B waits; when B gets the lock it sees stock 0 -> sold 0 units. Final stock 0, one sale.
* **Fix 2 - atomic conditional update** `UPDATE ... SET stock_qty = stock_qty - 1 WHERE stock_qty >= 1`: A sells 1, B sells 0. No explicit lock in app code; scales better because the lock is held only for the single statement.
* The `CHECK` constraint remains the safety net.

## C. Isolation levels
Transaction T1 reads a price twice while T2 changes it in between:
| Level | T1 first read | T1 second read | Anomaly |
|---|---:|---:|---|
| READ COMMITTED (PostgreSQL default) | 10000 | **12000** | Non-repeatable read |
| REPEATABLE READ | 10000 | **10000** | Prevented (snapshot isolation) |

**SERIALIZABLE** and write skew: rule "at least one of products 401/402 must stay in stock" (both start at 1). Two transactions each check the total (=2) and then zero a different product. Under SERIALIZABLE, PostgreSQL aborted one with `could not serialize access due to read/write dependencies` - in the saved run the final state was 401=0, 402=1: one product kept its unit, so the rule held (which product wins depends on timing). The application must **retry** the failed transaction - shown next.

## D. Deadlock
T1 locks product 501 then 502; T2 locks 502 then 501. PostgreSQL's deadlock detector reported `ERROR: deadlock detected` and aborted one transaction; the other committed. **Prevention:** always lock rows in a consistent order - `place_order()` sorts items by `product_id` before locking, and the re-test with the same order showed no deadlock (T2 simply waited).

## E. SERIALIZABLE with retry (`06_serializable_retry.sh`)
Same rule, but each transaction is wrapped in a loop that retries on SQLSTATE 40001. Output: one transaction committed first time; the other got `serialization failure (40001) -> retrying`, re-ran, and on its second attempt saw the new state and correctly removed nothing. Final stock 401=1, 402=0, so the rule held. Lesson: SERIALIZABLE is only safe if the application is written to retry.

## F. Optimistic locking (`07_optimistic_locking.sql`)
For the seller admin page, where a person may take minutes to edit a product, holding a row lock (pessimistic) is unacceptable. A `version` column is used instead: editor A's `UPDATE ... WHERE version = 1` changed 1 row (version became 2); editor B, still holding version 1, changed **0 rows** - the app detects this and asks B to reload. Final price 52,000 (A's), nothing silently overwritten.

| Approach | Used for in NaijaCart | Why |
|---|---|---|
| Pessimistic (`FOR UPDATE`) | Checkout stock decrement | Short transaction, high contention on popular items |
| Atomic conditional `UPDATE` | Single-row counters | Simplest; lock held for one statement only |
| Optimistic (version column) | Admin editing, long "think time" | No locks held while a human is editing |
| SERIALIZABLE + retry | Rules spanning several rows | Prevents write skew that row locks miss |

## G. MVCC (`08_mvcc_visibility.sh`)
PostgreSQL keeps multiple row versions. While a writer held an **uncommitted** update to product 701 (price 70,000 -> 75,000) and its row lock for 2 seconds, a reader at `READ UNCOMMITTED` still saw **70,000** and returned in **47 ms**, without waiting. After commit, the row's `xmin` changed from 1784 to 1785: a new row version created by the writer's transaction. So in PostgreSQL readers never block writers, writers never block readers, and dirty reads are impossible at every isolation level (`READ UNCOMMITTED` behaves as `READ COMMITTED`). Old versions are later removed by `VACUUM`.

## Design decisions
* Each of the four concurrency approaches above is matched to the situation it suits (table in F).
* Short transactions: no user interaction or external payment call while row locks are held.
* Use the default READ COMMITTED + row-level locking for order placement (high throughput); use SERIALIZABLE only for invariants spanning several rows, with retry logic.
* In a real payment flow the gateway call (Paystack/Flutterwave) happens outside the transaction using an idempotency key; order status is updated when the webhook confirms.
