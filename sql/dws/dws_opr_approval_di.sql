-- dws.dws_opr_approval_di  审批日汇总
-- 粒度：travel_date × tenant_id × flow_code
-- 来源：dwd_opr_approval_di
-- 生成方式：Spark SQL / Hive；字段 7 个：直接翻译 2 · 规则翻译 3 · 待确认 2
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_opr_approval_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.tenant_id,
  u.flow_code,
  SUM(u.approval_qty) AS approval_qty,
  SUM(u.approval_pass_qty) AS approval_pass_qty,
  SUM(u.approval_reject_qty) AS approval_reject_qty,
  SUM(u.approval_minute_qty) AS approval_minute_qty,
  SUM(u.approval_timeout_qty) AS approval_timeout_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_opr_approval_di
  SELECT
    tenant_id AS tenant_id,
    flow_code AS flow_code,
    COUNT(instance_no) AS approval_qty,
    COUNT(CASE WHEN instance_status = 'APPROVED' THEN 1 END) AS approval_pass_qty,
    COUNT(CASE WHEN instance_status = 'REJECTED' THEN 1 END) AS approval_reject_qty,
    NULL AS approval_minute_qty,  -- 待确认：sum(minutes(end_time - create_time)) where 已结束
    COUNT(CASE WHEN 1 = 1 THEN instance_no END) AS approval_timeout_qty  -- 待确认：完成时间>timeout_at
  FROM dwd.dwd_opr_approval_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY tenant_id, flow_code
) u
GROUP BY u.tenant_id, u.flow_code;
