-- ================================================================================================
-- dim.dim_fin_settle_timing_df  结算时点配置
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 结算时点配在支付方式上，由商户配置决定，不预设映射（5.8）
--   · 业务库暂无该字段：补齐前全部取 VERIFY（核销即结算）
-- 性能：
--   · 全量小表
-- ================================================================================================

INSERT OVERWRITE TABLE dim.dim_fin_settle_timing_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    c.tenant_id,                                                                  -- 商户租户ID
    m.pay_method_type,                                                            -- 支付方式
    'VERIFY'                                                         AS settle_timing_type,  -- 结算时点｜待确认：业务库补 settle_timing 后改为 COALESCE(c.settle_timing, 'VERIFY')
    CAST(NULL AS STRING)                                             AS valid_start_time,  -- 配置生效时间｜待确认：同上
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (SELECT DISTINCT tenant_id FROM ods.ods_fin_merchant_payment_config_df WHERE travel_date = '${bizdate}') c
CROSS JOIN (SELECT pay_method_type FROM VALUES ('BALANCE'), ('WECHAT'), ('ALIPAY'), ('CREDIT'), ('OFFLINE'), ('ZERO_FEE') AS v(pay_method_type)) m;
