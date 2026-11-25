-- dwd.dwd_trf_distribution_settle_di  分销采购链明细
-- 粒度：1行=1张票在分销链上的1个层级
-- 来源：dwd_fin_payment_di（batch_no 依赖链展开）+ dwd_fin_frozen_di
-- 生成方式：Spark SQL / Hive；字段 22 个：直接翻译 19 · 规则翻译 0 · 待确认 3
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_trf_distribution_settle_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.ticket_no         AS ticket_no,
  j1.order_no         AS order_no,
  a.order_group_no    AS order_group_no,
  a.batch_no          AS batch_no,
  a.item_no           AS item_no,
  a.payment_no        AS payment_no,
  a.depend_on_item_no AS chain_level_no,  -- 待确认：dwd_fin_payment_di.depend_on_item_no 递归计算
  j2.relation_no      AS relation_no,  -- 待确认：dim_trf_distribution_relation_zip.relation_no 按付款方/收款方租户匹配
  a.payee_tenant_id   AS supplier_tenant_id,
  a.payer_tenant_id   AS distributor_tenant_id,
  a.payer_account_no  AS payer_account_no,
  a.payee_account_no  AS payee_account_no,
  j1.sku_id           AS sku_id,
  a.pay_amt           AS sale_amt,
  a.settle_amt        AS settle_amt,
  a.profit_amt        AS profit_amt,
  j4.freeze_type      AS freeze_type,
  a.pay_method_type   AS pay_method_type,
  a.pay_time          AS pay_time,
  a.tenant_id         AS tenant_id,
  CURRENT_TIMESTAMP() AS etl_time
FROM dwd.dwd_fin_payment_di a
LEFT JOIN dwd.dwd_ord_ticket_di j1
  ON j1.ticket_no = a.ticket_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dim.dim_trf_distribution_relation_zip j2
  ON j2.relation_id = a.id
 AND j2.travel_date = '${bizdate}' AND j2.end_date = '9999-12-31'  -- 待确认：关联键
LEFT JOIN dim.dim_trf_distribution_relation_zip j3
  ON j3.relation_id = j2.relation_id
 AND j3.travel_date = '${bizdate}' AND j3.end_date = '9999-12-31'
LEFT JOIN dwd.dwd_fin_frozen_di j4
  ON j4.ticket_no = a.ticket_no AND j4.account_no = a.payee_account_no
 AND j4.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
