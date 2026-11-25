-- dws.dws_fin_account_frozen_di  账户×冻结类型 冻结日汇总
-- 粒度：travel_date × account_no × freeze_type × external_frozen_type
-- 来源：dwd_fin_frozen_di
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 3 · 规则翻译 1 · 待确认 5
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_fin_account_frozen_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.account_no,                                       -- 账户编号
  u.freeze_type,                                      -- 冻结类型
  u.external_frozen_type,                             -- 是否外部渠道冻结
  SUM(u.freeze_amt) AS freeze_amt,                    -- 冻结金额
  SUM(u.unfreeze_verify_amt) AS unfreeze_verify_amt,  -- 核销解冻金额
  SUM(u.unfreeze_refund_amt) AS unfreeze_refund_amt,  -- 退款释放金额
  SUM(u.freeze_record_qty) AS freeze_record_qty,      -- 冻结记录数
  SUM(u.external_freeze_amt) AS external_freeze_amt,  -- 外部渠道冻结金额
  SUM(u.expire_release_amt) AS expire_release_amt,    -- 过期兜底释放金额
  CURRENT_TIMESTAMP() AS etl_time                     -- ETL 加载时间
FROM (
  -- 来源：dwd_fin_frozen_di
  SELECT
    account_no AS account_no,                         -- 账户编号
    freeze_type AS freeze_type,                       -- 冻结类型
    external_frozen_type AS external_frozen_type,     -- 是否外部渠道冻结
    NULL AS freeze_amt,                               -- 冻结金额｜待确认：sum(amount) by create_date
    NULL AS unfreeze_verify_amt,                      -- 核销解冻金额｜待确认：sum(amount) where frozen_status='RELEASED' and frozen_event='VERIFY'
    NULL AS unfreeze_refund_amt,                      -- 退款释放金额｜待确认：sum(amount) where RELEASED and frozen_event='REFUND'
    COUNT(frozen_no) AS freeze_record_qty,            -- 冻结记录数
    NULL AS external_freeze_amt,                      -- 外部渠道冻结金额｜待确认：sum(amount) where external_frozen=1
    NULL AS expire_release_amt                        -- 过期兜底释放金额｜待确认：sum(amount) where release_reason='EXPIRE_TIMEOUT'
  FROM dwd.dwd_fin_frozen_di s                        -- 来源表「冻结/解冻明细」
  WHERE s.travel_date = '${bizdate}'                  -- 只取当日分区
  GROUP BY account_no, freeze_type, external_frozen_type  -- 按粒度键汇总
) u                                                   -- 各来源合并后的明细
GROUP BY u.account_no, u.freeze_type, u.external_frozen_type;  -- 按粒度键汇总
