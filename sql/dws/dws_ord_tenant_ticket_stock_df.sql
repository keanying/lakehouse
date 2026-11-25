-- dws.dws_ord_tenant_ticket_stock_df  商户×SKU 票状态存量快照
-- 粒度：travel_date × seller_tenant_id × sku_id × ticket_status × valid_end_date
-- 来源：dwd_ord_ticket_di, dwd_ord_ticket_status_log_di
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 4 · 规则翻译 4 · 待确认 13
-- 多来源：每个来源表按粒度键先汇总，UNION ALL 后再合并；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_ord_tenant_ticket_stock_df PARTITION (travel_date = '${bizdate}')
SELECT
  u.seller_tenant_id,
  u.sku_id,
  u.ticket_status,
  u.valid_end_date,
  SUM(u.ticket_stock_qty) AS ticket_stock_qty,
  SUM(u.unverified_ticket_qty) AS unverified_ticket_qty,
  SUM(u.unverified_amt) AS unverified_amt,
  SUM(u.expire_ticket_qty) AS expire_ticket_qty,
  SUM(u.realname_ticket_qty) AS realname_ticket_qty,
  SUM(u.pending_activate_ticket_qty) AS pending_activate_ticket_qty,
  SUM(u.issue_ticket_qty) AS issue_ticket_qty,
  SUM(u.pay_ticket_qty) AS pay_ticket_qty,
  SUM(u.verify_ticket_qty) AS verify_ticket_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_ord_ticket_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    ticket_status AS ticket_status,
    valid_end_date AS valid_end_date,
    COUNT(CASE WHEN 1 = 1 THEN ticket_no END) AS ticket_stock_qty,  -- 待确认：group by ticket_status
    COUNT(CASE WHEN 1 = 1 THEN ticket_no END) AS unverified_ticket_qty,  -- 待确认：status in (AVAILABLE,PARTIALLY_USED) and valid_end>=snapshot
    SUM(CASE WHEN 1 = 1 THEN unit_price_amt END) AS unverified_amt,  -- 待确认：of unverified tickets
    NULL AS expire_ticket_qty,
    NULL AS realname_ticket_qty,
    COUNT(CASE WHEN 1 = 1 THEN ticket_no END) AS pending_activate_ticket_qty,  -- 待确认：延迟激活 and valid_start='1970-01-01'
    COUNT(ticket_no) AS issue_ticket_qty,
    NULL AS pay_ticket_qty,
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_ticket_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY seller_tenant_id, sku_id, ticket_status, valid_end_date
  UNION ALL
  -- 来源：dwd_ord_ticket_status_log_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    CAST(NULL AS STRING) AS ticket_status,
    CAST(NULL AS STRING) AS valid_end_date,
    NULL AS ticket_stock_qty,
    NULL AS unverified_ticket_qty,
    NULL AS unverified_amt,
    COUNT(CASE WHEN after_status='EXPIRED' THEN ticket_no END) AS expire_ticket_qty,
    NULL AS realname_ticket_qty,
    NULL AS pending_activate_ticket_qty,
    NULL AS issue_ticket_qty,
    NULL AS pay_ticket_qty,
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_ticket_status_log_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
  UNION ALL
  -- 来源：dwd_ord_ticket_person_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    CAST(NULL AS STRING) AS ticket_status,
    CAST(NULL AS STRING) AS valid_end_date,
    NULL AS ticket_stock_qty,
    NULL AS unverified_ticket_qty,
    NULL AS unverified_amt,
    NULL AS expire_ticket_qty,
    COUNT(CASE WHEN person_qty>0 THEN ticket_no END) AS realname_ticket_qty,
    NULL AS pending_activate_ticket_qty,
    NULL AS issue_ticket_qty,
    NULL AS pay_ticket_qty,
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_ticket_person_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
  UNION ALL
  -- 来源：dwd_ord_order_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
    CAST(NULL AS STRING) AS ticket_status,
    CAST(NULL AS STRING) AS valid_end_date,
    NULL AS ticket_stock_qty,
    NULL AS unverified_ticket_qty,
    NULL AS unverified_amt,
    NULL AS expire_ticket_qty,
    NULL AS realname_ticket_qty,
    NULL AS pending_activate_ticket_qty,
    NULL AS issue_ticket_qty,
    SUM(CASE WHEN pay_time IS NOT NULL THEN buy_ticket_qty END) AS pay_ticket_qty,
    NULL AS verify_ticket_qty
  FROM dwd.dwd_ord_order_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
  UNION ALL
  -- 来源：dwd_ord_verify_di
  SELECT
    seller_tenant_id AS seller_tenant_id,
    sku_id AS sku_id,
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
    COUNT(DISTINCT CASE WHEN 1 = 1 THEN ticket_no END) AS verify_ticket_qty  -- 待确认：verify_result='SUCCESS'
  FROM dwd.dwd_ord_verify_di s
  WHERE s.travel_date <= '${bizdate}'
  GROUP BY seller_tenant_id, sku_id
) u
GROUP BY u.seller_tenant_id, u.sku_id, u.ticket_status, u.valid_end_date;
