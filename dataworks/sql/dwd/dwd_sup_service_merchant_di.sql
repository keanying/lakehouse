-- ================================================================================================
-- dwd.dwd_sup_service_merchant_di  服务商户明细
-- 粒度：1行=1个服务商户×1个服务项目
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_sup_member_df、ods_sup_cooperation_other_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 业务工厂/经营数据/服务商户/dwd_service_business_d_f（EMR_SPARK_SQL，cron 00 00 02 * * ?）
-- 业务规则 / 修正：
--   · 过渡期从旧表 dwd_service_business_d_f 平移：旧逻辑由多张中间表 / 外部采集加工，字段与 ODS 不能直接对应；字段口径按字典，上线顺序：先平移保证下游可切换，再按字段清单把「待确认」逐个改为从 ODS 计算后下线旧链路
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_sup_service_merchant_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    member_id,                                                                    -- 商户id
    member_kind,                                                                  -- 商户类型
    member_type,                                                                  -- 商户业态
    province                                                     AS province_name,  -- 商户所在省
    city                                                         AS city_name,    -- 商户所在市
    start_time,                                                                   -- 开始服务日期
    end_time                                                     AS valid_end_time,  -- 最后服务日期
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM dwd_service_business_d_f
WHERE pt = '${bizdate}'                                                           -- 过渡期：读旧表，按字段清单逐步改为从 ODS 计算
