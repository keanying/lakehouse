-- dws.dws_ord_verify_point_flow_hrs  核销点分时客流
-- 粒度：travel_date × stat_hour_no × seller_tenant_id × verify_point_id
-- 来源：dwd_ord_verify_di
-- 生成方式：Spark SQL / Hive；字段 6 个：直接翻译 3 · 规则翻译 0 · 待确认 3
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dws.dws_ord_verify_point_flow_hrs PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  u.stat_hour_no,                                                    -- 统计小时
  u.seller_tenant_id,                                                -- 卖家租户ID
  u.verify_point_id,                                                 -- 核销点ID
  SUM(u.verify_person_qty) AS verify_person_qty,                     -- 核销人次（入园人次）
  SUM(u.verify_fail_qty) AS verify_fail_qty,                         -- 核销失败次数
  SUM(u.verify_entitlement_qty) AS verify_entitlement_qty,           -- 核销权益次数
  CURRENT_TIMESTAMP() AS etl_time                                    -- ETL 加载时间
FROM (
  -- 来源：dwd_ord_verify_di
  SELECT
    verify_hour_no AS stat_hour_no,                                  -- 统计小时
    seller_tenant_id AS seller_tenant_id,                            -- 卖家租户ID
    verify_point_id AS verify_point_id,                              -- 核销点ID
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_person_qty,  -- 核销人次（入园人次）｜待确认：SUCCESS（待补放行人数后改 sum(pass_count)）
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_fail_qty,    -- 核销失败次数｜待确认：verify_result in ('FAILED','DUPLICATE')
    COUNT(CASE WHEN 1 = 1 THEN verify_no END) AS verify_entitlement_qty  -- 核销权益次数｜待确认：verify_result='SUCCESS'
  FROM dwd.dwd_ord_verify_di s                                       -- 来源表「核销明细（权益级）」
  WHERE s.travel_date = '${bizdate}'                                 -- 只取当日分区
  GROUP BY verify_hour_no, seller_tenant_id, verify_point_id         -- 按粒度键汇总
) u                                                                  -- 各来源合并后的明细
GROUP BY u.stat_hour_no, u.seller_tenant_id, u.verify_point_id;      -- 按粒度键汇总
