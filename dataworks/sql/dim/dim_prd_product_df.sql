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
    SELECT product_id,                                                            -- 产品ID
           scenic_id,                                                             -- 景区ID
           supplier_id,                                                           -- 供应商ID（租户ID）
           ticket_id,
           ticket_status,
           market_price_amt,
           update_time,
           package_role,
           test_flag                                                              -- 是否测试产品
    FROM dim.dim_prd_ticket_df
    WHERE product_id IS NOT NULL
)
INSERT OVERWRITE TABLE dim.dim_prd_product_df                                     -- 整表覆盖写入
SELECT
    t.product_id,                                                                 -- 产品ID
    MAX(t.scenic_id)                                                 AS scenic_id,  -- 景区ID
    MAX(t.supplier_id)                                               AS supplier_id,  -- 供应商ID（租户ID）
    MAX(s.scenic_type_code)                                          AS product_type_code,  -- 产品类型
    MAX(s.scenic_name)                                               AS product_name,  -- 产品名称（所属景区名称）
    COUNT(1)                                                         AS ticket_qty,  -- 票种数
    SUM(IF(t.ticket_status = '1', 1, 0))                             AS onsale_ticket_qty,  -- 在售票种数（状态=上架）
    MIN(IF(t.ticket_status = '1', t.market_price_amt, NULL))         AS min_price_amt,  -- 最低门市价（元）｜只看在售票
    MAX(IF(t.ticket_status = '1', t.market_price_amt, NULL))         AS max_price_amt,  -- 最高门市价（元）
    MAX(IF(t.package_role = 1, 1, 0))                                AS package_flag,  -- 是否含套票
    MAX(t.update_time)                                               AS last_update_time,  -- 产品下门票最近更新时间
    MAX(GREATEST(t.test_flag, COALESCE(s.test_flag, 0)))             AS test_flag,  -- 是否测试产品
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM t
LEFT JOIN (SELECT scenic_id, scenic_name, scenic_type_code, test_flag FROM dim.dim_prd_scenic_df) s  -- 关联「景区维度」按键聚合
  ON s.scenic_id = t.scenic_id                                                    -- 按 scenic_id 关联
GROUP BY t.product_id                                                             -- 按粒度键汇总
