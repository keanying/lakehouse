-- dwd.dwd_ord_order_group_di  聚合单明细
-- 粒度：1行=1个聚合单（order_group_no）
-- 来源：ods_ord_order_group_di
-- 生成方式：Spark SQL / Hive；字段 29 个：直接翻译 25 · 规则翻译 4 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
order_group_rn AS (                                                            -- 「聚合单」当日增量，同一主键按 binlog 时间倒序编号
  SELECT app_id, app_ref, buyer_customer_id, buyer_id, buyer_type, channel_id, contact_id_number,
         contact_id_type, contact_name, contact_phone, create_time, currency, id, operator_id,
         operator_tenant_id, operator_type, order_group_no, pay_status, pay_timeout_at, seller_tenant_id,
         tenant_id, total_amount, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_order_group_di
  WHERE travel_date = '${bizdate}'                                             -- 只取当日分区
),
order_group_latest AS (                                                        -- 「聚合单」每个主键只保留最新一条，剔除已删除记录
  SELECT app_id, app_ref, buyer_customer_id, buyer_id, buyer_type, channel_id, contact_id_number,
         contact_id_type, contact_name, contact_phone, create_time, currency, id, operator_id,
         operator_tenant_id, operator_type, order_group_no, pay_status, pay_timeout_at, seller_tenant_id,
         tenant_id, total_amount, update_time
  FROM order_group_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                             -- 剔除源库已删除的记录
),
payment_record_rn AS (                                                         -- 「支付记录」当日增量，同一主键按 binlog 时间倒序编号
  SELECT id, order_group_no, pay_time, pay_direction, pay_status, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_fin_payment_record_di
  WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')   -- 支付可能早于聚合单今天的变更，取近 400 天  -- 只取当日分区
),
payment_record_latest AS (                                                     -- 「支付记录」每个主键只保留最新一条，剔除已删除记录
  SELECT order_group_no, MIN(CASE WHEN pay_direction = 'INBOUND' AND pay_status IN ('PAID', 'PARTIAL_REFUNDED', 'REFUNDED') THEN pay_time END) AS first_pay_time
  FROM payment_record_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'  -- 剔除源库已删除的记录
      GROUP BY order_group_no
),
order_rn AS (                                                                  -- 「子单」当日增量，同一主键按 binlog 时间倒序编号
  SELECT id, order_group_no, quantity, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_order_di
  WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 400), 'yyyyMMdd')   -- 子单随聚合单创建，聚合单后续变更时需回看  -- 只取当日分区
),
order_latest AS (                                                              -- 「子单」每个主键只保留最新一条，剔除已删除记录
  SELECT order_group_no, SUM(quantity) AS order_ticket_qty
  FROM order_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'  -- 剔除源库已删除的记录
      GROUP BY order_group_no
),
order_count AS (                                                               -- 「子单」按 order_group_no 预聚合
  SELECT order_group_no, COUNT(order_no) AS v
  FROM ods.ods_ord_order_di
  WHERE travel_date = '${bizdate}'                                             -- 只取当日分区
  GROUP BY order_group_no                                                      -- 按粒度键汇总
),
channel_dim AS (                                                               -- 「渠道/接入端维度」当日数据，只取用到的列
  SELECT channel_id, channel_type
  FROM dim.dim_trf_channel_df
  WHERE travel_date = '${bizdate}'                                             -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_ord_order_group_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(channel_dim) */
  order_group_latest.id                                   AS order_group_id,   -- 聚合单ID（源表主键 id）
  order_group_latest.order_group_no                       AS order_group_no,   -- 聚合单号
  order_group_latest.seller_tenant_id                     AS seller_tenant_id,  -- 卖家租户ID（商品归属租户
  order_group_latest.channel_id                           AS channel_id,       -- 入口端ID
  order_group_latest.app_id                               AS app_code,         -- 对接端标识
  order_group_latest.app_ref                              AS app_ref_code,     -- 对接端自定义子标识（app_id对应）
  order_group_latest.operator_type                        AS operator_type,    -- 操作人类型
  order_group_latest.operator_id                          AS operator_id,      -- 操作人ID（多态
  order_group_latest.operator_tenant_id                   AS operator_tenant_id,  -- 操作人所属租户ID
  order_group_latest.buyer_type                           AS buyer_type,       -- 付款方类型
  order_group_latest.buyer_id                             AS buyer_id,         -- 付款方ID（多态
  order_group_latest.buyer_customer_id                    AS buyer_customer_id,  -- C端筛选冗余
  order_group_latest.contact_name                         AS contact_name,     -- 联系人姓名（脱敏）
  order_group_latest.contact_phone                        AS contact_phone_no,  -- 联系人手机（脱敏）
  order_group_latest.contact_id_type                      AS contact_cert_type,  -- 联系人证件类型
  order_group_latest.contact_id_number                    AS contact_cert_no,  -- 联系人证件号（脱敏）
  ROUND(order_group_latest.total_amount / 100, 2)         AS total_amt,        -- 总金额（元）
  order_group_latest.currency                             AS currency_code,    -- 币种（=商户配置币种
  order_group_latest.pay_status                           AS pay_status,       -- 支付状态
  order_group_latest.pay_timeout_at                       AS pay_timeout_time,  -- 支付超时截止时间
  order_group_latest.tenant_id                            AS tenant_id,        -- 租户ID（分库维度
  order_group_latest.create_time                          AS create_time,      -- 创建时间
  order_group_latest.update_time                          AS update_time,      -- 更新时间
  DATE_FORMAT(order_group_latest.create_time, 'yyyyMMdd') AS order_date,       -- 下单日期
  payment_record_latest.first_pay_time AS first_pay_time,  -- 首次支付成功时间｜口径：近 400 天支付记录中，收款（INBOUND）且已支付的最早支付时间
  order_latest.order_ticket_qty AS order_ticket_qty,  -- 聚合单内购买票数合计｜口径：聚合单下子单购买数量合计
  COALESCE(order_count.v, 0)                              AS sub_order_qty,    -- 聚合单内子单数（套票子项单除外）
  channel_dim.channel_type                                AS channel_type,     -- 入口渠道类型
  CURRENT_TIMESTAMP()                                     AS etl_time          -- ETL 加载时间
FROM order_group_latest
LEFT JOIN payment_record_latest                                                -- 关联「支付记录」，取 首次支付成功时间
  ON payment_record_latest.order_group_no = order_group_latest.order_group_no  -- 按 order_group_no 关联
LEFT JOIN order_latest                                                         -- 关联「子单」，取 聚合单内购买票数合计
  ON order_latest.order_group_no = order_group_latest.order_group_no           -- 按 order_group_no 关联
LEFT JOIN order_count                                                          -- 关联「子单」，取 聚合单内子单数（套票子项单除外）
  ON order_count.order_group_no = order_group_latest.order_group_no            -- 按 order_group_no 关联
LEFT JOIN channel_dim                                                          -- 关联「渠道/接入端维度」，取 入口渠道类型
  ON channel_dim.channel_id = order_group_latest.channel_id;                   -- 按 channel_id 关联
