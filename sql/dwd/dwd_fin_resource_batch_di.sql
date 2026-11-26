-- dwd.dwd_fin_resource_batch_di  资源包购买/消耗明细
-- 粒度：1行=1个资源批次的1日状态
-- 来源：ods_fin_resource_batch_df（相邻日快照求差）
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 14 · 规则翻译 0 · 待确认 2
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
resource_batch_chg AS (                                               -- 主表「资源批次（短信/积分）」：保留每条变更记录，只取用到的列
  SELECT batch_no, batch_status, create_time, expire_at, id, purchase_no, remaining_quantity,
         resource_type, tenant_id, total_quantity, unit, update_time
  FROM ods.ods_fin_resource_batch_df
  WHERE travel_date = '${bizdate}'                                    -- 只取当日分区
),
package_subscription_dtl AS (                                         -- 「套餐订购明细」当日数据，只取用到的列
  SELECT package_id, subscription_id
  FROM dwd.dwd_opr_package_subscription_di
  WHERE travel_date = '${bizdate}'                                    -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_fin_resource_batch_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  resource_batch_chg.id                            AS resource_batch_id,  -- 资源批次
  resource_batch_chg.batch_no                      AS batch_no,       -- 批次号
  resource_batch_chg.tenant_id                     AS tenant_id,      -- 归属商户ID
  ROUND(resource_batch_chg.resource_type / 100, 2) AS resource_type,  -- 资源类型
  resource_batch_chg.total_quantity                AS total_qty,      -- 总量（短信条数/积分点数/预警额度）
  resource_batch_chg.remaining_quantity            AS remaining_qty,  -- 剩余量
  resource_batch_chg.unit                          AS unit_type,      -- 单位
  resource_batch_chg.expire_at                     AS expire_time,    -- 过期时间
  resource_batch_chg.batch_status                  AS batch_status,   -- 状态
  resource_batch_chg.purchase_no                   AS purchase_no,    -- 购买流水号（引用资金流水）
  resource_batch_chg.create_time                   AS create_time,    -- 创建时间
  resource_batch_chg.update_time                   AS update_time,    -- 更新时间
  package_subscription_dtl.package_id              AS package_id,     -- 来源套餐ID
  resource_batch_chg.remaining_quantity            AS consume_qty,    -- 当日消耗量 = 昨日剩余量 - 今日剩余量｜待确认：ods_fin_resource_batch_df.remaining_quantity 日差
  CURRENT_TIMESTAMP()                              AS etl_time        -- ETL 加载时间
FROM resource_batch_chg
LEFT JOIN package_subscription_dtl                                    -- 关联「套餐订购明细」，取 来源套餐ID
  ON package_subscription_dtl.subscription_id = resource_batch_chg.id;  -- 按 id→subscription_id 关联｜待确认：关联键
