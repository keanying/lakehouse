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
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND tnum > 0                                                                -- 旧规则：变更票数为 0 的轨迹不出指标
)
INSERT OVERWRITE TABLE dwd.dwd_ord_order_track_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    t.id                                                             AS track_id,  -- 操作记录ID
    t.ordernum                                                       AS order_no,  -- 订单号
    CASE t.action
        WHEN 0 THEN 'BOOK' WHEN 1 THEN 'MODIFY' WHEN 2 THEN 'CANCEL' WHEN 3 THEN 'PRINT' WHEN 4 THEN 'PAY' WHEN 5 THEN 'VERIFY'
        WHEN 6 THEN 'REVOKE' WHEN 7 THEN 'REVOKE_MODIFY' WHEN 8 THEN 'REPRINT' WHEN 12 THEN 'EXPIRE' WHEN 16 THEN 'ADD_TICKET'
        WHEN 17 THEN 'FINISH' WHEN 33 THEN 'VERIFY'
            WHEN 38 THEN 'AFTER_SALE' ELSE 'OTHER' END                                                     AS track_action,  -- 操作
    t.inserttime                                                     AS action_time,  -- 操作时间
    t.tnum                                                           AS ticket_qty,  -- 本次操作票数
    t.left_num                                                       AS left_ticket_qty,  -- 操作后剩余票数
    CAST(t.tnum * o.sale_price_amt AS DECIMAL(18,2))                 AS sale_amt,  -- 本次操作金额（元）
    CAST(t.tnum * o.cost_price_amt AS DECIMAL(18,2))                 AS cost_amt,  -- 本次操作成本（元）
    -- 待确认：旧系统售后金额取业务库报表 report_checked 预计算，明细里只有 ext_content；JSON 键名上线前与业务库核对
    IF(
        t.action = 38,
        CAST(GET_JSON_OBJECT(t.ext_content, '$.refund_money') AS DECIMAL(18,2)) / 100,
        0
    ) AS refund_amt,                                                              -- 退回金额（元）
    IF(
        t.action = 38,
        CAST(GET_JSON_OBJECT(t.ext_content, '$.service_money') AS DECIMAL(18,2)) / 100,
        0
    ) AS service_fee_amt,                                                         -- 手续费收入（元）
    t.oper_member                                                    AS operator_id,  -- 操作人ID
    CAST(t.terminal AS STRING)                                       AS terminal_no,  -- 操作终端
    o.scenic_id,                                                                  -- 景区ID
    t.tid                                                            AS ticket_id,  -- 票ID
    o.order_role,                                                                 -- 主子单
    o.supplier_id,                                                                -- 供应商ID（租户ID）
    o.distributor_id,                                                             -- 一级分销商ID（订单退化维度）
    o.order_mode,                                                                 -- 下单渠道（订单退化维度）
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
           distributor_id,                                                        -- 一级分销商ID（订单退化维度）
           order_mode,                                                            -- 下单渠道（订单退化维度）
           pay_mode,                                                              -- 支付方式（订单退化维度）
           team_flag,                                                             -- 是否团队订单（订单退化维度）
           taker_province_code,                                                   -- 取票人客源省（订单退化维度）
           taker_city_code,                                                       -- 取票人客源市（订单退化维度）
           taker_district_code,                                                   -- 取票人客源区县（订单退化维度）
           scenic_id,                                                             -- 景区ID
           main_order_no,
           test_flag                                                              -- 是否测试订单
    FROM dwd.dwd_ord_order_di
) o ON o.travel_date = t.order_date AND o.order_no = t.ordernum
