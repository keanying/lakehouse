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
INSERT OVERWRITE TABLE dwd.dwd_prd_resource_order_di PARTITION (travel_date = '${bizdate}')
SELECT
    order_no,
    resource_id,
    rc_supplier_id                                               AS supplier_id,
    rc_purchase_id                                               AS purchase_member_id,
    '${bizdate}'                                                 AS stat_date,
    remote_order_no,
    order_status,
    ticket_qty,
    order_time,
    first_verify_time                                            AS vertify_time,
    rc_supplier_id                                               AS resource_center_supplier_id,
    rc_purchase_id                                               AS resource_center_purchase_id,
    scenic_id,
    CAST(NULL AS STRING)                                         AS scenic_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS scenic_type,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.land_type）
    CAST(NULL AS STRING)                                         AS scenic_type_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS scenic_province_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS scenic_city_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS belong_area,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.belong_area）
    ticket_id,
    CAST(NULL AS STRING)                                         AS ticket_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    distribute_system_code                                       AS distribute_system_type,
    CAST(NULL AS STRING)                                         AS distribute_system_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(order_mode AS STRING)                                   AS booking_channel,
    CAST(NULL AS STRING)                                         AS booking_channel_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    ticket_price_amt                                             AS booking_price,
    origin_ticket_qty                                            AS booking_qty,
    CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))    AS booking_pay_amt,
    pay_amt                                                      AS order_pay_amt,
    distributor_id,
    seller_id,
    buyer_id,
    CAST(NULL AS STRING)                                         AS ticket_taker_province,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS ticket_taker_city,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS fail_reason,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.fail_reason）
    CAST(NULL AS STRING)                                         AS fail_code,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.fail_code）
    IF(distribute_system_code = 'OTA', 1, 0)                     AS is_ota,
    CAST(NULL AS STRING)                                         AS resource_center_supplier_account,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_province,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_city,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_belong_area,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_is_test,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_supplier_type,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.resource_center_supplier_type）
    CAST(NULL AS STRING)                                         AS resource_center_supplier_auto_get,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_account,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_province,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_city,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_belong_area,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_is_test,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS resource_center_purchase_type,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.resource_center_purchase_type）
    CAST(NULL AS BIGINT)                                         AS order_no_supplier,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.order_no_supplier）
    CAST(NULL AS BIGINT)                                         AS order_no_purchase,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.order_no_purchase）
    CAST(NULL AS BIGINT)                                         AS order_no_land,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.order_no_land）
    CAST(NULL AS BIGINT)                                         AS resource_land_id,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.resource_land_id）
    CAST(NULL AS STRING)                                         AS resource_land_name,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS BIGINT)                                         AS resource_center_purchase_price,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.resource_center_purchase_price）
    CAST(NULL AS STRING)                                         AS scenic_topic,   -- 冗余维度属性：查询时关联维表，建议从明细移除
    cost_price_amt                                               AS cost_price,
    sale_price_amt                                               AS sale_price,
    CAST(NULL AS BIGINT)                                         AS rn,   -- 待确认：来源未同步（旧字段 dwd_resource_center_order_d_f.rn）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT /*+ BROADCAST(p) */ o.*, p.sid AS rc_supplier_id, p.fid AS rc_purchase_id
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT CAST(sid AS BIGINT) AS sid, CAST(fid AS BIGINT) AS fid, CAST(ticket_id AS BIGINT) AS ticket_id
              FROM ods.ods_prd_resource_purchase_df WHERE travel_date = '${bizdate}') p
          ON p.ticket_id = o.ticket_id AND p.fid = o.buyer_id      -- 采购商用资源中心采购的票下单
        WHERE o.travel_date = '${bizdate}' AND o.test_flag = 0
    ) t
