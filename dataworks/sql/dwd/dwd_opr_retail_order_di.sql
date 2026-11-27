-- ================================================================================================
-- dwd.dwd_opr_retail_order_di  零售订单商品明细
-- 粒度：1行=1个零售单据商品行（含退货 / 退款行）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_opr_retail_yinbao_ticket_item_di、ods_opr_retail_yinbao_ticket_di、ods_opr_retail_sixun_order_sale_detail_di、ods_opr_retail_sixun_order_di、ods_opr_retail_sixun_shop_df、ods_opr_retail_xisland_order_item_di、ods_opr_retail_xisland_order_di、ods_opr_retail_xisland_refund_order_item_di、ods_opr_retail_xisland_refund_order_di
-- 业务规则 / 修正：
--   · 原表只到单头（件数、商品为空），改为商品行；银豹人数取单头就餐人数报文，思迅取单头人数，均只记在每单第一行，按行求和不重复
--   · 思迅商品行没有实付，按单头 实付 / 应收 比例分摊；待确认：银豹就餐人数报文的键名（peopleNum）上线前核对
-- ================================================================================================
-- 置空列：多个源表 UNION ALL 归一时，某源表没有的字段置空（各源表字段对照见各分支）
INSERT OVERWRITE TABLE dwd.dwd_opr_retail_order_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- (1) ods_opr_retail_yinbao_ticket_item_di
SELECT
    'yinbao'                                                     AS retail_vendor,  -- 零售系统
    CAST(id AS BIGINT)                                           AS item_id,      -- 商品行记录ID
    sn                                                           AS order_no,     -- 零售单据号
    CAST(NULL AS STRING)                                         AS refund_no,    -- 退款单号（退货行）：此源表无此字段，置空
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 供应商ID（零售系统绑定的商户）
    CAST(con_sys_bind AS BIGINT)                                 AS con_sys_bind,  -- 对接系统绑定ID
    CAST(app_id AS STRING)                                       AS shop_code,    -- 门店编码 / 名称
    business_category                                            AS shop_category,  -- 门店分类
    COALESCE(product_barcode, CAST(product_uid AS STRING))       AS goods_code,   -- 商品编码
    name                                                         AS goods_name,   -- 商品名称
    CAST(NULL AS STRING)                                         AS goods_category,  -- 商品分类：此源表无此字段，置空
    IF(ticket_type = 'SELL_RETURN', 1, 0)                        AS refund_flag,  -- 是否退货
    CAST(invalid AS INT)                                         AS invalid_flag,  -- 单据是否作废（银豹）
    CAST(quantity AS DECIMAL(18,2))                              AS item_qty,     -- 数量
    CAST(sell_price AS DECIMAL(18,2))                            AS unit_price,   -- 单价（元）
    CAST(sell_price * quantity AS DECIMAL(18,2))                 AS sale_amt,     -- 应收金额
    CAST(total_amount AS DECIMAL(18,2))                          AS pay_amt,      -- 实付金额
    CAST(sell_price * quantity - total_amount AS DECIMAL(18,2))  AS discount_amt,  -- 优惠金额（元）
    CAST(total_profit AS DECIMAL(18,2))                          AS profit_amt,   -- 利润
    CAST(h_people AS BIGINT)                                     AS number_of_people,  -- 消费人数
    cashier                                                      AS operator,     -- 收银 / 操作人
    date_time                                                    AS order_time,   -- 单据时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT i.*, h.app_id, h.ticket_type, h.date_time, h.invalid, h.cashier, '' AS business_category,
               IF(                                                                -- 人数只记首行
                   ROW_NUMBER() OVER (PARTITION BY i.uid ORDER BY i.id) = 1,      -- 同一主键多次变更，按 binlog 时间倒序编号
                   CAST(GET_JSON_OBJECT(h.ticket_spend_detail, '$.peopleNum') AS BIGINT),
                   0
               ) AS h_people
        FROM ods.ods_opr_retail_yinbao_ticket_item_di i
        JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY uid ORDER BY sys_update_time DESC) AS rn
            FROM ods.ods_opr_retail_yinbao_ticket_di WHERE travel_date = '${bizdate}') h
          ON h.uid = i.uid AND h.rn = 1                                           -- 按 uid 关联｜单头：类型 / 时间 / 门店
        WHERE i.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
UNION ALL
-- (2) ods_opr_retail_sixun_order_sale_detail_di
SELECT
    'sixun'                                                      AS retail_vendor,  -- 零售系统
    CAST(id AS BIGINT)                                           AS item_id,      -- 商品行记录ID
    order_no,                                                                     -- 零售单据号
    CAST(NULL AS STRING)                                         AS refund_no,    -- 退款单号（退货行）：此源表无此字段，置空
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 供应商ID（零售系统绑定的商户）
    CAST(con_sys_bind AS BIGINT)                                 AS con_sys_bind,  -- 对接系统绑定ID
    shop_code,                                                                    -- 门店编码 / 名称
    shop_category,                                                                -- 门店分类
    product_name                                                 AS goods_code,   -- 商品编码
    product_name                                                 AS goods_name,   -- 商品名称
    CAST(NULL AS STRING)                                         AS goods_category,  -- 商品分类：此源表无此字段，置空
    IF(order_status = '2', 1, 0)                                 AS refund_flag,  -- 是否退货
    0                                                            AS invalid_flag,  -- 单据是否作废（银豹）：此源表无此字段，置空
    CAST(sale_num AS DECIMAL(18,2))                              AS item_qty,     -- 数量
    CAST(NULL AS DECIMAL(18,2))                                  AS unit_price,   -- 单价（元）：此源表无此字段，置空
    CAST(sale_money AS DECIMAL(18,2))                            AS sale_amt,     -- 应收金额
    CAST(sale_money * h_pay / NULLIF(h_sale, 0) AS DECIMAL(18,2)) AS pay_amt,     -- 实付金额
    CAST(sale_money - sale_money * h_pay / NULLIF(h_sale, 0) AS DECIMAL(18,2)) AS discount_amt,  -- 优惠金额（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS profit_amt,   -- 利润：此源表无此字段，置空
    CAST(h_people AS BIGINT)                                     AS number_of_people,  -- 消费人数
    operator,                                                                     -- 收银 / 操作人
    sale_time                                                    AS order_time,   -- 单据时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT d.*,
               h.status AS order_status,                                          -- 订单状态
               h.payment_money AS h_pay,
               h.sale_money AS h_sale,
               sh.shop_category,                                                  -- 门店分类
               IF(
                   ROW_NUMBER() OVER (PARTITION BY d.order_no ORDER BY d.seq_no) = 1,  -- 同一主键多次变更，按 binlog 时间倒序编号
                   h.number_of_people,                                            -- 消费人数
                   0
               ) AS h_people
        FROM ods.ods_opr_retail_sixun_order_sale_detail_di d
        LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_no ORDER BY sync_update_time DESC) AS rn
            FROM ods.ods_opr_retail_sixun_order_di WHERE travel_date = '${bizdate}') h
          ON h.order_no = d.order_no AND h.rn = 1                                 -- 按 order_no 关联｜单头：状态 / 实付 / 人数
        LEFT JOIN (SELECT shop_code, MAX(shop_category) AS shop_category
            FROM ods.ods_opr_retail_sixun_shop_df WHERE travel_date = '${bizdate}' GROUP BY shop_code) sh
          ON sh.shop_code = d.shop_code                                           -- 按 shop_code 关联｜门店分类
        WHERE d.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
UNION ALL
-- (3) ods_opr_retail_xisland_order_item_di
SELECT
    'xisland'                                                    AS retail_vendor,  -- 零售系统
    CAST(id AS BIGINT)                                           AS item_id,      -- 商品行记录ID
    order_code                                                   AS order_no,     -- 零售单据号
    CAST(NULL AS STRING)                                         AS refund_no,    -- 退款单号（退货行）：此源表无此字段，置空
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 供应商ID（零售系统绑定的商户）
    CAST(con_sys_bind AS BIGINT)                                 AS con_sys_bind,  -- 对接系统绑定ID
    store_name                                                   AS shop_code,    -- 门店编码 / 名称
    business_type                                                AS shop_category,  -- 门店分类
    product_name                                                 AS goods_code,   -- 商品编码
    product_name                                                 AS goods_name,   -- 商品名称
    class_name                                                   AS goods_category,  -- 商品分类
    0                                                            AS refund_flag,  -- 是否退货：此源表无此字段，置空
    0                                                            AS invalid_flag,  -- 单据是否作废（银豹）：此源表无此字段，置空
    CAST(quantity AS DECIMAL(18,2))                              AS item_qty,     -- 数量
    CAST(unit_price AS DECIMAL(18,2))                            AS unit_price,   -- 单价（元）
    CAST(amount AS DECIMAL(18,2))                                AS sale_amt,     -- 应收金额
    CAST(pay_amount AS DECIMAL(18,2))                            AS pay_amt,      -- 实付金额
    CAST(discount_amount AS DECIMAL(18,2))                       AS discount_amt,  -- 优惠金额（元）
    CAST(NULL AS DECIMAL(18,2))                                  AS profit_amt,   -- 利润：此源表无此字段，置空
    0                                                            AS number_of_people,  -- 消费人数：此源表无此字段，置空
    create_name                                                  AS operator,     -- 收银 / 操作人
    order_create_time                                            AS order_time,   -- 单据时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT i.*, h.store_name, h.business_type, h.create_name
        FROM ods.ods_opr_retail_xisland_order_item_di i
        LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_code ORDER BY sync_update_time DESC) AS rn
            FROM ods.ods_opr_retail_xisland_order_di WHERE travel_date = '${bizdate}') h
          ON h.order_code = i.order_code AND h.rn = 1                             -- 按 order_code 关联
        WHERE i.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
UNION ALL
-- (4) ods_opr_retail_xisland_refund_order_item_di
SELECT
    'xisland'                                                    AS retail_vendor,  -- 零售系统
    CAST(id AS BIGINT)                                           AS item_id,      -- 商品行记录ID
    order_code                                                   AS order_no,     -- 零售单据号
    refund_code                                                  AS refund_no,    -- 退款单号（退货行）
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 供应商ID（零售系统绑定的商户）
    CAST(con_sys_bind AS BIGINT)                                 AS con_sys_bind,  -- 对接系统绑定ID
    store_name                                                   AS shop_code,    -- 门店编码 / 名称
    business_type                                                AS shop_category,  -- 门店分类
    product_name                                                 AS goods_code,   -- 商品编码
    product_name                                                 AS goods_name,   -- 商品名称
    class_name                                                   AS goods_category,  -- 商品分类
    CAST(1 AS INT)                                               AS refund_flag,  -- 是否退货
    0                                                            AS invalid_flag,  -- 单据是否作废（银豹）：此源表无此字段，置空
    CAST(quantity AS DECIMAL(18,2))                              AS item_qty,     -- 数量
    CAST(unit_price AS DECIMAL(18,2))                            AS unit_price,   -- 单价（元）
    CAST(refund_amount AS DECIMAL(18,2))                         AS sale_amt,     -- 应收金额
    CAST(refund_amount AS DECIMAL(18,2))                         AS pay_amt,      -- 实付金额
    CAST(0 AS DECIMAL(18,2))                                     AS discount_amt,  -- 优惠金额（元）：此源表无此字段，置空
    CAST(NULL AS DECIMAL(18,2))                                  AS profit_amt,   -- 利润：此源表无此字段，置空
    0                                                            AS number_of_people,  -- 消费人数：此源表无此字段，置空
    create_name                                                  AS operator,     -- 收银 / 操作人
    refund_create_time                                           AS order_time,   -- 单据时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT i.*, h.store_name, h.business_type, h.create_name
        FROM ods.ods_opr_retail_xisland_refund_order_item_di i
        LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY refund_code ORDER BY sync_update_time DESC) AS rn
            FROM ods.ods_opr_retail_xisland_refund_order_di WHERE travel_date = '${bizdate}') h
          ON h.refund_code = i.refund_code AND h.rn = 1                           -- 按 refund_code 关联
        WHERE i.travel_date = '${bizdate}' AND h.refund_status <> 2               -- 只取当日分区，并按条件过滤｜剔除退款失败
    ) t
