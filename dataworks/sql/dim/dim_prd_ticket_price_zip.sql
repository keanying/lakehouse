-- ================================================================================================
-- dim.dim_prd_ticket_price_zip  门票价格
-- 粒度：1行=1张门票×1个价格配置（平日 / 特殊日期区间）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_prd_ticket_price_df、ods_prd_ticket_df
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_商品域/dim_prod_price_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据平台/DWS/dws_scenic_ticket_price_zipper_di（SERVERLESS_SPARK_SQL，cron 00 26 00 * * ?）
-- 业务规则 / 修正：
--   · 只取审核通过的价格配置；当日命中价格：区间包含统计日优先、特殊日期优先、再按离统计日最近（同旧 curr_price_rank）
--   · 旧拉链表的 order_status、price（旧 dws 拉链的单一价）由 成本价 / 零售价 两列代替；stat_date 不保留
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_prd_ticket_price_zip                               -- 整表覆盖写入
SELECT
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,    -- 票ID
    CAST(id AS BIGINT)                                           AS price_id,     -- 价格配置ID
    CAST(pid AS BIGINT)                                          AS product_id,   -- 产品ID
    CAST(landid AS BIGINT)                                       AS scenic_id,    -- 景区ID
    CAST(ptype AS INT)                                           AS price_type,   -- 价格类型
    start_date,                                                                   -- 生效开始日期
    end_date,                                                                     -- 生效结束日期
    weekdays,                                                                     -- 适用星期
    CAST(n_price AS DECIMAL(18,2)) / 100                         AS weekday_price_amt,  -- 平日价（元）
    CAST(m_price AS DECIMAL(18,2)) / 100                         AS weekend_price_amt,  -- 周末价（元）
    CAST(s_price AS DECIMAL(18,2)) / 100                         AS special_price_amt,  -- 特殊日期价（元）
    IF(
        ptype = 1,
        CAST(s_price AS DECIMAL(18,2)) / 100,
        CAST(n_price AS DECIMAL(18,2)) / 100
    ) AS cost_price_amt,                                                          -- 成本价（元）= 特殊日期取特殊价
    CAST(l_price AS DECIMAL(18,2)) / 100                         AS sale_price_amt,  -- 零售价（元）
    CAST(window_price AS DECIMAL(18,2)) / 100                    AS window_price_amt,  -- 窗口价（元）
    CAST(status AS INT)                                          AS price_status,  -- 审核状态
    CAST(storage AS BIGINT)                                      AS storage_qty,  -- 库存
    CAST(curr_price_rank AS INT)                                 AS curr_price_rank,  -- 统计日适用顺序
    FROM_UNIXTIME(update_time)                                   AS update_time,  -- 最后更新时间
    CAST(operater_id AS BIGINT)                                  AS operator_id,  -- 最后操作员
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT p.*, t.landid,
               ROW_NUMBER() OVER (PARTITION BY p.ticket_id                        -- 同一主键多次变更，按 binlog 时间倒序编号
                                  ORDER BY IF(
                                      TO_DATE(p.start_date) <= TO_DATE('${bizdate}', 'yyyyMMdd')
                                          AND TO_DATE(p.end_date) >= TO_DATE('${bizdate}', 'yyyyMMdd'),
                                      0,
                                      1
                                  ),
                                           p.ptype DESC,
                                           ABS(DATEDIFF(TO_DATE(p.end_date), TO_DATE('${bizdate}', 'yyyyMMdd')))) AS curr_price_rank  -- 统计日适用顺序
        FROM ods.ods_prd_ticket_price_df p
        LEFT JOIN (SELECT id, MAX(landid) AS landid FROM ods.ods_prd_ticket_df WHERE travel_date = '${bizdate}' GROUP BY id) t  -- 关联「门票表」按键聚合｜票 → 景区
          ON t.id = p.ticket_id                                                   -- 按 ticket_id→id 关联
        WHERE p.travel_date = '${bizdate}' AND p.status = 2                       -- 只取当日分区，并按条件过滤
    ) t
