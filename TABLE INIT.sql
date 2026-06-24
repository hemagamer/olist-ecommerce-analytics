CREATE DATABASE olist;


CREATE TABLE olist_customers_dataset (
    customer_id                VARCHAR(50)  PRIMARY KEY,
    customer_unique_id         VARCHAR(50),
    customer_zip_code_prefix   VARCHAR(10),
    customer_city              VARCHAR(50),
    customer_state             VARCHAR(5)
);

CREATE TABLE olist_geolocation_dataset (
    geolocation_id             SERIAL PRIMARY KEY,
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat            FLOAT,
    geolocation_lng            FLOAT,
    geolocation_city           VARCHAR(50),
    geolocation_state          VARCHAR(5)
);

CREATE TABLE olist_orders_dataset (
    order_id                        VARCHAR(50) PRIMARY KEY,
    customer_id                     VARCHAR(50),
    order_status                    VARCHAR(20),
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);

CREATE TABLE olist_order_items_dataset (
    order_id             VARCHAR(50),
    order_item_id        INT,
    product_id           VARCHAR(50),
    seller_id            VARCHAR(50),
    shipping_limit_date  TIMESTAMP,
    price                NUMERIC(10,2),
    freight_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE olist_order_payments_dataset (
    order_id             VARCHAR(50),
    payment_sequential   INT,
    payment_type         VARCHAR(20),
    payment_installments INT,
    payment_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE olist_order_reviews_dataset (
    review_id               VARCHAR(50),
    order_id                VARCHAR(50),
    review_score            INT,
    review_comment_title    VARCHAR(100),
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    PRIMARY KEY (review_id, order_id)
);

CREATE TABLE olist_products_dataset (
    product_id                   VARCHAR(50) PRIMARY KEY,
    product_category_name        VARCHAR(100),
    product_name_lenght          INT,
    product_description_lenght   INT,
    product_photos_qty           INT,
    product_weight_g             FLOAT,
    product_length_cm            FLOAT,
    product_height_cm            FLOAT,
    product_width_cm             FLOAT
);

CREATE TABLE olist_sellers_dataset (
    seller_id                VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix   VARCHAR(10),
    seller_city              VARCHAR(50),
    seller_state             VARCHAR(5)
);

-- Bridge table
CREATE TABLE customer_geolocation (
    customer_id     VARCHAR(50) NOT NULL,
    geolocation_id  INT         NOT NULL,
    PRIMARY KEY (customer_id, geolocation_id),
    FOREIGN KEY (customer_id)   REFERENCES olist_customers_dataset(customer_id),
    FOREIGN KEY (geolocation_id) REFERENCES olist_geolocation_dataset(geolocation_id)
);



CREATE INDEX idx_geo_zip ON olist_geolocation_dataset(geolocation_zip_code_prefix);
CREATE INDEX idx_cust_zip ON olist_customers_dataset(customer_zip_code_prefix);

INSERT INTO customer_geolocation (customer_id, geolocation_id)
SELECT c.customer_id, g.geolocation_id
FROM olist_customers_dataset c
JOIN olist_geolocation_dataset g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix;

select * from olist_sellers_dataset;
select * from olist_geolocation_dataset;
select * from customer_geolocation;
