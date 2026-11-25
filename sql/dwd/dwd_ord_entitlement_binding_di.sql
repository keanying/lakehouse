-- dwd.dwd_ord_entitlement_binding_di  人-权益绑定明细
-- 粒度：1行=1条绑定（ticket_no+person_id+entitlement_no）
-- 来源：ods_ord_person_entitlement_binding_di
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 13 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_ord_entitlement_binding_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS binding_id,        -- 人-权益绑定ID（源表主键 id）
  a.ticket_no         AS ticket_no,         -- 归属票号
  a.person_id         AS person_code,       -- 人ID（空串=开放争抢
  a.entitlement_no    AS entitlement_no,    -- 权益号
  a.binding_type      AS binding_type,      -- 绑定类型
  a.tenant_id         AS tenant_id,         -- 租户ID（分库维度）
  a.create_time       AS create_time,       -- 创建时间
  a.update_time       AS update_time,       -- 更新时间
  j1.seller_tenant_id AS seller_tenant_id,  -- 卖家租户ID
  j1.sku_id           AS sku_id,            -- SKU ID
  j2.entitlement_type AS entitlement_type,  -- 权益类型
  a.create_time       AS bind_time,         -- 绑定时间
  CURRENT_TIMESTAMP() AS etl_time           -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_person_entitlement_binding_di
  WHERE travel_date = '${bizdate}'          -- 只取当日分区
) a                                         -- 主表当日增量，按主键取最新一条
LEFT JOIN dwd.dwd_ord_ticket_di j1          -- 关联「票明细（出票）」，取 卖家租户ID、SKU ID
  ON j1.ticket_no = a.ticket_no             -- 按 ticket_no 关联
 AND j1.travel_date = '${bizdate}'          -- 只取当日分区
LEFT JOIN dwd.dwd_ord_entitlement_di j2     -- 关联「权益明细」，取 权益类型
  ON j2.entitlement_no = a.entitlement_no   -- 按 entitlement_no 关联
 AND j2.travel_date = '${bizdate}'          -- 只取当日分区
WHERE a.rn = 1                              -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';         -- 剔除源库已删除的记录
