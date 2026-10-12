-- NextWave: Data cleaning: clicks with campaign data
-- Source: MIS384 Assignment 2 report, Appendix 1
-- Dialect: Google BigQuery Standard SQL
--
-- Table references point at the original BigQuery project/dataset used for the
-- assignment. Replace them with your own `project.dataset` before running.

-- Step 1. Inspect Raw Data
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT click_id) AS unique_click_ids,
       COUNTIF(user_id IS NULL) AS null_user_id,
       COUNTIF(product_id IS NULL) AS null_product_id,
       COUNTIF(click_type IS NULL) AS null_click_type,
       COUNTIF(click_timestamp IS NULL) AS null_click_timestamp
FROM `A2.A2Clicks`;

-- Step 2. Identify Duplicate Records
SELECT click_id,
       COUNT(*) AS duplicate_count
FROM `A2.A2Clicks`
GROUP BY click_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Step 3. Standardise Text Fields
SELECT LOWER(TRIM(click_type)) AS click_type_clean,
       COUNT(*) AS cnt
FROM `A2.A2Clicks`
GROUP BY click_type_clean
ORDER BY cnt DESC;

-- Step 4. Remove Duplicate Records
SELECT *
FROM
  (SELECT *,
          ROW_NUMBER() OVER (PARTITION BY click_id
                             ORDER BY click_timestamp DESC) AS rn
   FROM `A2.A2Clicks`)
WHERE rn = 1;

-- Step 5. Filter Invalid Records
SELECT click_id,
       TRIM(user_id) AS user_id,
       TRIM(product_id) AS product_id,
       LOWER(TRIM(click_type)) AS click_type_clean,
       SAFE_CAST(click_timestamp AS TIMESTAMP) AS click_ts
FROM `MIS384.A2.A2Clicks`
WHERE TRIM(user_id) IS NOT NULL
  AND TRIM(user_id) != ''
  AND TRIM(product_id) IS NOT NULL
  AND TRIM(product_id) != ''
  AND LOWER(TRIM(click_type)) IS NOT NULL
  AND LOWER(TRIM(click_type)) != ''
  AND SAFE_CAST(click_timestamp AS TIMESTAMP) IS NOT NULL;

-- Step 6. Convert and Format Timestamp
SELECT click_id,
       click_timestamp,
       SAFE_CAST(click_timestamp AS TIMESTAMP) AS click_ts,
       DATE(SAFE_CAST(click_timestamp AS TIMESTAMP)) AS click_date,
       EXTRACT(HOUR
               FROM SAFE_CAST(click_timestamp AS TIMESTAMP)) AS click_hour
FROM `MIS384.A2.A2Clicks`
WHERE SAFE_CAST(click_timestamp AS TIMESTAMP) IS NOT NULL
LIMIT 100;

-- Step 7. Clean Campaign Variables
SELECT click_id,
       campaign_active,
       campaign_triggered_click,
       campaign_id_active,
       campaign_type_active,
       CASE
           WHEN CAST(campaign_active AS INT64) = 1 THEN 1
           ELSE 0
       END AS campaign_active_clean,
       CASE
           WHEN CAST(campaign_triggered_click AS INT64) = 1 THEN 1
           ELSE 0
       END AS campaign_triggered_click_clean,
       CASE
           WHEN CAST(campaign_active AS INT64) = 1 THEN COALESCE(TRIM(campaign_id_active), 'UNKNOWN_CAMPAIGN')
           ELSE 'NO_CAMPAIGN'
       END AS campaign_id_active_clean,
       CASE
           WHEN CAST(campaign_active AS INT64) = 1 THEN COALESCE(TRIM(campaign_type_active), 'Unknown Campaign Type')
           ELSE 'No Campaign'
       END AS campaign_type_active_clean
FROM `A2.A2Clicks`
LIMIT 100;

-- Step 8. Create Final Cleaned Table with Derived Features
CREATE OR REPLACE TABLE `A2.cleaned_clicks` AS WITH deduplicated AS
  (SELECT *,
          ROW_NUMBER() OVER (PARTITION BY click_id
                             ORDER BY click_timestamp DESC) AS rn
   FROM `A2.A2Clicks`),
                                                    base_clean AS
  (SELECT click_id,
          TRIM(user_id) AS user_id,
          TRIM(product_id) AS product_id,
          LOWER(TRIM(click_type)) AS click_type_clean,
          SAFE_CAST(click_timestamp AS TIMESTAMP) AS click_ts,
          CAST(campaign_active AS INT64) AS campaign_active,
          TRIM(campaign_id_active) AS campaign_id_active,
          TRIM(campaign_type_active) AS campaign_type_active,
          CAST(campaign_triggered_click AS INT64) AS campaign_triggered_click
   FROM deduplicated
   WHERE rn = 1),
                                                    filtered AS
  (SELECT *
   FROM base_clean
   WHERE user_id IS NOT NULL
     AND user_id != ''
     AND product_id IS NOT NULL
     AND product_id != ''
     AND click_type_clean IS NOT NULL
     AND click_type_clean != ''
     AND click_ts IS NOT NULL)
SELECT *
FROM filtered;
