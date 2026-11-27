-- ================================================================================================
-- ads.ads_fin_unclassified_flow_di  待归类资金流水异常清单
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 未命中归属规则的流水逐条列出（5.5），不进任何报表；产品确认后在归属规则表补规则，重跑当日即可
-- 性能：
--   · 单表过滤
-- ================================================================================================

INSERT OVERWRITE TABLE ads.ads_fin_unclassified_flow_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT flow_no,                                                             -- 资金流水号
       flow_time,                                                           -- 交易时间
       merchant_tenant_id,                                                  -- 本方商户租户ID
       account_no,                                                          -- 账本
       flow_type,                                                           -- 流水类型
       fee_item_code,                                                       -- 费用项
       frozen_event_type,                                                   -- 冻结事件
       change_amt,                                                          -- 变动金额（元）
       related_no,                                                          -- 关联业务号
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time  -- ETL 加载时间
FROM dwd.dwd_fin_balance_detail_di
WHERE travel_date = '${bizdate}' AND report_code = 'UNCLASSIFIED';          -- 只取当日分区，并按条件过滤
