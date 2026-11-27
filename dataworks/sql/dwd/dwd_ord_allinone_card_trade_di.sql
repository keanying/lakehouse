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
INSERT OVERWRITE TABLE dwd.dwd_ord_allinone_card_trade_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- (1) ods_ord_allinone_card_trades_di
SELECT
    'CARD_OP'                                                    AS trade_source,  -- 流水来源
    CAST(id AS BIGINT)                                           AS trade_id,     -- 流水ID
    ordernum                                                     AS trade_no,     -- 交易流水订单号（退款为退款单号）
    CAST(NULL AS STRING)                                         AS related_trade_no,  -- 退款对应的原消费流水号
    CAST(operation_type AS STRING)                               AS trade_type,   -- 交易类型
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 持卡用户ID
    CAST(NULL AS BIGINT)                                         AS counterparty_member_id,  -- 转账接收方用户ID（消费时的收款方）
    CAST(aio_card_id AS BIGINT)                                  AS card_id,      -- 开卡记录ID
    card_no                                                      AS card_no_mask,  -- 实体卡号（ODS 已脱敏）
    CAST(wrist_id AS BIGINT)                                     AS wrist_id,     -- 腕带ID
    CAST(site_id AS BIGINT)                                      AS site_id,      -- 站点ID
    CAST(sub_merchant_id AS BIGINT)                              AS sub_merchant_id,  -- 子商户ID
    CAST(pay_type AS INT)                                        AS pay_type,     -- 支付方式
    CAST(channel AS INT)                                         AS channel,      -- 操作渠道
    CAST(operate_id AS BIGINT)                                   AS operator_id,  -- 操作员ID
    CAST(money AS DECIMAL(18,2)) / 100                           AS trade_amt,    -- 交易金额（元）
    CAST(physical_principal AS DECIMAL(18,2)) / 100              AS principal_amt,  -- 卡本金发生额（元）
    CAST(physical_bonus AS DECIMAL(18,2)) / 100                  AS bonus_amt,    -- 卡奖励金发生额（元）
    CAST(physical_principal_balance AS DECIMAL(18,2)) / 100      AS principal_balance_amt,  -- 交易后卡本金余额（元）
    CAST(physical_bonus_balance AS DECIMAL(18,2)) / 100          AS bonus_balance_amt,  -- 交易后卡奖励金余额（元）
    CAST(NULL AS INT)                                            AS pay_status,   -- 消费支付状态
    CAST(NULL AS INT)                                            AS refund_status,  -- 退款状态
    FROM_UNIXTIME(create_time)                                   AS trade_time,   -- 交易时间
    CAST(o_scenic_id AS BIGINT)                                  AS scenic_id,    -- 景区ID
    CAST(o_ticket_id AS BIGINT)                                  AS ticket_id,    -- 票ID
    CAST(o_pay_mode AS INT)                                      AS order_pay_mode,  -- 订单支付方式（关联订单）
    0                                                            AS prepaid_dup_flag,  -- 卡消费是否与预存卡充值
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT a.*, o.*
        FROM ods.ods_ord_allinone_card_trades_di a                                -- 主表「allinone卡交易（待确认）」
        LEFT JOIN (SELECT order_no, MAX(scenic_id) AS o_scenic_id, MAX(ticket_id) AS o_ticket_id, MAX(pay_mode) AS o_pay_mode
                   FROM dwd.dwd_ord_order_di
                   WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 732), 'yyyyMMdd')  -- 近 2 年订单（同旧缓存表）
                   GROUP BY order_no) o ON o.order_no = a.ordernum                -- 按粒度键汇总
        WHERE a.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
UNION ALL
-- (2) ods_fin_card_order_journal_di
SELECT
    'PAY'                                                        AS trade_source,  -- 流水来源
    CAST(id AS BIGINT)                                           AS trade_id,     -- 流水ID
    ordernum                                                     AS trade_no,     -- 交易流水订单号（退款为退款单号）
    CAST(NULL AS STRING)                                         AS related_trade_no,  -- 退款对应的原消费流水号
    'CONSUME'                                                    AS trade_type,   -- 交易类型
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 持卡用户ID
    CAST(order_member_id AS BIGINT)                              AS counterparty_member_id,  -- 转账接收方用户ID（消费时的收款方）
    CAST(NULL AS BIGINT)                                         AS card_id,      -- 开卡记录ID
    CAST(NULL AS STRING)                                         AS card_no_mask,  -- 实体卡号（ODS 已脱敏）
    CAST(NULL AS BIGINT)                                         AS wrist_id,     -- 腕带ID
    CAST(NULL AS BIGINT)                                         AS site_id,      -- 站点ID
    CAST(NULL AS BIGINT)                                         AS sub_merchant_id,  -- 子商户ID
    CAST(NULL AS INT)                                            AS pay_type,     -- 支付方式
    CAST(NULL AS INT)                                            AS channel,      -- 操作渠道
    CAST(operate_id AS BIGINT)                                   AS operator_id,  -- 操作员ID
    CAST(money AS DECIMAL(18,2)) / 100                           AS trade_amt,    -- 交易金额（元）
    CAST(balance_pay_money AS DECIMAL(18,2)) / 100               AS principal_amt,  -- 卡本金发生额（元）
    CAST(award_pay_money AS DECIMAL(18,2)) / 100                 AS bonus_amt,    -- 卡奖励金发生额（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS principal_balance_amt,  -- 交易后卡本金余额（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS bonus_balance_amt,  -- 交易后卡奖励金余额（元）
    CAST(pay_status AS INT)                                      AS pay_status,   -- 消费支付状态
    CAST(refund_status AS INT)                                   AS refund_status,  -- 退款状态
    FROM_UNIXTIME(create_time)                                   AS trade_time,   -- 交易时间
    CAST(o_scenic_id AS BIGINT)                                  AS scenic_id,    -- 景区ID
    CAST(o_ticket_id AS BIGINT)                                  AS ticket_id,    -- 票ID
    CAST(o_pay_mode AS INT)                                      AS order_pay_mode,  -- 订单支付方式（关联订单）
    COALESCE(dup_flag, 0)                                        AS prepaid_dup_flag,  -- 卡消费是否与预存卡充值
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT a.*, o.*, d.dup_flag
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY update_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
              FROM ods.ods_fin_card_order_journal_di WHERE travel_date = '${bizdate}') a
        LEFT JOIN (SELECT order_no, MAX(scenic_id) AS o_scenic_id, MAX(ticket_id) AS o_ticket_id, MAX(pay_mode) AS o_pay_mode
                   FROM dwd.dwd_ord_order_di
                   WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 732), 'yyyyMMdd')  -- 近 2 年订单（同旧缓存表）
                   GROUP BY order_no) o ON o.order_no = a.ordernum                -- 按粒度键汇总
        LEFT JOIN (SELECT DISTINCT ordernum, 1 AS dup_flag FROM ods.ods_ord_allinone_card_trades_di
                   WHERE travel_date = '${bizdate}' AND pay_type = 4 AND money > 0 AND operation_type <> 18) d  -- 只取当日分区，并按条件过滤
          ON d.ordernum = a.ordernum                                              -- 按 ordernum 关联｜预存卡支付已在卡操作里计过
        WHERE a.rn = 1                                                            -- 只保留每个主键的最新一条
    ) t
UNION ALL
-- (3) ods_fin_card_order_refund_journal_di
SELECT
    'REFUND'                                                     AS trade_source,  -- 流水来源
    CAST(id AS BIGINT)                                           AS trade_id,     -- 流水ID
    refund_order_num                                             AS trade_no,     -- 交易流水订单号（退款为退款单号）
    ordernum                                                     AS related_trade_no,  -- 退款对应的原消费流水号
    'REFUND'                                                     AS trade_type,   -- 交易类型
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 持卡用户ID
    CAST(NULL AS BIGINT)                                         AS counterparty_member_id,  -- 转账接收方用户ID（消费时的收款方）
    CAST(NULL AS BIGINT)                                         AS card_id,      -- 开卡记录ID
    CAST(NULL AS STRING)                                         AS card_no_mask,  -- 实体卡号（ODS 已脱敏）
    CAST(NULL AS BIGINT)                                         AS wrist_id,     -- 腕带ID
    CAST(NULL AS BIGINT)                                         AS site_id,      -- 站点ID
    CAST(NULL AS BIGINT)                                         AS sub_merchant_id,  -- 子商户ID
    CAST(NULL AS INT)                                            AS pay_type,     -- 支付方式
    CAST(NULL AS INT)                                            AS channel,      -- 操作渠道
    CAST(operate_id AS BIGINT)                                   AS operator_id,  -- 操作员ID
    -CAST(refund_money AS DECIMAL(18,2)) / 100                   AS trade_amt,    -- 交易金额（元）
    -CAST(balance_refund_money AS DECIMAL(18,2)) / 100           AS principal_amt,  -- 卡本金发生额（元）
    -CAST(award_refund_money AS DECIMAL(18,2)) / 100             AS bonus_amt,    -- 卡奖励金发生额（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS principal_balance_amt,  -- 交易后卡本金余额（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS bonus_balance_amt,  -- 交易后卡奖励金余额（元）
    CAST(NULL AS INT)                                            AS pay_status,   -- 消费支付状态
    CAST(refund_status AS INT)                                   AS refund_status,  -- 退款状态
    FROM_UNIXTIME(create_time)                                   AS trade_time,   -- 交易时间
    CAST(o_scenic_id AS BIGINT)                                  AS scenic_id,    -- 景区ID
    CAST(o_ticket_id AS BIGINT)                                  AS ticket_id,    -- 票ID
    CAST(o_pay_mode AS INT)                                      AS order_pay_mode,  -- 订单支付方式（关联订单）
    0                                                            AS prepaid_dup_flag,  -- 卡消费是否与预存卡充值
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT a.*, o.*
        FROM ods.ods_fin_card_order_refund_journal_di a                           -- 主表「卡订单退款流水」
        LEFT JOIN (SELECT order_no, MAX(scenic_id) AS o_scenic_id, MAX(ticket_id) AS o_ticket_id, MAX(pay_mode) AS o_pay_mode
                   FROM dwd.dwd_ord_order_di
                   WHERE travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 732), 'yyyyMMdd')  -- 近 2 年订单（同旧缓存表）
                   GROUP BY order_no) o ON o.order_no = a.ordernum                -- 按粒度键汇总
        WHERE a.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
UNION ALL
-- (4) ods_ord_park_card_order_df
SELECT
    'IC_ORDER'                                                   AS trade_source,  -- 流水来源
    CAST(id AS BIGINT)                                           AS trade_id,     -- 流水ID
    ordernum                                                     AS trade_no,     -- 交易流水订单号（退款为退款单号）
    CAST(NULL AS STRING)                                         AS related_trade_no,  -- 退款对应的原消费流水号
    'IC_CARD_BUY'                                                AS trade_type,   -- 交易类型
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 持卡用户ID
    CAST(NULL AS BIGINT)                                         AS counterparty_member_id,  -- 转账接收方用户ID（消费时的收款方）
    CAST(card_id AS BIGINT)                                      AS card_id,      -- 开卡记录ID
    CAST(NULL AS STRING)                                         AS card_no_mask,  -- 实体卡号（ODS 已脱敏）
    CAST(NULL AS BIGINT)                                         AS wrist_id,     -- 腕带ID
    CAST(NULL AS BIGINT)                                         AS site_id,      -- 站点ID
    CAST(NULL AS BIGINT)                                         AS sub_merchant_id,  -- 子商户ID
    CAST(NULL AS INT)                                            AS pay_type,     -- 支付方式
    CAST(NULL AS INT)                                            AS channel,      -- 操作渠道
    CAST(op_id AS BIGINT)                                        AS operator_id,  -- 操作员ID
    CAST(money AS DECIMAL(18,2)) / 100                           AS trade_amt,    -- 交易金额（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS principal_amt,  -- 卡本金发生额（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS bonus_amt,    -- 卡奖励金发生额（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS principal_balance_amt,  -- 交易后卡本金余额（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS bonus_balance_amt,  -- 交易后卡奖励金余额（元）
    CAST(NULL AS INT)                                            AS pay_status,   -- 消费支付状态
    CAST(NULL AS INT)                                            AS refund_status,  -- 退款状态
    FROM_UNIXTIME(order_time)                                    AS trade_time,   -- 交易时间
    CAST(NULL AS BIGINT)                                         AS scenic_id,    -- 景区ID
    CAST(NULL AS BIGINT)                                         AS ticket_id,    -- 票ID
    CAST(NULL AS INT)                                            AS order_pay_mode,  -- 订单支付方式（关联订单）
    0                                                            AS prepaid_dup_flag,  -- 卡消费是否与预存卡充值
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_ord_park_card_order_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
  AND FROM_UNIXTIME(order_time, 'yyyyMMdd') = '${bizdate}'                        -- 全量快照取当日事件
