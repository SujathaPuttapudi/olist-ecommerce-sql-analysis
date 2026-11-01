-- STEP 13A: OVERALL SALES PERFORMANCE

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM clean.order_items
    GROUP BY order_id
)

SELECT
    COUNT(o.order_id) AS total_orders,
    COUNT(ov.order_id) AS orders_with_items,
    COUNT(*) FILTER (
        WHERE ov.order_id IS NULL
    ) AS orders_without_items,
    ROUND(SUM(ov.merchandise_value), 2) AS total_merchandise_sales,
    ROUND(SUM(ov.freight_value), 2) AS total_freight_value,
    ROUND(AVG(ov.merchandise_value), 2) AS average_order_value
FROM clean.orders o
LEFT JOIN order_values ov
    ON o.order_id = ov.order_id;
-- STEP 13B: SALES PERFORMANCE BY CATEGORY

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Uncategorized'
    ) AS category_name,
    COUNT(*) AS total_item_lines,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(DISTINCT oi.product_id) AS distinct_products,
    ROUND(SUM(oi.price), 2) AS merchandise_sales,
    ROUND(SUM(oi.freight_value), 2) AS freight_value
FROM clean.order_items oi
JOIN clean.products p
    ON oi.product_id = p.product_id
LEFT JOIN clean.category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Uncategorized'
    )
ORDER BY merchandise_sales DESC;
-- STEP 13C: CATEGORY SALES CONTRIBUTION

WITH category_sales AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Uncategorized'
        ) AS category_name,
        SUM(oi.price) AS merchandise_sales
    FROM clean.order_items oi
    JOIN clean.products p
        ON oi.product_id = p.product_id
    LEFT JOIN clean.category_name_translation t
        ON p.product_category_name = t.product_category_name
    GROUP BY
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Uncategorized'
        )
)

SELECT
    category_name,
    ROUND(merchandise_sales, 2) AS merchandise_sales,
    ROUND(
        merchandise_sales * 100.0 /
        SUM(merchandise_sales) OVER (),
        2
    ) AS sales_contribution_pct,
    DENSE_RANK() OVER (
        ORDER BY merchandise_sales DESC
    ) AS sales_rank
FROM category_sales
ORDER BY sales_rank;

-- STEP 14A: PRODUCT-LEVEL SALES PERFORMANCE

SELECT
    oi.product_id,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Uncategorized'
    ) AS category_name,
    COUNT(*) AS item_lines_sold,
    COUNT(DISTINCT oi.order_id) AS orders_containing_product,
    ROUND(SUM(oi.price), 2) AS merchandise_sales,
    ROUND(SUM(oi.freight_value), 2) AS total_freight,
    ROUND(AVG(oi.price), 2) AS average_item_price
FROM clean.order_items oi
JOIN clean.products p
    ON oi.product_id = p.product_id
LEFT JOIN clean.category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    oi.product_id,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Uncategorized'
    )
ORDER BY merchandise_sales DESC
LIMIT 20;
-- STEP 15A: CUSTOMER PURCHASE FREQUENCY

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM clean.order_items
    GROUP BY order_id
),

customer_summary AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS total_orders,
        COUNT(ov.order_id) AS orders_with_items,
        SUM(COALESCE(ov.merchandise_value, 0)) AS total_spent
    FROM clean.orders o
    JOIN clean.customers c
        ON o.customer_id = c.customer_id
    LEFT JOIN order_values ov
        ON o.order_id = ov.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS total_unique_customers,
    COUNT(*) FILTER (
        WHERE orders_with_items = 1
    ) AS one_time_customers,
    COUNT(*) FILTER (
        WHERE orders_with_items >= 2
    ) AS repeat_customers,
    ROUND(
        COUNT(*) FILTER (
            WHERE orders_with_items >= 2
        ) * 100.0 / COUNT(*),
        2
    ) AS repeat_customer_pct,
    ROUND(
        SUM(
            CASE
                WHEN orders_with_items >= 2 THEN total_spent
                ELSE 0
            END
        ),
        2
    ) AS repeat_customer_sales
FROM customer_summary;
-- STEP 16A: SALES BY CUSTOMER STATE

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM clean.order_items
    GROUP BY order_id
)

SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(ov.merchandise_value), 2) AS merchandise_sales,
    ROUND(AVG(ov.merchandise_value), 2) AS average_order_value
FROM clean.orders o
JOIN clean.customers c
    ON o.customer_id = c.customer_id
JOIN order_values ov
    ON o.order_id = ov.order_id
GROUP BY c.customer_state
ORDER BY merchandise_sales DESC;
-- STEP 16B: SALES BY SELLER STATE

SELECT
    s.seller_state,
    COUNT(DISTINCT s.seller_id) AS total_sellers,
    COUNT(*) AS item_lines_sold,
    COUNT(DISTINCT oi.order_id) AS orders_served,
    ROUND(SUM(oi.price), 2) AS merchandise_sales,
    ROUND(SUM(oi.freight_value), 2) AS total_freight
FROM clean.order_items oi
JOIN clean.sellers s
    ON oi.seller_id = s.seller_id
GROUP BY s.seller_state
ORDER BY merchandise_sales DESC;
-- STEP 17A: DELIVERY PERFORMANCE

SELECT
    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_estimated_delivery_date IS NOT NULL
    ) AS orders_with_both_dates,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date >
              order_estimated_delivery_date
    ) AS late_deliveries,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date <=
              order_estimated_delivery_date
    ) AS on_time_or_early_deliveries,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS missing_actual_delivery_date,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date -
                    order_purchase_timestamp
                )
            ) / 86400
        ) FILTER (
            WHERE order_delivered_customer_date IS NOT NULL
        ),
        2
    ) AS avg_delivery_days

FROM clean.orders
WHERE order_status = 'delivered';
-- STEP 17B: DELIVERY TIMING AND REVIEW SCORES

WITH delivery_status AS (
    SELECT
        order_id,
        CASE
            WHEN order_delivered_customer_date >
                 order_estimated_delivery_date
                THEN 'Late'
            WHEN order_delivered_customer_date <=
                 order_estimated_delivery_date
                THEN 'On time or early'
        END AS delivery_category
    FROM clean.orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

review_summary AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score,
        COUNT(*) AS review_count
    FROM clean.order_reviews
    GROUP BY order_id
)

SELECT
    d.delivery_category,
    COUNT(DISTINCT d.order_id) AS total_orders,
    COUNT(r.order_id) AS orders_with_reviews,
    ROUND(AVG(r.average_review_score), 2) AS average_review_score,
    ROUND(AVG(r.review_count), 2) AS average_reviews_per_order
FROM delivery_status d
LEFT JOIN review_summary r
    ON d.order_id = r.order_id
GROUP BY d.delivery_category
ORDER BY d.delivery_category;
-- STEP 18A: CUSTOMER REVIEW SCORE DISTRIBUTION

SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS review_percentage
FROM clean.order_reviews
GROUP BY review_score
ORDER BY review_score DESC;
-- STEP 18B: PAYMENT METHOD ANALYSIS

SELECT
    payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS orders_using_method,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM clean.order_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;
-- STEP 19A: SALES FROM PRODUCTS WITH MISSING CATEGORIES

SELECT
    COUNT(DISTINCT p.product_id) AS products_without_category,
    COUNT(*) AS item_lines,
    COUNT(DISTINCT oi.order_id) AS orders_affected,
    ROUND(SUM(oi.price), 2) AS merchandise_sales,
    ROUND(SUM(oi.price) * 100.0 /
        (SELECT SUM(price) FROM clean.order_items), 2
    ) AS sales_percentage
FROM clean.order_items oi
JOIN clean.products p
    ON oi.product_id = p.product_id
WHERE p.product_category_name IS NULL;
-- STEP 19B: DATA QUALITY SUMMARY

SELECT
    'Orders without item records' AS issue,
    COUNT(*) AS affected_records
FROM clean.orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM clean.order_items oi
    WHERE oi.order_id = o.order_id
)

UNION ALL

SELECT
    'Orders without payment records',
    COUNT(*)
FROM clean.orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM clean.order_payments p
    WHERE p.order_id = o.order_id
)

UNION ALL

SELECT
    'Products without categories',
    COUNT(*)
FROM clean.products
WHERE product_category_name IS NULL

UNION ALL

SELECT
    'Products without English category translation',
    COUNT(*)
FROM clean.products p
LEFT JOIN clean.category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL

UNION ALL

SELECT
    'Payment records with installment issues',
    COUNT(*)
FROM clean.order_payments
WHERE has_installment_issue = TRUE

UNION ALL

SELECT
    'Delivered orders without actual delivery date',
    COUNT(*)
FROM clean.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;
-- STEP 19C: DATA QUALITY IMPACT PERCENTAGES

SELECT
    'Orders without item records' AS issue,
    COUNT(*) AS affected_records,
    (SELECT COUNT(*) FROM clean.orders) AS total_records,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM clean.orders), 2
    ) AS affected_pct
FROM clean.orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM clean.order_items oi
    WHERE oi.order_id = o.order_id
)

UNION ALL

SELECT
    'Products without categories',
    COUNT(*),
    (SELECT COUNT(*) FROM clean.products),
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM clean.products), 2
    )
FROM clean.products
WHERE product_category_name IS NULL

UNION ALL

SELECT
    'Payment records with installment issues',
    COUNT(*),
    (SELECT COUNT(*) FROM clean.order_payments),
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM clean.order_payments), 2
    )
FROM clean.order_payments
WHERE has_installment_issue = TRUE

UNION ALL

SELECT
    'Delivered orders without actual delivery date',
    COUNT(*),
    (SELECT COUNT(*) FROM clean.orders
     WHERE order_status = 'delivered'),
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM clean.orders
         WHERE order_status = 'delivered'), 2
    )
FROM clean.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;
-- STEP 20A: FINAL CLEAN TABLE ROW COUNT VALIDATION

SELECT 'orders' AS table_name, COUNT(*) AS total_rows
FROM clean.orders

UNION ALL
SELECT 'order_items', COUNT(*)
FROM clean.order_items

UNION ALL
SELECT 'order_payments', COUNT(*)
FROM clean.order_payments

UNION ALL
SELECT 'customers', COUNT(*)
FROM clean.customers

UNION ALL
SELECT 'products', COUNT(*)
FROM clean.products

UNION ALL
SELECT 'sellers', COUNT(*)
FROM clean.sellers

UNION ALL
SELECT 'order_reviews', COUNT(*)
FROM clean.order_reviews

UNION ALL
SELECT 'geolocation', COUNT(*)
FROM clean.geolocation

UNION ALL
SELECT 'category_name_translation', COUNT(*)
FROM clean.category_name_translation

ORDER BY table_name;
-- STEP 20B: FINAL PRIMARY KEY AND FOREIGN KEY VALIDATION

SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type
FROM information_schema.table_constraints tc
WHERE tc.constraint_schema = 'clean'
  AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY
    tc.table_name,
    tc.constraint_type,
    tc.constraint_name;
-- STEP 20C: FINAL KEY UNIQUENESS VALIDATION

SELECT
    'orders' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_keys
FROM clean.orders

UNION ALL

SELECT
    'order_items',
    COUNT(*),
    COUNT(DISTINCT (order_id, order_item_id))
FROM clean.order_items

UNION ALL

SELECT
    'order_payments',
    COUNT(*),
    COUNT(DISTINCT (order_id, payment_sequential))
FROM clean.order_payments

UNION ALL

SELECT
    'customers',
    COUNT(*),
    COUNT(DISTINCT customer_id)
FROM clean.customers

UNION ALL

SELECT
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id)
FROM clean.products

UNION ALL

SELECT
    'sellers',
    COUNT(*),
    COUNT(DISTINCT seller_id)
FROM clean.sellers

UNION ALL

SELECT
    'order_reviews',
    COUNT(*),
    COUNT(DISTINCT (review_id, order_id))
FROM clean.order_reviews

UNION ALL

SELECT
    'category_name_translation',
    COUNT(*),
    COUNT(DISTINCT product_category_name)
FROM clean.category_name_translation

ORDER BY table_name;