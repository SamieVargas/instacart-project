-- ============================================================
-- dim_products.sql
-- Mart model: product dimension with reorder signal
-- Grain: 1 row per product
--
-- What this model does:
--   - pulls the full product catalog from int_order_products_joined
--   - aggregates order-product behavior to product grain
--   - calculates reorder rate per product across all prior orders
--   - surfaces the find_01 finding at product level instead of dept
--
-- Answers:
--   - which individual products have the highest reorder rates?
--   - which aisle and department does each product belong to?
--   - how many times has each product been ordered total?
--
-- Grain check:
--   one row per product_id — confirmed by unique test in schema.yml
-- ============================================================

with product_orders as (

    -- using int_order_products_joined, not raw
    -- already has aisle and department names joined in
    -- filtering to prior only: train set is the final order
    -- and we want behavioral history, not the outcome label
    SELECT
        product_id,
        product_name,
        aisle_id,
        aisle,
        department_id,
        department,
        reordered
    FROM
        {{ ref('int_order_products_joined') }}
    WHERE
        source_label = 'prior'

),

-- ------------------------------------------------------------
-- AGGREGATE TO PRODUCT GRAIN
-- collapse all order lines to 1 row per product
-- reorder_rate = what proportion of all orders for this
-- product were reorders (not first-time purchases)
-- total_orders = how many times this product was ordered
-- ------------------------------------------------------------

product_aggregates as (

    SELECT
        product_id,
        product_name,
        aisle_id,
        aisle,
        department_id,
        department,
        COUNT(*)                                        AS total_orders,
        COUNTIF(reordered = 1)                          AS total_reorders,
        ROUND(COUNTIF(reordered = 1) / COUNT(*), 3)    AS reorder_rate
    FROM
        product_orders
    GROUP BY
        product_id,
        product_name,
        aisle_id,
        aisle,
        department_id,
        department

)

SELECT
    product_id,
    product_name,
    aisle_id,
    aisle,
    department_id,
    department,
    total_orders,
    total_reorders,

    -- ------------------------------------------------------------
    -- REORDER RATE
    -- find_01 confirmed at dept level: dairy eggs 0.67, produce 0.65
    -- this column surfaces that same signal at product level
    -- high reorder_rate = habitual purchase (staple)
    -- low reorder_rate = discovery or impulse purchase
    -- ------------------------------------------------------------
    reorder_rate
FROM
    product_aggregates
ORDER BY
    reorder_rate DESC