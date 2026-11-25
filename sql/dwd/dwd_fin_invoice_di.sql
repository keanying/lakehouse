-- dwd.dwd_fin_invoice_di  发票明细
-- 粒度：1行=1个发票单（invoice_no）
-- 来源：ods_fin_invoice_order_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_fin_invoice_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                             AS invoice_id,
  a.invoice_no                     AS invoice_no,
  a.tenant_id                      AS tenant_id,
  a.invoice_type                   AS invoice_type,
  a.invoice_subject                AS invoice_subject_type,
  a.order_group_no                 AS order_group_no,
  a.fee_item                       AS fee_item_code,
  ROUND(a.invoice_amount / 100, 2) AS invoice_amt,
  a.invoice_config_id              AS invoice_config_id,
  a.invoice_status                 AS invoice_status,
  a.invoice_file_url               AS invoice_file_url_desc,
  a.approval_no                    AS approval_no,
  a.create_time                    AS create_time,
  a.update_time                    AS update_time,
  j1.invoice_provider_code         AS invoice_provider_code,
  a.create_time                    AS apply_time,
  CURRENT_TIMESTAMP()              AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_fin_invoice_order_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dim.dim_fin_invoice_config_df j1
  ON j1.invoice_config_id = a.invoice_config_id
 AND j1.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
