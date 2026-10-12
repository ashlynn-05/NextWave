-- NextWave: Section C: Campaign effectiveness
-- Source: MIS384 Assignment 2 report, Appendix 2
-- Dialect: Google BigQuery Standard SQL
--
-- Table references point at the original BigQuery project/dataset used for the
-- assignment. Replace them with your own `project.dataset` before running.

-- C1. Build funnel table - click-type breakdown by campaign status and type
CREATE OR REPLACE TABLE `leafy-clone-489205-d4.MIS384_A2_CleanedData.funnel_table` AS
SELECT campaign_active,
       campaign_type_active AS campaign_type,
       COUNTIF(click_type = 'view') AS views,
       COUNTIF(click_type = 'cart') AS carts,
       COUNTIF(click_type = 'purchase') AS purchase_clicks,
       SAFE_DIVIDE(COUNTIF(click_type = 'cart'), COUNTIF(click_type = 'view')) AS view_to_cart_rate,
       SAFE_DIVIDE(COUNTIF(click_type = 'purchase'), COUNTIF(click_type = 'cart')) AS cart_to_purchase_rate,
       SAFE_DIVIDE(COUNTIF(click_type = 'purchase'), COUNTIF(click_type = 'view')) AS view_to_purchase_rate
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Clicks_cleaned`
GROUP BY campaign_active,
         campaign_type_active;

-- C2. Build campaign-level table - per campaign performance
-- Enables per-campaign ranking and triggered click
-- attribution analysis in C4 and C5
CREATE OR REPLACE TABLE `leafy-clone-489205-d4.MIS384_A2_CleanedData.campaign_table` AS
SELECT campaign_active,
       campaign_id_active AS campaign_id,
       campaign_type_active AS campaign_type,
       COUNT(*) AS total_clicks,
       COUNTIF(click_type = 'view') AS views,
       COUNTIF(click_type = 'cart') AS carts,
       COUNTIF(click_type = 'purchase') AS purchase_clicks,
       COUNTIF(campaign_triggered_click = 1) AS triggered_clicks,
       SAFE_DIVIDE(COUNTIF(click_type = 'cart'), COUNTIF(click_type = 'view')) AS view_to_cart_rate,
       SAFE_DIVIDE(COUNTIF(click_type = 'purchase'), COUNTIF(click_type = 'cart')) AS cart_to_purchase_rate,
       SAFE_DIVIDE(COUNTIF(campaign_triggered_click = 1), COUNT(*)) AS triggered_click_rate
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Clicks_cleaned`
GROUP BY campaign_active,
         campaign_id_active,
         campaign_type_active;

-- C3. Overall funnel: campaign active vs non-campaign
-- Primary campaign effectiveness result.
SELECT CASE
           WHEN campaign_active = 1 THEN 'During campaign'
           ELSE 'Non-campaign'
       END AS period,
       SUM(views) AS total_views,
       SUM(carts) AS total_carts,
       SUM(purchase_clicks) AS total_purchases,
       ROUND(SAFE_DIVIDE(SUM(carts), SUM(views)) * 100, 2) AS view_to_cart_pct,
       ROUND(SAFE_DIVIDE(SUM(purchase_clicks), SUM(carts)) * 100, 2) AS cart_to_purchase_pct,
       ROUND(SAFE_DIVIDE(SUM(purchase_clicks), SUM(views)) * 100, 2) AS overall_conversion_pct
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.funnel_table`
GROUP BY campaign_active
ORDER BY campaign_active DESC;

-- C4. Funnel performance by campaign type
-- Identifies which campaign strategy produces the strongest
-- conversion and which underperforms relative to baseline
SELECT campaign_type,
       SUM(views) AS total_views,
       SUM(carts) AS total_carts,
       SUM(purchase_clicks) AS total_purchases,
       ROUND(SAFE_DIVIDE(SUM(carts), SUM(views)) * 100, 2) AS view_to_cart_pct,
       ROUND(SAFE_DIVIDE(SUM(purchase_clicks), SUM(carts)) * 100, 2) AS cart_to_purchase_pct,
       ROUND(SAFE_DIVIDE(SUM(purchase_clicks), SUM(views)) * 100, 2) AS overall_conversion_pct
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.funnel_table`
WHERE campaign_active = 1
GROUP BY campaign_type
ORDER BY overall_conversion_pct DESC;

-- C5. Triggered vs total clicks by campaign period
-- Distinguishes campaign-attributed clicks (within attribution
-- window following campaign exposure) from ambient browsing
-- during an active campaign window
SELECT CASE
           WHEN campaign_active = 1 THEN 'During campaign'
           ELSE 'Non-campaign'
       END AS period,
       SUM(total_clicks) AS total_clicks,
       SUM(triggered_clicks) AS triggered_clicks,
       ROUND(SAFE_DIVIDE(SUM(triggered_clicks), SUM(total_clicks)) * 100, 2) AS triggered_pct,
       ROUND(SAFE_DIVIDE(SUM(carts), SUM(views)) * 100, 2) AS view_to_cart_pct,
       ROUND(SAFE_DIVIDE(SUM(purchase_clicks), SUM(carts)) * 100, 2) AS cart_to_purchase_pct
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.campaign_table`
GROUP BY campaign_active
ORDER BY campaign_active DESC;

-- C6. Individual campaign performance ranked
-- by cart-to-purchase conversion rate
-- Enables identification of best and worst performing
-- individual campaigns within each type
SELECT campaign_id,
       campaign_type,
       total_clicks,
       views,
       carts,
       purchase_clicks,
       triggered_clicks,
       ROUND(view_to_cart_rate * 100, 2) AS view_to_cart_pct,
       ROUND(cart_to_purchase_rate * 100, 2) AS cart_to_purchase_pct,
       ROUND(triggered_click_rate * 100, 2) AS triggered_click_pct
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.campaign_table`
WHERE campaign_active = 1
ORDER BY cart_to_purchase_rate DESC;
