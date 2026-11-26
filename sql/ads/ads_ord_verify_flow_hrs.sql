-- ads.ads_ord_verify_flow_hrs  分时客流（入园人次）
-- 粒度：travel_date × stat_hour_no × seller_tenant_id × verify_point_id
-- 来源：dws_ord_verify_point_flow_hrs
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 6 · 规则翻译 7 · 待确认 0
-- 来源按粒度键预聚合后按公式计算

WITH
src_verify_point_flow AS (                           -- 来源「核销点分时客流」按粒度键预聚合
  SELECT
    s.stat_hour_no AS stat_hour_no,                  -- 统计小时
    s.seller_tenant_id AS seller_tenant_id,          -- 卖家租户ID
    s.verify_point_id AS verify_point_id,            -- 核销点ID
    SUM(s.verify_person_qty) AS verify_person_qty,
    SUM(s.verify_fail_qty) AS verify_fail_qty,
    SUM(s.verify_entitlement_qty) AS verify_entitlement_qty
  FROM dws.dws_ord_verify_point_flow_hrs s           -- 来源表「核销点分时客流」
  WHERE s.travel_date = '${bizdate}'                 -- 只取当日分区
  GROUP BY s.stat_hour_no, s.seller_tenant_id, s.verify_point_id  -- 按粒度键汇总
),
merged AS (                                          -- 按粒度键汇总，计算派生指标
  SELECT
    u.stat_hour_no,                                  -- 统计小时
    u.seller_tenant_id,                              -- 卖家租户ID
    u.verify_point_id,                               -- 核销点ID
    u.verify_person_qty AS verify_person_1h_qty,     -- 当小时核销人次（入园人次）
    u.verify_fail_qty AS verify_fail_1h_qty,         -- 当小时核销失败次数
    u.verify_fail_qty * 100 / NULLIF(u.verify_entitlement_qty, 0) AS verify_fail_1h_rate,  -- 当小时核销失败率
    u.verify_person_qty AS verify_person_1d_qty,     -- 当日核销人次（入园人次）
    u.verify_person_qty AS verify_person_7d_qty,     -- 近7日核销人次（入园人次）
    u.verify_person_qty AS verify_person_30d_qty,    -- 近30日核销人次（入园人次）
    u.verify_person_qty AS peak_hour_verify_qty,     -- 峰值小时入园人次
    CURRENT_TIMESTAMP() AS etl_time                  -- ETL 加载时间
  FROM src_verify_point_flow u
),
tenant_cur AS (                                      -- 「租户（商户/供应商/分销商）维度」当前有效版本，只取名称类字段
  SELECT tenant_id, tenant_name
  FROM dim.dim_sup_tenant_zip
  WHERE travel_date = '${bizdate}' AND end_date = '9999-12-31'  -- 取当日分区里的拉链当前有效版本
),
verify_point_dim AS (                                -- 「核销点维度」当日数据，只取名称类字段
  SELECT verify_point_id, verify_point_name
  FROM dim.dim_opr_verify_point_df
  WHERE travel_date = '${bizdate}'                   -- 只取当日分区
)
INSERT OVERWRITE TABLE ads.ads_ord_verify_flow_hrs PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT  /*+ BROADCAST(verify_point_dim) */
  merged.stat_hour_no,                               -- 统计小时
  merged.seller_tenant_id,                           -- 卖家租户ID
  merged.verify_point_id,                            -- 核销点ID
  tenant_cur.tenant_name AS seller_tenant_name,      -- 卖家租户名称
  verify_point_dim.verify_point_name AS verify_point_name,  -- 核销点名称
  merged.verify_person_1h_qty,                       -- 当小时核销人次（入园人次）
  merged.verify_fail_1h_qty,                         -- 当小时核销失败次数
  merged.verify_fail_1h_rate,                        -- 当小时核销失败率
  merged.verify_person_1d_qty,                       -- 当日核销人次（入园人次）
  merged.verify_person_7d_qty,                       -- 近7日核销人次（入园人次）
  merged.verify_person_30d_qty,                      -- 近30日核销人次（入园人次）
  merged.peak_hour_verify_qty,                       -- 峰值小时入园人次
  merged.etl_time                                    -- ETL 加载时间
FROM merged
LEFT JOIN tenant_cur                                 -- 关联「租户（商户/供应商/分销商）维度」，补 seller_tenant_name
  ON tenant_cur.tenant_id = merged.seller_tenant_id  -- 按 seller_tenant_id→tenant_id 关联
LEFT JOIN verify_point_dim                           -- 关联「核销点维度」，补 verify_point_name
  ON verify_point_dim.verify_point_id = merged.verify_point_id;  -- 按 verify_point_id 关联
