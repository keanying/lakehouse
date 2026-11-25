-- dwd.dwd_fin_resource_batch_di  资源包购买/消耗明细
-- 粒度：1行=1个资源批次的1日状态
-- 来源：ods_fin_resource_batch_df（相邻日快照求差）
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 14 · 规则翻译 0 · 待确认 1
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_fin_resource_batch_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                            AS resource_batch_id,  -- 资源批次
  a.batch_no                      AS batch_no,       -- 批次号
  a.tenant_id                     AS tenant_id,      -- 归属商户ID
  ROUND(a.resource_type / 100, 2) AS resource_type,  -- 资源类型
  a.total_quantity                AS total_qty,      -- 总量（短信条数/积分点数/预警额度）
  a.remaining_quantity            AS remaining_qty,  -- 剩余量
  a.unit                          AS unit_type,      -- 单位
  a.expire_at                     AS expire_time,    -- 过期时间
  a.batch_status                  AS batch_status,   -- 状态
  a.purchase_no                   AS purchase_no,    -- 购买流水号（引用资金流水）
  a.create_time                   AS create_time,    -- 创建时间
  a.update_time                   AS update_time,    -- 更新时间
  j1.package_id                   AS package_id,     -- 来源套餐ID
  a.remaining_quantity            AS consume_qty,    -- 当日消耗量 = 昨日剩余量 - 今日剩余量｜待确认：ods_fin_resource_batch_df.remaining_quantity 日差
  CURRENT_TIMESTAMP()             AS etl_time        -- ETL 加载时间
FROM ods.ods_fin_resource_batch_df a                 -- 主表「资源批次（短信/积分）」
LEFT JOIN dwd.dwd_opr_package_subscription_di j1     -- 关联「套餐订购明细」，取 来源套餐ID
  ON j1.tenant_id = a.tenant_id                      -- 按 tenant_id 关联
 AND j1.travel_date = '${bizdate}'                   -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                  -- 只取当日分区
