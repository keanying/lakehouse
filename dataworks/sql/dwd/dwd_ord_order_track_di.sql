-- ================================================================================================
-- dwd.dwd_ord_order_track_di  订单操作明细
-- 粒度：1行=1次订单操作（支付 / 修改 / 取消 / 撤销 / 完结 / 取票 / 售后）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_ord_order_track_di、dwd_ord_order_di
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据中台/DW/dwd_order_track_d_i（EMR_SPARK_SQL，cron 00 00 02 * * ?）
--   · 数据平台/DWS/dws_ord_order_track_wide_di（SERVERLESS_SPARK_SQL，cron 00 45 02 * * ?）
-- 业务规则 / 修正：
--   · 替代 dwd_order_track_d_i、ods_track_tnum_d_i 等：取消 / 撤销 / 完结 / 取票 / 售后票数原来在 5 个脚本各自按 action 拆列
--   · 操作码统一转标准编码（码表 track_action），下游不再写数字码
-- 性能：
--   · 轨迹按操作日增量，一天一分区，只追加不回改
--   · 关联订单带下单日分区条件，触发动态分区裁剪（旧任务全表关联订单宽表）
--   · 订单退化维度在这里一次带齐，DWS 直接聚合
-- ================================================================================================
WITH t AS (
    SELECT id, ordernum, action, tid, tnum, left_num, terminal, oper_member, ext_content, inserttime,
           FROM_UNIXTIME(order_time, 'yyyyMMdd') AS order_date
    FROM ods.ods_ord_order_track_di
    WHERE travel_date = '${bizdate}'
      AND tnum > 0          -- 旧规则：变更票数为 0 的轨迹不出指标
)
INSERT OVERWRITE TABLE dwd.dwd_ord_order_track_di PARTITION (travel_date = '${bizdate}')
SELECT
    t.id                                                             AS track_id,
    t.ordernum                                                       AS order_no,
    CASE t.action
        WHEN 0 THEN 'BOOK' WHEN 1 THEN 'MODIFY' WHEN 2 THEN 'CANCEL' WHEN 3 THEN 'PRINT' WHEN 4 THEN 'PAY' WHEN 5 THEN 'VERIFY'
        WHEN 6 THEN 'REVOKE' WHEN 7 THEN 'REVOKE_MODIFY' WHEN 8 THEN 'REPRINT' WHEN 12 THEN 'EXPIRE' WHEN 16 THEN 'ADD_TICKET'
        WHEN 17 THEN 'FINISH' WHEN 33 THEN 'VERIFY' WHEN 38 THEN 'AFTER_SALE' ELSE 'OTHER' END                                                     AS track_action,
    t.inserttime                                                     AS action_time,
    t.tnum                                                           AS ticket_qty,
    t.left_num                                                       AS left_ticket_qty,
    CAST(t.tnum * o.sale_price_amt AS DECIMAL(18,2))                 AS sale_amt,
    CAST(t.tnum * o.cost_price_amt AS DECIMAL(18,2))                 AS cost_amt,
    -- 待确认：旧系统售后金额取业务库报表 report_checked 预计算，明细里只有 ext_content；JSON 键名上线前与业务库核对
    IF(t.action = 38, CAST(GET_JSON_OBJECT(t.ext_content, '$.refund_money') AS DECIMAL(18,2)) / 100, 0) AS refund_amt,
    IF(t.action = 38, CAST(GET_JSON_OBJECT(t.ext_content, '$.service_money') AS DECIMAL(18,2)) / 100, 0) AS service_fee_amt,
    t.oper_member                                                    AS operator_id,
    CAST(t.terminal AS STRING)                                       AS terminal_no,
    o.scenic_id,
    t.tid                                                            AS ticket_id,
    o.order_role,
    o.supplier_id,
    o.distributor_id,
    o.order_mode,
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
