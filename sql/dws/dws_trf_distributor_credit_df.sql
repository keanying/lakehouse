-- dws.dws_trf_distributor_credit_df  分销关系授信快照
-- 粒度：travel_date × relation_no
-- 来源：dim_trf_distribution_relation_zip
-- 生成方式：Spark SQL / Hive；字段 5 个：直接翻译 1 · 规则翻译 1 · 待确认 3
-- 快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_trf_distributor_credit_df PARTITION (travel_date = '${bizdate}')
SELECT
  u.relation_no,
  SUM(u.credit_limit_amt) AS credit_limit_amt,
  SUM(u.credit_used_amt) AS credit_used_amt,
  SUM(u.credit_used_amt) * 100 / NULLIF(SUM(u.credit_limit_amt), 0) AS credit_usage_rate,
  SUM(u.new_distribution_relation_qty) AS new_distribution_relation_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dim_trf_distribution_relation_zip
  SELECT
    relation_no AS relation_no,
    NULL AS credit_limit_amt,  -- 待确认：credit_limit/100
    NULL AS credit_used_amt,  -- 待确认：credit_used/100
    COUNT(CASE WHEN 1 = 1 THEN relation_no END) AS new_distribution_relation_qty  -- 待确认：create_date in 周期
  FROM dim.dim_trf_distribution_relation_zip s
  WHERE s.travel_date = '${bizdate}' AND s.end_date = '9999-12-31'
  GROUP BY relation_no
) u
GROUP BY u.relation_no;
