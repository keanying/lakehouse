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
-- 置空列：多个源表 UNION ALL 归一时，某源表没有的字段置空（各源表字段对照见各分支）
INSERT OVERWRITE TABLE dwd.dwd_opr_parking_record_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- (1) ods_opr_parking_daoer5_entry_record_di
SELECT
    car_no,                                                                       -- 车牌号
    'daoer5'                                                     AS parking_vendor,  -- 停车厂商
    CAST(parking_no AS STRING)                                   AS parking_lot_code,  -- 停车场编码
    'IN'                                                         AS inout_type,   -- 出入类型
    in_time                                                      AS inout_time,   -- 出入时间
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,      -- 费用金额：此源表无此字段，置空
    id,                                                                           -- 自增ID
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    object_id,                                                                    -- 对象ID
    car_in_id,                                                                    -- 入场表ID
    entrance_id,                                                                  -- 控制器编号
    entrance_name,                                                                -- 入场控制器名称
    card_id,                                                                      -- 卡ID
    next_car_no,                                                                  -- 从车牌
    correct_car_no,                                                               -- 矫正车牌
    SUBSTRING_INDEX(card_no, '#', 1)                             AS card_no_mask,  -- 卡号（脱敏）
    contact_name,                                                                 -- 车主名称
    card_type_name,                                                               -- 卡类名称
    car_no_type,                                                                  -- 车牌类型
    card_type_id,                                                                 -- 停车类型
    in_time,                                                                      -- 入场时间
    entrance_user_name,                                                           -- 入场操作员
    in_pic,                                                                       -- 入场图片路径
    in_way,                                                                       -- 入场方式 0正常入场
    in_way_name,                                                                  -- 入场方式名称
    small,                                                                        -- 小车场内0 否 1是
    controlip,                                                                    -- 入场IP
    description,                                                                  -- 描述
    parking_no,                                                                   -- 车场编号
    parking_name,                                                                 -- 车场名称
    box_id,                                                                       -- 岗亭ID
    box_name,                                                                     -- 岗亭名称
    operator_name,                                                                -- 操作人
    park_owner,                                                                   -- 车场负责人
    SUBSTRING_INDEX(phone, '#', 1)                               AS phone_mask,   -- 电话号码（脱敏）
    data_origin,                                                                  -- 线下或线上
    delete_code,                                                                  -- 是否已经删除
    is_load,                                                                      -- 1待同步 2 已同步 3同步失败
    save_time,                                                                    -- 保存时间
    create_time,                                                                  -- 创建时间
    cflag,                                                                        -- 线下或线上
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_parking_daoer5_entry_record_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (2) ods_opr_parking_daoer5_exit_record_di
SELECT
    car_no,                                                                       -- 车牌号
    'daoer5'                                                     AS parking_vendor,  -- 停车厂商
    CAST(parking_no AS STRING)                                   AS parking_lot_code,  -- 停车场编码
    'OUT'                                                        AS inout_type,   -- 出入类型
    out_time                                                     AS inout_time,   -- 出入时间
    CAST(pay_charge AS DECIMAL(18,2)) / 100                      AS fee_amt,      -- 费用金额
    id,                                                                           -- 自增ID
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS object_id,    -- 对象ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_in_id,    -- 入场表ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_id,  -- 控制器编号：此源表无此字段，置空
    entrance_name,                                                                -- 入场控制器名称
    CAST(NULL AS STRING)                                         AS card_id,      -- 卡ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS next_car_no,  -- 从车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS correct_car_no,  -- 矫正车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_no_mask,  -- 卡号（脱敏）：此源表无此字段，置空
    contact_name,                                                                 -- 车主名称
    card_type_name,                                                               -- 卡类名称
    CAST(NULL AS STRING)                                         AS car_no_type,  -- 车牌类型：此源表无此字段，置空
    card_type_id,                                                                 -- 停车类型
    in_time,                                                                      -- 入场时间
    entrance_user_name,                                                           -- 入场操作员
    in_pic,                                                                       -- 入场图片路径
    CAST(NULL AS STRING)                                         AS in_way,       -- 入场方式 0正常入场：此源表无此字段，置空
    in_way_name,                                                                  -- 入场方式名称
    small,                                                                        -- 小车场内0 否 1是
    CAST(NULL AS STRING)                                         AS controlip,    -- 入场IP：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS description,  -- 描述：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_no,   -- 车场编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_name,  -- 车场名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_id,       -- 岗亭ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_name,     -- 岗亭名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS operator_name,  -- 操作人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS park_owner,   -- 车场负责人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS phone_mask,   -- 电话号码（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS data_origin,  -- 线下或线上：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS delete_code,  -- 是否已经删除：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS is_load,      -- 1待同步 2 已同步 3同步失败：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS save_time,    -- 保存时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS create_time,  -- 创建时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS cflag,        -- 线下或线上：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_parking_daoer5_exit_record_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (3) ods_opr_parking_daoer_entry_record_di
SELECT
    car_no,                                                                       -- 车牌号
    'daoer'                                                      AS parking_vendor,  -- 停车厂商
    CAST(entry_name AS STRING)                                   AS parking_lot_code,  -- 停车场编码
    'IN'                                                         AS inout_type,   -- 出入类型
    entry_time                                                   AS inout_time,   -- 出入时间
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,      -- 费用金额：此源表无此字段，置空
    id,                                                                           -- 自增ID
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS object_id,    -- 对象ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_in_id,    -- 入场表ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_id,  -- 控制器编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_name,  -- 入场控制器名称：此源表无此字段，置空
    card_id,                                                                      -- 卡ID
    CAST(NULL AS STRING)                                         AS next_car_no,  -- 从车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS correct_car_no,  -- 矫正车牌：此源表无此字段，置空
    SUBSTRING_INDEX(card_no, '#', 1)                             AS card_no_mask,  -- 卡号（脱敏）
    CAST(NULL AS STRING)                                         AS contact_name,  -- 车主名称：此源表无此字段，置空
    card_type_name,                                                               -- 卡类名称
    CAST(NULL AS STRING)                                         AS car_no_type,  -- 车牌类型：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS card_type_id,  -- 停车类型：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_time,      -- 入场时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_user_name,  -- 入场操作员：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_pic,       -- 入场图片路径：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way,       -- 入场方式 0正常入场：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way_name,  -- 入场方式名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS small,        -- 小车场内0 否 1是：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS controlip,    -- 入场IP：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS description,  -- 描述：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_no,   -- 车场编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_name,  -- 车场名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_id,       -- 岗亭ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_name,     -- 岗亭名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS operator_name,  -- 操作人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS park_owner,   -- 车场负责人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS phone_mask,   -- 电话号码（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS data_origin,  -- 线下或线上：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS delete_code,  -- 是否已经删除：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS is_load,      -- 1待同步 2 已同步 3同步失败：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS save_time,    -- 保存时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS create_time,  -- 创建时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS cflag,        -- 线下或线上：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_parking_daoer_entry_record_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (4) ods_opr_parking_daoer_exit_record_di
SELECT
    car_no,                                                                       -- 车牌号
    'daoer'                                                      AS parking_vendor,  -- 停车厂商
    CAST(entry_name AS STRING)                                   AS parking_lot_code,  -- 停车场编码
    'OUT'                                                        AS inout_type,   -- 出入类型
    exit_time                                                    AS inout_time,   -- 出入时间
    CAST(pay_charge AS DECIMAL(18,2)) / 100                      AS fee_amt,      -- 费用金额
    id,                                                                           -- 自增ID
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS object_id,    -- 对象ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_in_id,    -- 入场表ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_id,  -- 控制器编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_name,  -- 入场控制器名称：此源表无此字段，置空
    card_id,                                                                      -- 卡ID
    CAST(NULL AS STRING)                                         AS next_car_no,  -- 从车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS correct_car_no,  -- 矫正车牌：此源表无此字段，置空
    SUBSTRING_INDEX(card_no, '#', 1)                             AS card_no_mask,  -- 卡号（脱敏）
    CAST(NULL AS STRING)                                         AS contact_name,  -- 车主名称：此源表无此字段，置空
    card_type_name,                                                               -- 卡类名称
    CAST(NULL AS STRING)                                         AS car_no_type,  -- 车牌类型：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS card_type_id,  -- 停车类型：此源表无此字段，置空
    entry_time                                                   AS in_time,      -- 入场时间
    CAST(NULL AS STRING)                                         AS entrance_user_name,  -- 入场操作员：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_pic,       -- 入场图片路径：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way,       -- 入场方式 0正常入场：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way_name,  -- 入场方式名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS small,        -- 小车场内0 否 1是：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS controlip,    -- 入场IP：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS description,  -- 描述：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_no,   -- 车场编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_name,  -- 车场名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_id,       -- 岗亭ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_name,     -- 岗亭名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS operator_name,  -- 操作人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS park_owner,   -- 车场负责人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS phone_mask,   -- 电话号码（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS data_origin,  -- 线下或线上：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS delete_code,  -- 是否已经删除：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS is_load,      -- 1待同步 2 已同步 3同步失败：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS save_time,    -- 保存时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS create_time,  -- 创建时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS cflag,        -- 线下或线上：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_parking_daoer_exit_record_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (5) ods_opr_parking_ketuo_entry_record_di
SELECT
    plate_no                                                     AS car_no,       -- 车牌号
    'ketuo'                                                      AS parking_vendor,  -- 停车厂商
    CAST(cap_place AS STRING)                                    AS parking_lot_code,  -- 停车场编码
    'IN'                                                         AS inout_type,   -- 出入类型
    cap_time                                                     AS inout_time,   -- 出入时间
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,      -- 费用金额：此源表无此字段，置空
    id,                                                                           -- 自增ID
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS object_id,    -- 对象ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_in_id,    -- 入场表ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_id,  -- 控制器编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_name,  -- 入场控制器名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_id,      -- 卡ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS next_car_no,  -- 从车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS correct_car_no,  -- 矫正车牌：此源表无此字段，置空
    SUBSTRING_INDEX(card_no, '#', 1)                             AS card_no_mask,  -- 卡号（脱敏）
    CAST(NULL AS STRING)                                         AS contact_name,  -- 车主名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_type_name,  -- 卡类名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_no_type,  -- 车牌类型：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS card_type_id,  -- 停车类型：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_time,      -- 入场时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_user_name,  -- 入场操作员：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_pic,       -- 入场图片路径：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way,       -- 入场方式 0正常入场：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way_name,  -- 入场方式名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS small,        -- 小车场内0 否 1是：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS controlip,    -- 入场IP：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS description,  -- 描述：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_no,   -- 车场编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_name,  -- 车场名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_id,       -- 岗亭ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_name,     -- 岗亭名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS operator_name,  -- 操作人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS park_owner,   -- 车场负责人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS phone_mask,   -- 电话号码（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS data_origin,  -- 线下或线上：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS delete_code,  -- 是否已经删除：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS is_load,      -- 1待同步 2 已同步 3同步失败：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS save_time,    -- 保存时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS create_time,  -- 创建时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS cflag,        -- 线下或线上：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_parking_ketuo_entry_record_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (6) ods_opr_parking_ketuo_exit_record_di
SELECT
    plate_no                                                     AS car_no,       -- 车牌号
    'ketuo'                                                      AS parking_vendor,  -- 停车厂商
    CAST(cap_place AS STRING)                                    AS parking_lot_code,  -- 停车场编码
    'OUT'                                                        AS inout_type,   -- 出入类型
    cap_time                                                     AS inout_time,   -- 出入时间
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,      -- 费用金额：此源表无此字段，置空
    id,                                                                           -- 自增ID
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS object_id,    -- 对象ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_in_id,    -- 入场表ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_id,  -- 控制器编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_name,  -- 入场控制器名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_id,      -- 卡ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS next_car_no,  -- 从车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS correct_car_no,  -- 矫正车牌：此源表无此字段，置空
    SUBSTRING_INDEX(card_no, '#', 1)                             AS card_no_mask,  -- 卡号（脱敏）
    CAST(NULL AS STRING)                                         AS contact_name,  -- 车主名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_type_name,  -- 卡类名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_no_type,  -- 车牌类型：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS card_type_id,  -- 停车类型：此源表无此字段，置空
    cap_time                                                     AS in_time,      -- 入场时间
    CAST(NULL AS STRING)                                         AS entrance_user_name,  -- 入场操作员：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_pic,       -- 入场图片路径：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way,       -- 入场方式 0正常入场：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way_name,  -- 入场方式名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS small,        -- 小车场内0 否 1是：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS controlip,    -- 入场IP：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS description,  -- 描述：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_no,   -- 车场编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_name,  -- 车场名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_id,       -- 岗亭ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_name,     -- 岗亭名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS operator_name,  -- 操作人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS park_owner,   -- 车场负责人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS phone_mask,   -- 电话号码（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS data_origin,  -- 线下或线上：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS delete_code,  -- 是否已经删除：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS is_load,      -- 1待同步 2 已同步 3同步失败：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS save_time,    -- 保存时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS create_time,  -- 创建时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS cflag,        -- 线下或线上：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_parking_ketuo_exit_record_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (7) ods_opr_parking_shuaichen_entry_record_di
SELECT
    plate_num                                                    AS car_no,       -- 车牌号
    'shuaichen'                                                  AS parking_vendor,  -- 停车厂商
    CAST(park_code AS STRING)                                    AS parking_lot_code,  -- 停车场编码
    'IN'                                                         AS inout_type,   -- 出入类型
    enter_time                                                   AS inout_time,   -- 出入时间
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,      -- 费用金额：此源表无此字段，置空
    id,                                                                           -- 自增ID
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS object_id,    -- 对象ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_in_id,    -- 入场表ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_id,  -- 控制器编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_name,  -- 入场控制器名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_id,      -- 卡ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS next_car_no,  -- 从车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS correct_car_no,  -- 矫正车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_no_mask,  -- 卡号（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS contact_name,  -- 车主名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_type_name,  -- 卡类名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_no_type,  -- 车牌类型：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS card_type_id,  -- 停车类型：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_time,      -- 入场时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_user_name,  -- 入场操作员：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_pic,       -- 入场图片路径：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way,       -- 入场方式 0正常入场：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way_name,  -- 入场方式名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS small,        -- 小车场内0 否 1是：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS controlip,    -- 入场IP：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS description,  -- 描述：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_no,   -- 车场编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_name,  -- 车场名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_id,       -- 岗亭ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_name,     -- 岗亭名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS operator_name,  -- 操作人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS park_owner,   -- 车场负责人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS phone_mask,   -- 电话号码（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS data_origin,  -- 线下或线上：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS delete_code,  -- 是否已经删除：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS is_load,      -- 1待同步 2 已同步 3同步失败：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS save_time,    -- 保存时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS create_time,  -- 创建时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS cflag,        -- 线下或线上：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_parking_shuaichen_entry_record_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (8) ods_opr_parking_shuaichen_exit_record_di
SELECT
    plate_num                                                    AS car_no,       -- 车牌号
    'shuaichen'                                                  AS parking_vendor,  -- 停车厂商
    CAST(park_code AS STRING)                                    AS parking_lot_code,  -- 停车场编码
    'OUT'                                                        AS inout_type,   -- 出入类型
    exit_time                                                    AS inout_time,   -- 出入时间
    CAST(paid_amount AS DECIMAL(18,2)) / 100                     AS fee_amt,      -- 费用金额
    id,                                                                           -- 自增ID
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS object_id,    -- 对象ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_in_id,    -- 入场表ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_id,  -- 控制器编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_name,  -- 入场控制器名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_id,      -- 卡ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS next_car_no,  -- 从车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS correct_car_no,  -- 矫正车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_no_mask,  -- 卡号（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS contact_name,  -- 车主名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_type_name,  -- 卡类名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_no_type,  -- 车牌类型：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS card_type_id,  -- 停车类型：此源表无此字段，置空
    enter_time                                                   AS in_time,      -- 入场时间
    CAST(NULL AS STRING)                                         AS entrance_user_name,  -- 入场操作员：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_pic,       -- 入场图片路径：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way,       -- 入场方式 0正常入场：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way_name,  -- 入场方式名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS small,        -- 小车场内0 否 1是：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS controlip,    -- 入场IP：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS description,  -- 描述：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_no,   -- 车场编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_name,  -- 车场名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_id,       -- 岗亭ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_name,     -- 岗亭名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS operator_name,  -- 操作人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS park_owner,   -- 车场负责人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS phone_mask,   -- 电话号码（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS data_origin,  -- 线下或线上：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS delete_code,  -- 是否已经删除：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS is_load,      -- 1待同步 2 已同步 3同步失败：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS save_time,    -- 保存时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS create_time,  -- 创建时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS cflag,        -- 线下或线上：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_parking_shuaichen_exit_record_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (9) ods_opr_parking_zhihui_entry_record_di
SELECT
    car_no,                                                                       -- 车牌号
    'zhihui'                                                     AS parking_vendor,  -- 停车厂商
    CAST(park_key AS STRING)                                     AS parking_lot_code,  -- 停车场编码
    'IN'                                                         AS inout_type,   -- 出入类型
    enter_time                                                   AS inout_time,   -- 出入时间
    CAST(0 AS DECIMAL(18,2))                                     AS fee_amt,      -- 费用金额：此源表无此字段，置空
    id,                                                                           -- 自增ID
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS object_id,    -- 对象ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_in_id,    -- 入场表ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_id,  -- 控制器编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_name,  -- 入场控制器名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_id,      -- 卡ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS next_car_no,  -- 从车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS correct_car_no,  -- 矫正车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_no_mask,  -- 卡号（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS contact_name,  -- 车主名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_type_name,  -- 卡类名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_no_type,  -- 车牌类型：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS card_type_id,  -- 停车类型：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_time,      -- 入场时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_user_name,  -- 入场操作员：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_pic,       -- 入场图片路径：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way,       -- 入场方式 0正常入场：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way_name,  -- 入场方式名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS small,        -- 小车场内0 否 1是：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS controlip,    -- 入场IP：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS description,  -- 描述：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_no,   -- 车场编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_name,  -- 车场名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_id,       -- 岗亭ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_name,     -- 岗亭名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS operator_name,  -- 操作人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS park_owner,   -- 车场负责人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS phone_mask,   -- 电话号码（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS data_origin,  -- 线下或线上：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS delete_code,  -- 是否已经删除：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS is_load,      -- 1待同步 2 已同步 3同步失败：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS save_time,    -- 保存时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS create_time,  -- 创建时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS cflag,        -- 线下或线上：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_parking_zhihui_entry_record_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (10) ods_opr_parking_zhihui_exit_record_di
SELECT
    car_no,                                                                       -- 车牌号
    'zhihui'                                                     AS parking_vendor,  -- 停车厂商
    CAST(park_key AS STRING)                                     AS parking_lot_code,  -- 停车场编码
    'OUT'                                                        AS inout_type,   -- 出入类型
    out_time                                                     AS inout_time,   -- 出入时间
    CAST(total_amount AS DECIMAL(18,2)) / 100                    AS fee_amt,      -- 费用金额
    id,                                                                           -- 自增ID
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS object_id,    -- 对象ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_in_id,    -- 入场表ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_id,  -- 控制器编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS entrance_name,  -- 入场控制器名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_id,      -- 卡ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS next_car_no,  -- 从车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS correct_car_no,  -- 矫正车牌：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_no_mask,  -- 卡号（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS contact_name,  -- 车主名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_type_name,  -- 卡类名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS car_no_type,  -- 车牌类型：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS card_type_id,  -- 停车类型：此源表无此字段，置空
    enter_time                                                   AS in_time,      -- 入场时间
    CAST(NULL AS STRING)                                         AS entrance_user_name,  -- 入场操作员：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_pic,       -- 入场图片路径：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way,       -- 入场方式 0正常入场：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS in_way_name,  -- 入场方式名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS small,        -- 小车场内0 否 1是：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS controlip,    -- 入场IP：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS description,  -- 描述：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_no,   -- 车场编号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS parking_name,  -- 车场名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_id,       -- 岗亭ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS box_name,     -- 岗亭名称：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS operator_name,  -- 操作人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS park_owner,   -- 车场负责人：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS phone_mask,   -- 电话号码（脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS data_origin,  -- 线下或线上：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS delete_code,  -- 是否已经删除：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS is_load,      -- 1待同步 2 已同步 3同步失败：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS save_time,    -- 保存时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS create_time,  -- 创建时间：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS cflag,        -- 线下或线上：此源表无此字段，置空
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_parking_zhihui_exit_record_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
