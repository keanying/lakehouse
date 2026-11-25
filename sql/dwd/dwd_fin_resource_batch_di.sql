-- dwd.dwd_fin_resource_batch_di  资源包购买/消耗明细
-- 粒度：1行=1个资源批次的1日状态
-- 来源：ods_fin_resource_batch_df（相邻日快照求差）
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 14 · 规则翻译 0 · 待确认 1
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_fin_resource_batch_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                            AS resource_batch_id,
  a.batch_no                      AS batch_no,
  a.tenant_id                     AS tenant_id,
  ROUND(a.resource_type / 100, 2) AS resource_type,
  a.total_quantity                AS total_qty,
  a.remaining_quantity            AS remaining_qty,
  a.unit                          AS unit_type,
  a.expire_at                     AS expire_time,
  a.batch_status                  AS batch_status,
  a.purchase_no                   AS purchase_no,
  a.create_time                   AS create_time,
  a.update_time                   AS update_time,
  j1.package_id                   AS package_id,
  a.remaining_quantity            AS consume_qty,  -- 待确认：ods_fin_resource_batch_df.remaining_quantity 日差
  CURRENT_TIMESTAMP()             AS etl_time
FROM ods.ods_fin_resource_batch_df a
LEFT JOIN dwd.dwd_opr_package_subscription_di j1
  ON j1.tenant_id = a.tenant_id
 AND j1.travel_date = '${bizdate}'
WHERE a.travel_date = '${bizdate}';
