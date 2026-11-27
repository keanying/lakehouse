-- ================================================================================================
-- dwd.dwd_trf_api_order_di  OTA / API 对接订单明细
-- 粒度：1行=1张对接订单（当日新增 / 变更）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_trf_all_api_order_di、ods_trf_api_order_track_di
-- 业务规则 / 修正：
--   · 游客信息（tourist_info）与请求 / 响应报文不进 DWD：游客以 dwd_ord_traveler_di 为准，报文只保留交互次数
--   · 待确认：对接失败口径（errormsg 非空 vs handlestatus 码值）上线前与渠道对接组确认
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_trf_api_order_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS BIGINT)                                           AS api_order_id,
    pftorder                                                     AS order_no,
    apiorder                                                     AS api_order_no,
    remoteorder                                                  AS remote_order_no,
    temporder                                                    AS temp_order_no,
    CAST(coopb AS BIGINT)                                        AS con_sys_id,
    CAST(bcode AS BIGINT)                                        AS api_product_code,
    CAST(fid AS BIGINT)                                          AS distributor_id,
    CAST(ostatus AS INT)                                         AS api_order_status,
    CAST(handlestatus AS INT)                                    AS handle_status,
    CAST(select_status AS INT)                                   AS query_status,
    CAST(code_query_status AS INT)                               AS code_query_status,
    IF(COALESCE(errormsg, '') <> '', 1, 0)                       AS fail_flag,
    errormsg                                                     AS error_msg,
    CAST(ostnum AS BIGINT)                                       AS ticket_qty,
    COALESCE(interact_qty, 0)                                    AS interact_qty,
    ctime                                                        AS create_time,
    utime                                                        AS update_time,
    FROM_UNIXTIME(select_time)                                   AS query_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT a.*, k.interact_qty
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY utime DESC) AS rn
              FROM ods.ods_trf_all_api_order_di WHERE travel_date = '${bizdate}') a
        LEFT JOIN (SELECT pftorder, COUNT(1) AS interact_qty FROM ods.ods_trf_api_order_track_di
                   WHERE travel_date = '${bizdate}' GROUP BY pftorder) k
          ON k.pftorder = a.pftorder
        WHERE a.rn = 1      -- 同一记录当日多次变更取最新
    ) t
