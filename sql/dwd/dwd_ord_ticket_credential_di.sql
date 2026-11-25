-- dwd.dwd_ord_ticket_credential_di  凭证发码/撤销明细
-- 粒度：1行=1个凭证（credential_no）
-- 来源：ods_ord_ticket_credential_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 16 · 规则翻译 1 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_credential_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                  AS credential_id,     -- 票凭证ID（源表主键 id）
  a.credential_no                                       AS credential_no,     -- 凭证号
  a.ticket_no                                           AS ticket_no,         -- 归属票号
  a.credential_type                                     AS credential_type,   -- 凭证类型
  a.code_value                                          AS credential_code,   -- 码值（码池分配）（脱敏）
  a.code_pool_id                                        AS code_pool_id,      -- 归属码池ID
  a.status                                              AS credential_status,  -- 状态
  a.tenant_id                                           AS tenant_id,         -- 租户ID（分库维度）
  a.create_time                                         AS create_time,       -- 创建时间
  a.update_time                                         AS update_time,       -- 更新时间
  j1.order_no                                           AS order_no,          -- 所属子单号
  j1.seller_tenant_id                                   AS seller_tenant_id,  -- 卖家租户ID
  j1.sku_id                                             AS sku_id,            -- SKU ID
  a.create_time                                         AS issue_time,        -- 发码时间
  CASE WHEN a.status = 'REVOKED' THEN a.binlog_time END AS revoke_time,       -- 撤销时间
  1                                                     AS credential_qty,    -- 凭证数
  CURRENT_TIMESTAMP()                                   AS etl_time           -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_ticket_credential_di
  WHERE travel_date = '${bizdate}'                                            -- 只取当日分区
) a                                                                           -- 主表当日增量，按主键取最新一条
LEFT JOIN dwd.dwd_ord_ticket_di j1                                            -- 关联「票明细（出票）」，取 所属子单号、卖家租户ID、SKU ID
  ON j1.ticket_no = a.ticket_no                                               -- 按 ticket_no 关联
 AND j1.travel_date = '${bizdate}'                                            -- 只取当日分区
WHERE a.rn = 1                                                                -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                           -- 剔除源库已删除的记录
