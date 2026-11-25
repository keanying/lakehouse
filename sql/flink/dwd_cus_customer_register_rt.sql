-- dwd.dwd_cus_customer_register_rt  实时游客注册
-- 粒度：1行=1个新注册游客
-- 来源：ods_cus_customer_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 15 个：直接翻译 14 · 规则翻译 1 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_cus_customer_register_rt
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd') AS travel_date,
  a.id                                   AS customer_id,
  a.customer_no                          AS customer_no,
  a.customer_kind                        AS customer_type,
  a.gender                               AS gender_type,
  a.auth_status                          AS auth_status,
  a.customer_status                      AS customer_status,
  a.register_source                      AS register_source_code,
  a.register_tenant_id                   AS register_tenant_id,
  a.create_time                          AS create_time,
  a.update_time                          AS update_time,
  j1.channel_id                          AS register_channel_id,
  a.create_time                          AS register_time,
  1                                      AS register_qty,
  CURRENT_TIMESTAMP                      AS event_time
FROM ods.ods_cus_customer_rt a
LEFT JOIN dim.dim_trf_channel_df FOR SYSTEM_TIME AS OF a.proc_time AS j1
  ON j1.channel_code = a.register_source;
