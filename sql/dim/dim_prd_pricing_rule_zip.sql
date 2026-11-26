-- dim.dim_prd_pricing_rule_zip  定价规则维度
-- 粒度：1行=1条规则×1个有效区间
-- 来源：ods_prd_pricing_rule_df
-- 生成方式：Spark SQL / Hive（拉链表）；字段 14 个：直接翻译 14 · 规则翻译 0 · 待确认 0
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为全量快照，消失的主键闭链

WITH
pricing_rule_src AS (                                        -- 主表「定价规则」，只取用到的列
  SELECT base_price_ref, calculator, create_time, effective_from, effective_to, id, params, priority,
         rule_no, rule_type, sku_id, tenant_id, update_time
  FROM ods.ods_prd_pricing_rule_df
  WHERE travel_date = '${bizdate}'                           -- 只取当日分区
),
src AS (                                                     -- 今日最新状态（与拉链字段一一对应）
  SELECT 
    pricing_rule_src.id             AS pricing_rule_id,      -- 定价规则ID（源表主键 id）
    pricing_rule_src.rule_no        AS rule_no,              -- 规则编号
    pricing_rule_src.sku_id         AS sku_id,               -- SKU ID
    pricing_rule_src.rule_type      AS rule_type,            -- 规则类型
    pricing_rule_src.base_price_ref AS base_price_ref_type,  -- 基准价引用
    pricing_rule_src.calculator     AS calculator_type,      -- 计算方式
    pricing_rule_src.params         AS rule_param_desc,      -- 计算参数（JSON
    pricing_rule_src.priority       AS priority_no,          -- 优先级
    pricing_rule_src.effective_from AS effective_start_time,  -- 生效起始
    pricing_rule_src.effective_to   AS effective_end_time,   -- 生效终止
    pricing_rule_src.tenant_id      AS tenant_id,            -- 租户ID（分库维度）
    pricing_rule_src.create_time    AS create_time,          -- 创建时间
    pricing_rule_src.update_time    AS update_time           -- 更新时间
  FROM pricing_rule_src
),
src_hash AS (                                                -- 今日状态的行哈希（比较是否变化）
  SELECT s.*, MD5(CONCAT_WS('|', CAST(rule_no AS STRING), CAST(sku_id AS STRING), CAST(rule_type AS STRING), CAST(base_price_ref_type AS STRING), CAST(calculator_type AS STRING), CAST(rule_param_desc AS STRING), CAST(priority_no AS STRING), CAST(effective_start_time AS STRING), CAST(effective_end_time AS STRING), CAST(tenant_id AS STRING), CAST(create_time AS STRING), CAST(update_time AS STRING))) AS row_hash
  FROM src s
),
his AS (                                                     -- 昨日拉链及其行哈希
  SELECT h.*, MD5(CONCAT_WS('|', CAST(h.rule_no AS STRING), CAST(h.sku_id AS STRING), CAST(h.rule_type AS STRING), CAST(h.base_price_ref_type AS STRING), CAST(h.calculator_type AS STRING), CAST(h.rule_param_desc AS STRING), CAST(h.priority_no AS STRING), CAST(h.effective_start_time AS STRING), CAST(h.effective_end_time AS STRING), CAST(h.tenant_id AS STRING), CAST(h.create_time AS STRING), CAST(h.update_time AS STRING))) AS row_hash
  FROM dim.dim_prd_pricing_rule_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_prd_pricing_rule_zip PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- ① 历史记录：当前有效版本若有变化或已删除则闭链（结束日 = 昨天）
SELECT h.pricing_rule_id, h.rule_no, h.sku_id, h.rule_type, h.base_price_ref_type, h.calculator_type,
       h.rule_param_desc, h.priority_no, h.effective_start_time, h.effective_end_time, h.tenant_id,
       h.create_time, h.update_time,
  h.start_date,                                              -- 拉链开始日期
  CASE WHEN h.end_date = '9999-12-31' AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,  -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time                            -- ETL 加载时间
FROM his h
LEFT JOIN src_hash s ON s.pricing_rule_id = h.pricing_rule_id
UNION ALL
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.pricing_rule_id, s.rule_no, s.sku_id, s.rule_type, s.base_price_ref_type, s.calculator_type,
       s.rule_param_desc, s.priority_no, s.effective_start_time, s.effective_end_time, s.tenant_id,
       s.create_time, s.update_time,
  '${bizdate_dash}' AS start_date,                           -- 拉链开始日期
  '9999-12-31' AS end_date,                                  -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time                            -- ETL 加载时间
FROM src_hash s
LEFT JOIN his h ON h.pricing_rule_id = s.pricing_rule_id AND h.end_date = '9999-12-31'
WHERE h.pricing_rule_id IS NULL OR h.row_hash <> s.row_hash;
