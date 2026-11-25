-- dwd.dwd_fin_frozen_di  冻结/解冻明细
-- 粒度：1行=1条冻结记录（frozen_no）
-- 来源：ods_fin_frozen_record_di
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 19 · 规则翻译 2 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_fin_frozen_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
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
  a.external_frozen_no                                         AS external_frozen_no,  -- 外部冻结单号(第三方返回的冻结流水号
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  j1.account_type                                              AS account_type,   -- 账户类型
  j1.subject_id                                                AS subject_id,     -- 账户主体ID
  j2.sku_id                                                    AS sku_id,         -- SKU ID
  a.create_time                                                AS freeze_time,    -- 冻结时间
  CASE WHEN a.frozen_status = 'RELEASED' THEN a.binlog_time END AS release_time,  -- 解冻时间
  (CASE WHEN a.frozen_status = 'RELEASED' THEN a.binlog_time END) - (a.create_time) AS freeze_hour_qty,  -- 冻结时长（小时）
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_fin_frozen_record_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
) a                                                                               -- 主表当日增量，按主键取最新一条
LEFT JOIN dim.dim_fin_account_df j1                                               -- 关联「账户维度」，取 账户类型、账户主体ID
  ON j1.account_no = a.account_no                                                 -- 按 account_no 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
LEFT JOIN dwd.dwd_ord_ticket_di j2                                                -- 关联「票明细（出票）」，取 SKU ID
  ON j2.ticket_no = a.ticket_no                                                   -- 按 ticket_no 关联
 AND j2.travel_date = '${bizdate}'                                                -- 只取当日分区
WHERE a.rn = 1                                                                    -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                               -- 剔除源库已删除的记录
