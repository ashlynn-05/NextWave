-- NextWave: Section E: Segment x campaign crossover
-- Source: MIS384 Assignment 2 report, Appendix 2
-- Dialect: Google BigQuery Standard SQL
--
-- Table references point at the original BigQuery project/dataset used for the
-- assignment. Replace them with your own `project.dataset` before running.

-- E1. Campaign engagement metrics by RFM segment
-- Cross-references each segment's commercial value (avg_spend)
-- against campaign responsiveness (triggered_pct)
-- and cart conversion (cart_rate_pct)
SELECT rfm_segment,
       COUNT(*) AS customers,
       ROUND(AVG(total_spend), 2) AS avg_spend,
       ROUND(AVG(total_clicks), 2) AS avg_total_clicks,
       ROUND(AVG(campaign_clicks), 2) AS avg_campaign_clicks,
       ROUND(AVG(triggered_clicks), 2) AS avg_triggered_clicks,
       ROUND(AVG(cart_clicks), 2) AS avg_cart_clicks,
       ROUND(SAFE_DIVIDE(AVG(triggered_clicks), AVG(campaign_clicks)) * 100, 2) AS triggered_pct_of_campaign_clicks,
       ROUND(SAFE_DIVIDE(AVG(cart_clicks), AVG(view_clicks)) * 100, 2) AS cart_rate_pct
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments`
GROUP BY rfm_segment
ORDER BY avg_spend DESC;

-- E2. Value tier campaign responsiveness - final consolidation
-- Directly anchors all recommendations in the report.
-- Quantifies the targeting gap between high-value
-- and low-value customer segments.
SELECT CASE
           WHEN rfm_segment IN ('Champions',
                                'Loyal High-Value') THEN '1. High-Value (Champions + Loyal)'
           WHEN rfm_segment = 'At Risk' THEN '2. At Risk'
           WHEN rfm_segment = 'Big Spenders' THEN '3. Big Spenders'
           WHEN rfm_segment = 'New Customers' THEN '4. New Customers'
           ELSE '5. Low / Medium Value'
       END AS value_tier,
       COUNT(*) AS customers,
       ROUND(AVG(total_spend), 2) AS avg_spend,
       ROUND(AVG(campaign_clicks), 2) AS avg_campaign_clicks,
       ROUND(AVG(triggered_clicks), 2) AS avg_triggered_clicks,
       ROUND(SAFE_DIVIDE(AVG(triggered_clicks), AVG(campaign_clicks)) * 100, 2) AS triggered_pct_of_campaign_clicks,
       ROUND(SAFE_DIVIDE(AVG(cart_clicks), AVG(view_clicks)) * 100, 2) AS cart_rate_pct
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments`
GROUP BY value_tier
ORDER BY value_tier;

-- E3. Category revenue: campaign period vs non-campaign
-- Uses date-matched join between click timestamps and order dates
-- to identify transactions occurring on days when the same user
-- had a recorded click during a campaign window.
-- Note: proximity-based attribution - interpret directionally.
SELECT t.category,
       CASE
           WHEN cl.campaign_active = 1 THEN 'Campaign period'
           ELSE 'Non-campaign period'
       END AS period,
       COUNT(DISTINCT t.order_id) AS orders,
       ROUND(SUM(t.item_total), 2) AS total_revenue,
       ROUND(AVG(t.total_amount), 2) AS avg_order_value
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned` t
INNER JOIN
  (SELECT DISTINCT user_id,
                   DATE(click_timestamp) AS click_date,
                   campaign_active
   FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Clicks_cleaned`) cl ON t.user_id = cl.user_id
AND DATE(order_date_only) = cl.click_date
WHERE LOWER(t.order_status) IN ('completed',
                                'shipped')
GROUP BY t.category,
         cl.campaign_active
ORDER BY t.category,
         cl.campaign_active DESC;
