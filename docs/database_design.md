# Database Design

## 1. Overview

The project uses the Brazilian E-Commerce Public Dataset by Olist.

The PostgreSQL database is divided into two schemas:

- `raw` — source tables loaded from CSV files with minimal transformations;
- `analytics` — cleaned views and analytical data marts prepared for analysis.

This separation preserves the original source structure while keeping analytical transformations in a dedicated layer.

## 2. Raw layer

| Table | Description | Primary key |
|---|---|---|
| `raw.category_translation` | Translation of product category names from Portuguese to English | `product_category_name` |
| `raw.customers` | Customer identifiers and customer location | `customer_id` |
| `raw.orders` | Order status and timestamps for each order lifecycle stage | `order_id` |
| `raw.sellers` | Seller identifiers and seller location | `seller_id` |
| `raw.products` | Product category and physical characteristics | `product_id` |
| `raw.order_items` | Products and sellers associated with each order | `(order_id, order_item_id)` |
| `raw.payments` | Payment methods, installments, and payment amounts | `(order_id, payment_sequential)` |
| `raw.reviews` | Review scores and optional text comments | `(review_id, order_id)` |
| `raw.geolocation` | Geographic coordinates associated with ZIP code prefixes | `geolocation_id` |

## 3. Raw-layer relationships

The central entity is `raw.orders`.

Implemented foreign-key relationships:

- `raw.orders.customer_id` → `raw.customers.customer_id`;
- `raw.order_items.order_id` → `raw.orders.order_id`;
- `raw.order_items.product_id` → `raw.products.product_id`;
- `raw.order_items.seller_id` → `raw.sellers.seller_id`;
- `raw.payments.order_id` → `raw.orders.order_id`;
- `raw.reviews.order_id` → `raw.orders.order_id`.

The conceptual many-to-many relationship between orders and products is implemented through `raw.order_items`.

## 4. Raw-layer design decisions

### 4.1 Customer identifiers

- `customer_id` connects `customers` and `orders`;
- `customer_unique_id` identifies the same real customer across different orders.

Repeat purchase analysis, retention, cohort analysis, and RFM segmentation use `customer_unique_id`.

### 4.2 Composite primary keys

- `raw.order_items`: `(order_id, order_item_id)`;
- `raw.payments`: `(order_id, payment_sequential)`;
- `raw.reviews`: `(review_id, order_id)`.

### 4.3 Product category translation

`raw.products.product_category_name` is logically related to `raw.category_translation.product_category_name`.

A foreign-key constraint is not created because some categories do not have a matching English translation. The relationship is handled through a `LEFT JOIN`.

### 4.4 Geolocation

The source geolocation table contains multiple rows for the same ZIP code prefix. Therefore, `geolocation_zip_code_prefix` cannot be a primary key.

A technical key, `geolocation_id`, uniquely identifies each raw row.

### 4.5 Raw data preservation

The `raw` schema remains close to the original CSV files:

- original column names are preserved;
- duplicated geolocation rows are retained;
- missing values are not imputed;
- analytical transformations are moved to the `analytics` schema.

### 4.6 Data types and constraints

- fixed-length identifiers use `CHAR(32)`;
- monetary values use `NUMERIC`;
- dates and times use `TIMESTAMP`;
- review scores are restricted to values from 1 to 5;
- monetary values cannot be negative;
- nullable order timestamps are preserved for canceled or incomplete orders.

## 5. Analytics layer

| View | Grain | Purpose |
|---|---|---|
| `analytics.products` | one row per product | Clean product attributes, corrected column names, and English category names |
| `analytics.geolocation` | one row per ZIP code prefix | Deduplicated geographic lookup with representative coordinates |
| `analytics.orders_enriched` | one row per order | Order and customer data with geography and delivery features |
| `analytics.order_items_enriched` | one row per order item | Product, seller, category, geography, price, and freight information |
| `analytics.order_metrics` | one row per order | Aggregated order-level metrics for analysis and dashboards |

## 6. Analytics-layer transformations

### 6.1 Products

`analytics.products`:

- converts empty category values to `NULL`;
- joins English category names;
- assigns `unknown` when a translation is missing;
- corrects source spelling in analytical column names.

### 6.2 Geolocation

`analytics.geolocation` creates one row per ZIP code prefix.

For each prefix:

- median latitude and longitude are calculated;
- the most frequent city and state combination is selected.

### 6.3 Enriched orders

`analytics.orders_enriched` joins orders with customer and geographic data.

Derived fields include:

- order month;
- approval time in hours;
- processing time in days;
- delivery time in days;
- delayed-delivery indicator;
- difference between actual and estimated delivery dates.

### 6.4 Enriched order items

`analytics.order_items_enriched` combines order items with products, sellers, and seller geography.

It includes:

```text
item_total_value = price + freight_value
```

### 6.5 Order-level metrics

`analytics.order_metrics` is the main order-level data mart.

Order items, payments, and reviews are aggregated separately before joining to prevent row multiplication.

The view includes:

- item count;
- unique product count;
- seller count;
- product value;
- freight value;
- total item value;
- payment count and payment value;
- maximum installments;
- average review score;
- review count;
- review-title and review-message indicators.

## 7. Diagram files

The physical raw-layer ER diagram is stored in:

- `docs/olist_schema.dbml`;
- `docs/er_diagram.png`.

The analytics layer is documented separately because it consists of derived views.

## 8. Validation

Raw-layer validation:

```text
database/03_validate_raw_data.sql
```

Analytics-layer validation:

```text
database/05_validate_analytics_layer.sql
```

The validation scripts check:

- expected row counts;
- key uniqueness;
- referential integrity;
- missing and empty values;
- row-count preservation;
- duplicate prevention;
- derived metric consistency;
- geolocation coverage;
- categories without translations;
- order-level aggregation consistency.
