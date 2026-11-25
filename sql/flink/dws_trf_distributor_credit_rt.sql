-- dws.dws_trf_distributor_credit_rt  分销授信实时
-- 粒度：relation_no
-- 来源：dwd_trf_distribution_credit_rt
-- 生成方式：Flink SQL（持续聚合（快照类，按主键更新） → StarRocks 主键模型表）；字段 4 个：直接翻译 2 · 规则翻译 0 · 待确认 2
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_trf_distributor_credit_rt  -- 写入 StarRocks 目标表
SELECT
  u.travel_date,                              -- 数据日期
  u.relation_no,                              -- 分销关系编号
  SUM(u.credit_limit_amt) AS credit_limit_amt,  -- 授信额度
  SUM(u.credit_used_amt) AS credit_used_amt,  -- 已用授信
  CURRENT_TIMESTAMP AS update_time            -- 最近一次写入时间
FROM (
  -- 来源：dwd_trf_distribution_credit_rt
  SELECT
    travel_date AS travel_date,               -- 数据日期
    relation_no AS relation_no,               -- 分销关系编号
    NULL AS credit_limit_amt,                 -- 授信额度｜待确认：credit_limit/100
    NULL AS credit_used_amt                   -- 已用授信｜待确认：credit_used/100
  FROM dwd.dwd_trf_distribution_credit_rt s   -- 来源表「实时分销授信」
  GROUP BY travel_date, relation_no           -- 按粒度键汇总
) u                                           -- 各来源合并后的明细
GROUP BY u.travel_date, u.relation_no;        -- 按粒度键汇总
