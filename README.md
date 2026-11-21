# Customer Repeat Purchase & Retention Analysis

[Dashboard](screenshots/dashboard.png)

## 1. Project overview

An end-to-end retail analytics project that studies how customers repeat their purchases and how many come back month after month. Starting from a real-world transaction dataset, I built a customer-level sample, cleaned it in Excel, analysed it with SQL in PostgreSQL, and delivered a one-page Power BI dashboard with key insights.

**Result in one line:** about two-thirds of customers are repeat buyers, and they generate almost all revenue.

## 2. My thinking process

- **Customers, not rows.** A retention analysis breaks if a customer's history is cut in half. So I did not take the first 50,000 rows. I counted rows per customer, shuffled customers with a stored random key, and selected whole customers until the total reached about 50,000 rows.
- **Flag, don't delete.** Cancelled invoices are real events. I flagged them instead of deleting them, and excluded them only when counting purchases.
- **One clear definition.** Repeat customer = 2 or more distinct non-cancelled invoices. One-time = exactly 1. I kept the same definition in SQL and in DAX so the numbers match.
- **Count orders, not lines.** One invoice has many lines, so orders are counted with distinct invoice numbers, not row counts.
- **Be careful with the last month.** The data ends on 9 Dec 2011, so December is partial. I left it out of the retention average.
- **Keep it explainable.** I used 2 tables (customers, transactions) and simple queries I can walk through line by line.
- **Remove non-products.** Postage (`POST`) and Manual (`M`) are not products, so I removed them from the Power BI model.

## 3. Business problem

A retailer wants to know whether customers come back, how many stay, and where it can improve repeat purchases. Without this view, marketing effort cannot be aimed at the customers who matter most.

## 4. Business questions answered

1. Do customers come back? What share are repeat vs one-time buyers?
2. How much revenue comes from repeat customers?
3. How often does an average customer buy?
4. What share of customers return the next month (monthly retention)?
5. Which products do repeat customers buy most?
6. How do UK and non-UK customers compare? (via Region and Country slicers)

## 5. Key findings

| Metric | Result |
|---|---|
| Customers analysed (Power BI) | 527 |
| Repeat customers | 345 (65.5%) |
| One-time customers | 182 (34.5%) |
| Total revenue | £830.33K |
| Revenue from repeat customers | 92.5% |
| Orders per customer | 3.89 |
| Monthly retention, Dec 2010 to Oct 2011 | average 36.7%, range 29.5% to 46.6% |
| Top repeat-buyer products | Party Bunting, Jumbo Bag Red Retrospot, Regency Cakestand 3 Tier |

- Repeat customers are about two-thirds of customers but bring in 92.5% of revenue.
- The 182 one-time buyers are the main growth gap.
- Roughly 1 in 3 customers returns the next month.
- Monthly revenue peaks in Nov 2011. The data does not explain why, so I do not claim a cause.

**Limitations**
- The results come from a sample of 537 customers, not the full dataset.
- SQL analysis covers 529 customers with valid purchases. The Power BI model has 527 because Postage and Manual codes were removed there.
- The retention chart comes from a SQL table, so the Region and Country slicers do not filter it.
- December 2011 is a partial month, so the final retention point (Nov to Dec, 23.2%) is excluded from the average.
- Time between purchases and inactive-customer analysis are not included.

## 6. Data source

- **UCI Machine Learning Repository: Online Retail II**, sheet `Year 2010-2011` (1 Dec 2010 to 9 Dec 2011). Link: https://archive.ics.uci.edu/dataset/502/online+retail+ii
- 541,910 rows, 8 columns: Invoice, StockCode, Description, Quantity, InvoiceDate, Price, Customer ID, Country.
- The original file was kept unchanged. All work was done on a copy.
- Check the dataset's license and citation requirements on the UCI page.
- Working sample: 537 customers, 49,930 order lines (49,151 after removing duplicates).

## 7. Tools and tech stack

| Tool | Used for |
|---|---|
| Excel | Customer-level sampling, cleaning, validation, Pivot Tables |
| PostgreSQL / pgAdmin | Data model, SQL analysis, retention |
| Power BI | Data model, DAX measures, dashboard |
| Power Query | Removing non-product codes |

## 8. Core concepts demonstrated

- Customer-level sampling that preserves complete purchase histories
- Data cleaning and validation (duplicates, extra spaces, cancellations, blanks)
- Relational modeling with primary and foreign keys (1-to-many)
- SQL: JOIN, GROUP BY, CTE, window function, `DISTINCT ON`, self-join, `LEFT JOIN`
- Customer segmentation (one-time vs repeat) and monthly retention logic
- DAX: `CALCULATE`, `DISTINCTCOUNT`, `DIVIDE`, calculated columns
- Dashboard design and business storytelling

## 9. Project workflow

1. **Excel:** counted rows per customer (Pivot), assigned random keys, selected customers up to about 50,000 rows, extracted all their rows.
2. **Excel:** trimmed extra spaces (10,330 cells), removed 779 exact duplicates, flagged 1,091 cancelled invoices, validated fields with formulas.
3. **CSV:** exported the sample with dates as `yyyy-mm-dd hh:mm:ss`.
4. **PostgreSQL:** loaded a staging table, ran data checks, built `customers` and `transactions`.
5. **SQL analysis:** one-time vs repeat, revenue by customer, monthly customer table, retention.
6. **Power BI:** connected the tables, set the 1-to-many relationship, wrote DAX measures, built the dashboard.
7. **Insights:** added a key insights panel and documented limitations.

## 10. Sample SQL

**Keep each customer's most recent country** (one customer had two countries):
```sql
CREATE TABLE customers AS
SELECT DISTINCT ON (customer_id)
       customer_id,
       country,
       CASE WHEN country = 'United Kingdom' THEN 'UK' ELSE 'Non-UK' END AS region_group
FROM stg_retail
ORDER BY customer_id, invoicedate DESC;
```

**One-time vs repeat customers** (CTE + window function):
```sql
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
```

**Monthly retention** (self-join on a customer-month table):
```sql
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
```
`LEFT JOIN` keeps customers who did not return, so they are still counted in the denominator.

The full script is in `sql/retail_analysis.sql`.

## 11. Handling mixed data format

- **StockCode mixes numbers and letters** (`71053` and `85123A`). Loaded as `TEXT` so no code is lost or converted.
- **Invoice mixes numbers and a "C" prefix** (`C536379` = cancelled). Loaded as `TEXT`, then flagged with `LEFT(invoice,1) = 'C'`.
- **Ambiguous dates** (`12/1/2010` can be 1 Dec or 12 Jan). Formatted as `yyyy-mm-dd hh:mm:ss` before export, then loaded as `TIMESTAMP`.
- **Extra spaces in text cells.** Trimmed in Excel (10,330 cells).
- **Non-product codes in StockCode** (`POST`, `M`). Removed in Power Query for product analysis.
- **Customer with two countries.** Resolved with `DISTINCT ON`, keeping the most recent country.

## 12. Dashboard structure

One page, Teal and Amber theme:

- **Header:** title with Country and Region slicers.
- **KPI cards (5):** Total Revenue, Active Customers, Repeat Rate %, Orders per Customer, Repeat Revenue %.
- **Row 1:** donut (one-time vs repeat), area chart (monthly revenue), gauge (repeat rate).
- **Row 2:** scatter (orders vs revenue per customer), bar (top 10 products by repeat-customer revenue), line (monthly retention).
- **Key insights panel:** four short, data-backed insights.

## 13. How to reproduce this project

1. Download Online Retail II from UCI and keep the original file unchanged.
2. In Excel, build the customer-level sample: Pivot of rows per customer, random key (paste as values), running total up to about 50,000 rows, extract all rows for the selected customers.
3. Clean and validate the sample, then export `Retail_Clean_for_SQL.csv` with dates as `yyyy-mm-dd hh:mm:ss`.
4. In PostgreSQL, create the `retail_retention` database and the `stg_retail` table, and import the CSV.
5. Run `sql/retail_analysis.sql` to build `customers`, `transactions`, `monthly_customers` and the analysis queries.
6. Open `powerbi/UCI retail dashboard.pbix` in Power BI Desktop, update the PostgreSQL connection (server `localhost`, database `retail_retention`) and refresh.

**Repository structure**
```
├── README.md
├── data/          Retail_Clean_for_SQL.csv
├── excel/         cleaned workbook with Pivot Tables
├── sql/           retail_analysis.sql
├── powerbi/       UCI retail dashboard.pbix
└── screenshots/   dashboard.png
```

## Author

rutika 
