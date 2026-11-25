-- dwd.dwd_fin_frozen_di  冻结/解冻明细
-- 粒度：1行=1条冻结记录（frozen_no）
-- 来源：ods_fin_frozen_record_di
-- 生成方式：Spark SQL / Hive；字段 21 个：直接翻译 19 · 规则翻译 2 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_fin_frozen_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS frozen_id,
  a.frozen_no                                                  AS frozen_no,
  a.account_no                                                 AS account_no,
  a.ticket_no                                                  AS ticket_no,
  ROUND(a.amount / 100, 2)                                     AS freeze_amt,
  a.freeze_type                                                AS freeze_type,
  a.frozen_status                                              AS frozen_status,
  a.frozen_event                                               AS release_event_type,
  a.external_frozen                                            AS external_frozen_type,
  a.external_channel                                           AS external_channel_code,
  a.external_frozen_no                                         AS external_frozen_no,
  a.tenant_id                                                  AS tenant_id,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  j1.account_type                                              AS account_type,
  j1.subject_id                                                AS subject_id,
  j2.sku_id                                                    AS sku_id,
  a.create_time                                                AS freeze_time,
  CASE WHEN a.frozen_status = 'RELEASED' THEN a.binlog_time END AS release_time,
  (CASE WHEN a.frozen_status = 'RELEASED' THEN a.binlog_time END) - (a.create_time) AS freeze_hour_qty,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn
  FROM ods.ods_fin_frozen_record_di
  WHERE travel_date = '${bizdate}'
) a
LEFT JOIN dim.dim_fin_account_df j1
  ON j1.account_no = a.account_no
 AND j1.travel_date = '${bizdate}'
LEFT JOIN dwd.dwd_ord_ticket_di j2
  ON j2.ticket_no = a.ticket_no
 AND j2.travel_date = '${bizdate}'
WHERE a.rn = 1
  AND a.binlog_op_type <> 'DELETE';
