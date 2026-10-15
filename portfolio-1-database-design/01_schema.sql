-- NaijaCart: simulated Nigerian e-commerce platform (PostgreSQL 16)
-- Portfolio 1: schema in Third Normal Form (3NF)
DROP SCHEMA IF EXISTS shop CASCADE;
CREATE SCHEMA shop;
SET search_path = shop;

CREATE TABLE customer (
  customer_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name     VARCHAR(120) NOT NULL,
  email         VARCHAR(160) NOT NULL UNIQUE,
  phone         VARCHAR(20)  NOT NULL,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT ck_customer_email CHECK (email LIKE '%_@_%._%')
);

CREATE TABLE address (
  address_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id   BIGINT NOT NULL REFERENCES customer(customer_id) ON DELETE CASCADE,
  street        VARCHAR(200) NOT NULL,
  city          VARCHAR(80)  NOT NULL,
  state         VARCHAR(40)  NOT NULL,
  is_default    BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE category (
  category_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name          VARCHAR(80) NOT NULL UNIQUE,
  parent_id     INT REFERENCES category(category_id)   -- self-reference: category tree
);

CREATE TABLE seller (
  seller_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_name VARCHAR(120) NOT NULL UNIQUE,
  rating        NUMERIC(2,1) CHECK (rating BETWEEN 0 AND 5)
);

CREATE TABLE product (
  product_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  seller_id     INT NOT NULL REFERENCES seller(seller_id),
  category_id   INT NOT NULL REFERENCES category(category_id),
  name          VARCHAR(160) NOT NULL,
  price         NUMERIC(12,2) NOT NULL CHECK (price > 0),
  stock_qty     INT NOT NULL CHECK (stock_qty >= 0),   -- prevents overselling at DB level
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
  order_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id   BIGINT NOT NULL REFERENCES customer(customer_id),
  address_id    BIGINT NOT NULL REFERENCES address(address_id),
  status        VARCHAR(12) NOT NULL DEFAULT 'PENDING'
                CHECK (status IN ('PENDING','PAID','SHIPPED','DELIVERED','CANCELLED')),
  order_date    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE order_item (
  order_id      BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  product_id    BIGINT NOT NULL REFERENCES product(product_id),
  quantity      INT NOT NULL CHECK (quantity > 0),
  unit_price    NUMERIC(12,2) NOT NULL CHECK (unit_price > 0),  -- price snapshot at purchase time
  PRIMARY KEY (order_id, product_id)                            -- composite key
);

CREATE TABLE payment (
  payment_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id      BIGINT NOT NULL UNIQUE REFERENCES orders(order_id),  -- 1:1 with order
  method        VARCHAR(12) NOT NULL CHECK (method IN ('CARD','TRANSFER','USSD','WALLET')),
  amount        NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  status        VARCHAR(10) NOT NULL CHECK (status IN ('SUCCESS','FAILED','REFUNDED')),
  paid_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE delivery (
  delivery_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id      BIGINT NOT NULL UNIQUE REFERENCES orders(order_id),
  courier       VARCHAR(60) NOT NULL,
  status        VARCHAR(12) NOT NULL CHECK (status IN ('PROCESSING','IN_TRANSIT','DELIVERED','RETURNED')),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE review (
  review_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id    BIGINT NOT NULL REFERENCES product(product_id),
  customer_id   BIGINT NOT NULL REFERENCES customer(customer_id),
  rating        SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment       TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (product_id, customer_id)       -- one review per customer per product
);

-- Audit table used in Portfolio 3 (stock movements)
CREATE TABLE stock_log (
  log_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id    BIGINT NOT NULL REFERENCES product(product_id),
  change_qty    INT NOT NULL,
  reason        VARCHAR(40) NOT NULL,
  logged_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
