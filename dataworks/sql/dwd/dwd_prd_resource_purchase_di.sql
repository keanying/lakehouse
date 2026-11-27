-- ================================================================================================
-- dwd.dwd_prd_resource_purchase_di  资源采购明细
-- 粒度：1行=1次资源采购操作（自动 / 手动，含失败）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_prd_resource_purchase_recode_list_df
-- 业务规则 / 修正：
--   · 采购记录表为全量快照，按操作日 = bizdate 取当日采购事件；当前采购关系（是否已采购）仍以 ods_prd_resource_purchase_df 为准（资源中心订单关联用）
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_prd_resource_purchase_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS purchase_record_id,  -- 采购记录ID
    CAST(sid AS BIGINT)                                          AS supplier_id,  -- 供应商ID（租户ID）
    CAST(fid AS BIGINT)                                          AS purchaser_id,  -- 采购分销商ID
    CAST(pid AS BIGINT)                                          AS product_id,   -- 产品ID
    CAST(ticket_id AS BIGINT)                                    AS ticket_id,    -- 票ID
    CAST(status AS INT)                                          AS purchase_status,  -- 采购结果
    CAST(operation_status AS INT)                                AS purchase_mode,  -- 采购方式
    reason                                                       AS fail_reason,  -- 采购失败原因
    CAST(price_spread AS DECIMAL(18,2)) / 100                    AS price_spread_amt,  -- 分销差价（元）
    group_ids                                                    AS auto_group_ids,  -- 自动分销的分组列表（逗号分隔）
    CAST(all_distributor AS INT)                                 AS all_distributor_flag,  -- 是否默认分销给所有分销商
    CAST(opid AS BIGINT)                                         AS operator_id,  -- 操作员ID
    FROM_UNIXTIME(add_time)                                      AS purchase_time,  -- 采购操作时间
    FROM_UNIXTIME(update_time)                                   AS update_time,  -- 更新时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_prd_resource_purchase_recode_list_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
  AND FROM_UNIXTIME(add_time, 'yyyyMMdd') = '${bizdate}'                          -- 全量快照取当日事件
