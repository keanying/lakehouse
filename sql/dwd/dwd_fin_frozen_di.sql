-- dwd.dwd_fin_frozen_di  冻结/解冻明细
-- 粒度：1行=1条冻结记录（frozen_no）
-- 来源：ods_fin_frozen_record_di
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 19 · 规则翻译 2 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
frozen_record_rn AS (                                                             -- 「冻结记录」当日增量，同一主键按 binlog 时间倒序编号
  SELECT account_no, amount, binlog_time, create_time, external_channel, external_frozen,
         external_frozen_no, freeze_type, frozen_event, frozen_no, frozen_status, id, tenant_id,
         ticket_no, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 去重序号（1 = 最新）
  FROM ods.ods_fin_frozen_record_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
frozen_record_latest AS (                                                         -- 「冻结记录」每个主键只保留最新一条，剔除已删除记录
  SELECT account_no, amount, binlog_time, create_time, external_channel, external_frozen,
         external_frozen_no, freeze_type, frozen_event, frozen_no, frozen_status, id, tenant_id,
         ticket_no, update_time
  FROM frozen_record_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
account_dim AS (                                                                  -- 「账户维度」当日数据，只取用到的列
  SELECT account_no, account_type, subject_id
  FROM dim.dim_fin_account_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
ticket_dtl AS (                                                                   -- 「票明细（出票）」当日数据，只取用到的列
  SELECT sku_id, ticket_no
  FROM dwd.dwd_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_fin_frozen_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(account_dim) */
  frozen_record_latest.id                                      AS frozen_id,      -- 冻结记录ID（源表主键 id）
  frozen_record_latest.frozen_no                               AS frozen_no,      -- 冻结记录编号
  frozen_record_latest.account_no                              AS account_no,     -- 归属账户编号
  frozen_record_latest.ticket_no                               AS ticket_no,      -- 关联票号（票级冻结）
  ROUND(frozen_record_latest.amount / 100, 2)                  AS freeze_amt,     -- 冻结金额（元）= 利润/采购款/全款
  frozen_record_latest.freeze_type                             AS freeze_type,    -- 冻结类型
  frozen_record_latest.frozen_status                           AS frozen_status,  -- 状态
  frozen_record_latest.frozen_event                            AS release_event_type,  -- 冻结事件
  frozen_record_latest.external_frozen                         AS external_frozen_type,  -- 是否外部渠道冻结
  frozen_record_latest.external_channel                        AS external_channel_code,  -- 外部渠道(external_frozen=1时)
  frozen_record_latest.external_frozen_no                      AS external_frozen_no,  -- 外部冻结单号
  frozen_record_latest.tenant_id                               AS tenant_id,      -- 租户ID（分库维度）
  frozen_record_latest.create_time                             AS create_time,    -- 创建时间
  frozen_record_latest.update_time                             AS update_time,    -- 更新时间
  account_dim.account_type                                     AS account_type,   -- 账户类型
  account_dim.subject_id                                       AS subject_id,     -- 账户主体ID
  ticket_dtl.sku_id                                            AS sku_id,         -- SKU ID
  frozen_record_latest.create_time                             AS freeze_time,    -- 冻结时间
  CASE                                                                            -- 解冻时间
      WHEN frozen_record_latest.frozen_status = 'RELEASED' THEN frozen_record_latest.binlog_time
  END AS release_time,                                                            -- 解冻时间
  ROUND((UNIX_TIMESTAMP(CASE WHEN frozen_record_latest.frozen_status = 'RELEASED' THEN frozen_record_latest.binlog_time END)  -- 冻结时长（小时）
      - UNIX_TIMESTAMP(frozen_record_latest.create_time)) / 3600, 2) AS freeze_hour_qty,  -- 冻结时长（小时）
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM frozen_record_latest
LEFT JOIN account_dim                                                             -- 关联「账户维度」，取 账户类型、账户主体ID
  ON account_dim.account_no = frozen_record_latest.account_no                     -- 按 account_no 关联
LEFT JOIN ticket_dtl                                                              -- 关联「票明细（出票）」，取 SKU ID
  ON ticket_dtl.ticket_no = frozen_record_latest.ticket_no;                       -- 按 ticket_no 关联
