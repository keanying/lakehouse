-- dwd.dwd_ord_order_di  子单明细
-- 粒度：1行=1个子单（order_no）
-- 来源：ods_ord_order_di + ods_ord_order_group_di
-- 生成方式：Spark SQL / Hive；字段 36 个：直接翻译 28 · 规则翻译 8 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
order_rn AS (                                                                     -- 「子单」当日增量，同一主键按 binlog 时间倒序编号
  SELECT binlog_time, combo_flag, create_time, id, order_group_no, order_no, order_status,
         parent_order_no, quantity, sale_dims, seller_tenant_id, sku_id, sku_name, sku_version, tenant_id,
         unit_price, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_order_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
order_latest AS (                                                                 -- 「子单」每个主键只保留最新一条，剔除已删除记录
  SELECT binlog_time, combo_flag, create_time, id, order_group_no, order_no, order_status,
         parent_order_no, quantity, sale_dims, seller_tenant_id, sku_id, sku_name, sku_version, tenant_id,
         unit_price, update_time
  FROM order_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
order_group_rn AS (                                                               -- 「聚合单」当日增量，同一主键按 binlog 时间倒序编号
  SELECT app_id, app_ref, buyer_customer_id, buyer_type, channel_id, currency, id, operator_id,
         operator_type, order_group_no, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_order_group_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
order_group_latest AS (                                                           -- 「聚合单」每个主键只保留最新一条，剔除已删除记录
  SELECT app_id, app_ref, buyer_customer_id, buyer_type, channel_id, currency, id, operator_id,
         operator_type, order_group_no
  FROM order_group_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
channel_dim AS (                                                                  -- 「渠道/接入端维度」当日数据，只取用到的列
  SELECT channel_id, channel_type
  FROM dim.dim_trf_channel_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
sku_cur AS (                                                                      -- 「SKU维度」当前有效版本，只取用到的列
  SELECT product_type, sku_id, spu_id
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'                    -- 取当日分区里的拉链当前有效版本
),
sku_hist AS (                                                                     -- 「SKU维度」拉链全部版本（按时间点取历史版本）
  SELECT cost_price_amt, end_date, sku_id, start_date
  FROM dim.dim_prd_sku_zip
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_ord_order_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(channel_dim) */
  order_latest.id                                              AS order_id,       -- 子单ID（源表主键 id）
  order_latest.order_no                                        AS order_no,       -- 子单号
  order_latest.order_group_no                                  AS order_group_no,  -- 归属聚合单号
  order_latest.parent_order_no                                 AS parent_order_no,  -- 套票子单指向主单号
  order_latest.combo_flag                                      AS combo_type,     -- 是否套票主单
  order_latest.seller_tenant_id                                AS seller_tenant_id,  -- 卖家商户ID
  order_latest.sku_id                                          AS sku_id,         -- SKU ID
  order_latest.sku_name                                        AS sku_name,       -- SKU名称（下单时快照）
  order_latest.sku_version                                     AS sku_version_no,  -- 下单时SKU版本号
  order_latest.quantity                                        AS buy_ticket_qty,  -- 购买数量
  ROUND(order_latest.unit_price / 100, 2)                      AS unit_price_amt,  -- 单价（元）
  order_latest.order_status                                    AS order_status,   -- 状态
  order_latest.tenant_id                                       AS tenant_id,      -- 租户ID（分库维度）
  order_latest.create_time                                     AS create_time,    -- 创建时间
  order_latest.update_time                                     AS update_time,    -- 更新时间
  order_group_latest.channel_id                                AS channel_id,     -- 入口渠道ID
  channel_dim.channel_type                                     AS channel_type,   -- 入口渠道类型
  order_group_latest.app_id                                    AS app_code,       -- 对接端标识
  order_group_latest.app_ref                                   AS app_ref_code,   -- 对接端引用
  order_group_latest.operator_type                             AS operator_type,  -- 操作人类型
  order_group_latest.operator_id                               AS operator_id,    -- 操作人ID（游客或员工）
  order_group_latest.buyer_type                                AS buyer_type,     -- 付款方类型
  order_group_latest.buyer_customer_id                         AS buyer_customer_id,  -- 买家游客ID
  order_group_latest.currency                                  AS currency_code,  -- 币种编码
  sku_cur.spu_id                                               AS spu_id,         -- 产品(SPU)ID
  sku_cur.product_type                                         AS product_type,   -- 产品业态
  GET_JSON_OBJECT(order_latest.sale_dims, '$.date')            AS play_date,      -- 游玩日期
  GET_JSON_OBJECT(order_latest.sale_dims, '$.timeSlot')        AS time_slot_code,  -- 游玩时段
  GET_JSON_OBJECT(order_latest.sale_dims, '$.seatZone')        AS seat_zone_code,  -- 座位区域
  ROUND(order_latest.unit_price * order_latest.quantity /100, 2) AS order_amt,    -- 子单金额（元）= 单价 × 购买数量
  sku_hist.cost_price_amt                                      AS cost_price_amt,  -- 下单时 SKU 成本价（元）
  DATE_FORMAT(order_latest.create_time, 'yyyyMMdd')            AS order_date,     -- 下单日期
  CASE WHEN order_latest.order_status = 'PAID' THEN order_latest.binlog_time END AS pay_time,  -- 支付成功时间
  CASE WHEN order_latest.order_status = 'CANCELLED' THEN order_latest.binlog_time END AS cancel_time,  -- 取消时间
  DATEDIFF(TO_DATE(GET_JSON_OBJECT(order_latest.sale_dims, '$.date'), 'yyyyMMdd'), TO_DATE(DATE_FORMAT(order_latest.create_time, 'yyyyMMdd'), 'yyyyMMdd')) AS advance_book_day_qty,  -- 提前预订天数 = 游玩日期 - 下单日期
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM order_latest
LEFT JOIN order_group_latest                                                      -- 关联「聚合单」，取 入口渠道ID、对接端标识、对接端引用、操作人类型、操作人ID（游客或员工） 等 8 个字段
  ON order_group_latest.order_group_no = order_latest.order_group_no              -- 按 order_group_no 关联
LEFT JOIN channel_dim                                                             -- 关联「渠道/接入端维度」，取 入口渠道类型
  ON channel_dim.channel_id = order_group_latest.channel_id                       -- 按 channel_id 关联
LEFT JOIN sku_cur                                                                 -- 关联「SKU维度」，取 产品(SPU)ID、产品业态
  ON sku_cur.sku_id = order_latest.sku_id                                         -- 按 sku_id 关联
LEFT JOIN sku_hist                                                                -- 关联「SKU维度」，取 下单时 SKU 成本价（元）
  ON sku_hist.sku_id = order_latest.sku_id                                        -- 按 sku_id 关联
 AND TO_DATE(order_latest.create_time) BETWEEN sku_hist.start_date AND sku_hist.end_date;  -- 按下单时间取当时有效的版本
