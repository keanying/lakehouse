-- ================================================================================================
-- dwd.dwd_mkt_coupon_use_di  优惠券使用明细
-- 粒度：1行=1次用券（一单可用多张券）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_mkt_coupon_use_log_df
-- 业务规则 / 修正：
--   · 按用券日 = bizdate 取当日；统计实际抵扣时过滤 use_status = 2（已使用），占用后释放的不计
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_mkt_coupon_use_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS coupon_use_id,  -- 用券记录ID
    CAST(aid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(fid AS BIGINT)                                          AS member_id,    -- 用券用户ID
    use_order_num                                                AS order_no,     -- 使用订单号
    tradeid                                                      AS trade_no,     -- 支付订单号（合并付款）
    coupon_code,                                                                  -- 券码（多张逗号分隔）
    CAST(status AS INT)                                          AS use_status,   -- 状态
    CAST(SIZE(SPLIT(coupon_code, ',')) AS BIGINT)                AS coupon_qty,   -- 用券张数
    CAST(all_use_coupon_money AS DECIMAL(18,2)) / 100            AS deduct_amt,   -- 抵扣金额（元）
    FROM_UNIXTIME(use_time)                                      AS use_time,     -- 使用时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_mkt_coupon_use_log_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
  AND FROM_UNIXTIME(use_time, 'yyyyMMdd') = '${bizdate}'                          -- 全量快照取当日事件
