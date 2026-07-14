# Database Design

## 1. Overview

The project uses the Brazilian E-Commerce Public Dataset by Olist.  
The source data is stored in several CSV files describing customers, orders, products, sellers, payments, reviews, and geolocation.

The PostgreSQL database is divided into two schemas:

- `raw` — source tables loaded from CSV files with minimal transformations;
- `analytics` — cleaned tables, views, and analytical data marts that will be created later.

At the current stage, the `raw` schema contains nine source tables.

## 2. Raw-layer tables

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

## 3. Main relationships

The central entity of the database is `raw.orders`.

The following foreign-key relationships are implemented:

- `raw.orders.customer_id` → `raw.customers.customer_id`;
- `raw.order_items.order_id` → `raw.orders.order_id`;
- `raw.order_items.product_id` → `raw.products.product_id`;
- `raw.order_items.seller_id` → `raw.sellers.seller_id`;
- `raw.payments.order_id` → `raw.orders.order_id`;
- `raw.reviews.order_id` → `raw.orders.order_id`.

The relationship between orders and products is many-to-many at the conceptual level and is implemented through `raw.order_items`.

## 4. Design decisions

### 4.1 Customer identifiers

The source data contains two customer identifiers:

- `customer_id` is used to connect `customers` and `orders`;
- `customer_unique_id` identifies the same real customer across different orders.

In the Olist dataset, a customer may receive a new `customer_id` for each order. Therefore, repeat purchase analysis, cohort analysis, retention, and RFM segmentation will use `customer_unique_id`.

### 4.2 Composite primary keys

Several source tables do not have a single unique column.

For this reason, composite primary keys are used:

- `raw.order_items`: `(order_id, order_item_id)`;
- `raw.payments`: `(order_id, payment_sequential)`;
- `raw.reviews`: `(review_id, order_id)`.

These keys preserve the source structure and uniquely identify each row.

### 4.3 Product category translation

`raw.products.product_category_name` is logically related to  
`raw.category_translation.product_category_name`.

A foreign-key constraint is not created in the raw layer because some product categories have no matching English translation. The relationship will be used later through a `LEFT JOIN`, so products without a translation are not lost.

### 4.4 Geolocation

The source geolocation table contains multiple rows for the same ZIP code prefix. Therefore, `geolocation_zip_code_prefix` cannot be used as a primary key.

A technical key, `geolocation_id`, was added to uniquely identify each raw row.

No foreign-key relationships are currently created between geolocation and customers or sellers because the ZIP code prefix is not unique in `raw.geolocation`.

A cleaned geographic lookup table with one row per ZIP code prefix will be created later in the `analytics` schema.

### 4.5 Raw data preservation

The `raw` schema is intended to remain close to the original CSV files.

Consequently:

- original column names are preserved, including source spelling such as `product_name_lenght`;
- duplicated geolocation rows are retained;
- missing values are not imputed;
- transformations are kept minimal;
- business-oriented cleaning will be performed in the `analytics` schema.

### 4.6 Data types and constraints

The following choices were made:

- fixed-length 32-character identifiers use `CHAR(32)`;
- monetary values use `NUMERIC`, not floating-point types;
- timestamps use `TIMESTAMP`;
- review scores are restricted to values from 1 to 5;
- prices, freight values, and payment values cannot be negative;
- nullable date fields in `orders` are preserved because canceled or incomplete orders may not contain every lifecycle timestamp.

## 5. ER diagram

The ER diagram for the raw layer is stored in:

- `docs/olist_schema.dbml`;
- `docs/er_diagram.png`.

The DBML file contains the editable schema definition, while the PNG file is used for project documentation and the main README.

## 6. Validation

The file `database/03_validate_raw_data.sql` contains checks for:

- expected row counts;
- primary-key uniqueness;
- foreign-key integrity;
- missing values;
- empty strings;
- valid score and payment ranges;
- categories without English translations;
- repeated customer identifiers;
- duplicated geolocation rows.

The raw layer is considered ready when all expected row counts match the source files and all referential integrity checks return zero missing references.
