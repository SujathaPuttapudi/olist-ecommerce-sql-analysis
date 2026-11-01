# Olist E-Commerce Data Analysis Using SQL

## Business Question

**Which customers, products, or areas drive the most value, and what does the data quality problem cost us?**

## Project Overview

This project analyzes the Olist Brazilian E-Commerce dataset using PostgreSQL to understand sales performance, product and customer behaviour, geographic trends, delivery performance, payment patterns, and customer satisfaction.

The project also focuses on data quality: identifying missing values, duplicate records, inconsistent information, and relationship issues before using the data for business analysis.

## Business Objectives

- Understand overall sales performance and category contribution.
- Identify high-performing products and customer purchasing patterns.
- Analyze customer and seller geographic performance.
- Evaluate delivery performance and its association with customer reviews.
- Understand payment method usage.
- Identify data-quality issues and their impact on business reporting.

## Tools and Technologies

- **PostgreSQL 18** – Database management and SQL analysis
- **pgAdmin 4** – Database administration and query execution
- **SQL** – Data profiling, cleaning, joins, aggregations, CTEs, subqueries, and window functions
- **Excel/CSV** – Source dataset

## Dataset

The project uses the Olist Brazilian E-Commerce public dataset.

It contains nine CSV files covering:

- Orders
- Order items
- Payments
- Customers
- Products
- Sellers
- Reviews
- Geolocation
- Product category translations

The raw tables contain approximately 1 million geolocation records and transaction-level information from the Olist marketplace.

## Data Preparation and Cleaning

A separate `clean` schema was created to preserve the original `raw` data.

Key cleaning activities included:

- Trimming unnecessary spaces and standardizing text.
- Converting date and numeric fields into appropriate data types.
- Identifying missing values and invalid records.
- Removing 261,831 exact duplicate geolocation records.
- Preserving legitimate missing values instead of replacing them with assumptions.
- Flagging two payment records with installment issues.
- Validating primary keys and foreign-key relationships.

The final clean schema contains nine tables.

## Business Analysis and Key Findings

### 1. Overall Sales Performance

- Total merchandise sales: **R$13.59 million**
- Average merchandise order value: **R$137.75**
- Orders with item records: **98,666**
- Orders without item records: **775**

### 2. Category Performance

- Health & Beauty generated approximately **R$1.26 million**, leading category sales.
- Watches & Gifts generated approximately **R$1.21 million**.
- The top five categories contributed approximately **39.74%** of total merchandise sales.
- Products without category information generated **R$179,535.28** in merchandise sales.

### 3. Product Performance

- Identified the highest-selling products based on merchandise sales.
- Compared product sales, item quantities, number of orders, and average item prices.
- Distinguished high-value products from high-volume products.

### 4. Customer Behaviour

- Total unique customers: **96,096**
- Repeat customers: **2,913**
- Repeat customer percentage: **3.03%** of all unique customers.
- Merchandise sales from repeat customers: **R$763,291.86**

### 5. Geographic Performance

- São Paulo was the leading customer market, generating approximately **R$5.20 million** in merchandise sales.
- São Paulo was also the leading seller state, with approximately **R$8.75 million** in seller-side merchandise sales.
- Customer and seller geographic performance were analyzed separately.

### 6. Delivery and Customer Satisfaction

- Delivered orders: **96,478**
- Late deliveries: **7,826**
- Late delivery rate: **8.11%**
- Average purchase-to-delivery time: **12.56 days**
- Average review score for late deliveries: **2.57/5**
- Average review score for on-time or early deliveries: **4.29/5**

The results show a strong association between delivery timing and customer review scores.

### 7. Payment Analysis

- Credit cards were the leading payment method.
- Credit-card payment value: **R$12.54 million**
- Boleto payment value: **R$2.87 million**
- Payment records and distinct orders were analyzed separately.

### 8. Data Quality Findings

- 610 products had missing category information.
- 13 products had categories without English translations.
- 775 orders had no matching item records.
- One order had no matching payment record.
- Eight delivered orders had no actual delivery date.
- Two payment records had installment issues.

## Business Recommendations

1. Investigate late deliveries and improve delivery reliability.
2. Study customer retention opportunities to encourage repeat purchases.
3. Monitor leading product categories and high-performing products.
4. Investigate regional seller and customer performance.
5. Improve product-category completeness.
6. Review payment exceptions and incomplete order records.

## SQL Concepts Demonstrated

- SELECT, WHERE, GROUP BY, ORDER BY
- Aggregate functions: COUNT, SUM, AVG
- CASE statements and conditional aggregation
- INNER JOIN and LEFT JOIN
- Subqueries and CTEs
- Window functions: SUM OVER and DENSE_RANK
- Primary keys and foreign keys
- Data cleaning and validation
- Data-quality analysis

## Project Structure

- `01_profile.sql` – Initial data profiling and quality checks
- `02_clean.sql` – Data cleaning and clean table creation
- `03_analysis.sql` – Business analysis and key findings
- `documentation/` – Project insights and detailed reference documents
- `screenshots/` – Selected query outputs and analysis evidence

## Conclusion

This project demonstrates how SQL and PostgreSQL can be used to transform raw e-commerce data into structured, analysis-ready tables and meaningful business insights.

The analysis identifies important sales patterns, customer behaviour, geographic performance, delivery issues, and data-quality limitations. It also demonstrates the importance of validating data before using it to support business decisions.

**Note:** Sales figures in this project represent merchandise sales based on item prices. They should not be interpreted as company revenue after deductions or as profit because complete cost information is not available in the dataset.