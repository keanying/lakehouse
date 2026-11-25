-- dws.dws_ord_verify_point_flow_rt  核销点 分钟级客流
-- 粒度：seller_tenant_id × verify_point_id × 窗口
-- 来源：dwd_ord_verify_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 8 个：直接翻译 3 · 规则翻译 0 · 待确认 5
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_ord_verify_point_flow_rt
SELECT
  u.travel_date,
  u.window_start_time,
  u.window_end_time,
  u.seller_tenant_id,
  u.verify_point_id,
  SUM(u.verify_person_qty) AS verify_person_qty,
  SUM(u.verify_fail_qty) AS verify_fail_qty,
  SUM(u.verify_entitlement_qty) AS verify_entitlement_qty,
  SUM(u.duplicate_verify_qty) AS duplicate_verify_qty,
  SUM(u.offline_conflict_qty) AS offline_conflict_qty,
  CURRENT_TIMESTAMP AS update_time
FROM (
  -- 来源：dwd_ord_verify_rt
  SELECT
    window_start AS window_start_time,
    window_end AS window_end_time,
    travel_date AS travel_date,
    seller_tenant_id AS seller_tenant_id,
    verify_point_id AS verify_point_id,
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_person_qty,  -- 待确认：SUCCESS（待补放行人数后改 sum(pass_count)）
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_fail_qty,  -- 待确认：verify_result in ('FAILED','DUPLICATE')
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_entitlement_qty,  -- 待确认：verify_result='SUCCESS'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS duplicate_verify_qty,  -- 待确认：verify_result='DUPLICATE'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS offline_conflict_qty  -- 待确认：verify_type='OFFLINE' and verify_result='DUPLICATE'
  FROM TABLE(TUMBLE(TABLE dwd.dwd_ord_verify_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s
  GROUP BY window_start, window_end, travel_date, seller_tenant_id, verify_point_id
) u
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.seller_tenant_id, u.verify_point_id;
