-- dwd.dwd_fin_fund_flow_di  资金流水明细
-- 粒度：1行=1条流水（flow_no）
-- 来源：ods_fin_fund_flow_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 18 · 规则翻译 0 · 待确认 1
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_fin_fund_flow_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                             AS flow_id,
  a.flow_no                        AS flow_no,
  a.account_no                     AS account_no,
  a.flow_type                      AS flow_type,
  ROUND(a.amount / 100, 2)         AS change_amt,
  ROUND(a.balance_before / 100, 2) AS balance_before_amt,
  ROUND(a.balance_after / 100, 2)  AS balance_after_amt,
  a.related_no                     AS related_no,
  a.payment_batch_no               AS payment_batch_no,
  a.fee_item                       AS fee_item_code,
  a.remark                         AS remark_desc,
  a.tenant_id                      AS tenant_id,
  a.create_time                    AS create_time,
  a.update_time                    AS update_time,
  j1.account_type                  AS account_type,
  j1.subject_id                    AS subject_id,
  a.amount                         AS flow_direction_type,  -- 待确认：ods_fin_fund_flow_di.amount 正负判定
  a.create_time                    AS flow_time,
  CURRENT_TIMESTAMP()              AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_fin_fund_flow_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dim.dim_fin_account_df j1
  ON j1.account_no = a.account_no
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
