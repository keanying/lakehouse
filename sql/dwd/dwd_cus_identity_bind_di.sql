-- dwd.dwd_cus_identity_bind_di  渠道身份绑定明细
-- 粒度：1行=1条身份绑定
-- 来源：ods_cus_customer_identity_di
-- 生成方式：Spark SQL / Hive；字段 12 个：直接翻译 12 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_cus_identity_bind_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS customer_identity_id,  -- 游客多渠道身份ID（源表主键 id）
  a.customer_id       AS customer_id,           -- 归属 Customer ID
  a.identity_type     AS identity_type,         -- 标识类型
  a.identity_value    AS identity_code,         -- 标识值
  a.bind_channel_id   AS bind_channel_id,       -- 产生该标识的接入端ID
  a.bind_tenant_id    AS bind_tenant_id,        -- 产生该标识的租户ID
  a.identity_status   AS identity_status,       -- 状态
  a.create_time       AS create_time,           -- 创建时间
  a.update_time       AS update_time,           -- 更新时间
  a.create_time       AS bind_time,             -- 绑定时间
  1                   AS bind_qty,              -- 绑定次数
  CURRENT_TIMESTAMP() AS etl_time               -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_cus_customer_identity_di
  WHERE travel_date = '${bizdate}'              -- 只取当日分区
) a                                             -- 主表当日增量，按主键取最新一条
WHERE a.rn = 1                                  -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';             -- 剔除源库已删除的记录
