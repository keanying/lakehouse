-- dwd.dwd_opr_approval_di  审批实例明细
-- 粒度：1行=1个审批实例
-- 来源：ods_opr_approval_instance_di
-- 生成方式：Spark SQL / Hive；字段 20 个：直接翻译 17 · 规则翻译 1 · 待确认 2
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_opr_approval_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                  AS instance_id,      -- 审批实例ID（源表主键 id）
  a.instance_no                         AS instance_no,      -- 审批实例号
  a.flow_id                             AS flow_id,          -- 审批流ID
  a.flow_code                           AS flow_code,        -- 审批流标识码（冗余
  a.business_no                         AS business_no,      -- 关联业务号（退款单号/提现单号等）
  a.applicant_id                        AS applicant_id,     -- 申请人ID
  a.applicant_name                      AS applicant_name,   -- 申请人姓名（快照
  a.current_node                        AS current_node_name,  -- 当前审批节点名称
  a.timeout_at                          AS timeout_time,     -- 当前节点审批截止时间
  a.instance_status                     AS instance_status,  -- 状态
  a.tenant_id                           AS tenant_id,        -- 租户ID
  a.create_time                         AS create_time,      -- 创建时间
  a.update_time                         AS update_time,      -- 更新时间
  j1.flow_name                          AS flow_name,        -- 审批流名称
  a.create_time                         AS apply_time,       -- 发起时间
  a.instance_status                     AS finish_time,      -- 审批结束时间｜待确认：ods_opr_approval_instance_di.instance_status 终态的 binlog_time
  (a.instance_status) - (a.create_time) AS approval_minute_qty,  -- 审批耗时（分钟）
  NULL                                  AS timeout_type,     -- 是否超时｜待确认：finish_time 晚于 timeout_at 或进行中已超时
  1                                     AS approval_qty,     -- 审批实例数
  CURRENT_TIMESTAMP()                   AS etl_time          -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_opr_approval_instance_di
  WHERE travel_date = '${bizdate}'                           -- 只取当日分区
) a                                                          -- 主表当日增量，按主键取最新一条
LEFT JOIN dim.dim_opr_approval_flow_df j1                    -- 关联「审批流维度」，取 审批流名称
  ON j1.approval_flow_id = a.flow_id                         -- 按 flow_id→approval_flow_id 关联
 AND j1.travel_date = '${bizdate}'                           -- 只取当日分区
WHERE a.rn = 1                                               -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                          -- 剔除源库已删除的记录
