-- ================================================================================================
-- dwd.dwd_ord_verify_di  核销明细
-- 粒度：1行=1次验证（含年卡核销）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_ord_order_track_di、ods_ord_order_traveler_track_di、dwd_ord_order_di
-- 替代旧任务 6 个（上线对数一致后下线）：
--   · 业务工厂/经营数据/验证单表/dwd_order_verify_d_i（EMR_SPARK_SQL，cron 00 00 02 * * ?）
--   · 数据平台/DWD/dwd_ord_verification_detail_di（SERVERLESS_SPARK_SQL，cron 00 40 00 * * ?）
--   · 数据平台/DWD/dwd_ord_traveler_verification_details_di（SERVERLESS_SPARK_SQL，cron 00 43 01 * * ?）
--   · 数据中台/DW/dwd_tourist_verify_d_i（EMR_SPARK_SQL，cron 00 00 02 * * ?）
--   · 数据中台/DW/dwd_tourist_verify_d_i_temp（SERVERLESS_SPARK_SQL，cron 00 15 00 * * ?）
--   · 数据平台/DWS/dws_ord_traveler_verify_log_wide_di（SERVERLESS_SPARK_SQL，cron 00 30 07 * * ?）
-- 业务规则 / 修正：
--   · 替代 dwd_order_verify_d_i、dwd_tourist_verify_d_i 等 7 张
--   · 验证票数规则沿用旧 ods_track_tnum_d_i：action=5 时有 need_write_num 取之，否则非 53/54/32/85 来源取 tnum；action=33 且来源 32/85 取 tnum
--   · 修正：旧 dwd_order_verify_d_i 读的是 pt='pt'（字面量），实际取不到分区
-- 性能：
--   · 只读当日轨迹中的验证动作
--   · 游客核销人数先按订单聚合再关联
-- ================================================================================================
WITH t AS (
    SELECT id, ordernum, action, source, tid, terminal, branchterminal, oper_member, inserttime,
           FROM_UNIXTIME(order_time, 'yyyyMMdd') AS order_date,
           CASE WHEN action = 5 AND CAST(GET_JSON_OBJECT(ext_content, '$.need_write_num') AS INT) > 0
                     THEN CAST(GET_JSON_OBJECT(ext_content, '$.need_write_num') AS INT)
                WHEN (action = 5 AND source NOT IN (53, 54, 32, 85)) OR (action = 33 AND source IN (32, 85)) THEN tnum
                ELSE 0 END AS verify_qty,                                         -- 核销数量
           GET_JSON_OBJECT(ext_content, '$.card_no') AS card_no                   -- 卡编号（脱敏）
    FROM ods.ods_ord_order_track_di
    WHERE travel_date = '${bizdate}' AND action IN (5, 33) AND tnum > 0           -- 只取当日分区，并按条件过滤
),
traveler AS (                                                                     -- 当日核销的游客人数（游客轨迹 track_action=1 为入园核销）
    SELECT ordernum, COUNT(DISTINCT idx) AS traveler_qty                          -- 本次验证游客人数
    FROM ods.ods_ord_order_traveler_track_di
    WHERE travel_date = '${bizdate}' AND track_action = 1                         -- 只取当日分区，并按条件过滤
    GROUP BY ordernum                                                             -- 按粒度键汇总
)
INSERT OVERWRITE TABLE dwd.dwd_ord_verify_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT /*+ BROADCAST(tv) */
    t.id                                                             AS verify_id,  -- 验证记录ID
    t.ordernum                                                       AS order_no,  -- 订单号
    o.main_order_no,                                                              -- 主票订单号
    o.order_role,                                                                 -- 主子单
    o.scenic_id,                                                                  -- 景区ID
    t.tid                                                            AS ticket_id,  -- 票ID
    o.supplier_id,                                                                -- 供应商ID（租户ID）
    o.distributor_id,                                                             -- 一级分销商ID
    o.order_mode,                                                                 -- 下单渠道
    t.inserttime                                                     AS verify_time,  -- 验证时间
    t.verify_qty                                                     AS verify_ticket_qty,  -- 本次验证票数
    CAST(t.verify_qty * o.sale_price_amt AS DECIMAL(18,2))           AS verify_sale_amt,  -- 本次验证金额（元）
    CAST(t.verify_qty * o.cost_price_amt AS DECIMAL(18,2))           AS verify_cost_amt,  -- 本次验证成本（元）
    CASE WHEN t.card_no IS NOT NULL THEN 'ANNUAL_CARD'
         WHEN t.action = 33 THEN 'OTA_CALLBACK'                                   -- 外部平台回传验证
         ELSE CAST(t.source AS STRING) END                           AS verify_type,  -- 验证方式
    CAST(t.source AS INT)                                            AS terminal_type,  -- 验证终端类型（轨迹来源，旧终端过闸报表 terminal_type 同源）
    CAST(t.terminal AS STRING)                                       AS terminal_no,  -- 验证终端号
    CAST(t.branchterminal AS STRING)                                 AS branch_terminal_no,  -- 分终端号
    t.oper_member                                                    AS operator_id,  -- 操作员ID
    IF(t.card_no IS NOT NULL, 1, 0)                                  AS annual_card_flag,  -- 是否年卡核销
    COALESCE(tv.traveler_qty, 0)                                     AS traveler_qty,  -- 本次验证游客人数
    o.pay_mode,                                                                   -- 支付方式（订单退化维度）
    o.team_flag,                                                                  -- 是否团队订单（订单退化维度）
    o.taker_province_code,                                                        -- 取票人客源省（订单退化维度）
    o.taker_city_code,                                                            -- 取票人客源市（订单退化维度）
    o.taker_district_code,                                                        -- 取票人客源区县（订单退化维度）
    COALESCE(o.test_flag, 0)                                         AS test_flag,  -- 是否测试订单
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM t
-- 关联订单取单价与退化维度：ON 带上下单日分区（ODS 轨迹自带逻辑下单时间），Spark 动态分区裁剪只扫涉及的下单日
LEFT JOIN (
    SELECT order_no,                                                              -- 订单号
           travel_date,                                                           -- 数据日期
           sale_price_amt,
           cost_price_amt,
           order_role,                                                            -- 主子单
           supplier_id,                                                           -- 供应商ID（租户ID）
           distributor_id,                                                        -- 一级分销商ID
           order_mode,                                                            -- 下单渠道
           pay_mode,                                                              -- 支付方式（订单退化维度）
           team_flag,                                                             -- 是否团队订单（订单退化维度）
           taker_province_code,                                                   -- 取票人客源省（订单退化维度）
           taker_city_code,                                                       -- 取票人客源市（订单退化维度）
           taker_district_code,                                                   -- 取票人客源区县（订单退化维度）
           scenic_id,                                                             -- 景区ID
           main_order_no,                                                         -- 主票订单号
           test_flag                                                              -- 是否测试订单
    FROM dwd.dwd_ord_order_di
) o ON o.travel_date = t.order_date AND o.order_no = t.ordernum
LEFT JOIN traveler tv ON tv.ordernum = t.ordernum
WHERE t.verify_qty > 0
