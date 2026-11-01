/*
PROJECT: Olist Brazilian E-Commerce SQL Analysis
FILE: 01_profile.sql

PURPOSE
-------
Reproducible data profiling for the Olist raw dataset.

IMPORTANT
---------
1. Run this script while connected to the olist_project database.
2. The script only reads from the raw schema. It does not modify raw data.
3. Run section by section if you want to inspect each result separately.
4. Range checks below use guarded casts so malformed values do not crash the query.
5. Findings and cleaning decisions should also be recorded in data_profiling_log.docx.
*/

-- ============================================================
-- 0. BASELINE: ROW COUNTS
-- ============================================================

SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM raw.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM raw.order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM raw.order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM raw.order_reviews
UNION ALL
SELECT 'customers', COUNT(*) FROM raw.customers
UNION ALL
SELECT 'sellers', COUNT(*) FROM raw.sellers
UNION ALL
SELECT 'products', COUNT(*) FROM raw.products
UNION ALL
SELECT 'geolocation', COUNT(*) FROM raw.geolocation
UNION ALL
SELECT 'category_name_translation', COUNT(*) FROM raw.category_name_translation
ORDER BY table_name;


-- ============================================================
-- 1. KEY UNIQUENESS / GRAIN CHECKS
-- ============================================================

-- Orders: order_id should identify one order row.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_order_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_id_rows
FROM raw.orders;

-- Order items: the expected grain is one row per order_id + order_item_id.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (order_id, order_item_id)) AS distinct_order_item_keys,
    COUNT(*) - COUNT(DISTINCT (order_id, order_item_id)) AS duplicate_composite_key_rows,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM raw.order_items;

-- Payments: the expected grain is one row per order_id + payment_sequential.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (order_id, payment_sequential)) AS distinct_payment_keys,
    COUNT(*) - COUNT(DISTINCT (order_id, payment_sequential)) AS duplicate_composite_key_rows,
    COUNT(DISTINCT order_id) AS orders_with_payment_rows
FROM raw.order_payments;

-- Reviews: inspect review_id and order_id uniqueness separately.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id) AS distinct_review_ids,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM raw.order_reviews;

-- Customers: customer_id vs customer_unique_id.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS distinct_customer_unique_ids
FROM raw.customers;

-- Products and sellers: candidate primary-key checks.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS distinct_product_ids
FROM raw.products;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids
FROM raw.sellers;


-- ============================================================
-- 2. MISSING VALUES: ORDERS
-- ============================================================

SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_id), '') IS NULL) AS missing_order_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_id), '') IS NULL) AS missing_customer_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_status), '') IS NULL) AS missing_order_status,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_purchase_timestamp), '') IS NULL) AS missing_purchase_timestamp,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_approved_at), '') IS NULL) AS missing_approval_timestamp,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_delivered_carrier_date), '') IS NULL) AS missing_carrier_timestamp,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_delivered_customer_date), '') IS NULL) AS missing_customer_delivery_timestamp,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_estimated_delivery_date), '') IS NULL) AS missing_estimated_delivery_timestamp
FROM raw.orders;

-- Missing order dates by order status. Missing values may be status-dependent.
SELECT
    order_status,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_approved_at), '') IS NULL) AS missing_approval,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_delivered_carrier_date), '') IS NULL) AS missing_carrier_date,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_delivered_customer_date), '') IS NULL) AS missing_delivery_date
FROM raw.orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- ============================================================
-- 3. MISSING VALUES: ORDER ITEMS
-- ============================================================

SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_id), '') IS NULL) AS missing_order_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_item_id), '') IS NULL) AS missing_order_item_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_id), '') IS NULL) AS missing_product_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(seller_id), '') IS NULL) AS missing_seller_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(shipping_limit_date), '') IS NULL) AS missing_shipping_limit_date,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(price), '') IS NULL) AS missing_price,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(freight_value), '') IS NULL) AS missing_freight_value
FROM raw.order_items;

-- Check price/freight formats and negative values.
SELECT
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(price), '') IS NOT NULL
          AND TRIM(price) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'
    ) AS invalid_price_format,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(freight_value), '') IS NOT NULL
          AND TRIM(freight_value) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'
    ) AS invalid_freight_format,
    COUNT(*) FILTER (
        WHERE TRIM(price) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
          AND TRIM(price)::numeric < 0
    ) AS negative_price,
    COUNT(*) FILTER (
        WHERE TRIM(freight_value) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
          AND TRIM(freight_value)::numeric < 0
    ) AS negative_freight
FROM raw.order_items;

-- Inspect repeated order/product/seller combinations; do not assume these are duplicates.
SELECT
    order_id,
    product_id,
    seller_id,
    COUNT(*) AS item_rows,
    COUNT(DISTINCT order_item_id) AS distinct_item_numbers
FROM raw.order_items
GROUP BY order_id, product_id, seller_id
HAVING COUNT(*) > 1
ORDER BY item_rows DESC
LIMIT 50;


-- ============================================================
-- 4. MISSING VALUES / NUMERIC CHECKS: PAYMENTS
-- ============================================================

SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_id), '') IS NULL) AS missing_order_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(payment_sequential), '') IS NULL) AS missing_payment_sequential,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(payment_type), '') IS NULL) AS missing_payment_type,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(payment_installments), '') IS NULL) AS missing_payment_installments,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(payment_value), '') IS NULL) AS missing_payment_value
FROM raw.order_payments;

SELECT
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_sequential), '') IS NOT NULL
          AND TRIM(payment_sequential) !~ '^[+-]?[0-9]+$'
    ) AS invalid_payment_sequential_format,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_installments), '') IS NOT NULL
          AND TRIM(payment_installments) !~ '^[+-]?[0-9]+$'
    ) AS invalid_installments_format,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(payment_value), '') IS NOT NULL
          AND TRIM(payment_value) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'
    ) AS invalid_payment_value_format,
    COUNT(*) FILTER (
        WHERE TRIM(payment_installments) ~ '^[+-]?[0-9]+$'
          AND TRIM(payment_installments)::integer <= 0
    ) AS nonpositive_installments
FROM raw.order_payments;

-- Inspect the two zero/nonpositive installment rows identified during profiling.
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM raw.order_payments
WHERE TRIM(payment_installments) ~ '^[+-]?[0-9]+$'
  AND TRIM(payment_installments)::integer <= 0
ORDER BY order_id;


-- ============================================================
-- 5. REVIEWS
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id) AS distinct_review_ids,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(review_id), '') IS NULL) AS missing_review_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(order_id), '') IS NULL) AS missing_order_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(review_score), '') IS NULL) AS missing_review_score,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(review_comment_title), '') IS NULL) AS missing_review_title,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(review_comment_message), '') IS NULL) AS missing_review_message
FROM raw.order_reviews;

SELECT
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(review_score), '') IS NOT NULL
          AND TRIM(review_score) !~ '^[+-]?[0-9]+$'
    ) AS invalid_score_format,
    COUNT(*) FILTER (
        WHERE TRIM(review_score) ~ '^[+-]?[0-9]+$'
          AND TRIM(review_score)::integer NOT BETWEEN 1 AND 5
    ) AS score_outside_1_to_5
FROM raw.order_reviews;

-- Repeated review IDs: determine whether they refer to different orders.
SELECT
    COUNT(*) AS repeated_review_id_groups,
    COUNT(*) FILTER (WHERE distinct_orders > 1) AS repeated_ids_linked_to_multiple_orders,
    SUM(row_count - 1) AS extra_rows_from_repeated_ids
FROM (
    SELECT
        review_id,
        COUNT(*) AS row_count,
        COUNT(DISTINCT order_id) AS distinct_orders
    FROM raw.order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS repeated_reviews;

-- Inspect one repeated review ID (example found during profiling).
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM raw.order_reviews
WHERE review_id = '08528f70f579f0c830189efc523d2182'
ORDER BY order_id;


-- ============================================================
-- 6. CUSTOMERS
-- ============================================================

SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_id), '') IS NULL) AS missing_customer_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_unique_id), '') IS NULL) AS missing_customer_unique_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_zip_code_prefix), '') IS NULL) AS missing_zip_prefix,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_city), '') IS NULL) AS missing_city,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_state), '') IS NULL) AS missing_state
FROM raw.customers;


-- ============================================================
-- 7. PRODUCTS AND CATEGORY TRANSLATIONS
-- ============================================================

SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT product_id) AS distinct_product_ids,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_category_name), '') IS NULL) AS missing_category,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_name_length), '') IS NULL) AS missing_name_length,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_description_length), '') IS NULL) AS missing_description_length,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_photos_qty), '') IS NULL) AS missing_photos_qty,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_weight_g), '') IS NULL) AS missing_weight,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_length_cm), '') IS NULL) AS missing_length,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_height_cm), '') IS NULL) AS missing_height,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_width_cm), '') IS NULL) AS missing_width
FROM raw.products;

-- Confirm whether the same products are missing all four descriptive attributes.
SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_category_name), '') IS NULL) AS missing_category,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_name_length), '') IS NULL) AS missing_name_length,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_description_length), '') IS NULL) AS missing_description_length,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_photos_qty), '') IS NULL) AS missing_photos_qty,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_category_name), '') IS NULL
          AND NULLIF(TRIM(product_name_length), '') IS NULL
          AND NULLIF(TRIM(product_description_length), '') IS NULL
          AND NULLIF(TRIM(product_photos_qty), '') IS NULL
    ) AS missing_all_four
FROM raw.products;

-- Numeric-format validation for product attributes.
SELECT
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_weight_g), '') IS NOT NULL
          AND TRIM(product_weight_g) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'
    ) AS invalid_weight_format,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_length_cm), '') IS NOT NULL
          AND TRIM(product_length_cm) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'
    ) AS invalid_length_format,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_height_cm), '') IS NOT NULL
          AND TRIM(product_height_cm) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'
    ) AS invalid_height_format,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_width_cm), '') IS NOT NULL
          AND TRIM(product_width_cm) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'
    ) AS invalid_width_format,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(product_photos_qty), '') IS NOT NULL
          AND TRIM(product_photos_qty) !~ '^[+-]?[0-9]+$'
    ) AS invalid_photos_qty_format
FROM raw.products;

-- Range validation with guarded numeric conversions.
SELECT
    COUNT(*) FILTER (
        WHERE TRIM(product_weight_g) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
          AND TRIM(product_weight_g)::numeric < 0
    ) AS negative_weight,
    COUNT(*) FILTER (
        WHERE TRIM(product_length_cm) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
          AND TRIM(product_length_cm)::numeric <= 0
    ) AS nonpositive_length,
    COUNT(*) FILTER (
        WHERE TRIM(product_height_cm) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
          AND TRIM(product_height_cm)::numeric <= 0
    ) AS nonpositive_height,
    COUNT(*) FILTER (
        WHERE TRIM(product_width_cm) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
          AND TRIM(product_width_cm)::numeric <= 0
    ) AS nonpositive_width,
    COUNT(*) FILTER (
        WHERE TRIM(product_photos_qty) ~ '^[+-]?[0-9]+$'
          AND TRIM(product_photos_qty)::integer < 0
    ) AS negative_photos_qty
FROM raw.products;

-- Translation table quality.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_category_name) AS distinct_portuguese_categories,
    COUNT(DISTINCT product_category_name_english) AS distinct_english_categories,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_category_name), '') IS NULL) AS missing_portuguese_name,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(product_category_name_english), '') IS NULL) AS missing_english_name
FROM raw.category_name_translation;

-- Product-to-translation coverage and unmatched category names.
SELECT
    COUNT(*) AS product_rows,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(p.product_category_name), '') IS NULL) AS products_without_category,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(p.product_category_name), '') IS NOT NULL
          AND t.product_category_name IS NULL
    ) AS products_with_untranslated_category,
    COUNT(DISTINCT p.product_id) AS distinct_products_after_join
FROM raw.products AS p
LEFT JOIN raw.category_name_translation AS t
    ON p.product_category_name = t.product_category_name;

-- List category names that have products but no English translation.
SELECT
    p.product_category_name,
    COUNT(*) AS product_count
FROM raw.products AS p
LEFT JOIN raw.category_name_translation AS t
    ON p.product_category_name = t.product_category_name
WHERE NULLIF(TRIM(p.product_category_name), '') IS NOT NULL
  AND t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY product_count DESC;


-- ============================================================
-- 8. SELLERS
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(seller_id), '') IS NULL) AS missing_seller_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(seller_zip_code_prefix), '') IS NULL) AS missing_zip_prefix,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(seller_city), '') IS NULL) AS missing_city,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(seller_state), '') IS NULL) AS missing_state
FROM raw.sellers;


-- ============================================================
-- 9. GEOLOCATION
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(geolocation_zip_code_prefix), '') IS NULL) AS missing_zip_prefix,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(geolocation_lat), '') IS NULL) AS missing_latitude,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(geolocation_lng), '') IS NULL) AS missing_longitude,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(geolocation_city), '') IS NULL) AS missing_city,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(geolocation_state), '') IS NULL) AS missing_state
FROM raw.geolocation;

-- Coordinate format and range validation.
SELECT
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(geolocation_lat), '') IS NOT NULL
          AND TRIM(geolocation_lat) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'
    ) AS invalid_latitude_format,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(geolocation_lng), '') IS NOT NULL
          AND TRIM(geolocation_lng) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'
    ) AS invalid_longitude_format,
    COUNT(*) FILTER (
        WHERE TRIM(geolocation_lat) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
          AND (TRIM(geolocation_lat)::numeric < -90 OR TRIM(geolocation_lat)::numeric > 90)
    ) AS latitude_out_of_range,
    COUNT(*) FILTER (
        WHERE TRIM(geolocation_lng) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
          AND (TRIM(geolocation_lng)::numeric < -180 OR TRIM(geolocation_lng)::numeric > 180)
    ) AS longitude_out_of_range
FROM raw.geolocation;

-- Exact full-row duplicate count. Repeated ZIP prefixes alone are not necessarily duplicates.
SELECT
    (SELECT COUNT(*) FROM raw.geolocation) AS total_rows,
    (SELECT COUNT(*) FROM (
        SELECT DISTINCT
            geolocation_zip_code_prefix,
            geolocation_lat,
            geolocation_lng,
            geolocation_city,
            geolocation_state
        FROM raw.geolocation
    ) AS distinct_geo) AS distinct_full_records,
    (SELECT COUNT(*) FROM raw.geolocation)
      - (SELECT COUNT(*) FROM (
            SELECT DISTINCT
                geolocation_zip_code_prefix,
                geolocation_lat,
                geolocation_lng,
                geolocation_city,
                geolocation_state
            FROM raw.geolocation
        ) AS distinct_geo) AS exact_duplicate_rows;

SELECT
    COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_zip_prefixes,
    ROUND(COUNT(*)::numeric / COUNT(DISTINCT geolocation_zip_code_prefix), 2) AS average_rows_per_zip_prefix,
    MAX(rows_per_zip) AS maximum_rows_for_one_zip_prefix
FROM (
    SELECT geolocation_zip_code_prefix, COUNT(*) AS rows_per_zip
    FROM raw.geolocation
    GROUP BY geolocation_zip_code_prefix
) AS zip_counts;


-- ============================================================
-- 10. CROSS-TABLE RELATIONSHIP CHECKS
-- ============================================================

-- Order items whose product IDs do not exist in products.
SELECT COUNT(*) AS order_items_without_matching_product
FROM raw.order_items AS oi
LEFT JOIN raw.products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Order items whose seller IDs do not exist in sellers.
SELECT COUNT(*) AS order_items_without_matching_seller
FROM raw.order_items AS oi
LEFT JOIN raw.sellers AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Orders without any payment row.
SELECT COUNT(*) AS orders_without_payment_records
FROM raw.orders AS o
LEFT JOIN raw.order_payments AS op
    ON o.order_id = op.order_id
WHERE op.order_id IS NULL;

-- Orders whose customer_id does not exist in customers.
SELECT COUNT(*) AS orders_without_matching_customer
FROM raw.orders AS o
LEFT JOIN raw.customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Reviews whose order_id does not exist in orders.
SELECT COUNT(*) AS reviews_without_matching_order
FROM raw.order_reviews AS r
LEFT JOIN raw.orders AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


-- ============================================================
-- 11. TIMESTAMP FORMAT / CONVERSION VALIDATION (POSTGRESQL 18)
-- ============================================================

SELECT
    'order_purchase_timestamp' AS field_name,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_purchase_timestamp), '') IS NOT NULL
          AND NOT pg_input_is_valid(TRIM(order_purchase_timestamp), 'timestamp without time zone')
    ) AS invalid_timestamps
FROM raw.orders

UNION ALL
SELECT 'order_approved_at',
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_approved_at), '') IS NOT NULL
          AND NOT pg_input_is_valid(TRIM(order_approved_at), 'timestamp without time zone')
    )
FROM raw.orders

UNION ALL
SELECT 'order_delivered_carrier_date',
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL
          AND NOT pg_input_is_valid(TRIM(order_delivered_carrier_date), 'timestamp without time zone')
    )
FROM raw.orders

UNION ALL
SELECT 'order_delivered_customer_date',
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_delivered_customer_date), '') IS NOT NULL
          AND NOT pg_input_is_valid(TRIM(order_delivered_customer_date), 'timestamp without time zone')
    )
FROM raw.orders

UNION ALL
SELECT 'order_estimated_delivery_date',
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_estimated_delivery_date), '') IS NOT NULL
          AND NOT pg_input_is_valid(TRIM(order_estimated_delivery_date), 'timestamp without time zone')
    )
FROM raw.orders;


-- ============================================================
-- 12. TIMESTAMP CHRONOLOGY CHECKS
-- ============================================================

-- Counts for each chronology rule. Counts can overlap.
SELECT
    'Approval before purchase' AS check_name,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_approved_at), '') IS NOT NULL
          AND NULLIF(TRIM(order_purchase_timestamp), '') IS NOT NULL
          AND TRIM(order_approved_at)::timestamp < TRIM(order_purchase_timestamp)::timestamp
    ) AS issue_count
FROM raw.orders

UNION ALL
SELECT
    'Carrier handover before purchase',
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL
          AND NULLIF(TRIM(order_purchase_timestamp), '') IS NOT NULL
          AND TRIM(order_delivered_carrier_date)::timestamp < TRIM(order_purchase_timestamp)::timestamp
    )
FROM raw.orders

UNION ALL
SELECT
    'Carrier handover before approval',
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL
          AND NULLIF(TRIM(order_approved_at), '') IS NOT NULL
          AND TRIM(order_delivered_carrier_date)::timestamp < TRIM(order_approved_at)::timestamp
    )
FROM raw.orders

UNION ALL
SELECT
    'Customer delivery before carrier handover',
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_delivered_customer_date), '') IS NOT NULL
          AND NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL
          AND TRIM(order_delivered_customer_date)::timestamp < TRIM(order_delivered_carrier_date)::timestamp
    )
FROM raw.orders

UNION ALL
SELECT
    'Customer delivery before purchase',
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_delivered_customer_date), '') IS NOT NULL
          AND NULLIF(TRIM(order_purchase_timestamp), '') IS NOT NULL
          AND TRIM(order_delivered_customer_date)::timestamp < TRIM(order_purchase_timestamp)::timestamp
    )
FROM raw.orders;

-- Count unique orders with at least one chronology issue.
SELECT
    COUNT(*) AS total_orders_with_chronology_issues,
    COUNT(*) FILTER (
        WHERE TRIM(order_delivered_carrier_date)::timestamp < TRIM(order_purchase_timestamp)::timestamp
    ) AS carrier_before_purchase,
    COUNT(*) FILTER (
        WHERE TRIM(order_delivered_customer_date)::timestamp < TRIM(order_delivered_carrier_date)::timestamp
    ) AS delivery_before_carrier,
    COUNT(*) FILTER (
        WHERE TRIM(order_delivered_carrier_date)::timestamp < TRIM(order_approved_at)::timestamp
    ) AS carrier_before_approval
FROM raw.orders
WHERE
    (
        NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL
        AND NULLIF(TRIM(order_purchase_timestamp), '') IS NOT NULL
        AND TRIM(order_delivered_carrier_date)::timestamp < TRIM(order_purchase_timestamp)::timestamp
    )
    OR
    (
        NULLIF(TRIM(order_delivered_customer_date), '') IS NOT NULL
        AND NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL
        AND TRIM(order_delivered_customer_date)::timestamp < TRIM(order_delivered_carrier_date)::timestamp
    )
    OR
    (
        NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL
        AND NULLIF(TRIM(order_approved_at), '') IS NOT NULL
        AND TRIM(order_delivered_carrier_date)::timestamp < TRIM(order_approved_at)::timestamp
    );

-- Inspect a sample of affected orders; investigate before making any correction.
SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM raw.orders
WHERE
    (
        NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL
        AND NULLIF(TRIM(order_purchase_timestamp), '') IS NOT NULL
        AND TRIM(order_delivered_carrier_date)::timestamp < TRIM(order_purchase_timestamp)::timestamp
    )
    OR
    (
        NULLIF(TRIM(order_delivered_customer_date), '') IS NOT NULL
        AND NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL
        AND TRIM(order_delivered_customer_date)::timestamp < TRIM(order_delivered_carrier_date)::timestamp
    )
    OR
    (
        NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL
        AND NULLIF(TRIM(order_approved_at), '') IS NOT NULL
        AND TRIM(order_delivered_carrier_date)::timestamp < TRIM(order_approved_at)::timestamp
    )
ORDER BY order_status, order_id
LIMIT 30;


-- ============================================================
-- END OF PROFILING SCRIPT
-- ============================================================
