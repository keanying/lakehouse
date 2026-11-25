-- ads.ads_opr_risk_monitor_di  风控监控
-- 粒度：travel_date × rule_id × action_type
-- 来源：dws_opr_risk_rule_hit_di, dws_opr_audit_action_di, dws_ord_tenant_sku_verify_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 11 · 规则翻译 0 · 待确认 3
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_opr_risk_monitor_di PARTITION (travel_date = '${bizdate}')
SELECT
  x.rule_id,
  x.action_type,
  d1.rule_name AS rule_name,
  x.risk_hit_qty,
  x.risk_block_qty,
  x.risk_block_numerator_qty,
  x.risk_block_denominator_qty,
  x.blacklist_add_qty,
  x.ban_qty,
  x.night_action_qty,
  x.duplicate_verify_qty,
  x.etl_time
FROM (
SELECT
  u.rule_id,
  u.action_type,
  SUM(u.risk_hit_qty) AS risk_hit_qty,
  SUM(u.risk_block_qty) AS risk_block_qty,
  SUM(u.risk_block_numerator_qty) AS risk_block_numerator_qty,
  SUM(u.risk_block_denominator_qty) AS risk_block_denominator_qty,
  SUM(u.blacklist_add_qty) AS blacklist_add_qty,
  SUM(u.ban_qty) AS ban_qty,
  SUM(u.night_action_qty) AS night_action_qty,
  SUM(u.duplicate_verify_qty) AS duplicate_verify_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dws_opr_risk_rule_hit_di
  SELECT
    rule_id AS rule_id,
    action_type AS action_type,
    SUM(risk_hit_qty) AS risk_hit_qty,
    SUM(risk_block_qty) AS risk_block_qty,
    SUM(risk_block_qty) AS risk_block_numerator_qty,
    SUM(risk_hit_qty) AS risk_block_denominator_qty,
    SUM(blacklist_add_qty) AS blacklist_add_qty,
    SUM(ban_qty) AS ban_qty,
    NULL AS night_action_qty,
    NULL AS duplicate_verify_qty
  FROM dws.dws_opr_risk_rule_hit_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY rule_id, action_type
  UNION ALL
  -- 来源：dws_opr_audit_action_di
  SELECT
    CAST(NULL AS BIGINT) AS rule_id,
    action_type AS action_type,
    NULL AS risk_hit_qty,
    NULL AS risk_block_qty,
    NULL AS risk_block_numerator_qty,
    NULL AS risk_block_denominator_qty,
    NULL AS blacklist_add_qty,
    NULL AS ban_qty,
    SUM(night_action_qty) AS night_action_qty,
    NULL AS duplicate_verify_qty
  FROM dws.dws_opr_audit_action_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY action_type
  UNION ALL
  -- 来源：dws_ord_tenant_sku_verify_di
  SELECT
    CAST(NULL AS BIGINT) AS rule_id,
    CAST(NULL AS STRING) AS action_type,
    NULL AS risk_hit_qty,
    NULL AS risk_block_qty,
    NULL AS risk_block_numerator_qty,
    NULL AS risk_block_denominator_qty,
    NULL AS blacklist_add_qty,
    NULL AS ban_qty,
    NULL AS night_action_qty,
    SUM(duplicate_verify_qty) AS duplicate_verify_qty
  FROM dws.dws_ord_tenant_sku_verify_di s
  WHERE s.travel_date = '${bizdate}'
) u
GROUP BY u.rule_id, u.action_type
) x
LEFT JOIN dim.dim_opr_risk_rule_df d1 ON d1.risk_rule_id = x.rule_id AND d1.travel_date = '${bizdate}';
