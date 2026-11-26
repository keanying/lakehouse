-- dim.dim_mkt_coupon_df  优惠券维度
-- 粒度：1行=1张券模板
-- 来源：ods_mkt_coupon_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
coupon_src AS (                                           -- 主表「优惠券」，只取用到的列
  SELECT applicable_sku_ids, coupon_name, coupon_no, coupon_status, coupon_type, coupon_value,
         create_time, effective_from, effective_to, id, tenant_id, total_count, update_time, used_count
  FROM ods.ods_mkt_coupon_df
  WHERE travel_date = '${bizdate}'                        -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_mkt_coupon_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  coupon_src.id                 AS coupon_id,             -- 优惠券ID（源表主键 id）
  coupon_src.coupon_no          AS coupon_no,             -- 优惠券编号
  coupon_src.tenant_id          AS tenant_id,             -- 归属商户ID
  coupon_src.coupon_name        AS coupon_name,           -- 优惠券名称
  coupon_src.coupon_type        AS coupon_type,           -- 类型
  coupon_src.coupon_value       AS coupon_value_num,      -- 优惠值（分或百分比）
  coupon_src.applicable_sku_ids AS applicable_sku_list_desc,  -- 适用SKU列表（null=全部）
  coupon_src.total_count        AS total_qty,             -- 发行总量
  coupon_src.used_count         AS used_qty,              -- 已使用数量
  coupon_src.effective_from     AS effective_start_time,  -- 生效起始
  coupon_src.effective_to       AS effective_end_time,    -- 生效终止
  coupon_src.coupon_status      AS coupon_status,         -- 状态
  coupon_src.create_time        AS create_time,           -- 创建时间
  coupon_src.update_time        AS update_time,           -- 更新时间
  CURRENT_TIMESTAMP()           AS etl_time               -- ETL 加载时间
FROM coupon_src;
