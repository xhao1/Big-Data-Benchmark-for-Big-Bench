--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.


--Customer segmentation for return analysis: Customers are separated
--along the following dimensions: return frequency, return order ratio (total num-
--ber of orders partially or fully returned versus the total number of orders),
--return item ratio (total number of items returned versus the number of items
--purchased), return amount ration (total monetary amount of items returned ver-
--sus the amount purchased), return order ratio. Consider the store returns during
--a given year for the computation.

-- Resources

------ create input table for mahout --------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;

DROP TABLE IF EXISTS ${hiveconf:TEMP_TABLE};
CREATE TABLE ${hiveconf:TEMP_TABLE} (
  user_sk           BIGINT,
  orderRatio        decimal(15,7),
  itemsRatio        decimal(15,7),
  monetaryRatio     decimal(15,7),
  frequency         BIGINT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ' ' LINES TERMINATED BY '\n'
STORED AS TEXTFILE LOCATION '${hiveconf:TEMP_DIR}';

-- there are two possible version. Both are valid points of view

-- version ONE where customers without returns are also part of the analysis
INSERT INTO TABLE ${hiveconf:TEMP_TABLE}
SELECT
  ss_customer_sk AS user_sk,
  IF ( (returns_count IS NULL) OR (orders_count  IS NULL) OR ((returns_count / orders_count) IS NULL) , 0 , (returns_count / orders_count) ) AS orderRatio,
  IF ( (returns_items IS NULL) OR (orders_items  IS NULL) OR ((returns_items / orders_items) IS NULL) , 0 , (returns_items / orders_items) ) AS itemsRatio,
  IF ( (returns_money IS NULL) OR (orders_money  IS NULL) OR ((returns_money / orders_money) IS NULL) , 0 , (returns_money / orders_money) ) AS monetaryRatio,
  IF ( returns_count  IS NULL                                                                         , 0 ,  returns_count                 ) AS frequency
FROM
  (
    SELECT
      ss_customer_sk,
      -- return order ratio 
      count(distinct(ss_ticket_number)) as orders_count,
      -- return ss_item_sk ratio
      COUNT(ss_item_sk) as orders_items ,
      -- return monetary amount ratio    
      SUM( ss_net_paid ) AS orders_money
    FROM  store_sales s
    GROUP BY ss_customer_sk
  ) orders
  LEFT OUTER JOIN
  (  
    SELECT
      sr_customer_sk,
      -- return order ratio 
      count(distinct(sr_ticket_number)) as returns_count,
      -- return ss_item_sk ratio
      COUNT(sr_item_sk) as returns_items ,
      -- return monetary amount ratio    
      SUM( sr_return_amt ) AS returns_money
    FROM  store_returns
    GROUP BY sr_customer_sk
  ) returned ON ss_customer_sk=sr_customer_sk  
Cluster by user_sk
;


--version  TWO where customers are filtered out that don't have any returns
-- INSERT INTO TABLE ${hiveconf:TEMP_TABLE}
-- SELECT
-- ss_customer_sk AS user_sk,
-- IF ( (returns_count IS NULL) OR (orders_count  IS NULL) OR ((orders_count / returns_count) IS NULL) , 0 , (orders_count / returns_count) ) AS orderRatio,
-- IF ( (returns_items IS NULL) OR (orders_items  IS NULL) OR ((orders_items / returns_items) IS NULL) , 0 , (orders_items / returns_items) ) AS itemsRatio,
-- IF ( (returns_money IS NULL) OR (orders_money  IS NULL) OR ((orders_money / returns_money) IS NULL) , 0 , (orders_money / returns_money) ) AS monetaryRatio,
-- IF ( returns_count IS NULL                                                                          , 0 ,  returns_count                 ) AS frequency
-- FROM
-- (
-- SELECT
-- ss_customer_sk,
-- -- return order ratio 
-- count(distinct(ss_ticket_number)) as orders_count,
-- -- return ss_item_sk ratio
-- COUNT(ss_item_sk) as orders_items ,
-- -- return monetary amount ratio    
-- SUM( ss_net_paid ) AS orders_money
-- FROM  store_sales s
-- GROUP BY ss_customer_sk
-- ) orders,
-- (  
-- SELECT
-- sr_customer_sk,
-- -- return order ratio 
-- count(distinct(sr_ticket_number)) as returns_count,
-- -- return ss_item_sk ratio
-- COUNT(sr_item_sk) as returns_items ,
-- -- return monetary amount ratio    
-- SUM( sr_return_amt ) AS returns_money
-- FROM  store_returns
-- GROUP BY sr_customer_sk
-- ) returned 
-- WHERE ss_customer_sk=sr_customer_sk  
-- -- HAVING frequency > 1  -- this would filter out all customers that do not have returns
-- Cluster by user_sk
-- ;
