# Portfolio 4 - NoSQL and Advanced Data Models

Same case study (NaijaCart). Principle: **keep the relational database for transactions, add NoSQL where the access pattern fits it better** (polyglot persistence).

| Model | Used for | Technology | Executed here? |
|---|---|---|---|
| Document | Product catalogue with category-specific attributes and embedded reviews | PostgreSQL `JSONB` + GIN index (`01`, `02`, `06`); MongoDB version in `04_mongodb_design.js` | JSONB: **yes**. MongoDB: **run it yourself** (see note) |
| Key-value | Shopping cart, session, flash-sale stock, live best-sellers | Redis 7 (`03_redis_keyvalue.redis`, `run_redis_demo.sh`) | **yes** |
| Graph | "Customers who bought this also bought" | Neo4j/Cypher (`05_graph_recommendation_cypher.md`) | design only |

> **MongoDB / graph:** MongoDB could not be downloaded in the build environment, so `04_mongodb_design.js` has not been executed yet. To run it:
> ```bash
> docker run -d --name mongo -p 27017:27017 mongo:7
> docker exec -i mongo mongosh < 04_mongodb_design.js > results/04_mongodb_output.txt
> ```
> Screenshot the `explain("executionStats")` output and look for `IXSCAN` (index used) and `totalDocsExamined`. The Cypher file stays a design unless you also run Neo4j.

## 1. Document model - why it suits the catalogue
A phone has `ram_gb, storage_gb`; a laptop has `cpu, ram_gb`; a shirt has `size, colour`. In SQL this means either dozens of mostly-NULL columns or an Entity-Attribute-Value table that is slow and hard to query. A document keeps each product's own attributes together, with the latest reviews embedded so a product page is **one read**.
* 20,000 documents loaded into `product_catalog(product_id, doc JSONB)`; sample document in `results/01_document_model_output.txt`.
* Query: phones with exactly 8 GB RAM and 128 GB storage (`doc @> '{...}'`): **6.2 ms (Seq Scan, 20,000 rows examined) -> 0.63 ms with a GIN index** (Bitmap Index Scan, 277 matching rows). See `results/02_document_queries_output.txt`.
* **Suitability test** (`06_relational_vs_document.sh`): loading a full product page (product + category + seller + latest reviews). Relational: 3-table join plus a review sub-query, **0.27 ms**; document: one primary-key read, **0.05 ms**. Over 2,000 random product pages, with every value forced to be fully read: **106 ms relational vs 24 ms document (about 4.4x faster)**. This is the access pattern a catalogue serves millions of times a day, which is why the document model suits it.
* Trade-off: the document duplicates name/price (they must be kept in sync with `product`), and there is no foreign-key protection inside the JSON.

## 2. Key-value model - why Redis
Evidence: `results/03_redis_output.txt`.
* **Cart** = hash `cart:4242` (`HSET`/`HINCRBY`), expires with `EXPIRE` (TTL 604800 s). Carts are temporary and read constantly - no need for durable relational rows.
* **Session** = `SET session:abc123 ... EX 1800` (auto-expiry after 30 minutes).
* **Flash sale**: `DECR flash:stock:9001` is atomic and single-threaded in Redis, so 4 buyers for 3 units gave 2, 1, 0, **-1** - the -1 buyer is rejected and the counter restored with `INCR`. Millions of such operations per second are possible; the relational DB is updated asynchronously afterwards.
* **Best-sellers** = sorted set; `ZREVRANGE ... WITHSCORES` returned prod:205 (12), prod:101 (8), prod:330 (7) already ranked, `ZREVRANK` gives a product's rank in O(log n).
* Trade-off: Redis is in-memory first; use AOF/RDB persistence and treat it as a cache/short-lived store, with PostgreSQL as the system of record.

## 3. Graph model (design)
Recommendation queries are multi-hop traversals (customer -> bought -> product <- bought <- other customers). In SQL that is a self-join of `order_item` through `orders`; a graph database follows stored relationships directly. See `05_graph_recommendation_cypher.md`.

## Embedding vs referencing (document design decision)
| Data | Choice | Reason |
|---|---|---|
| Product attributes | Embed | Always read with the product, owned by it, small |
| Latest 3 reviews | Embed (copy) | Product page needs them in one read; full review history stays in its own collection/table |
| Order items | Embed in order | Read and written together; never change after purchase |
| Seller | Reference (`seller_id`) | Shared by thousands of products; embedding would duplicate updates |

## Consistency model per store
| Store | Consistency | Acceptable because |
|---|---|---|
| PostgreSQL (orders, payments, stock) | Strong, ACID | Money and stock cannot be wrong |
| JSONB / document catalogue | Copy of name/price kept in sync from `product` | A briefly stale price on a listing is corrected at checkout, which reads `product` |
| Redis carts and counters | In-memory, persistence optional | Losing a cart is an inconvenience, not a financial error |

## When NOT to use NoSQL here
Orders, payments and stock are relational and need ACID transactions and constraints (Portfolio 3), so they stay in PostgreSQL.

## Run
```bash
psql -d shopnaija -f 01_document_model_jsonb.sql -f 02_document_queries.sql
redis-server --daemonize yes && ./run_redis_demo.sh
```
