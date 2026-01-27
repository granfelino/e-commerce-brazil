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
	   o.order_ts AS order_date,
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

-- 6. Monthly revenue trend
CREATE VIEW mom_rev AS 
WITH monthly_rev AS (
	SELECT DATE_TRUNC('month', order_date) AS month,
	   SUM(price) AS revenue
	FROM main
	WHERE order_date >= MAKE_DATE(2017, 1, 1)
	GROUP BY 1
),
monthly_prev AS (
	SELECT *,
		   LAG(revenue) OVER(ORDER BY month) AS prev_rev
	FROM monthly_rev
)
SELECT month,
	   revenue,
	   CASE
	   		WHEN prev_rev IS NULL THEN NULL
			ELSE ROUND(((revenue / prev_rev) - 1) * 100, 2)
	   END  AS monthly_change
FROM monthly_prev;

-- 7. Yearly revenue trend
CREATE VIEW yoy_rev AS 
WITH yearly_rev AS (
	SELECT DATE_TRUNC('year', order_date) AS year,
	   SUM(price) AS revenue
	FROM main
	WHERE order_date >= MAKE_DATE(2017, 1, 1)
	GROUP BY 1
),
yearly_prev AS (
	SELECT *,
		   LAG(revenue) OVER(ORDER BY year) AS prev_rev
	FROM yearly_rev
)
SELECT year,
	   revenue,
	   CASE
	   		WHEN prev_rev IS NULL THEN NULL
			ELSE ROUND(((revenue / prev_rev) - 1) * 100, 2)
	   END  AS yearly_change
FROM yearly_prev;


-- 8. Top 3 categories per quarter
CREATE VIEW quarterly_cat_rev_view AS
WITH quarterly_cat_rev AS (
	SELECT DATE_TRUNC('quarter', order_date) AS quarter,
		   category,
		   SUM(price) AS total,
	   		ROW_NUMBER() OVER(
	   			PARTITION BY DATE_TRUNC('quarter', order_date)
	   			ORDER BY SUM(price) DESC
	   		) AS rnk
	FROM main
	WHERE order_date >= MAKE_DATE(2017, 1, 1)
	GROUP BY 1, 2
)
SELECT quarter,
	   category,
	   total,
	   rnk
FROM quarterly_cat_rev
WHERE rnk <= 3
ORDER BY 1, 3 DESC;


-- 9. Revenue vs volume over time
CREATE VIEW rev_quant_over_time_view AS
WITH weekly_rev_quant AS (
	SELECT DATE_TRUNC('week', order_date) AS week,
		   SUM(price) AS total_rev,
		   COUNT(*) AS total_quant
	FROM main
	WHERE order_date >= MAKE_DATE(2017, 1, 1)
	  AND order_date < MAKE_DATE(2018, 8, 27)
	GROUP BY 1
),
first_vals AS (
	SELECT week,
		   total_rev,
		   total_quant,
		   FIRST_VALUE(total_rev) OVER(ORDER BY total_rev) AS first_rev,
		   FIRST_VALUE(total_quant) OVER(ORDER BY total_quant) AS first_quant
	FROM weekly_rev_quant
)
SELECT week,
	   ROUND(total_rev / first_rev * 100, 2) AS revenue_index,
	   ROUND(total_quant::NUMERIC / first_quant * 100, 2) AS quant_index
FROM first_vals
ORDER BY week;
