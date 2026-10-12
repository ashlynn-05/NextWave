-- NextWave: Section B: Customer segmentation (RFM)
-- Source: MIS384 Assignment 2 report, Appendix 2
-- Dialect: Google BigQuery Standard SQL
--
-- Table references point at the original BigQuery project/dataset used for the
-- assignment. Replace them with your own `project.dataset` before running.

-- B1. Build customer-level summary table
-- Joins confirmed transaction behaviour with click engagement at the individual user level. LEFT JOIN retains all transacting customers regardless of click activity.
CREATE OR REPLACE TABLE `leafy-clone-489205-d4.MIS384_A2_CleanedData.customer_level` AS WITH transaction_summary AS
  (SELECT user_id,
          COUNT(DISTINCT order_id) AS frequency,
          ROUND(SUM(item_total), 2) AS total_spend,
          ROUND(AVG(total_amount), 2) AS avg_order_value,
          MAX(DATE(order_date_only)) AS last_purchase_date
   FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned`
   WHERE LOWER(order_status) IN ('completed',
                                 'shipped')
   GROUP BY user_id),
                                                                                             click_summary AS
  (SELECT user_id,
          COUNT(*) AS total_clicks,
          COUNTIF(click_type = 'view') AS view_clicks,
          COUNTIF(click_type = 'cart') AS cart_clicks,
          COUNTIF(click_type = 'purchase') AS purchase_clicks,
          COUNTIF(campaign_active = 1) AS campaign_clicks,
          COUNTIF(campaign_triggered_click = 1) AS triggered_clicks
   FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Clicks_cleaned`
   GROUP BY user_id)
SELECT t.user_id,
       t.frequency,
       t.total_spend,
       t.avg_order_value,
       DATE_DIFF(CURRENT_DATE(), t.last_purchase_date, DAY) AS recency_days,
       IFNULL(c.total_clicks, 0) AS total_clicks,
       IFNULL(c.view_clicks, 0) AS view_clicks,
       IFNULL(c.cart_clicks, 0) AS cart_clicks,
       IFNULL(c.purchase_clicks, 0) AS purchase_clicks,
       IFNULL(c.campaign_clicks, 0) AS campaign_clicks,
       IFNULL(c.triggered_clicks, 0) AS triggered_clicks
FROM transaction_summary t
LEFT JOIN click_summary c ON t.user_id = c.user_id;

-- B2. RFM scoring and segment classification
-- NTILE(5) on recency_days DESC: fewer days = higher score (more recent).
-- NTILE(5) on frequency and total_spend ASC: higher values = higher score.
-- CASE is priority-ordered: Champions evaluated first (strictest criteria).
CREATE OR REPLACE TABLE `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments` AS WITH scores AS
  (SELECT *,
          NTILE(5) OVER (
                         ORDER BY recency_days DESC) AS r_score,
          NTILE(5) OVER (
                         ORDER BY frequency ASC) AS f_score,
          NTILE(5) OVER (
                         ORDER BY total_spend ASC) AS m_score
   FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.customer_level`)
SELECT *,
       r_score + f_score + m_score AS rfm_score,
       CASE
           WHEN r_score >= 4
                AND f_score >= 4
                AND m_score >= 4 THEN 'Champions'
           WHEN f_score >= 4
                AND m_score >= 3 THEN 'Loyal High-Value'
           WHEN m_score >= 4 THEN 'Big Spenders'
           WHEN r_score <= 2
                AND (f_score >= 4
                     OR m_score >= 4) THEN 'At Risk'
           WHEN r_score >= 4
                AND frequency = 1 THEN 'New Customers'
           ELSE 'Low / Medium Value'
       END AS rfm_segment
FROM scores;

-- B3. RFM segment summary - primary segmentation output
-- Reports segment size, commercial value, recency,and campaign engagement per segment.
SELECT rfm_segment,
       COUNT(*) AS customer_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_base,
       ROUND(AVG(total_spend), 2) AS avg_spend,
       ROUND(AVG(frequency), 2) AS avg_orders,
       ROUND(AVG(recency_days), 0) AS avg_recency_days,
       ROUND(AVG(campaign_clicks), 2) AS avg_campaign_clicks,
       ROUND(AVG(triggered_clicks), 2) AS avg_triggered_clicks,
       ROUND(AVG(cart_clicks), 2) AS avg_cart_clicks
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments`
GROUP BY rfm_segment
ORDER BY avg_spend DESC;

-- B4. Purchase frequency distribution
-- Establishes the scale of the one-time buyer problem
-- that motivates the retention-focused recommendations
SELECT frequency_bucket,
       COUNT(*) AS customer_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM
  (SELECT user_id,
          COUNT(DISTINCT order_id) AS order_count,
          CASE
              WHEN COUNT(DISTINCT order_id) = 1 THEN '1 order'
              WHEN COUNT(DISTINCT order_id) BETWEEN 2 AND 3 THEN '2–3 orders'
              WHEN COUNT(DISTINCT order_id) BETWEEN 4 AND 6 THEN '4–6 orders'
              ELSE '7+ orders'
          END AS frequency_bucket
   FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned`
   WHERE LOWER(order_status) IN ('completed',
                                 'shipped')
   GROUP BY user_id)
GROUP BY frequency_bucket
ORDER BY MIN(order_count);

-- B5. Monthly order volume, revenue and active customers
-- Identifies seasonality patterns and campaign-correlated demand fluctuations across the 23-month window
SELECT FORMAT_DATE('%Y-%m', DATE(order_date_only)) AS month,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(item_total), 2) AS total_revenue,
       COUNT(DISTINCT user_id) AS active_customers,
       ROUND(AVG(total_amount), 2) AS avg_order_value
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned`
WHERE LOWER(order_status) IN ('completed',
                              'shipped')
GROUP BY month
ORDER BY month;

-- B6. Value tier binary comparison
-- Consolidates six segments into five strategic tiers
-- for executive-level narrative and recommendation anchoring
SELECT CASE
           WHEN rfm_segment IN ('Champions',
                                'Loyal High-Value') THEN '1. High-Value (Champions + Loyal)'
           WHEN rfm_segment = 'At Risk' THEN '2. At Risk'
           WHEN rfm_segment = 'Big Spenders' THEN '3. Big Spenders'
           WHEN rfm_segment = 'New Customers' THEN '4. New Customers'
           ELSE '5. Low / Medium Value'
       END AS value_tier,
       COUNT(*) AS customers,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_base,
       ROUND(AVG(total_spend), 2) AS avg_spend,
       ROUND(AVG(frequency), 2) AS avg_orders,
       ROUND(AVG(recency_days), 0) AS avg_recency_days,
       ROUND(AVG(campaign_clicks), 2) AS avg_campaign_clicks,
       ROUND(AVG(triggered_clicks), 2) AS avg_triggered_clicks,
       ROUND(SAFE_DIVIDE(AVG(triggered_clicks), AVG(campaign_clicks)) * 100, 2) AS triggered_pct_of_campaign_clicks,
       ROUND(SAFE_DIVIDE(AVG(cart_clicks), AVG(view_clicks)) * 100, 2) AS cart_rate_pct
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments`
GROUP BY value_tier
ORDER BY value_tier;

-- B7. Spend by gender
-- Identifies whether spending patterns differ across gender groups
-- to inform campaign personalisation recommendations
SELECT gender,
       COUNT(DISTINCT user_id) AS customers,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(item_total), 2) AS total_revenue,
       ROUND(AVG(total_amount), 2) AS avg_order_value
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned`
WHERE LOWER(order_status) IN ('completed',
                              'shipped')
  AND gender IS NOT NULL
GROUP BY gender
ORDER BY total_revenue DESC;
