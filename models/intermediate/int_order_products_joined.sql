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
--   written without table aliases due to a dbt Fusion
--   alias resolution bug with ref() models in joins
--   functionally identical to aliased version
-- ============================================================

{{ config(materialized='table') }}

with order_products as (

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

joined as (

    SELECT
        order_products.order_id,
        order_products.product_id,
        products.product_name,
        aisles.aisle_id,
        aisles.aisle,
        departments.department_id,
        departments.department,
        order_products.add_to_cart_order,
        order_products.reordered,
        order_products.source_label
    FROM
        order_products
    INNER JOIN
        products
        ON order_products.product_id = products.product_id
    INNER JOIN
        aisles
        ON products.aisle_id = aisles.aisle_id
    INNER JOIN
        departments
        ON products.department_id = departments.department_id

)

SELECT
    *
FROM
    joined