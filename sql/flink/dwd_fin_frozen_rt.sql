-- dwd.dwd_fin_frozen_rt  实时冻结/解冻明细
-- 粒度：1行=1条冻结记录（frozen_no）
-- 来源：ods_fin_frozen_record_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 22 个：直接翻译 19 · 规则翻译 3 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_fin_frozen_rt
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                       AS travel_date,
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
  CURRENT_TIMESTAMP                                            AS event_time
FROM ods.ods_fin_frozen_record_rt a
LEFT JOIN dim.dim_fin_account_df FOR SYSTEM_TIME AS OF a.proc_time AS j1
  ON j1.account_no = a.account_no
LEFT JOIN dwd.dwd_ord_ticket_di j2
  ON j2.ticket_no = a.ticket_no
 AND j2.travel_date = '${bizdate}';
