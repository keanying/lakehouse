-- dws.dws_opr_risk_rule_hit_di  风控规则命中日汇总
-- 粒度：travel_date × rule_id × action_type × dimension_type
-- 来源：dwd_opr_risk_event_di, dwd_opr_blacklist_log_di, dwd_opr_account_ban_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 3 · 规则翻译 2 · 待确认 5
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_risk_event AS (                               -- 来源「风控事件明细」按粒度键预聚合
  SELECT
    rule_id AS rule_id,                           -- 风控规则ID
    action_type AS action_type,                   -- 处置动作
    dimension_type AS dimension_type,             -- 规则维度
    COUNT(event_no) AS risk_hit_qty,              -- 风控命中次数
    COUNT(CASE WHEN 1 = 1 THEN event_no END) AS risk_block_qty,  -- 风控拦截次数｜待确认：action='BLOCK'
    NULL AS blacklist_add_qty,
    NULL AS ban_qty
  FROM dwd.dwd_opr_risk_event_di s                -- 来源表「风控事件明细」
  WHERE s.travel_date = '${bizdate}'              -- 只取当日分区
  GROUP BY rule_id, action_type, dimension_type   -- 按粒度键汇总
),
src_blacklist_log AS (                            -- 来源「黑名单变更明细」按粒度键预聚合
  SELECT
    rule_id AS rule_id,                           -- 风控规则ID
    CAST(NULL AS STRING) AS action_type,
    dimension_type AS dimension_type,             -- 规则维度
    NULL AS risk_hit_qty,
    NULL AS risk_block_qty,
    COUNT(CASE WHEN 1 = 1 THEN blacklist_no END) AS blacklist_add_qty,  -- 新增黑名单数｜待确认：新增
    NULL AS ban_qty
  FROM dwd.dwd_opr_blacklist_log_di s             -- 来源表「黑名单变更明细」
  WHERE s.travel_date = '${bizdate}'              -- 只取当日分区
  GROUP BY rule_id, dimension_type                -- 按粒度键汇总
),
src_account_ban AS (                              -- 来源「账号封禁明细」按粒度键预聚合
  SELECT
    rule_id AS rule_id,                           -- 风控规则ID
    CAST(NULL AS STRING) AS action_type,
    CAST(NULL AS STRING) AS dimension_type,
    NULL AS risk_hit_qty,
    NULL AS risk_block_qty,
    NULL AS blacklist_add_qty,
    COUNT(ban_no) AS ban_qty                      -- 封禁数
  FROM dwd.dwd_opr_account_ban_di s               -- 来源表「账号封禁明细」
  WHERE s.travel_date = '${bizdate}'              -- 只取当日分区
  GROUP BY rule_id                                -- 按粒度键汇总
),
all_src AS (                                      -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_risk_event
  UNION ALL
  SELECT * FROM src_blacklist_log
  UNION ALL
  SELECT * FROM src_account_ban
)
INSERT OVERWRITE TABLE dws.dws_opr_risk_rule_hit_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.rule_id,                                      -- 风控规则ID
  u.action_type,                                  -- 处置动作
  u.dimension_type,                               -- 规则维度
  SUM(u.risk_hit_qty) AS risk_hit_qty,            -- 风控命中次数
  SUM(u.risk_block_qty) AS risk_block_qty,        -- 风控拦截次数
  SUM(u.blacklist_add_qty) AS blacklist_add_qty,  -- 新增黑名单数
  SUM(u.ban_qty) AS ban_qty,                      -- 封禁数
  CURRENT_TIMESTAMP() AS etl_time                 -- ETL 加载时间
FROM all_src u
GROUP BY u.rule_id, u.action_type, u.dimension_type;  -- 按粒度键汇总
