-- dwd.dwd_cus_credential_register_di  个人凭证注册明细
-- 粒度：1行=1条个人凭证
-- 来源：ods_cus_customer_credential_di
-- 生成方式：Spark SQL / Hive；字段 10 个：直接翻译 10 · 规则翻译 0 · 待确认 0
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录

INSERT OVERWRITE TABLE dwd.dwd_cus_credential_register_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                 AS customer_credential_id,  -- 游客个人凭证ID（源表主键 id）
  a.credential_no      AS credential_no,           -- 凭证编号
  a.customer_id        AS customer_id,             -- 归属 Customer ID
  a.register_tenant_id AS register_tenant_id,      -- 注册租户ID
  a.credential_type    AS credential_type,         -- 凭证类型
  a.create_time        AS create_time,             -- 创建时间
  a.update_time        AS update_time,             -- 更新时间
  a.create_time        AS register_time,           -- 凭证注册时间
  1                    AS register_qty,            -- 注册凭证数
  CURRENT_TIMESTAMP()  AS etl_time                 -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_cus_customer_credential_di
  WHERE travel_date = '${bizdate}'                 -- 只取当日分区
) a                                                -- 主表当日增量，按主键取最新一条
WHERE a.rn = 1                                     -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                -- 剔除源库已删除的记录
