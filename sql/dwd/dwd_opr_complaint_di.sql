-- dwd.dwd_opr_complaint_di  投诉工单明细
-- 粒度：1行=1个投诉工单
-- 来源：ods_opr_complaint_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 15 · 规则翻译 2 · 待确认 2
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_opr_complaint_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS complaint_id,
  a.complaint_no                                               AS complaint_no,
  a.complainant_type                                           AS complainant_type,
  a.complainant_id                                             AS complainant_id,
  a.order_group_no                                             AS order_group_no,
  a.complaint_type                                             AS complaint_type,
  a.handler_id                                                 AS handler_id,
  a.sla_deadline                                               AS sla_deadline_time,
  a.complaint_status                                           AS complaint_status,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  j1.seller_tenant_id                                          AS seller_tenant_id,
  a.create_time                                                AS create_time_hour_no,  -- 待确认：ods_opr_complaint_di.create_time 取小时
  CASE WHEN a.complaint_status IN ('RESOLVED', 'CLOSED') THEN a.binlog_time END AS resolve_time,
  (CASE WHEN a.complaint_status IN ('RESOLVED', 'CLOSED') THEN a.binlog_time END) - (a.create_time) AS resolve_hour_qty,
  NULL                                                         AS sla_timeout_type,  -- 待确认：resolve_time 或当前时间晚于 sla_deadline
  1                                                            AS complaint_qty,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_opr_complaint_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dwd.dwd_ord_order_group_di j1
  ON j1.order_group_no = a.order_group_no
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
