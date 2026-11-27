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
INSERT OVERWRITE TABLE dwd.dwd_opr_retail_order_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- (1) ods_opr_retail_sixun_order_di
SELECT
    shop_code,                                                                    -- 销售门店号
    order_no,                                                                     -- 销售订单号
    CAST(payment_money AS DECIMAL(18,2))                         AS sale_amt,     -- 销售金额
    'sixun'                                                      AS retail_vendor,  -- 零售厂商
    CAST(NULL AS STRING)                                         AS goods_code,   -- 商品编码｜待确认：来源未同步
    CAST(NULL AS BIGINT)                                         AS item_qty,     -- 明细项数量
    CAST(NULL AS DECIMAL(18,2))                                  AS profit_amt,   -- profit金额（待确认）
    IF(status = '2', 1, 0)                                       AS refund_flag,  -- 退款标志
    id,                                                                           -- 主键
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    status                                                       AS order_status,  -- 是否有效
    payment_money                                                AS pay_amt,      -- 支付金额
    settlement_money                                             AS settlement_amt,  -- 实收金额
    table_number,                                                                 -- 座号
    number_of_people,                                                             -- 人数
    pos_name,                                                                     -- POS机名称
    operator,                                                                     -- 操作人员
    create_time,                                                                  -- 创建时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_retail_sixun_order_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (2) ods_opr_retail_yinbao_ticket_di
SELECT
    CAST(app_id AS STRING)                                       AS shop_code,    -- 销售门店号
    sn                                                           AS order_no,     -- 销售订单号
    CAST(total_amount AS DECIMAL(18,2))                          AS sale_amt,     -- 销售金额
    'yinbao'                                                     AS retail_vendor,  -- 零售厂商
    CAST(NULL AS STRING)                                         AS goods_code,   -- 商品编码
    CAST(NULL AS BIGINT)                                         AS item_qty,     -- 明细项数量
    CAST(total_profit AS DECIMAL(18,2))                          AS profit_amt,   -- profit金额（待确认）
    IF(ticket_type = 'SELL_RETURN', 1, 0)                        AS refund_flag,  -- 退款标志
    id,                                                                           -- 主键
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS order_status,  -- 是否有效
    CAST(NULL AS DECIMAL(10,2))                                  AS pay_amt,      -- 支付金额
    CAST(NULL AS DECIMAL(10,2))                                  AS settlement_amt,  -- 实收金额
    CAST(NULL AS STRING)                                         AS table_number,  -- 座号
    CAST(NULL AS BIGINT)                                         AS number_of_people,  -- 人数
    CAST(NULL AS STRING)                                         AS pos_name,     -- POS机名称
    CAST(NULL AS STRING)                                         AS operator,     -- 操作人员
    date_time                                                    AS create_time,  -- 创建时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_retail_yinbao_ticket_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
UNION ALL
-- (3) ods_opr_retail_xisland_order_di
SELECT
    store_name                                                   AS shop_code,    -- 销售门店号
    order_code                                                   AS order_no,     -- 销售订单号
    CAST(pay_amount AS DECIMAL(18,2))                            AS sale_amt,     -- 销售金额
    'xisland'                                                    AS retail_vendor,  -- 零售厂商
    CAST(NULL AS STRING)                                         AS goods_code,   -- 商品编码
    CAST(NULL AS BIGINT)                                         AS item_qty,     -- 明细项数量
    CAST(NULL AS DECIMAL(18,2))                                  AS profit_amt,   -- profit金额（待确认）
    IF(CAST(return_amount AS DECIMAL(18,2)) > 0, 1, 0)           AS refund_flag,  -- 退款标志
    id,                                                                           -- 主键
    con_sys_bind,                                                                 -- 绑定ID
    member_id,                                                                    -- 供应商ID
    CAST(NULL AS STRING)                                         AS order_status,  -- 是否有效
    pay_amount                                                   AS pay_amt,      -- 支付金额
    CAST(NULL AS DECIMAL(10,2))                                  AS settlement_amt,  -- 实收金额
    CAST(NULL AS STRING)                                         AS table_number,  -- 座号
    CAST(NULL AS BIGINT)                                         AS number_of_people,  -- 人数
    CAST(NULL AS STRING)                                         AS pos_name,     -- POS机名称
    CAST(NULL AS STRING)                                         AS operator,     -- 操作人员
    order_create_time                                            AS create_time,  -- 创建时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY sync_update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_opr_retail_xisland_order_di
        WHERE travel_date = '${bizdate}'                                          -- 只取当日分区
    ) t
WHERE rn = 1                                                                      -- 同一记录当日多次变更取最新
