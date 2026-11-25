-- dwd.dwd_ord_ticket_status_log_di  票状态流转明细
-- 粒度：1行=1次票状态变更
-- 来源：ods_ord_ticket_di（binlog 前后镜像）
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 9 · 规则翻译 3 · 待确认 0
-- 流水/状态变更类：保留每条变更记录

INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_status_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.ticket_no                                                  AS ticket_no,      -- 票号
  a.order_no                                                   AS order_no,       -- 所属子单号
  j1.order_group_no                                            AS order_group_no,  -- 所属聚合单号
  j1.seller_tenant_id                                          AS seller_tenant_id,  -- 卖家租户ID
  j1.sku_id                                                    AS sku_id,         -- SKU ID
  LAG(a.ticket_status) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS before_status,  -- 变更前状态
  a.ticket_status                                              AS after_status,   -- 变更后状态
  a.binlog_time                                                AS change_time,    -- 状态变更时间
  1                                                            AS status_change_qty,  -- 状态变更次数
  (UNIX_TIMESTAMP(a.binlog_time) - UNIX_TIMESTAMP(LAG(a.binlog_time) OVER (PARTITION BY a.id ORDER BY a.binlog_time))) / 60 AS stay_minute_qty,  -- 前一状态停留时长（分钟）
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM ods.ods_ord_ticket_di a                                                      -- 主表「票」
LEFT JOIN dwd.dwd_ord_ticket_di j1                                                -- 关联「票明细（出票）」，取 所属聚合单号、卖家租户ID、SKU ID
  ON j1.ticket_id = a.id                                                          -- 按 id→ticket_id 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                                               -- 只取当日分区
