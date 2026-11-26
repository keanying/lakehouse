-- dws.dws_opr_approval_di  审批日汇总
-- 粒度：travel_date × tenant_id × flow_code
-- 来源：dwd_opr_approval_di
-- 生成方式：Spark SQL / Hive；字段 7 个：直接翻译 2 · 规则翻译 3 · 待确认 2
-- 来源先按粒度键预聚合
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_approval AS (                                                                 -- 来源「审批实例明细」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                                                       -- 租户ID
    flow_code AS flow_code,                                                       -- 审批流编码
    COUNT(instance_no) AS approval_qty,                                           -- 审批发起数
    COUNT(CASE WHEN instance_status = 'APPROVED' THEN 1 END) AS approval_pass_qty,  -- 审批通过数
    COUNT(CASE WHEN instance_status = 'REJECTED' THEN 1 END) AS approval_reject_qty,  -- 审批拒绝数
    NULL AS approval_minute_qty,                                                  -- 待确认：sum(minutes(end_time - create_time)) where 已结束
    COUNT(CASE WHEN 1 = 1 THEN instance_no END) AS approval_timeout_qty           -- 审批超时数｜待确认：完成时间>timeout_at
  FROM dwd.dwd_opr_approval_di s                                                  -- 来源表「审批实例明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY tenant_id, flow_code                                                   -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_opr_approval_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.tenant_id,                                                                    -- 租户ID
  u.flow_code,                                                                    -- 审批流编码
  u.approval_qty,                                                                 -- 审批发起数
  u.approval_pass_qty,                                                            -- 审批通过数
  u.approval_reject_qty,                                                          -- 审批拒绝数
  u.approval_minute_qty,                                                          -- 审批总耗时
  u.approval_timeout_qty,                                                         -- 审批超时数
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM src_approval u;
