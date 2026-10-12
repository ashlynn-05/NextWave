-- NextWave: Section D: Product preferences and satisfaction
-- Source: MIS384 Assignment 2 report, Appendix 2
-- Dialect: Google BigQuery Standard SQL
--
-- Table references point at the original BigQuery project/dataset used for the
-- assignment. Replace them with your own `project.dataset` before running.

-- D1. Revenue and average rating by product category
-- Identifies which categories drive commercial value and
-- how satisfaction compares across the product portfolio
SELECT t.category,
       COUNT(DISTINCT t.order_id) AS total_orders,
       ROUND(SUM(t.item_total), 2) AS total_revenue,
       ROUND(AVG(t.item_price), 2) AS avg_unit_price,
       ROUND(AVG(r.rating), 2) AS avg_review_rating,
       COUNT(r.review_id) AS review_count
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned` t
LEFT JOIN `leafy-clone-489205-d4.MIS384_A2_CleanedData.Reviews_cleaned` r ON t.order_id = r.order_id
AND t.product_id = r.product_id
WHERE LOWER(t.order_status) IN ('completed',
                                'shipped')
GROUP BY t.category
ORDER BY total_revenue DESC;

-- D2. Top 5 revenue-generating products per segment
-- Identifies anchor products for High-Value and Mid-Value
-- segments to inform cross-sell and upsell recommendations
SELECT rfm_segment,
       product_name,
       category,
       brand,
       ROUND(SUM(t.item_total), 2) AS total_revenue,
       COUNT(DISTINCT t.order_id) AS orders
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned` t
INNER JOIN `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments` r ON t.user_id = r.user_id
WHERE LOWER(t.order_status) IN ('completed',
                                'shipped')
GROUP BY rfm_segment,
         product_name,
         category,
         brand QUALIFY ROW_NUMBER() OVER (PARTITION BY rfm_segment
                                          ORDER BY SUM(t.item_total) DESC) <= 5
ORDER BY rfm_segment,
         total_revenue DESC;

-- D3. Top brands by revenue per segment
-- Identifies whether brand concentration differs across
-- value segments and where cross-segment brand leverage exists
SELECT r.rfm_segment,
       t.brand,
       ROUND(SUM(t.item_total), 2) AS total_revenue,
       COUNT(DISTINCT t.order_id) AS orders,
       ROUND(AVG(t.item_price), 2) AS avg_unit_price
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned` t
INNER JOIN `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments` r ON t.user_id = r.user_id
WHERE LOWER(t.order_status) IN ('completed',
                                'shipped')
  AND t.brand IS NOT NULL
GROUP BY r.rfm_segment,
         t.brand QUALIFY ROW_NUMBER() OVER (PARTITION BY r.rfm_segment
                                            ORDER BY SUM(t.item_total) DESC) <= 5
ORDER BY r.rfm_segment,
         total_revenue DESC;

-- D4. Category revenue by RFM segment
-- Reveals category concentration differences across segments
-- and identifies where high-value customers concentrate spend
SELECT r.rfm_segment,
       t.category,
       COUNT(DISTINCT t.order_id) AS orders,
       ROUND(SUM(t.item_total), 2) AS total_revenue,
       ROUND(SUM(t.item_total) * 100.0 / SUM(SUM(t.item_total)) OVER (PARTITION BY r.rfm_segment), 2) AS pct_of_segment_revenue,
       ROUND(AVG(t.item_price), 2) AS avg_unit_price
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned` t
INNER JOIN `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments` r ON t.user_id = r.user_id
WHERE LOWER(t.order_status) IN ('completed',
                                'shipped')
GROUP BY r.rfm_segment,
         t.category
ORDER BY r.rfm_segment,
         total_revenue DESC;

-- D5. Category co-purchase analysis for Champions segment
-- Identifies category pairs most frequently purchased together
-- by the highest-value customers. Supports cross-sell and
-- basket-size recommendations (Brynjolfsson et al., 2003).
SELECT a.category AS category_1,
       b.category AS category_2,
       COUNT(DISTINCT a.order_id) AS co_purchase_orders,
       ROUND(COUNT(DISTINCT a.order_id) * 100.0 /
               (SELECT COUNT(DISTINCT order_id)
                FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned` t2
                INNER JOIN `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments` r2 ON t2.user_id = r2.user_id
                WHERE r2.rfm_segment = 'Champions'
                  AND LOWER(t2.order_status) IN ('completed', 'shipped')), 2) AS support_pct
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned` a
INNER JOIN `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned` b ON a.order_id = b.order_id
AND a.category < b.category
INNER JOIN `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments` r ON a.user_id = r.user_id
WHERE r.rfm_segment = 'Champions'
  AND LOWER(a.order_status) IN ('completed',
                                'shipped')
  AND LOWER(b.order_status) IN ('completed',
                                'shipped')
GROUP BY a.category,
         b.category
ORDER BY co_purchase_orders DESC
LIMIT 10;

-- D6. Average review rating and review frequency by segment
-- Assesses whether satisfaction differs across value tiers
-- and identifies which segments are most engaged as reviewers
SELECT r.rfm_segment,
       COUNT(rv.review_id) AS total_reviews,
       COUNT(DISTINCT rv.user_id) AS reviewers,
       ROUND(AVG(rv.rating), 2) AS avg_rating,
       ROUND(COUNT(rv.review_id) * 1.0 / COUNT(DISTINCT rv.user_id), 2) AS reviews_per_reviewer,
       ROUND(COUNTIF(rv.rating >= 4) * 100.0 / COUNT(rv.review_id), 2) AS positive_rate_pct,
       ROUND(COUNTIF(rv.rating <= 2) * 100.0 / COUNT(rv.review_id), 2) AS negative_rate_pct
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Reviews_cleaned` rv
INNER JOIN `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments` r ON rv.user_id = r.user_id
GROUP BY r.rfm_segment
ORDER BY avg_rating DESC;

-- D7. Average rating by category for Champions segment
-- Identifies satisfaction gaps in high-revenue categories
-- that represent retention risks for the most valuable customers
SELECT t.category,
       COUNT(rv.review_id) AS reviews,
       ROUND(AVG(rv.rating), 2) AS avg_rating,
       ROUND(COUNTIF(rv.rating >= 4) * 100.0 / COUNT(rv.review_id), 2) AS positive_rate_pct,
       ROUND(COUNTIF(rv.rating <= 2) * 100.0 / COUNT(rv.review_id), 2) AS negative_rate_pct,
       ROUND(SUM(t.item_total), 2) AS category_revenue
FROM `leafy-clone-489205-d4.MIS384_A2_CleanedData.Transactions_cleaned` t
INNER JOIN `leafy-clone-489205-d4.MIS384_A2_CleanedData.Reviews_cleaned` rv ON t.order_id = rv.order_id
AND t.product_id = rv.product_id
INNER JOIN `leafy-clone-489205-d4.MIS384_A2_CleanedData.rfm_segments` r ON t.user_id = r.user_id
WHERE r.rfm_segment = 'Champions'
  AND LOWER(t.order_status) IN ('completed',
                                'shipped')
GROUP BY t.category
ORDER BY avg_rating ASC;
