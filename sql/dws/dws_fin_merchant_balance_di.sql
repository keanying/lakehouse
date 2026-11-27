-- ================================================================================================
-- dws.dws_fin_merchant_balance_di  商户余额与费用日汇总
-- 依据：《3.0 通用财务报表 · 需求说明》v1.0（2026-11-24）
-- 业务规则：
--   · 只取商户 / 分销商账户（平台账户不算），双式记账只算本方这一条（风险 2）
--   · 归属按规则表：命中多条时取最具体（带冻结事件 > 带方向 > 只按流水类型）；都不命中 = UNCLASSIFIED（需求 5.5）
--   · 解冻流水分核销 / 退款：关联同账户同票的冻结记录；待确认：流水 related_no 对解冻填什么（冻结单号 / 票号）需研发确认
-- 性能：
--   · 规则表 BROADCAST；冻结记录只取当日释放的
-- ================================================================================================

WITH f AS (
    SELECT /*+ BROADCAST(a) */ f.flow_no, f.account_no, a.subject_id AS merchant_tenant_id, f.flow_type, f.fee_item_code, f.change_amt, f.related_no,
           IF(f.change_amt >= 0, 'IN', 'OUT') AS direction_type
    FROM dwd.dwd_fin_fund_flow_di f
    JOIN (SELECT account_no, subject_id, account_type FROM dim.dim_fin_account_df WHERE travel_date = '${bizdate}' AND account_type IN ('MERCHANT', 'DISTRIBUTOR')) a ON a.account_no = f.account_no
    WHERE f.travel_date = '${bizdate}'
),
ev AS (   -- 解冻流水的冻结事件：related_no 对冻结单号或票号（待确认）
    SELECT account_no, frozen_no, ticket_no, release_event_type FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}' AND frozen_status = 'RELEASED'
),
m AS (
    SELECT f.*, COALESCE(e1.release_event_type, e2.release_event_type) AS frozen_event_type
    FROM f
    LEFT JOIN ev e1 ON f.flow_type = 'UNFREEZE' AND e1.account_no = f.account_no AND e1.frozen_no = f.related_no
    LEFT JOIN ev e2 ON f.flow_type = 'UNFREEZE' AND e1.frozen_no IS NULL AND e2.account_no = f.account_no AND e2.ticket_no = f.related_no
),
hit AS (   -- 规则匹配：取最具体的一条
    SELECT m.flow_no, r.report_code,
           ROW_NUMBER() OVER (PARTITION BY m.flow_no ORDER BY (r.frozen_event_type <> '') DESC, (r.direction_type <> '') DESC, (r.fee_item_code <> '') DESC) AS rn
    FROM m
    JOIN (SELECT * FROM dim.dim_fin_report_rule_f WHERE source_type = 'FUND_FLOW') r
      ON r.flow_type = m.flow_type AND (r.fee_item_code = '' OR r.fee_item_code = m.fee_item_code)
     AND (r.direction_type = '' OR r.direction_type = m.direction_type) AND (r.frozen_event_type = '' OR r.frozen_event_type = m.frozen_event_type)
)
INSERT OVERWRITE TABLE dws.dws_fin_merchant_balance_di PARTITION (travel_date = '${bizdate}')
SELECT m.merchant_tenant_id, m.account_no, COALESCE(h.report_code, 'UNCLASSIFIED') AS report_code, m.flow_type, COALESCE(m.fee_item_code, '') AS fee_item_code,
       SUM(IF(m.change_amt > 0, m.change_amt, 0))                    AS fund_in_amt,
       -SUM(IF(m.change_amt < 0, m.change_amt, 0))                   AS fund_out_amt,
       COUNT(m.flow_no)                                              AS fund_flow_qty,
       DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM m
LEFT JOIN (SELECT flow_no, report_code FROM hit WHERE rn = 1) h ON h.flow_no = m.flow_no
GROUP BY m.merchant_tenant_id, m.account_no, COALESCE(h.report_code, 'UNCLASSIFIED'), m.flow_type, COALESCE(m.fee_item_code, '');
