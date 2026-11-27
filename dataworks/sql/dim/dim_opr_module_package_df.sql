-- ================================================================================================
-- dim.dim_opr_module_package_df  应用模块与套餐维度
-- 粒度：1行=1个套餐×1个包含模块（单独售卖的模块 package_id = 0）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_module_df、ods_opr_module_package_df、ods_opr_module_package_detail_df、ods_opr_module_package_classify_df、ods_opr_module_price_df
-- 替代旧任务 3 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_其他/dim_pft_module_package_classify_d_f（EMR_SPARK_SQL，cron 00 27 00 * * ?）
--   · 业务工厂/内部信息/财务部/客户属性cus_company/pft001_to_dim_prod_pft_module_package_detail_d_f（DI，cron 00 00 06 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dim_prd_module_price_df（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 资费按 资费配置（module_price）当日生效版本取：开始时间 ≤ 统计日、结束时间为 0 或 ≥ 统计日，同一目标取排序值最高的一条
--   · 套餐分类表 package_ids 为逗号分隔的套餐列表，拆行后按套餐关联
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_opr_module_package_df                              -- 整表覆盖写入
SELECT
    CAST(package_id AS BIGINT)                                   AS package_id,   -- 套餐ID
    CAST(module_id AS BIGINT)                                    AS module_id,    -- 模块ID
    module_name,                                                                  -- 模块名称
    CAST(category AS INT)                                        AS module_category,  -- 模块分类
    CAST(module_status AS INT)                                   AS module_status,  -- 模块状态
    CAST(free_day AS INT)                                        AS module_free_day_qty,  -- 模块免费天数（0 = 不免费）
    IF(online_time > 0, FROM_UNIXTIME(online_time), NULL)        AS module_online_time,  -- 模块上线时间
    CAST(module_fee AS DECIMAL(18,2)) / 100                      AS module_price_amt,  -- 模块当前资费
    package_name,                                                                 -- 套餐名称
    CAST(role AS INT)                                            AS package_role,  -- 套餐适用角色
    CAST(package_list_fee AS DECIMAL(18,2)) / 100                AS package_fee_amt,  -- 套餐标价（元）
    CAST(unit AS INT)                                            AS package_month_qty,  -- 套餐时长（月）
    CAST(package_status AS INT)                                  AS package_status,  -- 套餐状态
    CAST(package_fee AS DECIMAL(18,2)) / 100                     AS package_price_amt,  -- 套餐当前资费
    classify_name                                                AS package_classify_name,  -- 套餐分类名称
    CAST(classify_op_id AS BIGINT)                               AS operator_id,  -- 套餐分类最后操作人
    IF(classify_update_time > 0, FROM_UNIXTIME(classify_update_time), NULL) AS operate_time,  -- 套餐分类最后更新时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT x.package_id,                                                      -- 套餐ID
               x.module_id,                                                       -- 模块ID
               m.name AS module_name,                                             -- 模块名称
               m.category,
               m.status AS module_status,                                         -- 模块状态
               m.free_day,
               m.online_time,
               pm.fee AS module_fee,
               p.name AS package_name,                                            -- 套餐名称
               p.role,
               p.fee AS package_list_fee,
               p.unit,
               p.status AS package_status,                                        -- 套餐状态
               pp.fee AS package_fee,
               c.classify_name,
               c.op_id AS classify_op_id,
               c.update_time AS classify_update_time
        FROM (SELECT package_id, module_id FROM ods.ods_opr_module_package_detail_df WHERE travel_date = '${bizdate}'
              UNION ALL
              SELECT 0 AS package_id,                                             -- 套餐ID｜套餐内模块 + 单独售卖的模块
                     id AS module_id FROM ods.ods_opr_module_df WHERE travel_date = '${bizdate}') x
        JOIN ods.ods_opr_module_df m ON m.id = x.module_id AND m.travel_date = '${bizdate}'
        LEFT JOIN ods.ods_opr_module_package_df p ON p.id = x.package_id AND p.travel_date = '${bizdate}'
        LEFT JOIN (SELECT type, target_id, fee, mode, ROW_NUMBER() OVER (
            PARTITION BY type,
            target_id ORDER BY rank DESC,
            begin_time DESC
        ) AS rk                                                                   -- 优先级序号（1 = 生效）
        FROM ods.ods_opr_module_price_df
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区｜模块当日生效资费
          AND begin_time <= UNIX_TIMESTAMP('${bizdate}', 'yyyyMMdd')
          AND (end_time = 0 OR end_time >= UNIX_TIMESTAMP('${bizdate}', 'yyyyMMdd'))) pm ON pm.type = 1 AND pm.target_id = x.module_id AND pm.rk = 1
        LEFT JOIN (SELECT type, target_id, fee, mode, ROW_NUMBER() OVER (
            PARTITION BY type,
            target_id ORDER BY rank DESC,
            begin_time DESC
        ) AS rk                                                                   -- 优先级序号（1 = 生效）
        FROM ods.ods_opr_module_price_df
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区｜套餐当日生效资费
          AND begin_time <= UNIX_TIMESTAMP('${bizdate}', 'yyyyMMdd')
          AND (end_time = 0 OR end_time >= UNIX_TIMESTAMP('${bizdate}', 'yyyyMMdd'))) pp ON pp.type = 2 AND pp.target_id = x.package_id AND pp.rk = 1
        LEFT JOIN (SELECT CAST(pid AS BIGINT) AS package_id, MAX(classify_name) AS classify_name, MAX(op_id) AS op_id, MAX(update_time) AS update_time
                   FROM ods.ods_opr_module_package_classify_df LATERAL VIEW EXPLODE(SPLIT(package_ids, ',')) e AS pid
                   WHERE travel_date = '${bizdate}'                               -- 只取当日分区｜分类里的套餐列表拆行
                     AND is_delete = 0 GROUP BY CAST(pid AS BIGINT)) c ON c.package_id = x.package_id
    ) t
