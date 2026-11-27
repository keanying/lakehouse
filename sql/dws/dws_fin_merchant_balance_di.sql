-- ================================================================================================
-- dws.dws_fin_merchant_balance_di  商户余额与费用日汇总
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 按余额明细汇总：流入 / 流出、笔数；归属与费用类型沿用明细
-- 性能：
--   · 单表扫描当日分区
-- ================================================================================================

INSERT OVERWRITE TABLE dws.dws_fin_merchant_balance_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT merchant_tenant_id, account_no, report_code, fee_type_name, flow_type, fee_item_code,
       SUM(IF(change_amt > 0, change_amt, 0))                        AS fund_in_amt,  -- 资金流入
       -SUM(IF(change_amt < 0, change_amt, 0))                       AS fund_out_amt,  -- 资金流出
       COUNT(flow_no)                                                AS fund_flow_qty,  -- 流水笔数
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time        -- ETL 加载时间
FROM dwd.dwd_fin_balance_detail_di
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
GROUP BY merchant_tenant_id, account_no, report_code, fee_type_name, flow_type, fee_item_code;  -- 按粒度键汇总
