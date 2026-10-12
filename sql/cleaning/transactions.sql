-- NextWave: Data cleaning: transactions
-- Source: MIS384 Assignment 2 report, Appendix 1
-- Dialect: Google BigQuery Standard SQL
--
-- Table references point at the original BigQuery project/dataset used for the
-- assignment. Replace them with your own `project.dataset` before running.

-- Step 1. Check missing values
SELECT column_name,
       missing_count
FROM
  (SELECT COUNTIF(order_item_id IS NULL) AS order_item_id,
          COUNTIF(order_id IS NULL) AS order_id,
          COUNTIF(product_id IS NULL) AS product_id,
          COUNTIF(user_id IS NULL) AS user_id,
          COUNTIF(quantity IS NULL) AS quantity,
          COUNTIF(item_price IS NULL) AS item_price,
          COUNTIF(item_total IS NULL) AS item_total,
          COUNTIF(product_name IS NULL) AS product_name,
          COUNTIF(category IS NULL) AS category,
          COUNTIF(brand IS NULL) AS brand,
          COUNTIF(price IS NULL) AS price,
          COUNTIF(rating IS NULL) AS rating,
          COUNTIF(order_date IS NULL) AS order_date,
          COUNTIF(order_status IS NULL) AS order_status,
          COUNTIF(total_amount IS NULL) AS total_amount,
          COUNTIF(name IS NULL) AS name,
          COUNTIF(gender IS NULL) AS gender,
          COUNTIF(city IS NULL) AS city,
          COUNTIF(signup_date IS NULL) AS signup_date
   FROM `leafy-clone-489205-d4.transactions.Transactions`) UNPIVOT (missing_count
                                                                    FOR column_name IN (order_item_id,
                                                                                        order_id,
                                                                                        product_id,
                                                                                        user_id,
                                                                                        quantity,
                                                                                        item_price,
                                                                                        item_total,
                                                                                        product_name,
                                                                                        category,
                                                                                        brand,
                                                                                        price,
                                                                                        rating,
                                                                                        order_date,
                                                                                        order_status,
                                                                                        total_amount,
                                                                                        name,
                                                                                        gender,
                                                                                        city,
                                                                                        signup_date));

-- Step 2. Data quality issues
SELECT issue_type,
       issue_count
FROM
  (SELECT COUNTIF(quantity <= 0) AS invalid_quantity,
          COUNTIF(item_price < 0) AS negative_item_price,
          COUNTIF(item_total < 0) AS negative_item_total,
          COUNTIF(price < 0) AS negative_price,
          COUNTIF(rating < 0
                  OR rating > 5) AS invalid_rating,
          COUNTIF(total_amount < 0) AS negative_total_amount,
          COUNTIF(ROUND(quantity * item_price, 2) != ROUND(item_total, 2)) AS incorrect_item_total
   FROM `leafy-clone-489205-d4.transactions.Transactions`) UNPIVOT (issue_count
                                                                    FOR issue_type IN (invalid_quantity,
                                                                                       negative_item_price,
                                                                                       negative_item_total,
                                                                                       negative_price,
                                                                                       invalid_rating,
                                                                                       negative_total_amount,
                                                                                       incorrect_item_total));

-- Step 3. Order status consistency check
SELECT order_status,
       COUNT(*) AS count_rows
FROM `leafy-clone-489205-d4.transactions.Transactions`
GROUP BY order_status
ORDER BY count_rows DESC;

-- Step 4. Duplication check
SELECT duplicate_type,
       duplicate_count
FROM
  (SELECT COUNT(*) - COUNT(DISTINCT order_item_id) AS duplicate_order_item_id,
          COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_id
   FROM `leafy-clone-489205-d4.transactions.Transactions`) UNPIVOT (duplicate_count
                                                                    FOR duplicate_type IN (duplicate_order_item_id,
                                                                                           duplicate_order_id));

-- Step 5. Create cleaned transactions table
CREATE OR REPLACE TABLE `leafy-clone-489205-d4.transactions.Transactions_cleaned` AS
SELECT DISTINCT TRIM(order_item_id) AS order_item_id,
                TRIM(order_id) AS order_id,
                TRIM(product_id) AS product_id,
                TRIM(user_id) AS user_id,
                quantity,
                ROUND(item_price, 2) AS item_price,
                ROUND(quantity * item_price, 2) AS item_total,
                TRIM(product_name) AS product_name,
                TRIM(category) AS category,
                TRIM(brand) AS brand,
                ROUND(rating, 2) AS rating,
                DATE(order_date) AS order_date_only,
                TIME(order_date) AS order_time_only,
                CASE
                    WHEN LOWER(TRIM(order_status)) IN ('completed',
                                                       'complete',
                                                       'delivered') THEN 'Completed'
                    WHEN LOWER(TRIM(order_status)) IN ('cancelled',
                                                       'canceled',
                                                       'cancel') THEN 'Cancelled'
                    WHEN LOWER(TRIM(order_status)) IN ('pending',
                                                       'processing') THEN 'Pending'
                    WHEN LOWER(TRIM(order_status)) IN ('returned',
                                                       'return') THEN 'Returned'
                    ELSE INITCAP(TRIM(order_status))
                END AS order_status,
                ROUND(total_amount, 2) AS total_amount,
                TRIM(name) AS name,
                INITCAP(TRIM(gender)) AS gender,
                INITCAP(TRIM(city)) AS city,
                DATE(signup_date) AS signup_date
FROM `leafy-clone-489205-d4.transactions.Transactions`
WHERE order_item_id IS NOT NULL
  AND order_id IS NOT NULL
  AND product_id IS NOT NULL
  AND user_id IS NOT NULL
  AND quantity > 0
  AND item_price >= 0
  AND item_total >= 0
  AND rating BETWEEN 0 AND 5
  AND total_amount >= 0;

-- Step 6. Cleaned dataset summary
SELECT metric,
       value
FROM
  (SELECT CAST(COUNT(*) AS FLOAT64) AS total_rows,
          CAST(COUNT(DISTINCT order_item_id) AS FLOAT64) AS unique_order_items,
          CAST(COUNT(DISTINCT order_id) AS FLOAT64) AS unique_orders,
          CAST(COUNT(DISTINCT user_id) AS FLOAT64) AS unique_customers,
          CAST(COUNT(DISTINCT product_id) AS FLOAT64) AS unique_products,
          ROUND(SUM(item_total), 2) AS total_revenue
   FROM `leafy-clone-489205-d4.transactions.Transactions_cleaned`) UNPIVOT (value
                                                                            FOR metric IN (total_rows,
                                                                                           unique_order_items,
                                                                                           unique_orders,
                                                                                           unique_customers,
                                                                                           unique_products,
                                                                                           total_revenue));

-- Step 7. Cleaned order status check
SELECT order_status,
       COUNT(*) AS count_rows
FROM `leafy-clone-489205-d4.transactions.Transactions_cleaned`
GROUP BY order_status
ORDER BY count_rows DESC;

-- Step 8. Cleaned date and time check
SELECT order_date_only,
       order_time_only,
       COUNT(*) AS count_rows
FROM `leafy-clone-489205-d4.transactions.Transactions_cleaned`
GROUP BY order_date_only,
         order_time_only
ORDER BY order_date_only,
         order_time_only
LIMIT 20;
