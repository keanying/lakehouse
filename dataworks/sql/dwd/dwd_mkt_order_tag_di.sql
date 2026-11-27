-- ================================================================================================
-- dwd.dwd_mkt_order_tag_di  订单营销标签
-- 粒度：1行=1张订单×1个营销方式（当日下单）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：dwd_mkt_seckill_di、dwd_mkt_cut_price_di、dwd_mkt_group_booking_di、dwd_mkt_coupon_use_di、dwd_trf_promoter_order_df、dwd_prd_resource_order_di、dwd_ord_allinone_card_trade_di、dwd_ord_annual_card_trade_di、ods_ord_external_code_order_df、dwd_ord_order_di
-- 业务规则 / 修正：
--   · 各营销业务过程按订单号对齐当日下单的订单（预订口径同 dws_ord_scenic_ticket_trade_di）；一张订单可同时有多个营销方式，按营销方式汇总时不可跨类型相加
--   · 待确认：旧「新媒体」标签按 6 个固定账号判定（硬编码），未纳入；如仍需要请提供账号配置表
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_mkt_order_tag_di PARTITION (travel_date = '${bizdate}')
-- (1) dwd_mkt_seckill_di
SELECT
    order_no,
    marketing_type,
    CAST(supplier_id AS BIGINT)                                  AS supplier_id,
    CAST(scenic_id AS BIGINT)                                    AS scenic_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(distributor_id AS BIGINT)                               AS distributor_id,
    CAST(order_mode AS INT)                                      AS order_mode,
    order_role,
    CAST(origin_ticket_qty AS BIGINT)                            AS ticket_qty,
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS sale_amt,
    order_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT o.*, x.marketing_type
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT order_no, 'SECKILL' AS marketing_type FROM dwd.dwd_mkt_seckill_di WHERE travel_date = '${bizdate}' AND success_flag = 1) x
          ON x.order_no = o.order_no
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0 AND o.pay_status <> '2'      -- 同预订口径：当日下单、已支付、非测试
    ) t
UNION ALL
-- (2) dwd_mkt_cut_price_di
SELECT
    order_no,
    marketing_type,
    CAST(supplier_id AS BIGINT)                                  AS supplier_id,
    CAST(scenic_id AS BIGINT)                                    AS scenic_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(distributor_id AS BIGINT)                               AS distributor_id,
    CAST(order_mode AS INT)                                      AS order_mode,
    order_role,
    CAST(origin_ticket_qty AS BIGINT)                            AS ticket_qty,
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS sale_amt,
    order_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT o.*, x.marketing_type
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT order_no, 'CUT_PRICE' AS marketing_type FROM dwd.dwd_mkt_cut_price_di WHERE travel_date = '${bizdate}' AND COALESCE(order_no, '') <> '') x
          ON x.order_no = o.order_no
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0 AND o.pay_status <> '2'      -- 同预订口径：当日下单、已支付、非测试
    ) t
UNION ALL
-- (3) dwd_mkt_group_booking_di
SELECT
    order_no,
    marketing_type,
    CAST(supplier_id AS BIGINT)                                  AS supplier_id,
    CAST(scenic_id AS BIGINT)                                    AS scenic_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(distributor_id AS BIGINT)                               AS distributor_id,
    CAST(order_mode AS INT)                                      AS order_mode,
    order_role,
    CAST(origin_ticket_qty AS BIGINT)                            AS ticket_qty,
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS sale_amt,
    order_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT o.*, x.marketing_type
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT order_no, 'GROUP_BOOKING' AS marketing_type FROM dwd.dwd_mkt_group_booking_di WHERE travel_date = '${bizdate}') x
          ON x.order_no = o.order_no
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0 AND o.pay_status <> '2'      -- 同预订口径：当日下单、已支付、非测试
    ) t
UNION ALL
-- (4) dwd_mkt_coupon_use_di
SELECT
    order_no,
    marketing_type,
    CAST(supplier_id AS BIGINT)                                  AS supplier_id,
    CAST(scenic_id AS BIGINT)                                    AS scenic_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(distributor_id AS BIGINT)                               AS distributor_id,
    CAST(order_mode AS INT)                                      AS order_mode,
    order_role,
    CAST(origin_ticket_qty AS BIGINT)                            AS ticket_qty,
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS sale_amt,
    order_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT o.*, x.marketing_type
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT order_no, 'COUPON' AS marketing_type FROM dwd.dwd_mkt_coupon_use_di WHERE travel_date = '${bizdate}' AND use_status <> 3) x
          ON x.order_no = o.order_no
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0 AND o.pay_status <> '2'      -- 同预订口径：当日下单、已支付、非测试
    ) t
UNION ALL
-- (5) dwd_trf_promoter_order_df
SELECT
    order_no,
    marketing_type,
    CAST(supplier_id AS BIGINT)                                  AS supplier_id,
    CAST(scenic_id AS BIGINT)                                    AS scenic_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(distributor_id AS BIGINT)                               AS distributor_id,
    CAST(order_mode AS INT)                                      AS order_mode,
    order_role,
    CAST(origin_ticket_qty AS BIGINT)                            AS ticket_qty,
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS sale_amt,
    order_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT o.*, x.marketing_type
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT order_no, IF(promote_source = 'ALL_DIS', 'ALL_DIS', 'DISTRIBUTOR') AS marketing_type FROM dwd.dwd_trf_promoter_order_df WHERE travel_date = '${bizdate}' AND delete_flag = 0) x
          ON x.order_no = o.order_no
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0 AND o.pay_status <> '2'      -- 同预订口径：当日下单、已支付、非测试
    ) t
UNION ALL
-- (6) dwd_prd_resource_order_di
SELECT
    order_no,
    marketing_type,
    CAST(supplier_id AS BIGINT)                                  AS supplier_id,
    CAST(scenic_id AS BIGINT)                                    AS scenic_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(distributor_id AS BIGINT)                               AS distributor_id,
    CAST(order_mode AS INT)                                      AS order_mode,
    order_role,
    CAST(origin_ticket_qty AS BIGINT)                            AS ticket_qty,
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS sale_amt,
    order_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT o.*, x.marketing_type
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT order_no, 'RESOURCE_CENTER' AS marketing_type FROM dwd.dwd_prd_resource_order_di WHERE travel_date = '${bizdate}') x
          ON x.order_no = o.order_no
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0 AND o.pay_status <> '2'      -- 同预订口径：当日下单、已支付、非测试
    ) t
UNION ALL
-- (7) dwd_ord_allinone_card_trade_di
SELECT
    order_no,
    marketing_type,
    CAST(supplier_id AS BIGINT)                                  AS supplier_id,
    CAST(scenic_id AS BIGINT)                                    AS scenic_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(distributor_id AS BIGINT)                               AS distributor_id,
    CAST(order_mode AS INT)                                      AS order_mode,
    order_role,
    CAST(origin_ticket_qty AS BIGINT)                            AS ticket_qty,
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS sale_amt,
    order_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT o.*, x.marketing_type
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT trade_no AS order_no, 'PARK_CARD' AS marketing_type FROM dwd.dwd_ord_allinone_card_trade_di WHERE travel_date = '${bizdate}' AND trade_source = 'PAY') x
          ON x.order_no = o.order_no
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0 AND o.pay_status <> '2'      -- 同预订口径：当日下单、已支付、非测试
    ) t
UNION ALL
-- (8) dwd_ord_annual_card_trade_di
SELECT
    order_no,
    marketing_type,
    CAST(supplier_id AS BIGINT)                                  AS supplier_id,
    CAST(scenic_id AS BIGINT)                                    AS scenic_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(distributor_id AS BIGINT)                               AS distributor_id,
    CAST(order_mode AS INT)                                      AS order_mode,
    order_role,
    CAST(origin_ticket_qty AS BIGINT)                            AS ticket_qty,
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS sale_amt,
    order_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT o.*, x.marketing_type
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT order_no, 'ANNUAL_CARD' AS marketing_type FROM dwd.dwd_ord_annual_card_trade_di WHERE travel_date = '${bizdate}' AND COALESCE(order_no, '') <> '') x
          ON x.order_no = o.order_no
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0 AND o.pay_status <> '2'      -- 同预订口径：当日下单、已支付、非测试
    ) t
UNION ALL
-- (9) ods_ord_external_code_order_df
SELECT
    order_no,
    marketing_type,
    CAST(supplier_id AS BIGINT)                                  AS supplier_id,
    CAST(scenic_id AS BIGINT)                                    AS scenic_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(distributor_id AS BIGINT)                               AS distributor_id,
    CAST(order_mode AS INT)                                      AS order_mode,
    order_role,
    CAST(origin_ticket_qty AS BIGINT)                            AS ticket_qty,
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS sale_amt,
    order_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT o.*, x.marketing_type
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT ordernum AS order_no, 'EXTERNAL_CODE' AS marketing_type FROM ods.ods_ord_external_code_order_df WHERE travel_date = '${bizdate}' AND state = 1) x
          ON x.order_no = o.order_no
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0 AND o.pay_status <> '2'      -- 同预订口径：当日下单、已支付、非测试
    ) t
