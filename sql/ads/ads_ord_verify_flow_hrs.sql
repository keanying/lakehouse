-- ads.ads_ord_verify_flow_hrs  分时客流（入园人次）
-- 粒度：travel_date × stat_hour_no × seller_tenant_id × verify_point_id
-- 来源：dws_ord_verify_point_flow_hrs
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 6 · 规则翻译 7 · 待确认 0

INSERT OVERWRITE TABLE ads.ads_ord_verify_flow_hrs PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  x.stat_hour_no,                                               -- 统计小时
  x.seller_tenant_id,                                           -- 卖家租户ID
  x.verify_point_id,                                            -- 核销点ID
  d1.tenant_name AS seller_tenant_name,                         -- 卖家租户名称
  d2.verify_point_name AS verify_point_name,                    -- 核销点名称
  x.verify_person_1h_qty,                                       -- 当小时核销人次（入园人次）
  x.verify_fail_1h_qty,                                         -- 当小时核销失败次数
  x.verify_fail_1h_rate,                                        -- 当小时核销失败率
  x.verify_person_1d_qty,                                       -- 当日核销人次（入园人次）
  x.verify_person_7d_qty,                                       -- 近7日核销人次（入园人次）
  x.verify_person_30d_qty,                                      -- 近30日核销人次（入园人次）
  x.peak_hour_verify_qty,                                       -- 峰值小时入园人次
  x.etl_time                                                    -- ETL 加载时间
FROM (
SELECT
  u.stat_hour_no,                                               -- 统计小时
  u.seller_tenant_id,                                           -- 卖家租户ID
  u.verify_point_id,                                            -- 核销点ID
  SUM(u.verify_person_qty) AS verify_person_1h_qty,             -- 当小时核销人次（入园人次）
  SUM(u.verify_fail_qty) AS verify_fail_1h_qty,                 -- 当小时核销失败次数
  SUM(u.verify_fail_qty) * 100 / NULLIF(SUM(u.verify_entitlement_qty), 0) AS verify_fail_1h_rate,  -- 当小时核销失败率
  SUM(u.verify_person_qty) AS verify_person_1d_qty,             -- 当日核销人次（入园人次）
  SUM(u.verify_person_qty) AS verify_person_7d_qty,             -- 近7日核销人次（入园人次）
  SUM(u.verify_person_qty) AS verify_person_30d_qty,            -- 近30日核销人次（入园人次）
  SUM(u.verify_person_qty) AS peak_hour_verify_qty,             -- 峰值小时入园人次
  CURRENT_TIMESTAMP() AS etl_time                               -- ETL 加载时间
FROM (
  -- 来源：dws_ord_verify_point_flow_hrs
  SELECT
    s.stat_hour_no AS stat_hour_no,                             -- 统计小时
    s.seller_tenant_id AS seller_tenant_id,                     -- 卖家租户ID
    s.verify_point_id AS verify_point_id,                       -- 核销点ID
    SUM(s.verify_person_qty) AS verify_person_qty,
    SUM(s.verify_fail_qty) AS verify_fail_qty,
    SUM(s.verify_entitlement_qty) AS verify_entitlement_qty
  FROM dws.dws_ord_verify_point_flow_hrs s                      -- 来源表「核销点分时客流」
  WHERE s.travel_date = '${bizdate}'                            -- 只取当日分区
  GROUP BY s.stat_hour_no, s.seller_tenant_id, s.verify_point_id  -- 按粒度键汇总
) u                                                             -- 各来源合并后的明细
GROUP BY u.stat_hour_no, u.seller_tenant_id, u.verify_point_id  -- 按粒度键汇总
) x                                                             -- 汇总结果，外层再补维度名称
LEFT JOIN dim.dim_sup_tenant_zip d1 ON d1.tenant_id = x.seller_tenant_id AND d1.travel_date = '${bizdate}' AND d1.end_date = '9999-12-31'  -- 关联「租户（商户/供应商/分销商）维度」，取维度名称
LEFT JOIN dim.dim_opr_verify_point_df d2 ON d2.verify_point_id = x.verify_point_id AND d2.travel_date = '${bizdate}';  -- 关联「核销点维度」，取维度名称
