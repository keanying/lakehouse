-- dwd.dwd_fin_invoice_di  发票明细
-- 粒度：1行=1个发票单（invoice_no）
-- 来源：ods_fin_invoice_order_di
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 17 · 规则翻译 0 · 待确认 0
-- 主表增量先去重再关联；每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
invoice_order_rn AS (                                                           -- 「发票单」当日增量，同一主键按 binlog 时间倒序编号
  SELECT approval_no, create_time, fee_item, id, invoice_amount, invoice_config_id, invoice_file_url,
         invoice_no, invoice_status, invoice_subject, invoice_type, order_group_no, tenant_id,
         update_time, binlog_op_type,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn    -- 去重序号（1 = 最新）
  FROM ods.ods_fin_invoice_order_di
  WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
),
invoice_order_latest AS (                                                       -- 「发票单」每个主键只保留最新一条，剔除已删除记录
  SELECT approval_no, create_time, fee_item, id, invoice_amount, invoice_config_id, invoice_file_url,
         invoice_no, invoice_status, invoice_subject, invoice_type, order_group_no, tenant_id,
         update_time                                                            -- 更新时间
  FROM invoice_order_rn
  WHERE rn = 1
    AND binlog_op_type <> 'DELETE'                                              -- 剔除源库已删除的记录
),
invoice_config_dim AS (                                                         -- 「发票配置维度」当日数据，只取用到的列
  SELECT invoice_config_id, invoice_provider_code
  FROM dim.dim_fin_invoice_config_df
  WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_fin_invoice_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(invoice_config_dim) */
  invoice_order_latest.id                             AS invoice_id,            -- 发票单ID（源表主键 id）
  invoice_order_latest.invoice_no                     AS invoice_no,            -- 发票单号
  invoice_order_latest.tenant_id                      AS tenant_id,             -- 开票商户ID
  invoice_order_latest.invoice_type                   AS invoice_type,          -- 发票类型
  invoice_order_latest.invoice_subject                AS invoice_subject_type,  -- 开票主体
  invoice_order_latest.order_group_no                 AS order_group_no,        -- 关联订单号（商户给游客开票）
  invoice_order_latest.fee_item                       AS fee_item_code,         -- 费用项（平台给商户开票时）
  ROUND(invoice_order_latest.invoice_amount / 100, 2) AS invoice_amt,           -- 开票金额（元）
  invoice_order_latest.invoice_config_id              AS invoice_config_id,     -- 发票配置ID
  invoice_order_latest.invoice_status                 AS invoice_status,        -- 状态
  invoice_order_latest.invoice_file_url               AS invoice_file_url_desc,  -- 发票文件URL-开票成功后存OSS
  invoice_order_latest.approval_no                    AS approval_no,           -- 审批实例号
  invoice_order_latest.create_time                    AS create_time,           -- 创建时间
  invoice_order_latest.update_time                    AS update_time,           -- 更新时间
  invoice_config_dim.invoice_provider_code            AS invoice_provider_code,  -- 开票服务商
  invoice_order_latest.create_time                    AS apply_time,            -- 开票申请时间
  CURRENT_TIMESTAMP()                                 AS etl_time               -- ETL 加载时间
FROM invoice_order_latest
LEFT JOIN invoice_config_dim                                                    -- 关联「发票配置维度」，取 开票服务商
  ON invoice_config_dim.invoice_config_id = invoice_order_latest.invoice_config_id;  -- 按 invoice_config_id 关联
