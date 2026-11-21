CREATE TABLE stg_retail (
    invoice      TEXT,
    stockcode    TEXT,
    description  TEXT,
    quantity     INTEGER,
    invoicedate  TIMESTAMP,
    price        NUMERIC(10,2),
    customer_id  INTEGER,
    country      TEXT
);

--check file import
SELECT COUNT(*)                    AS total_rows,
       COUNT(DISTINCT customer_id) AS total_customers,
       MIN(invoicedate)            AS first_date,
       MAX(invoicedate)            AS last_date
FROM stg_retail;

--check missing customer ids
SELECT COUNT(*) AS missing_customer_ids
FROM stg_retail
WHERE customer_id IS NULL;

--check cancelation
SELECT COUNT(*) FROM stg_retail WHERE invoice LIKE 'C%';

--country more than one
SELECT customer_id, COUNT(DISTINCT country) AS country_count
FROM stg_retail
GROUP BY customer_id
HAVING COUNT(DISTINCT country) > 1;


SELECT country, COUNT(*) AS rows_count,
       MIN(invoicedate) AS first_date,
       MAX(invoicedate) AS last_date
FROM stg_retail
WHERE customer_id = 12431
GROUP BY country;


---Create customer table
CREATE TABLE customers AS
SELECT DISTINCT ON (customer_id)
       customer_id,
       country,
       CASE WHEN country = 'United Kingdom' THEN 'UK' ELSE 'Non-UK' END AS region_group
FROM stg_retail
ORDER BY customer_id, invoicedate DESC;

ALTER TABLE customers ADD PRIMARY KEY (customer_id);


--Create trancation table
CREATE TABlE Transactions AS 
SELECT ROW_NUMBER() OVER () AS line_id,
       invoice,
       stockcode,
       description,
       quantity,
       invoicedate,
       price,
       ROUND(quantity * price, 2) AS revenue,
       (LEFT(invoice,1) = 'C') AS is_cancelled,
       customer_id
FROM stg_retail;

ALTER TABLE transactions ADD PRIMARY KEY (line_id);
ALTER TABLE transactions ADD FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

---Check table
SELECT 'customers' AS tbl, COUNT(*) FROM customers
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions;


---Total sales 
SELECT COUNT(customer_id) from stg_retail as total_sales;



--Custumer bills and total revenue withot cancelled
SELECT c.customer_id,
       c.country,
       COUNT(DISTINCT t.invoice) AS total_orders,
       ROUND(SUM(t.revenue), 2)  AS total_revenue
FROM customers c
JOIN transactions t ON t.customer_id = c.customer_id
WHERE t.is_cancelled = FALSE
GROUP BY c.customer_id, c.country
ORDER BY total_revenue DESC
LIMIT 10;


--Business Query 1: One-time vs Repeat ग्राहक (Objective 1)
WITH cust_orders AS (
    SELECT customer_id,
           COUNT(DISTINCT invoice) AS order_count
    FROM transactions
    WHERE is_cancelled = FALSE
    GROUP BY customer_id
)
SELECT CASE WHEN order_count = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_customers
FROM cust_orders
GROUP BY 1;



SELECT country, COUNT(*) AS customers
FROM customers
GROUP BY country
ORDER BY customers DESC;


--IN EACH CUSTOUMER BY IN EACH MONTH
CREATE TABLE monthly_customers AS
SELECT DISTINCT customer_id,
       DATE_TRUNC('month', invoicedate)::date AS m
FROM transactions
WHERE is_cancelled = FALSE;


--Retention
SELECT a.m                    AS month,
       COUNT(a.customer_id)   AS customers,
       COUNT(b.customer_id)   AS came_back_next_month,
       ROUND(100.0 * COUNT(b.customer_id) / COUNT(a.customer_id), 1) AS retention_pct
FROM monthly_customers a
LEFT JOIN monthly_customers b
       ON b.customer_id = a.customer_id
      AND b.m = a.m + INTERVAL '1 month'
WHERE a.m < DATE '2011-12-01'
GROUP BY a.m
ORDER BY a.m;














