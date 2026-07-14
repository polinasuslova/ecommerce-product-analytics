SELECT 'category_translation' AS table_name, COUNT(*) AS row_count
FROM raw.category_translation
UNION ALL
SELECT 'customers', COUNT(*) FROM raw.customers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM raw.geolocation
UNION ALL
SELECT 'order_items', COUNT(*) FROM raw.order_items
UNION ALL
SELECT 'orders', COUNT(*) FROM raw.orders
UNION ALL
SELECT 'payments', COUNT(*) FROM raw.payments
UNION ALL
SELECT 'products', COUNT(*) FROM raw.products
UNION ALL
SELECT 'reviews', COUNT(*) FROM raw.reviews
UNION ALL
SELECT 'sellers', COUNT(*) FROM raw.sellers
ORDER BY table_name;


SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_category_name) AS unique_portuguese_names,
    COUNT(DISTINCT product_category_name_english) AS unique_english_names
FROM raw.category_translation;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM raw.customers;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_ids,
    COUNT(DISTINCT customer_id) AS unique_customer_ids
FROM raw.orders;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS unique_seller_ids
FROM raw.sellers;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS unique_product_ids
FROM raw.products;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (order_id, order_item_id)) AS unique_order_items
FROM raw.order_items;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (order_id, payment_sequential)) AS unique_payments
FROM raw.payments;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (review_id, order_id)) AS unique_reviews
FROM raw.reviews;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_id) AS unique_geolocation_ids,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS unique_zip_code_prefixes
FROM raw.geolocation;


SELECT COUNT(*) AS orders_without_customer
FROM raw.orders AS o
LEFT JOIN raw.customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT COUNT(*) AS items_without_order
FROM raw.order_items AS oi
LEFT JOIN raw.orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS items_without_product
FROM raw.order_items AS oi
LEFT JOIN raw.products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS items_without_seller
FROM raw.order_items AS oi
LEFT JOIN raw.sellers AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

SELECT COUNT(*) AS payments_without_order
FROM raw.payments AS p
LEFT JOIN raw.orders AS o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS reviews_without_order
FROM raw.reviews AS r
LEFT JOIN raw.orders AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


SELECT
    COUNT(*) FILTER (WHERE order_approved_at IS NULL)
        AS missing_order_approved_at,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL)
        AS missing_order_delivered_carrier_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)
        AS missing_order_delivered_customer_date
FROM raw.orders;

SELECT
    COUNT(*) FILTER (WHERE product_category_name IS NULL)
        AS missing_category,
    COUNT(*) FILTER (WHERE product_name_lenght IS NULL)
        AS missing_name_length,
    COUNT(*) FILTER (WHERE product_description_lenght IS NULL)
        AS missing_description_length,
    COUNT(*) FILTER (WHERE product_photos_qty IS NULL)
        AS missing_photos_qty,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL)
        AS missing_weight,
    COUNT(*) FILTER (WHERE product_length_cm IS NULL)
        AS missing_length,
    COUNT(*) FILTER (WHERE product_height_cm IS NULL)
        AS missing_height,
    COUNT(*) FILTER (WHERE product_width_cm IS NULL)
        AS missing_width
FROM raw.products;

SELECT
    COUNT(*) FILTER (WHERE review_comment_title IS NULL)
        AS missing_review_titles,
    COUNT(*) FILTER (WHERE review_comment_message IS NULL)
        AS missing_review_messages,
    COUNT(*) FILTER (WHERE review_creation_date IS NULL)
        AS missing_review_creation_dates,
    COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL)
        AS missing_review_answer_timestamps
FROM raw.reviews;


SELECT
    COUNT(*) FILTER (
        WHERE product_category_name IS NOT NULL
          AND TRIM(product_category_name) = ''
    ) AS empty_product_categories
FROM raw.products;

SELECT
    COUNT(*) FILTER (
        WHERE review_comment_title IS NOT NULL
          AND TRIM(review_comment_title) = ''
    ) AS empty_review_titles,
    COUNT(*) FILTER (
        WHERE review_comment_message IS NOT NULL
          AND TRIM(review_comment_message) = ''
    ) AS empty_review_messages
FROM raw.reviews;


SELECT
    order_status,
    COUNT(*) AS orders_count
FROM raw.orders
GROUP BY order_status
ORDER BY orders_count DESC;

SELECT
    review_score,
    COUNT(*) AS reviews_count
FROM raw.reviews
GROUP BY review_score
ORDER BY review_score;

SELECT
    payment_type,
    COUNT(*) AS payments_count
FROM raw.payments
GROUP BY payment_type
ORDER BY payments_count DESC;

SELECT
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    MIN(freight_value) AS min_freight_value,
    MAX(freight_value) AS max_freight_value
FROM raw.order_items;

SELECT
    MIN(payment_installments) AS min_installments,
    MAX(payment_installments) AS max_installments,
    MIN(payment_value) AS min_payment_value,
    MAX(payment_value) AS max_payment_value
FROM raw.payments;


SELECT DISTINCT
    p.product_category_name
FROM raw.products AS p
LEFT JOIN raw.category_translation AS ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL
ORDER BY p.product_category_name;


SELECT
    customer_unique_id,
    COUNT(*) AS customer_id_count
FROM raw.customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY customer_id_count DESC, customer_unique_id
LIMIT 10;


SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS unique_zip_code_prefixes
FROM raw.geolocation;

SELECT COALESCE(SUM(rows_count - 1), 0) AS duplicate_rows
FROM (
    SELECT
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state,
        COUNT(*) AS rows_count
    FROM raw.geolocation
    GROUP BY
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    HAVING COUNT(*) > 1
) AS duplicates;


SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'raw'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
