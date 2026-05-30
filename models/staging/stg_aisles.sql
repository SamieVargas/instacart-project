-- ============================================================
-- stg_aisles.sql
-- Staging model for the aisles raw table
-- Grain: 1 row per aisle
--
-- What this model does:
--   - passthrough clean with consistent column naming
--   - 134 aisles total
--   - used in int_order_products_joined to enrich products
--     with aisle names for dim_products and fct_orders
-- ============================================================

with source as (

    SELECT
        *
    FROM
        {{ source('instacart', 'aisles') }}

),

renamed as (

    SELECT
        aisle_id,
        aisle
    FROM
        source

)

SELECT
    *
FROM
    renamed