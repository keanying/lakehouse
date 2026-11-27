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
INSERT OVERWRITE TABLE dwd.dwd_trf_api_order_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS api_order_id,  -- 对接订单记录ID
    pftorder                                                     AS order_no,     -- 平台订单号
    apiorder                                                     AS api_order_no,  -- 对接方订单号
    remoteorder                                                  AS remote_order_no,  -- 远端订单号
    temporder                                                    AS temp_order_no,  -- 临时订单号
    CAST(coopb AS BIGINT)                                        AS con_sys_id,   -- 对接系统（合作商家）ID
    CAST(bcode AS BIGINT)                                        AS api_product_code,  -- 对接方商品编码
    CAST(fid AS BIGINT)                                          AS distributor_id,  -- 分销商ID
    CAST(ostatus AS INT)                                         AS api_order_status,  -- 对接订单状态
    CAST(handlestatus AS INT)                                    AS handle_status,  -- 处理状态
    CAST(select_status AS INT)                                   AS query_status,  -- 查询状态
    CAST(code_query_status AS INT)                               AS code_query_status,  -- 向第三方请求消费码状态
    IF(COALESCE(errormsg, '') <> '', 1, 0)                       AS fail_flag,    -- 是否对接失败
    errormsg                                                     AS error_msg,    -- 错误信息
    CAST(ostnum AS BIGINT)                                       AS ticket_qty,   -- 订单票数
    COALESCE(interact_qty, 0)                                    AS interact_qty,  -- 当日报文交互次数
    ctime                                                        AS create_time,  -- 记录时间
    utime                                                        AS update_time,  -- 更新时间
    FROM_UNIXTIME(select_time)                                   AS query_time,   -- 最近查询订单状态时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT a.*, k.interact_qty
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY utime DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
              FROM ods.ods_trf_all_api_order_di WHERE travel_date = '${bizdate}') a
        LEFT JOIN (SELECT pftorder, COUNT(1) AS interact_qty FROM ods.ods_trf_api_order_track_di
                   WHERE travel_date = '${bizdate}' GROUP BY pftorder) k          -- 只取当日分区
          ON k.pftorder = a.pftorder                                              -- 按 pftorder 关联
        WHERE a.rn = 1                                                            -- 只保留每个主键的最新一条｜同一记录当日多次变更取最新
    ) t
