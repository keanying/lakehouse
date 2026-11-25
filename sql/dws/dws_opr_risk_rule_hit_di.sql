-- dws.dws_opr_risk_rule_hit_di  风控规则命中日汇总
-- 粒度：travel_date × rule_id × action_type × dimension_type
-- 来源：dwd_opr_risk_event_di, dwd_opr_blacklist_log_di, dwd_opr_account_ban_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 3 · 规则翻译 2 · 待确认 5
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_opr_risk_rule_hit_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.rule_id,
  u.action_type,
  u.dimension_type,
  SUM(u.risk_hit_qty) AS risk_hit_qty,
  SUM(u.risk_block_qty) AS risk_block_qty,
  SUM(u.blacklist_add_qty) AS blacklist_add_qty,
  SUM(u.ban_qty) AS ban_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_opr_risk_event_di
  SELECT
    rule_id AS rule_id,
    action_type AS action_type,
    dimension_type AS dimension_type,
    COUNT(event_no) AS risk_hit_qty,
    COUNT(CASE WHEN 1 = 1 THEN event_no END) AS risk_block_qty,  -- 待确认：action='BLOCK'
    NULL AS blacklist_add_qty,
    NULL AS ban_qty
  FROM dwd.dwd_opr_risk_event_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY rule_id, action_type, dimension_type
  UNION ALL
  -- 来源：dwd_opr_blacklist_log_di
  SELECT
    rule_id AS rule_id,
    CAST(NULL AS STRING) AS action_type,
    dimension_type AS dimension_type,
    NULL AS risk_hit_qty,
    NULL AS risk_block_qty,
    COUNT(CASE WHEN 1 = 1 THEN blacklist_no END) AS blacklist_add_qty,  -- 待确认：新增
    NULL AS ban_qty
  FROM dwd.dwd_opr_blacklist_log_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY rule_id, dimension_type
  UNION ALL
  -- 来源：dwd_opr_account_ban_di
  SELECT
    rule_id AS rule_id,
    CAST(NULL AS STRING) AS action_type,
    CAST(NULL AS STRING) AS dimension_type,
    NULL AS risk_hit_qty,
    NULL AS risk_block_qty,
    NULL AS blacklist_add_qty,
    COUNT(ban_no) AS ban_qty
  FROM dwd.dwd_opr_account_ban_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY rule_id
) u
GROUP BY u.rule_id, u.action_type, u.dimension_type;
