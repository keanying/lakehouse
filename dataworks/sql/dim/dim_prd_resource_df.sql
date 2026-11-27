-- ================================================================================================
-- dim.dim_prd_resource_df  资源中心资源维度
-- 粒度：1行=1个资源中心资源（景区 / 产品）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_prd_resource_land_df、ods_prd_resource_product_df、ods_opr_resource_center_district_df
-- 替代旧任务 7 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_资源中心/dim_resource_center_prod_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_资源中心/dim_resource_center_purchase_d_f（SERVERLESS_SPARK_SQL，cron 00 00 02 * * ?）
--   · 数据中台/数据维度(DIM)/dim_资源中心/dim_resource_center_user_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_资源域/dim_resource_type_d_f（EMR_SPARK_SQL，cron 00 20 00 * * ?）
--   · 业务工厂/内部信息/财务部/资源中心考核2/dim_res_resource_center_district_2022_d_f（DI，cron 00 00 05 * * ?）
--   · 数据中台/同步任务/MySQL_to_Hive/同步_资源中心/s_dim_resource_center_district_d_f（DI，cron 00 12 00 * * ?）
--   · 业务工厂/内部信息/财务部/资源中心考核2/dws_res_resource_center_land_attr_detail_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 过渡期从旧表 dim_resource_center_purchase_d_f 平移：旧逻辑由多张中间表 / 外部采集加工，字段与 ODS 不能直接对应；字段口径按字典，上线顺序：先平移保证下游可切换，再按字段清单把「待确认」逐个改为从 ODS 计算后下线旧链路
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_prd_resource_df                                    -- 整表覆盖写入
SELECT
    CAST(NULL AS BIGINT)                                         AS resource_id,  -- 资源ID｜待确认：来源未同步
    supply_user_id,                                                               -- 供应商id
    purchase_user_id,                                                             -- 采购商id
    ticket_id,                                                                    -- 票ID
    ticket_fullname                                              AS ticket_name,  -- 票全称
    CAST(pid AS BIGINT)                                          AS product_id,   -- 产品ID
    purchase_time,                                                                -- 产品被采购时间
    add_time,                                                                     -- 产品首次上架资源中心时间
    max_add_time,                                                                 -- 产品最新上架资源中心时间
    resource_update_time,                                                         -- 资源中心产品更新时间
    off_time,                                                                     -- 产品下架时间
    CAST(opid AS BIGINT)                                         AS operator_id,  -- 操作员id
    price_state,                                                                  -- 采购价格是否相同
    CAST(land_id AS BIGINT)                                      AS scenic_id,    -- 景区ID
    land_name                                                    AS scenic_name,  -- 景区名称
    land_province                                                AS scenic_province_name,  -- 景区省
    land_city                                                    AS scenic_city_name,  -- 景区市
    land_type_name                                               AS scenic_type_name,  -- 景区/产品类型
    CAST(apply_did AS BIGINT)                                    AS origin_supplier_id,  -- 原始（顶级）供应商ID（租户ID）
    CAST(purchase_distribute_num AS BIGINT)                      AS purchase_distribute_qty,  -- 采购者将产品分销下级数
    CAST(purchase_ota_num AS BIGINT)                             AS purchase_ota_qty,  -- 采购者将产品上架OTA数
    ticket_max_expiration_date,                                                   -- 产品过期时间
    resource_product_status,                                                      -- 资源中心产品状态
    product_status,                                                               -- 产品状态
    purchace_status,                                                              -- 采购状态
    is_auto_purchace,                                                             -- 是否自动采购
    ticket_validity,                                                              -- 门票有效期
    purchase_chain_validity,                                                      -- 票采购链有效性
    supply_type,                                                                  -- 资源中心供应类型
    CAST(NULL AS STRING)                                         AS stat_date,    -- 统计日期｜待确认：来源未同步（旧字段 dim_resource_center_user_d_f.stat_date）
    CAST(NULL AS STRING)                                         AS resource_type,  -- 直签/第三方｜待确认：来源未同步（旧字段 dim_resource_type_d_f.resource_type）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM dim_resource_center_purchase_d_f
WHERE pt = ${bizdate}                                                             -- 过渡期：读旧表，按字段清单逐步改为从 ODS 计算
