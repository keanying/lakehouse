-- dwd.dwd_fin_payment_rt  实时支付明细
-- 粒度：1行=1条支付记录（payment_no）
-- 来源：ods_fin_payment_record_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 30 个：直接翻译 26 · 规则翻译 4 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_fin_payment_rt                                             -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                 AS travel_date,       -- 数据日期
  a.id                                                   AS payment_id,        -- 支付记录ID（源表主键 id）
  a.payment_no                                           AS payment_no,        -- 支付流水号
  a.batch_no                                             AS batch_no,          -- 批量支付单号(同批共享)
  a.item_no                                              AS item_no,           -- 批内项号(批内唯一
  a.depend_on_item                                       AS depend_on_item_no,  -- 依赖项号(必须在依赖项成功后执行
  a.order_group_no                                       AS order_group_no,    -- 归属聚合单号
  a.pay_direction                                        AS pay_direction_type,  -- 资金方向
  a.pay_method                                           AS pay_method_type,   -- 支付方式
  a.receive_channel                                      AS receive_channel_type,  -- 收款渠道(INBOUND-收款时填)
  ROUND(a.amount / 100, 2)                               AS pay_amt,           -- 支付金额（元）
  ROUND(a.settle_amount / 100, 2)                        AS settle_amt,        -- 结算金额（元
  a.transaction_no                                       AS transaction_no,    -- 渠道流水号
  a.payer_account_no                                     AS payer_account_no,  -- 付款方账户(OUTBOUND-采购付款=采购方
  a.payee_account_no                                     AS payee_account_no,  -- 收款方账户(INBOUND-收款=卖方
  a.ticket_no                                            AS ticket_no,         -- 关联票号(用于关联冻结记录)
  a.external_frozen                                      AS external_frozen_type,  -- 是否外部渠道冻结
  a.pay_time                                             AS pay_time,          -- 支付时间
  a.pay_status                                           AS pay_status,        -- 支付状态
  a.tenant_id                                            AS tenant_id,         -- 租户ID（分库维度）
  a.create_time                                          AS create_time,       -- 创建时间
  a.update_time                                          AS update_time,       -- 更新时间
  j1.seller_tenant_id                                    AS seller_tenant_id,  -- 卖家租户ID
  j2.subject_id                                          AS payer_tenant_id,   -- 付款方租户ID
  j3.subject_id                                          AS payee_tenant_id,   -- 收款方租户ID
  j4.sku_id                                              AS sku_id,            -- SKU ID（按票关联）
  GET_JSON_OBJECT(a.freeze_instructions, '$.freezeType') AS freeze_type,       -- 冻结类型
  ROUND(a.amount - a.settle_amount /100, 2)              AS profit_amt,        -- 本级利润（元）= 支付金额 - 结算金额
  DATE_FORMAT(a.pay_time, 'yyyyMMdd')                    AS pay_date,          -- 支付日期
  CURRENT_TIMESTAMP                                      AS event_time         -- 事件时间（binlog 时间）
FROM ods.ods_fin_payment_record_rt a                                           -- 主表「支付记录 binlog 流」
LEFT JOIN dwd.dwd_ord_order_group_di j1                                        -- 关联「聚合单明细」，取 卖家租户ID
  ON j1.order_group_no = a.order_group_no                                      -- 按 order_group_no 关联
 AND j1.travel_date = '${bizdate}'                                             -- 只取当日分区
LEFT JOIN dim.dim_fin_account_df FOR SYSTEM_TIME AS OF a.proc_time AS j2       -- 关联「账户维度」，取 付款方租户ID
  ON j2.account_no = a.payer_account_no                                        -- 按 payer_account_no→account_no 关联
LEFT JOIN dim.dim_fin_account_df FOR SYSTEM_TIME AS OF a.proc_time AS j3       -- 关联「账户维度」，取 收款方租户ID
  ON j3.account_no = a.payee_account_no                                        -- 按 payee_account_no→account_no 关联
LEFT JOIN dwd.dwd_ord_ticket_di j4                                             -- 关联「票明细（出票）」，取 SKU ID（按票关联）
  ON j4.ticket_no = a.ticket_no                                                -- 按 ticket_no 关联
 AND j4.travel_date = '${bizdate}';                                            -- 只取当日分区
