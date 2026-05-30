-- ============================================================
-- dim_users.sql
-- Mart model: user-level behavior aggregates
-- Grain: 1 row per user
--
-- What this model does:
--   - aggregates order and product behavior to user grain
--   - calculates total orders, avg order size, reorder tendency
--   - flags users whose most recent order is in the train set
--     (these are the users whose final order is labeled)
--
-- Answers:
--   - how many orders has each user placed?
--   - what is each user's average order size?
--   - what proportion of each user's items are reorders?
--   - which users are in the train set (have a labeled final order)?
--
-- Grain check:
--   one row per user_id — confirmed by unique test in schema.yml
-- ============================================================

with orders as (

    SELECT
        order_id,
        user_id,
        eval_set,
        order_number,
        days_since_prior_order,
        order_size,
        reorder_ratio
    FROM
        {{ ref('fct_orders') }}

),

-- ------------------------------------------------------------
-- USER-LEVEL AGGREGATES
-- collapsing all orders to 1 row per user
-- total_orders = how many orders this user placed in prior set
-- avg_order_size = average number of items per order
-- avg_reorder_ratio = how habitual is this user overall
--   0.0 = always buying new items
--   1.0 = always reordering the same items
-- is_train_user = TRUE if this user has a labeled final order
--   useful for filtering to users we can do reorder analysis on
-- ------------------------------------------------------------

user_aggregates as (

    SELECT
        user_id,
        COUNT(
            CASE WHEN eval_set = 'prior' THEN order_id END
        )                                               AS total_prior_orders,
        MAX(order_number)                               AS max_order_number,
        ROUND(AVG(
            CASE WHEN eval_set = 'prior' THEN order_size END
        ), 1)                                           AS avg_order_size,
        ROUND(AVG(
            CASE WHEN eval_set = 'prior' THEN reorder_ratio END
        ), 3)                                           AS avg_reorder_ratio,
        MAX(
            CASE WHEN eval_set = 'prior'
                 AND days_since_prior_order = 30
                 THEN 1 ELSE 0 END
        )                                               AS has_capped_order,

        -- ------------------------------------------------------------
        -- IS TRAIN USER
        -- TRUE if this user has an order in the train eval_set
        -- these are the users whose final order is fully labeled
        -- confirmed in disc_02: 131,209 train users, 1 order each
        -- ------------------------------------------------------------
        MAX(
            CASE WHEN eval_set = 'train' THEN 1 ELSE 0 END
        ) = 1                                           AS is_train_user

    FROM
        orders
    GROUP BY
        user_id

)

SELECT
    user_id,
    total_prior_orders,
    max_order_number,
    avg_order_size,

    -- ------------------------------------------------------------
    -- AVG REORDER RATIO
    -- user-level habit signal
    -- high = habitual shopper restocking the same items
    -- low = explorer or new user still building their basket
    -- this is the user-level version of the find_01 dept finding
    -- ------------------------------------------------------------
    avg_reorder_ratio,
    has_capped_order,
    is_train_user
FROM
    user_aggregates
ORDER BY
    total_prior_orders DESC