-- ============================================================
-- INSTACART DATA DISCOVERY
-- Purpose: Understand the raw tables before building dbt models
-- Run each section independently in the BigQuery console
-- ============================================================


-- ------------------------------------------------------------
-- 1. TABLE ROW COUNTS
-- Confirm all 6 tables loaded correctly from Kaggle via bq CLI
-- Expected: ~3.4M in order_products_prior, ~131K in order_products_train
-- Asset:   assets/disc_01_table_row_counts.png
-- ------------------------------------------------------------

SELECT 
  'orders' AS table_name, 
  COUNT(*) AS row_count 
FROM 
  instacart_raw.orders

UNION ALL

SELECT 
  'products' AS table_name, 
  COUNT(*) AS row_count 
FROM 
  instacart_raw.products

UNION ALL

SELECT 
  'order_products_prior' AS table_name, 
  COUNT(*) AS row_count 
FROM 
  instacart_raw.order_products_prior

UNION ALL

SELECT 
  'order_products_train' AS table_name, 
  COUNT(*) AS row_count 
FROM 
  instacart_raw.order_products_train

UNION ALL

SELECT 
  'aisles' AS table_name, 
  COUNT(*) AS row_count 
FROM 
  instacart_raw.aisles

UNION ALL

SELECT 
  'departments' AS table_name, 
  COUNT(*) AS row_count 
FROM 
  instacart_raw.departments;


-- ------------------------------------------------------------
-- 2. UNDERSTANDING eval_set
-- Instacart split users into 3 groups for an ML competition:
--   prior = all orders BEFORE a user's most recent one (shopping history)
--   train = the most recent order for users in the training group
--   test  = the most recent order for users in the test group (no product labels)
--
-- Key insight: train and test will show ~1 order per user
-- prior will show many orders per user --> it IS the history
-- This is why prior and train ship as separate files and why
-- blindly UNIONing them without a source label breaks analysis
-- ------------------------------------------------------------

SELECT
  eval_set,
  COUNT(*) AS order_count,
  COUNT(DISTINCT user_id) AS user_count,
  ROUND(COUNT(*) / COUNT(DISTINCT user_id), 1) AS orders_per_user
FROM 
  instacart_raw.orders
GROUP BY 
  eval_set
ORDER BY 
  order_count DESC;


-- ------------------------------------------------------------
-- 3. COMBINING PRIOR + TRAIN WITH SOURCE LABEL
-- This is the pattern used in stg_order_products.sql
-- Adding source_label preserves which eval_set each row came from
-- so downstream models can filter to history vs. final order
-- ------------------------------------------------------------

SELECT
  *,
  'prior' AS source_label
FROM 
  instacart_raw.order_products_prior

UNION ALL

SELECT
  *,
  'train' AS source_label
FROM 
  instacart_raw.order_products_train;

-- Then running the second SQL query again to see the labeled eval_set split 
-- Asset:   assets/disc_02_eval_set_split.png

-- ============================================================
-- QC_01: DAYS SINCE PRIOR ORDER CAP
-- Purpose: Identify the 30-day ceiling in 'days_since_prior_order'
-- Asset:   assets/qc_01_days_since_prior_cap.png
-- ============================================================

-- ------------------------------------------------------------
-- WHAT WE ARE LOOKING FOR:
-- Instacart caps days_since_prior_order at 30
-- A value of 30 does NOT mean exactly 30 days, it means 30 OR MORE
-- ------------------------------------------------------------

SELECT
  days_since_prior_order,
  COUNT(*) AS order_count
FROM
  instacart_raw.orders
GROUP BY
  days_since_prior_order
ORDER BY
  days_since_prior_order ASC;

-- ============================================================
-- QC_02: NULL CHECK ON FIRST ORDERS
-- Purpose: Confirm NULLs in 'days_since_prior_order' only appear
--          on a user's very first order ('order_number' = 1)
-- Asset:   assets/qc_02_null_check_first_orders.png
-- ============================================================

-- ------------------------------------------------------------
-- WHAT WE ARE LOOKING FOR
-- 'days_since_prior_order' should be NULL when 'order_number' = 1
-- because there is no prior order to measure from
-- If NULLs appear on 'order_number' > 1 that is a data quality problem
-- A clean result looks like: null_count drops to 0 after row 1
-- ------------------------------------------------------------

SELECT
  order_number,
  COUNTIF(days_since_prior_order IS NULL) AS null_count,
  COUNT(*) AS total_orders,
  ROUND(COUNTIF(days_since_prior_order IS NULL) / COUNT(*) * 100, 1) AS null_pct
FROM
  instacart_raw.orders
GROUP BY
  order_number
ORDER BY
  order_number ASC
LIMIT
  10;

-- ============================================================
-- FIND_01: REORDER RATE BY DEPARTMENT
-- Purpose: Identify which product departments have the highest
--          reorder rates across all prior orders
-- Asset:   assets/find_01_reorder_rate_by_dept.png
-- ============================================================

-- ------------------------------------------------------------
-- WHAT WE ARE LOOKING FOR
-- 'reorder_rate' = proportion of order lines that are reorders
-- A high reorder rate means users are habitually buying from
-- that department, and not discovering new products
-- This is the first signal of where habit vs. exploration lives
-- in the Instacart basket
-- ------------------------------------------------------------

SELECT
  d.department,
  COUNT(*) AS total_order_lines,
  COUNTIF(op.reordered = 1) AS reorders,
  ROUND(COUNTIF(op.reordered = 1) / COUNT(*), 3) AS reorder_rate
FROM
  instacart_raw.order_products_prior AS op
JOIN
  instacart_raw.products AS p
  ON op.product_id = p.product_id
JOIN
  instacart_raw.departments AS d
  ON p.department_id = d.department_id
GROUP BY
  d.department
ORDER BY
  reorder_rate DESC;