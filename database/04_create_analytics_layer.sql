CREATE OR REPLACE VIEW analytics.products AS
SELECT
    p.product_id,
    NULLIF(TRIM(p.product_category_name), '')
        AS product_category_name,
    COALESCE(
        ct.product_category_name_english,
        'unknown'
    ) AS product_category_name_english,
    p.product_name_lenght
        AS product_name_length,
    p.product_description_lenght
        AS product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM raw.products AS p
LEFT JOIN raw.category_translation AS ct
    ON p.product_category_name = ct.product_category_name;


CREATE OR REPLACE VIEW analytics.geolocation AS
WITH city_counts AS (
    SELECT
        geolocation_zip_code_prefix,
        geolocation_city,
        geolocation_state,
        COUNT(*) AS location_count,
        ROW_NUMBER() OVER (
            PARTITION BY geolocation_zip_code_prefix
            ORDER BY COUNT(*) DESC,
                     geolocation_city,
                     geolocation_state
        ) AS row_number
    FROM raw.geolocation
    GROUP BY
        geolocation_zip_code_prefix,
        geolocation_city,
        geolocation_state
),
coordinates AS (
    SELECT
        geolocation_zip_code_prefix,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY geolocation_lat
        ) AS latitude,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY geolocation_lng
        ) AS longitude
    FROM raw.geolocation
    GROUP BY geolocation_zip_code_prefix
)
SELECT
    c.geolocation_zip_code_prefix AS zip_code_prefix,
    c.latitude,
    c.longitude,
    cc.geolocation_city AS city,
    cc.geolocation_state AS state
FROM coordinates AS c
JOIN city_counts AS cc
    ON c.geolocation_zip_code_prefix =
       cc.geolocation_zip_code_prefix
   AND cc.row_number = 1;


CREATE OR REPLACE VIEW analytics.orders_enriched AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS order_month,

    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,

    g.latitude AS customer_latitude,
    g.longitude AS customer_longitude,

    EXTRACT(
        EPOCH FROM (o.order_approved_at - o.order_purchase_timestamp)) 
    / 3600.0 AS approval_time_hours,

    EXTRACT(
        EPOCH FROM (o.order_delivered_carrier_date - o.order_approved_at))
    / 86400.0 AS processing_time_days,

    EXTRACT(
        EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) 
    / 86400.0 AS delivery_time_days,

    (o.order_delivered_customer_date > o.order_estimated_delivery_date
    ) AS is_delayed,

    EXTRACT(
        EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)
    ) / 86400.0 AS delivery_delay_days

FROM raw.orders AS o
JOIN raw.customers AS c
    ON o.customer_id = c.customer_id
LEFT JOIN analytics.geolocation AS g
    ON c.customer_zip_code_prefix = g.zip_code_prefix;


CREATE OR REPLACE VIEW analytics.order_items_enriched AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS item_total_value,

    p.product_category_name,
    p.product_category_name_english,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,

    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,

    g.latitude AS seller_latitude,
    g.longitude AS seller_longitude

FROM raw.order_items AS oi
JOIN analytics.products AS p
    ON oi.product_id = p.product_id
JOIN raw.sellers AS s
    ON oi.seller_id = s.seller_id
LEFT JOIN analytics.geolocation AS g
    ON s.seller_zip_code_prefix = g.zip_code_prefix;


CREATE OR REPLACE VIEW analytics.order_metrics AS
WITH item_metrics AS (
    SELECT
        order_id,
        COUNT(*) AS items_count,
        COUNT(DISTINCT product_id) AS unique_products_count,
        COUNT(DISTINCT seller_id) AS sellers_count,
        SUM(price) AS products_value,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS order_items_value
    FROM raw.order_items
    GROUP BY order_id
),
payment_metrics AS (
    SELECT
        order_id,
        COUNT(*) AS payments_count,
        SUM(payment_value) AS payment_value,
        MAX(payment_installments) AS max_payment_installments
    FROM raw.payments
    GROUP BY order_id
),
review_metrics AS (
    SELECT
        order_id,
        AVG(review_score)::NUMERIC(4, 2) AS average_review_score,
        COUNT(*) AS reviews_count,
        BOOL_OR(review_comment_title IS NOT NULL)
            AS has_review_title,
        BOOL_OR(review_comment_message IS NOT NULL)
            AS has_review_message
    FROM raw.reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.customer_unique_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_month,
    o.customer_city,
    o.customer_state,
    o.delivery_time_days,
    o.is_delayed,
    o.delivery_delay_days,

    COALESCE(i.items_count, 0) AS items_count,
    COALESCE(i.unique_products_count, 0)
        AS unique_products_count,
    COALESCE(i.sellers_count, 0) AS sellers_count,
    i.products_value,
    i.freight_value,
    i.order_items_value,

    COALESCE(p.payments_count, 0) AS payments_count,
    p.payment_value,
    p.max_payment_installments,

    r.average_review_score,
    COALESCE(r.reviews_count, 0) AS reviews_count,
    COALESCE(r.has_review_title, FALSE)
        AS has_review_title,
    COALESCE(r.has_review_message, FALSE)
        AS has_review_message

FROM analytics.orders_enriched AS o
LEFT JOIN item_metrics AS i
    ON o.order_id = i.order_id
LEFT JOIN payment_metrics AS p
    ON o.order_id = p.order_id
LEFT JOIN review_metrics AS r
    ON o.order_id = r.order_id;