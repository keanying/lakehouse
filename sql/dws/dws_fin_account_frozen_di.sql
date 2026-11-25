-- dws.dws_fin_account_frozen_di  账户×冻结类型 冻结日汇总
-- 粒度：travel_date × account_no × freeze_type × external_frozen_type
-- 来源：dwd_fin_frozen_di
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 3 · 规则翻译 1 · 待确认 5
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_fin_account_frozen_di PARTITION (travel_date = '${bizdate}')
SELECT
  u.account_no,
  u.freeze_type,
  u.external_frozen_type,
  SUM(u.freeze_amt) AS freeze_amt,
  SUM(u.unfreeze_verify_amt) AS unfreeze_verify_amt,
  SUM(u.unfreeze_refund_amt) AS unfreeze_refund_amt,
  SUM(u.freeze_record_qty) AS freeze_record_qty,
  SUM(u.external_freeze_amt) AS external_freeze_amt,
  SUM(u.expire_release_amt) AS expire_release_amt,
  CURRENT_TIMESTAMP() AS etl_time
FROM (
  -- 来源：dwd_fin_frozen_di
  SELECT
    account_no AS account_no,
    freeze_type AS freeze_type,
    external_frozen_type AS external_frozen_type,
    NULL AS freeze_amt,  -- 待确认：sum(amount) by create_date
    NULL AS unfreeze_verify_amt,  -- 待确认：sum(amount) where frozen_status='RELEASED' and frozen_event='VERIFY'
    NULL AS unfreeze_refund_amt,  -- 待确认：sum(amount) where RELEASED and frozen_event='REFUND'
    COUNT(frozen_no) AS freeze_record_qty,
    NULL AS external_freeze_amt,  -- 待确认：sum(amount) where external_frozen=1
    NULL AS expire_release_amt  -- 待确认：sum(amount) where release_reason='EXPIRE_TIMEOUT'
  FROM dwd.dwd_fin_frozen_di s
  WHERE s.travel_date = '${bizdate}'
  GROUP BY account_no, freeze_type, external_frozen_type
) u
GROUP BY u.account_no, u.freeze_type, u.external_frozen_type;
