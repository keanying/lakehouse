-- dwd.dwd_trf_distribution_credit_rt  实时分销授信
-- 粒度：1行=1条分销关系×1个有效区间
-- 来源：ods_trf_distribution_relation_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 20 个：直接翻译 13 · 规则翻译 2 · 待确认 5
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dwd.dwd_trf_distribution_credit_rt
SELECT
  DATE_FORMAT(a.binlog_time, 'yyyyMMdd')        AS travel_date,
  a.id                                          AS relation_id,
  a.relation_no                                 AS relation_no,
  a.supplier_tenant_id                          AS supplier_tenant_id,
  a.distributor_tenant_id                       AS distributor_tenant_id,
  a.parent_relation_id                          AS parent_relation_id,
  a.distribution_mode                           AS distribution_mode_type,
  a.payment_mode                                AS payment_mode_type,
  ROUND(a.credit_limit / 100, 2)                AS credit_limit_amt,
  ROUND(a.credit_used / 100, 2)                 AS credit_used_amt,
  a.relation_status                             AS relation_status,
  a.create_time                                 AS create_time,
  a.update_time                                 AS update_time,
  a.parent_relation_id                          AS chain_level_no,  -- 待确认：ods_trf_distribution_relation_rt.parent_relation_id 递归
  a.supplier_tenant_id                          AS level1_tenant_id,  -- 待确认：ods_trf_distribution_relation_rt.supplier_tenant_id 递归至根
  a.distributor_tenant_id                       AS level2_tenant_id,  -- 待确认：ods_trf_distribution_relation_rt.distributor_tenant_id 递归
  a.distributor_tenant_id                       AS level3_tenant_id,  -- 待确认：ods_trf_distribution_relation_rt.distributor_tenant_id 递归
  a.distributor_tenant_id                       AS level4_tenant_id,  -- 待确认：ods_trf_distribution_relation_rt.distributor_tenant_id 递归
  ROUND(a.credit_limit - a.credit_used /100, 2) AS credit_available_amt,
  CURRENT_TIMESTAMP                             AS event_time
FROM ods.ods_trf_distribution_relation_rt a;
