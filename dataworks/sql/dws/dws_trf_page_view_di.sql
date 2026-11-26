-- ================================================================================================
-- dws.dws_trf_page_view_di  页面访问日汇总
-- 粒度：1行=1天×页面
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_trf_page_view_di
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 去重类指标存位图（TO_BITMAP / BITMAP_UNION，UDF 与 PFT3.0 同一套），任意周期 BITMAP_UNION_COUNT
--   · 来源：pv = dwd.dwd_trf_page_view_di（页面访问）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_trf_page_view_di PARTITION (travel_date = '${bizdate}')
SELECT
    page_code,
    SUM(page_pv)                                                 AS page_pv,
    BITMAP_UNION(page_uv_qty)                                    AS page_uv_qty,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- pv：页面访问
    SELECT
        page_code,
        SUM(COALESCE(pv_qty, 1))                                     AS page_pv,
        BITMAP_UNION(TO_BITMAP(XXHASH64(distinct_id)))               AS page_uv_qty
    FROM dwd.dwd_trf_page_view_di
    WHERE travel_date = '${bizdate}'
    GROUP BY page_code
) u
GROUP BY page_code
