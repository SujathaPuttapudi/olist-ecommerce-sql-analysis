-- =========================================
-- OLIST PROJECT: DATA CLEANING
-- File: 02_clean.sql
-- =========================================


-- STEP 1: CREATE CLEAN SCHEMA
CREATE SCHEMA IF NOT EXISTS clean;


-- STEP 2: CREATE CLEAN ORDERS TABLE
-- CREATE TABLE clean.orders AS
SELECT
    TRIM(order_id) AS order_id,
    TRIM(customer_id) AS customer_id,
    LOWER(TRIM(order_status)) AS order_status,

    NULLIF(TRIM(order_purchase_timestamp), '')::timestamp
        AS order_purchase_timestamp,

    NULLIF(TRIM(order_approved_at), '')::timestamp
        AS order_approved_at,

    NULLIF(TRIM(order_delivered_carrier_date), '')::timestamp
        AS order_delivered_carrier_date,

    NULLIF(TRIM(order_delivered_customer_date), '')::timestamp
        AS order_delivered_customer_date,

    NULLIF(TRIM(order_estimated_delivery_date), '')::timestamp
        AS order_estimated_delivery_date

FROM raw.orders;


-- STEP 3: VERIFY CLEAN ORDERS
SELECT
    (SELECT COUNT(*) FROM raw.orders) AS raw_rows,
    (SELECT COUNT(*) FROM clean.orders) AS clean_rows;


-- STEP 4: CREATE CLEAN ORDER ITEMS
-- =========================================
-- STEP 4A: VALIDATE ORDER ITEM DATA
SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_item_id), '') IS NULL
    ) AS blank_item_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_item_id), '') IS NOT NULL
          AND NOT pg_input_is_valid(
              TRIM(order_item_id), 'integer'
          )
    ) AS invalid_item_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(shipping_limit_date), '') IS NULL
    ) AS blank_shipping_dates,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(shipping_limit_date), '') IS NOT NULL
          AND NOT pg_input_is_valid(
              TRIM(shipping_limit_date), 'timestamp'
          )
    ) AS invalid_shipping_dates

FROM raw.order_items;
-- STEP 4B: CREATE CLEAN ORDER ITEMS TABLE

CREATE TABLE clean.order_items AS
SELECT
    TRIM(order_id) AS order_id,
    TRIM(product_id) AS product_id,
    TRIM(seller_id) AS seller_id,
    TRIM(order_item_id)::integer AS order_item_id,
    TRIM(shipping_limit_date)::timestamp AS shipping_limit_date,
    TRIM(price)::numeric AS price,
    TRIM(freight_value)::numeric AS freight_value

FROM raw.order_items;
-- STEP 4C: VERIFY CLEAN ORDER ITEMS ROW COUNT

SELECT
    (SELECT COUNT(*) FROM raw.order_items) AS raw_rows,
    (SELECT COUNT(*) FROM clean.order_items) AS clean_rows;
-- STEP 4D: VERIFY CLEAN ORDER ITEMS DATA TYPES
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'order_items'
ORDER BY ordinal_position;
-- STEP 4E: VERIFY UNIQUE ORDER ITEM KEY
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (order_id, order_item_id)) AS unique_item_keys,
    COUNT(*) - COUNT(DISTINCT (order_id, order_item_id))
        AS duplicate_item_keys
FROM clean.order_items;
-- STEP 4F: ADD COMPOSITE PRIMARY KEY
ALTER TABLE clean.order_items
ADD CONSTRAINT pk_order_items
PRIMARY KEY (order_id, order_item_id);
-- =========================================
-- STEP 5: CLEAN ORDER PAYMENTS
-- =========================================

-- STEP 5A: VALIDATE PAYMENT DATA

SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_sequential), '') IS NULL
    ) AS blank_payment_sequential,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_sequential), '') IS NOT NULL
          AND NOT pg_input_is_valid(
              TRIM(payment_sequential), 'integer'
          )
    ) AS invalid_payment_sequential,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_installments), '') IS NOT NULL
          AND NOT pg_input_is_valid(
              TRIM(payment_installments), 'integer'
          )
    ) AS invalid_installments,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_value), '') IS NULL
    ) AS blank_payment_value,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_value), '') IS NOT NULL
          AND NOT pg_input_is_valid(
              TRIM(payment_value), 'numeric'
          )
    ) AS invalid_payment_value

FROM raw.order_payments;
-- STEP 5B: CREATE CLEAN ORDER PAYMENTS TABLE

CREATE TABLE clean.order_payments AS
SELECT
    TRIM(order_id) AS order_id,
    TRIM(payment_type) AS payment_type,
    TRIM(payment_sequential)::integer AS payment_sequential,
    TRIM(payment_installments)::integer AS payment_installments,
    TRIM(payment_value)::numeric AS payment_value
FROM raw.order_payments;
-- STEP 5C: VERIFY CLEAN ORDER PAYMENTS ROW COUNT

SELECT
    (SELECT COUNT(*) FROM raw.order_payments) AS raw_rows,
    (SELECT COUNT(*) FROM clean.order_payments) AS clean_rows;
-- STEP 5D: VERIFY CLEAN ORDER PAYMENTS DATA TYPES

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'order_payments'
ORDER BY ordinal_position;
-- STEP 5E: VERIFY UNIQUE PAYMENT KEY

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (order_id, payment_sequential))
        AS unique_payment_keys,
    COUNT(*) - COUNT(DISTINCT (order_id, payment_sequential))
        AS duplicate_payment_keys
FROM clean.order_payments;
-- STEP 5F: ADD COMPOSITE PRIMARY KEY

ALTER TABLE clean.order_payments
ADD CONSTRAINT pk_order_payments
PRIMARY KEY (order_id, payment_sequential);
-- STEP 5G: INSPECT ZERO-INSTALLMENT RECORDS

SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM clean.order_payments
WHERE payment_installments = 0
ORDER BY order_id;
-- STEP 5H: FLAG NON-POSITIVE INSTALLMENT RECORDS

ALTER TABLE clean.order_payments
ADD COLUMN has_installment_issue BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE clean.order_payments
SET has_installment_issue = TRUE
WHERE payment_installments <= 0;
-- STEP 5I: VERIFY INSTALLMENT QUALITY FLAGS

SELECT
    has_installment_issue,
    COUNT(*) AS record_count
FROM clean.order_payments
GROUP BY has_installment_issue
ORDER BY has_installment_issue;
-- =========================================
-- STEP 6: CLEAN CUSTOMER DATA
-- =========================================

-- STEP 6A: VALIDATE CUSTOMER DATA

SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(customer_id), '') IS NULL
    ) AS blank_customer_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(customer_unique_id), '') IS NULL
    ) AS blank_customer_unique_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(customer_zip_code_prefix), '') IS NULL
    ) AS blank_zip_codes,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(customer_city), '') IS NULL
    ) AS blank_cities,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(customer_state), '') IS NULL
    ) AS blank_states

FROM raw.customers;
-- STEP 6B: CREATE CLEAN CUSTOMERS TABLE

CREATE TABLE clean.customers AS
SELECT
    TRIM(customer_id) AS customer_id,
    TRIM(customer_unique_id) AS customer_unique_id,
    TRIM(customer_zip_code_prefix) AS customer_zip_code_prefix,
    INITCAP(TRIM(customer_city)) AS customer_city,
    UPPER(TRIM(customer_state)) AS customer_state
FROM raw.customers;
-- STEP 6C: VERIFY CLEAN CUSTOMERS ROW COUNT

SELECT
    (SELECT COUNT(*) FROM raw.customers) AS raw_rows,
    (SELECT COUNT(*) FROM clean.customers) AS clean_rows;
-- STEP 6D: VERIFY CLEAN CUSTOMERS DATA TYPES

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'customers'
ORDER BY ordinal_position;
-- STEP 6E: CHECK CUSTOMER ID UNIQUENESS

SELECT
    COUNT(*) AS total_rows,
    COUNT(customer_id) AS non_null_customer_ids,
    COUNT(DISTINCT customer_id) AS unique_customer_ids,
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_customer_ids
FROM clean.customers;
-- STEP 6F: ADD PRIMARY KEY TO CUSTOMERS

ALTER TABLE clean.customers
ADD CONSTRAINT pk_customers PRIMARY KEY (customer_id);
-- STEP 7A: PROFILE RAW PRODUCTS

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS unique_product_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_id), '') IS NULL
    ) AS missing_product_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_category_name), '') IS NULL
    ) AS missing_categories,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_weight_g), '') IS NULL
    ) AS missing_weights,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_length_cm), '') IS NULL
    ) AS missing_lengths,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_height_cm), '') IS NULL
    ) AS missing_heights,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_width_cm), '') IS NULL
    ) AS missing_widths

FROM raw.products;
-- STEP 7B: CREATE CLEAN PRODUCTS TABLE

CREATE TABLE clean.products AS
SELECT
    TRIM(product_id) AS product_id,
    NULLIF(TRIM(product_category_name), '') AS product_category_name,
    NULLIF(TRIM(product_name_lenght), '')::integer AS product_name_lenght,
    NULLIF(TRIM(product_description_lenght), '')::integer AS product_description_lenght,
    NULLIF(TRIM(product_photos_qty), '')::integer AS product_photos_qty,
    NULLIF(TRIM(product_weight_g), '')::integer AS product_weight_g,
    NULLIF(TRIM(product_length_cm), '')::integer AS product_length_cm,
    NULLIF(TRIM(product_height_cm), '')::integer AS product_height_cm,
    NULLIF(TRIM(product_width_cm), '')::integer AS product_width_cm
FROM raw.products;
-- STEP 7C: VERIFY CLEAN PRODUCTS ROW COUNT

SELECT
    (SELECT COUNT(*) FROM raw.products) AS raw_rows,
    (SELECT COUNT(*) FROM clean.products) AS clean_rows;
-- STEP 7D: VERIFY CLEAN PRODUCTS DATA TYPES

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'products'
ORDER BY ordinal_position;
-- STEP 7E: CHECK PRODUCT ID UNIQUENESS

SELECT
    COUNT(*) AS total_rows,
    COUNT(product_id) AS non_null_product_ids,
    COUNT(DISTINCT product_id) AS unique_product_ids,
    COUNT(*) - COUNT(DISTINCT product_id) AS duplicate_product_ids
FROM clean.products;
-- STEP 7F: ADD PRIMARY KEY TO PRODUCTS

ALTER TABLE clean.products
ADD CONSTRAINT pk_products PRIMARY KEY (product_id);
-- STEP 7G: CHECK MISSING PRODUCT ATTRIBUTE PATTERNS

SELECT
    COUNT(*) FILTER (
        WHERE product_category_name IS NULL
    ) AS missing_categories,

    COUNT(*) FILTER (
        WHERE product_name_lenght IS NULL
    ) AS missing_name_lengths,

    COUNT(*) FILTER (
        WHERE product_description_lenght IS NULL
    ) AS missing_description_lengths,

    COUNT(*) FILTER (
        WHERE product_photos_qty IS NULL
    ) AS missing_photo_counts,

    COUNT(*) FILTER (
        WHERE product_category_name IS NULL
          AND product_name_lenght IS NULL
          AND product_description_lenght IS NULL
          AND product_photos_qty IS NULL
    ) AS missing_all_four_descriptive_fields,

    COUNT(*) FILTER (
        WHERE product_weight_g IS NULL
          AND product_length_cm IS NULL
          AND product_height_cm IS NULL
          AND product_width_cm IS NULL
    ) AS missing_all_four_physical_dimensions

FROM clean.products;
-- STEP 8A: PROFILE RAW SELLERS

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS unique_seller_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(seller_id), '') IS NULL
    ) AS missing_seller_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(seller_zip_code_prefix), '') IS NULL
    ) AS missing_zip_codes,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(seller_city), '') IS NULL
    ) AS missing_cities,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(seller_state), '') IS NULL
    ) AS missing_states

FROM raw.sellers;
-- STEP 8B: CREATE CLEAN SELLERS TABLE

CREATE TABLE clean.sellers AS
SELECT
    TRIM(seller_id) AS seller_id,
    TRIM(seller_zip_code_prefix) AS seller_zip_code_prefix,
    INITCAP(TRIM(seller_city)) AS seller_city,
    UPPER(TRIM(seller_state)) AS seller_state
FROM raw.sellers;
-- STEP 8C: VERIFY CLEAN SELLERS ROW COUNT

SELECT
    (SELECT COUNT(*) FROM raw.sellers) AS raw_rows,
    (SELECT COUNT(*) FROM clean.sellers) AS clean_rows;
-- STEP 8D: VERIFY CLEAN SELLERS DATA TYPES

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'sellers'
ORDER BY ordinal_position;
-- STEP 8E: CHECK SELLER ID UNIQUENESS

SELECT
    COUNT(*) AS total_rows,
    COUNT(seller_id) AS non_null_seller_ids,
    COUNT(DISTINCT seller_id) AS unique_seller_ids,
    COUNT(*) - COUNT(DISTINCT seller_id) AS duplicate_seller_ids
FROM clean.sellers;
-- STEP 8F: ADD PRIMARY KEY TO SELLERS

ALTER TABLE clean.sellers
ADD CONSTRAINT pk_sellers PRIMARY KEY (seller_id);
-- STEP 9A: PROFILE CATEGORY TRANSLATION

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_category_name) AS unique_portuguese_categories,
    COUNT(DISTINCT product_category_name_english) AS unique_english_categories,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_category_name), '') IS NULL
    ) AS missing_portuguese_categories,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_category_name_english), '') IS NULL
    ) AS missing_english_categories

FROM raw.category_name_translation;
-- STEP 9B: CREATE CLEAN CATEGORY TRANSLATION TABLE

CREATE TABLE clean.category_name_translation AS
SELECT
    TRIM(product_category_name) AS product_category_name,
    TRIM(product_category_name_english) AS product_category_name_english
FROM raw.category_name_translation;
-- STEP 9C: VERIFY CATEGORY TRANSLATION ROW COUNT

SELECT
    (SELECT COUNT(*) FROM raw.category_name_translation) AS raw_rows,
    (SELECT COUNT(*) FROM clean.category_name_translation) AS clean_rows;
-- STEP 9D: VERIFY CATEGORY TRANSLATION DATA TYPES

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'category_name_translation'
ORDER BY ordinal_position;
-- STEP 9E: CHECK PORTUGUESE CATEGORY UNIQUENESS

SELECT
    COUNT(*) AS total_rows,
    COUNT(product_category_name) AS non_null_categories,
    COUNT(DISTINCT product_category_name) AS unique_categories,
    COUNT(*) - COUNT(DISTINCT product_category_name) AS duplicate_categories
FROM clean.category_name_translation;
-- STEP 9F: ADD PRIMARY KEY TO CATEGORY TRANSLATION

ALTER TABLE clean.category_name_translation
ADD CONSTRAINT pk_category_translation
PRIMARY KEY (product_category_name);
-- STEP 10A: PROFILE RAW ORDER REVIEWS

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(DISTINCT order_id) AS unique_order_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(review_id), '') IS NULL
    ) AS missing_review_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_id), '') IS NULL
    ) AS missing_order_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(review_score), '') IS NULL
    ) AS missing_review_scores,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(review_comment_title), '') IS NULL
    ) AS missing_review_titles,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(review_comment_message), '') IS NULL
    ) AS missing_review_messages

FROM raw.order_reviews;
-- STEP 10B: FIND REPEATED REVIEW IDS

SELECT
    review_id,
    COUNT(*) AS record_count,
    COUNT(DISTINCT order_id) AS linked_orders,
    COUNT(DISTINCT review_score) AS different_scores
FROM raw.order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC
LIMIT 20;
-- STEP 10C: SUMMARIZE REPEATED REVIEW IDS

SELECT
    COUNT(*) AS repeated_review_ids,
    SUM(record_count) AS records_with_repeated_ids,
    SUM(record_count - 1) AS extra_records,
    COUNT(*) FILTER (
        WHERE linked_orders > 1
    ) AS review_ids_linked_to_multiple_orders
FROM (
    SELECT
        review_id,
        COUNT(*) AS record_count,
        COUNT(DISTINCT order_id) AS linked_orders
    FROM raw.order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS repeated;
-- STEP 10C: SUMMARIZE REPEATED REVIEW IDS

SELECT
    COUNT(*) AS repeated_review_ids,
    SUM(record_count) AS records_with_repeated_ids,
    SUM(record_count - 1) AS extra_records,
    COUNT(*) FILTER (
        WHERE linked_orders > 1
    ) AS review_ids_linked_to_multiple_orders
FROM (
    SELECT
        review_id,
        COUNT(*) AS record_count,
        COUNT(DISTINCT order_id) AS linked_orders
    FROM raw.order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS repeated;
-- STEP 10D: CHECK REVIEW ID AND ORDER ID COMBINATION

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (review_id, order_id)) AS unique_review_order_pairs,
    COUNT(*) - COUNT(DISTINCT (review_id, order_id)) AS duplicate_pairs
FROM raw.order_reviews;
-- STEP 10E: VALIDATE REVIEW TIMESTAMPS

SELECT
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(review_creation_date), '') IS NULL
    ) AS missing_creation_dates,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(review_answer_timestamp), '') IS NULL
    ) AS missing_answer_dates,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(review_creation_date), '') IS NOT NULL
          AND NOT pg_input_is_valid(
              TRIM(review_creation_date), 'timestamp'
          )
    ) AS invalid_creation_dates,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(review_answer_timestamp), '') IS NOT NULL
          AND NOT pg_input_is_valid(
              TRIM(review_answer_timestamp), 'timestamp'
          )
    ) AS invalid_answer_dates

FROM raw.order_reviews;
-- STEP 10F: CREATE CLEAN ORDER REVIEWS TABLE

CREATE TABLE clean.order_reviews AS
SELECT
    TRIM(review_id) AS review_id,
    TRIM(order_id) AS order_id,
    TRIM(review_score)::integer AS review_score,
    NULLIF(TRIM(review_comment_title), '') AS review_comment_title,
    NULLIF(TRIM(review_comment_message), '') AS review_comment_message,
    TRIM(review_creation_date)::timestamp AS review_creation_date,
    TRIM(review_answer_timestamp)::timestamp AS review_answer_timestamp
FROM raw.order_reviews;
-- STEP 10G: VERIFY CLEAN REVIEWS ROW COUNT

SELECT
    (SELECT COUNT(*) FROM raw.order_reviews) AS raw_rows,
    (SELECT COUNT(*) FROM clean.order_reviews) AS clean_rows;
-- STEP 10H: VERIFY CLEAN REVIEWS DATA TYPES

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'order_reviews'
ORDER BY ordinal_position;
-- STEP 10I: VERIFY REVIEW COMPOSITE KEY

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (review_id, order_id)) AS unique_review_order_pairs,
    COUNT(*) - COUNT(DISTINCT (review_id, order_id)) AS duplicate_pairs
FROM clean.order_reviews;
-- STEP 10J: ADD COMPOSITE PRIMARY KEY TO REVIEWS

ALTER TABLE clean.order_reviews
ADD CONSTRAINT pk_order_reviews
PRIMARY KEY (review_id, order_id);
-- STEP 11A: PROFILE RAW GEOLOCATION

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS unique_zip_prefixes,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(geolocation_zip_code_prefix), '') IS NULL
    ) AS missing_zip_prefixes,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(geolocation_lat), '') IS NULL
    ) AS missing_latitudes,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(geolocation_lng), '') IS NULL
    ) AS missing_longitudes,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(geolocation_city), '') IS NULL
    ) AS missing_cities,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(geolocation_state), '') IS NULL
    ) AS missing_states

FROM raw.geolocation;
-- STEP 11B: CHECK EXACT GEOLOCATION DUPLICATES

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    )) AS unique_full_records,
    COUNT(*) - COUNT(DISTINCT (
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    )) AS exact_duplicate_rows
FROM raw.geolocation;
-- STEP 11C: VALIDATE GEOLOCATION COORDINATES

SELECT
    COUNT(*) FILTER (
        WHERE NOT pg_input_is_valid(
            TRIM(geolocation_lat), 'numeric'
        )
    ) AS invalid_latitudes,

    COUNT(*) FILTER (
        WHERE NOT pg_input_is_valid(
            TRIM(geolocation_lng), 'numeric'
        )
    ) AS invalid_longitudes,

    COUNT(*) FILTER (
        WHERE TRIM(geolocation_lat)::numeric NOT BETWEEN -90 AND 90
    ) AS out_of_range_latitudes,

    COUNT(*) FILTER (
        WHERE TRIM(geolocation_lng)::numeric NOT BETWEEN -180 AND 180
    ) AS out_of_range_longitudes

FROM raw.geolocation;
-- STEP 11D: CREATE CLEAN GEOLOCATION TABLE

CREATE TABLE clean.geolocation AS
SELECT DISTINCT
    TRIM(geolocation_zip_code_prefix) AS geolocation_zip_code_prefix,
    TRIM(geolocation_lat)::numeric AS geolocation_lat,
    TRIM(geolocation_lng)::numeric AS geolocation_lng,
    INITCAP(TRIM(geolocation_city)) AS geolocation_city,
    UPPER(TRIM(geolocation_state)) AS geolocation_state
FROM raw.geolocation;
-- STEP 11E: VERIFY CLEAN GEOLOCATION ROW COUNT

SELECT
    (SELECT COUNT(*) FROM raw.geolocation) AS raw_rows,
    (SELECT COUNT(*) FROM clean.geolocation) AS clean_rows;
-- STEP 11F: VERIFY GEOLOCATION DATA TYPES

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'geolocation'
ORDER BY ordinal_position;-- STEP 11G: VERIFY GEOLOCATION UNIQUENESS

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS unique_zip_prefixes,
    COUNT(*) - COUNT(DISTINCT geolocation_zip_code_prefix) AS repeated_zip_rows,
    COUNT(*) - COUNT(DISTINCT (
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    )) AS duplicate_full_records
FROM clean.geolocation;

-- STEP 12A: VALIDATE TABLE RELATIONSHIPS

SELECT
    'Orders -> Customers' AS relationship,
    COUNT(*) AS source_rows,
    COUNT(*) FILTER (WHERE c.customer_id IS NULL) AS unmatched_rows
FROM clean.orders o
LEFT JOIN clean.customers c
    ON o.customer_id = c.customer_id

UNION ALL

SELECT
    'Order Items -> Orders',
    COUNT(*),
    COUNT(*) FILTER (WHERE o.order_id IS NULL)
FROM clean.order_items i
LEFT JOIN clean.orders o
    ON i.order_id = o.order_id

UNION ALL

SELECT
    'Order Items -> Products',
    COUNT(*),
    COUNT(*) FILTER (WHERE p.product_id IS NULL)
FROM clean.order_items i
LEFT JOIN clean.products p
    ON i.product_id = p.product_id

UNION ALL

SELECT
    'Order Items -> Sellers',
    COUNT(*),
    COUNT(*) FILTER (WHERE s.seller_id IS NULL)
FROM clean.order_items i
LEFT JOIN clean.sellers s
    ON i.seller_id = s.seller_id

UNION ALL

SELECT
    'Payments -> Orders',
    COUNT(*),
    COUNT(*) FILTER (WHERE o.order_id IS NULL)
FROM clean.order_payments p
LEFT JOIN clean.orders o
    ON p.order_id = o.order_id

UNION ALL

SELECT
    'Reviews -> Orders',
    COUNT(*),
    COUNT(*) FILTER (WHERE o.order_id IS NULL)
FROM clean.order_reviews r
LEFT JOIN clean.orders o
    ON r.order_id = o.order_id

UNION ALL

SELECT
    'Orders -> Payments',
    COUNT(*),
    COUNT(*) FILTER (WHERE p.order_id IS NULL)
FROM clean.orders o
LEFT JOIN clean.order_payments p
    ON o.order_id = p.order_id

UNION ALL

SELECT
    'Products -> Category Translation',
    COUNT(*),
    COUNT(*) FILTER (WHERE t.product_category_name IS NULL)
FROM clean.products p
LEFT JOIN clean.category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL;
-- STEP 12B: VERIFY ORDERS WITHOUT PAYMENT RECORDS

SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM clean.order_payments p
            WHERE p.order_id = o.order_id
        )
    ) AS orders_without_payment
FROM clean.orders o;
-- STEP 12C: IDENTIFY UNTRANSLATED CATEGORIES

SELECT
    p.product_category_name,
    COUNT(*) AS product_count
FROM clean.products p
LEFT JOIN clean.category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY product_count DESC;
-- STEP 12D: ADD VALIDATED FOREIGN KEYS

ALTER TABLE clean.orders
ADD CONSTRAINT fk_orders_customers
FOREIGN KEY (customer_id)
REFERENCES clean.customers(customer_id);

ALTER TABLE clean.order_items
ADD CONSTRAINT fk_items_orders
FOREIGN KEY (order_id)
REFERENCES clean.orders(order_id);

ALTER TABLE clean.order_items
ADD CONSTRAINT fk_items_products
FOREIGN KEY (product_id)
REFERENCES clean.products(product_id);

ALTER TABLE clean.order_items
ADD CONSTRAINT fk_items_sellers
FOREIGN KEY (seller_id)
REFERENCES clean.sellers(seller_id);

ALTER TABLE clean.order_payments
ADD CONSTRAINT fk_payments_orders
FOREIGN KEY (order_id)
REFERENCES clean.orders(order_id);

ALTER TABLE clean.order_reviews
ADD CONSTRAINT fk_reviews_orders
FOREIGN KEY (order_id)
REFERENCES clean.orders(order_id);
-- STEP 12E: CHECK ORDERS TABLE CONSTRAINTS

SELECT
    conname AS constraint_name,
    contype AS constraint_type
FROM pg_constraint
WHERE conrelid = 'clean.orders'::regclass;
-- STEP 12F: VERIFY ORDERS PRIMARY KEY CANDIDATE

SELECT
    COUNT(*) AS total_rows,
    COUNT(order_id) AS non_null_order_ids,
    COUNT(DISTINCT order_id) AS unique_order_ids
FROM clean.orders;
-- STEP 12G: ADD ORDERS PRIMARY KEY

ALTER TABLE clean.orders
ADD CONSTRAINT pk_orders PRIMARY KEY (order_id);
-- STEP 12H: CHECK EXISTING FOREIGN KEYS

SELECT
    conrelid::regclass AS table_name,
    conname AS constraint_name,
    confrelid::regclass AS referenced_table
FROM pg_constraint
WHERE contype = 'f'
  AND connamespace = 'clean'::regnamespace
ORDER BY table_name, constraint_name;
-- STEP 12I: ADD VALIDATED FOREIGN KEYS

ALTER TABLE clean.orders
ADD CONSTRAINT fk_orders_customers
FOREIGN KEY (customer_id)
REFERENCES clean.customers(customer_id);

ALTER TABLE clean.order_items
ADD CONSTRAINT fk_items_orders
FOREIGN KEY (order_id)
REFERENCES clean.orders(order_id);

ALTER TABLE clean.order_items
ADD CONSTRAINT fk_items_products
FOREIGN KEY (product_id)
REFERENCES clean.products(product_id);

ALTER TABLE clean.order_items
ADD CONSTRAINT fk_items_sellers
FOREIGN KEY (seller_id)
REFERENCES clean.sellers(seller_id);

ALTER TABLE clean.order_payments
ADD CONSTRAINT fk_payments_orders
FOREIGN KEY (order_id)
REFERENCES clean.orders(order_id);

ALTER TABLE clean.order_reviews
ADD CONSTRAINT fk_reviews_orders
FOREIGN KEY (order_id)
REFERENCES clean.orders(order_id);
-- STEP 12J: VERIFY FOREIGN KEYS

SELECT
    conrelid::regclass AS table_name,
    conname AS constraint_name,
    confrelid::regclass AS referenced_table
FROM pg_constraint
WHERE contype = 'f'
  AND connamespace = 'clean'::regnamespace
ORDER BY table_name, constraint_name;