-- dws.dws_cus_tenant_growth_rt  游客实时增长
-- 粒度：tenant_id × register_channel_id × 窗口
-- 来源：dwd_cus_customer_register_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 4 个：直接翻译 3 · 规则翻译 0 · 待确认 1
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_cus_tenant_growth_rt
SELECT
  u.travel_date,
  u.window_start_time,
  u.window_end_time,
  u.tenant_id,
  u.register_channel_id,
  SUM(u.new_customer_qty) AS new_customer_qty,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_cus_customer_register_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    register_tenant_id AS tenant_id,
    register_channel_id AS register_channel_id,
    COUNT(CASE WHEN 1 = 1 THEN customer_id END) AS new_customer_qty  -- 待确认：kind='REAL'
  FROM TABLE(TUMBLE(TABLE dwd.dwd_cus_customer_register_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, register_tenant_id, register_channel_id
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.tenant_id, u.register_channel_id;
