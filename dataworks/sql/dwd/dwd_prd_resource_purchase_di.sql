-- ================================================================================================
-- dwd.dwd_prd_resource_purchase_di  资源采购明细
-- 粒度：1行=1次资源采购操作（自动 / 手动，含失败）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_prd_resource_purchase_recode_list_df
-- 业务规则 / 修正：
--   · 采购记录表为全量快照，按操作日 = bizdate 取当日采购事件；当前采购关系（是否已采购）仍以 ods_prd_resource_purchase_df 为准（资源中心订单关联用）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_prd_resource_purchase_di PARTITION (travel_date = '${bizdate}')
SELECT
    CAST(id AS BIGINT)                                           AS purchase_record_id,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    CAST(fid AS BIGINT)                                          AS purchaser_id,
    CAST(pid AS BIGINT)                                          AS product_id,
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,
    CAST(status AS INT)                                          AS purchase_status,
    CAST(operation_status AS INT)                                AS purchase_mode,
    reason                                                       AS fail_reason,
    CAST(price_spread AS DECIMAL(18,2)) / 100                    AS price_spread_amt,
    group_ids                                                    AS auto_group_ids,
    CAST(all_distributor AS INT)                                 AS all_distributor_flag,
    CAST(opid AS BIGINT)                                         AS operator_id,
    FROM_UNIXTIME(add_time)                                      AS purchase_time,
    FROM_UNIXTIME(update_time)                                   AS update_time,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM ods.ods_prd_resource_purchase_recode_list_df
WHERE travel_date = '${bizdate}'
  AND FROM_UNIXTIME(add_time, 'yyyyMMdd') = '${bizdate}'   -- 全量快照取当日事件
