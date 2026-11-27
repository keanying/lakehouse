-- ================================================================================================
-- dwd.dwd_ord_mps_detail_di  商户视角经营明细
-- 粒度：1行=1次订单操作（业务单号）×本方商户
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_ord_report_dwm_common_di
-- 业务规则 / 修正：
--   · 报表库 dwm_common 是逐笔操作明细（不是汇总），优惠金额、买卖双方手续费、重打印只有这里有；作为业务过程来源，不再只用于对数
--   · 金额单位分 → 元；同一业务单号当日多次同步取最新（按 created_at）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_ord_mps_detail_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(business_no AS BIGINT)                                  AS business_no,  -- 业务单号（一次操作一条）
    CAST(merchant_id AS BIGINT)                                  AS member_id,    -- 本方商户ID（「我」视角）
    CAST(parent_merchant_id AS BIGINT)                           AS supplier_id,  -- 供应商ID（租户ID）
    CAST(distributor_id AS BIGINT)                               AS distributor_id,  -- 下级商户（卖出对象）ID
    order_no,                                                                     -- 订单号
    parent_order_no,                                                              -- 主订单号
    trade_no,                                                                     -- 交易单号
    CAST(operate_type AS INT)                                    AS operate_type,  -- 操作类型
    product_type,                                                                 -- 产品类型
    CAST(spu_id AS BIGINT)                                       AS product_id,   -- 产品ID
    CAST(sku_id AS BIGINT)                                       AS ticket_id,    -- 票ID
    CAST(poi_id AS BIGINT)                                       AS poi_id,       -- POI ID
    CAST(sale_channel AS INT)                                    AS order_mode,   -- 销售渠道
    CAST(operate_channel AS INT)                                 AS operate_channel,  -- 操作渠道
    CAST(sale_pay_mode AS INT)                                   AS pay_mode,     -- 销售支付方式
    CAST(cost_pay_mode AS INT)                                   AS cost_pay_mode,  -- 采购支付方式
    CAST(pack_type AS INT)                                       AS pack_type,    -- 套票规则
    CAST(sell_operator_id AS BIGINT)                             AS sell_operator_id,  -- 售票员ID
    CAST(operator_id AS BIGINT)                                  AS operator_id,  -- 操作人ID
    CAST(sell_site_id AS BIGINT)                                 AS sell_site_id,  -- 售票站点
    CAST(operate_site_id AS BIGINT)                              AS operate_site_id,  -- 操作站点
    CAST(cost_unit_price AS DECIMAL(18,2)) / 100                 AS cost_unit_price,  -- 采购单价（元）
    CAST(sale_unit_price AS DECIMAL(18,2)) / 100                 AS sale_unit_price,  -- 销售单价（元）
    CAST(pay_count AS BIGINT)                                    AS pay_qty,      -- 预订数量
    CAST(pay_cost_price AS DECIMAL(18,2)) / 100                  AS pay_cost_amt,  -- 预订采购金额
    CAST(pay_cost_discount_price AS DECIMAL(18,2)) / 100         AS pay_cost_discount_amt,  -- 预订采购优惠（元）
    CAST(pay_sale_price AS DECIMAL(18,2)) / 100                  AS pay_sale_amt,  -- 预订销售金额
    CAST(pay_sale_discount_price AS DECIMAL(18,2)) / 100         AS pay_sale_discount_amt,  -- 预订销售优惠（元）
    CAST(verify_count AS BIGINT)                                 AS verify_qty,   -- 核销数量
    CAST(verify_cost_price AS DECIMAL(18,2)) / 100               AS verify_cost_amt,  -- 核销采购金额
    CAST(verify_cost_discount_price AS DECIMAL(18,2)) / 100      AS verify_cost_discount_amt,  -- 核销采购优惠（元）
    CAST(verify_sale_price AS DECIMAL(18,2)) / 100               AS verify_sale_amt,  -- 核销销售金额
    CAST(verify_sale_discount_price AS DECIMAL(18,2)) / 100      AS verify_sale_discount_amt,  -- 核销销售优惠（元）
    CAST(cancel_count AS BIGINT)                                 AS cancel_qty,   -- 取消数量
    CAST(cancel_cost_price AS DECIMAL(18,2)) / 100               AS cancel_cost_amt,  -- 取消采购金额
    CAST(cancel_cost_discount_price AS DECIMAL(18,2)) / 100      AS cancel_cost_discount_amt,  -- 取消采购优惠（元）
    CAST(cancel_sale_price AS DECIMAL(18,2)) / 100               AS cancel_sale_amt,  -- 取消销售金额
    CAST(cancel_sale_discount_price AS DECIMAL(18,2)) / 100      AS cancel_sale_discount_amt,  -- 取消销售优惠（元）
    CAST(cancel_cost_fee AS DECIMAL(18,2)) / 100                 AS cancel_cost_fee_amt,  -- 取消采购手续费（元）
    CAST(cancel_sale_fee AS DECIMAL(18,2)) / 100                 AS cancel_sale_fee_amt,  -- 取消销售手续费（元）
    CAST(revoke_count AS BIGINT)                                 AS revoke_qty,   -- 撤销数量
    CAST(revoke_cost_price AS DECIMAL(18,2)) / 100               AS revoke_cost_amt,  -- 撤销采购金额
    CAST(revoke_cost_discount_price AS DECIMAL(18,2)) / 100      AS revoke_cost_discount_amt,  -- 撤销采购优惠（元）
    CAST(revoke_sale_price AS DECIMAL(18,2)) / 100               AS revoke_sale_amt,  -- 撤销销售金额
    CAST(revoke_sale_discount_price AS DECIMAL(18,2)) / 100      AS revoke_sale_discount_amt,  -- 撤销销售优惠（元）
    CAST(revoke_cost_fee AS DECIMAL(18,2)) / 100                 AS revoke_cost_fee_amt,  -- 撤销采购手续费（元）
    CAST(revoke_sale_fee AS DECIMAL(18,2)) / 100                 AS revoke_sale_fee_amt,  -- 撤销销售手续费（元）
    CAST(after_sale_count AS BIGINT)                             AS after_sale_qty,  -- 售后数量
    CAST(after_cost_price AS DECIMAL(18,2)) / 100                AS after_sale_cost_amt,  -- 售后采购金额（元）
    CAST(after_sale_price AS DECIMAL(18,2)) / 100                AS after_sale_sale_amt,  -- 售后销售金额（元）
    CAST(collect_count AS BIGINT)                                AS collect_qty,  -- 取票数量
    CAST(reprint_count AS BIGINT)                                AS reprint_qty,  -- 重打印数量
    operated_at                                                  AS operate_time,  -- 操作时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT *
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY business_no, merchant_id ORDER BY created_at DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
              FROM ods.ods_ord_report_dwm_common_di WHERE travel_date = '${bizdate}') d
        WHERE d.rn = 1                                                            -- 同一业务单号 × 商户重复同步取最新
    ) t
