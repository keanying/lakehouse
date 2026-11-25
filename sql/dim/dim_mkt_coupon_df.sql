-- dim.dim_mkt_coupon_df  优惠券维度
-- 粒度：1行=1张券模板
-- 来源：ods_mkt_coupon_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_mkt_coupon_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                 AS coupon_id,             -- 优惠券ID（源表主键 id）
  a.coupon_no          AS coupon_no,             -- 优惠券编号
  a.tenant_id          AS tenant_id,             -- 归属商户ID
  a.coupon_name        AS coupon_name,           -- 优惠券名称
  a.coupon_type        AS coupon_type,           -- 类型
  a.coupon_value       AS coupon_value_num,      -- 优惠值（分或百分比）
  a.applicable_sku_ids AS applicable_sku_list_desc,  -- 适用SKU列表（null=全部）
  a.total_count        AS total_qty,             -- 发行总量
  a.used_count         AS used_qty,              -- 已使用数量
  a.effective_from     AS effective_start_time,  -- 生效起始
  a.effective_to       AS effective_end_time,    -- 生效终止
  a.coupon_status      AS coupon_status,         -- 状态
  a.create_time        AS create_time,           -- 创建时间
  a.update_time        AS update_time,           -- 更新时间
  CURRENT_TIMESTAMP()  AS etl_time               -- ETL 加载时间
FROM ods.ods_mkt_coupon_df a                     -- 主表「优惠券」
WHERE a.travel_date = '${bizdate}';              -- 只取当日分区
