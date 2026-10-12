-- NextWave: Section A: Data scope and verification
-- Source: MIS384 Assignment 2 report, Appendix 2
-- Dialect: Google BigQuery Standard SQL
--
-- Table references point at the original BigQuery project/dataset used for the
-- assignment. Replace them with your own `project.dataset` before running.

-- A1. Record counts across all three source tables
SELECT 'Transactions' AS table_name,
       COUNT(*) AS row_count
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned`
UNION ALL
SELECT 'Reviews',
       COUNT(*)
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Reviews_cleaned`
UNION ALL
SELECT 'Clicks',
       COUNT(*)
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Clicks_cleaned`;

-- A2. Transaction date range, analysis window,
-- unique customer and order counts
SELECT MIN(DATE(order_date_only)) AS earliest_order,
       MAX(DATE(order_date_only)) AS latest_order,
       DATE_DIFF(MAX(DATE(order_date_only)), MIN(DATE(order_date_only)), MONTH) AS analysis_window_months,
       COUNT(DISTINCT user_id) AS unique_customers,
       COUNT(DISTINCT order_id) AS unique_orders
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned`
WHERE LOWER(order_status) IN ('completed',
                              'shipped');
