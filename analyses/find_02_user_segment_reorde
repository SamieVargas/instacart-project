-- ============================================================
-- find_02_user_segment_reorder.sql
-- Purpose: Segment users by order history depth and compare
--          reorder behavior across segments
-- Asset:   assets/find_02_reorder_rate_by_user_segment.png
--
-- This query answers the core thesis of the project:
--   when does reorder behavior become reliable enough to trust?
--
-- Finding: reorder ratio grows from 0.221 (new users, 1-3 orders)
-- to 0.670 (veterans, 20+ orders) — a 3x difference
-- Any ML reorder prediction model trained on all users equally
-- is being diluted by new user noise
-- Data only becomes reliable for reorder prediction at the
-- Established tier: 10+ orders
--
-- Source: dbt_svargas.dim_users
-- Run in BigQuery console or connect to Looker Studio as a view
-- ============================================================

-- ------------------------------------------------------------
-- TO CREATE AS A VIEW IN BIGQUERY:
-- Run the full statement below including CREATE OR REPLACE VIEW
-- This makes it available as a data source in Looker Studio
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW
    `instacart-497823.dbt_svargas.vw_user_segment_reorder`
AS (

    SELECT

        -- ------------------------------------------------------------
        -- USER SEGMENT
        -- bucketing users by total prior orders places them into
        -- behavioral cohorts based on platform experience depth
        -- new users are still discovering — not yet habitual
        -- veteran users are on autopilot — highly predictable
        -- ------------------------------------------------------------
        CASE
            WHEN total_prior_orders BETWEEN 1 AND 3   THEN '1. New (1-3 orders)'
            WHEN total_prior_orders BETWEEN 4 AND 9   THEN '2. Growing (4-9 orders)'
            WHEN total_prior_orders BETWEEN 10 AND 19 THEN '3. Established (10-19 orders)'
            WHEN total_prior_orders >= 20              THEN '4. Veteran (20+ orders)'
        END                                         AS user_segment,

        COUNT(*)                                    AS user_count,

        -- ------------------------------------------------------------
        -- AVG REORDER RATIO
        -- the headline metric: how much of each order is autopilot
        -- low = still exploring, high = habitual and predictable
        -- this is where the ML reliability threshold lives
        -- ------------------------------------------------------------
        ROUND(AVG(avg_reorder_ratio), 3)            AS avg_reorder_ratio,

        ROUND(AVG(avg_order_size), 1)               AS avg_order_size,

        -- percent of users in this segment who have a capped order
        -- higher in veteran users expected — more orders = more
        -- chances of a 30+ day gap appearing in history
        ROUND(AVG(has_capped_order) * 100, 1)       AS pct_with_capped_order

    FROM
        `instacart-497823.dbt_svargas.dim_users`
    WHERE
        total_prior_orders > 0
    GROUP BY
        user_segment
    ORDER BY
        user_segment ASC

)