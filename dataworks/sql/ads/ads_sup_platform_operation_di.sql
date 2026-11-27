-- ================================================================================================
-- ads.ads_sup_platform_operation_di  平台经营（内部）
-- 粒度：1行=1天×商户
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dws_sup_member_di、dws_ord_scenic_ticket_trade_di
-- 性能：
--   · ADS 只存日粒度：周 / 月 / 年 / 节假日 / 自定义区间与同比环比在查询时关联 dim_opr_period_f（见「指标口径 · ADS 业务指标」）
--   · 比率类不落比率值，只存分子分母；去重类存位图；快照类取日终值
--   · 多个上游各自预聚合后 UNION ALL，按 ADS 粒度合并（替代旧系统多表 FULL JOIN）
-- ================================================================================================
-- 补 0 / 补空列：多来源 UNION ALL 时，某来源不产出的指标补 0 或空，外层按粒度 SUM 后即为各来源之和，不影响结果
-- 取 -1 的维度列：该来源没有这个维度（如核销来源没有下单渠道），用 -1 表示「不适用」，按该维度分析时只看产出它的来源
INSERT OVERWRITE TABLE ads.ads_sup_platform_operation_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    member_id,                                                                    -- 商户ID
    BITMAP_UNION(login_member_bitmap)                            AS login_member_bitmap,  -- 登录商户数去重位图（日）
    SUM(module_open_qty)                                         AS module_open_qty,  -- 模块开通数（日）
    SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额（日）
    SUM(pay_sale_amt)                                            AS pay_sale_amt,  -- 支付金额（日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- dws_sup_member_di
    SELECT
        member_id,                                                                -- 商户ID
        BITMAP_UNION(login_member_qty)                               AS login_member_bitmap,  -- 登录商户数去重位图（日）
        SUM(module_open_qty)                                         AS module_open_qty,  -- 模块开通数（日）
        CAST(0 AS DECIMAL(18,2))                                     AS order_sale_amt,  -- 预订金额（日）：此来源不产出，补0
        CAST(0 AS DECIMAL(18,2))                                     AS pay_sale_amt  -- 支付金额（日）：此来源不产出，补0
    FROM dws.dws_sup_member_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
    GROUP BY member_id                                                            -- 按粒度键汇总
    UNION ALL
    -- dws_ord_scenic_ticket_trade_di
    SELECT
        CAST(-1 AS BIGINT)                                           AS member_id,  -- 商户ID：此来源不区分，取 -1（不适用）
        CAST(NULL AS BINARY)                                         AS login_member_bitmap,  -- 登录商户数去重位图（日）：此来源不产出，补空
        CAST(0 AS BIGINT)                                            AS module_open_qty,  -- 模块开通数（日）：此来源不产出，补0
        SUM(order_sale_amt)                                          AS order_sale_amt,  -- 预订金额（日）
        SUM(pay_sale_amt)                                            AS pay_sale_amt  -- 支付金额（日）
    FROM dws.dws_ord_scenic_ticket_trade_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
) u                                                                               -- 各来源合并后的明细
GROUP BY member_id                                                                -- 按粒度键汇总
