-- ================================================================================================
-- dim.dim_opr_module_package_df  应用模块 / 套餐维度
-- 粒度：1行=1个应用模块或套餐
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_module_df、ods_opr_module_package_df、ods_opr_module_package_classify_df、ods_opr_module_price_df
-- 替代旧任务 3 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_其他/dim_pft_module_package_classify_d_f（EMR_SPARK_SQL，cron 00 27 00 * * ?）
--   · 业务工厂/内部信息/财务部/客户属性cus_company/pft001_to_dim_prod_pft_module_package_detail_d_f（DI，cron 00 00 06 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dim_prd_module_price_df（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 过渡期从旧表 dim_pft_module_package_classify_d_f 平移：旧逻辑由多张中间表 / 外部采集加工，字段与 ODS 不能直接对应；字段口径按字典，上线顺序：先平移保证下游可切换，再按字段清单把「待确认」逐个改为从 ODS 计算后下线旧链路
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_opr_module_package_df
SELECT
    CAST(NULL AS STRING)                                         AS module_id,   -- 待确认：来源未同步（旧字段 dim_prod_pft_module_package_detail_d_f.module_id）
    package_id,
    CAST(NULL AS STRING)                                         AS module_name,   -- 待确认：来源未同步
    package_classify_name,
    CAST(operate_id AS BIGINT)                                   AS operator_id,
    operate_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM dim_pft_module_package_classify_d_f
WHERE pt = '${bizdate}'   -- 过渡期：读旧表，按字段清单逐步改为从 ODS 计算
