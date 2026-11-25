-- dim.dim_opr_approval_flow_df  审批流维度
-- 粒度：1行=1个审批流版本
-- 来源：ods_opr_approval_flow_df
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 12 · 规则翻译 2 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_opr_approval_flow_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                         AS approval_flow_id,  -- 审批流定义ID（源表主键 id）
  a.flow_no                                                    AS flow_no,        -- 审批流编号
  a.flow_code                                                  AS flow_code,      -- 审批流唯一标识码（手动输入
  a.flow_name                                                  AS flow_name,      -- 审批流名称
  a.scope                                                      AS scope_type,     -- 范围
  a.tenant_id                                                  AS tenant_id,      -- 租户ID
  a.flow_status                                                AS flow_status,    -- 状态
  a.version                                                    AS version_no,     -- 版本号
  a.version_status                                             AS version_status,  -- 版本状态
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  JSON_ARRAY_LENGTH(GET_JSON_OBJECT(a.flow_definition, '$.nodes')) AS node_qty,   -- 审批节点数
  GET_JSON_OBJECT(a.flow_definition, '$.timeoutHours')         AS timeout_hour_qty,  -- 单节点超时时长（小时）
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM ods.ods_opr_approval_flow_df a                                               -- 主表「审批流定义」
WHERE a.travel_date = '${bizdate}';                                               -- 只取当日分区
