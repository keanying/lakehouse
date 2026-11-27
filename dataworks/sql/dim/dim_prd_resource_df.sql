-- ================================================================================================
-- dim.dim_prd_resource_df  资源中心资源维度
-- 粒度：1行=1个资源中心上架产品（供应商 × 门票）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_prd_resource_product_df、ods_prd_resource_land_df、ods_prd_resource_land_attr_df、ods_prd_resource_purchase_df、ods_opr_province_df、ods_opr_resource_center_district_df
-- 替代旧任务 7 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_资源中心/dim_resource_center_prod_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_资源中心/dim_resource_center_purchase_d_f（SERVERLESS_SPARK_SQL，cron 00 00 02 * * ?）
--   · 数据中台/数据维度(DIM)/dim_资源中心/dim_resource_center_user_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_资源域/dim_resource_type_d_f（EMR_SPARK_SQL，cron 00 20 00 * * ?）
--   · 业务工厂/内部信息/财务部/资源中心考核2/dim_res_resource_center_district_2022_d_f（DI，cron 00 00 05 * * ?）
--   · 数据中台/同步任务/MySQL_to_Hive/同步_资源中心/s_dim_resource_center_district_d_f（DI，cron 00 12 00 * * ?）
--   · 业务工厂/内部信息/财务部/资源中心考核2/dws_res_resource_center_land_attr_detail_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 考核区域：景区所在省（省编码 → 省名）对资源中心区域配置表；采购数：采购关系中状态为已采购的分销商去重
--   · 旧表的采购链路有效期、自动采购等列来自旧中间表的采购关系，已在 dwd_prd_resource_purchase_di（采购明细）中提供，维度不再重复
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_prd_resource_df                                    -- 整表覆盖写入
SELECT
    CAST(id AS BIGINT)                                           AS resource_id,  -- 资源ID（资源中心上架记录）
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(pid AS BIGINT)                                          AS product_id,   -- 产品ID
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,    -- 票ID
    ticket_name,                                                                  -- 门票名称
    CAST(lid AS BIGINT)                                          AS scenic_id,    -- 景区ID
    land_name                                                    AS scenic_name,  -- 景区名称（资源中心景区）
    land_level                                                   AS scenic_level,  -- 景区等级
    p_type                                                       AS scenic_type_code,  -- 景区类型
    CAST(land_province_code AS STRING)                           AS province_code,  -- 景区所在省编码
    province_name,                                                                -- 景区所在省
    CAST(land_city_code AS STRING)                               AS city_code,    -- 景区所在市编码
    district                                                     AS belong_area,  -- 资源中心考核区域（按景区所在省）
    CAST(import_province AS INT)                                 AS import_province_flag,  -- 是否重点关注省
    CAST(resource_type AS INT)                                   AS resource_type,  -- 资源选项
    CAST(price_spread AS DECIMAL(18,2)) / 100                    AS price_spread_amt,  -- 分销差价（元）
    shop                                                         AS sale_channel,  -- 销售渠道
    CAST(ddays AS INT)                                           AS advance_day_qty,  -- 提前下单天数
    CAST(refund_rule AS INT)                                     AS refund_rule,  -- 退票规则
    CAST(billing_state AS INT)                                   AS billing_state,  -- 开票状态
    CAST(status AS INT)                                          AS resource_status,  -- 是否仍在资源中心分销
    CAST(platform_status AS INT)                                 AS platform_status,  -- 平台状态
    max_expiration_date,                                                          -- 门票最大有效日期
    COALESCE(purchase_member_qty, 0)                             AS purchase_member_qty,  -- 已采购的分销商数（采购状态 = 已采购）
    CAST(scenic_sales AS BIGINT)                                 AS scenic_sales_qty,  -- 景区累计销量（资源中心统计）
    CAST(scenic_purchase_num AS BIGINT)                          AS scenic_purchase_qty,  -- 景区被采购数（资源中心统计）
    CAST(opid AS BIGINT)                                         AS operator_id,  -- 最后操作员ID
    FROM_UNIXTIME(add_time)                                      AS add_time,     -- 上架时间
    FROM_UNIXTIME(update_time)                                   AS update_time,  -- 最后更新时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT r.*,
               l.land_name,
               l.land_level,
               l.p_type,
               l.province_code AS land_province_code,
               l.city_code AS land_city_code,
               pv.province_name,                                                  -- 景区所在省
               d.district,
               d.import_province,
               la.resource_type,                                                  -- 资源选项
               la.sales AS scenic_sales,
               la.purchase_num AS scenic_purchase_num,
               pc.purchase_member_qty                                             -- 已采购的分销商数（采购状态 = 已采购）
        FROM ods.ods_prd_resource_product_df r
        LEFT JOIN ods.ods_prd_resource_land_df l                                  -- 关联「资源中心景区产品表」｜资源中心景区
          ON l.sid = r.sid AND l.lid = r.lid AND l.travel_date = '${bizdate}'     -- 按 sid、lid 关联
        LEFT JOIN ods.ods_prd_resource_land_attr_df la                            -- 关联「资源景区属性」｜景区统计属性
          ON la.sid = r.sid AND la.lid = r.lid AND la.travel_date = '${bizdate}'  -- 按 sid、lid 关联
        LEFT JOIN ods.ods_opr_province_df pv                                      -- 关联「dim省（待确认）」｜省编码 → 省名
          ON pv.province_code = l.province_code AND pv.travel_date = '${bizdate}'  -- 按 province_code 关联
        LEFT JOIN ods.ods_opr_resource_center_district_df d                       -- 关联「资源中心区县」｜省 → 考核区域
          ON d.province = pv.province_name AND d.travel_date = '${bizdate}'       -- 按 province_name→province 关联
        LEFT JOIN (SELECT sid, ticket_id, COUNT(DISTINCT fid) AS purchase_member_qty FROM ods.ods_prd_resource_purchase_df
                   WHERE travel_date = '${bizdate}'                               -- 只取当日分区
                     AND status = 1 GROUP BY sid,
                     ticket_id) pc ON pc.sid = r.sid AND pc.ticket_id = r.ticket_id
        WHERE r.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
