-- dws.dws_trf_distributor_credit_df  分销关系授信快照
-- 粒度：travel_date × relation_no
-- 来源：dim_trf_distribution_relation_zip
-- 生成方式：Spark SQL / Hive；字段 5 个：直接翻译 1 · 规则翻译 1 · 待确认 3
-- 来源先按粒度键预聚合；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_distribution_relation AS (                                                   -- 来源「分销关系维度」按粒度键预聚合
  SELECT
    relation_no AS relation_no,                                                  -- 分销关系编号
    NULL AS credit_limit_amt,                                                    -- 待确认：credit_limit/100
    NULL AS credit_used_amt,                                                     -- 待确认：credit_used/100
    COUNT(CASE WHEN 1 = 1 THEN relation_no END) AS new_distribution_relation_qty  -- 新建分销关系数｜待确认：create_date in 周期
  FROM dim.dim_trf_distribution_relation_zip s                                   -- 来源表「分销关系维度」
  WHERE s.travel_date = '${bizdate}' AND s.end_date = '9999-12-31'               -- 取当日分区里的拉链当前有效版本
  GROUP BY relation_no                                                           -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_trf_distributor_credit_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.relation_no,                                                                 -- 分销关系编号
  u.credit_limit_amt,                                                            -- 授信额度
  u.credit_used_amt,                                                             -- 已用授信
  u.credit_used_amt * 100 / NULLIF(u.credit_limit_amt, 0) AS credit_usage_rate,  -- 授信使用率
  u.new_distribution_relation_qty,                                               -- 新建分销关系数
  CURRENT_TIMESTAMP() AS etl_time                                                -- ETL 加载时间
FROM src_distribution_relation u;
