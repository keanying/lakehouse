-- dwd.dwd_ord_entitlement_di  权益明细
-- 粒度：1行=1个权益（entitlement_no）
-- 来源：ods_ord_entitlement_di + dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 23 个：直接翻译 17 · 规则翻译 6 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
entitlement_rn AS (                                                               -- 「权益」当日增量，同一主键按 binlog 时间倒序编号
  SELECT create_time, entitlement_detail, entitlement_name, entitlement_no, entitlement_type, id, status,
         tenant_id, ticket_no, update_time, used_count, valid_end, valid_start, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_entitlement_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
entitlement_latest AS (                                                           -- 「权益」每个主键只保留最新一条，剔除已删除记录
  SELECT create_time, entitlement_detail, entitlement_name, entitlement_no, entitlement_type, id, status,
         tenant_id, ticket_no, update_time, used_count, valid_end, valid_start
  FROM entitlement_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
ticket_dtl AS (                                                                   -- 「票明细（出票）」当日数据，只取用到的列
  SELECT order_no, seller_tenant_id, sku_id, ticket_no
  FROM dwd.dwd_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_ord_entitlement_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  entitlement_latest.id                                        AS entitlement_id,  -- 权益ID（源表主键 id）
  entitlement_latest.entitlement_no                            AS entitlement_no,  -- 权益号
  entitlement_latest.ticket_no                                 AS ticket_no,      -- 归属票号
  entitlement_latest.entitlement_type                          AS entitlement_type,  -- 权益类型
  entitlement_latest.entitlement_name                          AS entitlement_name,  -- 权益名称（如"成人入园""住宿1晚"）
  entitlement_latest.status                                    AS entitlement_status,  -- 权益状态
  entitlement_latest.used_count                                AS used_qty,       -- 已用次数（所有类型共有）
  entitlement_latest.valid_start                               AS valid_start_time,  -- 权益有效期起始（可收窄于票有效期
  entitlement_latest.valid_end                                 AS valid_end_time,  -- 权益有效期终止（毫秒精度）
  entitlement_latest.tenant_id                                 AS tenant_id,      -- 租户ID（分库维度）
  entitlement_latest.create_time                               AS create_time,    -- 创建时间
  entitlement_latest.update_time                               AS update_time,    -- 更新时间
  ticket_dtl.order_no                                          AS order_no,       -- 所属子单号
  ticket_dtl.seller_tenant_id                                  AS seller_tenant_id,  -- 卖家租户ID
  ticket_dtl.sku_id                                            AS sku_id,         -- SKU ID
  GET_JSON_OBJECT(entitlement_latest.entitlement_detail, '$.projectId') AS project_id,  -- 权益对应项目ID
  GET_JSON_OBJECT(entitlement_latest.entitlement_detail, '$.maxCount') AS max_qty,  -- 最大可用次数（COUNTED-计次型
  JSON_ARRAY_LENGTH(GET_JSON_OBJECT(entitlement_latest.entitlement_detail, '$.candidateRefs')) AS candidate_qty,  -- 可选项目数
  GET_JSON_OBJECT(entitlement_latest.entitlement_detail, '$.durationMinutes') AS duration_minute_qty,  -- 可用时长（分钟
  GET_JSON_OBJECT(entitlement_latest.entitlement_detail, '$.quotaAmount') AS quota_amt,  -- 额度（元
  (GET_JSON_OBJECT(entitlement_latest.entitlement_detail, '$.maxCount')) - (entitlement_latest.used_count) AS remain_qty,  -- 剩余可用次数 = 最大可用次数 - 已使用次数
  entitlement_latest.create_time                               AS issue_time,     -- 发放时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM entitlement_latest
LEFT JOIN ticket_dtl                                                              -- 关联「票明细（出票）」，取 所属子单号、卖家租户ID、SKU ID
  ON ticket_dtl.ticket_no = entitlement_latest.ticket_no;                         -- 按 ticket_no 关联
