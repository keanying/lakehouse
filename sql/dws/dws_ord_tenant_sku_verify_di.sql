-- dws.dws_ord_tenant_sku_verify_di  商户×SKU×核销点 核销日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × verify_point_id × verify_type
-- 来源：dwd_ord_verify_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 4 · 规则翻译 9 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_verify AS (                                                                   -- 来源「核销明细（权益级）」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                                         -- 卖家租户ID
    sku_id AS sku_id,                                                             -- SKU ID
    verify_point_id AS verify_point_id,                                           -- 核销点ID
    verify_type AS verify_type,                                                   -- 核销类型
    COUNT(DISTINCT CASE WHEN verify_result_type='SUCCESS' THEN ticket_no END) AS verify_ticket_qty,  -- 核销票数
    COUNT(CASE WHEN verify_result_type='SUCCESS' THEN verify_no END) AS verify_entitlement_qty,  -- 核销权益次数
    COUNT(CASE WHEN verify_result_type = 'SUCCESS' THEN verify_no END) AS verify_person_qty,  -- 核销人次（入园人次）
    COUNT(CASE WHEN verify_result_type in ('FAILED','DUPLICATE') THEN verify_no END) AS verify_fail_qty,  -- 核销失败次数
    COUNT(CASE WHEN verify_type='OFFLINE' and verify_result_type = 'SUCCESS' THEN verify_no END) AS offline_verify_qty,  -- 离线核销次数
    SUM(CASE WHEN s.verify_result_type = 'SUCCESS' THEN s.verify_amt END) AS verify_amt,  -- 核销金额｜口径：核销成功的核销金额；DWD 已按「票单价 ÷ 可核销次数」分摊到每次核销，同一张票合计不超过票价
    COUNT(CASE WHEN verify_result_type='DUPLICATE' THEN verify_no END) AS duplicate_verify_qty,  -- 重复核销次数
    COUNT(CASE WHEN verify_type='OFFLINE' and verify_result_type='DUPLICATE' THEN verify_no END) AS offline_conflict_qty,  -- 离线核销冲突次数
    SUM(CASE WHEN s.verify_result_type = 'SUCCESS' AND s.verify_time = tk.tk_first_verify_time THEN DATEDIFF(TO_DATE(s.verify_time), TO_DATE(tk.tk_issue_time)) END) AS verify_after_pay_day_qty  -- 支付到首次核销天数合计｜口径：票的首次核销日 − 出票日（每张票只在首次核销那次记）
  FROM dwd.dwd_ord_verify_di s  -- 来源表「核销明细（权益级）」
  LEFT JOIN (SELECT ticket_no AS tk_no, MAX(delay_active_type) AS tk_delay, MIN(issue_time) AS tk_issue_time, MIN(first_verify_time) AS tk_first_verify_time
             FROM dwd.dwd_ord_ticket_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd') GROUP BY ticket_no) tk ON tk.tk_no = s.ticket_no
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id, verify_point_id, verify_type                 -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_ord_tenant_sku_verify_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                                                             -- 卖家租户ID
  u.sku_id,                                                                       -- SKU ID
  u.verify_point_id,                                                              -- 核销点ID
  u.verify_type,                                                                  -- 核销类型
  u.verify_ticket_qty,                                                            -- 核销票数
  u.verify_entitlement_qty,                                                       -- 核销权益次数
  u.verify_person_qty,                                                            -- 核销人次（入园人次）
  u.verify_fail_qty,                                                              -- 核销失败次数
  u.offline_verify_qty,                                                           -- 离线核销次数
  u.verify_amt,                                                                   -- 核销金额
  u.duplicate_verify_qty,                                                         -- 重复核销次数
  u.offline_conflict_qty,                                                         -- 离线核销冲突次数
  u.verify_after_pay_day_qty,                                                     -- 支付到首次核销天数合计
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM src_verify u;
