-- ================================================================================================
-- dim.dim_prd_product_df  产品维度
-- 粒度：1行=1个产品（pid）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_prd_ticket_df、dim_prd_scenic_df
-- 业务规则 / 修正：
--   · 旧系统没有产品维度，产品属性散在票维表；pid 与景区 1:1，名称 / 类型取景区
-- 性能：
--   · 直接由已标准化的票维度聚合，不再回读 ODS
-- ================================================================================================
WITH t AS (
    SELECT product_id, scenic_id, supplier_id, ticket_id, ticket_status, market_price_amt, update_time, package_role, test_flag
    FROM dim.dim_prd_ticket_df
    WHERE product_id IS NOT NULL
)
INSERT OVERWRITE TABLE dim.dim_prd_product_df
SELECT
    t.product_id,
    MAX(t.scenic_id)                                                 AS scenic_id,
    MAX(t.supplier_id)                                               AS supplier_id,
    MAX(s.scenic_type_code)                                          AS product_type_code,
    MAX(s.scenic_name)                                               AS product_name,
    COUNT(1)                                                         AS ticket_qty,
    SUM(IF(t.ticket_status = '1', 1, 0))                             AS onsale_ticket_qty,
    MIN(IF(t.ticket_status = '1', t.market_price_amt, NULL))         AS min_price_amt,   -- 只看在售票
    MAX(IF(t.ticket_status = '1', t.market_price_amt, NULL))         AS max_price_amt,
    MAX(IF(t.package_role = 1, 1, 0))                                AS package_flag,
    MAX(t.update_time)                                               AS last_update_time,
    MAX(GREATEST(t.test_flag, COALESCE(s.test_flag, 0)))             AS test_flag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM t
LEFT JOIN (SELECT scenic_id, scenic_name, scenic_type_code, test_flag FROM dim.dim_prd_scenic_df) s ON s.scenic_id = t.scenic_id
GROUP BY t.product_id
