-- ================================================================================================
-- dwd.dwd_opr_parking_record_di  停车出入场明细
-- 粒度：1行=1次车辆出入场
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_opr_parking_daoer5_entry_record_di、ods_opr_parking_daoer5_exit_record_di、ods_opr_parking_daoer_entry_record_di、ods_opr_parking_daoer_exit_record_di、ods_opr_parking_ketuo_entry_record_di、ods_opr_parking_ketuo_exit_record_di、ods_opr_parking_shuaichen_entry_record_di、ods_opr_parking_shuaichen_exit_record_di、ods_opr_parking_zhihui_entry_record_di、ods_opr_parking_zhihui_exit_record_di
-- 业务规则 / 修正：
--   · 5 个停车厂商 × 入场 / 出场 10 张表 UNION ALL 归一：厂商、车场、进出类型、时间、金额统一口径（旧系统 10 个独立汇总任务）
--   · 待确认：ketuo 出场表没有收费金额；金额单位按分（/100）与厂商接口核对
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_opr_parking_record_di PARTITION (travel_date = '${bizdate}')
-- (1) ods_opr_parking_daoer5_entry_record_di
SELECT
    car_no,
    'daoer5'                                                     AS parking_vendor,
    CAST(parking_no AS STRING)                                   AS parking_lot_code,
    'IN'                                                         AS inout_type,
    in_time                                                      AS inout_time,
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,
    id,
    con_sys_bind,
    member_id,
    object_id,
    car_in_id,
    entrance_id,
    entrance_name,
    card_id,
    next_car_no,
    correct_car_no,
    SUBSTRING_INDEX(card_no, '#', 1)                             AS card_no_mask,
    contact_name,
    card_type_name,
    car_no_type,
    card_type_id,
    in_time,
    entrance_user_name,
    in_pic,
    in_way,
    in_way_name,
    small,
    controlip,
    description,
    parking_no,
    parking_name,
    box_id,
    box_name,
    operator_name,
    park_owner,
    SUBSTRING_INDEX(phone, '#', 1)                               AS phone_mask,
    data_origin,
    delete_code,
    is_load,
    save_time,
    create_time,
    cflag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_parking_daoer5_entry_record_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (2) ods_opr_parking_daoer5_exit_record_di
SELECT
    car_no,
    'daoer5'                                                     AS parking_vendor,
    CAST(parking_no AS STRING)                                   AS parking_lot_code,
    'OUT'                                                        AS inout_type,
    out_time                                                     AS inout_time,
    CAST(pay_charge AS DECIMAL(18,2)) / 100                      AS fee_amt,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS object_id,
    CAST(NULL AS STRING)                                         AS car_in_id,
    CAST(NULL AS STRING)                                         AS entrance_id,
    entrance_name,
    CAST(NULL AS STRING)                                         AS card_id,
    CAST(NULL AS STRING)                                         AS next_car_no,
    CAST(NULL AS STRING)                                         AS correct_car_no,
    CAST(NULL AS STRING)                                         AS card_no_mask,
    contact_name,
    card_type_name,
    CAST(NULL AS STRING)                                         AS car_no_type,
    card_type_id,
    in_time,
    entrance_user_name,
    in_pic,
    CAST(NULL AS STRING)                                         AS in_way,
    in_way_name,
    small,
    CAST(NULL AS STRING)                                         AS controlip,
    CAST(NULL AS STRING)                                         AS description,
    CAST(NULL AS STRING)                                         AS parking_no,
    CAST(NULL AS STRING)                                         AS parking_name,
    CAST(NULL AS STRING)                                         AS box_id,
    CAST(NULL AS STRING)                                         AS box_name,
    CAST(NULL AS STRING)                                         AS operator_name,
    CAST(NULL AS STRING)                                         AS park_owner,
    CAST(NULL AS STRING)                                         AS phone_mask,
    CAST(NULL AS STRING)                                         AS data_origin,
    CAST(NULL AS STRING)                                         AS delete_code,
    CAST(NULL AS BIGINT)                                         AS is_load,
    CAST(NULL AS STRING)                                         AS save_time,
    CAST(NULL AS STRING)                                         AS create_time,
    CAST(NULL AS STRING)                                         AS cflag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_parking_daoer5_exit_record_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (3) ods_opr_parking_daoer_entry_record_di
SELECT
    car_no,
    'daoer'                                                      AS parking_vendor,
    CAST(entry_name AS STRING)                                   AS parking_lot_code,
    'IN'                                                         AS inout_type,
    entry_time                                                   AS inout_time,
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS object_id,
    CAST(NULL AS STRING)                                         AS car_in_id,
    CAST(NULL AS STRING)                                         AS entrance_id,
    CAST(NULL AS STRING)                                         AS entrance_name,
    card_id,
    CAST(NULL AS STRING)                                         AS next_car_no,
    CAST(NULL AS STRING)                                         AS correct_car_no,
    SUBSTRING_INDEX(card_no, '#', 1)                             AS card_no_mask,
    CAST(NULL AS STRING)                                         AS contact_name,
    card_type_name,
    CAST(NULL AS STRING)                                         AS car_no_type,
    CAST(NULL AS BIGINT)                                         AS card_type_id,
    CAST(NULL AS STRING)                                         AS in_time,
    CAST(NULL AS STRING)                                         AS entrance_user_name,
    CAST(NULL AS STRING)                                         AS in_pic,
    CAST(NULL AS STRING)                                         AS in_way,
    CAST(NULL AS STRING)                                         AS in_way_name,
    CAST(NULL AS STRING)                                         AS small,
    CAST(NULL AS STRING)                                         AS controlip,
    CAST(NULL AS STRING)                                         AS description,
    CAST(NULL AS STRING)                                         AS parking_no,
    CAST(NULL AS STRING)                                         AS parking_name,
    CAST(NULL AS STRING)                                         AS box_id,
    CAST(NULL AS STRING)                                         AS box_name,
    CAST(NULL AS STRING)                                         AS operator_name,
    CAST(NULL AS STRING)                                         AS park_owner,
    CAST(NULL AS STRING)                                         AS phone_mask,
    CAST(NULL AS STRING)                                         AS data_origin,
    CAST(NULL AS STRING)                                         AS delete_code,
    CAST(NULL AS BIGINT)                                         AS is_load,
    CAST(NULL AS STRING)                                         AS save_time,
    CAST(NULL AS STRING)                                         AS create_time,
    CAST(NULL AS STRING)                                         AS cflag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_parking_daoer_entry_record_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (4) ods_opr_parking_daoer_exit_record_di
SELECT
    car_no,
    'daoer'                                                      AS parking_vendor,
    CAST(entry_name AS STRING)                                   AS parking_lot_code,
    'OUT'                                                        AS inout_type,
    exit_time                                                    AS inout_time,
    CAST(pay_charge AS DECIMAL(18,2)) / 100                      AS fee_amt,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS object_id,
    CAST(NULL AS STRING)                                         AS car_in_id,
    CAST(NULL AS STRING)                                         AS entrance_id,
    CAST(NULL AS STRING)                                         AS entrance_name,
    card_id,
    CAST(NULL AS STRING)                                         AS next_car_no,
    CAST(NULL AS STRING)                                         AS correct_car_no,
    SUBSTRING_INDEX(card_no, '#', 1)                             AS card_no_mask,
    CAST(NULL AS STRING)                                         AS contact_name,
    card_type_name,
    CAST(NULL AS STRING)                                         AS car_no_type,
    CAST(NULL AS BIGINT)                                         AS card_type_id,
    entry_time                                                   AS in_time,
    CAST(NULL AS STRING)                                         AS entrance_user_name,
    CAST(NULL AS STRING)                                         AS in_pic,
    CAST(NULL AS STRING)                                         AS in_way,
    CAST(NULL AS STRING)                                         AS in_way_name,
    CAST(NULL AS STRING)                                         AS small,
    CAST(NULL AS STRING)                                         AS controlip,
    CAST(NULL AS STRING)                                         AS description,
    CAST(NULL AS STRING)                                         AS parking_no,
    CAST(NULL AS STRING)                                         AS parking_name,
    CAST(NULL AS STRING)                                         AS box_id,
    CAST(NULL AS STRING)                                         AS box_name,
    CAST(NULL AS STRING)                                         AS operator_name,
    CAST(NULL AS STRING)                                         AS park_owner,
    CAST(NULL AS STRING)                                         AS phone_mask,
    CAST(NULL AS STRING)                                         AS data_origin,
    CAST(NULL AS STRING)                                         AS delete_code,
    CAST(NULL AS BIGINT)                                         AS is_load,
    CAST(NULL AS STRING)                                         AS save_time,
    CAST(NULL AS STRING)                                         AS create_time,
    CAST(NULL AS STRING)                                         AS cflag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_parking_daoer_exit_record_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (5) ods_opr_parking_ketuo_entry_record_di
SELECT
    plate_no                                                     AS car_no,
    'ketuo'                                                      AS parking_vendor,
    CAST(cap_place AS STRING)                                    AS parking_lot_code,
    'IN'                                                         AS inout_type,
    cap_time                                                     AS inout_time,
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS object_id,
    CAST(NULL AS STRING)                                         AS car_in_id,
    CAST(NULL AS STRING)                                         AS entrance_id,
    CAST(NULL AS STRING)                                         AS entrance_name,
    CAST(NULL AS STRING)                                         AS card_id,
    CAST(NULL AS STRING)                                         AS next_car_no,
    CAST(NULL AS STRING)                                         AS correct_car_no,
    SUBSTRING_INDEX(card_no, '#', 1)                             AS card_no_mask,
    CAST(NULL AS STRING)                                         AS contact_name,
    CAST(NULL AS STRING)                                         AS card_type_name,
    CAST(NULL AS STRING)                                         AS car_no_type,
    CAST(NULL AS BIGINT)                                         AS card_type_id,
    CAST(NULL AS STRING)                                         AS in_time,
    CAST(NULL AS STRING)                                         AS entrance_user_name,
    CAST(NULL AS STRING)                                         AS in_pic,
    CAST(NULL AS STRING)                                         AS in_way,
    CAST(NULL AS STRING)                                         AS in_way_name,
    CAST(NULL AS STRING)                                         AS small,
    CAST(NULL AS STRING)                                         AS controlip,
    CAST(NULL AS STRING)                                         AS description,
    CAST(NULL AS STRING)                                         AS parking_no,
    CAST(NULL AS STRING)                                         AS parking_name,
    CAST(NULL AS STRING)                                         AS box_id,
    CAST(NULL AS STRING)                                         AS box_name,
    CAST(NULL AS STRING)                                         AS operator_name,
    CAST(NULL AS STRING)                                         AS park_owner,
    CAST(NULL AS STRING)                                         AS phone_mask,
    CAST(NULL AS STRING)                                         AS data_origin,
    CAST(NULL AS STRING)                                         AS delete_code,
    CAST(NULL AS BIGINT)                                         AS is_load,
    CAST(NULL AS STRING)                                         AS save_time,
    CAST(NULL AS STRING)                                         AS create_time,
    CAST(NULL AS STRING)                                         AS cflag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_parking_ketuo_entry_record_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (6) ods_opr_parking_ketuo_exit_record_di
SELECT
    plate_no                                                     AS car_no,
    'ketuo'                                                      AS parking_vendor,
    CAST(cap_place AS STRING)                                    AS parking_lot_code,
    'OUT'                                                        AS inout_type,
    cap_time                                                     AS inout_time,
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS object_id,
    CAST(NULL AS STRING)                                         AS car_in_id,
    CAST(NULL AS STRING)                                         AS entrance_id,
    CAST(NULL AS STRING)                                         AS entrance_name,
    CAST(NULL AS STRING)                                         AS card_id,
    CAST(NULL AS STRING)                                         AS next_car_no,
    CAST(NULL AS STRING)                                         AS correct_car_no,
    SUBSTRING_INDEX(card_no, '#', 1)                             AS card_no_mask,
    CAST(NULL AS STRING)                                         AS contact_name,
    CAST(NULL AS STRING)                                         AS card_type_name,
    CAST(NULL AS STRING)                                         AS car_no_type,
    CAST(NULL AS BIGINT)                                         AS card_type_id,
    cap_time                                                     AS in_time,
    CAST(NULL AS STRING)                                         AS entrance_user_name,
    CAST(NULL AS STRING)                                         AS in_pic,
    CAST(NULL AS STRING)                                         AS in_way,
    CAST(NULL AS STRING)                                         AS in_way_name,
    CAST(NULL AS STRING)                                         AS small,
    CAST(NULL AS STRING)                                         AS controlip,
    CAST(NULL AS STRING)                                         AS description,
    CAST(NULL AS STRING)                                         AS parking_no,
    CAST(NULL AS STRING)                                         AS parking_name,
    CAST(NULL AS STRING)                                         AS box_id,
    CAST(NULL AS STRING)                                         AS box_name,
    CAST(NULL AS STRING)                                         AS operator_name,
    CAST(NULL AS STRING)                                         AS park_owner,
    CAST(NULL AS STRING)                                         AS phone_mask,
    CAST(NULL AS STRING)                                         AS data_origin,
    CAST(NULL AS STRING)                                         AS delete_code,
    CAST(NULL AS BIGINT)                                         AS is_load,
    CAST(NULL AS STRING)                                         AS save_time,
    CAST(NULL AS STRING)                                         AS create_time,
    CAST(NULL AS STRING)                                         AS cflag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_parking_ketuo_exit_record_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (7) ods_opr_parking_shuaichen_entry_record_di
SELECT
    plate_num                                                    AS car_no,
    'shuaichen'                                                  AS parking_vendor,
    CAST(park_code AS STRING)                                    AS parking_lot_code,
    'IN'                                                         AS inout_type,
    enter_time                                                   AS inout_time,
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS object_id,
    CAST(NULL AS STRING)                                         AS car_in_id,
    CAST(NULL AS STRING)                                         AS entrance_id,
    CAST(NULL AS STRING)                                         AS entrance_name,
    CAST(NULL AS STRING)                                         AS card_id,
    CAST(NULL AS STRING)                                         AS next_car_no,
    CAST(NULL AS STRING)                                         AS correct_car_no,
    CAST(NULL AS STRING)                                         AS card_no_mask,
    CAST(NULL AS STRING)                                         AS contact_name,
    CAST(NULL AS STRING)                                         AS card_type_name,
    CAST(NULL AS STRING)                                         AS car_no_type,
    CAST(NULL AS BIGINT)                                         AS card_type_id,
    CAST(NULL AS STRING)                                         AS in_time,
    CAST(NULL AS STRING)                                         AS entrance_user_name,
    CAST(NULL AS STRING)                                         AS in_pic,
    CAST(NULL AS STRING)                                         AS in_way,
    CAST(NULL AS STRING)                                         AS in_way_name,
    CAST(NULL AS STRING)                                         AS small,
    CAST(NULL AS STRING)                                         AS controlip,
    CAST(NULL AS STRING)                                         AS description,
    CAST(NULL AS STRING)                                         AS parking_no,
    CAST(NULL AS STRING)                                         AS parking_name,
    CAST(NULL AS STRING)                                         AS box_id,
    CAST(NULL AS STRING)                                         AS box_name,
    CAST(NULL AS STRING)                                         AS operator_name,
    CAST(NULL AS STRING)                                         AS park_owner,
    CAST(NULL AS STRING)                                         AS phone_mask,
    CAST(NULL AS STRING)                                         AS data_origin,
    CAST(NULL AS STRING)                                         AS delete_code,
    CAST(NULL AS BIGINT)                                         AS is_load,
    CAST(NULL AS STRING)                                         AS save_time,
    CAST(NULL AS STRING)                                         AS create_time,
    CAST(NULL AS STRING)                                         AS cflag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_parking_shuaichen_entry_record_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (8) ods_opr_parking_shuaichen_exit_record_di
SELECT
    plate_num                                                    AS car_no,
    'shuaichen'                                                  AS parking_vendor,
    CAST(park_code AS STRING)                                    AS parking_lot_code,
    'OUT'                                                        AS inout_type,
    exit_time                                                    AS inout_time,
    CAST(paid_amount AS DECIMAL(18,2)) / 100                     AS fee_amt,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS object_id,
    CAST(NULL AS STRING)                                         AS car_in_id,
    CAST(NULL AS STRING)                                         AS entrance_id,
    CAST(NULL AS STRING)                                         AS entrance_name,
    CAST(NULL AS STRING)                                         AS card_id,
    CAST(NULL AS STRING)                                         AS next_car_no,
    CAST(NULL AS STRING)                                         AS correct_car_no,
    CAST(NULL AS STRING)                                         AS card_no_mask,
    CAST(NULL AS STRING)                                         AS contact_name,
    CAST(NULL AS STRING)                                         AS card_type_name,
    CAST(NULL AS STRING)                                         AS car_no_type,
    CAST(NULL AS BIGINT)                                         AS card_type_id,
    enter_time                                                   AS in_time,
    CAST(NULL AS STRING)                                         AS entrance_user_name,
    CAST(NULL AS STRING)                                         AS in_pic,
    CAST(NULL AS STRING)                                         AS in_way,
    CAST(NULL AS STRING)                                         AS in_way_name,
    CAST(NULL AS STRING)                                         AS small,
    CAST(NULL AS STRING)                                         AS controlip,
    CAST(NULL AS STRING)                                         AS description,
    CAST(NULL AS STRING)                                         AS parking_no,
    CAST(NULL AS STRING)                                         AS parking_name,
    CAST(NULL AS STRING)                                         AS box_id,
    CAST(NULL AS STRING)                                         AS box_name,
    CAST(NULL AS STRING)                                         AS operator_name,
    CAST(NULL AS STRING)                                         AS park_owner,
    CAST(NULL AS STRING)                                         AS phone_mask,
    CAST(NULL AS STRING)                                         AS data_origin,
    CAST(NULL AS STRING)                                         AS delete_code,
    CAST(NULL AS BIGINT)                                         AS is_load,
    CAST(NULL AS STRING)                                         AS save_time,
    CAST(NULL AS STRING)                                         AS create_time,
    CAST(NULL AS STRING)                                         AS cflag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_parking_shuaichen_exit_record_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (9) ods_opr_parking_zhihui_entry_record_di
SELECT
    car_no,
    'zhihui'                                                     AS parking_vendor,
    CAST(park_key AS STRING)                                     AS parking_lot_code,
    'IN'                                                         AS inout_type,
    enter_time                                                   AS inout_time,
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS object_id,
    CAST(NULL AS STRING)                                         AS car_in_id,
    CAST(NULL AS STRING)                                         AS entrance_id,
    CAST(NULL AS STRING)                                         AS entrance_name,
    CAST(NULL AS STRING)                                         AS card_id,
    CAST(NULL AS STRING)                                         AS next_car_no,
    CAST(NULL AS STRING)                                         AS correct_car_no,
    CAST(NULL AS STRING)                                         AS card_no_mask,
    CAST(NULL AS STRING)                                         AS contact_name,
    CAST(NULL AS STRING)                                         AS card_type_name,
    CAST(NULL AS STRING)                                         AS car_no_type,
    CAST(NULL AS BIGINT)                                         AS card_type_id,
    CAST(NULL AS STRING)                                         AS in_time,
    CAST(NULL AS STRING)                                         AS entrance_user_name,
    CAST(NULL AS STRING)                                         AS in_pic,
    CAST(NULL AS STRING)                                         AS in_way,
    CAST(NULL AS STRING)                                         AS in_way_name,
    CAST(NULL AS STRING)                                         AS small,
    CAST(NULL AS STRING)                                         AS controlip,
    CAST(NULL AS STRING)                                         AS description,
    CAST(NULL AS STRING)                                         AS parking_no,
    CAST(NULL AS STRING)                                         AS parking_name,
    CAST(NULL AS STRING)                                         AS box_id,
    CAST(NULL AS STRING)                                         AS box_name,
    CAST(NULL AS STRING)                                         AS operator_name,
    CAST(NULL AS STRING)                                         AS park_owner,
    CAST(NULL AS STRING)                                         AS phone_mask,
    CAST(NULL AS STRING)                                         AS data_origin,
    CAST(NULL AS STRING)                                         AS delete_code,
    CAST(NULL AS BIGINT)                                         AS is_load,
    CAST(NULL AS STRING)                                         AS save_time,
    CAST(NULL AS STRING)                                         AS create_time,
    CAST(NULL AS STRING)                                         AS cflag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_parking_zhihui_entry_record_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
UNION ALL
-- (10) ods_opr_parking_zhihui_exit_record_di
SELECT
    car_no,
    'zhihui'                                                     AS parking_vendor,
    CAST(park_key AS STRING)                                     AS parking_lot_code,
    'OUT'                                                        AS inout_type,
    out_time                                                     AS inout_time,
    CAST(total_amount AS DECIMAL(18,2)) / 100                    AS fee_amt,
    id,
    con_sys_bind,
    member_id,
    CAST(NULL AS STRING)                                         AS object_id,
    CAST(NULL AS STRING)                                         AS car_in_id,
    CAST(NULL AS STRING)                                         AS entrance_id,
    CAST(NULL AS STRING)                                         AS entrance_name,
    CAST(NULL AS STRING)                                         AS card_id,
    CAST(NULL AS STRING)                                         AS next_car_no,
    CAST(NULL AS STRING)                                         AS correct_car_no,
    CAST(NULL AS STRING)                                         AS card_no_mask,
    CAST(NULL AS STRING)                                         AS contact_name,
    CAST(NULL AS STRING)                                         AS card_type_name,
    CAST(NULL AS STRING)                                         AS car_no_type,
    CAST(NULL AS BIGINT)                                         AS card_type_id,
    enter_time                                                   AS in_time,
    CAST(NULL AS STRING)                                         AS entrance_user_name,
    CAST(NULL AS STRING)                                         AS in_pic,
    CAST(NULL AS STRING)                                         AS in_way,
    CAST(NULL AS STRING)                                         AS in_way_name,
    CAST(NULL AS STRING)                                         AS small,
    CAST(NULL AS STRING)                                         AS controlip,
    CAST(NULL AS STRING)                                         AS description,
    CAST(NULL AS STRING)                                         AS parking_no,
    CAST(NULL AS STRING)                                         AS parking_name,
    CAST(NULL AS STRING)                                         AS box_id,
    CAST(NULL AS STRING)                                         AS box_name,
    CAST(NULL AS STRING)                                         AS operator_name,
    CAST(NULL AS STRING)                                         AS park_owner,
    CAST(NULL AS STRING)                                         AS phone_mask,
    CAST(NULL AS STRING)                                         AS data_origin,
    CAST(NULL AS STRING)                                         AS delete_code,
    CAST(NULL AS BIGINT)                                         AS is_load,
    CAST(NULL AS STRING)                                         AS save_time,
    CAST(NULL AS STRING)                                         AS create_time,
    CAST(NULL AS STRING)                                         AS cflag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn
        FROM ods.ods_opr_parking_zhihui_exit_record_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
