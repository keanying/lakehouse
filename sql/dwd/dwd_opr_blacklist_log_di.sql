-- dwd.dwd_opr_blacklist_log_di  黑名单变更明细
-- 粒度：1行=1次黑名单新增/失效/撤销
-- 来源：ods_opr_blacklist_di
-- 生成方式：Spark SQL / Hive；字段 18 个：直接翻译 17 · 规则翻译 0 · 待确认 1
-- 流水/状态变更类：保留每条变更记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_opr_blacklist_log_di PARTITION (travel_date = '${bizdate}')
SELECT
  a.id                AS blacklist_id,
  a.blacklist_no      AS blacklist_no,
  a.dimension         AS dimension_type,
  a.dimension_value   AS dimension_value_desc,
  a.reason            AS reason_desc,
  a.scope             AS scope_type,
  a.banned_actions    AS banned_action_list_desc,
  a.expires_at        AS expire_time,
  a.blacklist_status  AS blacklist_status,
  a.created_by_type   AS created_by_type,
  a.rule_id           AS rule_id,
  a.tenant_id         AS tenant_id,
  a.create_time       AS create_time,
  a.update_time       AS update_time,
  a.blacklist_status  AS change_type,  -- 待确认：ods_opr_blacklist_di.blacklist_status 变化判定
  a.binlog_time       AS change_time,
  1                   AS change_qty,
  CURRENT_TIMESTAMP() AS etl_time
FROM ods.ods_opr_blacklist_di a
WHERE a.travel_date = '${bizdate}';
