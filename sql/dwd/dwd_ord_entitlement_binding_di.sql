-- dwd.dwd_ord_entitlement_binding_di  人-权益绑定明细
-- 粒度：1行=1条绑定（ticket_no+person_id+entitlement_no）
-- 来源：ods_ord_person_entitlement_binding_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
person_entitlement_binding_rn AS (                                       -- 「人-权益绑定」当日增量，同一主键按 binlog 时间倒序编号
  SELECT binding_type, create_time, entitlement_no, id, person_id, tenant_id, ticket_no, update_time,
         binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 去重序号（1 = 最新）
  FROM ods.ods_ord_person_entitlement_binding_di
  WHERE travel_date = '${bizdate}'                                       -- 只取当日分区
),
person_entitlement_binding_latest AS (                                   -- 「人-权益绑定」每个主键只保留最新一条，剔除已删除记录
  SELECT binding_type, create_time, entitlement_no, id, person_id, tenant_id, ticket_no, update_time
  FROM person_entitlement_binding_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                       -- 剔除源库已删除的记录
),
ticket_dtl AS (                                                          -- 「票明细（出票）」当日数据，只取用到的列
  SELECT seller_tenant_id, sku_id, ticket_no
  FROM dwd.dwd_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                       -- 只取当日分区
),
entitlement_dtl AS (                                                     -- 「权益明细」当日数据，只取用到的列
  SELECT entitlement_no, entitlement_type
  FROM dwd.dwd_ord_entitlement_di
  WHERE travel_date = '${bizdate}'                                       -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_ord_entitlement_binding_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  person_entitlement_binding_latest.id             AS binding_id,        -- 人-权益绑定ID（源表主键 id）
  person_entitlement_binding_latest.ticket_no      AS ticket_no,         -- 归属票号
  person_entitlement_binding_latest.person_id      AS person_code,       -- 人ID
  person_entitlement_binding_latest.entitlement_no AS entitlement_no,    -- 权益号
  person_entitlement_binding_latest.binding_type   AS binding_type,      -- 绑定类型
  person_entitlement_binding_latest.tenant_id      AS tenant_id,         -- 租户ID（分库维度）
  person_entitlement_binding_latest.create_time    AS create_time,       -- 创建时间
  person_entitlement_binding_latest.update_time    AS update_time,       -- 更新时间
  ticket_dtl.seller_tenant_id                      AS seller_tenant_id,  -- 卖家租户ID
  ticket_dtl.sku_id                                AS sku_id,            -- SKU ID
  entitlement_dtl.entitlement_type                 AS entitlement_type,  -- 权益类型
  person_entitlement_binding_latest.create_time    AS bind_time,         -- 绑定时间
  CURRENT_TIMESTAMP()                              AS etl_time           -- ETL 加载时间
FROM person_entitlement_binding_latest
LEFT JOIN ticket_dtl                                                     -- 关联「票明细（出票）」，取 卖家租户ID、SKU ID
  ON ticket_dtl.ticket_no = person_entitlement_binding_latest.ticket_no  -- 按 ticket_no 关联
LEFT JOIN entitlement_dtl                                                -- 关联「权益明细」，取 权益类型
  ON entitlement_dtl.entitlement_no = person_entitlement_binding_latest.entitlement_no;  -- 按 entitlement_no 关联
