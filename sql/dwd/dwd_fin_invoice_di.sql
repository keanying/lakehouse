-- dwd.dwd_fin_invoice_di  发票明细
-- 粒度：1行=1个发票单（invoice_no）
-- 来源：ods_fin_invoice_order_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_fin_invoice_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                             AS invoice_id,             -- 发票单ID（源表主键 id）
  a.invoice_no                     AS invoice_no,             -- 发票单号
  a.tenant_id                      AS tenant_id,              -- 开票商户ID
  a.invoice_type                   AS invoice_type,           -- 发票类型
  a.invoice_subject                AS invoice_subject_type,   -- 开票主体
  a.order_group_no                 AS order_group_no,         -- 关联订单号（商户给游客开票）
  a.fee_item                       AS fee_item_code,          -- 费用项（平台给商户开票时）
  ROUND(a.invoice_amount / 100, 2) AS invoice_amt,            -- 开票金额（元）
  a.invoice_config_id              AS invoice_config_id,      -- 发票配置ID
  a.invoice_status                 AS invoice_status,         -- 状态
  a.invoice_file_url               AS invoice_file_url_desc,  -- 发票文件URL-开票成功后存OSS
  a.approval_no                    AS approval_no,            -- 审批实例号
  a.create_time                    AS create_time,            -- 创建时间
  a.update_time                    AS update_time,            -- 更新时间
  j1.invoice_provider_code         AS invoice_provider_code,  -- 开票服务商
  a.create_time                    AS apply_time,             -- 开票申请时间
  CURRENT_TIMESTAMP()              AS etl_time                -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_fin_invoice_order_di
  WHERE travel_date = '${bizdate}'                            -- 只取当日分区
) a                                                           -- 主表当日增量，按主键取最新一条
LEFT JOIN dim.dim_fin_invoice_config_df j1                    -- 关联「发票配置维度」，取 开票服务商
  ON j1.invoice_config_id = a.invoice_config_id               -- 按 invoice_config_id 关联
 AND j1.travel_date = '${bizdate}'                            -- 只取当日分区
WHERE a.rn = 1                                                -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                           -- 剔除源库已删除的记录
