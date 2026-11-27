-- dwd.dwd_ord_verify_di  核销明细（权益级）
-- 粒度：1行=1次核销（verify_no）
-- 来源：ods_ord_verify_record_di + dwd_ord_entitlement_di + dwd_ord_ticket_di
-- 生成方式：Spark SQL / Hive；字段 28 个：直接翻译 24 · 规则翻译 4 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
verify_record_chg AS (                                                            -- 主表「核销记录」：保留每条变更记录，只取用到的列
  SELECT create_time, device_id, entitlement_no, id, offline_timestamp, operator_id, tenant_id, ticket_no,
         update_time, verify_no, verify_point_id, verify_result, verify_type
  FROM ods.ods_ord_verify_record_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
ticket_dtl AS (                                                                   -- 「票明细（出票）」当日数据，只取用到的列
  SELECT order_no, play_date, seller_tenant_id, sku_id, spu_id, ticket_no, unit_price_amt
  FROM dwd.dwd_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
entitlement_dtl AS (                                                              -- 「权益明细」当日数据，只取用到的列
  SELECT entitlement_no, entitlement_type, max_qty
  FROM dwd.dwd_ord_entitlement_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
binding_cnt AS (                                                                  -- 每张票每个权益的绑定人数  -- 「核销点维度」当日数据，只取用到的列
  SELECT ticket_no AS b_ticket_no,                                                -- 核销票号（关联子查询列）
         entitlement_no AS b_ent_no,
         MAX(IF(binding_type = 'OPEN' OR person_code = '', 1, 0)) AS b_open,
         COUNT(DISTINCT IF(person_code <> '', person_code, NULL)) AS b_person_qty  -- 游客人数（关联子查询列）
  FROM dwd.dwd_ord_entitlement_binding_di WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')
  GROUP BY ticket_no, entitlement_no                                              -- 按粒度键汇总
),
verify_point_dim AS (
  SELECT verify_point_id, verify_point_type
  FROM dim.dim_opr_verify_point_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
device_dim AS (                                                                   -- 「设备维度」当日数据，只取用到的列
  SELECT device_id, device_type
  FROM dim.dim_opr_device_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_ord_verify_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(verify_point_dim, device_dim) */
  verify_record_chg.id                                         AS verify_id,      -- 核销记录ID（源表主键 id）
  verify_record_chg.verify_no                                  AS verify_no,      -- 核销记录号
  verify_record_chg.ticket_no                                  AS ticket_no,      -- 核销票号
  verify_record_chg.entitlement_no                             AS entitlement_no,  -- 核销权益号
  verify_record_chg.verify_point_id                            AS verify_point_id,  -- 核销点ID
  verify_record_chg.operator_id                                AS operator_id,    -- 操作人ID
  verify_record_chg.device_id                                  AS device_id,      -- 核销设备ID
  verify_record_chg.verify_type                                AS verify_type,    -- 核销类型
  verify_record_chg.offline_timestamp                          AS offline_device_time,  -- 离线时序戳（离线核销时设备时间）
  verify_record_chg.verify_result                              AS verify_result_type,  -- 结果
  verify_record_chg.tenant_id                                  AS tenant_id,      -- 租户ID（分库维度）
  verify_record_chg.create_time                                AS create_time,    -- 创建时间
  verify_record_chg.update_time                                AS update_time,    -- 更新时间
  ticket_dtl.order_no                                          AS order_no,       -- 所属子单号
  ticket_dtl.seller_tenant_id                                  AS seller_tenant_id,  -- 卖家租户ID
  ticket_dtl.sku_id                                            AS sku_id,         -- SKU ID
  ticket_dtl.spu_id                                            AS spu_id,         -- 产品(SPU)ID
  ticket_dtl.play_date                                         AS play_date,      -- 游玩日期
  entitlement_dtl.entitlement_type                             AS entitlement_type,  -- 权益类型
  verify_point_dim.verify_point_type                           AS verify_point_type,  -- 核销点类型
  device_dim.device_type                                       AS device_type,    -- 设备类型
  verify_record_chg.create_time                                AS verify_time,    -- 核销时间
  HOUR(verify_record_chg.create_time)                          AS verify_hour_no,  -- 核销小时
  CASE                                                                            -- 本次核销人数｜口径：按票 + 权益的绑定人数；开放争抢模式或未绑定人记 1
      WHEN binding_cnt.b_open = 1 OR COALESCE(binding_cnt.b_person_qty, 0) = 0 THEN 1
      ELSE binding_cnt.b_person_qty
  END AS verify_person_qty,                                                       -- 本次核销人数
  1                                                            AS verify_qty,     -- 核销次数
  ticket_dtl.unit_price_amt / NULLIF(entitlement_dtl.max_qty, 0) AS verify_amt,   -- 核销金额
  CASE                                                                            -- 是否离线冲突
      WHEN verify_record_chg.verify_result='DUPLICATE' AND verify_record_chg.verify_type ='OFFLINE' THEN 1
      ELSE 0
  END AS offline_conflict_type,                                                   -- 是否离线冲突
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM verify_record_chg
LEFT JOIN ticket_dtl                                                              -- 关联「票明细（出票）」，取 所属子单号、卖家租户ID、SKU ID、产品(SPU)ID、游玩日期 等 6 个字段
  ON ticket_dtl.ticket_no = verify_record_chg.ticket_no                           -- 按 ticket_no 关联
LEFT JOIN entitlement_dtl                                                         -- 关联「权益明细」，取 权益类型、核销金额
  ON entitlement_dtl.entitlement_no = verify_record_chg.entitlement_no            -- 按 entitlement_no 关联
LEFT JOIN binding_cnt                                                             -- 关联「核销点维度」，取 核销点类型
  ON binding_cnt.b_ticket_no = verify_record_chg.ticket_no                        -- 按 ticket_no→b_ticket_no 关联
    AND binding_cnt.b_ent_no = verify_record_chg.entitlement_no
LEFT JOIN verify_point_dim
  ON verify_point_dim.verify_point_id = verify_record_chg.verify_point_id         -- 按 verify_point_id 关联
LEFT JOIN device_dim                                                              -- 关联「设备维度」，取 设备类型
  ON device_dim.device_id = verify_record_chg.device_id;                          -- 按 device_id 关联
