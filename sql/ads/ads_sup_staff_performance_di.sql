-- ads.ads_sup_staff_performance_di  员工/窗口业绩
-- 粒度：travel_date × tenant_id × staff_id
-- 来源：dws_sup_staff_operate_di
-- 生成方式：Spark SQL / Hive；字段 8 个：直接翻译 8 · 规则翻译 0 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_staff_operate AS (                        -- 来源「员工操作日汇总（窗口/导游/核销员）」按粒度键预聚合
  SELECT
    tenant_id AS tenant_id,                   -- 租户ID
    staff_id AS staff_id,                     -- 员工ID
    SUM(staff_order_qty) AS staff_order_qty,  -- 员工代下单数（日）
    SUM(staff_pay_amt) AS staff_pay_amt,      -- 员工代下单支付金额（日）
    SUM(staff_verify_qty) AS staff_verify_qty,  -- 员工核销次数（日）
    SUM(staff_refund_qty) AS staff_refund_qty  -- 员工发起退款单数（日）
  FROM dws.dws_sup_staff_operate_di s         -- 来源表「员工操作日汇总（窗口/导游/核销员）」
  WHERE s.travel_date = '${bizdate}'          -- 只取当日分区
  GROUP BY tenant_id, staff_id                -- 按粒度键汇总
),
merged AS (                                   -- 按粒度键汇总，计算派生指标
  SELECT
    u.tenant_id,                              -- 租户ID
    u.staff_id,                               -- 员工ID
    u.staff_order_qty,                        -- 员工代下单数（日）
    u.staff_pay_amt,                          -- 员工代下单支付金额（日）
    u.staff_verify_qty,                       -- 员工核销次数（日）
    u.staff_refund_qty,                       -- 员工发起退款单数（日）
    CURRENT_TIMESTAMP() AS etl_time           -- ETL 加载时间
  FROM src_staff_operate u
),
tenant_cur AS (                               -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
),
staff_cur AS (                                -- 「员工维度」当前有效版本，只取名称类字段
  SELECT staff_id, staff_name
  FROM dim.dim_sup_staff_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_sup_staff_performance_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.tenant_id,                           -- 租户ID
  merged.staff_id,                            -- 员工ID
  tenant_cur.tenant_name AS tenant_name,      -- 租户名称
  staff_cur.staff_name AS staff_name,         -- 员工姓名
  merged.staff_order_qty,                     -- 员工代下单数（日）
  merged.staff_pay_amt,                       -- 员工代下单支付金额（日）
  merged.staff_verify_qty,                    -- 员工核销次数（日）
  merged.staff_refund_qty,                    -- 员工发起退款单数（日）
  merged.etl_time                             -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                          -- 关联「租户（商户/供应商/分销商）维度」，补 tenant_name
  ON tenant_cur.tenant_id = merged.tenant_id  -- 按 tenant_id 关联
LEFT JOIN staff_cur                           -- 关联「员工维度」，补 staff_name
  ON staff_cur.staff_id = merged.staff_id;    -- 按 staff_id 关联
