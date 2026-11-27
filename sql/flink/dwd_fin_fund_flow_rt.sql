-- ================================================================================================
-- dwd.dwd_fin_fund_flow_rt  实时资金流水明细
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 与离线 dwd_fin_fund_flow_di 同字段，另带归属 report_code（规则同 dim_fin_report_rule_f）
--   · 只处理新增流水（binlog I），流水不可变
-- 性能：
--   · 规则表、账户维表 lookup join（缓存 10 分钟）
-- ================================================================================================

-- Flink SQL：ods_fin_fund_flow_rt（MySQL CDC）→ StarRocks dwd.dwd_fin_fund_flow_rt
INSERT INTO sr_dwd_fin_fund_flow_rt
SELECT
    DATE_FORMAT(f.create_time, 'yyyyMMdd')                           AS travel_date,
    f.id                                                             AS flow_id,
    f.flow_no, f.account_no, f.flow_type,
    CAST(f.amount AS DECIMAL(18,2)) / 100                            AS change_amt,
    CAST(f.balance_before AS DECIMAL(18,2)) / 100                    AS balance_before_amt,
    CAST(f.balance_after AS DECIMAL(18,2)) / 100                     AS balance_after_amt,
    f.related_no, f.payment_batch_no, f.fee_item                     AS fee_item_code,
    f.tenant_id, a.account_type, a.subject_id,
    IF(f.amount >= 0, 1, 2)                                          AS flow_direction_type,
    CAST(f.create_time AS STRING)                                    AS flow_time,
    COALESCE(r.report_code, 'UNCLASSIFIED')                          AS report_code,
    f.proc_time                                                      AS event_time
FROM ods_fin_fund_flow_rt f
LEFT JOIN dim_fin_account_lookup FOR SYSTEM_TIME AS OF f.proc_time AS a ON a.account_no = f.account_no
LEFT JOIN dim_fin_report_rule_lookup FOR SYSTEM_TIME AS OF f.proc_time AS r
       ON r.source_type = 'FUND_FLOW' AND r.flow_type = f.flow_type AND r.direction_type = IF(f.amount >= 0, 'IN', 'OUT')
WHERE f.op_type = 'I';
