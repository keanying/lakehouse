-- dwd.dwd_ord_ticket_di  票明细（出票）
-- 粒度：1行=1张票（ticket_no）
-- 来源：ods_ord_ticket_di + dwd_ord_order_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 21 · 规则翻译 6 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
ticket_rn AS (                                                                 -- 「票」当日增量，同一主键按 binlog 时间倒序编号
  SELECT create_time, id, metadata, order_no, pass_policy, tenant_id, ticket_no, ticket_status,
         update_time, valid_end, valid_start, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                             -- 只取当日分区
),
ticket_latest AS (                                                             -- 「票」每个主键只保留最新一条，剔除已删除记录
  SELECT create_time, id, metadata, order_no, pass_policy, tenant_id, ticket_no, ticket_status,
         update_time, valid_end, valid_start
  FROM ticket_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                             -- 剔除源库已删除的记录
),
order_dtl AS (                                                                 -- 「子单明细」当日数据，只取用到的列
  SELECT buyer_customer_id, channel_id, order_group_no, order_no, play_date, seller_tenant_id, sku_id,
      spu_id, unit_price_amt
  FROM dwd.dwd_ord_order_di
  WHERE travel_date = '${bizdate}'                                             -- 只取当日分区
),
verify_dtl AS (                                                                -- 「核销明细（权益级）」当日数据，只取用到的列
  SELECT ticket_no, MIN(create_time) AS first_verify_time
  FROM dwd.dwd_ord_verify_di
  WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd') AND verify_result_type = 'SUCCESS'  -- 只取当日分区
    GROUP BY ticket_no
)
INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  ticket_latest.id                                       AS ticket_id,         -- 票ID（源表主键 id）
  ticket_latest.ticket_no                                AS ticket_no,         -- 票号
  ticket_latest.order_no                                 AS order_no,          -- 归属子单号
  ticket_latest.ticket_status                            AS ticket_status,     -- 票状态
  ticket_latest.valid_start                              AS valid_start_time,  -- 有效期起始
  ticket_latest.valid_end                                AS valid_end_time,    -- 有效期终止（毫秒精度）
  ticket_latest.pass_policy                              AS pass_policy_type,  -- 放行策略（从SKU继承）
  ticket_latest.tenant_id                                AS tenant_id,         -- 租户ID（分库维度）
  ticket_latest.create_time                              AS create_time,       -- 创建时间
  ticket_latest.update_time                              AS update_time,       -- 更新时间
  order_dtl.order_group_no                               AS order_group_no,    -- 所属聚合单号
  order_dtl.seller_tenant_id                             AS seller_tenant_id,  -- 卖家租户ID
  order_dtl.sku_id                                       AS sku_id,            -- SKU ID
  order_dtl.spu_id                                       AS spu_id,            -- 产品(SPU)ID
  order_dtl.channel_id                                   AS channel_id,        -- 入口渠道ID
  order_dtl.buyer_customer_id                            AS buyer_customer_id,  -- 买家游客ID
  order_dtl.play_date                                    AS play_date,         -- 游玩日期
  DATE_FORMAT(ticket_latest.valid_end, 'yyyyMMdd')       AS valid_end_date,    -- 有效期截止日期
  GET_JSON_OBJECT(ticket_latest.metadata, '$.seatInfo')  AS seat_no,           -- 座位号（演出/场馆）
  GET_JSON_OBJECT(ticket_latest.metadata, '$.cabinInfo') AS cabin_no,          -- 舱位号（游船）
  GET_JSON_OBJECT(ticket_latest.metadata, '$.schedule')  AS schedule_time,     -- 场次/班次时间
  order_dtl.unit_price_amt                               AS unit_price_amt,    -- 票分摊单价（元）
  1                                                      AS ticket_qty,        -- 票数
  CASE WHEN ticket_latest.valid_start IS NULL OR ticket_latest.valid_start = '' OR ticket_latest.valid_start LIKE '1970-01-01%' THEN 1 ELSE 0 END AS delay_active_type,  -- 是否延迟激活｜口径：有效期起始为空或默认值（首次核销时回填）即延迟激活
  verify_dtl.first_verify_time AS first_verify_time,  -- 首次核销时间｜口径：近 400 天核销成功记录的最早时间
  ticket_latest.create_time                              AS issue_time,        -- 出票时间
  CURRENT_TIMESTAMP()                                    AS etl_time           -- ETL 加载时间
FROM ticket_latest
LEFT JOIN order_dtl                                                            -- 关联「子单明细」，取 所属聚合单号、卖家租户ID、SKU ID、产品(SPU)ID、入口渠道ID 等 8 个字段
  ON order_dtl.order_no = ticket_latest.order_no                               -- 按 order_no 关联
LEFT JOIN verify_dtl                                                           -- 关联「核销明细（权益级）」，取 首次核销时间
  ON verify_dtl.ticket_no = ticket_latest.ticket_no;                           -- 按 ticket_no 关联
