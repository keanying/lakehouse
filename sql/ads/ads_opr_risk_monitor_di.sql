-- ads.ads_opr_risk_monitor_di  风控监控
-- 粒度：travel_date × rule_id × action_type
-- 来源：dws_opr_risk_rule_hit_di, dws_opr_audit_action_di, dws_ord_tenant_sku_verify_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 11 · 规则翻译 0 · 待确认 3
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE ads.ads_opr_risk_monitor_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.rule_id,                                    -- 风控规则ID
  x.action_type,                                -- 处置动作
  d1.rule_name AS rule_name,                    -- 规则名称
  x.risk_hit_qty,                               -- 风控命中次数（日）
  x.risk_block_qty,                             -- 风控拦截次数（日）
  x.risk_block_numerator_qty,                   -- 风控拦截率分子（日）
  x.risk_block_denominator_qty,                 -- 风控拦截率分母（日）
  x.blacklist_add_qty,                          -- 新增黑名单数（日）
  x.ban_qty,                                    -- 封禁数（日）
  x.night_action_qty,                           -- 凌晨操作次数（日）
  x.duplicate_verify_qty,                       -- 重复核销次数（日）
  x.etl_time                                    -- ETL 加载时间
FROM (
SELECT
  u.rule_id,                                    -- 风控规则ID
  u.action_type,                                -- 处置动作
  SUM(u.risk_hit_qty) AS risk_hit_qty,          -- 风控命中次数（日）
  SUM(u.risk_block_qty) AS risk_block_qty,      -- 风控拦截次数（日）
  SUM(u.risk_block_numerator_qty) AS risk_block_numerator_qty,  -- 风控拦截率分子（日）
  SUM(u.risk_block_denominator_qty) AS risk_block_denominator_qty,  -- 风控拦截率分母（日）
  SUM(u.blacklist_add_qty) AS blacklist_add_qty,  -- 新增黑名单数（日）
  SUM(u.ban_qty) AS ban_qty,                    -- 封禁数（日）
  SUM(u.night_action_qty) AS night_action_qty,  -- 凌晨操作次数（日）
  SUM(u.duplicate_verify_qty) AS duplicate_verify_qty,  -- 重复核销次数（日）
  CURRENT_TIMESTAMP() AS etl_time               -- ETL 加载时间
FROM (
  -- 来源：dws_opr_risk_rule_hit_di
  SELECT
    rule_id AS rule_id,                         -- 风控规则ID
    action_type AS action_type,                 -- 处置动作
    SUM(risk_hit_qty) AS risk_hit_qty,          -- 风控命中次数（日）
    SUM(risk_block_qty) AS risk_block_qty,      -- 风控拦截次数（日）
    SUM(risk_block_qty) AS risk_block_numerator_qty,  -- 风控拦截率分子（日）
    SUM(risk_hit_qty) AS risk_block_denominator_qty,  -- 风控拦截率分母（日）
    SUM(blacklist_add_qty) AS blacklist_add_qty,  -- 新增黑名单数（日）
    SUM(ban_qty) AS ban_qty,                    -- 封禁数（日）
    NULL AS night_action_qty,                   -- 凌晨操作次数（日）
    NULL AS duplicate_verify_qty                -- 重复核销次数（日）
  FROM dws.dws_opr_risk_rule_hit_di s           -- 来源表「风控规则命中日汇总」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
  GROUP BY rule_id, action_type                 -- 按粒度键汇总
  UNION ALL                                     -- 合并各来源
  -- 来源：dws_opr_audit_action_di
  SELECT
    CAST(NULL AS BIGINT) AS rule_id,            -- 风控规则ID
    action_type AS action_type,                 -- 处置动作
    NULL AS risk_hit_qty,                       -- 风控命中次数（日）
    NULL AS risk_block_qty,                     -- 风控拦截次数（日）
    NULL AS risk_block_numerator_qty,           -- 风控拦截率分子（日）
    NULL AS risk_block_denominator_qty,         -- 风控拦截率分母（日）
    NULL AS blacklist_add_qty,                  -- 新增黑名单数（日）
    NULL AS ban_qty,                            -- 封禁数（日）
    SUM(night_action_qty) AS night_action_qty,  -- 凌晨操作次数（日）
    NULL AS duplicate_verify_qty                -- 重复核销次数（日）
  FROM dws.dws_opr_audit_action_di s            -- 来源表「操作审计日汇总」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
  GROUP BY action_type                          -- 按粒度键汇总
  UNION ALL                                     -- 合并各来源
  -- 来源：dws_ord_tenant_sku_verify_di
  SELECT
    CAST(NULL AS BIGINT) AS rule_id,            -- 风控规则ID
    CAST(NULL AS STRING) AS action_type,        -- 处置动作
    NULL AS risk_hit_qty,                       -- 风控命中次数（日）
    NULL AS risk_block_qty,                     -- 风控拦截次数（日）
    NULL AS risk_block_numerator_qty,           -- 风控拦截率分子（日）
    NULL AS risk_block_denominator_qty,         -- 风控拦截率分母（日）
    NULL AS blacklist_add_qty,                  -- 新增黑名单数（日）
    NULL AS ban_qty,                            -- 封禁数（日）
    NULL AS night_action_qty,                   -- 凌晨操作次数（日）
    SUM(duplicate_verify_qty) AS duplicate_verify_qty  -- 重复核销次数（日）
  FROM dws.dws_ord_tenant_sku_verify_di s       -- 来源表「商户×SKU×核销点 核销日汇总」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
) u                                             -- 各来源合并后的明细
GROUP BY u.rule_id, u.action_type               -- 按粒度键汇总
) x                                             -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_opr_risk_rule_df d1 ON d1.risk_rule_id = x.rule_id AND d1.travel_date = '${bizdate}';  -- 关联「风控规则维度」，取维度名称
