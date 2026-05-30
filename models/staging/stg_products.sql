-- ============================================================
-- stg_products.sql
-- Staging model for the products raw table
-- Grain: 1 row per product
--
-- What this model does:
--   - renames columns to consistent snake_case
--   - keeps foreign keys to aisles and departments
--     for joining in int_order_products_joined
--
-- What this model does NOT do:
--   - no joins to aisles or departments yet (that happens in intermediate)
--   - no aggregations, no business logic
-- ============================================================

with source as (

    SELECT
        *
    FROM
        {{ source('instacart', 'products') }}

),

renamed as (

    SELECT

        -- ------------------------------------------------------------
        -- KEYS
        -- ------------------------------------------------------------
        product_id,

        -- foreign keys used in int_order_products_joined
        -- to enrich with aisle and department names
        aisle_id,
        department_id,

        -- ------------------------------------------------------------
        -- PRODUCT ATTRIBUTES
        -- ------------------------------------------------------------
        product_name

    FROM
        source

)

SELECT
    *
FROM
    renamed