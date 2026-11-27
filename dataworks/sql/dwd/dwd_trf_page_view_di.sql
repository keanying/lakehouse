-- ================================================================================================
-- dwd.dwd_trf_page_view_di  页面访问明细
-- 粒度：1行=1次页面访问
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_prd_resource_search_history_df、微商城埋点
-- 业务规则 / 修正：
--   · 资源中心搜索行为作为页面访问；待确认：微商城埋点（旧 dwd_user_resource_center_pv_d_f 来自埋点日志）未在导出包，接入后作为第二个分支 UNION ALL
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_trf_page_view_di PARTITION (travel_date = '${bizdate}')
SELECT
    CONCAT('resource_search_', COALESCE(search_type, '0'))       AS page_code,
    CAST(member_id AS BIGINT)                                    AS user_id,
    add_time                                                     AS visit_time,
    id,
    member_id,
    shop,
    key_word,
    add_time,
    search_type,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_prd_resource_search_history_df
WHERE travel_date = '${bizdate}'
  AND DATE_FORMAT(add_time, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
