-- dwd.dwd_cus_customer_register_di  游客注册明细
-- 粒度：1行=1个新注册游客
-- 来源：ods_cus_customer_di
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 14 · 规则翻译 0 · 待确认 1
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_cus_customer_register_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                 AS customer_id,
  a.customer_no        AS customer_no,
  a.customer_kind      AS customer_type,
  a.gender             AS gender_type,
  a.auth_status        AS auth_status,
  a.customer_status    AS customer_status,
  a.register_source    AS register_source_code,
  a.register_tenant_id AS register_tenant_id,
  a.create_time        AS create_time,
  a.update_time        AS update_time,
  j1.channel_id        AS register_channel_id,
  a.birthday           AS age_band_code,  -- 待确认：ods_cus_customer_di.birthday 计算
  a.create_time        AS register_time,
  1                    AS register_qty,
  CURRENT_TIMESTAMP()  AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_cus_customer_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dim.dim_trf_channel_df j1
  ON j1.channel_code = a.register_source
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
