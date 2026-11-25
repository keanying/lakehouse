-- dwd.dwd_opr_complaint_di  投诉工单明细
-- 粒度：1行=1个投诉工单
-- 来源：ods_opr_complaint_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 15 · 规则翻译 2 · 待确认 2
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_opr_complaint_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                         AS complaint_id,   -- 投诉工单ID（源表主键 id）
  a.complaint_no                                               AS complaint_no,   -- 工单编号
  a.complainant_type                                           AS complainant_type,  -- 投诉方
  a.complainant_id                                             AS complainant_id,  -- 投诉方ID
  a.order_group_no                                             AS order_group_no,  -- 关联订单号（游客投诉时）
  a.complaint_type                                             AS complaint_type,  -- 类型
  a.handler_id                                                 AS handler_id,     -- 处理人ID
  a.sla_deadline                                               AS sla_deadline_time,  -- SLA截止时间
  a.complaint_status                                           AS complaint_status,  -- 状态
  a.tenant_id                                                  AS tenant_id,      -- 租户ID
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  j1.seller_tenant_id                                          AS seller_tenant_id,  -- 被投诉的卖家租户ID
  a.create_time                                                AS create_time_hour_no,  -- 投诉提交小时｜待确认：ods_opr_complaint_di.create_time 取小时
  CASE WHEN a.complaint_status IN ('RESOLVED', 'CLOSED') THEN a.binlog_time END AS resolve_time,  -- 处理完成时间
  (CASE WHEN a.complaint_status IN ('RESOLVED', 'CLOSED') THEN a.binlog_time END) - (a.create_time) AS resolve_hour_qty,  -- 处理时长（小时）
  NULL                                                         AS sla_timeout_type,  -- 是否超 SLA｜待确认：resolve_time 或当前时间晚于 sla_deadline
  1                                                            AS complaint_qty,  -- 投诉数
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn   -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_opr_complaint_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
) a                                                                               -- 主表当日增量，按主键取最新一条
LEFT JOIN dwd.dwd_ord_order_group_di j1                                           -- 关联「聚合单明细」，取 被投诉的卖家租户ID
  ON j1.order_group_no = a.order_group_no                                         -- 按 order_group_no 关联
 AND j1.travel_date = '${bizdate}'                                                -- 只取当日分区
WHERE a.rn = 1                                                                    -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                               -- 剔除源库已删除的记录
