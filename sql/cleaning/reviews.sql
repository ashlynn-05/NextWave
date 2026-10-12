-- NextWave: Data cleaning: product reviews
-- Source: MIS384 Assignment 2 report, Appendix 1
-- Dialect: Google BigQuery Standard SQL
--
-- Table references point at the original BigQuery project/dataset used for the
-- assignment. Replace them with your own `project.dataset` before running.

-- Step 1. Overall quality check
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT review_id) AS unique_review_ids,
       COUNTIF(review_id IS NULL) AS null_review_id,
       COUNTIF(order_id IS NULL) AS null_order_id,
       COUNTIF(product_id IS NULL) AS null_product_id,
       COUNTIF(user_id IS NULL) AS null_user_id,
       COUNTIF(rating IS NULL) AS null_rating,
       COUNTIF(review_text IS NULL) AS null_review_text,
       COUNTIF(review_date IS NULL) AS null_review_date,
       COUNTIF(rating NOT BETWEEN 1 AND 5) AS invalid_rating,
       MIN(TIMESTAMP(review_date)) AS earliest_review,
       MAX(TIMESTAMP(review_date)) AS latest_review
FROM `mis384-a2-494112.A2.a2mis384`;

-- Step 2. Check duplicates (same user_id + order_id + product_id)
SELECT user_id,
       product_id,
       COUNT(*) AS review_count
FROM `mis384-a2-494112.A2.a2mis384`
GROUP BY user_id,
         product_id
HAVING COUNT(*) > 1
ORDER BY review_count DESC;

-- Step 3. Generate clean table
CREATE OR REPLACE TABLE `mis384-a2-494112.A2.reviews_cleaned` AS
SELECT review_id,
       order_id,
       product_id,
       user_id,
       rating,
       review_text,
       TIMESTAMP(review_date) AS review_date
FROM
  (SELECT *,
          ROW_NUMBER() OVER (PARTITION BY user_id, order_id, product_id
                             ORDER BY TIMESTAMP(review_date) DESC) AS rn
   FROM `mis384-a2-494112.A2.a2mis384`)
WHERE rn = 1;

-- Step 4. Double-check cleaned table
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT review_id) AS unique_review_ids,
       COUNTIF(review_id IS NULL) AS null_review_id,
       COUNTIF(order_id IS NULL) AS null_order_id,
       COUNTIF(product_id IS NULL) AS null_product_id,
       COUNTIF(user_id IS NULL) AS null_user_id,
       COUNTIF(rating IS NULL) AS null_rating,
       COUNTIF(review_text IS NULL) AS null_review_text,
       COUNTIF(review_date IS NULL) AS null_review_date,
       COUNTIF(rating NOT BETWEEN 1 AND 5) AS invalid_rating,
       (SELECT COUNT(*)
   FROM
     (SELECT user_id,
             order_id,
             product_id
      FROM `mis384-a2-494112.A2.reviews_cleaned`
      GROUP BY user_id,
               order_id,
               product_id
      HAVING COUNT(*) > 1)) AS remaining_duplicates
FROM `mis384-a2-494112.A2.reviews_cleaned`;
