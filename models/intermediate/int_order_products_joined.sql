-- ============================================================
-- int_order_products_joined.sql
-- Intermediate model: enriched order-product records
-- Grain: 1 row per product per order
--
-- What this model does:
--   - joins stg_order_products to stg_products, stg_aisles,
--     and stg_departments in one place
--   - produces a single enriched table reused by both:
--       fct_orders   (order-level metrics)
--       dim_products (product catalog with reorder signal)
--
-- Why intermediate and not just join in the mart:
--   - without this model the same 3-way join would live in
--     two separate mart files and drift over time
--   - one model, one test, two consumers
--   - if a department name ever changes, fix it here only
--
-- What this model does NOT do:
--   - no aggregations yet (that happens in the marts)
--   - no filtering by eval_set or source_label
--     downstream models decide what to filter
-- ============================================================

with order_products as (

    -- pulling from staging, not raw
    -- stg_order_products already combined prior + train
    -- and added source_label for downstream filtering
    SELECT
        order_id,
        product_id,
        add_to_cart_order,
        reordered,
        source_label
    FROM
        {{ ref('stg_order_products') }}

),

products as (

    SELECT
        product_id,
        product_name,
        aisle_id,
        department_id
    FROM
        {{ ref('stg_products') }}

),

aisles as (

    SELECT
        aisle_id,
        aisle
    FROM
        {{ ref('stg_aisles') }}

),

departments as (

    SELECT
        department_id,
        department
    FROM
        {{ ref('stg_departments') }}

),

-- ------------------------------------------------------------
-- JOIN EVERYTHING TOGETHER
-- order_products is the base (left side)
-- products, aisles, departments are all lookup enrichment
-- all joins are inner: every product_id should have a match
-- if a join fails here it means a referential integrity issue
-- in the raw data worth flagging
-- ------------------------------------------------------------

joined as (

    SELECT

        -- keys
        order_products.order_id,
        order_products.product_id,

        -- product details
        products.product_name,

        -- aisle details
        -- find_02 will use aisle for granular reorder analysis
        aisles.aisle_id,
        aisles.aisle,

        -- department details
        -- find_01 confirmed dairy eggs + produce top reorder depts
        departments.department_id,
        departments.department,

        -- order behavior
        order_products.add_to_cart_order,
        order_products.reordered,
        order_products.source_label

    FROM
        order_products
    JOIN
        products
        ON order_products.product_id = products.product_id
    JOIN
        aisles
        ON products.aisle_id = aisles.aisle_id
    JOIN
        departments
        ON products.department_id = departments.department_id

)

SELECT
    *
FROM
    joined