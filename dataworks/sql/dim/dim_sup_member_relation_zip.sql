-- ================================================================================================
-- dim.dim_sup_member_relation_zip  商户分销关系拉链
-- 粒度：1行=1对供应商-分销商关系×1个有效区间
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_sup_member_relation_df、ods_trf_evolute_group_df
-- 替代旧任务 3 个（上线对数一致后下线）：
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_user_relationship_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_distributor_group_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_prod_distribute_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
-- 业务规则 / 修正：
--   · 替代 dim_user_relationship_d_f、dim_distributor_group_d_f、dim_prod_distribute_d_f：旧系统每天全量重建关系快照再 JOIN 分组
-- 性能：
--   · 关系表自带业务时间，直接生成拉链区间；分组先按 供应商 × 分销商 去重再关联
-- ================================================================================================
-- 分销关系拉链：关系本身带建立 / 解除时间（rectime / cuttime），直接按业务时间生成区间，不需要每日比对快照
WITH r AS (
    SELECT CAST(parent_id AS BIGINT) AS parent_id, CAST(son_id AS BIGINT) AS son_id, son_id_type, CAST(ship_type AS BIGINT) AS ship_type, status, rectime, cuttime,
           ROW_NUMBER() OVER (PARTITION BY parent_id, son_id ORDER BY rectime DESC) AS rn
    FROM ods.ods_sup_member_relation_df
    WHERE travel_date = '${bizdate}'
),
grp AS (   -- 分销商分组：同一供应商下一个分销商可能在多个组，取最新加入的
    SELECT sid, fid, group_id
    FROM (SELECT CAST(sid AS BIGINT) AS sid, CAST(fid AS BIGINT) AS fid, CAST(group_id AS BIGINT) AS group_id,
                 ROW_NUMBER() OVER (PARTITION BY sid, fid ORDER BY rectime DESC) AS rn
          FROM ods.ods_trf_evolute_group_fid_df WHERE travel_date = '${bizdate}') t
    WHERE rn = 1
)
INSERT OVERWRITE TABLE dim.dim_sup_member_relation_zip
SELECT /*+ BROADCAST(g) */
    r.parent_id                                                      AS supplier_id,
    r.son_id                                                         AS distributor_id,
    DATE_FORMAT(r.rectime, 'yyyyMMdd')                               AS start_date,
    IF(r.status = '0', '99991231', DATE_FORMAT(COALESCE(r.cuttime, r.rectime), 'yyyyMMdd')) AS end_date,   -- 有效关系 end_date = 99991231
    '${bizdate}'                                                   AS stat_date,
    r.parent_id,
    r.son_id,
    r.son_id_type                                                    AS son_type,
    r.ship_type                                                      AS relationship_type,
    g.group_id                                                       AS distributor_group,
    r.rectime                                                        AS add_time,
    r.cuttime                                                        AS cut_time,
    r.status                                                         AS order_status,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM r
LEFT JOIN grp g ON g.sid = r.parent_id AND g.fid = r.son_id
WHERE r.rn = 1
