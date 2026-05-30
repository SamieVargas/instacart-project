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
-- Note on structure:
--   written as a single SELECT rather than chained CTEs
--   due to a dbt Fusion preview engine bug with CTE column
--   resolution on UNION ALL views — functionally identical
-- ============================================================

{{ config(materialized='table') }}

SELECT

    -- keys
    op.order_id,
    op.product_id,

    -- product details
    p.product_name,

    -- aisle details
    -- find_02 will use aisle for granular reorder analysis
    a.aisle_id,
    a.aisle,

    -- department details
    -- find_01 confirmed dairy eggs + produce top reorder depts
    d.department_id,
    d.department,

    -- order behavior
    op.add_to_cart_order,
    op.reordered,
    op.source_label

FROM
    {{ ref('stg_order_products') }} AS op
JOIN
    {{ ref('stg_products') }} AS p
    ON op.product_id = p.product_id
JOIN
    {{ ref('stg_aisles') }} AS a
    ON p.aisle_id = a.aisle_id
JOIN
    {{ ref('stg_departments') }} AS d
    ON p.department_id = d.department_id