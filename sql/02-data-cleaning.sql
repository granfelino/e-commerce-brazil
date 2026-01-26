------ CLEANING CUSTOMERS ------

-- how many rows total?
-- 99442
SELECT COUNT(*) FROM customers_stage;

-- NULLS? --
-- 0
SELECT COUNT(*)
FROM customers
WHERE customer_id IS NULL
	OR unique_id IS NULL
	OR zip_prefix IS NULL
	OR city IS NULL
	OR state IS NULL;

-- fake NULLs?
-- 0
SELECT COUNT(*)
FROM customers
WHERE LOWER(TRIM(customer_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(unique_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(zip_prefix)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(city)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(state)) IN ('', 'n/a', 'null');


------ STAGING CUSTOMERS ------
CREATE TABLE customers_stage AS 
SELECT * FROM customers;


-- flag header row
ALTER TABLE customers_stage
ADD COLUMN header_row BOOLEAN DEFAULT FALSE;

UPDATE customers_stage
SET header_row = true
WHERE customer_id = 'customer_id'
   AND unique_id = 'customer_unique_id'
   AND zip_prefix = 'customer_zip_code_prefix'
   AND city = 'customer_city'
   AND state = 'customer_state';

-- trim whitespace
UPDATE customers_stage
SET customer_id = TRIM(customer_id),
	unique_id = TRIM(unique_id),
	zip_prefix = TRIM(zip_prefix),
	city = TRIM(city),
	state = TRIM(state);

-- look for unnecessary symbols

-- IDs length not equal to average?
-- only header row
SELECT customer_id
FROM customers_stage
WHERE LENGTH(customer_id) <> (
	SELECT ROUND(AVG(LENGTH(customer_id)))
	FROM customers_stage
);

-- only header row
SELECT unique_id
FROM customers_stage
WHERE LENGTH(unique_id) <> (
	SELECT ROUND(AVG(LENGTH(unique_id)))
	FROM customers_stage
);

-- zip code containing non-digit values?
-- only header row
SELECT zip_prefix
FROM customers_stage
WHERE zip_prefix ~ '[^\d]+';

-- cities names containing other signs than
-- letters, whitespace, dashes, single quotes?
-- header row & city: "quilometro 14 do mutum" LOL, actual city
SELECT city
FROM customers_stage
WHERE city ~ '[^a-zA-Z\s\-'']+';

-- states not containing big letters?
-- only header row
SELECT state
FROM customers_stage
WHERE state ~ '[^A-Z]';

-- we trimmed once, so checking fake NULLs again:
-- 0
SELECT COUNT(*)
FROM customers
WHERE LOWER(TRIM(customer_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(unique_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(zip_prefix)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(city)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(state)) IN ('', 'n/a', 'null');

-- duplicate rows?
-- 0
SELECT customer_id, unique_id, zip_prefix, city, state
FROM customers_stage
GROUP BY customer_id, unique_id, zip_prefix, city, state
HAVING COUNT(*) > 1;

-- duplicate unique IDs?
-- 2997 
-- as far as I understand the description of the dataset
-- the unique IDs MIGHT be assigned in different stores
-- to different customers where their customer IDs change with
-- each purchase
SELECT DISTINCT unique_id
FROM customers_stage
GROUP BY unique_id
HAVING COUNT(unique_id) > 1;

-- duplicates excluding customer_id column?
-- 2770
SELECT unique_id, zip_prefix, city, state
FROM customers_stage
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
ORDER BY zip_prefix;

-- since I do not know how to exactly interpret these duplicate
-- values I will exclude them all from further analysis
-- it is a small fraction of the whole dataset (100k vs 3k rows)

-- are duplicates excludeing customer_id within the unique_id duplicates?
-- 2770 unique_ids (all of them) from the 2nd query are within the 1st one
-- ergo, it is enough to flag the unique_id duplicates to get rid of them all
WITH ex_cid AS (
	SELECT unique_id, zip_prefix, city, state
	FROM customers_stage
	GROUP BY 1, 2, 3, 4
	HAVING COUNT(*) > 1
	ORDER BY zip_prefix
)
SELECT COUNT(unique_id)
FROM ex_cid
WHERE unique_id IN (
	SELECT DISTINCT unique_id
	FROM customers_stage
	GROUP BY unique_id
	HAVING COUNT(unique_id) > 1
)

-- create a unique_id duplicates column
ALTER TABLE customers_stage
ADD COLUMN unique_id_duplicate BOOLEAN DEFAULT false;

-- set column values
WITH uid_duplicates AS (
	SELECT DISTINCT unique_id
	FROM customers_stage
	GROUP BY unique_id
	HAVING COUNT(unique_id) > 1
)
UPDATE customers_stage cs
SET unique_id_duplicate = true
FROM uid_duplicates ud
WHERE cs.unique_id = ud.unique_id
RETURNING *;


------ CLEAN CUSTOMERS ------
CREATE TABLE customers_clean AS
SELECT customer_id, unique_id, zip_prefix, city, state
FROM customers_stage
WHERE NOT header_row
  AND NOT unique_id_duplicate;

------ ANALYSIS CUSTOMERS ------
-- all apart from zip_prefix are text columns
CREATE TABLE customers_analysis AS 
SELECT customer_id,
	   unique_id,
	   zip_prefix::INTEGER,
	   city,
	   state
FROM customers_clean;

-- make customer_id primary key
ALTER TABLE customers_analysis
ADD CONSTRAINT customer_id_pk
PRIMARY KEY (customer_id)

-- make columns not null
ALTER TABLE customers_analysis
	ALTER COLUMN unique_id SET NOT NULL,
	ALTER COLUMN zip_prefix SET NOT NULL,
	ALTER COLUMN city SET NOT NULL,
	ALTER COLUMN state SET NOT NULL;

-- make unique_id unique
ALTER TABLE customers_analysis
ADD CONSTRAINT uid_unique
UNIQUE (unique_id);


------ CLEANING ORDERS ------
-- headers row needs to be flagged

-- no duplicates of order_ids
SELECT order_id
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- status looks fine
SELECT DISTINCT status
FROM orders
ORDER BY status;

-- NULLs?
-- 2980 rows
SELECT *
FROM orders
WHERE order_id IS NULL
   OR customer_id IS NULL
   OR status IS NULL
   OR order_ts IS NULL
   OR approve_ts IS NULL
   OR delivery_carrier_ts IS NULL
   OR delivery_customer_ts IS NULL
   OR delivery_estimated_ts IS NULL;   
   
-- NULLS only in these columns -> thi is OK
SELECT *
FROM orders
WHERE approve_ts IS NULL
   OR delivery_carrier_ts IS NULL
   OR delivery_customer_ts IS NULL;

-- no fake nulls
SELECT COUNT(*)
FROM orders
WHERE LOWER(TRIM(order_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(customer_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(status)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(order_ts)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(approve_ts)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(delivery_carrier_ts)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(delivery_customer_ts)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(delivery_estimated_ts)) IN ('', 'n/a', 'null');

-- ORDERS STAGING
CREATE TABLE orders_stage AS
SELECT * FROM orders;

-- delete the header row
DELETE FROM orders_stage
WHERE order_id = 'order_id'
  AND customer_id = 'customer_id'
  AND status = 'order_status'
  AND order_ts = 'order_purchase_timestamp';

-- ORDERS ANALYTICS
CREATE TABLE orders_analytics AS
SELECT order_id,
	   customer_id,
	   status,
	   order_ts::TIMESTAMP,
	   approve_ts::TIMESTAMP,
	   delivery_carrier_ts::TIMESTAMP,
	   delivery_customer_ts::TIMESTAMP,
	   delivery_estimated_ts::TIMESTAMP
FROM orders_stage;

-- add pk
ALTER TABLE orders_analytics
ADD CONSTRAINT order_id_pk
PRIMARY KEY (order_id);

-- set not null
ALTER TABLE orders_analytics
	ALTER COLUMN customer_id SET NOT NULL,
	ALTER COLUMN status SET NOT NULL;


------ CLEANING ORDER ITEMS ------
-- header row needs to be deleted
-- here each item is listed separately
-- so there are many order_id duplicates

-- ~10k unique orders
SELECT DISTINCT order_id
FROM order_items
GROUP BY 1
HAVING COUNT(*) > 1;

-- no NULLs
SELECT *
FROM order_items
WHERE order_id IS NULL
   OR item_id IS NULL
   OR product_id IS NULL
   OR seller_id IS NULL
   OR shipping_limit_ts IS NULL
   OR price IS NULL
   OR shipping IS NULL;

-- no fake NULLs
SELECT COUNT(*)
FROM order_items_stage
WHERE LOWER(TRIM(order_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(item_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(product_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(seller_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(shipping_limit_ts)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(price)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(shipping)) IN ('', 'n/a', 'null');

-- create staging
CREATE TABLE order_items_stage AS
SELECT * FROM order_items;

-- drop header
DELETE FROM order_items_stage
WHERE order_id = 'order_id'
  AND item_id = 'order_item_id'
  AND product_id = 'product_id';

-- no weird values
SELECT * 
FROM order_items_stage
WHERE item_id::INTEGER < 0
   OR price::NUMERIC < 0
   OR shipping::NUMERIC < 0;

-- create analytics
CREATE TABLE order_items_analytics AS
SELECT order_id,
	   item_id::INTEGER,
	   product_id,
	   seller_id,
	   shipping_limit_ts::TIMESTAMP,
	   price::NUMERIC,
	   shipping::NUMERIC
FROM order_items_stage;

-- add constraints
ALTER TABLE order_items_analytics
    ALTER COLUMN order_id SET NOT NULL,
    ALTER COLUMN item_id SET NOT NULL,
    ALTER COLUMN product_id SET NOT NULL,
    ALTER COLUMN seller_id SET NOT NULL,
    ALTER COLUMN shipping_limit_ts SET NOT NULL,
    ALTER COLUMN price SET NOT NULL,
    ALTER COLUMN shipping SET NOT NULL;

------ CLEANING PRODUCTS ------
-- drop header row

-- no duplicates
SELECT *
FROM products
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
HAVING COUNT(*) > 1;

-- no product_id duplicate
SELECT product_id
FROM products_staging
GROUP BY 1
HAVING COUNT(*) > 1;

-- 611 rows with
-- category, name_len, description_len and photos_quantity NULL
-- I'll exclude these, since the main interest of mine in this
-- table is the categor of the product
SELECT *
FROM products
WHERE product_id IS NULL
   OR category IS NULL
   OR name_len IS NULL
   OR description_len IS NULL
   OR photos_quantity IS NULL
   OR weight IS NULL
   OR length IS NULL
   OR height IS NULL
   OR width IS NULL;

-- no fake nulls
SELECT COUNT(*)
FROM products
WHERE LOWER(TRIM(product_id)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(category)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(name_len)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(description_len)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(photos_quantity)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(weight)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(length)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(height)) IN ('', 'n/a', 'null')
   OR LOWER(TRIM(width)) IN ('', 'n/a', 'null');

-- create products staging
CREATE TABLE products_staging AS
SELECT * FROM products;


-- delete the header row
DELETE FROM products_staging
WHERE product_id='product_id'
AND category = 'product_category_name';

-- add a flag column with category null
ALTER TABLE products_staging
ADD COLUMN category_null BOOLEAN DEFAULT false;

UPDATE products_staging
SET category_null = true
WHERE category IS NULL
RETURNING *;

-- add categories translations
BEGIN;
ALTER TABLE products_staging
ADD COLUMN category_en TEXT;

UPDATE products_staging
SET category_en = ct.cat_en
FROM cat_translation ct
WHERE category = ct.cat_pr
RETURNING *;

-- flag translation nulls
ALTER TABLE products_staging
ADD COLUMN category_en_null BOOLEAN DEFAULT false;

UPDATE products_staging
SET category_en_null = true
WHERE category_en IS NULL
AND NOT category_null
RETURNING *;

-- create products analysis
CREATE TABLE products_analysis AS
SELECT product_id,
	   category_en AS category,
	   name_len::INTEGER,
	   description_len::INTEGER,
	   photos_quantity::INTEGER,
	   weight::INTEGER,
	   length::INTEGER,
	   height::INTEGER,
	   width::INTEGER
FROM products_staging
WHERE NOT category_null
  AND NOT category_en_null;

-- add constraints
ALTER TABLE products_analysis
ADD CONSTRAINT product_id_pk
PRIMARY KEY (product_id);

ALTER TABLE products_analysis
ALTER COLUMN category SET NOT NULL;

-- cleaning complete

-- rename original tables to raw
-- i should've done it first
-- but since i don't have much time
-- i'll change the names now


ALTER TABLE orders
RENAME TO orders_raw;

ALTER TABLE customers
RENAME TO customers_raw;

ALTER TABLE order_items
RENAME TO order_items_raw;

ALTER TABLE products
RENAME TO products_raw;


-- create views 
CREATE VIEW customers AS 
SELECT * FROM customers_analysis;

CREATE VIEW orders AS
SELECT * FROM orders_analytics;

CREATE VIEW order_items AS
SELECT * FROM order_items_analytics;

CREATE VIEW products AS
SELECT * FROM products_analysis;
