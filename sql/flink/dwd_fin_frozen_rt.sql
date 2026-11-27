-- dwd.dwd_fin_frozen_rt  实时冻结/解冻明细
-- 粒度：1行=1条冻结记录（frozen_no）
-- 来源：ods_fin_frozen_record_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 22 个：直接翻译 19 · 规则翻译 3 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_fin_frozen_rt                                                 -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                       AS travel_date,    -- 数据日期
  a.id                                                         AS frozen_id,      -- 冻结记录ID（源表主键 id）
  a.frozen_no                                                  AS frozen_no,      -- 冻结记录编号
  a.account_no                                                 AS account_no,     -- 归属账户编号
  a.ticket_no                                                  AS ticket_no,      -- 关联票号（票级冻结）
  ROUND(a.amount / 100, 2)                                     AS freeze_amt,     -- 冻结金额（元）= 利润/采购款/全款
  a.freeze_type                                                AS freeze_type,    -- 冻结类型
  a.frozen_status                                              AS frozen_status,  -- 状态
  a.frozen_event                                               AS release_event_type,  -- 冻结事件
  a.external_frozen                                            AS external_frozen_type,  -- 是否外部渠道冻结
  a.external_channel                                           AS external_channel_code,  -- 外部渠道(external_frozen=1时)
  a.external_frozen_no                                         AS external_frozen_no,  -- 外部冻结单号
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  j1.account_type                                              AS account_type,   -- 账户类型
  j1.subject_id                                                AS subject_id,     -- 账户主体ID
  j2.sku_id                                                    AS sku_id,         -- SKU ID
  a.create_time                                                AS freeze_time,    -- 冻结时间
  CASE WHEN a.frozen_status = 'RELEASED' THEN a.binlog_time END AS release_time,  -- 解冻时间
  TIMESTAMPDIFF(                                                                  -- 冻结时长（小时）
      HOUR,
      a.create_time,                                                              -- 创建时间
      CASE WHEN a.frozen_status = 'RELEASED' THEN a.binlog_time END
  ) AS freeze_hour_qty,                                                           -- 冻结时长（小时）
  CURRENT_TIMESTAMP                                            AS event_time      -- 事件时间（binlog 时间）
FROM ods.ods_fin_frozen_record_rt a                                               -- 主表「冻结记录 binlog 流」
LEFT JOIN dim.dim_fin_account_df FOR SYSTEM_TIME AS OF a.proc_time AS j1          -- 关联「账户维度」，取 账户类型、账户主体ID
  ON j1.account_no = a.account_no                                                 -- 按 account_no 关联
LEFT JOIN dwd.dwd_ord_ticket_di j2                                                -- 关联「票明细（出票）」，取 SKU ID
  ON j2.ticket_no = a.ticket_no                                                   -- 按 ticket_no 关联
 AND j2.travel_date = '${bizdate}';                                               -- 只取当日分区
