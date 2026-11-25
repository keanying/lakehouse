-- dws.dws_ord_verify_point_flow_rt  核销点 分钟级客流
-- 粒度：seller_tenant_id × verify_point_id × 窗口
-- 来源：dwd_ord_verify_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 8 个：直接翻译 3 · 规则翻译 0 · 待确认 5
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_ord_verify_point_flow_rt                              -- 写入 StarRocks 目标表
SELECT
  u.travel_date,                                                          -- 数据日期
  u.window_start_time,                                                    -- 窗口开始时间
  u.window_end_time,                                                      -- 窗口结束时间
  u.seller_tenant_id,                                                     -- 卖家租户ID
  u.verify_point_id,                                                      -- 核销点ID
  SUM(u.verify_person_qty) AS verify_person_qty,                          -- 核销人次（入园人次）
  SUM(u.verify_fail_qty) AS verify_fail_qty,                              -- 核销失败次数
  SUM(u.verify_entitlement_qty) AS verify_entitlement_qty,                -- 核销权益次数
  SUM(u.duplicate_verify_qty) AS duplicate_verify_qty,                    -- 重复核销次数
  SUM(u.offline_conflict_qty) AS offline_conflict_qty,                    -- 离线核销冲突次数
  CURRENT_TIMESTAMP AS update_time                                        -- 最近一次写入时间
FROM (
  -- 来源：dwd_ord_verify_rt
  SELECT
    window_start AS window_start_time,                                    -- 窗口开始时间
    window_end AS window_end_time,                                        -- 窗口结束时间
    travel_date AS travel_date,                                           -- 数据日期
    seller_tenant_id AS seller_tenant_id,                                 -- 卖家租户ID
    verify_point_id AS verify_point_id,                                   -- 核销点ID
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_person_qty,       -- 核销人次（入园人次）｜待确认：SUCCESS（待补放行人数后改 sum(pass_count)）
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_fail_qty,         -- 核销失败次数｜待确认：verify_result in ('FAILED','DUPLICATE')
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_entitlement_qty,  -- 核销权益次数｜待确认：verify_result='SUCCESS'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS duplicate_verify_qty,    -- 重复核销次数｜待确认：verify_result='DUPLICATE'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS offline_conflict_qty     -- 离线核销冲突次数｜待确认：verify_type='OFFLINE' and verify_result='DUPLICATE'
  FROM TABLE(TUMBLE(TABLE dwd.dwd_ord_verify_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s  -- 按事件时间切 1 分钟滚动窗口
  GROUP BY window_start, window_end, travel_date, seller_tenant_id, verify_point_id  -- 按粒度键汇总
) u                                                                       -- 各来源合并后的明细
GROUP BY u.window_start_time, u.window_end_time, u.travel_date, u.seller_tenant_id, u.verify_point_id;  -- 按粒度键汇总
