-- dwd.dwd_ord_ticket_status_log_di  票状态流转明细
-- 粒度：1行=1次票状态变更
-- 来源：ods_ord_ticket_di（binlog 前后镜像）
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 9 · 规则翻译 3 · 待确认 0
-- 流水/状态变更类：保留每条变更记录

INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_status_log_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.ticket_no                                                  AS ticket_no,
  a.order_no                                                   AS order_no,
  j1.order_group_no                                            AS order_group_no,
  j1.seller_tenant_id                                          AS seller_tenant_id,
  j1.sku_id                                                    AS sku_id,
  LAG(a.ticket_status) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS before_status,
  a.ticket_status                                              AS after_status,
  a.binlog_time                                                AS change_time,
  1                                                            AS status_change_qty,
  (UNIX_TIMESTAMP(a.binlog_time) - UNIX_TIMESTAMP(LAG(a.binlog_time) OVER (PARTITION BY a.id ORDER BY a.binlog_time))) / 60 AS stay_minute_qty,
  a.tenant_id                                                  AS tenant_id,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM ods.ods_ord_ticket_di a
LEFT JOIN dwd.dwd_ord_ticket_di j1
  ON j1.ticket_id = a.id
 AND j1.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
