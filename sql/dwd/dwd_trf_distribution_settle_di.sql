-- dwd.dwd_trf_distribution_settle_di  分销采购链明细
-- 粒度：1行=1张票在分销链上的1个层级
-- 来源：dwd_fin_payment_di（batch_no 依赖链展开）+ dwd_fin_frozen_di
-- 生成方式：Spark SQL / Hive；字段 22 个：直接翻译 19 · 规则翻译 0 · 待确认 3
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_trf_distribution_settle_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.ticket_no         AS ticket_no,                 -- 票号
  j1.order_no         AS order_no,                  -- 子单号
  a.order_group_no    AS order_group_no,            -- 聚合单号
  a.batch_no          AS batch_no,                  -- 支付批次号
  a.item_no           AS item_no,                   -- 支付批次内明细号
  a.payment_no        AS payment_no,                -- 支付记录号
  a.depend_on_item_no AS chain_level_no,            -- 分销链层级｜待确认：dwd_fin_payment_di.depend_on_item_no 递归计算
  j2.relation_no      AS relation_no,               -- 分销关系编号｜待确认：dim_trf_distribution_relation_zip.relation_no 按付款方/收款方租户匹配
  a.payee_tenant_id   AS supplier_tenant_id,        -- 本级供应商（收款方）租户ID
  a.payer_tenant_id   AS distributor_tenant_id,     -- 本级分销商（付款方）租户ID
  a.payer_account_no  AS payer_account_no,          -- 付款账户号
  a.payee_account_no  AS payee_account_no,          -- 收款账户号
  j1.sku_id           AS sku_id,                    -- SKU ID
  a.pay_amt           AS sale_amt,                  -- 本级售价（元）
  a.settle_amt        AS settle_amt,                -- 本级结算价（元）
  a.profit_amt        AS profit_amt,                -- 本级利润（元）= 售价 - 结算价
  j4.freeze_type      AS freeze_type,               -- 冻结类型
  a.pay_method_type   AS pay_method_type,           -- 支付方式
  a.pay_time          AS pay_time,                  -- 支付时间
  a.tenant_id         AS tenant_id,                 -- 租户ID（分库维度）
  CURRENT_TIMESTAMP() AS etl_time                   -- ETL 加载时间
FROM dwd.dwd_fin_payment_di a                       -- 主表「支付明细」
LEFT JOIN dwd.dwd_ord_ticket_di j1                  -- 关联「票明细（出票）」，取 子单号、SKU ID
  ON j1.ticket_no = a.ticket_no                     -- 按 ticket_no 关联
 AND j1.travel_date = '${bizdate}'                  -- 只取当日分区
LEFT JOIN dim.dim_trf_distribution_relation_zip j2  -- 关联「分销关系维度」，取 分销关系编号
  ON j2.relation_id = a.id                          -- 按 id→relation_id 关联
 AND j2.travel_date = '${bizdate}' AND j2.end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本｜待确认：关联键
LEFT JOIN dim.dim_trf_distribution_relation_zip j3  -- 关联「分销关系维度」
  ON j3.relation_id = j2.relation_id                -- 按 relation_id 关联
 AND j3.travel_date = '${bizdate}' AND j3.end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
LEFT JOIN dwd.dwd_fin_frozen_di j4                  -- 关联「冻结/解冻明细」，取 冻结类型
  ON j4.ticket_no = a.ticket_no AND j4.account_no = a.payee_account_no  -- 按 ticket_no、payee_account_no→account_no 关联
 AND j4.travel_date = '${bizdate}'                  -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                 -- 只取当日分区
