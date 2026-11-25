-- dim.dim_trf_channel_tenant_df  渠道-租户绑定维度
-- 粒度：1行=1条绑定
-- 来源：ods_trf_channel_tenant_binding_df
-- 生成方式：Spark SQL / Hive；字段 15 个：直接翻译 15 · 规则翻译 0 · 待确认 0

INSERT OVERWRITE TABLE dim.dim_trf_channel_tenant_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                AS channel_tenant_binding_id,  -- 渠道-租户绑定ID（源表主键 id）
  a.binding_no        AS binding_no,          -- 绑定编号
  a.channel_id        AS channel_id,          -- 渠道ID
  a.tenant_id         AS tenant_id,           -- 租户ID（FK→t_tenant.id
  a.partner_id        AS partner_code,        -- 合作方ID（冗余便于查询
  a.ota_merchant_id   AS ota_merchant_code,   -- OTA侧商户ID
  a.ota_sub_channel   AS ota_sub_channel_code,  -- OTA子渠道枚举（可选
  a.binding_status    AS binding_status,      -- 绑定状态
  a.valid_from        AS valid_start_time,    -- 生效开始时间
  a.valid_to          AS valid_end_time,      -- 生效结束时间
  a.create_time       AS create_time,         -- 创建时间
  a.update_time       AS update_time,         -- 更新时间
  j1.channel_code     AS channel_code,        -- 渠道编码
  j1.channel_type     AS channel_type,        -- 渠道类型
  CURRENT_TIMESTAMP() AS etl_time             -- ETL 加载时间
FROM ods.ods_trf_channel_tenant_binding_df a  -- 主表「渠道-租户绑定」
LEFT JOIN dim.dim_trf_channel_df j1           -- 关联「渠道/接入端维度」，取 渠道编码、渠道类型
  ON j1.channel_id = a.channel_id             -- 按 channel_id 关联
 AND j1.travel_date = '${bizdate}'            -- 只取当日分区
WHERE a.travel_date = '${bizdate}';           -- 只取当日分区
