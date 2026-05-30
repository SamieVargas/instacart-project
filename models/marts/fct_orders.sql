-- ============================================================
-- fct_orders.sql
-- Mart model: order-level fact table
-- Grain: 1 row per order
--
-- What this model does:
--   - joins stg_orders to int_order_products_joined
--   - aggregates product-level data up to the order level
--   - calculates order size, reorder ratio, and flags
--     orders where the days_since_prior_order cap is active
--
-- Answers:
--   - what is the average order size by day of week?
--   - what is the reorder ratio per order?
--   - which orders are affected by the 30-day cap?
--
-- Grain check:
--   one row per order_id — confirmed by unique test in schema.yml
-- ============================================================

with orders as (

    SELECT
        order_id,
        user_id,
        eval_set,
        order_number,
        order_dow,
        order_hour_of_day,
        days_since_prior_order
    FROM
        {{ ref('stg_orders') }}

),

order_products as (

    SELECT
        order_id,
        product_id,
        reordered,
        add_to_cart_order,
        source_label
    FROM
        {{ ref('int_order_products_joined') }}

),

-- ------------------------------------------------------------
-- AGGREGATE TO ORDER GRAIN
-- each order has multiple products in int_order_products_joined
-- this aggregation collapses them back to 1 row per order
-- reorder_ratio = what proportion of items were reorders
-- order_size = total number of items in the order
-- ------------------------------------------------------------

order_aggregates as (

    SELECT
        order_id,
        COUNT(product_id)                               AS order_size,
        COUNTIF(reordered = 1)                          AS reordered_items,
        ROUND(COUNTIF(reordered = 1) / COUNT(product_id), 3) AS reorder_ratio
    FROM
        order_products
    GROUP BY
        order_id

),

joined as (

    SELECT

        -- keys
        orders.order_id,
        orders.user_id,

        -- order metadata
        orders.eval_set,
        orders.order_number,

        -- time dimensions
        -- order_dow: 0 = Sunday, 6 = Saturday
        orders.order_dow,
        orders.order_hour_of_day,

        -- ------------------------------------------------------------
        -- DAYS SINCE PRIOR ORDER
        -- NULL on first orders (order_number = 1) — confirmed in qc_02
        -- capped at 30 — confirmed in qc_01 (spike of 369K orders)
        -- is_capped flag marks orders where 30 likely means 30+
        -- downstream analysts should not treat capped values as exact
        -- ------------------------------------------------------------
        orders.days_since_prior_order,
        CASE
            WHEN orders.days_since_prior_order = 30 THEN TRUE
            ELSE FALSE
        END                                             AS is_days_since_prior_capped,

        -- order size metrics
        order_aggregates.order_size,
        order_aggregates.reordered_items,

        -- ------------------------------------------------------------
        -- REORDER RATIO
        -- proportion of items in this order that were reorders
        -- 0.0 = all new items, 1.0 = all reorders
        -- find_01 showed dairy eggs + produce drive high reorder rates
        -- a value > 1 would indicate a join fanout — tested in schema.yml
        -- ------------------------------------------------------------
        order_aggregates.reorder_ratio

    FROM
        orders
    LEFT JOIN
        order_aggregates
        ON orders.order_id = order_aggregates.order_id

)

SELECT
    *
FROM
    joined