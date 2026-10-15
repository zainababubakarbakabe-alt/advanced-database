# Portfolio 1: Database Design & Modelling

## Case Study: NaijaCart
NaijaCart is a Nigerian multi-seller e-commerce marketplace modeled after platforms like Jumia and Konga. It connects independent merchants with buyers who check out via local payment options (cards, bank transfers, USSD, wallets) and have goods shipped via domestic couriers.

The schema supports 5 core user groups: customers, sellers, logistics dispatchers, finance reconcilers, and read-only business analysts. To make query plans and concurrency testing realistic, the database is seeded with 50,000 customers, 20,000 products, 200,000 orders, and 600,000 order items (`02_seed_data.sql`).

## ER Diagram
![NaijaCart ERD](diagrams/erd.png)

## Relational Schema & Keys
The design uses 11 tables normalized to BCNF:

```text
customer   (PK customer_id, full_name, email UNIQUE, phone, created_at)
address    (PK address_id, FK customer_id, street, city, state, is_default)
category   (PK category_id, name UNIQUE, FK parent_id -> category)
seller     (PK seller_id, business_name UNIQUE, rating)
product    (PK product_id, FK seller_id, FK category_id, name, price, stock_qty)
orders     (PK order_id, FK customer_id, FK address_id, status, order_date)
order_item (PK (order_id, product_id), FK order_id, FK product_id, quantity, unit_price)
payment    (PK payment_id, FK order_id UNIQUE, method, amount, status, paid_at)
delivery   (PK delivery_id, FK order_id UNIQUE, courier, status, updated_at)
review     (PK review_id, FK product_id, FK customer_id, rating, comment, UNIQUE(product_id, customer_id))
stock_log  (PK log_id, FK product_id, change_qty, reason, logged_at)
```

## Database Constraints & Business Rules
- **No overselling:** `CHECK (stock_qty >= 0)` on `product`. PostgreSQL rejects any concurrent transaction that would push inventory below zero.
- **Positive money and quantities:** `CHECK (price > 0)` and `CHECK (quantity > 0)`.
- **Order lifecycles:** `CHECK (status IN ('PENDING', 'PAID', 'SHIPPED', 'DELIVERED', 'CANCELLED'))`.
- **One payment & delivery per order:** `UNIQUE(order_id)` on both `payment` and `delivery`.
- **Review anti-spam:** `UNIQUE(product_id, customer_id)` prevents repeat reviews from the same buyer.
- **Audit protection:** Addresses and line items cascade on delete with their parent, but `orders` and `payment` do not, preserving financial audit trails.

## Normalisation (1NF to BCNF)
I transformed an unnormalised single-row order record into BCNF:
1. **1NF:** Extracted repeating item lists into `order_item(order_id, product_id, quantity, unit_price)` and separated addresses.
2. **2NF:** Removed partial dependencies on `(order_id, product_id)` by moving catalog data (`name`, `price`, `seller`) into `product`. Only `quantity` and purchased `unit_price` remain on the junction.
3. **3NF & BCNF:** Removed transitive dependencies: customer info moved to `customer`, seller info to `seller`, and categories into a recursive tree (`parent_id`). Every determinant is a candidate key, satisfying BCNF.

**Intentional denormalisation:**
- `order_item.unit_price`: Kept as an immutable snapshot of the price at checkout (catalog prices change over time).
- `payment.amount`: Kept for accounting reconciliation and audit integrity.

## Access Control & Security (`03_roles_security.sql`)
Roles enforce least privilege and NDPA 2023 data minimisation:
- **`naijacart_app`**: Read catalog, create orders and payments; cannot delete orders or payments.
- **`naijacart_analyst` (`analyst_ada`)**: Queries sales reports via `v_sales_anonymised`. Denied access to customer tables (names, emails, phones, and streets are hidden).
- **`naijacart_finance`**: Read-only access to orders and payments.

Run `./04_test_roles.sh` to verify that `analyst_ada` can query the reporting view but gets `permission denied` when attempting to access customer emails or delete an order.

## How to Run
```bash
psql -h localhost -U dbadmin -d shopnaija -f 01_schema.sql
psql -h localhost -U dbadmin -d shopnaija -f 02_seed_data.sql
psql -h localhost -U dbadmin -d shopnaija -f 03_roles_security.sql
./04_test_roles.sh
```
