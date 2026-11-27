-- dws.dws_trf_distributor_credit_rt  分销授信实时
-- 粒度：relation_no
-- 来源：dwd_trf_distribution_credit_rt
-- 生成方式：Flink SQL（持续聚合（快照类，按主键更新） → StarRocks 主键模型表）；字段 4 个：直接翻译 2 · 规则翻译 2 · 待确认 0
-- 来源先按粒度键预聚合

INSERT INTO dws.dws_trf_distributor_credit_rt  -- 写入 StarRocks 目标表
WITH
src_distribution_credit AS (                   -- 来源「实时分销授信」按粒度键预聚合
  SELECT
    travel_date AS travel_date,                -- 数据日期
    relation_no AS relation_no,                -- 分销关系编号
    SUM(credit_limit_amt) AS credit_limit_amt,  -- 授信额度
    SUM(credit_used_amt) AS credit_used_amt    -- 已用授信
  FROM dwd.dwd_trf_distribution_credit_rt s    -- 来源表「实时分销授信」
  GROUP BY travel_date, relation_no            -- 按粒度键汇总
)
SELECT
  u.travel_date,                               -- 数据日期
  u.relation_no,                               -- 分销关系编号
  u.credit_limit_amt,                          -- 授信额度
  u.credit_used_amt,                           -- 已用授信
  CURRENT_TIMESTAMP AS update_time             -- 最近一次写入时间
FROM src_distribution_credit u;
