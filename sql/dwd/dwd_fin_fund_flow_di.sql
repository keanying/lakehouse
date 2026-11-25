-- dwd.dwd_fin_fund_flow_di  资金流水明细
-- 粒度：1行=1条流水（flow_no）
-- 来源：ods_fin_fund_flow_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 18 · 规则翻译 0 · 待确认 1
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_fin_fund_flow_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                             AS flow_id,            -- 资金流水ID（源表主键 id）
  a.flow_no                        AS flow_no,            -- 流水号
  a.account_no                     AS account_no,         -- 归属账户编号
  a.flow_type                      AS flow_type,          -- 流水类型
  ROUND(a.amount / 100, 2)         AS change_amt,         -- 变动金额（元
  ROUND(a.balance_before / 100, 2) AS balance_before_amt,  -- 变动前余额（元）
  ROUND(a.balance_after / 100, 2)  AS balance_after_amt,  -- 变动后余额（元）
  a.related_no                     AS related_no,         -- 关联业务号（订单号/退款号/提现号等）
  a.payment_batch_no               AS payment_batch_no,   -- 关联支付批次号(追溯资金动作来源)
  a.fee_item                       AS fee_item_code,      -- 费用项（短信费/提现手续费等）
  a.remark                         AS remark_desc,        -- 备注
  a.tenant_id                      AS tenant_id,          -- 租户ID（分库维度）
  a.create_time                    AS create_time,        -- 创建时间
  a.update_time                    AS update_time,        -- 更新时间
  j1.account_type                  AS account_type,       -- 账户类型
  j1.subject_id                    AS subject_id,         -- 账户主体ID
  a.amount                         AS flow_direction_type,  -- 资金方向｜待确认：ods_fin_fund_flow_di.amount 正负判定
  a.create_time                    AS flow_time,          -- 流水发生时间
  CURRENT_TIMESTAMP()              AS etl_time            -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_fin_fund_flow_di
  WHERE travel_date = '${bizdate}'                        -- 只取当日分区
) a                                                       -- 主表当日增量，按主键取最新一条
LEFT JOIN dim.dim_fin_account_df j1                       -- 关联「账户维度」，取 账户类型、账户主体ID
  ON j1.account_no = a.account_no                         -- 按 account_no 关联
 AND j1.travel_date = '${bizdate}'                        -- 只取当日分区
WHERE a.rn = 1                                            -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                       -- 剔除源库已删除的记录
