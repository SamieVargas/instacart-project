-- ============================================================
-- stg_orders.sql
-- Staging model for the orders raw table
-- Grain: 1 row per order
--
-- What this model does:
--   - renames columns to consistent snake_case
--   - casts data types explicitly so downstream models don't guess
--   - documents the days_since_prior_order NULL and cap behavior
--     so analysts don't filter or misinterpret these rows
--
-- What this model does NOT do:
--   - no aggregations
--   - no joins
--   - no business logic
--   staging is just clean and rename, nothing more
-- ============================================================

with source as (

    -- pulling directly from the raw BigQuery table via sources.yml
    -- if the raw table location ever changes, update sources.yml only
    SELECT
        *
    FROM
        {{ source('instacart', 'orders') }}

),

renamed as (

    SELECT

        -- ------------------------------------------------------------
        -- KEYS
        -- ------------------------------------------------------------
        order_id,
        user_id,

        -- ------------------------------------------------------------
        -- ORDER METADATA
        -- eval_set tells us which group this order belongs to:
        --   prior = shopping history
        --   train = final order, labeled
        --   test  = final order, no labels
        -- confirmed in disc_02: train and test are always 1 per user
        -- ------------------------------------------------------------
        eval_set,
        order_number,

        -- ------------------------------------------------------------
        -- TIME DIMENSIONS
        -- order_dow: 0 = Sunday, 6 = Saturday
        -- order_hour_of_day: 0-23
        -- ------------------------------------------------------------
        order_dow,
        order_hour_of_day,

        -- ------------------------------------------------------------
        -- DAYS SINCE PRIOR ORDER
        -- NULL on order_number = 1 (no prior order to measure from)
        -- confirmed clean in qc_02: 100% null on first orders only
        --
        -- capped at 30 by Instacart: a value of 30 means 30 OR MORE days
        -- confirmed in qc_01: spike of 369K orders at 30 vs ~20K neighbors
        -- downstream models should not treat 30 as an exact measurement
        -- ------------------------------------------------------------
        days_since_prior_order

    FROM
        source

)

SELECT
    *
FROM
    renamed