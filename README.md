# NaijaCart - Advanced Database Portfolio

Coursework portfolio for Advanced Database Systems. The project uses a simulated Nigerian e-commerce marketplace called **NaijaCart** (similar to Jumia or Konga) to test relational schema design, indexing, transactions, NoSQL models, and distributed database setups.

## Folders

* `portfolio-1-database-design`: 11-table BCNF schema, seed data, ER diagram, and user roles.
* `portfolio-2-query-optimisation`: 7 queries tested with EXPLAIN ANALYZE before and after indexing, plus a materialized view test.
* `portfolio-3-transactions-concurrency`: Checkout function, concurrency tests (lost updates, deadlocks, isolation levels), and locking.
* `portfolio-4-nosql`: PostgreSQL JSONB document catalogue, Redis for carts/sessions, and MongoDB/graph designs.
* `portfolio-5-distributed-cloud`: Streaming replication, failover test, and hash sharding with `postgres_fdw`.
* `docs`: The 3-page report (`final-documentation.pdf`), Word copy, and screenshots.

## Quick Start

You will need PostgreSQL (14 or 16) and Redis running locally.

To set up the database and run all benchmarks for Portfolios 1 to 4:

```bash
createdb shopnaija
./run_all.sh
```

This takes about 2 minutes. It loads 50,000 customers, 20,000 products, 200,000 orders, and 600,000 order items. The seed uses `setseed(0.42)`, so the data and query plans are identical on every run.

Portfolio 5 involves stopping and promoting database nodes, so it is run separately (instructions are inside `portfolio-5-distributed-cloud/README.md`).

## What's Executed vs Designed

* **Tested & executed:** Everything in Portfolios 1, 2, and 3; the PostgreSQL JSONB and Redis parts of Portfolio 4; and the replication and sharding demos in Portfolio 5. All terminal outputs and plans are saved in each folder's `results/` directory.
* **Designs only:** The MongoDB script and Neo4j Cypher recommendation model in Portfolio 4, and the multi-region AWS setup in Portfolio 5 are architectural designs submitted for comparison.

## Report

The required LMS documentation is in [docs/final-documentation.pdf](docs/final-documentation.pdf) (Word version is in [docs/final-documentation.docx](docs/final-documentation.docx)).
