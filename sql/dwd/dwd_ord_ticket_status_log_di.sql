-- dwd.dwd_ord_ticket_status_log_di  票状态流转明细
-- 粒度：1行=1次票状态变更
-- 来源：ods_ord_ticket_di（binlog 前后镜像）
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 9 · 规则翻译 3 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
ticket_chg AS (                                                                   -- 主表「票」：保留每条变更记录，只取用到的列
  SELECT binlog_time, id, order_no, tenant_id, ticket_no, ticket_status
  FROM ods.ods_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
ticket_dtl AS (                                                                   -- 「票明细（出票）」当日数据，只取用到的列
  SELECT order_group_no, seller_tenant_id, sku_id, ticket_id
  FROM dwd.dwd_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_status_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  ticket_chg.ticket_no                                         AS ticket_no,      -- 票号
  ticket_chg.order_no                                          AS order_no,       -- 所属子单号
  ticket_dtl.order_group_no                                    AS order_group_no,  -- 所属聚合单号
  ticket_dtl.seller_tenant_id                                  AS seller_tenant_id,  -- 卖家租户ID
  ticket_dtl.sku_id                                            AS sku_id,         -- SKU ID
  LAG(ticket_chg.ticket_status) OVER (PARTITION BY ticket_chg.id ORDER BY ticket_chg.binlog_time) AS before_status,  -- 变更前状态
  ticket_chg.ticket_status                                     AS after_status,   -- 变更后状态
  ticket_chg.binlog_time                                       AS change_time,    -- 状态变更时间
  1                                                            AS status_change_qty,  -- 状态变更次数
  (UNIX_TIMESTAMP(ticket_chg.binlog_time) - UNIX_TIMESTAMP(LAG(ticket_chg.binlog_time)  -- 前一状态停留时长（分钟）
      OVER (PARTITION BY ticket_chg.id ORDER BY ticket_chg.binlog_time))) / 60 AS stay_minute_qty,  -- 前一状态停留时长（分钟）
  ticket_chg.tenant_id                                         AS tenant_id,      -- 租户ID（分库维度）
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM ticket_chg
LEFT JOIN ticket_dtl                                                              -- 关联「票明细（出票）」，取 所属聚合单号、卖家租户ID、SKU ID
  ON ticket_dtl.ticket_id = ticket_chg.id;                                        -- 按 id→ticket_id 关联
