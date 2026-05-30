-- ============================================================
-- stg_departments.sql
-- Staging model for the departments raw table
-- Grain: 1 row per department
--
-- What this model does:
--   - passthrough clean with consistent column naming
--   - 21 departments total
--   - used in int_order_products_joined to enrich products
--     with department names
--
-- find_01 finding: dairy eggs (0.67) and produce (0.65) are
-- the top reorder departments — confirmed in exploration phase
-- ============================================================

with source as (

    SELECT
        *
    FROM
        {{ source('instacart', 'departments') }}

),

renamed as (

    SELECT
        department_id,
        department
    FROM
        source

)

SELECT
    *
FROM
    renamed