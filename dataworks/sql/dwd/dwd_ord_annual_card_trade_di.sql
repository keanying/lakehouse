-- ================================================================================================
-- dwd.dwd_ord_annual_card_trade_di  年卡交易明细
-- 粒度：1行=1笔年卡交易（售卡 / 续费 / 补卡 / 取消 / 激活 / 特权支付）或 1 次激活申请
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_ord_annual_card_trade_di、ods_ord_annual_card_active_apply_df、dim_prd_ticket_df
-- 业务规则 / 修正：
--   · 修正交易类型码值：源表 0 售卡 1 续费 2 补卡 3 取消 4 激活 5 验证（特权支付），原映射把 2（补卡）当激活
--   · 激活申请人姓名 / 手机 / 证件、审核材料（证件照片）、激活参数报文属个人信息，不进事实表
-- ================================================================================================
-- 置空列：多个源表 UNION ALL 归一时，某源表没有的字段置空（各源表字段对照见各分支）
INSERT OVERWRITE TABLE dwd.dwd_ord_annual_card_trade_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
-- (1) ods_ord_annual_card_trade_di
SELECT
    'TRADE'                                                      AS trade_source,  -- 来源
    CAST(id AS BIGINT)                                           AS trade_id,     -- 记录ID（与来源联合唯一）
    ordernum                                                     AS trade_no,     -- 交易订单号（激活申请为申请ID）
    ordernum                                                     AS order_no,     -- 平台订单号（售卡 / 续费订单）
    CAST(card_id AS BIGINT)                                      AS card_id,      -- 年卡ID
    CAST(pid AS BIGINT)                                          AS card_product_id,  -- 年卡产品ID
    p_name                                                       AS card_package_name,  -- 卡套餐名称
    CASE type
        WHEN 0 THEN 'SELL'
        WHEN 1 THEN 'RENEW'
        WHEN 2 THEN 'REISSUE'
        WHEN 3 THEN 'CANCEL'
        WHEN 4 THEN 'ACTIVE'
        WHEN 5 THEN 'PRIVILEGE_PAY'
        ELSE CAST(type AS STRING)
    END AS trade_type,                                                            -- 交易类型
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,    -- 票ID
    CAST(t_scenic_id AS BIGINT)                                  AS scenic_id,    -- 景区ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 持卡会员ID
    CAST(payway AS INT)                                          AS pay_way,      -- 支付方式
    CAST(source AS INT)                                          AS trade_channel,  -- 交易来源
    CAST(num AS BIGINT)                                          AS trade_qty,    -- 数量
    CAST(pay_money AS DECIMAL(18,2)) / 100                       AS trade_amt,    -- 支付金额（元）
    card_no                                                      AS card_no_mask,  -- 实体卡号（ODS 已脱敏）
    virtual_no,                                                                   -- 虚拟卡号
    physics_no,                                                                   -- 物理卡号
    CAST(NULL AS INT)                                            AS audit_status,  -- 激活申请审核状态：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS apply_remark,  -- 激活申请备注：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS audit_remark,  -- 激活审核备注：此源表无此字段，置空
    remark,                                                                       -- 交易备注
    CAST(operator_id AS BIGINT)                                  AS operator_id,  -- 操作员 / 审核人ID
    FROM_UNIXTIME(add_time)                                      AS trade_time,   -- 交易 / 申请时间
    FROM_UNIXTIME(update_time)                                   AS update_time,  -- 更新时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT a.*, tk.t_scenic_id
        FROM ods.ods_ord_annual_card_trade_di a                                   -- 主表「年卡卡交易」
        LEFT JOIN (SELECT ticket_id, MAX(scenic_id) AS t_scenic_id FROM dim.dim_prd_ticket_df GROUP BY ticket_id) tk  -- 关联「票维度」按键聚合｜票 → 景区
          ON tk.ticket_id = a.ticket_id                                           -- 按 ticket_id 关联
        WHERE a.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
UNION ALL
-- (2) ods_ord_annual_card_active_apply_df
SELECT
    'ACTIVE_APPLY'                                               AS trade_source,  -- 来源
    CAST(id AS BIGINT)                                           AS trade_id,     -- 记录ID（与来源联合唯一）
    CAST(id AS STRING)                                           AS trade_no,     -- 交易订单号（激活申请为申请ID）
    CAST(NULL AS STRING)                                         AS order_no,     -- 平台订单号（售卡 / 续费订单）：此源表无此字段，置空
    CAST(annual_id AS BIGINT)                                    AS card_id,      -- 年卡ID
    CAST(NULL AS BIGINT)                                         AS card_product_id,  -- 年卡产品ID：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_package_name,  -- 卡套餐名称：此源表无此字段，置空
    'ACTIVE_APPLY'                                               AS trade_type,   -- 交易类型
    CAST(tid AS BIGINT)                                          AS ticket_id,    -- 票ID
    CAST(t_scenic_id AS BIGINT)                                  AS scenic_id,    -- 景区ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(NULL AS BIGINT)                                         AS member_id,    -- 持卡会员ID：此源表无此字段，置空
    CAST(NULL AS INT)                                            AS pay_way,      -- 支付方式：此源表无此字段，置空
    CAST(NULL AS INT)                                            AS trade_channel,  -- 交易来源：此源表无此字段，置空
    CAST(NULL AS BIGINT)                                         AS trade_qty,    -- 数量：此源表无此字段，置空
    CAST(NULL AS DECIMAL(18,2))                                  AS trade_amt,    -- 支付金额（元）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS card_no_mask,  -- 实体卡号（ODS 已脱敏）：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS virtual_no,   -- 虚拟卡号：此源表无此字段，置空
    CAST(NULL AS STRING)                                         AS physics_no,   -- 物理卡号：此源表无此字段，置空
    CAST(state AS INT)                                           AS audit_status,  -- 激活申请审核状态
    apply_remark,                                                                 -- 激活申请备注
    audit_remark,                                                                 -- 激活审核备注
    CAST(NULL AS STRING)                                         AS remark,       -- 交易备注：此源表无此字段，置空
    CAST(op_id AS BIGINT)                                        AS operator_id,  -- 操作员 / 审核人ID
    create_time                                                  AS trade_time,   -- 交易 / 申请时间
    update_time,                                                                  -- 更新时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT a.*, tk.t_scenic_id
        FROM ods.ods_ord_annual_card_active_apply_df a                            -- 主表「年卡卡激活申请」
        LEFT JOIN (SELECT ticket_id, MAX(scenic_id) AS t_scenic_id FROM dim.dim_prd_ticket_df GROUP BY ticket_id) tk  -- 关联「票维度」按键聚合｜票 → 景区
          ON tk.ticket_id = a.tid                                                 -- 按 tid→ticket_id 关联
        WHERE a.travel_date = '${bizdate}'                                        -- 只取当日分区｜全量快照取当日申请
          AND REGEXP_REPLACE(SUBSTR(a.create_time, 1, 10), '-', '') = '${bizdate}'
    ) t
