-- dws.dws_ord_tenant_sku_verify_rt  商户×SKU 实时核销
-- 粒度：seller_tenant_id × sku_id × 窗口
-- 来源：dwd_ord_verify_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 7 个：直接翻译 3 · 规则翻译 0 · 待确认 4
-- 来源先按粒度键预聚合
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dws.dws_ord_tenant_sku_verify_rt                              -- 写入 StarRocks 目标表
WITH
src_verify AS (                                                           -- 来源「实时核销明细」按粒度键预聚合（1 分钟滚动窗口）
  SELECT
    window_start AS window_start_time,                                    -- 窗口开始时间
    window_end AS window_end_time,                                        -- 窗口结束时间
    travel_date AS travel_date,                                           -- 数据日期
    seller_tenant_id AS seller_tenant_id,                                 -- 卖家租户ID
    sku_id AS sku_id,                                                     -- SKU ID
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS verify_ticket_qty,  -- 核销票数｜待确认：verify_result='SUCCESS'
    NULL AS verify_amt,                                                   -- 待确认：sum(unit_price_amt) of verified tickets（同票只计1次）（与离线同一口径 A021）
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_entitlement_qty,  -- 核销权益次数｜待确认：verify_result='SUCCESS'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_fail_qty          -- 核销失败次数｜待确认：verify_result in ('FAILED','DUPLICATE')
  FROM TABLE(TUMBLE(TABLE dwd.dwd_ord_verify_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s  -- 按事件时间切 1 分钟滚动窗口
  GROUP BY window_start, window_end, travel_date, seller_tenant_id, sku_id  -- 按粒度键汇总
)
SELECT
  u.travel_date,                                                          -- 数据日期
  u.window_start_time,                                                    -- 窗口开始时间
  u.window_end_time,                                                      -- 窗口结束时间
  u.seller_tenant_id,                                                     -- 卖家租户ID
  u.sku_id,                                                               -- SKU ID
  u.verify_ticket_qty,                                                    -- 核销票数
  u.verify_amt,                                                           -- 核销金额
  u.verify_entitlement_qty,                                               -- 核销权益次数
  u.verify_fail_qty,                                                      -- 核销失败次数
  CURRENT_TIMESTAMP AS update_time                                        -- 最近一次写入时间
FROM src_verify u;
