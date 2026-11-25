-- dwd.dwd_opr_approval_di  审批实例明细
-- 粒度：1行=1个审批实例
-- 来源：ods_opr_approval_instance_di
-- 生成方式：Spark SQL / Hive；字段 20 个：直接翻译 17 · 规则翻译 1 · 待确认 2
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_opr_approval_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                  AS instance_id,
  a.instance_no                         AS instance_no,
  a.flow_id                             AS flow_id,
  a.flow_code                           AS flow_code,
  a.business_no                         AS business_no,
  a.applicant_id                        AS applicant_id,
  a.applicant_name                      AS applicant_name,
  a.current_node                        AS current_node_name,
  a.timeout_at                          AS timeout_time,
  a.instance_status                     AS instance_status,
  a.tenant_id                           AS tenant_id,
  a.create_time                         AS create_time,
  a.update_time                         AS update_time,
  j1.flow_name                          AS flow_name,
  a.create_time                         AS apply_time,
  a.instance_status                     AS finish_time,  -- 待确认：ods_opr_approval_instance_di.instance_status 终态的 binlog_time
  (a.instance_status) - (a.create_time) AS approval_minute_qty,
  NULL                                  AS timeout_type,  -- 待确认：finish_time 晚于 timeout_at 或进行中已超时
  1                                     AS approval_qty,
  CURRENT_TIMESTAMP()                   AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_opr_approval_instance_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dim.dim_opr_approval_flow_df j1
  ON j1.approval_flow_id = a.flow_id
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
