-- dws.dws_trf_distributor_credit_rt  分销授信实时
-- 粒度：relation_no
-- 来源：dwd_trf_distribution_credit_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 4 个：直接翻译 2 · 规则翻译 0 · 待确认 2
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_trf_distributor_credit_rt
SELECT
  u.window_start_time,
  u.window_end_time,
  u.travel_date,
  u.relation_no,
  SUM(u.credit_limit_amt) AS credit_limit_amt,
  SUM(u.credit_used_amt) AS credit_used_amt,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_trf_distribution_credit_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    relation_no AS relation_no,
    NULL AS credit_limit_amt,  -- 待确认：credit_limit/100
    NULL AS credit_used_amt  -- 待确认：credit_used/100
  FROM TABLE(TUMBLE(TABLE dwd.dwd_trf_distribution_credit_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, relation_no
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.relation_no;
