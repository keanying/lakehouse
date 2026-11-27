-- dwd.dwd_opr_approval_di  审批实例明细
-- 粒度：1行=1个审批实例
-- 来源：ods_opr_approval_instance_di
-- 生成方式：Spark SQL / Hive；字段 20 个：直接翻译 17 · 规则翻译 3 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
approval_instance_rn AS (                                                         -- 「审批实例」当日增量，同一主键按 binlog 时间倒序编号
  SELECT applicant_id, applicant_name, business_no, create_time, current_node, flow_code, flow_id, id,
         instance_no, instance_status, tenant_id, timeout_at, update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn      -- 去重序号（1 = 最新）
  FROM ods.ods_opr_approval_instance_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
),
approval_instance_latest AS (                                                     -- 「审批实例」每个主键只保留最新一条，剔除已删除记录
  SELECT applicant_id, applicant_name, business_no, create_time, current_node, flow_code, flow_id, id,
         instance_no, instance_status, tenant_id, timeout_at, update_time
  FROM approval_instance_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                                -- 剔除源库已删除的记录
),
approval_flow_dim AS (                                                            -- 「审批流维度」当日数据，只取用到的列
  SELECT approval_flow_id, flow_name
  FROM dim.dim_opr_approval_flow_df
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_opr_approval_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(approval_flow_dim) */
  approval_instance_latest.id                                  AS instance_id,    -- 审批实例ID（源表主键 id）
  approval_instance_latest.instance_no                         AS instance_no,    -- 审批实例号
  approval_instance_latest.flow_id                             AS flow_id,        -- 审批流ID
  approval_instance_latest.flow_code                           AS flow_code,      -- 审批流标识码
  approval_instance_latest.business_no                         AS business_no,    -- 关联业务号（退款单号/提现单号等）
  approval_instance_latest.applicant_id                        AS applicant_id,   -- 申请人ID
  approval_instance_latest.applicant_name                      AS applicant_name,  -- 申请人姓名
  approval_instance_latest.current_node                        AS current_node_name,  -- 当前审批节点名称
  approval_instance_latest.timeout_at                          AS timeout_time,   -- 当前节点审批截止时间
  approval_instance_latest.instance_status                     AS instance_status,  -- 状态
  approval_instance_latest.tenant_id                           AS tenant_id,      -- 租户ID
  approval_instance_latest.create_time                         AS create_time,    -- 创建时间
  approval_instance_latest.update_time                         AS update_time,    -- 更新时间
  approval_flow_dim.flow_name                                  AS flow_name,      -- 审批流名称
  approval_instance_latest.create_time                         AS apply_time,     -- 发起时间
  CASE                                                                            -- 审批结束时间｜口径：状态为终态（通过 / 拒绝 / 取消）时的最后更新时间
      WHEN approval_instance_latest.instance_status IN ('APPROVED', 'REJECTED', 'CANCELLED') THEN approval_instance_latest.update_time
  END AS finish_time,                                                             -- 审批结束时间
  ROUND((UNIX_TIMESTAMP(CASE WHEN approval_instance_latest.instance_status IN ('APPROVED', 'REJECTED', 'CANCELLED') THEN approval_instance_latest.update_time END)  -- 审批耗时（分钟）
      - UNIX_TIMESTAMP(approval_instance_latest.create_time)) / 60, 2) AS approval_minute_qty,  -- 审批耗时（分钟）
  CASE                                                                            -- 是否超时｜口径：结束时间（进行中取当前时间）晚于节点截止时间
      WHEN COALESCE(CASE WHEN approval_instance_latest.instance_status IN ('APPROVED', 'REJECTED', 'CANCELLED') THEN approval_instance_latest.update_time END, CURRENT_TIMESTAMP()) > approval_instance_latest.timeout_at THEN 1
      ELSE 0
  END AS timeout_type,                                                            -- 是否超时
  1                                                            AS approval_qty,   -- 审批实例数
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM approval_instance_latest
LEFT JOIN approval_flow_dim                                                       -- 关联「审批流维度」，取 审批流名称
  ON approval_flow_dim.approval_flow_id = approval_instance_latest.flow_id;       -- 按 flow_id→approval_flow_id 关联
