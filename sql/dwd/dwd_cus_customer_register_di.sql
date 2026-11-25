-- dwd.dwd_cus_customer_register_di  游客注册明细
-- 粒度：1行=1个新注册游客
-- 来源：ods_cus_customer_di
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 14 · 规则翻译 0 · 待确认 1
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_cus_customer_register_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                 AS customer_id,          -- C端游客主账号ID（源表主键 id）
  a.customer_no        AS customer_no,          -- 客户编号
  a.customer_kind      AS customer_type,        -- 账号类型
  a.gender             AS gender_type,          -- 性别
  a.auth_status        AS auth_status,          -- 认证状态
  a.customer_status    AS customer_status,      -- 状态
  a.register_source    AS register_source_code,  -- 注册来源渠道编码
  a.register_tenant_id AS register_tenant_id,   -- 所属租户ID
  a.create_time        AS create_time,          -- 创建时间
  a.update_time        AS update_time,          -- 更新时间
  j1.channel_id        AS register_channel_id,  -- 注册渠道ID
  a.birthday           AS age_band_code,        -- 注册时年龄段｜待确认：ods_cus_customer_di.birthday 计算
  a.create_time        AS register_time,        -- 注册时间
  1                    AS register_qty,         -- 注册人数
  CURRENT_TIMESTAMP()  AS etl_time              -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_cus_customer_di
  WHERE travel_date = '${bizdate}'              -- 只取当日分区
) a                                             -- 主表当日增量，按主键取最新一条
LEFT JOIN dim.dim_trf_channel_df j1             -- 关联「渠道/接入端维度」，取 注册渠道ID
  ON j1.channel_code = a.register_source        -- 按 register_source→channel_code 关联
 AND j1.travel_date = '${bizdate}'              -- 只取当日分区
WHERE a.rn = 1                                  -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';             -- 剔除源库已删除的记录
