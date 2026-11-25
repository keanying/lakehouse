-- dim.dim_opr_approval_flow_df  审批流维度
-- 粒度：1行=1个审批流版本
-- 来源：ods_opr_approval_flow_df
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 12 · 规则翻译 2 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_approval_flow_df PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                                                         AS approval_flow_id,
  a.flow_no                                                    AS flow_no,
  a.flow_code                                                  AS flow_code,
  a.flow_name                                                  AS flow_name,
  a.scope                                                      AS scope_type,
  a.tenant_id                                                  AS tenant_id,
  a.flow_status                                                AS flow_status,
  a.version                                                    AS version_no,
  a.version_status                                             AS version_status,
  a.create_time                                                AS create_time,
  a.update_time                                                AS update_time,
  JSON_ARRAY_LENGTH(GET_JSON_OBJECT(a.flow_definition, '$.nodes')) AS node_qty,
  GET_JSON_OBJECT(a.flow_definition, '$.timeoutHours')         AS timeout_hour_qty,
  CURRENT_TIMESTAMP()                                          AS etl_time
FROM ods.ods_opr_approval_flow_df a
WHERE a.travel_date = '${bizdate}';
