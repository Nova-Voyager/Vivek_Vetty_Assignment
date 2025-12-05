-- If a table named "transactions" or "items" already exists, delete it first
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS items CASCADE;

CREATE TABLE items (
  store_id TEXT,            --store this item belongs to (like 'a'
  item_id TEXT PRIMARY KEY,  --unique id for the item (text)
  item_category TEXT,        --category of the item (like 'chair')
  item_name TEXT             --readable name of the item (like 'coffee table')
);

CREATE TABLE transactions (
  transaction_id SERIAL PRIMARY KEY,   --number for each row
  buyer_id INTEGER,                    --id of the person who bought something
  purchase_time TIMESTAMPTZ,           --purchase happened (with timezone)
  refund_time TIMESTAMPTZ,             --refund happened (if it did); null if no refund
  store_id TEXT,                      --store sold the item
  item_id TEXT,                       --id of the item bought
  gross_transaction_value NUMERIC(12,2)  --how much money the transaction was worth
);


INSERT INTO transactions (buyer_id, purchase_time, refund_time, store_id, item_id, gross_transaction_value) VALUES
 (3,  '2019-09-19 21:19:06.544+00', NULL,                                'a', 'a1', 58.00),
 (12, '2019-12-10 20:10:34.324+00', '2019-12-15 23:19:06.544+00',          'b', 'b2', 475.00),
 (3,  '2020-09-01 23:59:46.561+00', '2020-09-02 21:22:06.331+00',          'f', 'f9', 33.00),
 (2,  '2020-04-30 21:19:06.544+00', NULL,                                'd', 'd3', 250.00),
 (1,  '2020-10-22 22:20:06.531+00', NULL,                                'f', 'f2', 91.00),
 (8,  '2020-04-16 21:10:22.214+00', NULL,                                'e', 'e7', 24.00),
 (5,  '2019-09-23 12:09:35.542+00', '2019-09-27 02:55:02.114+00',          'g', 'g6', 61.00);

INSERT INTO items (store_id, item_id, item_category, item_name) VALUES
 ('a', 'a1', 'pants', 'denim pants'),
 ('a', 'a2', 'tops',  'blouse'),
 ('f', 'f1', 'table', 'coffee table'),
 ('f', 'f5', 'chair', 'lounge chair'),
 ('f', 'f6', 'chair', 'armchair'),
 ('d', 'd2', 'jewelry', 'bracelet'),
 ('b', 'b4', 'earphone', 'airpods');

 select * from items
  select * from transactions


---- Q1. Count of purchases per month (excluding refunded)
SELECT
  DATE_TRUNC('month', purchase_time) AS month,  --it is grouping timestamps into months
  COUNT(*) AS purchase_count                       --its count how many purchase happening in month
FROM transactions
WHERE refund_time IS NULL                 --only include purchases that were not refunded
GROUP BY 1
ORDER BY 1;

-- Q2: How many stores received at least 5 orders in October 2020?
-- First select only October 2020 rows. Then count stores that have 5 or more orders having.
SELECT COUNT(*) AS stores_with_at_least_5_orders
FROM (
  SELECT store_id
  FROM transactions
  WHERE purchase_time >= '2020-10-01'::timestamptz   -- start of Oct 2020
    AND purchase_time <  '2020-11-01'::timestamptz   -- end of Oct 2020 which is exclusive
  GROUP BY store_id
  HAVING COUNT(*) >= 5                               --  keeping stores with 5+ orders
) X;



-- Q3: For each store, shortest interval (in minutes) from purchase to refund
-- Consider only transactions that were refunded. For each store, compute the time between purchase and refund,
-- convert to minutes, and take the smallest value per store.
SELECT
  store_id,
  MIN(EXTRACT(EPOCH FROM (refund_time - purchase_time)) / 60.0) AS min_refund_time_minutes
  -- EXTRACT(EPOCH FROM ...) gives seconds; divide by 60 to get minutes
FROM transactions
WHERE refund_time IS NOT NULL  
GROUP BY store_id
ORDER BY store_id;



-- Q4: Gross transaction value of every store’s first order
-- Use DISTINCT ON to pick the earliest purchase per store, then show its value.
SELECT DISTINCT ON (store_id)
  store_id,
  gross_transaction_value
FROM transactions
ORDER BY store_id, purchase_time ASC;  





-- Q5: Most popular item name that buyers order on their first purchase
-- Step 1: For each buyer, pick their first transaction (earliest purchase_time).
-- Step 2: Look up the item name in the items table.
SELECT i.item_name
FROM (
  SELECT DISTINCT ON (buyer_id) buyer_id, item_id
  FROM transactions
  ORDER BY buyer_id, purchase_time ASC  -- keep the first purchase per buyer
) first_order
JOIN items i ON i.item_id = first_order.item_id
GROUP BY i.item_name
ORDER BY COUNT(*) DESC
LIMIT 1;  -- return the top item_name



-- Q6: Create a flag in transactions to indicate whether the refund can be processed (within 72 hours)
-- Add a column called refund_processable if it doesn't already exist. This column will hold TRUE or FALSE.
ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS refund_processable BOOLEAN;

-- Set the flag to TRUE when refund exists and happened within 72 hours of purchase; otherwise FALSE.
UPDATE transactions
SET refund_processable =
  (refund_time IS NOT NULL
   AND (refund_time - purchase_time) <= INTERVAL '72 hours');

-- Show refunded transactions and whether they can be processed
SELECT transaction_id, buyer_id, purchase_time, refund_time, refund_processable
FROM transactions
WHERE refund_time IS NOT NULL
ORDER BY purchase_time;




-- Q7: Create a rank by buyer_id and filter for only the second purchase per buyer (ignore refunds)
-- Computing rank (1,2,3...) for each buyer based on purchase_time,
-- but only consider purchases that were NOT refunded. Then select rows with rank = 2.
SELECT
  transaction_id,
  buyer_id,
  purchase_time,
  store_id,
  item_id,
  gross_transaction_value
FROM (
  SELECT
    transaction_id,
    buyer_id,
    purchase_time,
    store_id,
    item_id,
    gross_transaction_value,
    ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time ASC) AS rn
    -- rn = 1 means buyer's 1st non-refunded purchase, rn = 2 means 2nd non-refunded purchase, etc.
  FROM transactions
  WHERE refund_time IS NULL   -- ignore refunded purchases
) t
WHERE rn = 2   -- only keep the second purchase per buyer
ORDER BY buyer_id;



-- Q8: How to find the second transaction time per buyer (don’t use min/max)
-- Use ROW_NUMBER partitioned by buyer_id, ordered by purchase time, then select rn = 2.
SELECT buyer_id, purchase_time AS second_purchase_time
FROM (
  SELECT
    buyer_id,
    purchase_time,
    ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time ASC) AS rn
  FROM transactions
) t
WHERE rn = 2
ORDER BY buyer_id;

