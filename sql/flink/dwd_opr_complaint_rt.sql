-- dwd.dwd_opr_complaint_rt  实时投诉工单
-- 粒度：1行=1个投诉工单
-- 来源：ods_opr_complaint_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 20 个：直接翻译 15 · 规则翻译 5 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_opr_complaint_rt                                              -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd')                       AS travel_date,    -- 数据日期
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
  HOUR(a.create_time) AS create_time_hour_no,  -- 投诉提交小时｜口径：投诉提交时间取小时
  CASE WHEN a.complaint_status IN ('RESOLVED', 'CLOSED') THEN a.binlog_time END AS resolve_time,  -- 处理完成时间
  TIMESTAMPDIFF(HOUR, a.create_time, CASE WHEN a.complaint_status IN ('RESOLVED', 'CLOSED') THEN a.binlog_time END) AS resolve_hour_qty,  -- 处理时长（小时）
  CASE WHEN COALESCE(CASE WHEN a.complaint_status IN ('RESOLVED', 'CLOSED') THEN a.binlog_time END, CURRENT_TIMESTAMP) > a.sla_deadline THEN 1 ELSE 0 END AS sla_timeout_type,  -- 是否超 SLA｜口径：同离线
  1                                                            AS complaint_qty,  -- 投诉数
  CURRENT_TIMESTAMP                                            AS event_time      -- 事件时间（binlog 时间）
FROM ods.ods_opr_complaint_rt a                                                   -- 主表「投诉工单 binlog 流」
LEFT JOIN dwd.dwd_ord_order_group_di j1                                           -- 关联「聚合单明细」，取 被投诉的卖家租户ID
  ON j1.order_group_no = a.order_group_no                                         -- 按 order_group_no 关联
 AND j1.travel_date = '${bizdate}';                                               -- 只取当日分区
