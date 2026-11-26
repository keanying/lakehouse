-- dws.dws_sup_tenant_lifetime_df  商户累计至今汇总
-- 粒度：travel_date（快照日）× seller_tenant_id
-- 来源：dws_sup_tenant_trade_di
-- 生成方式：Spark SQL / Hive；字段 8 个：直接翻译 1 · 规则翻译 2 · 待确认 5
-- 多来源：每个来源先按粒度键预聚合，UNION ALL 后再汇总；快照/累计表：增量来源取截至统计日的全部分区
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

WITH
src_customer_trade AS (                                          -- 来源「游客×商户 交易日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                        -- 卖家租户ID
    NULL AS first_pay_date,                                      -- 待确认：min(pay_date)
    NULL AS last_pay_date,                                       -- 待确认：max(pay_date)
    NULL AS active_tenant_qty,
    CAST(NULL AS BINARY) AS active_tenant_bitmap
  FROM dws.dws_cus_customer_trade_di s                           -- 来源表「游客×商户 交易日汇总」
  WHERE s.travel_date <= '${bizdate}'                            -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id                                      -- 按粒度键汇总
),
src_tenant_trade AS (                                            -- 来源「商户经营日汇总」按粒度键预聚合
  SELECT
    seller_tenant_id AS seller_tenant_id,                        -- 卖家租户ID
    NULL AS first_pay_date,
    NULL AS last_pay_date,
    COUNT(DISTINCT CASE WHEN pay_amt>0 THEN seller_tenant_id END) AS active_tenant_qty,  -- 动销商户数
    BITMAP_UNION(TO_BITMAP(CASE WHEN pay_amt>0 THEN seller_tenant_id END)) AS active_tenant_bitmap  -- 动销商户数去重位图
  FROM dws.dws_sup_tenant_trade_di s                             -- 来源表「商户经营日汇总」
  WHERE s.travel_date <= '${bizdate}'                            -- 累计口径：取截至统计日的全部分区
  GROUP BY seller_tenant_id                                      -- 按粒度键汇总
),
all_src AS (                                                     -- 各来源字段已对齐，UNION ALL 合并（比多表 FULL JOIN 少 shuffle）
  SELECT * FROM src_customer_trade
  UNION ALL
  SELECT * FROM src_tenant_trade
)
INSERT OVERWRITE TABLE dws.dws_sup_tenant_lifetime_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.seller_tenant_id,                                            -- 卖家租户ID
  MIN(u.first_pay_date) AS first_pay_date,                       -- 首次支付日期
  MAX(u.last_pay_date) AS last_pay_date,                         -- 最近支付日期
  NULL AS total_pay_amt,                                         -- 待确认：sum(pay_amt) 全历史
  NULL AS pay_30d_amt,                                           -- 待确认：sum(pay_amt) 近30天
  NULL AS active_day_30d_qty,                                    -- 待确认：count(distinct travel_date) where pay_amt>0 近30天
  SUM(u.active_tenant_qty) AS active_tenant_qty,                 -- 动销商户数
  BITMAP_UNION(u.active_tenant_bitmap) AS active_tenant_bitmap,  -- 动销商户数去重位图
  CURRENT_TIMESTAMP() AS etl_time                                -- ETL 加载时间
FROM all_src u
GROUP BY u.seller_tenant_id;                                     -- 按粒度键汇总
