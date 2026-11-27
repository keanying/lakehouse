-- ================================================================================================
-- dwd.dwd_ord_annual_card_trade_di  年卡交易明细
-- 粒度：1行=1笔年卡交易（售卡 / 续费 / 激活 / 退卡）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_ord_annual_card_trade_di、ods_ord_annual_card_order_di、ods_ord_annual_card_renew_di、ods_ord_annual_card_active_apply_df
-- 业务规则 / 修正：
--   · 年卡交易为主表；待确认：type 码值（0 售卡 / 1 续费 / 2 激活）上线前与年卡业务库核对
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_ord_annual_card_trade_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS STRING)                                           AS trade_no,
    CONCAT('#', SUBSTRING_INDEX(card_no, '#', -1))               AS card_no,
    CAST(pid AS BIGINT)                                          AS card_product_id,
    CASE CAST(type AS STRING) WHEN '0' THEN 'SELL' WHEN '1' THEN 'RENEW' WHEN '2' THEN 'ACTIVE' ELSE CAST(type AS STRING) END AS trade_type,
    CAST(pay_money AS DECIMAL(18,2)) / 100                       AS trade_amt,
    add_time                                                     AS trade_time,
    id,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(NULL AS BIGINT)                                         AS annual_id,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.annual_id）
    CAST(NULL AS STRING)                                         AS mobile_mask,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.mobile）
    CAST(NULL AS STRING)                                         AS id_card_no_mask,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.id_card）
    CAST(NULL AS STRING)                                         AS name,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.name）
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(NULL AS STRING)                                         AS audit_materials,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.audit_materials）
    CAST(NULL AS BIGINT)                                         AS state,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.state）
    CAST(NULL AS STRING)                                         AS apply_remark,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.apply_remark）
    CAST(NULL AS STRING)                                         AS audit_remark,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.audit_remark）
    CAST(NULL AS BIGINT)                                         AS op_id,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.op_id）
    CAST(NULL AS STRING)                                         AS active_params,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.active_params）
    CAST(NULL AS STRING)                                         AS create_time,   -- 待确认：来源未同步（旧字段 ods_ord_annual_card_active_apply_df.create_time）
    update_time,
    card_no                                                      AS card_no_mask,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY update_time DESC) AS rn
        FROM ods.ods_ord_annual_card_trade_di
        WHERE travel_date = '${bizdate}'
    ) t
WHERE rn = 1   -- 同一记录当日多次变更取最新
