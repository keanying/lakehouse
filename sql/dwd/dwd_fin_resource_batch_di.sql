-- dwd.dwd_fin_resource_batch_di  资源包购买/消耗明细
-- 粒度：1行=1个资源批次的1日状态
-- 来源：ods_fin_resource_batch_df（相邻日快照求差）
-- 生成方式：Spark SQL / Hive；字段 16 个：直接翻译 14 · 规则翻译 2 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
resource_batch_chg AS (                                                           -- 主表「资源批次（短信/积分）」：保留每条变更记录，只取用到的列
  SELECT batch_no, batch_status, create_time, expire_at, id, purchase_no, remaining_quantity,
         resource_type, tenant_id, total_quantity, unit, update_time
  FROM ods.ods_fin_resource_batch_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
batch_prev AS (                                                                   -- 昨日批次快照的剩余量  -- 「套餐订购明细」当日数据，只取用到的列
  SELECT id AS prev_id,                                                           -- 上一条记录ID
         remaining_quantity AS prev_remaining FROM ods.ods_fin_resource_batch_df
             WHERE travel_date = DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 1), 'yyyyMMdd')
),
purchase_flow AS (                                                                -- 购买流水 → 订购单号（流水 related_no）
  SELECT flow_no,
         MAX(related_no) AS related_no FROM dwd.dwd_fin_fund_flow_di
             WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')
               AND flow_type = 'RESOURCE' GROUP BY flow_no
),
package_subscription_dtl AS (
  SELECT subscription_no, MAX(package_id) AS package_id                           -- 来源套餐ID
  FROM dwd.dwd_opr_package_subscription_di
  WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')  -- 只取当日分区
    GROUP BY subscription_no                                                      -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dwd.dwd_fin_resource_batch_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  resource_batch_chg.id                 AS resource_batch_id,                     -- 资源批次
  resource_batch_chg.batch_no           AS batch_no,                              -- 批次号
  resource_batch_chg.tenant_id          AS tenant_id,                             -- 归属商户ID
  resource_batch_chg.resource_type      AS resource_type,                         -- 资源类型
  resource_batch_chg.total_quantity     AS total_qty,                             -- 总量（短信条数/积分点数/预警额度）
  resource_batch_chg.remaining_quantity AS remaining_qty,                         -- 剩余量
  resource_batch_chg.unit               AS unit_type,                             -- 单位
  resource_batch_chg.expire_at          AS expire_time,                           -- 过期时间
  resource_batch_chg.batch_status       AS batch_status,                          -- 状态
  resource_batch_chg.purchase_no        AS purchase_no,                           -- 购买流水号（引用资金流水）
  resource_batch_chg.create_time        AS create_time,                           -- 创建时间
  resource_batch_chg.update_time        AS update_time,                           -- 更新时间
  package_subscription_dtl.package_id   AS package_id,                            -- 来源套餐ID
  GREATEST(COALESCE(batch_prev.prev_remaining, resource_batch_chg.total_quantity) - resource_batch_chg.remaining_quantity, 0) AS consume_qty,  -- 当日消耗量 = 昨日剩余量 - 今日剩余量｜口径：昨日剩余 − 今日剩余；今日新建批次按 总量 − 剩余；不含新购
  CURRENT_TIMESTAMP()                   AS etl_time                               -- ETL 加载时间
FROM resource_batch_chg
LEFT JOIN purchase_flow ON purchase_flow.flow_no = resource_batch_chg.purchase_no  -- 关联「套餐订购明细」，取 来源套餐ID
LEFT JOIN batch_prev ON batch_prev.prev_id = resource_batch_chg.id
LEFT JOIN package_subscription_dtl
  ON package_subscription_dtl.subscription_no = purchase_flow.related_no          -- 按 related_no→subscription_no 关联｜口径说明：资源包购买流水的关联单号 = 订购单号;
