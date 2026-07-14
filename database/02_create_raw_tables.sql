CREATE TABLE IF NOT EXISTS raw.category_translation (
    product_category_name TEXT PRIMARY KEY,
    product_category_name_english TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id CHAR(32) PRIMARY KEY,
    customer_unique_id CHAR(32) NOT NULL,
    customer_zip_code_prefix INTEGER NOT NULL,
    customer_city TEXT NOT NULL,
    customer_state CHAR(2) NOT NULL
);

CREATE TABLE IF NOT EXISTS raw.orders (
    order_id CHAR(32) PRIMARY KEY,
    customer_id CHAR(32) NOT NULL,
    order_status TEXT NOT NULL,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP NOT NULL,

	CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES raw.customers(customer_id)
);

CREATE TABLE IF NOT EXISTS raw.sellers (
    seller_id CHAR(32) PRIMARY KEY,
    seller_zip_code_prefix INTEGER NOT NULL,
    seller_city TEXT NOT NULL,
    seller_state CHAR(2) NOT NULL
);

CREATE TABLE IF NOT EXISTS raw.products (
    product_id CHAR(32) PRIMARY KEY,
    product_category_name TEXT,
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);

CREATE TABLE IF NOT EXISTS raw.order_items (
    order_id CHAR(32) NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id CHAR(32) NOT NULL,
    seller_id CHAR(32) NOT NULL,
    shipping_limit_date TIMESTAMP NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    freight_value NUMERIC(10, 2) NOT NULL,

    CONSTRAINT pk_order_items
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES raw.orders(order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES raw.products(product_id),

    CONSTRAINT fk_order_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES raw.sellers(seller_id),

    CONSTRAINT chk_order_items_price
        CHECK (price >= 0),

    CONSTRAINT chk_order_items_freight
        CHECK (freight_value >= 0)
);

CREATE TABLE IF NOT EXISTS raw.payments (
    order_id CHAR(32) NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type TEXT NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value NUMERIC(12, 2) NOT NULL,

    CONSTRAINT pk_payments
        PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id)
        REFERENCES raw.orders(order_id),

    CONSTRAINT chk_payments_installments
        CHECK (payment_installments >= 0),

    CONSTRAINT chk_payments_value
        CHECK (payment_value >= 0)
);

CREATE TABLE IF NOT EXISTS raw.reviews (
    review_id CHAR(32) NOT NULL,
    order_id CHAR(32) NOT NULL,
    review_score INTEGER NOT NULL,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP NOT NULL,
    review_answer_timestamp TIMESTAMP NOT NULL,

    CONSTRAINT pk_reviews
        PRIMARY KEY (review_id, order_id),

    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES raw.orders(order_id),

    CONSTRAINT chk_reviews_score
        CHECK (review_score BETWEEN 1 AND 5)
);

CREATE TABLE IF NOT EXISTS raw.geolocation (
    geolocation_id BIGSERIAL PRIMARY KEY,
    geolocation_zip_code_prefix INTEGER NOT NULL,
    geolocation_lat NUMERIC(10, 7) NOT NULL,
    geolocation_lng NUMERIC(10, 7) NOT NULL,
    geolocation_city TEXT NOT NULL,
    geolocation_state CHAR(2) NOT NULL
);