-- create orders table
CREATE TABLE orders (
	order_id TEXT,
	customer_id TEXT,
	status TEXT,
	order_ts TEXT,
	approve_ts TEXT,
	delivery_carrier_ts TEXT,
	delivery_customer_ts TEXT,
	delivery_estimated_ts TEXT
);

-- create order items table
CREATE TABLE order_items (
	order_id TEXT, 
	item_id TEXT,
	product_id TEXT,
	seller_id TEXT,
	shipping_limit_ts TEXT,
	price TEXT,
	shipping TEXT
);


-- create customers table
CREATE TABLE customers (
	customer_id TEXT,
	unique_id TEXT,
	zip_prefix TEXT,
	city TEXT,
	state TEXT
);


-- create products table
CREATE TABLE products (
	product_id TEXT,
	category TEXT,
	name_len TEXT,
	description_len TEXT,
	photos_quantity TEXT,
	weight TEXT,
	length TEXT,
	height TEXT,
	width TEXT
);

-- create category translation table
CREATE TABLE cat_translation (
	cat_pr TEXT,
	cat_en TEXT
);
