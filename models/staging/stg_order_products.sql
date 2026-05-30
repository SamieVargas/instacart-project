-- ============================================================
-- stg_order_products.sql
-- Staging model combining prior and train order products
-- Grain: 1 row per product per order
--
-- What this model does:
--   - unions prior and train into one table
--   - adds source_label so downstream models always know
--     which eval_set a row came from
--   - keeps reordered flag used in find_01 reorder analysis
--
-- Why union here and not in the mart:
--   - one place to maintain the union logic
--   - intermediate and mart models get a clean single table
--   - source_label lets any downstream model filter to
--     just history (prior) or just final orders (train)
--
-- Note: test set excluded intentionally
--   test has no reordered labels so it cannot be used
--   for any reorder rate analysis
-- ============================================================

with prior as (

    SELECT
        order_id,
        product_id,
        add_to_cart_order,
        reordered,
        'prior' AS source_label
    FROM
        {{ source('instacart', 'order_products_prior') }}

),

train as (

    SELECT
        order_id,
        product_id,
        add_to_cart_order,
        reordered,
        'train' AS source_label
    FROM
        {{ source('instacart', 'order_products_train') }}

),

-- ------------------------------------------------------------
-- UNION PRIOR + TRAIN
-- confirmed in disc_02: prior = 3.2M orders, train = 131K
-- combined total: ~33.8M order-product rows
-- ------------------------------------------------------------

unioned as (

    SELECT * FROM prior

    UNION ALL

    SELECT * FROM train

)

SELECT
    *
FROM
    unioned