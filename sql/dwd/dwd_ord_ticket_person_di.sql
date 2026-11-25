-- dwd.dwd_ord_ticket_person_di  票游客明细
-- 粒度：1行=1张票上1个人（ticket_no+person_id）
-- 来源：ods_ord_ticket_person_di
-- 生成方式：Spark SQL / Hive；字段 27 个：直接翻译 21 · 规则翻译 0 · 待确认 6
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_ord_ticket_person_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                 AS person_id,
  a.ticket_no          AS ticket_no,
  a.person_id          AS person_code,
  a.global_customer_id AS global_customer_id,
  a.name               AS person_name,
  a.id_type            AS cert_type,
  a.id_number          AS cert_no,
  a.phone              AS phone_no,
  a.is_primary         AS primary_person_type,
  a.tenant_id          AS tenant_id,
  a.create_time        AS create_time,
  a.update_time        AS update_time,
  j1.order_no          AS order_no,
  j1.seller_tenant_id  AS seller_tenant_id,
  j1.sku_id            AS sku_id,
  j1.play_date         AS play_date,
  j2.country_code      AS origin_country_code,  -- 待确认：dim_opr_region_f.country_code 按证件号前 6 位映射
  j3.province_code     AS origin_province_code,  -- 待确认：dim_opr_region_f.province_code 按证件号前 6 位映射
  j3.province_name     AS origin_province_name,
  j3.city_code         AS origin_city_code,
  j3.city_name         AS origin_city_name,
  a.id_number          AS age_year_qty,  -- 待确认：ods_ord_ticket_person_di.id_number 第 7~14 位出生日期 与 play_date 计算
  NULL                 AS age_band_code,  -- 待确认：age_year_qty 分段
  a.id_number          AS gender_type,  -- 待确认：ods_ord_ticket_person_di.id_number 第 17 位奇偶
  1                    AS person_qty,
  CURRENT_TIMESTAMP()  AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_ord_ticket_person_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dwd.dwd_ord_ticket_di j1
  ON j1.ticket_no = a.ticket_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dim.dim_opr_region_f j2
  ON j2.region_id = a.id  -- 待确认：关联键
LEFT JOIN dim.dim_opr_region_f j3
  ON j3.region_id = j2.region_id
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
