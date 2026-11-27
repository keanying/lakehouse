-- ================================================================================================
-- dwd.dwd_prd_resource_order_di  资源中心订单明细
-- 粒度：1行=1张经资源中心采购商品产生的订单（当日下单，按唯一订单号去重）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：dwd_ord_order_di、ods_prd_resource_purchase_df、dwd_ord_order_distribution_di、dwd_trf_api_order_di、dim_prd_scenic_df、dim_prd_ticket_df、dim_sup_member_df、dim_trf_channel_f、dim_opr_region_f、ods_opr_resource_center_district_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/资源中心考核2/dwd_resource_center_order_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 唯一订单：OTA 下单失败会重试，按 远端单号（无则平台单号）去重；上架商 / 采购商 / 景区的第几单在近 2 年订单上编号（同旧口径）
--   · 名称、地区、类型等属性按维表关联补齐（旧系统同样来自用户 / 景区维表）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_prd_resource_order_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    order_no,                                                                     -- 订单号
    remote_order_no,                                                              -- 远端订单号
    order_status,                                                                 -- 订单状态
    CAST(ticket_qty AS BIGINT)                                   AS ticket_qty,   -- 票数
    order_time,                                                                   -- 下单时间
    first_verify_time                                            AS verify_time,  -- 首次核销时间
    CAST(scenic_id AS BIGINT)                                    AS scenic_id,    -- 景区ID
    scenic_name,                                                                  -- 景区名称
    scenic_type_code,                                                             -- 产品类型编码
    scenic_type_name,                                                             -- 产品类型
    s_province                                                   AS scenic_province_name,  -- 景区所在省
    s_city                                                       AS scenic_city_name,  -- 景区所在市
    s_area                                                       AS belong_area,  -- 产品归属考核区域
    scenic_topic,                                                                 -- 景区主题
    CAST(resource_scenic_id AS BIGINT)                           AS resource_land_id,  -- 业态景区ID
    resource_scenic_name                                         AS resource_land_name,  -- 业态景区名称
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,    -- 票ID
    ticket_full_name                                             AS ticket_name,  -- 票全称
    CAST(resource_id AS BIGINT)                                  AS resource_id,  -- 资源中心资源ID
    distribute_system_code,                                                       -- 对接分销平台编码
    dsys_name                                                    AS distribute_system_name,  -- 对接分销平台名称
    CAST(order_mode AS INT)                                      AS booking_channel,  -- 下单渠道
    channel_name                                                 AS booking_channel_name,  -- 下单渠道名称
    CAST(ticket_price_amt AS DECIMAL(18,2))                      AS booking_price,  -- 下单单价（元）
    CAST(origin_ticket_qty AS BIGINT)                            AS booking_qty,  -- 下单票数
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS booking_pay_amt,  -- 下单金额（元）= 下单票数 × 销售单价
    CAST(pay_amt AS DECIMAL(18,2))                               AS order_pay_amt,  -- 订单实付（元）
    CAST(cost_price_amt AS DECIMAL(18,2))                        AS cost_price,   -- 结算单价（元）
    CAST(sale_price_amt AS DECIMAL(18,2))                        AS sale_price,   -- 销售单价（元）
    CAST(purchase_cost_amt AS DECIMAL(18,2))                     AS resource_center_purchase_price,  -- 采购商采购成本
    CAST(distributor_id AS BIGINT)                               AS distributor_id,  -- 一级分销商ID
    CAST(seller_id AS BIGINT)                                    AS seller_id,    -- 卖方ID
    CAST(buyer_id AS BIGINT)                                     AS buyer_id,     -- 买方ID
    taker_province                                               AS ticket_taker_province,  -- 取票人省
    taker_city                                                   AS ticket_taker_city,  -- 取票人市
    fail_code,                                                                    -- 对接下单失败处理码
    fail_reason,                                                                  -- 对接下单失败原因
    CAST(rc_supplier_id AS BIGINT)                               AS supplier_id,  -- 供应商ID（租户ID）
    ms_account                                                   AS resource_center_supplier_account,  -- 上架商账号
    ms_name                                                      AS resource_center_supplier_name,  -- 上架商名称
    ms_province                                                  AS resource_center_supplier_province,  -- 上架商所在省
    ms_city                                                      AS resource_center_supplier_city,  -- 上架商所在市
    ms_area                                                      AS resource_center_supplier_belong_area,  -- 上架商考核区域
    CAST(ms_test AS INT)                                         AS resource_center_supplier_is_test,  -- 上架商是否测试账号
    ms_type                                                      AS resource_center_supplier_type,  -- 上架商账号类型
    CAST(rc_purchase_id AS BIGINT)                               AS purchase_member_id,  -- 资源中心采购商ID
    mp_account                                                   AS resource_center_purchase_account,  -- 采购商账号
    mp_name                                                      AS resource_center_purchase_name,  -- 采购商名称
    mp_province                                                  AS resource_center_purchase_province,  -- 采购商所在省
    mp_city                                                      AS resource_center_purchase_city,  -- 采购商所在市
    mp_area                                                      AS resource_center_purchase_belong_area,  -- 采购商考核区域
    CAST(mp_test AS INT)                                         AS resource_center_purchase_is_test,  -- 采购商是否测试账号
    mp_type                                                      AS resource_center_purchase_type,  -- 采购商账号类型
    CAST(seq_supplier AS BIGINT)                                 AS order_no_supplier,  -- 上架商第几张资源中心订单（近 2 年）
    CAST(seq_purchase AS BIGINT)                                 AS order_no_purchase,  -- 采购商第几张资源中心订单（近 2 年）
    CAST(seq_land AS BIGINT)                                     AS order_no_land,  -- 景区第几张资源中心订单（近 2 年）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT o.*,
               s.scenic_name,                                                     -- 景区名称
               s.scenic_type_code,                                                -- 产品类型编码
               s.scenic_type_name,                                                -- 产品类型
               s.province_name AS s_province,
               s.city_name AS s_city,
               s.belong_area AS s_area,
               s.scenic_topic,                                                    -- 景区主题
               s.resource_scenic_id,
               s.resource_scenic_name,
               tk.ticket_full_name,
               cd.channel_name AS dsys_name,
               co.channel_name,
               rp.region_name AS taker_province,
               rc.region_name AS taker_city,
               api.fail_code,                                                     -- 对接下单失败处理码
               api.fail_reason,                                                   -- 对接下单失败原因
               dist.purchase_cost_amt,
               ms.account AS ms_account,
               ms.member_name AS ms_name,
               ms.province_name AS ms_province,
               ms.city_name AS ms_city,
               ds.district AS ms_area,
               ms.test_flag AS ms_test,
               ms.member_type_code AS ms_type,
               mp.account AS mp_account,
               mp.member_name AS mp_name,
               mp.province_name AS mp_province,
               mp.city_name AS mp_city,
               dp.district AS mp_area,
               mp.test_flag AS mp_test,
               mp.member_type_code AS mp_type
        FROM (
            SELECT a.*,
                   ROW_NUMBER() OVER (PARTITION BY a.rc_supplier_id ORDER BY a.order_time) AS seq_supplier,  -- 同一主键多次变更，按 binlog 时间倒序编号｜近 2 年内序号（同旧口径）
                   ROW_NUMBER() OVER (PARTITION BY a.rc_purchase_id ORDER BY a.order_time) AS seq_purchase,  -- 同一主键多次变更，按 binlog 时间倒序编号
                   ROW_NUMBER() OVER (PARTITION BY a.scenic_id ORDER BY a.order_time) AS seq_land  -- 同一主键多次变更，按 binlog 时间倒序编号
            FROM (
                SELECT /*+ BROADCAST(p) */ o.*,
                       p.sid AS rc_supplier_id,
                       p.fid AS rc_purchase_id,
                       ROW_NUMBER() OVER (PARTITION BY COALESCE(NULLIF(o.remote_order_no, ''), o.order_no) ORDER BY o.travel_date DESC) AS rn_one  -- 同一主键多次变更，按 binlog 时间倒序编号｜OTA 重试：远端单号唯一
                FROM dwd.dwd_ord_order_di o
                JOIN (SELECT DISTINCT CAST(sid AS BIGINT) AS sid, CAST(fid AS BIGINT) AS fid, CAST(ticket_id AS BIGINT) AS ticket_id
                      FROM ods.ods_prd_resource_purchase_df WHERE travel_date = '${bizdate}') p
                  ON p.ticket_id = o.ticket_id AND p.fid = o.buyer_id             -- 按 ticket_id、buyer_id→fid 关联｜采购商用资源中心采购的票下单
                WHERE o.travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 732), 'yyyyMMdd')
                  AND o.test_flag = 0
                  AND o.pay_status <> '2'
            ) a                                                                   -- 主表当日增量，按主键取最新一条
            WHERE a.rn_one = 1
        ) o
        LEFT JOIN dim.dim_prd_scenic_df s ON s.scenic_id = o.scenic_id
        LEFT JOIN dim.dim_prd_ticket_df tk ON tk.ticket_id = o.ticket_id
        LEFT JOIN dim.dim_trf_channel_f co                                        -- 关联「下单渠道 / 分销平台维度」
          ON co.channel_type = 'ORDER_CHANNEL' AND co.channel_code = CAST(o.order_mode AS STRING)
        LEFT JOIN dim.dim_trf_channel_f cd                                        -- 关联「下单渠道 / 分销平台维度」
          ON cd.channel_type = 'DISTRIBUTE_SYSTEM' AND cd.channel_code = o.distribute_system_code  -- 按 distribute_system_code→channel_code 关联
        LEFT JOIN dim.dim_opr_region_f rp ON rp.region_code = o.taker_province_code
        LEFT JOIN dim.dim_opr_region_f rc ON rc.region_code = o.taker_city_code
        LEFT JOIN dim.dim_sup_member_df ms ON ms.member_id = o.rc_supplier_id
        LEFT JOIN dim.dim_sup_member_df mp ON mp.member_id = o.rc_purchase_id
        LEFT JOIN ods.ods_opr_resource_center_district_df ds                      -- 关联「资源中心区县」
          ON ds.province = ms.province_name AND ds.travel_date = '${bizdate}'     -- 按 province_name→province 关联
        LEFT JOIN ods.ods_opr_resource_center_district_df dp                      -- 关联「资源中心区县」
          ON dp.province = mp.province_name AND dp.travel_date = '${bizdate}'     -- 按 province_name→province 关联
        LEFT JOIN (SELECT order_no, MAX(CAST(handle_status AS STRING)) AS fail_code, MAX(error_msg) AS fail_reason FROM dwd.dwd_trf_api_order_di
                   WHERE travel_date = '${bizdate}'                               -- 只取当日分区
                     AND fail_flag = 1 GROUP BY order_no) api ON api.order_no = o.order_no
        LEFT JOIN (SELECT order_no, buyer_id, SUM(price_amt * ticket_qty) AS purchase_cost_amt FROM dwd.dwd_ord_order_distribution_di
                   WHERE travel_date = '${bizdate}' GROUP BY order_no,            -- 只取当日分区
                   buyer_id) dist ON dist.order_no = o.order_no AND dist.buyer_id = o.rc_purchase_id
        WHERE o.travel_date = '${bizdate}'                                        -- 只取当日分区｜序号在近 2 年上算好后，只落当日下单
    ) t
