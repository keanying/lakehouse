-- ================================================================================================
-- dwd.dwd_sup_customer_visit_di  客户拜访 / 接待明细
-- 粒度：1行=1次客户拜访或接待
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_sup_oa_customer_visit_ledger_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/经营数据/dwd_mkt_oa_customer_reception_detail_df（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 过渡期从旧表 dwd_mkt_oa_customer_reception_detail_df 平移：旧逻辑由多张中间表 / 外部采集加工，字段与 ODS 不能直接对应；字段口径按字典，上线顺序：先平移保证下游可切换，再按字段清单把「待确认」逐个改为从 ODS 计算后下线旧链路
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_sup_customer_visit_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(NULL AS BIGINT)                                         AS company_id,   -- 待确认：来源未同步
    CAST(NULL AS STRING)                                         AS visit_time,   -- 待确认：来源未同步
    CAST(NULL AS BIGINT)                                         AS staff_id,   -- 待确认：来源未同步
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM dwd_mkt_oa_customer_reception_detail_df
