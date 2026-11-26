-- dwd.dwd_ord_ticket_credential_di  凭证发码/撤销明细
-- 粒度：1行=1个凭证（credential_no）
-- 来源：ods_ord_ticket_credential_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 16 · 规则翻译 1 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
ticket_credential_rn AS (                                                         -- 「票凭证」当日增量，同一主键按 binlog 时间倒序编号
  SELECT binlog_time, code_pool_id, code_value, create_time, credential_no, credential_type, id, status,
         tenant_id, ticket_no, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_ticket_credential_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
ticket_credential_latest AS (                                                     -- 「票凭证」每个主键只保留最新一条，剔除已删除记录
  SELECT binlog_time, code_pool_id, code_value, create_time, credential_no, credential_type, id, status,
         tenant_id, ticket_no, update_time
  FROM ticket_credential_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
ticket_dtl AS (                                                                   -- 「票明细（出票）」当日数据，只取用到的列
  SELECT order_no, seller_tenant_id, sku_id, ticket_no
  FROM dwd.dwd_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_credential_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  ticket_credential_latest.id                                  AS credential_id,  -- 票凭证ID（源表主键 id）
  ticket_credential_latest.credential_no                       AS credential_no,  -- 凭证号
  ticket_credential_latest.ticket_no                           AS ticket_no,      -- 归属票号
  ticket_credential_latest.credential_type                     AS credential_type,  -- 凭证类型
  ticket_credential_latest.code_value                          AS credential_code,  -- 码值（码池分配）（脱敏）
  ticket_credential_latest.code_pool_id                        AS code_pool_id,   -- 归属码池ID
  ticket_credential_latest.status                              AS credential_status,  -- 状态
  ticket_credential_latest.tenant_id                           AS tenant_id,      -- 租户ID（分库维度）
  ticket_credential_latest.create_time                         AS create_time,    -- 创建时间
  ticket_credential_latest.update_time                         AS update_time,    -- 更新时间
  ticket_dtl.order_no                                          AS order_no,       -- 所属子单号
  ticket_dtl.seller_tenant_id                                  AS seller_tenant_id,  -- 卖家租户ID
  ticket_dtl.sku_id                                            AS sku_id,         -- SKU ID
  ticket_credential_latest.create_time                         AS issue_time,     -- 发码时间
  CASE WHEN ticket_credential_latest.status = 'REVOKED' THEN ticket_credential_latest.binlog_time END AS revoke_time,  -- 撤销时间
  1                                                            AS credential_qty,  -- 凭证数
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM ticket_credential_latest
LEFT JOIN ticket_dtl                                                              -- 关联「票明细（出票）」，取 所属子单号、卖家租户ID、SKU ID
  ON ticket_dtl.ticket_no = ticket_credential_latest.ticket_no;                   -- 按 ticket_no 关联
