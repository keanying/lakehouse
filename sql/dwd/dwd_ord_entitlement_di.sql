-- dwd.dwd_ord_entitlement_di  权益明细
-- 粒度：1行=1个权益（entitlement_no）
-- 来源：ods_ord_entitlement_di + dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 23 个：直接翻译 17 · 规则翻译 6 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_ord_entitlement_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                         AS entitlement_id,  -- 权益ID（源表主键 id）
  a.entitlement_no                                             AS entitlement_no,  -- 权益号
  a.ticket_no                                                  AS ticket_no,      -- 归属票号
  a.entitlement_type                                           AS entitlement_type,  -- 权益类型
  a.entitlement_name                                           AS entitlement_name,  -- 权益名称（如"成人入园""住宿1晚"）
  a.status                                                     AS entitlement_status,  -- 权益状态
  a.used_count                                                 AS used_qty,       -- 已用次数（所有类型共有）
  a.valid_start                                                AS valid_start_time,  -- 权益有效期起始（可收窄于票有效期
  a.valid_end                                                  AS valid_end_time,  -- 权益有效期终止（毫秒精度）
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  j1.order_no                                                  AS order_no,       -- 所属子单号
  j1.seller_tenant_id                                          AS seller_tenant_id,  -- 卖家租户ID
  j1.sku_id                                                    AS sku_id,         -- SKU ID
  GET_JSON_OBJECT(a.entitlement_detail, '$.projectId')         AS project_id,     -- 权益对应项目ID
  GET_JSON_OBJECT(a.entitlement_detail, '$.maxCount')          AS max_qty,        -- 最大可用次数（COUNTED-计次型
  JSON_ARRAY_LENGTH(GET_JSON_OBJECT(a.entitlement_detail, '$.candidateRefs')) AS candidate_qty,  -- 可选项目数
  GET_JSON_OBJECT(a.entitlement_detail, '$.durationMinutes')   AS duration_minute_qty,  -- 可用时长（分钟
  GET_JSON_OBJECT(a.entitlement_detail, '$.quotaAmount')       AS quota_amt,      -- 额度（元
  (GET_JSON_OBJECT(a.entitlement_detail, '$.maxCount')) - (a.used_count) AS remain_qty,  -- 剩余可用次数 = 最大可用次数 - 已使用次数
  a.create_time                                                AS issue_time,     -- 发放时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_entitlement_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
) a                                                                               -- 主表当日增量，按主键取最新一条
LEFT JOIN dwd.dwd_ord_ticket_di j1                                                -- 关联「票明细（出票）」，取 所属子单号、卖家租户ID、SKU ID
  ON j1.ticket_no = a.ticket_no                                                   -- 按 ticket_no 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
WHERE a.rn = 1                                                                    -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                               -- 剔除源库已删除的记录
