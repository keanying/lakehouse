-- ================================================================================================
-- dwd.dwd_opr_retail_order_di  零售订单明细
-- 粒度：1行=1个零售订单商品行（含退货）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_opr_retail_yinbao_ticket_di、ods_opr_retail_sixun_order_di、ods_opr_retail_xisland_order_di 等
-- 业务规则 / 修正：
--   · 银豹 / 思迅 / 小岛 3 套零售系统 UNION ALL 归一（旧系统每套一条独立链路）
--   · 待确认：退货标识各系统码值（思迅 status=2、银豹 SELL_RETURN）上线前与厂商确认；商品明细在 *_item 表，件数待接入
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_opr_retail_order_di PARTITION (travel_date = '${bizdate}')
-- (1) ods_opr_retail_sixun_order_di
SELECT
    shop_code,
    order_no,
    CAST(payment_money AS DECIMAL(18,2))                         AS sale_amt,
    'sixun'                                                      AS retail_vendor,
    CAST(NULL AS STRING)                                         AS goods_code,   -- 待确认：来源未同步
    CAST(NULL AS BIGINT)                                         AS item_qty,
    IF(status = '2', 1, 0)                                       AS refund_flag,
    id,
    con_sys_bind,
    member_id,
    status                                                       AS order_status,
    payment_money                                                AS pay_amt,
    settlement_money                                             AS settlement_amt,
    table_number,
    number_of_people,
    pos_name,
    operator,
    create_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_retail_sixun_order_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (2) ods_opr_retail_yinbao_ticket_di
SELECT
    CAST(app_id AS STRING)                                       AS shop_code,
    sn                                                           AS order_no,
    CAST(total_amount AS DECIMAL(18,2))                          AS sale_amt,
    'yinbao'                                                     AS retail_vendor,
    CAST(NULL AS STRING)                                         AS goods_code,
    CAST(NULL AS BIGINT)                                         AS item_qty,
    IF(ticket_type = 'SELL_RETURN', 1, 0)                        AS refund_flag,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS order_status,
    CAST(NULL AS DECIMAL(10,2))                                  AS pay_amt,
    CAST(NULL AS DECIMAL(10,2))                                  AS settlement_amt,
    CAST(NULL AS STRING)                                         AS table_number,
    CAST(NULL AS BIGINT)                                         AS number_of_people,
    CAST(NULL AS STRING)                                         AS pos_name,
    CAST(NULL AS STRING)                                         AS operator,
    date_time                                                    AS create_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_retail_yinbao_ticket_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (3) ods_opr_retail_xisland_order_di
SELECT
    store_name                                                   AS shop_code,
    order_code                                                   AS order_no,
    CAST(pay_amount AS DECIMAL(18,2))                            AS sale_amt,
    'xisland'                                                    AS retail_vendor,
    CAST(NULL AS STRING)                                         AS goods_code,
    CAST(NULL AS BIGINT)                                         AS item_qty,
    IF(CAST(return_amount AS DECIMAL(18,2)) > 0, 1, 0)           AS refund_flag,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS order_status,
    pay_amount                                                   AS pay_amt,
    CAST(NULL AS DECIMAL(10,2))                                  AS settlement_amt,
    CAST(NULL AS STRING)                                         AS table_number,
    CAST(NULL AS BIGINT)                                         AS number_of_people,
    CAST(NULL AS STRING)                                         AS pos_name,
    CAST(NULL AS STRING)                                         AS operator,
    order_create_time                                            AS create_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_retail_xisland_order_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
