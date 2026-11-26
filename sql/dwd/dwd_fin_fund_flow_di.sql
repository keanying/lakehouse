-- dwd.dwd_fin_fund_flow_di  资金流水明细
-- 粒度：1行=1条流水（flow_no）
-- 来源：ods_fin_fund_flow_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 18 · 规则翻译 0 · 待确认 1
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
fund_flow_rn AS (                                                        -- 「资金流水」当日增量，同一主键按 binlog 时间倒序编号
  SELECT account_no, amount, balance_after, balance_before, create_time, fee_item, flow_no, flow_type, id,
         payment_batch_no, related_no, remark, tenant_id, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_fin_fund_flow_di
  WHERE travel_date = '${bizdate}'                                       -- 只取当日分区
),
fund_flow_latest AS (                                                    -- 「资金流水」每个主键只保留最新一条，剔除已删除记录
  SELECT account_no, amount, balance_after, balance_before, create_time, fee_item, flow_no, flow_type, id,
         payment_batch_no, related_no, remark, tenant_id, update_time
  FROM fund_flow_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                       -- 剔除源库已删除的记录
),
account_dim AS (                                                         -- 「账户维度」当日数据，只取用到的列
  SELECT account_no, account_type, subject_id
  FROM dim.dim_fin_account_df
  WHERE travel_date = '${bizdate}'                                       -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_fin_fund_flow_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(account_dim) */
  fund_flow_latest.id                             AS flow_id,            -- 资金流水ID（源表主键 id）
  fund_flow_latest.flow_no                        AS flow_no,            -- 流水号
  fund_flow_latest.account_no                     AS account_no,         -- 归属账户编号
  fund_flow_latest.flow_type                      AS flow_type,          -- 流水类型
  ROUND(fund_flow_latest.amount / 100, 2)         AS change_amt,         -- 变动金额（元
  ROUND(fund_flow_latest.balance_before / 100, 2) AS balance_before_amt,  -- 变动前余额（元）
  ROUND(fund_flow_latest.balance_after / 100, 2)  AS balance_after_amt,  -- 变动后余额（元）
  fund_flow_latest.related_no                     AS related_no,         -- 关联业务号（订单号/退款号/提现号等）
  fund_flow_latest.payment_batch_no               AS payment_batch_no,   -- 关联支付批次号(追溯资金动作来源)
  fund_flow_latest.fee_item                       AS fee_item_code,      -- 费用项（短信费/提现手续费等）
  fund_flow_latest.remark                         AS remark_desc,        -- 备注
  fund_flow_latest.tenant_id                      AS tenant_id,          -- 租户ID（分库维度）
  fund_flow_latest.create_time                    AS create_time,        -- 创建时间
  fund_flow_latest.update_time                    AS update_time,        -- 更新时间
  account_dim.account_type                        AS account_type,       -- 账户类型
  account_dim.subject_id                          AS subject_id,         -- 账户主体ID
  fund_flow_latest.amount                         AS flow_direction_type,  -- 资金方向｜待确认：ods_fin_fund_flow_di.amount 正负判定
  fund_flow_latest.create_time                    AS flow_time,          -- 流水发生时间
  CURRENT_TIMESTAMP()                             AS etl_time            -- ETL 加载时间
FROM fund_flow_latest
LEFT JOIN account_dim                                                    -- 关联「账户维度」，取 账户类型、账户主体ID
  ON account_dim.account_no = fund_flow_latest.account_no;               -- 按 account_no 关联
