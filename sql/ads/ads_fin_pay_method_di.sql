-- ads.ads_fin_pay_method_di  支付方式结构
-- 粒度：travel_date × tenant_id
-- 来源：dws_fin_tenant_pay_method_di
-- 生成方式：Spark SQL / Hive；字段 23 个：直接翻译 3 · 规则翻译 20 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_fin_pay_method_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.tenant_id,                                                                    -- 租户ID
  d1.tenant_name AS tenant_name,                                                  -- 租户名称
  x.wechat_inbound_pay_amt,                                                       -- 微信收款金额（日）
  x.alipay_inbound_pay_amt,                                                       -- 支付宝收款金额（日）
  x.balance_inbound_pay_amt,                                                      -- 余额收款金额（日）
  x.credit_inbound_pay_amt,                                                       -- 授信收款金额（日）
  x.offline_inbound_pay_amt,                                                      -- 线下收款收款金额（日）
  x.wechat_pay_record_qty,                                                        -- 微信支付笔数（日）
  x.alipay_pay_record_qty,                                                        -- 支付宝支付笔数（日）
  x.balance_pay_record_qty,                                                       -- 余额支付笔数（日）
  x.credit_pay_record_qty,                                                        -- 授信支付笔数（日）
  x.offline_pay_record_qty,                                                       -- 线下收款支付笔数（日）
  x.wechat_pay_method_share_numerator_amt,                                        -- 微信支付方式占比分子（日）
  x.wechat_pay_method_share_denominator_amt,                                      -- 微信支付方式占比分母（日）
  x.alipay_pay_method_share_numerator_amt,                                        -- 支付宝支付方式占比分子（日）
  x.alipay_pay_method_share_denominator_amt,                                      -- 支付宝支付方式占比分母（日）
  x.balance_pay_method_share_numerator_amt,                                       -- 余额支付方式占比分子（日）
  x.balance_pay_method_share_denominator_amt,                                     -- 余额支付方式占比分母（日）
  x.credit_pay_method_share_numerator_amt,                                        -- 授信支付方式占比分子（日）
  x.credit_pay_method_share_denominator_amt,                                      -- 授信支付方式占比分母（日）
  x.offline_pay_method_share_numerator_amt,                                       -- 线下收款支付方式占比分子（日）
  x.offline_pay_method_share_denominator_amt,                                     -- 线下收款支付方式占比分母（日）
  x.zero_fee_order_qty,                                                           -- 0元单数（日）
  x.etl_time                                                                      -- ETL 加载时间
FROM (
SELECT
  u.tenant_id,                                                                    -- 租户ID
  SUM(u.wechat_inbound_pay_amt) AS wechat_inbound_pay_amt,                        -- 微信收款金额（日）
  SUM(u.alipay_inbound_pay_amt) AS alipay_inbound_pay_amt,                        -- 支付宝收款金额（日）
  SUM(u.balance_inbound_pay_amt) AS balance_inbound_pay_amt,                      -- 余额收款金额（日）
  SUM(u.credit_inbound_pay_amt) AS credit_inbound_pay_amt,                        -- 授信收款金额（日）
  SUM(u.offline_inbound_pay_amt) AS offline_inbound_pay_amt,                      -- 线下收款收款金额（日）
  SUM(u.wechat_pay_record_qty) AS wechat_pay_record_qty,                          -- 微信支付笔数（日）
  SUM(u.alipay_pay_record_qty) AS alipay_pay_record_qty,                          -- 支付宝支付笔数（日）
  SUM(u.balance_pay_record_qty) AS balance_pay_record_qty,                        -- 余额支付笔数（日）
  SUM(u.credit_pay_record_qty) AS credit_pay_record_qty,                          -- 授信支付笔数（日）
  SUM(u.offline_pay_record_qty) AS offline_pay_record_qty,                        -- 线下收款支付笔数（日）
  SUM(u.wechat_pay_method_share_numerator_amt) AS wechat_pay_method_share_numerator_amt,  -- 微信支付方式占比分子（日）
  SUM(u.wechat_pay_method_share_denominator_amt) AS wechat_pay_method_share_denominator_amt,  -- 微信支付方式占比分母（日）
  SUM(u.alipay_pay_method_share_numerator_amt) AS alipay_pay_method_share_numerator_amt,  -- 支付宝支付方式占比分子（日）
  SUM(u.alipay_pay_method_share_denominator_amt) AS alipay_pay_method_share_denominator_amt,  -- 支付宝支付方式占比分母（日）
  SUM(u.balance_pay_method_share_numerator_amt) AS balance_pay_method_share_numerator_amt,  -- 余额支付方式占比分子（日）
  SUM(u.balance_pay_method_share_denominator_amt) AS balance_pay_method_share_denominator_amt,  -- 余额支付方式占比分母（日）
  SUM(u.credit_pay_method_share_numerator_amt) AS credit_pay_method_share_numerator_amt,  -- 授信支付方式占比分子（日）
  SUM(u.credit_pay_method_share_denominator_amt) AS credit_pay_method_share_denominator_amt,  -- 授信支付方式占比分母（日）
  SUM(u.offline_pay_method_share_numerator_amt) AS offline_pay_method_share_numerator_amt,  -- 线下收款支付方式占比分子（日）
  SUM(u.offline_pay_method_share_denominator_amt) AS offline_pay_method_share_denominator_amt,  -- 线下收款支付方式占比分母（日）
  SUM(u.zero_fee_order_qty) AS zero_fee_order_qty,                                -- 0元单数（日）
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM (
  -- 来源：dws_fin_tenant_pay_method_di
  SELECT
    tenant_id AS tenant_id,                                                       -- 租户ID
    SUM(CASE WHEN pay_method_type = 'WECHAT' THEN inbound_pay_amt END) AS wechat_inbound_pay_amt,  -- 微信收款金额（日）
    SUM(CASE WHEN pay_method_type = 'ALIPAY' THEN inbound_pay_amt END) AS alipay_inbound_pay_amt,  -- 支付宝收款金额（日）
    SUM(CASE WHEN pay_method_type = 'BALANCE' THEN inbound_pay_amt END) AS balance_inbound_pay_amt,  -- 余额收款金额（日）
    SUM(CASE WHEN pay_method_type = 'CREDIT' THEN inbound_pay_amt END) AS credit_inbound_pay_amt,  -- 授信收款金额（日）
    SUM(CASE WHEN pay_method_type = 'OFFLINE' THEN inbound_pay_amt END) AS offline_inbound_pay_amt,  -- 线下收款收款金额（日）
    SUM(CASE WHEN pay_method_type = 'WECHAT' THEN pay_record_qty END) AS wechat_pay_record_qty,  -- 微信支付笔数（日）
    SUM(CASE WHEN pay_method_type = 'ALIPAY' THEN pay_record_qty END) AS alipay_pay_record_qty,  -- 支付宝支付笔数（日）
    SUM(CASE WHEN pay_method_type = 'BALANCE' THEN pay_record_qty END) AS balance_pay_record_qty,  -- 余额支付笔数（日）
    SUM(CASE WHEN pay_method_type = 'CREDIT' THEN pay_record_qty END) AS credit_pay_record_qty,  -- 授信支付笔数（日）
    SUM(CASE WHEN pay_method_type = 'OFFLINE' THEN pay_record_qty END) AS offline_pay_record_qty,  -- 线下收款支付笔数（日）
    SUM(CASE WHEN pay_method_type = 'WECHAT' THEN inbound_pay_amt END) AS wechat_pay_method_share_numerator_amt,  -- 微信支付方式占比分子（日）
    SUM(CASE WHEN pay_method_type = 'WECHAT' THEN inbound_pay_amt END) AS wechat_pay_method_share_denominator_amt,  -- 微信支付方式占比分母（日）
    SUM(CASE WHEN pay_method_type = 'ALIPAY' THEN inbound_pay_amt END) AS alipay_pay_method_share_numerator_amt,  -- 支付宝支付方式占比分子（日）
    SUM(CASE WHEN pay_method_type = 'ALIPAY' THEN inbound_pay_amt END) AS alipay_pay_method_share_denominator_amt,  -- 支付宝支付方式占比分母（日）
    SUM(CASE WHEN pay_method_type = 'BALANCE' THEN inbound_pay_amt END) AS balance_pay_method_share_numerator_amt,  -- 余额支付方式占比分子（日）
    SUM(CASE WHEN pay_method_type = 'BALANCE' THEN inbound_pay_amt END) AS balance_pay_method_share_denominator_amt,  -- 余额支付方式占比分母（日）
    SUM(CASE WHEN pay_method_type = 'CREDIT' THEN inbound_pay_amt END) AS credit_pay_method_share_numerator_amt,  -- 授信支付方式占比分子（日）
    SUM(CASE WHEN pay_method_type = 'CREDIT' THEN inbound_pay_amt END) AS credit_pay_method_share_denominator_amt,  -- 授信支付方式占比分母（日）
    SUM(CASE WHEN pay_method_type = 'OFFLINE' THEN inbound_pay_amt END) AS offline_pay_method_share_numerator_amt,  -- 线下收款支付方式占比分子（日）
    SUM(CASE WHEN pay_method_type = 'OFFLINE' THEN inbound_pay_amt END) AS offline_pay_method_share_denominator_amt,  -- 线下收款支付方式占比分母（日）
    SUM(zero_fee_order_qty) AS zero_fee_order_qty                                 -- 0元单数（日）
  FROM dws.dws_fin_tenant_pay_method_di s                                         -- 来源表「商户×支付方式 收付款日汇总」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY tenant_id                                                              -- 按粒度键汇总
) u                                                                               -- 各来源合并后的明细
GROUP BY u.tenant_id                                                              -- 按粒度键汇总
) x                                                                               -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31';  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
