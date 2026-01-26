-- make a table which will serve as an entry point
-- i collected the most important information
-- from all tables and compiled it into one table
-- here: one row = one item from one order of one customer

CREATE TABLE main AS
SELECT o.order_id,
	   c.unique_id AS customer_id,
	   o.status,
	   oi.item_id,
	   oi.product_id,
	   p.category,
	   oi.price,
	   oi.shipping,
	   c.state
FROM orders o
JOIN order_items oi USING (order_id)
JOIN products p USING (product_id)
JOIN customers c USING (customer_id);

-- here are some questions which give a lot of insight into the data compiled

-- 1. Which product categories drive revenue and which volume?
--    In other words: what categories generate money and which sell in big quantities?

-- which categories generate the most money?
CREATE VIEW cat_by_rev_view AS
WITH cat_by_rev AS (
	SELECT category,
		   SUM(price) AS total_revenue,
		   ROW_NUMBER() OVER (
				ORDER BY SUM(price) DESC
		   ) AS rnk
	FROM main
	GROUP BY category
)
SELECT CASE
			WHEN rnk <= 12 THEN category ELSE 'other'
	   END AS grouped_category,
	   SUM(total_revenue) AS revenue
FROM cat_by_rev
GROUP BY grouped_category
ORDER BY revenue DESC;

-- which categories sell the most amount of products?
CREATE VIEW cat_by_quantity_view AS
WITH cat_by_quantity AS (
	SELECT category,
		   COUNT(product_id) AS total_quantity,
		   ROW_NUMBER() OVER (
		   		ORDER BY COUNT(product_id) DESC
	       ) AS rnk
	FROM main
	GROUP BY category
)
SELECT CASE
			WHEN rnk <= 12 THEN category ELSE 'other'
	   END AS grouped_category,
	   SUM(total_quantity) AS quantity
FROM cat_by_quantity
GROUP BY grouped_category
ORDER BY quantity DESC;


-- 2. How does revenue look like when looking by order status?
--    How much lost revenue does from cancelling orders arise?
CREATE VIEW lost_rev_by_status_view AS 
SELECT CASE
			WHEN status IN ('delivered', 'shipped', 'invoiced', 'approved') THEN 'completed'
			WHEN status = 'processing' THEN status
			ELSE 'failed'
	   END AS grouped_status,
	   SUM(price) AS total
FROM main
GROUP BY grouped_status
ORDER BY total DESC;


-- 3. What percentage of items has a price lower than that of its shipping?
--    When does customer need to pay more for the shipping than the product itself?
CREATE VIEW shipping_dominated_items_view AS
SELECT COUNT(*) AS total_items_sold,
	   SUM(CASE WHEN price < shipping THEN 1 ELSE 0 END) AS shipping_dominated_items,
	   SUM(CASE WHEN price < shipping THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) AS share
FROM main;

-- 4. What is an average item price in every state?
--    Are there states buying more expensive/cheaper items than others?
CREATE VIEW avg_price_by_state_view AS
WITH state_avg AS (
	SELECT state,
		   ROW_NUMBER() OVER(ORDER BY AVG(price) DESC) AS rnk
	FROM main
	GROUP BY state
)
SELECT CASE
			WHEN rnk <= 12 THEN state ELSE 'other'
	   END AS grouped_state,
	   AVG(price) AS avg_price
FROM main
JOIN state_avg USING (state)
GROUP BY grouped_state
ORDER BY avg_price DESC;


-- 5. What is the proportion of customers buying cheap or expensive items?
CREATE VIEW customer_avg_item_price_buckets_view AS
WITH customer_avg_item AS (
	SELECT customer_id,
		   AVG(price) AS avg_price
	FROM main
	GROUP BY customer_id
),
percentiles AS (
	SELECT PERCENTILE_CONT(0.2) WITHIN GROUP (ORDER BY avg_price) AS p20,
		   PERCENTILE_CONT(0.4) WITHIN GROUP (ORDER BY avg_price) AS p40,
		   PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY avg_price) AS p60,
		   PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY avg_price) AS p80
	FROM customer_avg_item
)
SELECT CASE
			WHEN avg_price <= p20 THEN '0-20'
			WHEN avg_price BETWEEN p20 AND p40 THEN '20-40'
			WHEN avg_price BETWEEN p40 AND p60 THEN '40-60'
			WHEN avg_price BETWEEN p60 AND p80 THEN '60-80'
			WHEN avg_price > 80 THEN '80-100'
	   END AS buckets,
	   COUNT(*) AS customer_count
FROM customer_avg_item
CROSS JOIN percentiles
GROUP BY buckets
ORDER BY buckets;
