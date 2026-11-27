-- ================================================================================================
-- dwd.dwd_prd_resource_order_di  资源中心订单明细
-- 粒度：1行=1张经资源中心采购商品产生的订单
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：dwd_ord_order_di、ods_prd_resource_purchase_df、dim_prd_resource_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/财务部/资源中心考核2/dwd_resource_center_order_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 资源中心订单 = 标准订单明细 ∩ 资源中心采购关系（采购商 + 票），不再单独从业务库拉一遍订单（旧 dwd_resource_center_order_d_f 重算订单）
--   · 名称 / 账号 / 省市等冗余维度属性不在明细计算，查询时关联 dim_sup_member_df、dim_prd_scenic_df
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_prd_resource_order_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    order_no,                                                                     -- 订单号
    resource_id,                                                                  -- 资源ID
    rc_supplier_id                                               AS supplier_id,  -- 供应商ID（租户ID）
    rc_purchase_id                                               AS purchase_member_id,  -- 采购会员ID
    '${bizdate}'                                                 AS stat_date,    -- 统计日期
    remote_order_no,                                                              -- 远程订单号
    order_status,                                                                 -- 订单状态
    ticket_qty,                                                                   -- 票数
    order_time,                                                                   -- 逻辑下单时间
    first_verify_time                                            AS vertify_time,  -- 验证时间
    rc_supplier_id                                               AS resource_center_supplier_id,  -- 资源中心供应商ID（租户ID）
    rc_purchase_id                                               AS resource_center_purchase_id,  -- 采购商ID
    scenic_id,                                                                    -- 景区ID
    CAST(NULL AS STRING)                                         AS scenic_name,  -- 景区名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS scenic_type,  -- 产品类型编码｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.land_type）
    CAST(NULL AS STRING)                                         AS scenic_type_name,  -- 景区类型｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS scenic_province_name,  -- 景区省名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS scenic_city_name,  -- 景区城市名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS belong_area,  -- 产品归属区域｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.belong_area）
    ticket_id,                                                                    -- 票ID
    CAST(NULL AS STRING)                                         AS ticket_name,  -- 票名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_name,  -- 资源名｜冗余维度属性：查询时关联维表，建议从明细移除
    distribute_system_code                                       AS distribute_system_type,  -- 对接分销平台类型
    CAST(NULL AS STRING)                                         AS distribute_system_name,  -- 对接分销平台名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(order_mode AS STRING)                                   AS booking_channel,  -- 销售渠道ID
    CAST(NULL AS STRING)                                         AS booking_channel_name,  -- 销售渠道名称｜冗余维度属性：查询时关联维表，建议从明细移除
    ticket_price_amt                                             AS booking_price,  -- 票价
    origin_ticket_qty                                            AS booking_qty,  -- 预定票数
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS booking_pay_amt,  -- 预定金额
    pay_amt                                                      AS order_pay_amt,  -- 订单支付金额
    distributor_id,                                                               -- 一级分销商id
    seller_id,                                                                    -- 销售者id
    buyer_id,                                                                     -- 购买者id
    CAST(NULL AS STRING)                                         AS ticket_taker_province,  -- 客源省｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS ticket_taker_city,  -- 客源市｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS fail_reason,  -- 失败原因｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.fail_reason）
    CAST(NULL AS STRING)                                         AS fail_code,    -- 失败代码｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.fail_code）
    IF(distribute_system_code = 'OTA', 1, 0)                     AS is_ota,       -- ota订单？ 是/否
    CAST(NULL AS STRING)                                         AS resource_center_supplier_account,  -- 资源中心供应商账户｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_name,  -- 资源中心供应商名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_province,  -- 资源中心供应商省｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_city,  -- 资源中心供应商市｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_belong_area,  -- 资源中心供应商所属区域｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_is_test,  -- 资源中心供应商是否测试｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_type,  -- 资源中心供应商类型｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.resource_center_supplier_type）
    CAST(NULL AS STRING)                                         AS resource_center_supplier_auto_get,  -- 资源中心供应商自动get（待确认）｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_account,  -- 资源中心采购账户｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_name,  -- 资源中心采购名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_province,  -- 资源中心采购省｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_city,  -- 资源中心采购市｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_belong_area,  -- 资源中心采购所属区域｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_is_test,  -- 资源中心采购是否测试｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_type,  -- 资源中心采购类型｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.resource_center_purchase_type）
    CAST(NULL AS BIGINT)                                         AS order_no_supplier,  -- 供货商订单序号｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.order_no_supplier）
    CAST(NULL AS BIGINT)                                         AS order_no_purchase,  -- 采购商订单序号｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.order_no_purchase）
    CAST(NULL AS BIGINT)                                         AS order_no_land,  -- 产品订单序号｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.order_no_land）
    CAST(NULL AS BIGINT)                                         AS resource_land_id,  -- 业态景区id｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.resource_land_id）
    CAST(NULL AS STRING)                                         AS resource_land_name,  -- 业态景区名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS BIGINT)                                         AS resource_center_purchase_price,  -- 采购商采购成本价｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.resource_center_purchase_price）
    CAST(NULL AS STRING)                                         AS scenic_topic,  -- 景区主题｜冗余维度属性：查询时关联维表，建议从明细移除
    cost_price_amt                                               AS cost_price,   -- 供货商成本价
    sale_price_amt                                               AS sale_price,   -- 零售价
    CAST(NULL AS BIGINT)                                         AS rn,           -- 价格排序｜待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.rn）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT /*+ BROADCAST(p) */ o.*,
               p.sid AS rc_supplier_id,
               p.fid AS rc_purchase_id
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT CAST(sid AS BIGINT) AS sid, CAST(fid AS BIGINT) AS fid, CAST(ticket_id AS BIGINT) AS ticket_id
              FROM ods.ods_prd_resource_purchase_df WHERE travel_date = '${bizdate}') p
          ON p.ticket_id = o.ticket_id AND p.fid = o.buyer_id                     -- 按 ticket_id、buyer_id→fid 关联｜采购商用资源中心采购的票下单
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0                    -- 只取当日分区，并按条件过滤
    ) t
