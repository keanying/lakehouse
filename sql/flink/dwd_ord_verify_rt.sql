-- dwd.dwd_ord_verify_rt  实时核销明细
-- 粒度：1行=1次核销（verify_no）
-- 来源：ods_ord_verify_record_rt + ods_ord_entitlement_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 29 个：直接翻译 24 · 规则翻译 4 · 待确认 1
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT INTO dwd.dwd_ord_verify_rt                                                 -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                       AS travel_date,    -- 数据日期
  a.id                                                         AS verify_id,      -- 核销记录ID（源表主键 id）
  a.verify_no                                                  AS verify_no,      -- 核销记录号
  a.ticket_no                                                  AS ticket_no,      -- 核销票号
  a.entitlement_no                                             AS entitlement_no,  -- 核销权益号
  a.verify_point_id                                            AS verify_point_id,  -- 核销点ID
  a.operator_id                                                AS operator_id,    -- 操作人ID
  a.device_id                                                  AS device_id,      -- 核销设备ID
  a.verify_type                                                AS verify_type,    -- 核销类型
  a.offline_timestamp                                          AS offline_device_time,  -- 离线时序戳（离线核销时设备时间）
  a.verify_result                                              AS verify_result_type,  -- 结果
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间（在线=服务器时间
  a.update_time                                                AS update_time,    -- 更新时间
  j1.order_no                                                  AS order_no,       -- 所属子单号
  j1.seller_tenant_id                                          AS seller_tenant_id,  -- 卖家租户ID
  j1.sku_id                                                    AS sku_id,         -- SKU ID
  j1.spu_id                                                    AS spu_id,         -- 产品(SPU)ID
  j1.play_date                                                 AS play_date,      -- 游玩日期
  j2.entitlement_type                                          AS entitlement_type,  -- 权益类型
  j3.verify_point_type                                         AS verify_point_type,  -- 核销点类型
  j4.device_type                                               AS device_type,    -- 设备类型
  a.create_time                                                AS verify_time,    -- 核销时间
  HOUR(a.create_time)                                          AS verify_hour_no,  -- 核销小时
  NULL                                                         AS verify_person_qty,  -- 本次核销人数｜待确认：dwd_ord_entitlement_binding_di 按 ticket_no+entitlement_no 计人数，开放模式记 1
  1                                                            AS verify_qty,     -- 核销次数
  j1.unit_price_amt / NULLIF(j2.max_qty, 0)                    AS verify_amt,     -- 核销金额（元
  CASE WHEN a.verify_result='DUPLICATE' AND a.verify_type ='OFFLINE' THEN 1 ELSE 0 END AS offline_conflict_type,  -- 是否离线冲突
  CURRENT_TIMESTAMP                                            AS event_time      -- 事件时间（binlog 时间）
FROM ods.ods_ord_verify_record_rt a                                               -- 主表「核销记录 binlog 流」
LEFT JOIN dwd.dwd_ord_ticket_di j1                                                -- 关联「票明细（出票）」，取 所属子单号、卖家租户ID、SKU ID、产品(SPU)ID、游玩日期 等 6 个字段
  ON j1.ticket_no = a.ticket_no                                                   -- 按 ticket_no 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
LEFT JOIN dwd.dwd_ord_entitlement_di j2                                           -- 关联「权益明细」，取 权益类型、核销金额（元
  ON j2.entitlement_no = a.entitlement_no                                         -- 按 entitlement_no 关联
 AND j2.travel_date = '${bizdate}'                                                -- 只取当日分区
LEFT JOIN dim.dim_opr_verify_point_df FOR SYSTEM_TIME AS OF a.proc_time AS j3     -- 关联「核销点维度」，取 核销点类型
  ON j3.verify_point_id = a.verify_point_id                                       -- 按 verify_point_id 关联
LEFT JOIN dim.dim_opr_device_df FOR SYSTEM_TIME AS OF a.proc_time AS j4           -- 关联「设备维度」，取 设备类型
  ON j4.device_id = a.device_id;                                                  -- 按 device_id 关联
