-- ================================================================================================
-- dim.dim_prd_scenic_df  景区维度
-- 粒度：1行=1个景区（lid）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_prd_scenic_df、ods_prd_management_resource_df、ods_prd_management_land_df、ods_opr_resource_center_district_df、dim_opr_region_f、dim_opr_dict_f、dim_sup_member_df
-- 替代旧任务 5 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_商品域/dim_land_d_f（EMR_SPARK_SQL，cron 00 00 01 * * ?）
--   · 数据平台/DIM/dim_attr_scenic_info_df（SERVERLESS_SPARK_SQL，cron 00 23 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_其他/dim_land_topic_d_f（EMR_SPARK_SQL，cron 00 25 00 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dim_prd_ticket_scenic_composite_df（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_资源域/dim_resource_land_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
-- 业务规则 / 修正：
--   · 替代 dim_land_d_f、dim_attr_scenic_info_df 等 5 张
--   · 修正：业态景区名称被 CAST 成 INT（恒为空）；测试景区把 is_test_user=0 当测试；地区名两套城市表各取一半
-- 性能：
--   · 地区、码表、业态映射均为小表，BROADCAST
--   · 业态映射多版本取最新一条，先去重再关联，避免景区行放大
-- ================================================================================================
WITH land AS (
    SELECT CAST(id AS BIGINT) AS scenic_id,                                       -- 景区ID
           title,
           status,
           CAST(apply_did AS BIGINT) AS supplier_id,                              -- 供应商ID（租户ID）
           p_type,
           jtype,
           topic,
           SPLIT(area, '\\|')                                     AS area_parts,  -- 省|市|区县
           address, lng_lat_pos, oversea, reception_ability, resourceid, addtime
    FROM ods.ods_prd_scenic_df
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
),
resource_map AS (                                                                 -- 景区 → 业态景区：同一景区多次映射取最新
    SELECT land_id, mt_id
    FROM (
        SELECT CAST(land_id AS BIGINT) AS land_id,                                -- 景区id
               CAST(mt_id AS BIGINT) AS mt_id,                                    -- 业态ID
               ROW_NUMBER() OVER (PARTITION BY land_id ORDER BY CAST(id AS BIGINT) DESC) AS rn  -- 去重序号（1 = 最新）
        FROM ods.ods_prd_management_resource_df
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
    WHERE rn = 1
),
resource_land AS (SELECT CAST(id AS BIGINT) AS mt_id, title
    FROM ods.ods_prd_management_land_df WHERE travel_date = '${bizdate}' AND COALESCE(is_del, '0') = '0'),
region AS (SELECT region_code, region_name FROM dim.dim_opr_region_f),
area_belong AS (SELECT province, MAX(district) AS district                        -- 区域
    FROM ods.ods_opr_resource_center_district_df WHERE travel_date = '${bizdate}' GROUP BY province),
dict AS (
    SELECT dict_type,
    dict_code,
    dict_name FROM dim.dim_opr_dict_f WHERE dict_type IN ('scenic_type', 'scenic_topic')
)
INSERT OVERWRITE TABLE dim.dim_prd_scenic_df                                      -- 整表覆盖写入
SELECT /*+ BROADCAST(rl, rp, rc, rd, ab, dt, dp, mb) */
    l.scenic_id,                                                                  -- 景区ID
    l.title                                                          AS scenic_name,  -- 景区名称
    l.status                                                         AS scenic_status,  -- 景区状态
    l.supplier_id,                                                                -- 供应商ID（租户ID）
    l.p_type                                                         AS scenic_type_code,  -- 景区类型编码
    dt.dict_name                                                     AS scenic_type_name,  -- 景区类型名称
    l.jtype                                                          AS scenic_level,  -- 景区等级
    COALESCE(dp.dict_name, SPLIT(l.topic, ',')[0])                   AS scenic_topic,  -- 主题（主题列表第一个）｜多主题取第一个
    l.topic                                                          AS scenic_topic_list,  -- 全部主题
    l.area_parts[0]                                                  AS province_code,  -- 所在省编码
    rp.region_name                                                   AS province_name,  -- 所在省
    l.area_parts[1]                                                  AS city_code,  -- 所在市编码
    rc.region_name                                                   AS city_name,  -- 所在市
    l.area_parts[2]                                                  AS district_code,  -- 所在区县编码
    rd.region_name                                                   AS district_name,  -- 所在区县
    ab.district                                                      AS belong_area,  -- 归属大区（资源中心考核区域）｜大区（华东 / 华南 …）
    l.address,                                                                    -- 详细地址
    CAST(SPLIT(l.lng_lat_pos, ',')[0] AS DECIMAL(10,6))              AS longitude,  -- 经度
    CAST(SPLIT(l.lng_lat_pos, ',')[1] AS DECIMAL(10,6))              AS latitude,  -- 纬度
    CAST(l.oversea AS INT)                                           AS oversea_flag,  -- 是否境外
    CAST(l.reception_ability AS BIGINT)                              AS reception_capacity_qty,  -- 最大承载量（人）
    CAST(l.resourceid AS BIGINT)                                     AS resource_id,  -- 资源中心资源ID
    rm.mt_id                                                         AS resource_scenic_id,  -- 业态景区ID
    rl.title                                                         AS resource_scenic_name,  -- 业态景区名称｜旧逻辑 CAST(title AS INT) 恒为空，已修正
    l.addtime                                                        AS create_time,  -- 景区创建时间
    IF(l.title LIKE '%测试%' OR l.title LIKE '%压测%' OR mb.test_flag = 1, 1, 0) AS test_flag,  -- 是否测试景区
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM land l
LEFT JOIN resource_map rm ON rm.land_id = l.scenic_id
LEFT JOIN resource_land rl ON rl.mt_id = rm.mt_id
LEFT JOIN region rp ON rp.region_code = l.area_parts[0]
LEFT JOIN region rc ON rc.region_code = l.area_parts[1]
LEFT JOIN region rd ON rd.region_code = l.area_parts[2]
LEFT JOIN area_belong ab ON ab.province = rp.region_name
LEFT JOIN dict dt ON dt.dict_type = 'scenic_type' AND dt.dict_code = l.p_type
LEFT JOIN dict dp ON dp.dict_type = 'scenic_topic' AND dp.dict_code = SPLIT(l.topic, ',')[0]
LEFT JOIN (SELECT member_id, test_flag FROM dim.dim_sup_member_df) mb ON mb.member_id = l.supplier_id
