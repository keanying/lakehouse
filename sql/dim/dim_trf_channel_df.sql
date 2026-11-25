-- dim.dim_trf_channel_df  渠道/接入端维度
-- 粒度：1行=1个渠道
-- 来源：ods_trf_channel_df + ods_trf_api_key_df
-- 生成方式：Spark SQL / Hive；字段 17 个：直接翻译 16 · 规则翻译 1 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_trf_channel_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                        AS channel_id,          -- 接入端/渠道ID（源表主键 id）
  a.channel_code              AS channel_code,        -- 渠道唯一编码
  a.channel_name              AS channel_name,        -- 渠道展示名
  a.partner_id                AS partner_code,        -- 合作方ID（Partner 统一抽象
  a.partner_name              AS partner_name,        -- 合作方名称（冗余展示用
  a.channel_type              AS channel_type,        -- 渠道类型
  a.channel_scope             AS channel_scope_type,  -- 渠道作用域
  a.owner_tenant_id           AS owner_tenant_id,     -- 渠道所有者租户ID
  a.default_operator_staff_id AS default_operator_staff_id,  -- 默认操作员ID
  a.channel_status            AS channel_status,      -- 状态
  a.valid_from                AS valid_start_time,    -- 生效开始时间
  a.valid_to                  AS valid_end_time,      -- 生效结束时间
  a.create_time               AS create_time,         -- 创建时间
  a.update_time               AS update_time,         -- 更新时间
  COALESCE(j1.v, 0)           AS api_key_qty,         -- 有效 API-API 接口 Key 数
  j2.rate_limit_qps           AS rate_limit_qps_qty,  -- API-API 接口 限流 QPS-取最大
  CURRENT_TIMESTAMP()         AS etl_time             -- ETL 加载时间
FROM ods.ods_trf_channel_df a                         -- 主表「接入端/渠道」
LEFT JOIN (SELECT channel_id, COUNT(key_no) AS v FROM ods.ods_trf_api_key_df WHERE travel_date = '${bizdate}' GROUP BY channel_id) j1  -- 关联「API密钥」按键聚合，得到 有效 API-API 接口 Key 数
  ON j1.channel_id = a.id                             -- 按 id→channel_id 关联
LEFT JOIN ods.ods_trf_api_key_df j2                   -- 关联「API密钥」，取 API-API 接口 限流 QPS-取最大
  ON j2.channel_id = a.id                             -- 按 id→channel_id 关联
 AND j2.travel_date = '${bizdate}'                    -- 只取当日分区
WHERE a.travel_date = '${bizdate}';                   -- 只取当日分区
