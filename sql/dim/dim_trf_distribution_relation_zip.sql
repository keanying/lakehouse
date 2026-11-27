-- dim.dim_trf_distribution_relation_zip  分销关系维度
-- 粒度：1行=1条分销关系×1个有效区间
-- 来源：ods_trf_distribution_relation_df
-- 生成方式：Spark SQL / Hive（拉链表）；字段 19 个：直接翻译 13 · 规则翻译 6 · 待确认 0
-- 拉链：比对今日源数据与昨日拉链的行哈希，变化的旧版本闭链、新版本开链；源为全量快照，消失的主键闭链

WITH
distribution_relation_src AS (                                                    -- 主表「分销关系」，只取用到的列
  SELECT create_time, credit_limit, credit_used, distribution_mode, distributor_tenant_id, id,
         parent_relation_id, payment_mode, relation_no, relation_status, supplier_tenant_id, update_time
  FROM ods.ods_trf_distribution_relation_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
src AS (                                                                          -- 今日最新状态（与拉链字段一一对应）
  SELECT 
    distribution_relation_src.id                                 AS relation_id,  -- 分销关系ID（源表主键 id）
    distribution_relation_src.relation_no                        AS relation_no,  -- 分销关系编号
    distribution_relation_src.supplier_tenant_id                 AS supplier_tenant_id,  -- 供应商租户ID
    distribution_relation_src.distributor_tenant_id              AS distributor_tenant_id,  -- 分销商租户ID
    distribution_relation_src.parent_relation_id                 AS parent_relation_id,  -- 上级分销关系ID（4级采购链）
    distribution_relation_src.distribution_mode                  AS distribution_mode_type,  -- 分销模式
    distribution_relation_src.payment_mode                       AS payment_mode_type,  -- 支付模式
    ROUND(distribution_relation_src.credit_limit / 100, 2)       AS credit_limit_amt,  -- 授信额度
    ROUND(distribution_relation_src.credit_used / 100, 2)        AS credit_used_amt,  -- 已用授信（元）
    distribution_relation_src.relation_status                    AS relation_status,  -- 状态
    distribution_relation_src.create_time                        AS create_time,  -- 创建时间
    distribution_relation_src.update_time                        AS update_time,  -- 更新时间
    (1 + IF(p1.id IS NULL, 0, 1) + IF(p2.id IS NULL, 0, 1) + IF(p3.id IS NULL, 0, 1)) AS chain_level_no,  -- 本关系在采购链中的层级｜口径：本关系往上逐级找上级关系（parent_relation_id，最多 4 级）的层数
    CASE (1 + IF(p1.id IS NULL, 0, 1) + IF(p2.id IS NULL, 0, 1) + IF(p3.id IS NULL, 0, 1))  -- 1 级｜口径：最顶层关系的供应商 = 源头供应商
        WHEN 1 THEN distribution_relation_src.supplier_tenant_id
        WHEN 2 THEN p1.supplier_tenant_id
        WHEN 3 THEN p2.supplier_tenant_id
        WHEN 4 THEN p3.supplier_tenant_id
    END AS level1_tenant_id,                                                      -- 1 级（源头供应商）租户ID
    CASE (1 + IF(p1.id IS NULL, 0, 1) + IF(p2.id IS NULL, 0, 1) + IF(p3.id IS NULL, 0, 1))  -- 2 级分销商租户ID｜口径：最顶层关系的分销商
        WHEN 1 THEN distribution_relation_src.distributor_tenant_id
        WHEN 2 THEN p1.distributor_tenant_id
        WHEN 3 THEN p2.distributor_tenant_id
        WHEN 4 THEN p3.distributor_tenant_id
    END AS level2_tenant_id,                                                      -- 2 级分销商租户ID
    CASE (1 + IF(p1.id IS NULL, 0, 1) + IF(p2.id IS NULL, 0, 1) + IF(p3.id IS NULL, 0, 1))  -- 3 级分销商租户ID｜口径：第 2 层关系的分销商
        WHEN 2 THEN distribution_relation_src.distributor_tenant_id
        WHEN 3 THEN p1.distributor_tenant_id
        WHEN 4 THEN p2.distributor_tenant_id
    END AS level3_tenant_id,                                                      -- 3 级分销商租户ID
    CASE (1 + IF(p1.id IS NULL, 0, 1) + IF(p2.id IS NULL, 0, 1) + IF(p3.id IS NULL, 0, 1))  -- 4 级分销商租户ID｜口径：第 3 层关系的分销商
        WHEN 3 THEN distribution_relation_src.distributor_tenant_id
        WHEN 4 THEN p1.distributor_tenant_id
    END AS level4_tenant_id,                                                      -- 4 级分销商租户ID
    ROUND((distribution_relation_src.credit_limit - distribution_relation_src.credit_used) / 100, 2) AS credit_available_amt  -- 剩余授信额度
  FROM distribution_relation_src
      LEFT JOIN distribution_relation_src p1 ON p1.id = distribution_relation_src.parent_relation_id  -- 上一级关系
      LEFT JOIN distribution_relation_src p2 ON p2.id = p1.parent_relation_id
      LEFT JOIN distribution_relation_src p3 ON p3.id = p2.parent_relation_id
),
src_hash AS (                                                                     -- 今日状态的行哈希（比较是否变化）
  SELECT s.*,
         MD5(CONCAT_WS(                                                           -- 行哈希：除拉链键外全部属性拼接后 MD5，判断是否变化
             '|',
             CAST(relation_no AS STRING),
             CAST(supplier_tenant_id AS STRING),
             CAST(distributor_tenant_id AS STRING),
             CAST(parent_relation_id AS STRING),
             CAST(distribution_mode_type AS STRING),
             CAST(payment_mode_type AS STRING),
             CAST(credit_limit_amt AS STRING),
             CAST(credit_used_amt AS STRING),
             CAST(relation_status AS STRING),
             CAST(create_time AS STRING),
             CAST(update_time AS STRING),
             CAST(chain_level_no AS STRING),
             CAST(level1_tenant_id AS STRING),
             CAST(level2_tenant_id AS STRING),
             CAST(level3_tenant_id AS STRING),
             CAST(level4_tenant_id AS STRING),
             CAST(credit_available_amt AS STRING)
         )) AS row_hash                                                           -- 行哈希：除拉链键外全部属性拼接后 MD5，判断是否变化
  FROM src s
),
his AS (                                                                          -- 昨日拉链及其行哈希
  SELECT h.*,
         MD5(CONCAT_WS(                                                           -- 行哈希：除拉链键外全部属性拼接后 MD5，判断是否变化
             '|',
             CAST(h.relation_no AS STRING),
             CAST(h.supplier_tenant_id AS STRING),
             CAST(h.distributor_tenant_id AS STRING),
             CAST(h.parent_relation_id AS STRING),
             CAST(h.distribution_mode_type AS STRING),
             CAST(h.payment_mode_type AS STRING),
             CAST(h.credit_limit_amt AS STRING),
             CAST(h.credit_used_amt AS STRING),
             CAST(h.relation_status AS STRING),
             CAST(h.create_time AS STRING),
             CAST(h.update_time AS STRING),
             CAST(h.chain_level_no AS STRING),
             CAST(h.level1_tenant_id AS STRING),
             CAST(h.level2_tenant_id AS STRING),
             CAST(h.level3_tenant_id AS STRING),
             CAST(h.level4_tenant_id AS STRING),
             CAST(h.credit_available_amt AS STRING)
         )) AS row_hash                                                           -- 行哈希：除拉链键外全部属性拼接后 MD5，判断是否变化
  FROM dim.dim_trf_distribution_relation_zip h
  WHERE h.travel_date = '${bizdate_prev}'
)
INSERT OVERWRITE TABLE dim.dim_trf_distribution_relation_zip PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- ① 历史记录：当前有效版本若有变化或已删除则闭链（结束日 = 昨天）
SELECT h.relation_id, h.relation_no, h.supplier_tenant_id, h.distributor_tenant_id,
       h.parent_relation_id, h.distribution_mode_type, h.payment_mode_type, h.credit_limit_amt,
       h.credit_used_amt, h.relation_status, h.create_time, h.update_time, h.chain_level_no,
       h.level1_tenant_id, h.level2_tenant_id, h.level3_tenant_id, h.level4_tenant_id,
       h.credit_available_amt,                                                    -- 剩余授信额度
  h.start_date,                                                                   -- 拉链开始日期
  CASE WHEN h.end_date = '9999-12-31' AND (s.row_hash IS NULL OR s.row_hash <> h.row_hash)
       THEN '${bizdate_prev_dash}' ELSE h.end_date END AS end_date,               -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM his h
LEFT JOIN src_hash s ON s.relation_id = h.relation_id
UNION ALL
-- ② 新增或变化的记录开新链（开始日 = 今天，结束日 = 9999-12-31）
SELECT s.relation_id, s.relation_no, s.supplier_tenant_id, s.distributor_tenant_id,
       s.parent_relation_id, s.distribution_mode_type, s.payment_mode_type, s.credit_limit_amt,
       s.credit_used_amt, s.relation_status, s.create_time, s.update_time, s.chain_level_no,
       s.level1_tenant_id, s.level2_tenant_id, s.level3_tenant_id, s.level4_tenant_id,
       s.credit_available_amt,                                                    -- 剩余授信额度
  '${bizdate_dash}' AS start_date,                                                -- 拉链开始日期
  '9999-12-31' AS end_date,                                                       -- 拉链结束日期
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM src_hash s
LEFT JOIN his h ON h.relation_id = s.relation_id AND h.end_date = '9999-12-31'
WHERE h.relation_id IS NULL OR h.row_hash <> s.row_hash;
