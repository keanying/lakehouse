-- dwd.dwd_ord_order_group_di  聚合单明细
-- 粒度：1行=1个聚合单（order_group_no）
-- 来源：ods_ord_order_group_di
-- 生成方式：Spark SQL / Hive；字段 29 个：直接翻译 25 · 规则翻译 2 · 待确认 2
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_ord_order_group_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                   AS order_group_id,    -- 聚合单ID（源表主键 id）
  a.order_group_no                       AS order_group_no,    -- 聚合单号
  a.seller_tenant_id                     AS seller_tenant_id,  -- 卖家租户ID（商品归属租户
  a.channel_id                           AS channel_id,        -- 入口端ID
  a.app_id                               AS app_code,          -- 对接端标识
  a.app_ref                              AS app_ref_code,      -- 对接端自定义子标识（app_id对应）
  a.operator_type                        AS operator_type,     -- 操作人类型
  a.operator_id                          AS operator_id,       -- 操作人ID（多态
  a.operator_tenant_id                   AS operator_tenant_id,  -- 操作人所属租户ID
  a.buyer_type                           AS buyer_type,        -- 付款方类型
  a.buyer_id                             AS buyer_id,          -- 付款方ID（多态
  a.buyer_customer_id                    AS buyer_customer_id,  -- C端筛选冗余
  a.contact_name                         AS contact_name,      -- 联系人姓名（脱敏）
  a.contact_phone                        AS contact_phone_no,  -- 联系人手机（脱敏）
  a.contact_id_type                      AS contact_cert_type,  -- 联系人证件类型
  a.contact_id_number                    AS contact_cert_no,   -- 联系人证件号（脱敏）
  ROUND(a.total_amount / 100, 2)         AS total_amt,         -- 总金额（元）
  a.currency                             AS currency_code,     -- 币种（=商户配置币种
  a.pay_status                           AS pay_status,        -- 支付状态
  a.pay_timeout_at                       AS pay_timeout_time,  -- 支付超时截止时间
  a.tenant_id                            AS tenant_id,         -- 租户ID（分库维度
  a.create_time                          AS create_time,       -- 创建时间
  a.update_time                          AS update_time,       -- 更新时间
  DATE_FORMAT(a.create_time, 'yyyyMMdd') AS order_date,        -- 下单日期
  j1.pay_time                            AS first_pay_time,    -- 首次支付成功时间｜待确认：ods_fin_payment_record_di.pay_time 按 order_group_no 取 INBOUND 且 PAID 的最小值
  j2.quantity                            AS order_ticket_qty,  -- 聚合单内购买票数合计｜待确认：ods_ord_order_di.quantity 按 order_group_no 汇总
  COALESCE(j3.v, 0)                      AS sub_order_qty,     -- 聚合单内子单数（套票子项单除外）
  j4.channel_type                        AS channel_type,      -- 入口渠道类型
  CURRENT_TIMESTAMP()                    AS etl_time           -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_order_group_di
  WHERE travel_date = '${bizdate}'                             -- 只取当日分区
) a                                                            -- 主表当日增量，按主键取最新一条
LEFT JOIN ods.ods_fin_payment_record_di j1                     -- 关联「支付记录」，取 首次支付成功时间
  ON j1.order_group_no = a.order_group_no                      -- 按 order_group_no 关联
 AND j1.travel_date = '${bizdate}'                             -- 只取当日分区
LEFT JOIN ods.ods_ord_order_di j2                              -- 关联「子单」，取 聚合单内购买票数合计
  ON j2.order_group_no = a.order_group_no                      -- 按 order_group_no 关联
 AND j2.travel_date = '${bizdate}'                             -- 只取当日分区
LEFT JOIN (SELECT order_group_no, COUNT(order_no) AS v FROM ods.ods_ord_order_di WHERE travel_date = '${bizdate}' GROUP BY order_group_no) j3  -- 关联「子单」按键聚合，得到 聚合单内子单数（套票子项单除外）
  ON j3.order_group_no = a.order_group_no                      -- 按 order_group_no 关联
LEFT JOIN dim.dim_trf_channel_df j4                            -- 关联「渠道/接入端维度」，取 入口渠道类型
  ON j4.channel_id = a.channel_id                              -- 按 channel_id 关联
 AND j4.travel_date = '${bizdate}'                             -- 只取当日分区
WHERE a.rn = 1                                                 -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                            -- 剔除源库已删除的记录
