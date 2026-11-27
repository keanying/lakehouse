-- dim.dim_trf_channel_df  渠道/接入端维度
-- 粒度：1行=1个渠道
-- 来源：ods_trf_channel_df + ods_trf_api_key_df
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 16 · 规则翻译 1 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
channel_src AS (                                              -- 主表「接入端/渠道」，只取用到的列
  SELECT channel_code, channel_name, channel_scope, channel_status, channel_type, create_time,
         default_operator_staff_id, id, owner_tenant_id, partner_id, partner_name, update_time,
         valid_from, valid_to
  FROM ods.ods_trf_channel_df
  WHERE travel_date = '${bizdate}'                            -- 只取当日分区
),
api_key_count AS (                                            -- 「API密钥」按 channel_id 预聚合
  SELECT channel_id, COUNT(key_no) AS v                       -- 拆分 / 展开后的单个值
  FROM ods.ods_trf_api_key_df
  WHERE travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY channel_id                                         -- 按粒度键汇总
),
api_key_src AS (                                              -- 「API密钥」当日数据，只取用到的列
  SELECT channel_id, rate_limit_qps
  FROM ods.ods_trf_api_key_df
  WHERE travel_date = '${bizdate}'                            -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_trf_channel_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  channel_src.id                        AS channel_id,        -- 接入端/渠道ID（源表主键 id）
  channel_src.channel_code              AS channel_code,      -- 渠道唯一编码
  channel_src.channel_name              AS channel_name,      -- 渠道展示名
  channel_src.partner_id                AS partner_code,      -- 合作方ID
  channel_src.partner_name              AS partner_name,      -- 合作方名称
  channel_src.channel_type              AS channel_type,      -- 渠道类型
  channel_src.channel_scope             AS channel_scope_type,  -- 渠道作用域
  channel_src.owner_tenant_id           AS owner_tenant_id,   -- 渠道所有者租户ID
  channel_src.default_operator_staff_id AS default_operator_staff_id,  -- 默认操作员ID
  channel_src.channel_status            AS channel_status,    -- 状态
  channel_src.valid_from                AS valid_start_time,  -- 生效开始时间
  channel_src.valid_to                  AS valid_end_time,    -- 生效结束时间
  channel_src.create_time               AS create_time,       -- 创建时间
  channel_src.update_time               AS update_time,       -- 更新时间
  COALESCE(api_key_count.v, 0)          AS api_key_qty,       -- 有效 API-API 接口 Key 数
  api_key_src.rate_limit_qps            AS rate_limit_qps_qty,  -- API-API 接口 限流 QPS-取最大
  CURRENT_TIMESTAMP()                   AS etl_time           -- ETL 加载时间
FROM channel_src
LEFT JOIN api_key_count                                       -- 关联「API密钥」，取 有效 API-API 接口 Key 数
  ON api_key_count.channel_id = channel_src.id                -- 按 id→channel_id 关联
LEFT JOIN api_key_src                                         -- 关联「API密钥」，取 API-API 接口 限流 QPS-取最大
  ON api_key_src.channel_id = channel_src.id;                 -- 按 id→channel_id 关联
