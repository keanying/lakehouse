-- dwd.dwd_ord_ticket_person_di  票游客明细
-- 粒度：1行=1张票上1个人（ticket_no+person_id）
-- 来源：ods_ord_ticket_person_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 21 · 规则翻译 0 · 待确认 6
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
ticket_person_rn AS (                                              -- 「票上的人」当日增量，同一主键按 binlog 时间倒序编号
  SELECT create_time, global_customer_id, id, id_number, id_type, is_primary, name, person_id, phone,
         tenant_id, ticket_no, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_ticket_person_di
  WHERE travel_date = '${bizdate}'                                 -- 只取当日分区
),
ticket_person_latest AS (                                          -- 「票上的人」每个主键只保留最新一条，剔除已删除记录
  SELECT create_time, global_customer_id, id, id_number, id_type, is_primary, name, person_id, phone,
         tenant_id, ticket_no, update_time
  FROM ticket_person_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                 -- 剔除源库已删除的记录
),
ticket_dtl AS (                                                    -- 「票明细（出票）」当日数据，只取用到的列
  SELECT order_no, play_date, seller_tenant_id, sku_id, ticket_no
  FROM dwd.dwd_ord_ticket_di
  WHERE travel_date = '${bizdate}'                                 -- 只取当日分区
),
region_dim AS (                                                    -- 「地区维度」当日数据，只取用到的列
  SELECT city_code, city_name, country_code, province_code, province_name, region_id
  FROM dim.dim_opr_region_f
)
INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_person_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(region_dim) */
  ticket_person_latest.id                 AS person_id,            -- 票上的人ID（源表主键 id）
  ticket_person_latest.ticket_no          AS ticket_no,            -- 归属票号
  ticket_person_latest.person_id          AS person_code,          -- 人ID（票内唯一）
  ticket_person_latest.global_customer_id AS global_customer_id,   -- 关联 Customer 全局ID
  ticket_person_latest.name               AS person_name,          -- 姓名（脱敏）
  ticket_person_latest.id_type            AS cert_type,            -- 证件类型
  ticket_person_latest.id_number          AS cert_no,              -- 证件号（脱敏）
  ticket_person_latest.phone              AS phone_no,             -- 手机号（脱敏）
  ticket_person_latest.is_primary         AS primary_person_type,  -- 是否主游客
  ticket_person_latest.tenant_id          AS tenant_id,            -- 租户ID（分库维度）
  ticket_person_latest.create_time        AS create_time,          -- 创建时间
  ticket_person_latest.update_time        AS update_time,          -- 更新时间
  ticket_dtl.order_no                     AS order_no,             -- 所属子单号
  ticket_dtl.seller_tenant_id             AS seller_tenant_id,     -- 卖家租户ID
  ticket_dtl.sku_id                       AS sku_id,               -- SKU ID
  ticket_dtl.play_date                    AS play_date,            -- 游玩日期
  region_dim.country_code                 AS origin_country_code,  -- 客源国家编码｜待确认：dim_opr_region_f.country_code 按证件号前 6 位映射
  region_dim.province_code                AS origin_province_code,  -- 客源省份编码｜待确认：dim_opr_region_f.province_code 按证件号前 6 位映射
  region_dim.province_name                AS origin_province_name,  -- 客源省份名称
  region_dim.city_code                    AS origin_city_code,     -- 客源城市编码
  region_dim.city_name                    AS origin_city_name,     -- 客源城市名称
  ticket_person_latest.id_number          AS age_year_qty,         -- 游玩时年龄（岁）｜待确认：ods_ord_ticket_person_di.id_number 第 7~14 位出生日期 与 play_date 计算
  NULL                                    AS age_band_code,        -- 年龄段｜待确认：age_year_qty 分段
  ticket_person_latest.id_number          AS gender_type,          -- 性别｜待确认：ods_ord_ticket_person_di.id_number 第 17 位奇偶
  1                                       AS person_qty,           -- 游客人数
  CURRENT_TIMESTAMP()                     AS etl_time              -- ETL 加载时间
FROM ticket_person_latest
LEFT JOIN ticket_dtl                                               -- 关联「票明细（出票）」，取 所属子单号、卖家租户ID、SKU ID、游玩日期
  ON ticket_dtl.ticket_no = ticket_person_latest.ticket_no         -- 按 ticket_no 关联
LEFT JOIN region_dim                                               -- 关联「地区维度」，取 客源国家编码、客源省份编码、客源省份名称、客源城市编码、客源城市名称
  ON region_dim.region_id = ticket_person_latest.id;               -- 按 id→region_id 关联｜待确认：关联键
