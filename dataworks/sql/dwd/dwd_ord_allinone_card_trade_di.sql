-- ================================================================================================
-- dwd.dwd_ord_allinone_card_trade_di  园区一卡通交易明细
-- 粒度：1行=1笔一卡通交易（购卡 / 充值 / 工本费 / 押金 / 消费 / 退款）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_ord_allinone_card_trades_di、ods_fin_card_order_journal_di、ods_fin_card_order_refund_journal_di、ods_ord_park_card_order_df、dwd_ord_order_di
-- 业务规则 / 修正：
--   · 四类流水 UNION ALL（IC 卡购卡订单为全量快照，按下单日取当日）；金额统一分 → 元、退款取负，SUM 即净额；消费笔数统计时过滤 pay_status = 2（已支付）、退款过滤 refund_status = 2（成功）
--   · 旧系统 dws_tps_aioc_summary_* 把 operation1~10 做成透视列，这里保留 trade_type 一列，DWS 按行汇总
--   · 景区 / 票 / 订单支付方式按订单号关联近 2 年订单明细（同旧缓存表口径）；卡消费口径同旧系统：pay_status <> 3、排除 CMB 开头流水、排除预存卡已计的重复支付
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_ord_allinone_card_trade_di PARTITION (travel_date = '${bizdate}')
-- (1) ods_ord_allinone_card_trades_di
SELECT
    'CARD_OP'                                                    AS trade_source,
    CAST(id AS BIGINT)                                           AS trade_id,
    ordernum                                                     AS trade_no,
    CAST(NULL AS STRING)                                         AS related_trade_no,
    CAST(operation_type AS STRING)                               AS trade_type,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(member_id AS BIGINT)                                    AS member_id,
    CAST(NULL AS BIGINT)                                         AS counterparty_member_id,
    CAST(aio_card_id AS BIGINT)                                  AS card_id,
    card_no                                                      AS card_no_mask,
    CAST(wrist_id AS BIGINT)                                     AS wrist_id,
    CAST(site_id AS BIGINT)                                      AS site_id,
    CAST(sub_merchant_id AS BIGINT)                              AS sub_merchant_id,
    CAST(pay_type AS INT)                                        AS pay_type,
    CAST(channel AS INT)                                         AS channel,
    CAST(operate_id AS BIGINT)                                   AS operator_id,
    CAST(money AS DECIMAL(18,2)) / 100                           AS trade_amt,
    CAST(physical_principal AS DECIMAL(18,2)) / 100              AS principal_amt,
    CAST(physical_bonus AS DECIMAL(18,2)) / 100                  AS bonus_amt,
    CAST(physical_principal_balance AS DECIMAL(18,2)) / 100      AS principal_balance_amt,
    CAST(physical_bonus_balance AS DECIMAL(18,2)) / 100          AS bonus_balance_amt,
    CAST(NULL AS INT)                                            AS pay_status,
    CAST(NULL AS INT)                                            AS refund_status,
    FROM_UNIXTIME(create_time)                                   AS trade_time,
    CAST(o_scenic_id AS BIGINT)                                  AS scenic_id,
    CAST(o_ticket_id AS BIGINT)                                  AS ticket_id,
    CAST(o_pay_mode AS INT)                                      AS order_pay_mode,
    0                                                            AS prepaid_dup_flag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT a.*, o.*
        FROM ods.ods_ord_allinone_card_trades_di a
        LEFT JOIN (SELECT order_no, MAX(scenic_id) AS o_scenic_id, MAX(ticket_id) AS o_ticket_id, MAX(pay_mode) AS o_pay_mode
                   FROM dwd.dwd_ord_order_di
                   WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 732), 'yyyyMMdd')   -- 近 2 年订单（同旧缓存表）
                   GROUP BY order_no) o ON o.order_no = a.ordernum
        WHERE a.travel_date = '${bizdate}'
    ) t
UNION ALL
-- (2) ods_fin_card_order_journal_di
SELECT
    'PAY'                                                        AS trade_source,
    CAST(id AS BIGINT)                                           AS trade_id,
    ordernum                                                     AS trade_no,
    CAST(NULL AS STRING)                                         AS related_trade_no,
    'CONSUME'                                                    AS trade_type,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(member_id AS BIGINT)                                    AS member_id,
    CAST(order_member_id AS BIGINT)                              AS counterparty_member_id,
    CAST(NULL AS BIGINT)                                         AS card_id,
    CAST(NULL AS STRING)                                         AS card_no_mask,
    CAST(NULL AS BIGINT)                                         AS wrist_id,
    CAST(NULL AS BIGINT)                                         AS site_id,
    CAST(NULL AS BIGINT)                                         AS sub_merchant_id,
    CAST(NULL AS INT)                                            AS pay_type,
    CAST(NULL AS INT)                                            AS channel,
    CAST(operate_id AS BIGINT)                                   AS operator_id,
    CAST(money AS DECIMAL(18,2)) / 100                           AS trade_amt,
    CAST(balance_pay_money AS DECIMAL(18,2)) / 100               AS principal_amt,
    CAST(award_pay_money AS DECIMAL(18,2)) / 100                 AS bonus_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS principal_balance_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS bonus_balance_amt,
    CAST(pay_status AS INT)                                      AS pay_status,
    CAST(refund_status AS INT)                                   AS refund_status,
    FROM_UNIXTIME(create_time)                                   AS trade_time,
    CAST(o_scenic_id AS BIGINT)                                  AS scenic_id,
    CAST(o_ticket_id AS BIGINT)                                  AS ticket_id,
    CAST(o_pay_mode AS INT)                                      AS order_pay_mode,
    COALESCE(dup_flag, 0)                                        AS prepaid_dup_flag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT a.*, o.*, d.dup_flag
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY update_time DESC) AS rn
              FROM ods.ods_fin_card_order_journal_di WHERE travel_date = '${bizdate}') a
        LEFT JOIN (SELECT order_no, MAX(scenic_id) AS o_scenic_id, MAX(ticket_id) AS o_ticket_id, MAX(pay_mode) AS o_pay_mode
                   FROM dwd.dwd_ord_order_di
                   WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 732), 'yyyyMMdd')   -- 近 2 年订单（同旧缓存表）
                   GROUP BY order_no) o ON o.order_no = a.ordernum
        LEFT JOIN (SELECT DISTINCT ordernum, 1 AS dup_flag FROM ods.ods_ord_allinone_card_trades_di
                   WHERE travel_date = '${bizdate}' AND pay_type = 4 AND money > 0 AND operation_type <> 18) d
          ON d.ordernum = a.ordernum      -- 预存卡支付已在卡操作里计过
        WHERE a.rn = 1
    ) t
UNION ALL
-- (3) ods_fin_card_order_refund_journal_di
SELECT
    'REFUND'                                                     AS trade_source,
    CAST(id AS BIGINT)                                           AS trade_id,
    refund_order_num                                             AS trade_no,
    ordernum                                                     AS related_trade_no,
    'REFUND'                                                     AS trade_type,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(member_id AS BIGINT)                                    AS member_id,
    CAST(NULL AS BIGINT)                                         AS counterparty_member_id,
    CAST(NULL AS BIGINT)                                         AS card_id,
    CAST(NULL AS STRING)                                         AS card_no_mask,
    CAST(NULL AS BIGINT)                                         AS wrist_id,
    CAST(NULL AS BIGINT)                                         AS site_id,
    CAST(NULL AS BIGINT)                                         AS sub_merchant_id,
    CAST(NULL AS INT)                                            AS pay_type,
    CAST(NULL AS INT)                                            AS channel,
    CAST(operate_id AS BIGINT)                                   AS operator_id,
    -CAST(refund_money AS DECIMAL(18,2)) / 100                   AS trade_amt,
    -CAST(balance_refund_money AS DECIMAL(18,2)) / 100           AS principal_amt,
    -CAST(award_refund_money AS DECIMAL(18,2)) / 100             AS bonus_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS principal_balance_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS bonus_balance_amt,
    CAST(NULL AS INT)                                            AS pay_status,
    CAST(refund_status AS INT)                                   AS refund_status,
    FROM_UNIXTIME(create_time)                                   AS trade_time,
    CAST(o_scenic_id AS BIGINT)                                  AS scenic_id,
    CAST(o_ticket_id AS BIGINT)                                  AS ticket_id,
    CAST(o_pay_mode AS INT)                                      AS order_pay_mode,
    0                                                            AS prepaid_dup_flag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT a.*, o.*
        FROM ods.ods_fin_card_order_refund_journal_di a
        LEFT JOIN (SELECT order_no, MAX(scenic_id) AS o_scenic_id, MAX(ticket_id) AS o_ticket_id, MAX(pay_mode) AS o_pay_mode
                   FROM dwd.dwd_ord_order_di
                   WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 732), 'yyyyMMdd')   -- 近 2 年订单（同旧缓存表）
                   GROUP BY order_no) o ON o.order_no = a.ordernum
        WHERE a.travel_date = '${bizdate}'
    ) t
UNION ALL
-- (4) ods_ord_park_card_order_df
SELECT
    'IC_ORDER'                                                   AS trade_source,
    CAST(id AS BIGINT)                                           AS trade_id,
    ordernum                                                     AS trade_no,
    CAST(NULL AS STRING)                                         AS related_trade_no,
    'IC_CARD_BUY'                                                AS trade_type,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(member_id AS BIGINT)                                    AS member_id,
    CAST(NULL AS BIGINT)                                         AS counterparty_member_id,
    CAST(card_id AS BIGINT)                                      AS card_id,
    CAST(NULL AS STRING)                                         AS card_no_mask,
    CAST(NULL AS BIGINT)                                         AS wrist_id,
    CAST(NULL AS BIGINT)                                         AS site_id,
    CAST(NULL AS BIGINT)                                         AS sub_merchant_id,
    CAST(NULL AS INT)                                            AS pay_type,
    CAST(NULL AS INT)                                            AS channel,
    CAST(op_id AS BIGINT)                                        AS operator_id,
    CAST(money AS DECIMAL(18,2)) / 100                           AS trade_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS principal_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS bonus_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS principal_balance_amt,
    CAST(NULL AS DECIMAL(18,2))                                  AS bonus_balance_amt,
    CAST(NULL AS INT)                                            AS pay_status,
    CAST(NULL AS INT)                                            AS refund_status,
    FROM_UNIXTIME(order_time)                                    AS trade_time,
    CAST(NULL AS BIGINT)                                         AS scenic_id,
    CAST(NULL AS BIGINT)                                         AS ticket_id,
    CAST(NULL AS INT)                                            AS order_pay_mode,
    0                                                            AS prepaid_dup_flag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_ord_park_card_order_df
WHERE travel_date = '${bizdate}'
  AND FROM_UNIXTIME(order_time, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
