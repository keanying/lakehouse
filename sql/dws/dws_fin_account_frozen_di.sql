-- dws.dws_fin_account_frozen_di  账户×冻结类型 冻结日汇总
-- 粒度：travel_date × account_no × freeze_type × external_frozen_type
-- 来源：dwd_fin_frozen_di
-- 生成方式：Spark SQL / Hive；字段 9 个：直接翻译 3 · 规则翻译 6 · 待确认 0
-- 来源先按粒度键预聚合

WITH
src_frozen AS (                                                                   -- 来源「冻结/解冻明细」按粒度键预聚合
  SELECT
    account_no AS account_no,                                                     -- 账户编号
    freeze_type AS freeze_type,                                                   -- 冻结类型
    external_frozen_type AS external_frozen_type,                                 -- 是否外部渠道冻结
    SUM(freeze_amt) AS freeze_amt,                                                -- 冻结金额
    SUM(CASE WHEN frozen_status='RELEASED' and release_event_type='VERIFY' THEN freeze_amt END) AS unfreeze_verify_amt,  -- 核销解冻金额
    SUM(CASE WHEN frozen_status = 'RELEASED' and release_event_type='REFUND' THEN freeze_amt END) AS unfreeze_refund_amt,  -- 退款释放金额
    COUNT(frozen_no) AS freeze_record_qty,                                        -- 冻结记录数
    SUM(CASE WHEN external_frozen_type=1 THEN freeze_amt END) AS external_freeze_amt,  -- 外部渠道冻结金额
    SUM(CASE WHEN frozen_status = 'RELEASED' AND DATE_FORMAT(release_time, 'yyyyMMdd') = '${bizdate}'  -- 过期兜底释放金额｜口径：口径说明：冻结记录没有释放原因字段，按「当日释放、且冻结事件既不是核销也不是退款」认定为过期兜底释放
        AND COALESCE(release_event_type, '') NOT IN ('VERIFY', 'REFUND') THEN freeze_amt END) AS expire_release_amt  -- 过期兜底释放金额
  FROM dwd.dwd_fin_frozen_di s                                                    -- 来源表「冻结/解冻明细」
  WHERE s.travel_date = '${bizdate}'                                              -- 只取当日分区
  GROUP BY account_no, freeze_type, external_frozen_type                          -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dws.dws_fin_account_frozen_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.account_no,                                                                   -- 账户编号
  u.freeze_type,                                                                  -- 冻结类型
  u.external_frozen_type,                                                         -- 是否外部渠道冻结
  u.freeze_amt,                                                                   -- 冻结金额
  u.unfreeze_verify_amt,                                                          -- 核销解冻金额
  u.unfreeze_refund_amt,                                                          -- 退款释放金额
  u.freeze_record_qty,                                                            -- 冻结记录数
  u.external_freeze_amt,                                                          -- 外部渠道冻结金额
  u.expire_release_amt,                                                           -- 过期兜底释放金额
  CURRENT_TIMESTAMP() AS etl_time                                                 -- ETL 加载时间
FROM src_frozen u;
