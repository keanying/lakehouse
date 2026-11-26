-- dwd.dwd_trf_distribution_settle_di  分销采购链明细
-- 粒度：1行=1张票在分销链上的1个层级
-- 来源：dwd_fin_payment_di（batch_no 依赖链展开）+ dwd_fin_frozen_di
-- 生成方式：Spark SQL / Hive；字段 22 个：直接翻译 19 · 规则翻译 0 · 待确认 3
-- 每个 WITH 逻辑块只取用到的列并先过滤分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
payment_dtl AS (                                              -- 主表「支付明细」，只取用到的列
  SELECT batch_no, depend_on_item_no, id, item_no, order_group_no, pay_amt, pay_method_type, pay_time,
         payee_account_no, payee_tenant_id, payer_account_no, payer_tenant_id, payment_no, profit_amt,
         settle_amt, tenant_id, ticket_no
  FROM dwd.dwd_fin_payment_di
  WHERE travel_date = '${bizdate}'                            -- 只取当日分区
),
ticket_dtl AS (                                               -- 「票明细（出票）」当日数据，只取用到的列
  SELECT order_no, sku_id, ticket_no
  FROM dwd.dwd_ord_ticket_di
  WHERE travel_date = '${bizdate}'                            -- 只取当日分区
),
distribution_relation_cur AS (                                -- 「分销关系维度」当前有效版本，只取用到的列
  SELECT relation_id, relation_no
  FROM dim.dim_trf_distribution_relation_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
),
frozen_dtl AS (                                               -- 「冻结/解冻明细」当日数据，只取用到的列
  SELECT account_no, freeze_type, ticket_no
  FROM dwd.dwd_fin_frozen_di
  WHERE travel_date = '${bizdate}'                            -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_trf_distribution_settle_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  payment_dtl.ticket_no                 AS ticket_no,         -- 票号
  ticket_dtl.order_no                   AS order_no,          -- 子单号
  payment_dtl.order_group_no            AS order_group_no,    -- 聚合单号
  payment_dtl.batch_no                  AS batch_no,          -- 支付批次号
  payment_dtl.item_no                   AS item_no,           -- 支付批次内明细号
  payment_dtl.payment_no                AS payment_no,        -- 支付记录号
  payment_dtl.depend_on_item_no         AS chain_level_no,    -- 分销链层级｜待确认：dwd_fin_payment_di.depend_on_item_no 递归计算
  distribution_relation_cur.relation_no AS relation_no,       -- 分销关系编号｜待确认：dim_trf_distribution_relation_zip.relation_no 按付款方/收款方租户匹配
  payment_dtl.payee_tenant_id           AS supplier_tenant_id,  -- 本级供应商（收款方）租户ID
  payment_dtl.payer_tenant_id           AS distributor_tenant_id,  -- 本级分销商（付款方）租户ID
  payment_dtl.payer_account_no          AS payer_account_no,  -- 付款账户号
  payment_dtl.payee_account_no          AS payee_account_no,  -- 收款账户号
  ticket_dtl.sku_id                     AS sku_id,            -- SKU ID
  payment_dtl.pay_amt                   AS sale_amt,          -- 本级售价（元）
  payment_dtl.settle_amt                AS settle_amt,        -- 本级结算价（元）
  payment_dtl.profit_amt                AS profit_amt,        -- 本级利润（元）= 售价 - 结算价
  frozen_dtl.freeze_type                AS freeze_type,       -- 冻结类型
  payment_dtl.pay_method_type           AS pay_method_type,   -- 支付方式
  payment_dtl.pay_time                  AS pay_time,          -- 支付时间
  payment_dtl.tenant_id                 AS tenant_id,         -- 租户ID（分库维度）
  CURRENT_TIMESTAMP()                   AS etl_time           -- ETL 加载时间
FROM payment_dtl
LEFT JOIN ticket_dtl                                          -- 关联「票明细（出票）」，取 子单号、SKU ID
  ON ticket_dtl.ticket_no = payment_dtl.ticket_no             -- 按 ticket_no 关联
LEFT JOIN distribution_relation_cur                           -- 关联「分销关系维度」，取 分销关系编号
  ON distribution_relation_cur.relation_id = payment_dtl.id   -- 按 id→relation_id 关联｜待确认：关联键
LEFT JOIN frozen_dtl                                          -- 关联「冻结/解冻明细」，取 冻结类型
  ON frozen_dtl.ticket_no = payment_dtl.ticket_no AND frozen_dtl.account_no = payment_dtl.payer_account_no;  -- 按 ticket_no、payer_account_no→account_no 关联
