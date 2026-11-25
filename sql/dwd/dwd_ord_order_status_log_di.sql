-- dwd.dwd_ord_order_status_log_di  子单状态流转明细
-- 粒度：1行=1次子单状态变更
-- 来源：ods_ord_order_di（binlog 前后镜像）
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 8 · 规则翻译 3 · 待确认 0
-- 流水/状态变更类：保留每条变更记录

INSERT OVERWRITE TABLE dwd.dwd_ord_order_status_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.order_no                                                   AS order_no,       -- 子单号
  a.order_group_no                                             AS order_group_no,  -- 所属聚合单号
  a.seller_tenant_id                                           AS seller_tenant_id,  -- 卖家租户ID
  a.sku_id                                                     AS sku_id,         -- SKU ID
  LAG(a.order_status) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS before_status,  -- 变更前状态
  a.order_status                                               AS after_status,   -- 变更后状态
  a.binlog_time                                                AS change_time,    -- 状态变更时间
  1                                                            AS status_change_qty,  -- 状态变更次数
  (UNIX_TIMESTAMP(a.binlog_time) - UNIX_TIMESTAMP(LAG(a.binlog_time) OVER (PARTITION BY a.id ORDER BY a.binlog_time))) / 60 AS stay_minute_qty,  -- 前一状态停留时长（分钟）
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM ods.ods_ord_order_di a                                                       -- 主表「子单」
WHERE a.travel_date = '${bizdate}';                                               -- 只取当日分区
