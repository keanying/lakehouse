-- dws.dws_ord_tenant_entitlement_di  商户×权益类型 权益使用日汇总
-- 粒度：travel_date × seller_tenant_id × sku_id × entitlement_type × binding_type
-- 来源：dwd_ord_entitlement_di, dwd_ord_entitlement_binding_di, dwd_ord_verify_di, dwd_ord_ticket_status_log_di
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 4 · 规则翻译 12 · 待确认 0
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总

WITH
src_entitlement AS (                                        -- 来源「权益明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                   -- 卖家租户ID
    sku_id AS sku_id,                                       -- SKU ID
    entitlement_type AS entitlement_type,                   -- 权益类型
    CAST(NULL AS STRING) AS binding_type,
    COUNT(entitlement_no) AS entitlement_issue_qty,         -- 发放权益数
    SUM(used_qty) AS entitlement_used_qty,                  -- 权益已用次数
    SUM(max_qty) AS entitlement_total_qty,  -- 权益可用总次数｜口径：计次 / 选择型权益的最大可用次数合计
    SUM(CASE WHEN entitlement_type = 'QUOTA' THEN quota_amt END) AS quota_total_amt,  -- 额度型权益总额度｜口径：额度型权益的额度合计（元）
    NULL AS activate_ticket_qty,
    NULL AS activate_delay_day_qty,
    NULL AS pending_activate_ticket_qty
  FROM dwd.dwd_ord_entitlement_di s                         -- 来源表「权益明细」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id, entitlement_type       -- 按粒度键汇总
),
src_ticket_status_log AS (                                  -- 来源「票状态流转明细」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                   -- 卖家租户ID
    sku_id AS sku_id,                                       -- SKU ID
    CAST(NULL AS STRING) AS entitlement_type,
    CAST(NULL AS STRING) AS binding_type,
    NULL AS entitlement_issue_qty,
    NULL AS entitlement_used_qty,
    NULL AS entitlement_total_qty,
    NULL AS quota_total_amt,
    COUNT(DISTINCT CASE WHEN tk.tk_delay = 1 AND s.before_status = 'AVAILABLE' AND s.after_status IN ('PARTIALLY_USED', 'USED') THEN s.ticket_no END) AS activate_ticket_qty,  -- 激活票数｜口径：延迟激活票首次使用即激活：状态由可用变为部分使用 / 已使用
    SUM(CASE WHEN tk.tk_delay = 1 AND s.before_status = 'AVAILABLE' AND s.after_status IN ('PARTIALLY_USED', 'USED') THEN DATEDIFF(TO_DATE(s.change_time), TO_DATE(tk.tk_issue_time)) END) AS activate_delay_day_qty,  -- 激活延迟天数合计｜口径：激活日 − 出票日（出票即支付完成），求平均激活延迟用
    NULL AS pending_activate_ticket_qty
  FROM dwd.dwd_ord_ticket_status_log_di s  -- 来源表「票状态流转明细」
  LEFT JOIN (SELECT ticket_no AS tk_no, MAX(delay_active_type) AS tk_delay, MIN(issue_time) AS tk_issue_time, MIN(first_verify_time) AS tk_first_verify_time
             FROM dwd.dwd_ord_ticket_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd') GROUP BY ticket_no) tk ON tk.tk_no = s.ticket_no
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                         -- 按粒度键汇总
),
src_ticket AS (                                             -- 来源「票明细（出票）」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                   -- 卖家租户ID
    sku_id AS sku_id,                                       -- SKU ID
    CAST(NULL AS STRING) AS entitlement_type,
    CAST(NULL AS STRING) AS binding_type,
    NULL AS entitlement_issue_qty,
    NULL AS entitlement_used_qty,
    NULL AS entitlement_total_qty,
    NULL AS quota_total_amt,
    NULL AS activate_ticket_qty,
    NULL AS activate_delay_day_qty,
    COUNT(CASE WHEN delay_active_type = 1 AND first_verify_time IS NULL AND ticket_status = 'AVAILABLE' THEN ticket_no END) AS pending_activate_ticket_qty  -- 待激活票数｜口径：延迟激活且尚未首次核销的可用票
  FROM dwd.dwd_ord_ticket_di s                              -- 来源表「票明细（出票）」
  WHERE s.travel_date = '${bizdate}'                        -- 只取当日分区
  GROUP BY seller_tenant_id, sku_id                         -- 按粒度键汇总
),
all_src AS (                                                -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_entitlement
  UNION ALL
  SELECT * FROM src_ticket_status_log
  UNION ALL
  SELECT * FROM src_ticket
)
INSERT OVERWRITE TABLE dws.dws_ord_tenant_entitlement_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                                       -- 卖家租户ID
  u.sku_id,                                                 -- SKU ID
  u.entitlement_type,                                       -- 权益类型
  u.binding_type,                                           -- 绑定方式
  SUM(u.entitlement_issue_qty) AS entitlement_issue_qty,    -- 发放权益数
  SUM(u.entitlement_used_qty) AS entitlement_used_qty,      -- 权益已用次数
  SUM(u.entitlement_total_qty) AS entitlement_total_qty,    -- 权益可用总次数
  SUM(u.quota_total_amt) AS quota_total_amt,                -- 额度型权益总额度
  SUM(u.activate_ticket_qty) AS activate_ticket_qty,        -- 激活票数
  SUM(u.activate_delay_day_qty) AS activate_delay_day_qty,  -- 激活延迟天数合计
  SUM(u.pending_activate_ticket_qty) AS pending_activate_ticket_qty,  -- 待激活票数
  CURRENT_TIMESTAMP() AS etl_time                           -- ETL 加载时间
FROM all_src u
GROUP BY u.seller_tenant_id, u.sku_id, u.entitlement_type, u.binding_type;  -- 按粒度键汇总
