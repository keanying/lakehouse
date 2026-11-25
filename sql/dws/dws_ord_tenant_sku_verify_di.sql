-- dws.dws_ord_tenant_sku_verify_di  商户×SKU×核销点 核销日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × verify_point_id × verify_type
-- 来源：dwd_ord_verify_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 4 · 规则翻译 1 · 待确认 8
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_ord_tenant_sku_verify_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                                                     -- 卖家租户ID
  u.sku_id,                                                               -- SKU ID
  u.verify_point_id,                                                      -- 核销点ID
  u.verify_type,                                                          -- 核销类型
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,                          -- 核销票数
  SUM(u.verify_entitlement_qty) AS verify_entitlement_qty,                -- 核销权益次数
  SUM(u.verify_person_qty) AS verify_person_qty,                          -- 核销人次（入园人次）
  SUM(u.verify_fail_qty) AS verify_fail_qty,                              -- 核销失败次数
  SUM(u.offline_verify_qty) AS offline_verify_qty,                        -- 离线核销次数
  SUM(u.verify_amt) AS verify_amt,                                        -- 核销金额
  SUM(u.duplicate_verify_qty) AS duplicate_verify_qty,                    -- 重复核销次数
  SUM(u.offline_conflict_qty) AS offline_conflict_qty,                    -- 离线核销冲突次数
  SUM(u.verify_after_pay_day_qty) AS verify_after_pay_day_qty,            -- 支付到首次核销天数合计
  CURRENT_TIMESTAMP() AS etl_time                                         -- ETL 加载时间
FROM (
  -- 来源：dwd_ord_verify_di
  SELECT
    seller_tenant_id AS seller_tenant_id,                                 -- 卖家租户ID
    sku_id AS sku_id,                                                     -- SKU ID
    verify_point_id AS verify_point_id,                                   -- 核销点ID
    verify_type AS verify_type,                                           -- 核销类型
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS verify_ticket_qty,  -- 核销票数｜待确认：verify_result='SUCCESS'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_entitlement_qty,  -- 核销权益次数｜待确认：verify_result='SUCCESS'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_person_qty,       -- 核销人次（入园人次）｜待确认：SUCCESS（待补放行人数后改 sum(pass_count)）
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_fail_qty,         -- 核销失败次数｜待确认：verify_result in ('FAILED','DUPLICATE')
    COUNT(CASE WHEN verify_type='OFFLINE' and verify_result_type = 'SUCCESS' THEN verify_no END) AS offline_verify_qty,  -- 离线核销次数
    NULL AS verify_amt,                                                   -- 核销金额｜待确认：sum(unit_price_amt) of verified tickets（同票只计1次）
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS duplicate_verify_qty,    -- 重复核销次数｜待确认：verify_result='DUPLICATE'
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS offline_conflict_qty,    -- 离线核销冲突次数｜待确认：verify_type='OFFLINE' and verify_result='DUPLICATE'
    NULL AS verify_after_pay_day_qty                                      -- 支付到首次核销天数合计｜待确认：sum(datediff(first_verify_date, pay_date))
  FROM dwd.dwd_ord_verify_di s                                            -- 来源表「核销明细（权益级）」
  WHERE s.travel_date = '${bizdate}'                                      -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id, verify_point_id, verify_type         -- 按粒度键汇总
) u                                                                       -- 各来源合并后的明细
GROUP BY u.seller_tenant_id, u.sku_id, u.verify_point_id, u.verify_type;  -- 按粒度键汇总
