-- dwd.dwd_ord_ticket_di  票明细（出票）
-- 粒度：1行=1张票（ticket_no）
-- 来源：ods_ord_ticket_di + dwd_ord_order_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 21 · 规则翻译 4 · 待确认 2
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                       AS ticket_id,         -- 票ID（源表主键 id）
  a.ticket_no                                AS ticket_no,         -- 票号
  a.order_no                                 AS order_no,          -- 归属子单号
  a.ticket_status                            AS ticket_status,     -- 票状态
  a.valid_start                              AS valid_start_time,  -- 有效期起始
  a.valid_end                                AS valid_end_time,    -- 有效期终止（毫秒精度）
  a.pass_policy                              AS pass_policy_type,  -- 放行策略（从SKU继承）
  a.tenant_id                                AS tenant_id,         -- 租户ID（分库维度）
  a.create_time                              AS create_time,       -- 创建时间
  a.update_time                              AS update_time,       -- 更新时间
  j1.order_group_no                          AS order_group_no,    -- 所属聚合单号
  j1.seller_tenant_id                        AS seller_tenant_id,  -- 卖家租户ID
  j1.sku_id                                  AS sku_id,            -- SKU ID
  j1.spu_id                                  AS spu_id,            -- 产品(SPU)ID
  j1.channel_id                              AS channel_id,        -- 入口渠道ID
  j1.buyer_customer_id                       AS buyer_customer_id,  -- 买家游客ID
  j1.play_date                               AS play_date,         -- 游玩日期
  DATE_FORMAT(a.valid_end, 'yyyyMMdd')       AS valid_end_date,    -- 有效期截止日期
  GET_JSON_OBJECT(a.metadata, '$.seatInfo')  AS seat_no,           -- 座位号（演出/场馆）
  GET_JSON_OBJECT(a.metadata, '$.cabinInfo') AS cabin_no,          -- 舱位号（游船）
  GET_JSON_OBJECT(a.metadata, '$.schedule')  AS schedule_time,     -- 场次/班次时间
  j1.unit_price_amt                          AS unit_price_amt,    -- 票分摊单价（元）
  1                                          AS ticket_qty,        -- 票数
  a.valid_start                              AS delay_active_type,  -- 是否延迟激活｜待确认：ods_ord_ticket_di.valid_start 为空判定
  j2.create_time                             AS first_verify_time,  -- 首次核销时间｜待确认：dwd_ord_verify_di.create_time 按 ticket_no 取最小
  a.create_time                              AS issue_time,        -- 出票时间
  CURRENT_TIMESTAMP()                        AS etl_time           -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                 -- 只取当日分区
) a                                                                -- 主表当日增量，按主键取最新一条
LEFT JOIN dwd.dwd_ord_order_di j1                                  -- 关联「子单明细」，取 所属聚合单号、卖家租户ID、SKU ID、产品(SPU)ID、入口渠道ID 等 8 个字段
  ON j1.order_no = a.order_no                                      -- 按 order_no 关联
 AND j1.travel_date = '${bizdate}'                                 -- 只取当日分区
LEFT JOIN dwd.dwd_ord_verify_di j2                                 -- 关联「核销明细（权益级）」，取 首次核销时间
  ON j2.ticket_no = a.ticket_no                                    -- 按 ticket_no 关联
 AND j2.travel_date = '${bizdate}'                                 -- 只取当日分区
WHERE a.rn = 1                                                     -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                -- 剔除源库已删除的记录
