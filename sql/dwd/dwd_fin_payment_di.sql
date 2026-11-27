-- dwd.dwd_fin_payment_di  支付明细
-- 粒度：1行=1条支付记录（payment_no）
-- 来源：ods_fin_payment_record_di
-- 生成方式：Spark SQL / Hive；字段 29 个：直接翻译 26 · 规则翻译 3 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
payment_record_rn AS (                                                            -- 「支付记录」当日增量，同一主键按 binlog 时间倒序编号
  SELECT amount, batch_no, create_time, depend_on_item, external_frozen, freeze_instructions, id, item_no,
         order_group_no, pay_direction, pay_method, pay_status, pay_time, payee_account_no,
         payer_account_no, payment_no, receive_channel, settle_amount, tenant_id, ticket_no,
         transaction_no, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 去重序号（1 = 最新）
  FROM ods.ods_fin_payment_record_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
payment_record_latest AS (                                                        -- 「支付记录」每个主键只保留最新一条，剔除已删除记录
  SELECT amount, batch_no, create_time, depend_on_item, external_frozen, freeze_instructions, id, item_no,
         order_group_no, pay_direction, pay_method, pay_status, pay_time, payee_account_no,
         payer_account_no, payment_no, receive_channel, settle_amount, tenant_id, ticket_no,
         transaction_no, update_time
  FROM payment_record_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
order_group_dtl AS (                                                              -- 「聚合单明细」当日数据，只取用到的列
  SELECT order_group_no, seller_tenant_id
  FROM dwd.dwd_ord_order_group_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
account_dim AS (                                                                  -- 「账户维度」当日数据，只取用到的列
  SELECT account_no, subject_id
  FROM dim.dim_fin_account_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
account_dim_2 AS (                                                                -- 「账户维度」当日数据，只取用到的列
  SELECT account_no, subject_id
  FROM dim.dim_fin_account_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
ticket_dtl AS (                                                                   -- 「票明细（出票）」当日数据，只取用到的列
  SELECT sku_id, ticket_no
  FROM dwd.dwd_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_fin_payment_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(account_dim, account_dim_2) */
  payment_record_latest.id                                     AS payment_id,     -- 支付记录ID（源表主键 id）
  payment_record_latest.payment_no                             AS payment_no,     -- 支付流水号
  payment_record_latest.batch_no                               AS batch_no,       -- 批量支付单号(同批共享)
  payment_record_latest.item_no                                AS item_no,        -- 批内项号
  payment_record_latest.depend_on_item                         AS depend_on_item_no,  -- 依赖项号
  payment_record_latest.order_group_no                         AS order_group_no,  -- 归属聚合单号
  payment_record_latest.pay_direction                          AS pay_direction_type,  -- 资金方向
  payment_record_latest.pay_method                             AS pay_method_type,  -- 支付方式
  payment_record_latest.receive_channel                        AS receive_channel_type,  -- 收款渠道(INBOUND-收款时填)
  ROUND(payment_record_latest.amount / 100, 2)                 AS pay_amt,        -- 支付金额（元）
  ROUND(payment_record_latest.settle_amount / 100, 2)          AS settle_amt,     -- 结算金额
  payment_record_latest.transaction_no                         AS transaction_no,  -- 渠道流水号
  payment_record_latest.payer_account_no                       AS payer_account_no,  -- 付款方账户
  payment_record_latest.payee_account_no                       AS payee_account_no,  -- 收款方账户
  payment_record_latest.ticket_no                              AS ticket_no,      -- 关联票号(用于关联冻结记录)
  payment_record_latest.external_frozen                        AS external_frozen_type,  -- 是否外部渠道冻结
  payment_record_latest.pay_time                               AS pay_time,       -- 支付时间
  payment_record_latest.pay_status                             AS pay_status,     -- 支付状态
  payment_record_latest.tenant_id                              AS tenant_id,      -- 租户ID（分库维度）
  payment_record_latest.create_time                            AS create_time,    -- 创建时间
  payment_record_latest.update_time                            AS update_time,    -- 更新时间
  order_group_dtl.seller_tenant_id                             AS seller_tenant_id,  -- 卖家租户ID
  account_dim.subject_id                                       AS payer_tenant_id,  -- 付款方租户ID
  account_dim_2.subject_id                                     AS payee_tenant_id,  -- 收款方租户ID
  ticket_dtl.sku_id                                            AS sku_id,         -- SKU ID（按票关联）
  GET_JSON_OBJECT(payment_record_latest.freeze_instructions, '$[0].freezeType') AS freeze_type,  -- 冻结类型
  ROUND(payment_record_latest.amount - payment_record_latest.settle_amount /100, 2) AS profit_amt,  -- 本级利润（元）= 支付金额 - 结算金额
  DATE_FORMAT(payment_record_latest.pay_time, 'yyyyMMdd')      AS pay_date,       -- 支付日期
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM payment_record_latest
LEFT JOIN order_group_dtl                                                         -- 关联「聚合单明细」，取 卖家租户ID
  ON order_group_dtl.order_group_no = payment_record_latest.order_group_no        -- 按 order_group_no 关联
LEFT JOIN account_dim                                                             -- 关联「账户维度」，取 付款方租户ID
  ON account_dim.account_no = payment_record_latest.payer_account_no              -- 按 payer_account_no→account_no 关联
LEFT JOIN account_dim_2                                                           -- 关联「账户维度」，取 收款方租户ID
  ON account_dim_2.account_no = payment_record_latest.payee_account_no            -- 按 payee_account_no→account_no 关联
LEFT JOIN ticket_dtl                                                              -- 关联「票明细（出票）」，取 SKU ID（按票关联）
  ON ticket_dtl.ticket_no = payment_record_latest.ticket_no;                      -- 按 ticket_no 关联
