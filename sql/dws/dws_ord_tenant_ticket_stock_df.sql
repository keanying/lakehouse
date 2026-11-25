-- dws.dws_ord_tenant_ticket_stock_df  商户×SKU 票状态存量快照
-- 粒度：travel_date × seller_tenant_id × sku_id × ticket_status × valid_end_date
-- 来源：dwd_ord_ticket_di, dwd_ord_ticket_status_log_di
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 4 · 规则翻译 4 · 待确认 13
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_ord_tenant_ticket_stock_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                             -- 卖家租户ID
  u.sku_id,                                       -- SKU ID
  u.ticket_status,                                -- 票状态
  u.valid_end_date,                               -- 有效期截止日期
  SUM(u.ticket_stock_qty) AS ticket_stock_qty,    -- 票存量
  SUM(u.unverified_ticket_qty) AS unverified_ticket_qty,  -- 未核销在途票数
  SUM(u.unverified_amt) AS unverified_amt,        -- 未核销在途金额（预收）
  SUM(u.expire_ticket_qty) AS expire_ticket_qty,  -- 过期票数
  SUM(u.realname_ticket_qty) AS realname_ticket_qty,  -- 实名票数
  SUM(u.pending_activate_ticket_qty) AS pending_activate_ticket_qty,  -- 待激活票数
  SUM(u.issue_ticket_qty) AS issue_ticket_qty,    -- 出票张数
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,        -- 支付票数
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,  -- 核销票数
  CURRENT_TIMESTAMP() AS etl_time                 -- ETL 加载时间
FROM (
  -- 来源：dwd_ord_ticket_di
  SELECT
    seller_tenant_id AS seller_tenant_id,         -- 卖家租户ID
    sku_id AS sku_id,                             -- SKU ID
    ticket_status AS ticket_status,               -- 票状态
    valid_end_date AS valid_end_date,             -- 有效期截止日期
    COUNT(CASE WHEN 1 = 1 THEN ticket_no END) AS ticket_stock_qty,  -- 票存量｜待确认：group by ticket_status
    COUNT(CASE WHEN 1 = 1 THEN ticket_no END) AS unverified_ticket_qty,  -- 未核销在途票数｜待确认：status in (AVAILABLE,PARTIALLY_USED) and valid_end>=snapshot
    SUM(CASE WHEN 1 = 1 THEN unit_price_amt END) AS unverified_amt,  -- 未核销在途金额（预收）｜待确认：of unverified tickets
    NULL AS expire_ticket_qty,                    -- 过期票数
    NULL AS realname_ticket_qty,                  -- 实名票数
    COUNT(CASE WHEN 1 = 1 THEN ticket_no END) AS pending_activate_ticket_qty,  -- 待激活票数｜待确认：延迟激活 and valid_start='1970-01-01'
    COUNT(ticket_no) AS issue_ticket_qty,         -- 出票张数
    NULL AS pay_ticket_qty,                       -- 支付票数
    NULL AS verify_ticket_qty                     -- 核销票数
  FROM dwd.dwd_ord_ticket_di s                    -- 来源表「票明细（出票）」
  WHERE s.travel_date <= '${bizdate}'             -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id, sku_id, ticket_status, valid_end_date  -- 按粒度键汇总
  UNION ALL                                       -- 合并各来源
  -- 来源：dwd_ord_ticket_status_log_di
  SELECT
    seller_tenant_id AS seller_tenant_id,         -- 卖家租户ID
    sku_id AS sku_id,                             -- SKU ID
    CAST(NULL AS STRING) AS ticket_status,        -- 票状态
    CAST(NULL AS STRING) AS valid_end_date,       -- 有效期截止日期
    NULL AS ticket_stock_qty,                     -- 票存量
    NULL AS unverified_ticket_qty,                -- 未核销在途票数
    NULL AS unverified_amt,                       -- 未核销在途金额（预收）
    COUNT(CASE WHEN after_status='EXPIRED' THEN ticket_no END) AS expire_ticket_qty,  -- 过期票数
    NULL AS realname_ticket_qty,                  -- 实名票数
    NULL AS pending_activate_ticket_qty,          -- 待激活票数
    NULL AS issue_ticket_qty,                     -- 出票张数
    NULL AS pay_ticket_qty,                       -- 支付票数
    NULL AS verify_ticket_qty                     -- 核销票数
  FROM dwd.dwd_ord_ticket_status_log_di s         -- 来源表「票状态流转明细」
  WHERE s.travel_date <= '${bizdate}'             -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id, sku_id               -- 按粒度键汇总
  UNION ALL                                       -- 合并各来源
  -- 来源：dwd_ord_ticket_person_di
  SELECT
    seller_tenant_id AS seller_tenant_id,         -- 卖家租户ID
    sku_id AS sku_id,                             -- SKU ID
    CAST(NULL AS STRING) AS ticket_status,        -- 票状态
    CAST(NULL AS STRING) AS valid_end_date,       -- 有效期截止日期
    NULL AS ticket_stock_qty,                     -- 票存量
    NULL AS unverified_ticket_qty,                -- 未核销在途票数
    NULL AS unverified_amt,                       -- 未核销在途金额（预收）
    NULL AS expire_ticket_qty,                    -- 过期票数
    COUNT(CASE WHEN person_qty>0 THEN ticket_no END) AS realname_ticket_qty,  -- 实名票数
    NULL AS pending_activate_ticket_qty,          -- 待激活票数
    NULL AS issue_ticket_qty,                     -- 出票张数
    NULL AS pay_ticket_qty,                       -- 支付票数
    NULL AS verify_ticket_qty                     -- 核销票数
  FROM dwd.dwd_ord_ticket_person_di s             -- 来源表「票游客明细」
  WHERE s.travel_date <= '${bizdate}'             -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id, sku_id               -- 按粒度键汇总
  UNION ALL                                       -- 合并各来源
  -- 来源：dwd_ord_order_di
  SELECT
    seller_tenant_id AS seller_tenant_id,         -- 卖家租户ID
    sku_id AS sku_id,                             -- SKU ID
    CAST(NULL AS STRING) AS ticket_status,        -- 票状态
    CAST(NULL AS STRING) AS valid_end_date,       -- 有效期截止日期
    NULL AS ticket_stock_qty,                     -- 票存量
    NULL AS unverified_ticket_qty,                -- 未核销在途票数
    NULL AS unverified_amt,                       -- 未核销在途金额（预收）
    NULL AS expire_ticket_qty,                    -- 过期票数
    NULL AS realname_ticket_qty,                  -- 实名票数
    NULL AS pending_activate_ticket_qty,          -- 待激活票数
    NULL AS issue_ticket_qty,                     -- 出票张数
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,  -- 支付票数
    NULL AS verify_ticket_qty                     -- 核销票数
  FROM dwd.dwd_ord_order_di s                     -- 来源表「子单明细」
  WHERE s.travel_date <= '${bizdate}'             -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id, sku_id               -- 按粒度键汇总
  UNION ALL                                       -- 合并各来源
  -- 来源：dwd_ord_verify_di
  SELECT
    seller_tenant_id AS seller_tenant_id,         -- 卖家租户ID
    sku_id AS sku_id,                             -- SKU ID
    CAST(NULL AS STRING) AS ticket_status,        -- 票状态
    CAST(NULL AS STRING) AS valid_end_date,       -- 有效期截止日期
    NULL AS ticket_stock_qty,                     -- 票存量
    NULL AS unverified_ticket_qty,                -- 未核销在途票数
    NULL AS unverified_amt,                       -- 未核销在途金额（预收）
    NULL AS expire_ticket_qty,                    -- 过期票数
    NULL AS realname_ticket_qty,                  -- 实名票数
    NULL AS pending_activate_ticket_qty,          -- 待激活票数
    NULL AS issue_ticket_qty,                     -- 出票张数
    NULL AS pay_ticket_qty,                       -- 支付票数
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS verify_ticket_qty  -- 核销票数｜待确认：verify_result='SUCCESS'
  FROM dwd.dwd_ord_verify_di s                    -- 来源表「核销明细（权益级）」
  WHERE s.travel_date <= '${bizdate}'             -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id, sku_id               -- 按粒度键汇总
) u                                               -- 各来源合并后的明细
GROUP BY u.seller_tenant_id, u.sku_id, u.ticket_status, u.valid_end_date;  -- 按粒度键汇总
