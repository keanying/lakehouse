-- dwd.dwd_opr_complaint_di  投诉工单明细
-- 粒度：1行=1个投诉工单
-- 来源：ods_opr_complaint_di
-- 生成方式：Spark SQL / Hive；字段 19 个：直接翻译 15 · 规则翻译 4 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
complaint_rn AS (                                                                 -- 「投诉工单」当日增量，同一主键按 binlog 时间倒序编号
  SELECT binlog_time, complainant_id, complainant_type, complaint_no, complaint_status, complaint_type,
         create_time, handler_id, id, order_group_no, sla_deadline, tenant_id, update_time,
         binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_opr_complaint_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
complaint_latest AS (                                                             -- 「投诉工单」每个主键只保留最新一条，剔除已删除记录
  SELECT binlog_time, complainant_id, complainant_type, complaint_no, complaint_status, complaint_type,
         create_time, handler_id, id, order_group_no, sla_deadline, tenant_id, update_time
  FROM complaint_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
order_group_dtl AS (                                                              -- 「聚合单明细」当日数据，只取用到的列
  SELECT order_group_no, seller_tenant_id
  FROM dwd.dwd_ord_order_group_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_opr_complaint_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  complaint_latest.id                                          AS complaint_id,   -- 投诉工单ID（源表主键 id）
  complaint_latest.complaint_no                                AS complaint_no,   -- 工单编号
  complaint_latest.complainant_type                            AS complainant_type,  -- 投诉方
  complaint_latest.complainant_id                              AS complainant_id,  -- 投诉方ID
  complaint_latest.order_group_no                              AS order_group_no,  -- 关联订单号（游客投诉时）
  complaint_latest.complaint_type                              AS complaint_type,  -- 类型
  complaint_latest.handler_id                                  AS handler_id,     -- 处理人ID
  complaint_latest.sla_deadline                                AS sla_deadline_time,  -- SLA截止时间
  complaint_latest.complaint_status                            AS complaint_status,  -- 状态
  complaint_latest.tenant_id                                   AS tenant_id,      -- 租户ID
  complaint_latest.create_time                                 AS create_time,    -- 创建时间
  complaint_latest.update_time                                 AS update_time,    -- 更新时间
  order_group_dtl.seller_tenant_id                             AS seller_tenant_id,  -- 被投诉的卖家租户ID
  HOUR(complaint_latest.create_time) AS create_time_hour_no,  -- 投诉提交小时｜口径：投诉提交时间取小时
  CASE WHEN complaint_latest.complaint_status IN ('RESOLVED', 'CLOSED') THEN complaint_latest.binlog_time END AS resolve_time,  -- 处理完成时间
  ROUND((UNIX_TIMESTAMP(CASE WHEN complaint_latest.complaint_status IN ('RESOLVED', 'CLOSED') THEN complaint_latest.binlog_time END) - UNIX_TIMESTAMP(complaint_latest.create_time)) / 3600, 2) AS resolve_hour_qty,  -- 处理时长（小时）
  CASE WHEN COALESCE(CASE WHEN complaint_latest.complaint_status IN ('RESOLVED', 'CLOSED') THEN complaint_latest.binlog_time END, CURRENT_TIMESTAMP()) > complaint_latest.sla_deadline THEN 1 ELSE 0 END AS sla_timeout_type,  -- 是否超 SLA｜口径：解决时间（未解决取当前时间）晚于 SLA 截止
  1                                                            AS complaint_qty,  -- 投诉数
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM complaint_latest
LEFT JOIN order_group_dtl                                                         -- 关联「聚合单明细」，取 被投诉的卖家租户ID
  ON order_group_dtl.order_group_no = complaint_latest.order_group_no;            -- 按 order_group_no 关联
