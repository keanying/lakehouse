-- dws.dws_ord_tenant_sku_verify_rt  商户×SKU 实时核销
-- 粒度：seller_tenant_id × sku_id × 窗口
-- 来源：dwd_ord_verify_rt
-- 生成方式：Flink SQL（1 分钟滚动窗口聚合 → StarRocks 主键模型表）；字段 7 个：直接翻译 3 · 规则翻译 4 · 待确认 0
-- 来源先按粒度键预聚合

INSERT INTO dws.dws_ord_tenant_sku_verify_rt                                      -- 写入 StarRocks 目标表
WITH
src_verify AS (                                                                   -- 来源「实时核销明细」按粒度键预聚合（1 分钟滚动窗口）
  SELECT
    window_start AS window_start_time,                                            -- 窗口开始时间
    window_end AS window_end_time,                                                -- 窗口结束时间
    travel_date AS travel_date,                                                   -- 数据日期
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    sku_id AS sku_id,                                                             -- SKU ID
    COUNT(DISTINCT CASE WHEN verify_result_type='SUCCESS' THEN ticket_no END) AS verify_ticket_qty,  -- 核销票数
    SUM(CASE WHEN verify_result_type = 'SUCCESS' THEN verify_amt END) AS verify_amt,  -- 核销金额｜口径：核销成功的核销金额（DWD 已按可核销次数分摊）
    COUNT(CASE WHEN verify_result_type='SUCCESS' THEN verify_no END) AS verify_entitlement_qty,  -- 核销权益次数
    COUNT(CASE WHEN verify_result_type in ('FAILED','DUPLICATE') THEN verify_no END) AS verify_fail_qty  -- 核销失败次数
  FROM TABLE(TUMBLE(TABLE dwd.dwd_ord_verify_rt, DESCRIPTOR(event_time), INTERVAL '1' MINUTE)) s  -- 按事件时间切 1 分钟滚动窗口
  GROUP BY window_start, window_end, travel_date, seller_tenant_id, sku_id        -- 按粒度键汇总
)
SELECT
  u.travel_date,                                                                  -- 数据日期
  u.window_start_time,                                                            -- 窗口开始时间
  u.window_end_time,                                                              -- 窗口结束时间
  u.seller_tenant_id,                                                             -- 卖家租户ID
  u.sku_id,                                                                       -- SKU ID
  u.verify_ticket_qty,                                                            -- 核销票数
  u.verify_amt,                                                                   -- 核销金额
  u.verify_entitlement_qty,                                                       -- 核销权益次数
  u.verify_fail_qty,                                                              -- 核销失败次数
  CURRENT_TIMESTAMP AS update_time                                                -- 最近一次写入时间
FROM src_verify u;
