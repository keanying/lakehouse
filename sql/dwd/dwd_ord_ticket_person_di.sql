-- dwd.dwd_ord_ticket_person_di  票游客明细
-- 粒度：1行=1张票上1个人（ticket_no+person_id）
-- 来源：ods_ord_ticket_person_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 21 · 规则翻译 0 · 待确认 6
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_person_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                 AS person_id,            -- 票上的人ID（源表主键 id）
  a.ticket_no          AS ticket_no,            -- 归属票号
  a.person_id          AS person_code,          -- 人ID（票内唯一）
  a.global_customer_id AS global_customer_id,   -- 关联 Customer 全局ID
  a.name               AS person_name,          -- 姓名（脱敏）
  a.id_type            AS cert_type,            -- 证件类型
  a.id_number          AS cert_no,              -- 证件号（脱敏）
  a.phone              AS phone_no,             -- 手机号（脱敏）
  a.is_primary         AS primary_person_type,  -- 是否主游客
  a.tenant_id          AS tenant_id,            -- 租户ID（分库维度）
  a.create_time        AS create_time,          -- 创建时间
  a.update_time        AS update_time,          -- 更新时间
  j1.order_no          AS order_no,             -- 所属子单号
  j1.seller_tenant_id  AS seller_tenant_id,     -- 卖家租户ID
  j1.sku_id            AS sku_id,               -- SKU ID
  j1.play_date         AS play_date,            -- 游玩日期
  j2.country_code      AS origin_country_code,  -- 客源国家编码｜待确认：dim_opr_region_f.country_code 按证件号前 6 位映射
  j3.province_code     AS origin_province_code,  -- 客源省份编码｜待确认：dim_opr_region_f.province_code 按证件号前 6 位映射
  j3.province_name     AS origin_province_name,  -- 客源省份名称
  j3.city_code         AS origin_city_code,     -- 客源城市编码
  j3.city_name         AS origin_city_name,     -- 客源城市名称
  a.id_number          AS age_year_qty,         -- 游玩时年龄（岁）｜待确认：ods_ord_ticket_person_di.id_number 第 7~14 位出生日期 与 play_date 计算
  NULL                 AS age_band_code,        -- 年龄段｜待确认：age_year_qty 分段
  a.id_number          AS gender_type,          -- 性别｜待确认：ods_ord_ticket_person_di.id_number 第 17 位奇偶
  1                    AS person_qty,           -- 游客人数
  CURRENT_TIMESTAMP()  AS etl_time              -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_ord_ticket_person_di
  WHERE travel_date = '${bizdate}'              -- 只取当日分区
) a                                             -- 主表当日增量，按主键取最新一条
LEFT JOIN dwd.dwd_ord_ticket_di j1              -- 关联「票明细（出票）」，取 所属子单号、卖家租户ID、SKU ID、游玩日期
  ON j1.ticket_no = a.ticket_no                 -- 按 ticket_no 关联
 AND j1.travel_date = '${bizdate}'              -- 只取当日分区
LEFT JOIN dim.dim_opr_region_f j2               -- 关联「地区维度」，取 客源国家编码
  ON j2.region_id = a.id                        -- 按 id→region_id 关联｜待确认：关联键
LEFT JOIN dim.dim_opr_region_f j3               -- 关联「地区维度」，取 客源省份编码、客源省份名称、客源城市编码、客源城市名称
  ON j3.region_id = j2.region_id                -- 按 region_id 关联
WHERE a.rn = 1                                  -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';             -- 剔除源库已删除的记录
