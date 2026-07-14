SELECT 'geolocation' AS view_name, COUNT(*) AS row_count
FROM analytics.geolocation
UNION ALL
SELECT 'order_items_enriched', COUNT(*) FROM analytics.order_items_enriched
UNION ALL
SELECT 'order_metrics', COUNT(*) FROM analytics.order_metrics
UNION ALL
SELECT 'orders_enriched', COUNT(*) FROM analytics.orders_enriched
UNION ALL
SELECT 'products', COUNT(*) FROM analytics.products
ORDER BY view_name;


SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT product_id) AS unique_product_ids
FROM analytics.products;

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT zip_code_prefix) AS unique_zip_code_prefixes
FROM analytics.geolocation;

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id) AS unique_order_ids
FROM analytics.orders_enriched;

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT (order_id, order_item_id)) AS unique_order_items
FROM analytics.order_items_enriched;

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id) AS unique_order_ids
FROM analytics.order_metrics;


SELECT product_id, COUNT(*) AS rows_count
FROM analytics.products
GROUP BY product_id
HAVING COUNT(*) > 1;

SELECT zip_code_prefix, COUNT(*) AS rows_count
FROM analytics.geolocation
GROUP BY zip_code_prefix
HAVING COUNT(*) > 1;

SELECT order_id, COUNT(*) AS rows_count
FROM analytics.orders_enriched
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT order_id, order_item_id, COUNT(*) AS rows_count
FROM analytics.order_items_enriched
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

SELECT order_id, COUNT(*) AS rows_count
FROM analytics.order_metrics
GROUP BY order_id
HAVING COUNT(*) > 1;


SELECT (SELECT COUNT(*) FROM analytics.products)
     - (SELECT COUNT(*) FROM raw.products)
       AS products_row_difference;

SELECT (SELECT COUNT(*) FROM analytics.orders_enriched)
     - (SELECT COUNT(*) FROM raw.orders)
       AS orders_row_difference;

SELECT (SELECT COUNT(*) FROM analytics.order_items_enriched)
     - (SELECT COUNT(*) FROM raw.order_items)
       AS order_items_row_difference;

SELECT (SELECT COUNT(*) FROM analytics.order_metrics)
     - (SELECT COUNT(*) FROM raw.orders)
       AS order_metrics_row_difference;


SELECT COUNT(*) AS orders_without_customer
FROM analytics.orders_enriched
WHERE customer_unique_id IS NULL;

SELECT COUNT(*) AS items_without_product
FROM analytics.order_items_enriched
WHERE product_id IS NULL;

SELECT COUNT(*) AS items_without_seller
FROM analytics.order_items_enriched
WHERE seller_id IS NULL;


SELECT COUNT(*) AS unknown_products
FROM analytics.products
WHERE product_category_name_english = 'unknown';

SELECT product_category_name,
       COUNT(*) AS products_count
FROM analytics.products
WHERE product_category_name_english = 'unknown'
GROUP BY product_category_name
ORDER BY products_count DESC, product_category_name;


SELECT COUNT(*) FILTER (WHERE customer_latitude IS NULL)
           AS orders_without_customer_latitude,
       COUNT(*) FILTER (WHERE customer_longitude IS NULL)
           AS orders_without_customer_longitude
FROM analytics.orders_enriched;

SELECT COUNT(*) FILTER (WHERE seller_latitude IS NULL)
           AS items_without_seller_latitude,
       COUNT(*) FILTER (WHERE seller_longitude IS NULL)
           AS items_without_seller_longitude
FROM analytics.order_items_enriched;


SELECT COUNT(*) FILTER (WHERE approval_time_hours < 0)
           AS negative_approval_times,
       COUNT(*) FILTER (WHERE processing_time_days < 0)
           AS negative_processing_times,
       COUNT(*) FILTER (WHERE delivery_time_days < 0)
           AS negative_delivery_times
FROM analytics.orders_enriched;

SELECT COUNT(*) FILTER (
           WHERE order_delivered_customer_date IS NULL
             AND is_delayed IS NOT NULL
       ) AS undelivered_orders_with_delay_flag,
       COUNT(*) FILTER (
           WHERE order_delivered_customer_date IS NOT NULL
             AND is_delayed IS NULL
       ) AS delivered_orders_without_delay_flag
FROM analytics.orders_enriched;


SELECT COUNT(*) AS invalid_counts
FROM analytics.order_metrics
WHERE items_count < 0
   OR unique_products_count < 0
   OR sellers_count < 0
   OR payments_count < 0
   OR reviews_count < 0;

SELECT COUNT(*) AS inconsistent_unique_products
FROM analytics.order_metrics
WHERE unique_products_count > items_count;

SELECT COUNT(*) AS inconsistent_seller_counts
FROM analytics.order_metrics
WHERE sellers_count > items_count;

SELECT COUNT(*) AS negative_order_values
FROM analytics.order_metrics
WHERE products_value < 0
   OR freight_value < 0
   OR order_items_value < 0
   OR payment_value < 0;

SELECT COUNT(*) AS inconsistent_item_totals
FROM analytics.order_metrics
WHERE products_value IS NOT NULL
  AND freight_value IS NOT NULL
  AND order_items_value IS NOT NULL
  AND ABS(order_items_value - (products_value + freight_value)) > 0.01;


SELECT COUNT(*) FILTER (WHERE items_count = 0) AS orders_without_items,
       COUNT(*) FILTER (WHERE payments_count = 0) AS orders_without_payments,
       COUNT(*) FILTER (WHERE reviews_count = 0) AS orders_without_reviews
FROM analytics.order_metrics;


SELECT COUNT(*) AS mismatched_orders
FROM analytics.order_metrics
WHERE payment_value IS NOT NULL
  AND order_items_value IS NOT NULL
  AND ABS(payment_value - order_items_value) > 0.01;

SELECT order_id,
       order_items_value,
       payment_value,
       payment_value - order_items_value AS difference
FROM analytics.order_metrics
WHERE payment_value IS NOT NULL
  AND order_items_value IS NOT NULL
  AND ABS(payment_value - order_items_value) > 0.01
ORDER BY ABS(payment_value - order_items_value) DESC
LIMIT 20;


SELECT MIN(average_review_score) AS min_average_review_score,
       MAX(average_review_score) AS max_average_review_score
FROM analytics.order_metrics;

SELECT COUNT(*) AS invalid_average_review_scores
FROM analytics.order_metrics
WHERE average_review_score IS NOT NULL
  AND (average_review_score < 1 OR average_review_score > 5);


SELECT table_name
FROM information_schema.views
WHERE table_schema = 'analytics'
ORDER BY table_name;
