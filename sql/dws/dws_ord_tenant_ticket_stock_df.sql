-- dws.dws_ord_tenant_ticket_stock_df  商户×SKU 票状态存量快照
-- 粒度：travel_date × seller_tenant_id × sku_id × ticket_status × valid_end_date
-- 来源：dwd_ord_ticket_di, dwd_ord_ticket_status_log_di
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 4 · 规则翻译 17 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总；快照/累计表：增量来源取截至统计日的全部分区

WITH
src_ticket AS (                                                       -- 来源「票明细（出票）」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                             -- 卖家租户ID
    sku_id AS sku_id,                                                 -- SKU ID
    ticket_status AS ticket_status,                                   -- 票状态
    valid_end_date AS valid_end_date,                                 -- 有效期截止日期
    COUNT(DISTINCT ticket_no) AS ticket_stock_qty,  -- 票存量｜口径：按票状态（粒度键）计票存量
    COUNT(DISTINCT CASE WHEN ticket_status IN ('AVAILABLE', 'PARTIALLY_USED') AND valid_end_date >= '${bizdate_dash}' THEN ticket_no END) AS unverified_ticket_qty,  -- 未核销在途票数｜口径：可用 / 部分使用、且未过有效期
    SUM(CASE WHEN ticket_status IN ('AVAILABLE', 'PARTIALLY_USED') AND valid_end_date >= '${bizdate_dash}' THEN unit_price_amt END) AS unverified_amt,  -- 未核销在途金额｜口径：未核销在途票的单价合计（预收口径）
    NULL AS expire_ticket_qty,
    NULL AS realname_ticket_qty,
    COUNT(CASE WHEN delay_active_type = 1 AND first_verify_time IS NULL AND ticket_status = 'AVAILABLE' THEN ticket_no END) AS pending_activate_ticket_qty,  -- 待激活票数｜口径：延迟激活且尚未首次核销的可用票
    COUNT(ticket_no) AS issue_ticket_qty,                             -- 出票张数
    NULL AS pay_ticket_qty,
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_ticket_di s                                        -- 来源表「票明细（出票）」
  WHERE s.travel_date <= '${bizdate}'                                 -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id, sku_id, ticket_status, valid_end_date    -- 按粒度键汇总
),
src_ticket_status_log AS (                                            -- 来源「票状态流转明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                             -- 卖家租户ID
    sku_id AS sku_id,                                                 -- SKU ID
    CAST(NULL AS STRING) AS ticket_status,
    CAST(NULL AS STRING) AS valid_end_date,
    NULL AS ticket_stock_qty,
    NULL AS unverified_ticket_qty,
    NULL AS unverified_amt,
    COUNT(CASE WHEN after_status='EXPIRED' THEN ticket_no END) AS expire_ticket_qty,  -- 过期票数
    NULL AS realname_ticket_qty,
    NULL AS pending_activate_ticket_qty,
    NULL AS issue_ticket_qty,
    NULL AS pay_ticket_qty,
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_ticket_status_log_di s                             -- 来源表「票状态流转明细」
  WHERE s.travel_date <= '${bizdate}'                                 -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id, sku_id                                   -- 按粒度键汇总
),
src_ticket_person AS (                                                -- 来源「票游客明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                             -- 卖家租户ID
    sku_id AS sku_id,                                                 -- SKU ID
    CAST(NULL AS STRING) AS ticket_status,
    CAST(NULL AS STRING) AS valid_end_date,
    NULL AS ticket_stock_qty,
    NULL AS unverified_ticket_qty,
    NULL AS unverified_amt,
    NULL AS expire_ticket_qty,
    COUNT(CASE WHEN person_qty>0 THEN ticket_no END) AS realname_ticket_qty,  -- 实名票数
    NULL AS pending_activate_ticket_qty,
    NULL AS issue_ticket_qty,
    NULL AS pay_ticket_qty,
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_ticket_person_di s                                 -- 来源表「票游客明细」
  WHERE s.travel_date <= '${bizdate}'                                 -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id, sku_id                                   -- 按粒度键汇总
),
src_order AS (                                                        -- 来源「子单明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                             -- 卖家租户ID
    sku_id AS sku_id,                                                 -- SKU ID
    CAST(NULL AS STRING) AS ticket_status,
    CAST(NULL AS STRING) AS valid_end_date,
    NULL AS ticket_stock_qty,
    NULL AS unverified_ticket_qty,
    NULL AS unverified_amt,
    NULL AS expire_ticket_qty,
    NULL AS realname_ticket_qty,
    NULL AS pending_activate_ticket_qty,
    NULL AS issue_ticket_qty,
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,  -- 支付票数
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_order_di s                                         -- 来源表「子单明细」
  WHERE s.travel_date <= '${bizdate}'                                 -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id, sku_id                                   -- 按粒度键汇总
),
src_verify AS (                                                       -- 来源「核销明细（权益级）」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                             -- 卖家租户ID
    sku_id AS sku_id,                                                 -- SKU ID
    CAST(NULL AS STRING) AS ticket_status,
    CAST(NULL AS STRING) AS valid_end_date,
    NULL AS ticket_stock_qty,
    NULL AS unverified_ticket_qty,
    NULL AS unverified_amt,
    NULL AS expire_ticket_qty,
    NULL AS realname_ticket_qty,
    NULL AS pending_activate_ticket_qty,
    NULL AS issue_ticket_qty,
    NULL AS pay_ticket_qty,
    COUNT(DISTINCT CASE WHEN verify_result_type='SUCCESS' THEN ticket_no END) AS verify_ticket_qty  -- 核销票数
  FROM dwd.dwd_ord_verify_di s                                        -- 来源表「核销明细（权益级）」
  WHERE s.travel_date <= '${bizdate}'                                 -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id, sku_id                                   -- 按粒度键汇总
),
all_src AS (                                                          -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_ticket
  UNION ALL
  SELECT * FROM src_ticket_status_log
  UNION ALL
  SELECT * FROM src_ticket_person
  UNION ALL
  SELECT * FROM src_order
  UNION ALL
  SELECT * FROM src_verify
)
INSERT OVERWRITE TABLE dws.dws_ord_tenant_ticket_stock_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                                                 -- 卖家租户ID
  u.sku_id,                                                           -- SKU ID
  u.ticket_status,                                                    -- 票状态
  u.valid_end_date,                                                   -- 有效期截止日期
  SUM(u.ticket_stock_qty) AS ticket_stock_qty,                        -- 票存量
  SUM(u.unverified_ticket_qty) AS unverified_ticket_qty,              -- 未核销在途票数
  SUM(u.unverified_amt) AS unverified_amt,                            -- 未核销在途金额（预收）
  SUM(u.expire_ticket_qty) AS expire_ticket_qty,                      -- 过期票数
  SUM(u.realname_ticket_qty) AS realname_ticket_qty,                  -- 实名票数
  SUM(u.pending_activate_ticket_qty) AS pending_activate_ticket_qty,  -- 待激活票数
  SUM(u.issue_ticket_qty) AS issue_ticket_qty,                        -- 出票张数
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,                            -- 支付票数
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,                      -- 核销票数
  CURRENT_TIMESTAMP() AS etl_time                                     -- ETL 加载时间
FROM all_src u
GROUP BY u.seller_tenant_id, u.sku_id, u.ticket_status, u.valid_end_date;  -- 按粒度键汇总
