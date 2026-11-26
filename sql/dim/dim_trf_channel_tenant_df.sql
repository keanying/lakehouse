-- dim.dim_trf_channel_tenant_df  渠道-租户绑定维度
-- 粒度：1行=1条绑定
-- 来源：ods_trf_channel_tenant_binding_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区；小维表广播关联

WITH
channel_tenant_binding_src AS (                                       -- 主表「渠道-租户绑定」，只取用到的列
  SELECT binding_no, binding_status, channel_id, create_time, id, ota_merchant_id, ota_sub_channel,
         partner_id, tenant_id, update_time, valid_from, valid_to
  FROM ods.ods_trf_channel_tenant_binding_df
  WHERE travel_date = '${bizdate}'                                    -- 只取当日分区
),
channel_dim AS (                                                      -- 「渠道/接入端维度」当日数据，只取用到的列
  SELECT channel_code, channel_id, channel_type
  FROM dim.dim_trf_channel_df
  WHERE travel_date = '${bizdate}'                                    -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_trf_channel_tenant_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(channel_dim) */
  channel_tenant_binding_src.id              AS channel_tenant_binding_id,  -- 渠道-租户绑定ID（源表主键 id）
  channel_tenant_binding_src.binding_no      AS binding_no,           -- 绑定编号
  channel_tenant_binding_src.channel_id      AS channel_id,           -- 渠道ID
  channel_tenant_binding_src.tenant_id       AS tenant_id,            -- 租户ID（FK→t_tenant.id
  channel_tenant_binding_src.partner_id      AS partner_code,         -- 合作方ID（冗余便于查询
  channel_tenant_binding_src.ota_merchant_id AS ota_merchant_code,    -- OTA侧商户ID
  channel_tenant_binding_src.ota_sub_channel AS ota_sub_channel_code,  -- OTA子渠道枚举（可选
  channel_tenant_binding_src.binding_status  AS binding_status,       -- 绑定状态
  channel_tenant_binding_src.valid_from      AS valid_start_time,     -- 生效开始时间
  channel_tenant_binding_src.valid_to        AS valid_end_time,       -- 生效结束时间
  channel_tenant_binding_src.create_time     AS create_time,          -- 创建时间
  channel_tenant_binding_src.update_time     AS update_time,          -- 更新时间
  channel_dim.channel_code                   AS channel_code,         -- 渠道编码
  channel_dim.channel_type                   AS channel_type,         -- 渠道类型
  CURRENT_TIMESTAMP()                        AS etl_time              -- ETL 加载时间
FROM channel_tenant_binding_src
LEFT JOIN channel_dim                                                 -- 关联「渠道/接入端维度」，取 渠道编码、渠道类型
  ON channel_dim.channel_id = channel_tenant_binding_src.channel_id;  -- 按 channel_id 关联
