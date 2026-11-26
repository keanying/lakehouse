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
                ELSE 0 END AS verify_qty,
           GET_JSON_OBJECT(ext_content, '$.card_no') AS card_no
    FROM ods.ods_ord_order_track_di
    WHERE travel_date = '${bizdate}' AND action IN (5, 33) AND tnum > 0
),
traveler AS (   -- 当日核销的游客人数（游客轨迹 track_action=1 为入园核销）
    SELECT ordernum, COUNT(DISTINCT idx) AS traveler_qty
    FROM ods.ods_ord_order_traveler_track_di
    WHERE travel_date = '${bizdate}' AND track_action = 1
    GROUP BY ordernum
)
INSERT OVERWRITE TABLE dwd.dwd_ord_verify_di PARTITION (travel_date = '${bizdate}')
SELECT /*+ BROADCAST(tv) */
    t.id                                                             AS verify_id,
    t.ordernum                                                       AS order_no,
    o.main_order_no,
    o.order_role,
    o.scenic_id,
    t.tid                                                            AS ticket_id,
    o.supplier_id,
    o.distributor_id,
    o.order_mode,
    t.inserttime                                                     AS verify_time,
    t.verify_qty                                                     AS verify_ticket_qty,
    CAST(t.verify_qty * o.sale_price_amt AS DECIMAL(18,2))           AS verify_sale_amt,
    CAST(t.verify_qty * o.cost_price_amt AS DECIMAL(18,2))           AS verify_cost_amt,
    CASE WHEN t.card_no IS NOT NULL THEN 'ANNUAL_CARD'
         WHEN t.action = 33 THEN 'OTA_CALLBACK'                      -- 外部平台回传验证
         ELSE CAST(t.source AS STRING) END                           AS verify_type,
    CAST(t.terminal AS STRING)                                       AS terminal_no,
    CAST(t.branchterminal AS STRING)                                 AS branch_terminal_no,
    t.oper_member                                                    AS operator_id,
    IF(t.card_no IS NOT NULL, 1, 0)                                  AS annual_card_flag,
    COALESCE(tv.traveler_qty, 0)                                     AS traveler_qty,
    o.pay_mode,
    o.team_flag,
    o.taker_province_code,
    o.taker_city_code,
    o.taker_district_code,
    COALESCE(o.test_flag, 0)                                         AS test_flag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM t
-- 关联订单取单价与退化维度：ON 带上下单日分区（ODS 轨迹自带逻辑下单时间），Spark 动态分区裁剪只扫涉及的下单日
LEFT JOIN (
    SELECT order_no, travel_date, sale_price_amt, cost_price_amt, order_role, supplier_id, distributor_id, order_mode, pay_mode,
           team_flag, taker_province_code, taker_city_code, taker_district_code, scenic_id, main_order_no, test_flag
    FROM dwd.dwd_ord_order_di
) o ON o.travel_date = t.order_date AND o.order_no = t.ordernum
LEFT JOIN traveler tv ON tv.ordernum = t.ordernum
WHERE t.verify_qty > 0
