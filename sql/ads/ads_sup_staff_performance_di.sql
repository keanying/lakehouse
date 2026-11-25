-- ads.ads_sup_staff_performance_di  员工/窗口业绩
-- 粒度：travel_date × tenant_id × staff_id
-- 来源：dws_sup_staff_operate_di
-- 生成方式：Spark SQL / Hive；字段 8 个：直接翻译 8 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_sup_staff_performance_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.tenant_id,                                  -- 租户ID
  x.staff_id,                                   -- 员工ID
  d1.tenant_name AS tenant_name,                -- 租户名称
  d2.staff_name AS staff_name,                  -- 员工姓名
  x.staff_order_qty,                            -- 员工代下单数（日）
  x.staff_pay_amt,                              -- 员工代下单支付金额（日）
  x.staff_verify_qty,                           -- 员工核销次数（日）
  x.staff_refund_qty,                           -- 员工发起退款单数（日）
  x.etl_time                                    -- ETL 加载时间
FROM (
SELECT
  u.tenant_id,                                  -- 租户ID
  u.staff_id,                                   -- 员工ID
  SUM(u.staff_order_qty) AS staff_order_qty,    -- 员工代下单数（日）
  SUM(u.staff_pay_amt) AS staff_pay_amt,        -- 员工代下单支付金额（日）
  SUM(u.staff_verify_qty) AS staff_verify_qty,  -- 员工核销次数（日）
  SUM(u.staff_refund_qty) AS staff_refund_qty,  -- 员工发起退款单数（日）
  CURRENT_TIMESTAMP() AS etl_time               -- ETL 加载时间
FROM (
  -- 来源：dws_sup_staff_operate_di
  SELECT
    tenant_id AS tenant_id,                     -- 租户ID
    staff_id AS staff_id,                       -- 员工ID
    SUM(staff_order_qty) AS staff_order_qty,    -- 员工代下单数（日）
    SUM(staff_pay_amt) AS staff_pay_amt,        -- 员工代下单支付金额（日）
    SUM(staff_verify_qty) AS staff_verify_qty,  -- 员工核销次数（日）
    SUM(staff_refund_qty) AS staff_refund_qty   -- 员工发起退款单数（日）
  FROM dws.dws_sup_staff_operate_di s           -- 来源表「员工操作日汇总（窗口/导游/核销员）」
  WHERE s.travel_date = '${bizdate}'            -- 只取当日分区
  GROUP BY tenant_id, staff_id                  -- 按粒度键汇总
) u                                             -- 各来源合并后的明细
GROUP BY u.tenant_id, u.staff_id                -- 按粒度键汇总
) x                                             -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_sup_staff_zip d2 ON d2.staff_id = x.staff_id AND d2.travel_date = '${bizdate}' AND d2.end_date = '9999-12-31';  -- 关联「员工维度」，取维度名称
