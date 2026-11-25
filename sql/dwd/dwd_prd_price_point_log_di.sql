-- dwd.dwd_prd_price_point_log_di  价格点变更明细
-- 粒度：1行=1次价格点新增/修改/删除
-- 来源：ods_prd_price_point_di（binlog）
-- 生成方式：Spark SQL / Hive；字段 20 个：直接翻译 18 · 规则翻译 2 · 待确认 0
-- 流水/状态变更类：保留每条变更记录

INSERT OVERWRITE TABLE dwd.dwd_prd_price_point_log_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS price_point_id,
  a.price_no                                                   AS price_no,
  a.sku_id                                                     AS sku_id,
  a.channel                                                    AS price_channel_code,
  a.date_single                                                AS price_date,
  a.date_from                                                  AS price_start_date,
  a.date_to                                                    AS price_end_date,
  a.weekday_mask                                               AS weekday_mask_code,
  a.ext_dims                                                   AS ext_dim_desc,
  a.priority                                                   AS priority_no,
  a.effective_from                                             AS effective_start_time,
  a.effective_to                                               AS effective_end_time,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  a.binlog_op_type                                             AS change_type,
  LAG(a.price) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS before_price_amt,
  a.price                                                      AS after_price_amt,
  a.binlog_time                                                AS change_time,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM ods.ods_prd_price_point_di a
WHERE a.travel_date = '${bizdate}';
