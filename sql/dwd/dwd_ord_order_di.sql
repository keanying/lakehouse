-- dwd.dwd_ord_order_di  子单明细
-- 粒度：1行=1个子单（order_no）
-- 来源：ods_ord_order_di + ods_ord_order_group_di
-- 生成方式：Spark SQL / Hive；字段 36 个：直接翻译 28 · 规则翻译 8 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_ord_order_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                         AS order_id,       -- 子单ID（源表主键 id）
  a.order_no                                                   AS order_no,       -- 子单号
  a.order_group_no                                             AS order_group_no,  -- 归属聚合单号
  a.parent_order_no                                            AS parent_order_no,  -- 套票子单指向主单号
  a.combo_flag                                                 AS combo_type,     -- 是否套票主单
  a.seller_tenant_id                                           AS seller_tenant_id,  -- 卖家商户ID
  a.sku_id                                                     AS sku_id,         -- SKU ID
  a.sku_name                                                   AS sku_name,       -- SKU名称（下单时快照）
  a.sku_version                                                AS sku_version_no,  -- 下单时SKU版本号
  a.quantity                                                   AS buy_ticket_qty,  -- 购买数量
  ROUND(a.unit_price / 100, 2)                                 AS unit_price_amt,  -- 单价（元）
  a.order_status                                               AS order_status,   -- 状态
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  j1.channel_id                                                AS channel_id,     -- 入口渠道ID
  j2.channel_type                                              AS channel_type,   -- 入口渠道类型
  j1.app_id                                                    AS app_code,       -- 对接端标识
  j1.app_ref                                                   AS app_ref_code,   -- 对接端引用
  j1.operator_type                                             AS operator_type,  -- 操作人类型
  j1.operator_id                                               AS operator_id,    -- 操作人ID（游客或员工）
  j1.buyer_type                                                AS buyer_type,     -- 付款方类型
  j1.buyer_customer_id                                         AS buyer_customer_id,  -- 买家游客ID
  j1.currency                                                  AS currency_code,  -- 币种编码
  j3.spu_id                                                    AS spu_id,         -- 产品(SPU)ID
  j3.product_type                                              AS product_type,   -- 产品业态
  GET_JSON_OBJECT(a.sale_dims, '$.date')                       AS play_date,      -- 游玩日期
  GET_JSON_OBJECT(a.sale_dims, '$.timeSlot')                   AS time_slot_code,  -- 游玩时段
  GET_JSON_OBJECT(a.sale_dims, '$.seatZone')                   AS seat_zone_code,  -- 座位区域
  ROUND(a.unit_price * a.quantity /100, 2)                     AS order_amt,      -- 子单金额（元）= 单价 × 购买数量
  j4.cost_price_amt                                            AS cost_price_amt,  -- 下单时 SKU 成本价（元）
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                       AS order_date,     -- 下单日期
  CASE WHEN a.order_status = 'PAID' THEN a.binlog_time END     AS pay_time,       -- 支付成功时间
  CASE WHEN a.order_status = 'CANCELLED' THEN a.binlog_time END AS cancel_time,   -- 取消时间
  DATEDIFF(TO_DATE(GET_JSON_OBJECT(a.sale_dims, '$.date'), 'yyyyMMdd'), TO_DATE(DATE_FORMAT(a.create_time, 'yyyyMMdd'), 'yyyyMMdd')) AS advance_book_day_qty,  -- 提前预订天数 = 游玩日期 - 下单日期
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_order_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
) a                                                                               -- 主表当日增量，按主键取最新一条
LEFT JOIN ods.ods_ord_order_group_di j1                                           -- 关联「聚合单」，取 入口渠道ID、对接端标识、对接端引用、操作人类型、操作人ID（游客或员工） 等 8 个字段
  ON j1.order_group_no = a.order_group_no                                         -- 按 order_group_no 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
LEFT JOIN dim.dim_trf_channel_df j2                                               -- 关联「渠道/接入端维度」，取 入口渠道类型
  ON j2.channel_id = j1.channel_id                                                -- 按 channel_id 关联
 AND j2.travel_date = '${bizdate}'                                                -- 只取当日分区
LEFT JOIN dim.dim_prd_sku_zip j3                                                  -- 关联「SKU维度」，取 产品(SPU)ID、产品业态
  ON j3.sku_id = a.sku_id                                                         -- 按 sku_id 关联
 AND j3.travel_date = '${bizdate}' AND j3.end_date = '9999-12-31'                 -- 取当日分区里的拉链当前有效版本
LEFT JOIN dim.dim_prd_sku_zip j4                                                  -- 关联「SKU维度」，取 下单时 SKU 成本价（元）
  ON j4.sku_id = a.sku_id                                                         -- 按 sku_id 关联
 AND j4.travel_date = '${bizdate}'                                                -- 只取当日分区
 AND TO_DATE(a.create_time) BETWEEN j4.start_date AND j4.end_date                 -- 按时间点取拉链历史版本
WHERE a.rn = 1                                                                    -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                               -- 剔除源库已删除的记录
