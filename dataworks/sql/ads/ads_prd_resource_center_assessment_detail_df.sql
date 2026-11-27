-- ================================================================================================
-- ads.ads_prd_resource_center_assessment_detail_df  资源中心考核明细
-- 粒度：1行=1个考核对象（产品 / 采购商 / 供货商）×考核类型
-- 分区：无分区
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dwd_prd_resource_order_di、dim_prd_resource_df、dim_prd_scenic_df、dim_sup_member_df、ods_opr_resource_center_district_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/资源中心考核2/ads_res_center_assessment_province2022_detail_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 替代旧 ads_res_center_assessment_province2022_detail_d_f：与考核指标表共用同一套 CTE 口径（第 10 单产品、第 10 单采购商、标杆供货商 / 采购商），对象清单与计数一一对应
-- 性能：
--   · 与考核指标表同源 CTE，订单明细只读一次
-- ================================================================================================
WITH ro AS (                                                             -- 资源中心订单（2022 年起全部日分区）；land_id = 业态景区（同一景区多个上架商只算一个产品）
    SELECT order_no, order_time, SUBSTR(order_time, 1, 7) AS mon, ticket_id, scenic_id,
           COALESCE(resource_land_id,
                    scenic_id) AS land_id, COALESCE(resource_land_name,
                    scenic_name) AS land_name, scenic_province_name AS land_prov,
           supplier_id AS sup_id,
           resource_center_supplier_name AS sup_name,                    -- 用户名称
           resource_center_supplier_account AS sup_account,
           resource_center_supplier_province AS sup_prov,
           purchase_member_id AS pur_id,
           resource_center_purchase_name AS pur_name,
           resource_center_purchase_province AS pur_prov,
           booking_qty, booking_pay_amt, cost_price, sale_price, order_status, order_no_land
    FROM dwd.dwd_prd_resource_order_di
    WHERE travel_date >= '20220101'
),
rp AS (                                                                  -- 资源中心上架商品：手动供应 = 上架商不在「自动获取资源」名单；land_id 同上
    SELECT r.resource_id,
           r.ticket_id,
           r.scenic_id,
           r.supplier_id,
           r.province_name AS land_prov,
           r.resource_type,
           r.add_time,
           COALESCE(s.resource_scenic_id,
                    r.scenic_id) AS land_id, COALESCE(s.resource_scenic_name,
                    s.scenic_name) AS land_name,                         -- 景区大屏标题-商户名称
           IF(a.user_id IS NULL, 1, 0) AS manual_flag
    FROM dim.dim_prd_resource_df r
    LEFT JOIN dim.dim_prd_scenic_df s ON s.scenic_id = r.scenic_id
    LEFT JOIN (SELECT DISTINCT user_id FROM ods.ods_opr_resource_center_auto_get_user_df WHERE travel_date = '${bizdate}') a  -- 关联「资源中心自动获取用户」按键聚合
      ON a.user_id = r.supplier_id                                       -- 按 supplier_id→user_id 关联
),
ent AS (                                                                 -- 入驻：资源中心资金账户首笔入驻操作（op_type = 1）的月份；剔除内部 / 测试账号
    SELECT member_id, MIN(FROM_UNIXTIME(add_time, 'yyyy-MM')) AS mon
    FROM ods.ods_prd_resource_amount_operation_track_df
    WHERE travel_date = '${bizdate}'                                     -- 只取当日分区
      AND op_type = 1
      AND member_id NOT IN (
          46992,
          13912747,
          12041060,
          14475274,
          16753023,
          23604282,
          24443195,
          7309895,
          32343705,
          38320338,
          38322741,
          38335458
      )
    GROUP BY member_id                                                   -- 按粒度键汇总
),
lf AS (                                                                  -- 每个业态景区的首个上架资源：资源类型（1-第三方 2-直签）与上架时间（旧 pm = 1）
    SELECT land_id, land_name, land_prov, resource_type, add_time
    FROM (SELECT rp.*, ROW_NUMBER() OVER (PARTITION BY land_id ORDER BY add_time) AS pm FROM rp) t  -- 同一主键多次变更，按 binlog 时间倒序编号
    WHERE pm = 1
),
lf10 AS (                                                                -- 首个资源上架之后、该业态景区的第 10 张订单
    SELECT * FROM (
        SELECT lf.land_id, lf.land_name, lf.resource_type, ro.land_prov, ro.order_time,
               ROW_NUMBER() OVER (PARTITION BY lf.land_id ORDER BY ro.order_time) AS pm  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM lf JOIN ro ON ro.land_id = lf.land_id AND ro.order_time >= lf.add_time
        WHERE lf.resource_type IN (1, 2)) t
    WHERE pm = 10
),
p10 AS (                                                                 -- 采购商（按省）累计第 10 张订单（2022 年起）
    SELECT * FROM (
        SELECT pur_id,
        pur_name,
        pur_prov,
        order_time,
        ROW_NUMBER() OVER (PARTITION BY pur_prov, pur_id ORDER BY order_time) AS pm FROM ro  -- 同一主键多次变更，按 binlog 时间倒序编号
    ) t
    WHERE pm = 10
),
sm AS (                                                                  -- 供货商月订单数（标杆：景区类单月 ≥250，非景区类单月 ≥750；须已入驻）
    SELECT ro.mon,
           ro.sup_prov,
           ro.sup_id,
           MAX(ro.sup_name) AS sup_name,                                 -- 用户名称
           COUNT(1) AS fcount,
           MAX(m.corp_kind_type) AS corp_kind_type                       -- 公司类型
    FROM ro
    JOIN ent e ON e.member_id = ro.sup_id
    LEFT JOIN dim.dim_sup_member_df m ON m.member_id = ro.sup_id
    GROUP BY ro.mon, ro.sup_prov, ro.sup_id                              -- 按粒度键汇总
),
bench AS (                                                               -- 首次达标的月份（同一供货商只算一次）
    SELECT * FROM (
        SELECT sm.*, IF(corp_kind_type = 1, '新增标杆景区供货商数', '新增标杆旅行社供货商数') AS kpi,
               ROW_NUMBER() OVER (                                       -- 同一主键多次变更，按 binlog 时间倒序编号
                   PARTITION BY sup_prov,
                   sup_id,
                   IF(corp_kind_type = 1, 1, 0) ORDER BY mon
               ) AS pm
        FROM sm
        WHERE (corp_kind_type = 1 AND fcount >= 250)
          OR (COALESCE(corp_kind_type, -1) <> 1 AND fcount >= 750)) t
    WHERE pm = 1
),
area AS (                                                                -- 省 → 考核区域、是否重点省
    SELECT province,                                                     -- 省
           MAX(district) AS district,                                    -- 区域
           MAX(CAST(import_province AS INT)) AS import_province          -- 1-重点关注省
    FROM ods.ods_opr_resource_center_district_df WHERE travel_date = '${bizdate}' GROUP BY province
),
obj AS (
    SELECT SUBSTR(order_time, 1, 10) AS booking_month,                   -- 达标日期（yyyy-MM-dd）
           land_prov AS province,                                        -- 省
           land_id AS obj_id,
           land_name AS obj_name,
           IF(resource_type = 2, '新增唯一产品数（部门考核）-直签（大于10单）', '新增唯一产品数（部门考核）-第三方（大于10单）') AS kpi
    FROM lf10
    UNION ALL
    SELECT SUBSTR(order_time, 1, 10), pur_prov, pur_id, pur_name, '累计交易10单采购商数' FROM p10
    UNION ALL
    SELECT CONCAT(mon, '-01'), sup_prov, sup_id, sup_name, kpi FROM bench
    UNION ALL
    SELECT CONCAT(mon, '-01'), pur_prov, pur_id, pur_name, '新增标杆采购商数'
    FROM (SELECT mon, pur_prov, pur_id, MAX(pur_name) AS pur_name, ROW_NUMBER() OVER (PARTITION BY pur_prov, pur_id ORDER BY mon) AS pm  -- 同一主键多次变更，按 binlog 时间倒序编号
          FROM ro GROUP BY mon, pur_prov, pur_id HAVING SUM(booking_pay_amt) >= 100000) t
    WHERE pm = 1
)
INSERT OVERWRITE TABLE ads.ads_prd_resource_center_assessment_detail_df  -- 整表覆盖写入
SELECT DISTINCT
    o.booking_month,                                                     -- 达标日期（yyyy-MM-dd）
    COALESCE(a.district, '未知') AS belong_area,                           -- 考核区域
    o.province,                                                          -- 省
    o.obj_id AS resource_land_id,                                        -- 考核对象ID
    o.kpi AS type,                                                       -- 考核类型（与考核指标表的中文类型一致）
    o.obj_name AS resource_land_name,                                    -- 考核对象名称
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time  -- ETL 加载时间
FROM obj o
LEFT JOIN area a ON a.province = o.province
WHERE o.booking_month >= '2022-01-01'
