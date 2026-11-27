-- dwd.dwd_ord_order_status_log_di  子单状态流转明细
-- 粒度：1行=1次子单状态变更
-- 来源：ods_ord_order_di（binlog 前后镜像）
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 8 · 规则翻译 3 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
order_chg AS (                                                                    -- 主表「子单」：保留每条变更记录，只取用到的列
  SELECT binlog_time, id, order_group_no, order_no, order_status, seller_tenant_id, sku_id, tenant_id
  FROM ods.ods_ord_order_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_ord_order_status_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  order_chg.order_no                                           AS order_no,       -- 子单号
  order_chg.order_group_no                                     AS order_group_no,  -- 所属聚合单号
  order_chg.seller_tenant_id                                   AS seller_tenant_id,  -- 卖家租户ID
  order_chg.sku_id                                             AS sku_id,         -- SKU ID
  LAG(order_chg.order_status) OVER (PARTITION BY order_chg.id ORDER BY order_chg.binlog_time) AS before_status,  -- 变更前状态
  order_chg.order_status                                       AS after_status,   -- 变更后状态
  order_chg.binlog_time                                        AS change_time,    -- 状态变更时间
  1                                                            AS status_change_qty,  -- 状态变更次数
  (UNIX_TIMESTAMP(order_chg.binlog_time) - UNIX_TIMESTAMP(LAG(order_chg.binlog_time)  -- 前一状态停留时长（分钟）
      OVER (PARTITION BY order_chg.id ORDER BY order_chg.binlog_time))) / 60 AS stay_minute_qty,  -- 前一状态停留时长（分钟）
  order_chg.tenant_id                                          AS tenant_id,      -- 租户ID（分库维度）
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM order_chg;
