-- dwd.dwd_cus_customer_register_rt  实时游客注册
-- 粒度：1行=1个新注册游客
-- 来源：ods_cus_customer_rt
-- 生成方式：Flink SQL（CDC 源表 → StarRocks 主键模型表；维表 Lookup Join）；字段 15 个：直接翻译 14 · 规则翻译 1 · 待确认 0
-- 源表 ods.*_rt 为 Flink CDC 表（含 proc_time AS PROCTIME()），目标表在 StarRocks catalog 中

INSERT INTO dwd.dwd_cus_customer_register_rt                      -- 写入 StarRocks 目标表
SELECT
  DATE_FORMAT(a.create_time, 'yyyyMMdd') AS travel_date,          -- 数据日期
  a.id                                   AS customer_id,          -- C端游客主账号ID（源表主键 id）
  a.customer_no                          AS customer_no,          -- 客户编号
  a.customer_kind                        AS customer_type,        -- 账号类型
  a.gender                               AS gender_type,          -- 性别
  a.auth_status                          AS auth_status,          -- 认证状态
  a.customer_status                      AS customer_status,      -- 状态
  a.register_source                      AS register_source_code,  -- 注册来源渠道编码
  a.register_tenant_id                   AS register_tenant_id,   -- 所属租户ID
  a.create_time                          AS create_time,          -- 创建时间
  a.update_time                          AS update_time,          -- 更新时间
  j1.channel_id                          AS register_channel_id,  -- 注册渠道ID
  a.create_time                          AS register_time,        -- 注册时间
  1                                      AS register_qty,         -- 注册人数
  CURRENT_TIMESTAMP                      AS event_time            -- 事件时间（binlog 时间）
FROM ods.ods_cus_customer_rt a                                    -- 主表「游客账号 binlog 流」
LEFT JOIN dim.dim_trf_channel_df FOR SYSTEM_TIME AS OF a.proc_time AS j1  -- 关联「渠道/接入端维度」，取 注册渠道ID
  ON j1.channel_code = a.register_source;                         -- 按 register_source→channel_code 关联
