-- dwd.dwd_opr_complaint_rt  实时投诉工单
-- 粒度：1行=1个投诉工单
-- 来源：ods_opr_complaint_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 20 个：直接翻译 15 · 规则翻译 3 · 待确认 2
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dwd.dwd_opr_complaint_rt
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                       AS travel_date,
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
  a.create_time                                                AS create_time_hour_no,  -- 待确认：ods_opr_complaint_rt.create_time 取小时
  CASE WHEN a.complaint_status IN ('RESOLVED', 'CLOSED') THEN a.binlog_time END AS resolve_time,
  (CASE WHEN a.complaint_status IN ('RESOLVED', 'CLOSED') THEN a.binlog_time END) - (a.create_time) AS resolve_hour_qty,
  NULL                                                         AS sla_timeout_type,  -- 待确认：resolve_time 或当前时间晚于 sla_deadline
  1                                                            AS complaint_qty,
  CURRENT_TIMESTAMP                                            AS event_time
FROM ods.ods_opr_complaint_rt a
LEFT JOIN dwd.dwd_ord_order_group_di j1
  ON j1.order_group_no = a.order_group_no
 AND j1.travel_date = '${bizdate}';
