-- ads.ads_opr_risk_monitor_di  风控监控
-- 粒度：travel_date × rule_id × action_type
-- 来源：dws_opr_risk_rule_hit_di, dws_opr_audit_action_di, dws_ord_tenant_sku_verify_di
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 11 · 规则翻译 3 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_risk_rule_hit AS (                              -- 来源「风控规则命中日汇总」按粒度键预聚合
  SELECT
    rule_id AS rule_id,                             -- 风控规则ID
    action_type AS action_type,                     -- 处置动作
    SUM(risk_hit_qty) AS risk_hit_qty,              -- 风控命中次数（日）
    SUM(risk_block_qty) AS risk_block_qty,          -- 风控拦截次数（日）
    SUM(risk_block_qty) AS risk_block_numerator_qty,  -- 风控拦截率分子（日）
    SUM(risk_hit_qty) AS risk_block_denominator_qty,  -- 风控拦截率分母（日）
    SUM(blacklist_add_qty) AS blacklist_add_qty,    -- 新增黑名单数（日）
    SUM(ban_qty) AS ban_qty,                        -- 封禁数（日）
    NULL AS night_action_qty,
    NULL AS duplicate_verify_qty
  FROM dws.dws_opr_risk_rule_hit_di s               -- 来源表「风控规则命中日汇总」
  WHERE s.travel_date = '${bizdate}'                -- 只取当日分区
  GROUP BY rule_id, action_type                     -- 按粒度键汇总
),
src_audit_action AS (                               -- 来源「操作审计日汇总」按粒度键预聚合
  SELECT
    CAST(NULL AS BIGINT) AS rule_id,
    action_type AS action_type,                     -- 处置动作
    NULL AS risk_hit_qty,
    NULL AS risk_block_qty,
    NULL AS risk_block_numerator_qty,
    NULL AS risk_block_denominator_qty,
    NULL AS blacklist_add_qty,
    NULL AS ban_qty,
    SUM(night_action_qty) AS night_action_qty,      -- 凌晨操作次数（日）
    NULL AS duplicate_verify_qty
  FROM dws.dws_opr_audit_action_di s                -- 来源表「操作审计日汇总」
  WHERE s.travel_date = '${bizdate}'                -- 只取当日分区
  GROUP BY action_type                              -- 按粒度键汇总
),
src_tenant_sku_verify AS (                          -- 来源「商户×SKU×核销点 核销日汇总」按粒度键预聚合
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
    SUM(duplicate_verify_qty) AS duplicate_verify_qty  -- 重复核销次数（日）
  FROM dws.dws_ord_tenant_sku_verify_di s           -- 来源表「商户×SKU×核销点 核销日汇总」
  WHERE s.travel_date = '${bizdate}'                -- 只取当日分区
),
all_src AS (                                        -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_risk_rule_hit
  UNION ALL
  SELECT * FROM src_audit_action
  UNION ALL
  SELECT * FROM src_tenant_sku_verify
),
merged AS (                                         -- 按粒度键汇总，计算派生指标
  SELECT
    u.rule_id,                                      -- 风控规则ID
    u.action_type,                                  -- 处置动作
    SUM(u.risk_hit_qty) AS risk_hit_qty,            -- 风控命中次数（日）
    SUM(u.risk_block_qty) AS risk_block_qty,        -- 风控拦截次数（日）
    SUM(u.risk_block_numerator_qty) AS risk_block_numerator_qty,  -- 风控拦截率分子（日）
    SUM(u.risk_block_denominator_qty) AS risk_block_denominator_qty,  -- 风控拦截率分母（日）
    SUM(u.blacklist_add_qty) AS blacklist_add_qty,  -- 新增黑名单数（日）
    SUM(u.ban_qty) AS ban_qty,                      -- 封禁数（日）
    SUM(u.night_action_qty) AS night_action_qty,    -- 凌晨操作次数（日）
    SUM(u.duplicate_verify_qty) AS duplicate_verify_qty,  -- 重复核销次数（日）
    CURRENT_TIMESTAMP() AS etl_time                 -- ETL 加载时间
  FROM all_src u
  GROUP BY u.rule_id, u.action_type                 -- 按粒度键汇总
),
risk_rule_dim AS (                                  -- 「风控规则维度」当日数据，只取名称类字段
  SELECT risk_rule_id, rule_name
  FROM dim.dim_opr_risk_rule_df
  WHERE travel_date = '${bizdate}'                  -- 只取当日分区
)
INSERT OVERWRITE TABLE ads.ads_opr_risk_monitor_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(risk_rule_dim) */
  merged.rule_id,                                   -- 风控规则ID
  merged.action_type,                               -- 处置动作
  risk_rule_dim.rule_name AS rule_name,             -- 规则名称
  merged.risk_hit_qty,                              -- 风控命中次数（日）
  merged.risk_block_qty,                            -- 风控拦截次数（日）
  merged.risk_block_numerator_qty,                  -- 风控拦截率分子（日）
  merged.risk_block_denominator_qty,                -- 风控拦截率分母（日）
  merged.blacklist_add_qty,                         -- 新增黑名单数（日）
  merged.ban_qty,                                   -- 封禁数（日）
  merged.night_action_qty,                          -- 凌晨操作次数（日）
  merged.duplicate_verify_qty,                      -- 重复核销次数（日）
  merged.etl_time                                   -- ETL 加载时间
FROM merged
LEFT JOIN risk_rule_dim                             -- 关联「风控规则维度」，补 rule_name
  ON risk_rule_dim.risk_rule_id = merged.rule_id;   -- 按 rule_id→risk_rule_id 关联
