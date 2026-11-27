-- ================================================================================================
-- ads.ads_prd_resource_center_assessment_df  资源中心考核指标
-- 粒度：1行=1个考核月×考核区域×省（全量重算）
-- 分区：无分区
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：dwd_prd_resource_order_di、dim_prd_resource_df、dim_prd_scenic_df、dim_sup_member_df、dim_opr_dict_f、ods_prd_resource_amount_operation_track_df、ods_opr_resource_center_auto_get_user_df、ods_opr_resource_center_district_df、ods_sup_member_relation_df、dwd_ord_order_distribution_di
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/资源中心考核2/ads_res_center_assessment_province2022_d_f（EMR_SPARK_SQL，cron 00 00 05 * * ?）
-- 业务规则 / 修正：
--   · 替代旧 ads_res_center_assessment_province2022_d_f：旧表依赖 dws_resource_center_user / land_summary / land_attr_detail / ticket_summary、ads_resource_center_order / cutchain_order 等 8 张中间表，改为从资源中心订单明细、资源商品维度直接计算（中间口径在 CTE 里一处定义）
--   · 26 个指标先算成「月 × 省 × 类型 × 值」竖表再转宽表，与旧 SQL 的 UNION 结构一一对应，类型名沿用旧中文名便于对数
--   · 断连 GMV：分销关系里「资源中心关系（类型 4）被断开（状态 1）后、又建立的普通分销关系（类型 0、状态 0）」上的订单，同旧 cutchain 口径
--   · 「当月发生交易 SPU 数」沿用旧 SQL 实际口径：按资源景区上架月份计数（景区 × 上架商）
-- 性能：
--   · 订单明细只读一次（ro），其余 CTE 复用；窗口排序都在订单级一次完成
--   · 区域表、自动供应名单 BROADCAST
-- ================================================================================================
WITH ro AS (                                                                      -- 资源中心订单（2022 年起全部日分区）；land_id = 业态景区（同一景区多个上架商只算一个产品）
    SELECT order_no, order_time, SUBSTR(order_time, 1, 7) AS mon, ticket_id, scenic_id,
           COALESCE(resource_land_id,
                    scenic_id) AS land_id, COALESCE(resource_land_name,
                    scenic_name) AS land_name, scenic_province_name AS land_prov,
           supplier_id AS sup_id,
           resource_center_supplier_name AS sup_name,                             -- 用户名称
           resource_center_supplier_account AS sup_account,
           resource_center_supplier_province AS sup_prov,
           purchase_member_id AS pur_id,
           resource_center_purchase_name AS pur_name,
           resource_center_purchase_province AS pur_prov,
           booking_qty, booking_pay_amt, cost_price, sale_price, order_status, order_no_land
    FROM dwd.dwd_prd_resource_order_di
    WHERE travel_date >= '20220101'
),
rp AS (                                                                           -- 资源中心上架商品：手动供应 = 上架商不在「自动获取资源」名单；land_id 同上
    SELECT r.resource_id,
           r.ticket_id,
           r.scenic_id,
           r.supplier_id,
           r.province_name AS land_prov,
           r.resource_type,
           r.add_time,
           COALESCE(s.resource_scenic_id,
                    r.scenic_id) AS land_id, COALESCE(s.resource_scenic_name,
                    s.scenic_name) AS land_name,                                  -- 景区大屏标题-商户名称
           IF(a.user_id IS NULL, 1, 0) AS manual_flag
    FROM dim.dim_prd_resource_df r
    LEFT JOIN dim.dim_prd_scenic_df s ON s.scenic_id = r.scenic_id
    LEFT JOIN (SELECT DISTINCT user_id FROM ods.ods_opr_resource_center_auto_get_user_df WHERE travel_date = '${bizdate}') a  -- 关联「资源中心自动获取用户」按键聚合
      ON a.user_id = r.supplier_id                                                -- 按 supplier_id→user_id 关联
),
ent AS (                                                                          -- 入驻：资源中心资金账户首笔入驻操作（op_type = 1）的月份；剔除内部 / 测试账号
    SELECT member_id, MIN(FROM_UNIXTIME(add_time, 'yyyy-MM')) AS mon
    FROM ods.ods_prd_resource_amount_operation_track_df
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
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
    GROUP BY member_id                                                            -- 按粒度键汇总
),
lf AS (                                                                           -- 每个业态景区的首个上架资源：资源类型（1-第三方 2-直签）与上架时间（旧 pm = 1）
    SELECT land_id, land_name, land_prov, resource_type, add_time
    FROM (SELECT rp.*, ROW_NUMBER() OVER (PARTITION BY land_id ORDER BY add_time) AS pm FROM rp) t  -- 同一主键多次变更，按 binlog 时间倒序编号
    WHERE pm = 1
),
lf10 AS (                                                                         -- 首个资源上架之后、该业态景区的第 10 张订单
    SELECT * FROM (
        SELECT lf.land_id, lf.land_name, lf.resource_type, ro.land_prov, ro.order_time,
               ROW_NUMBER() OVER (PARTITION BY lf.land_id ORDER BY ro.order_time) AS pm  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM lf JOIN ro ON ro.land_id = lf.land_id AND ro.order_time >= lf.add_time
        WHERE lf.resource_type IN (1, 2)) t
    WHERE pm = 10
),
p10 AS (                                                                          -- 采购商（按省）累计第 10 张订单（2022 年起）
    SELECT * FROM (
        SELECT pur_id,
        pur_name,
        pur_prov,
        order_time,
        ROW_NUMBER() OVER (PARTITION BY pur_prov, pur_id ORDER BY order_time) AS pm FROM ro  -- 同一主键多次变更，按 binlog 时间倒序编号
    ) t
    WHERE pm = 10
),
sm AS (                                                                           -- 供货商月订单数（标杆：景区类单月 ≥250，非景区类单月 ≥750；须已入驻）
    SELECT ro.mon,
           ro.sup_prov,
           ro.sup_id,
           MAX(ro.sup_name) AS sup_name,                                          -- 用户名称
           COUNT(1) AS fcount,
           MAX(m.corp_kind_type) AS corp_kind_type                                -- 公司类型
    FROM ro
    JOIN ent e ON e.member_id = ro.sup_id
    LEFT JOIN dim.dim_sup_member_df m ON m.member_id = ro.sup_id
    GROUP BY ro.mon, ro.sup_prov, ro.sup_id                                       -- 按粒度键汇总
),
bench AS (                                                                        -- 首次达标的月份（同一供货商只算一次）
    SELECT * FROM (
        SELECT sm.*, IF(corp_kind_type = 1, '新增标杆景区供货商数', '新增标杆旅行社供货商数') AS kpi,
               ROW_NUMBER() OVER (                                                -- 同一主键多次变更，按 binlog 时间倒序编号
                   PARTITION BY sup_prov,
                   sup_id,
                   IF(corp_kind_type = 1, 1, 0) ORDER BY mon
               ) AS pm
        FROM sm
        WHERE (corp_kind_type = 1 AND fcount >= 250)
          OR (COALESCE(corp_kind_type, -1) <> 1 AND fcount >= 750)) t
    WHERE pm = 1
),
area AS (                                                                         -- 省 → 考核区域、是否重点省
    SELECT province,                                                              -- 省
           MAX(district) AS district,                                             -- 区域
           MAX(CAST(import_province AS INT)) AS import_province                   -- 是否重点省
    FROM ods.ods_opr_resource_center_district_df WHERE travel_date = '${bizdate}' GROUP BY province
),
cut AS (                                                                          -- 断连订单：资源中心关系断开后重新建立的普通分销关系（卖家 → 买家）上的订单
    SELECT DISTINCT d.order_no
    FROM dwd.dwd_ord_order_distribution_di d
    JOIN (SELECT r1.parent_id, r1.son_id
          FROM ods.ods_sup_member_relation_df r1
          JOIN ods.ods_sup_member_relation_df r2                                  -- 关联「会员关系表」
            ON r2.parent_id = r1.parent_id AND r2.son_id = r1.son_id AND r2.travel_date = '${bizdate}'  -- 按 parent_id、son_id 关联
           AND r2.status = 1 AND r2.ship_type = 4                                 -- 资源中心关系，已断开
          WHERE r1.travel_date = '${bizdate}' AND r1.status = 0 AND r1.ship_type = 0  -- 只取当日分区，并按条件过滤｜普通分销关系，有效
            AND r1.rectime >= r2.cuttime                                          -- 断开之后重新建立
          GROUP BY r1.parent_id, r1.son_id) b                                     -- 按粒度键汇总
      ON b.parent_id = d.seller_id AND b.son_id = d.buyer_id                      -- 按 seller_id→parent_id、buyer_id→son_id 关联
    WHERE d.travel_date > DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 732), 'yyyyMMdd')  -- 近 2 年（同旧口径）
),
co AS (SELECT ro.* FROM ro JOIN cut ON cut.order_no = ro.order_no),
st AS (SELECT dict_code FROM dim.dim_opr_dict_f WHERE dict_type = 'order_status' AND dict_name IN ('已使用，特产时为确认收货', '订单完结')),
k AS (                                                                            -- 竖表：月 × 省 × 考核类型 × 值
    -- 新增激活：用户（供货商 / 采购商任一身份）首单月份
    SELECT SUBSTR(MIN(order_time), 1, 7) AS booking_month,                        -- 考核月份（yyyy-MM）
           MAX(prov) AS province,                                                 -- 省
           '新增激活' AS kpi,
           user_id AS obj_id
    FROM (
        SELECT sup_id AS user_id,                                                 -- 用户id
        sup_prov AS prov,
        order_time FROM ro UNION ALL SELECT pur_id,
        pur_prov,
        order_time FROM ro
    ) u                                                                           -- 各来源合并后的明细
    GROUP BY user_id                                                              -- 按粒度键汇总
    UNION ALL
    -- 新增入驻（账号 38302503 归福建省，同旧口径）
    SELECT e.mon, IF(e.member_id = 38302503, '福建省', m.province_name), '新增入驻', e.member_id
    FROM ent e LEFT JOIN dim.dim_sup_member_df m ON m.member_id = e.member_id
    UNION ALL
    SELECT SUBSTR(MIN(order_time), 1, 7), MAX(land_prov), '新增启用票类', ticket_id FROM ro GROUP BY ticket_id
    UNION ALL
    SELECT SUBSTR(MIN(order_time), 1, 7), MAX(land_prov), '新增启用产品数', scenic_id FROM ro GROUP BY scenic_id
    UNION ALL
    SELECT SUBSTR(MIN(add_time), 1, 7),
           MAX(land_prov),
           '新增票类',
           ticket_id FROM rp WHERE manual_flag = 1 GROUP BY ticket_id
    UNION ALL
    SELECT SUBSTR(MIN(add_time), 1, 7),
           MAX(land_prov),
           '新增产品数',
           scenic_id FROM rp WHERE manual_flag = 1 GROUP BY scenic_id
    UNION ALL
    SELECT SUBSTR(MIN(add_time), 1, 7),
           MAX(land_prov),
           '新增唯一产品数（部门考核）',
           land_id FROM rp WHERE manual_flag = 1 GROUP BY land_id
    UNION ALL
    SELECT SUBSTR(add_time, 1, 7),
           land_prov,
           IF(resource_type = 2, '新增唯一产品数（部门考核）-直签', '新增唯一产品数（部门考核）-第三方'),
           land_id
    FROM lf WHERE resource_type IN (1, 2)
    UNION ALL
    SELECT SUBSTR(MIN(add_time), 1, 7),
           MAX(land_prov),
           '当月发生交易SPU数',
           CONCAT(land_id, '-', supplier_id) FROM rp GROUP BY land_id,
           supplier_id
    UNION ALL
    -- 第 10 单激活：用户两种身份的订单合并排序
    SELECT SUBSTR(order_time, 1, 7), prov, '新增订单≥10用户数', user_id
    FROM (SELECT u.*, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_time) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
          FROM (
              SELECT sup_id AS user_id,                                           -- 用户id
              sup_prov AS prov,
              order_time FROM ro UNION ALL SELECT pur_id,
              pur_prov,
              order_time FROM ro
          ) u) t
    WHERE rn = 10
    UNION ALL
    SELECT SUBSTR(order_time, 1, 7), land_prov, '新增订单≥10产品数', scenic_id FROM ro WHERE order_no_land = 10
    UNION ALL
    SELECT mon, pur_prov, '交易采购商数', pur_id FROM ro GROUP BY mon, pur_prov, pur_id
    UNION ALL
    -- 新增激活采购商：累计 ≥10 单的采购商，计在首单月份
    SELECT SUBSTR(MIN(order_time), 1, 7),
           MAX(pur_prov),
           '新增激活采购商数',
           pur_id FROM ro GROUP BY pur_id HAVING COUNT(1) >= 10
    UNION ALL
    SELECT SUBSTR(order_time, 1, 7),
           land_prov,
           IF(resource_type = 2, '新增唯一产品数（部门考核）-直签（大于10单）', '新增唯一产品数（部门考核）-第三方（大于10单）'),
           land_id
    FROM lf10
    UNION ALL
    SELECT SUBSTR(order_time, 1, 7), pur_prov, '累计交易10单采购商数', pur_id FROM p10
    UNION ALL
    SELECT mon, sup_prov, kpi, sup_id FROM bench
    UNION ALL
    -- 新增标杆采购商：单月预订 ≥10 万元，首次达标月
    SELECT mon, pur_prov, '新增标杆采购商数', pur_id
    FROM (SELECT mon, pur_prov, pur_id, ROW_NUMBER() OVER (PARTITION BY pur_prov, pur_id ORDER BY mon) AS pm  -- 同一主键多次变更，按 binlog 时间倒序编号
          FROM (
              SELECT mon,
              pur_prov,
              pur_id FROM ro GROUP BY mon,
              pur_prov,
              pur_id HAVING SUM(booking_pay_amt) >= 100000
          ) x) t
    WHERE pm = 1
    UNION ALL
    -- 累计超过 10 单：当月有第 10 单及以后订单的采购商
    SELECT DISTINCT SUBSTR(order_time, 1, 7), pur_prov, '累计交易超过10单采购商数', pur_id
    FROM (
        SELECT pur_id,
        pur_prov,
        order_time,
        ROW_NUMBER() OVER (PARTITION BY pur_prov, pur_id ORDER BY order_time) AS pm FROM ro  -- 同一主键多次变更，按 binlog 时间倒序编号
    ) t
    WHERE pm >= 10
),
amt AS (                                                                          -- 金额类：GMV / 断连 GMV（按景区省、按采购商省）、指定账号利润
    SELECT mon AS booking_month,                                                  -- 考核月份（yyyy-MM）
           land_prov AS province,                                                 -- 省
           'GMV' AS kpi,
           SUM(booking_pay_amt) AS v FROM ro GROUP BY mon,
           land_prov
    UNION ALL SELECT mon, pur_prov, 'GMV-采购商', SUM(booking_pay_amt) FROM ro GROUP BY mon, pur_prov
    UNION ALL SELECT mon, land_prov, '断连GMV', SUM(booking_pay_amt) FROM co GROUP BY mon, land_prov
    UNION ALL SELECT mon, pur_prov, '断连GMV-采购商', SUM(booking_pay_amt) FROM co GROUP BY mon, pur_prov
    UNION ALL
    SELECT mon,
           land_prov,
           '利润',
           SUM((COALESCE(sale_price, 0) - COALESCE(cost_price, 0)) * COALESCE(booking_qty, 0))
    FROM ro
    WHERE sup_account IN ('65129163', '5902514', '71065544')
      AND mon >= '2025-01'
      AND order_status IN (SELECT dict_code FROM st)
    GROUP BY mon, land_prov                                                       -- 按粒度键汇总
),
kv AS (                                                                           -- 计数类按对象去重后与金额类合并
    SELECT booking_month,                                                         -- 考核月份（yyyy-MM）
           province,                                                              -- 省
           kpi,
           CAST(COUNT(DISTINCT obj_id) AS DECIMAL(18,2)) AS v FROM k GROUP BY booking_month,
           province,                                                              -- 省
           kpi
    UNION ALL
    SELECT booking_month, province, kpi, CAST(ROUND(v, 2) AS DECIMAL(18,2)) FROM amt
)
INSERT OVERWRITE TABLE ads.ads_prd_resource_center_assessment_df                  -- 整表覆盖写入
SELECT /*+ BROADCAST(a) */
    k.booking_month,                                                              -- 考核月份（yyyy-MM）
    CASE WHEN a.district IS NULL THEN '未知'
         WHEN k.booking_month >= '2026-05' AND a.district = '陈娟芳' THEN
              CASE WHEN k.province IN ('浙江省', '江苏省', '上海市', '湖南省', '海南省') THEN '林丰'
                   WHEN k.province IN ('湖北省', '山西省', '河北省', '安徽省', '河南省') THEN '王佳鑫' END
         ELSE a.district END AS belong_area,                                      -- 考核区域
    k.province,                                                                   -- 省
    MAX(a.import_province) AS import_province,                                    -- 是否重点省
    CAST(SUM(IF(k.kpi = '新增激活', k.v, 0)) AS BIGINT) AS active_num,                -- 新增激活用户数
    CAST(SUM(IF(k.kpi = '新增入驻', k.v, 0)) AS BIGINT) AS enter_num,                 -- 新增入驻用户数
    CAST(SUM(IF(k.kpi = '新增票类', k.v, 0)) AS BIGINT) AS ticket_num,                -- 新增手动供应票种数
    CAST(SUM(IF(k.kpi = '新增启用票类', k.v, 0)) AS BIGINT) AS ticket_active_num,       -- 新增启用票类（首单）
    CAST(SUM(IF(k.kpi = '新增产品数', k.v, 0)) AS BIGINT) AS land_num,                 -- 新增手动供应产品数
    CAST(SUM(IF(k.kpi = '新增启用产品数', k.v, 0)) AS BIGINT) AS land_active_num,        -- 新增启用产品数（首单）
    CAST(SUM(IF(k.kpi = '新增订单≥10用户数', k.v, 0)) AS BIGINT) AS active_10_num,       -- 新增激活用户数（第 10 单）
    CAST(SUM(IF(k.kpi = '新增订单≥10产品数', k.v, 0)) AS BIGINT) AS land_active_10_num,  -- 新增激活产品数（第 10 单）
    CAST(SUM(IF(k.kpi = '新增激活采购商数', k.v, 0)) AS BIGINT) AS active_purchase_num,   -- 新增激活采购商数
    CAST(SUM(IF(k.kpi = '交易采购商数', k.v, 0)) AS BIGINT) AS trade_purchase_num,      -- 交易采购商数
    CAST(SUM(IF(k.kpi = 'GMV', k.v, 0)) AS DECIMAL(18,2)) AS order_pay_amount,    -- GMV
    CAST(SUM(IF(k.kpi = '断连GMV', k.v, 0)) AS DECIMAL(18,2)) AS cutchain_pay_amount,  -- 断连 GMV
    CAST(SUM(IF(k.kpi = 'GMV-采购商', k.v, 0)) AS DECIMAL(18,2)) AS order_pay_cg_amount,  -- 采购商 GMV
    CAST(SUM(IF(k.kpi = '断连GMV-采购商', k.v, 0)) AS DECIMAL(18,2)) AS cutchain_pay_cg_amount,  -- 采购商断连 GMV
    CAST(SUM(IF(k.kpi = '新增唯一产品数（部门考核）', k.v, 0)) AS BIGINT) AS land_num_depart,  -- 新增唯一产品数
    CAST(SUM(IF(k.kpi = '新增唯一产品数（部门考核）-直签', k.v, 0)) AS BIGINT) AS land_num_depart_direct,  -- 新增唯一产品数-直签
    CAST(SUM(IF(k.kpi = '新增唯一产品数（部门考核）-第三方', k.v, 0)) AS BIGINT) AS land_num_depart_third,  -- 新增唯一产品数-第三方
    CAST(SUM(IF(k.kpi = '当月发生交易SPU数', k.v, 0)) AS BIGINT) AS land_num_company,    -- 当月新上架资源景区数（景区 × 上架商）
    CAST(SUM(IF(k.kpi = '新增唯一产品数（部门考核）-直签（大于10单）', k.v, 0)) AS BIGINT) AS land_num_depart_direct_10,  -- 新增唯一产品数-直签（第 10 单）
    CAST(SUM(IF(k.kpi = '新增唯一产品数（部门考核）-第三方（大于10单）', k.v, 0)) AS BIGINT) AS land_num_depart_third_10,  -- 新增唯一产品数-第三方（第 10 单）
    CAST(SUM(IF(k.kpi = '累计交易10单采购商数', k.v, 0)) AS BIGINT) AS land_purchase_num_10,  -- 累计交易 10 单采购商数
    CAST(SUM(IF(k.kpi = '新增标杆景区供货商数', k.v, 0)) AS BIGINT) AS land_num_250,        -- 新增标杆景区供货商数
    CAST(SUM(IF(k.kpi = '新增标杆旅行社供货商数', k.v, 0)) AS BIGINT) AS noland_num_750,     -- 新增标杆旅行社供货商数
    CAST(SUM(IF(k.kpi = '新增标杆采购商数', k.v, 0)) AS BIGINT) AS purchase_account_10,   -- 新增标杆采购商数
    CAST(SUM(IF(k.kpi = '累计交易超过10单采购商数', k.v, 0)) AS BIGINT) AS purchase_account_10_add,  -- 累计交易超过 10 单的采购商数
    CAST(SUM(IF(k.kpi = '利润', k.v, 0)) AS DECIMAL(18,2)) AS profit,               -- 利润
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM kv k
LEFT JOIN area a ON a.province = k.province
WHERE k.booking_month >= '2022-01'
GROUP BY k.booking_month, CASE WHEN a.district IS NULL THEN '未知'                  -- 按粒度键汇总
                      WHEN k.booking_month >= '2026-05' AND a.district = '陈娟芳' THEN
                           CASE WHEN k.province IN ('浙江省', '江苏省', '上海市', '湖南省', '海南省') THEN '林丰'
                                WHEN k.province IN ('湖北省', '山西省', '河北省', '安徽省', '河南省') THEN '王佳鑫' END
                      ELSE a.district END, k.province
