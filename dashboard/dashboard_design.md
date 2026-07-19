# Dashboard Design

## Overview

The project includes an interactive dashboard created in Yandex DataLens.

The dashboard summarizes the main business, customer, delivery, review, product, and geographic findings from the Olist e-commerce dataset.

The dashboard is built from aggregated CSV data marts generated from PostgreSQL by:

```text
dashboard/export_dashboard_data.py
```

The exported CSV files are stored locally in:

```text
dashboard/data/
```

They are excluded from Git because they can be reproduced from the database.

## Dashboard Structure

The dashboard contains four pages:

1. Executive Overview
2. Customer Analytics
3. Delivery and Reviews
4. Products and Geography

Screenshots of the completed pages are stored in:

```text
dashboard/screenshots/
```

## 1. Executive Overview

The Executive Overview page presents the main marketplace performance indicators.

### KPI Cards

- Total GMV
- Delivered Orders
- Unique Customers
- Average Order Value
- Average Review Score
- Delayed Order Rate

### Charts

- Monthly GMV
- Monthly Delivered Orders

### Purpose

This page provides a high-level summary of marketplace scale, customer activity, revenue, customer satisfaction, and delivery quality.

### Data Sources

- `executive_metrics.csv`
- `monthly_metrics.csv`

### Aggregation Logic

The executive dataset contains one summary row.

For already calculated totals, the dashboard uses `MAX`:

- GMV
- delivered orders
- unique customers

For already calculated averages and rates, the dashboard uses `AVG`:

- average order value
- average review score
- delayed order rate
- average delivery time

The monthly dataset contains one row per month.

The dashboard uses:

- `SUM` for monthly GMV and delivered orders;
- `AVG` for monthly averages and rates.

## 2. Customer Analytics

The Customer Analytics page focuses on acquisition, repeat purchasing, retention, and RFM segmentation.

### Charts

- New and Repeat Customers by Month
- Monthly Repeat Customer Share
- Orders per Active Customer
- Customers by RFM Segment
- Monetary Value by RFM Segment
- Customer Retention by Cohort Index

### Purpose

This page helps evaluate whether marketplace growth is driven by newly acquired customers or by repeat purchases.

It also identifies customer segments that contribute the most monetary value.

### Data Sources

- `customer_metrics.csv`
- `cohort_retention.csv`
- `rfm_segments.csv`

### Aggregation Logic

For monthly customer metrics:

- customer counts and delivered orders use `SUM`;
- repeat customer share uses `AVG`;
- orders per active customer uses `AVG`.

For RFM segment metrics:

- customer counts and monetary value use `SUM`;
- average recency, frequency, and monetary value use `AVG`.

The cohort retention data is stored in long format:

```text
cohort_month
cohort_index
active_customers
cohort_size
retention_rate_percent
```

## 3. Delivery and Reviews

The Delivery and Reviews page compares delayed and on-time orders.

The Boolean field is interpreted as:

```text
is_delayed = False → On Time
is_delayed = True  → Delayed
```

### Charts

- Monthly Low Review Rate by Delay Status
- Delivered Orders by Delay Status
- Monthly Delivery Time by Delay Status
- Monthly Review Score by Delay Status

### Purpose

This page evaluates the relationship between delivery performance and customer satisfaction.

It demonstrates that delayed orders have longer delivery times, lower review scores, and substantially higher low-review rates.

### Data Source

- `delivery_metrics.csv`

### Data Granularity

Each row represents:

```text
one month × one delivery status
```

### Aggregation Logic

The dashboard uses:

- `SUM(delivered_orders)` for order counts;
- `AVG(average_delivery_time_days)` for monthly delivery-time values;
- `AVG(average_review_score)` for monthly review-score values;
- `AVG(low_review_rate_percent)` for monthly low-review-rate values.

The displayed period starts in January 2017 to avoid unstable values caused by the very small number of orders in the earliest months.

## 4. Products and Geography

The Products and Geography page analyzes product categories and customer states.

### Charts

- Top 10 Product Categories by Sales Value
- Top 10 Product Categories by Delivered Orders
- Top Categories by Average Review Score
- GMV by Customer State
- Delayed Order Rate by Customer State
- Average Delivery Time by Customer State

### Purpose

This page identifies:

- the categories generating the highest sales value;
- the categories with the largest order volume;
- highly rated product categories;
- the geographic concentration of GMV;
- states with higher delayed-order rates;
- states with longer average delivery times.

### Data Sources

- `category_metrics.csv`
- `state_metrics.csv`

### Aggregation Logic

For category metrics:

- sales value, freight value, items sold, and delivered orders use `SUM`;
- average item price, average freight value, and average review score use `AVG`.

For state metrics:

- GMV, delivered orders, and unique customers use `SUM`;
- average order value, average delivery time, delayed order rate, and average review score use `AVG`.

To improve readability, the dashboard mainly displays the top 10 categories or states.

For review-score, delay-rate, and delivery-time comparisons, low-volume categories or states are filtered out where appropriate to reduce the influence of small samples.

## Data Export Process

Dashboard data is generated by running:

```bash
python dashboard/export_dashboard_data.py
```

The script:

1. connects to PostgreSQL;
2. queries the analytics schema;
3. exports aggregated dashboard data marts;
4. saves the resulting CSV files in `dashboard/data/`.

Generated data marts:

```text
executive_metrics.csv
monthly_metrics.csv
customer_metrics.csv
delivery_metrics.csv
category_metrics.csv
state_metrics.csv
cohort_retention.csv
rfm_segments.csv
```

## Limitations

- The dashboard is based on historical Olist data and does not represent current marketplace performance.
- The dashboard uses aggregated CSV data marts rather than a live PostgreSQL connection.
- Some calculated averages and rates are already aggregated before loading into DataLens.
- Early months with low order volume may contain unstable metrics.
- Product category names preserve the source dataset format and may contain underscores.
- The dashboard describes associations in observational data and does not establish causal effects.

## Dashboard Screenshots

The final dashboard screenshots are stored in:

```text
dashboard/screenshots/
├── Executive Overview — Executive_Overview.png
├── Customer Analytics — Customer_Analytics.png
├── Delivery and Reviews — Delivery_and_Reviews.png
└── Products and Geography — Products_and_Geography.png
```
