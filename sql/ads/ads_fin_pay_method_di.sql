-- ads.ads_fin_pay_method_di  支付方式结构
-- 粒度：travel_date × tenant_id
-- 来源：dws_fin_tenant_pay_method_di
-- 生成方式：Spark SQL / Hive；字段 23 个：直接翻译 3 · 规则翻译 20 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_tenant_pay_method AS (                                                        -- 来源「商户×支付方式 收付款日汇总」按粒度键预聚合
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
),
merged AS (                                                                       -- 按粒度键汇总，计算派生指标
  SELECT
    u.tenant_id,                                                                  -- 租户ID
    u.wechat_inbound_pay_amt,                                                     -- 微信收款金额（日）
    u.alipay_inbound_pay_amt,                                                     -- 支付宝收款金额（日）
    u.balance_inbound_pay_amt,                                                    -- 余额收款金额（日）
    u.credit_inbound_pay_amt,                                                     -- 授信收款金额（日）
    u.offline_inbound_pay_amt,                                                    -- 线下收款收款金额（日）
    u.wechat_pay_record_qty,                                                      -- 微信支付笔数（日）
    u.alipay_pay_record_qty,                                                      -- 支付宝支付笔数（日）
    u.balance_pay_record_qty,                                                     -- 余额支付笔数（日）
    u.credit_pay_record_qty,                                                      -- 授信支付笔数（日）
    u.offline_pay_record_qty,                                                     -- 线下收款支付笔数（日）
    u.wechat_pay_method_share_numerator_amt,                                      -- 微信支付方式占比分子（日）
    u.wechat_pay_method_share_denominator_amt,                                    -- 微信支付方式占比分母（日）
    u.alipay_pay_method_share_numerator_amt,                                      -- 支付宝支付方式占比分子（日）
    u.alipay_pay_method_share_denominator_amt,                                    -- 支付宝支付方式占比分母（日）
    u.balance_pay_method_share_numerator_amt,                                     -- 余额支付方式占比分子（日）
    u.balance_pay_method_share_denominator_amt,                                   -- 余额支付方式占比分母（日）
    u.credit_pay_method_share_numerator_amt,                                      -- 授信支付方式占比分子（日）
    u.credit_pay_method_share_denominator_amt,                                    -- 授信支付方式占比分母（日）
    u.offline_pay_method_share_numerator_amt,                                     -- 线下收款支付方式占比分子（日）
    u.offline_pay_method_share_denominator_amt,                                   -- 线下收款支付方式占比分母（日）
    u.zero_fee_order_qty,                                                         -- 0元单数（日）
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
  FROM src_tenant_pay_method u
),
tenant_cur AS (                                                                   -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'                    -- 取当日分区里的拉链当前有效版本
)
INSERT OVERWRITE TABLE ads.ads_fin_pay_method_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  merged.tenant_id,                                                               -- 租户ID
  tenant_cur.tenant_name AS tenant_name,                                          -- 租户名称
  merged.wechat_inbound_pay_amt,                                                  -- 微信收款金额（日）
  merged.alipay_inbound_pay_amt,                                                  -- 支付宝收款金额（日）
  merged.balance_inbound_pay_amt,                                                 -- 余额收款金额（日）
  merged.credit_inbound_pay_amt,                                                  -- 授信收款金额（日）
  merged.offline_inbound_pay_amt,                                                 -- 线下收款收款金额（日）
  merged.wechat_pay_record_qty,                                                   -- 微信支付笔数（日）
  merged.alipay_pay_record_qty,                                                   -- 支付宝支付笔数（日）
  merged.balance_pay_record_qty,                                                  -- 余额支付笔数（日）
  merged.credit_pay_record_qty,                                                   -- 授信支付笔数（日）
  merged.offline_pay_record_qty,                                                  -- 线下收款支付笔数（日）
  merged.wechat_pay_method_share_numerator_amt,                                   -- 微信支付方式占比分子（日）
  merged.wechat_pay_method_share_denominator_amt,                                 -- 微信支付方式占比分母（日）
  merged.alipay_pay_method_share_numerator_amt,                                   -- 支付宝支付方式占比分子（日）
  merged.alipay_pay_method_share_denominator_amt,                                 -- 支付宝支付方式占比分母（日）
  merged.balance_pay_method_share_numerator_amt,                                  -- 余额支付方式占比分子（日）
  merged.balance_pay_method_share_denominator_amt,                                -- 余额支付方式占比分母（日）
  merged.credit_pay_method_share_numerator_amt,                                   -- 授信支付方式占比分子（日）
  merged.credit_pay_method_share_denominator_amt,                                 -- 授信支付方式占比分母（日）
  merged.offline_pay_method_share_numerator_amt,                                  -- 线下收款支付方式占比分子（日）
  merged.offline_pay_method_share_denominator_amt,                                -- 线下收款支付方式占比分母（日）
  merged.zero_fee_order_qty,                                                      -- 0元单数（日）
  merged.etl_time                                                                 -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                                              -- 关联「租户（商户/供应商/分销商）维度」，补 tenant_name
  ON tenant_cur.tenant_id = merged.tenant_id;                                     -- 按 tenant_id 关联
