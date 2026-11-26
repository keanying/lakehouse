-- ================================================================================================
-- dim.dim_trf_gate_f  闸机 / 终端维度
-- 粒度：1行=1个终端（闸机 / 手持机）
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_trf_device_inout_journal_di
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 业务工厂/票务数据/出入园/出入园数据校验工作流/dim_input_group_gate_d_f（EMR_SPARK_SQL，cron 00 23 00 * * ?）
-- 业务规则 / 修正：
--   · 过渡期从旧表 dim_input_group_gate_d_f 平移：旧逻辑由多张中间表 / 外部采集加工，字段与 ODS 不能直接对应；字段口径按字典，上线顺序：先平移保证下游可切换，再按字段清单把「待确认」逐个改为从 ODS 计算后下线旧链路
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_trf_gate_f
SELECT
    CAST(NULL AS STRING)                                         AS terminal_no,   -- 待确认：来源未同步
    CAST(NULL AS BIGINT)                                         AS gate_group_id,   -- 待确认：来源未同步
    CAST(NULL AS BIGINT)                                         AS scenic_id,   -- 待确认：来源未同步
    gid,
    CAST(sid AS BIGINT)                                          AS supplier_id,
    gate,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM dim_input_group_gate_d_f
WHERE pt = ${bizdate}   -- 过渡期：读旧表，按字段清单逐步改为从 ODS 计算
