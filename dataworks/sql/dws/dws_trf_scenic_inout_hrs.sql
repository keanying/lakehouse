-- ================================================================================================
-- dws.dws_trf_scenic_inout_hrs  景区出入园小时汇总
-- 粒度：1行=1小时×景区×闸机组×终端
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_trf_scenic_inout_di
-- 替代旧任务 17 个（上线对数一致后下线）：
--   · 业务工厂/票务数据/出入园/出入园周月数据汇总工作流/dws_scenic_inout_cycle_summary_d_i（EMR_SPARK_SQL，cron 00 20 00 * * ?）
--   · 业务工厂/票务数据/出入园/出入园周月数据汇总工作流/dws_scenic_inout_week_summary_d_i（EMR_SPARK_SQL，cron 00 20 00 * * ?）
--   · 业务工厂/票务数据/出入园/出入园周月数据汇总工作流/dws_scenic_inout_week_summary_last_d_f（EMR_SPARK_SQL，cron 00 20 00 * * ?）
--   · 业务工厂/票务数据/终端过闸/终端过闸汇总工作流/dws_daily_terminal_pass_summary_d_i（EMR_SPARK_SQL，cron 00 15 00 * * ?）
--   · 业务工厂/票务数据/终端过闸/终端过闸汇总工作流_小时维度/dws_hourly_terminal_pass_summary_d_i（EMR_SPARK_SQL，cron 00 21 00 * * ?）
--   · 业务工厂/票务数据/终端过闸/终端过闸汇总工作流/dws_monthly_terminal_pass_summary_d_i（EMR_SPARK_SQL，cron 00 15 00 * * ?）
--   · 业务工厂/票务数据/终端过闸/终端过闸汇总工作流/dws_yearly_terminal_pass_summary_d_i（EMR_SPARK_SQL，cron 00 15 00 * * ?）
--   · 业务工厂/票务数据/终端过闸/终端过闸汇总工作流/dws_daily_report_terminal_pass_full_d_i（EMR_SPARK_SQL，cron 00 15 00 * * ?）
--   · 业务工厂/票务数据/终端过闸/终端过闸汇总工作流_小时维度/dws_hourly_report_terminal_pass_full_d_i（EMR_SPARK_SQL，cron 00 21 00 * * ?）
--   · 业务工厂/票务数据/终端过闸/分终端汇总工作流/dws_daily_report_branch_terminal_summary_d_i（EMR_SPARK_SQL，cron 00 05 00 * * ?）
--   · 业务工厂/票务数据/终端过闸/分终端汇总工作流/dws_daily_report_ticket_branch_terminal_summary_d_i（EMR_SPARK_SQL，cron 00 05 00 * * ?）
--   · 业务工厂/票务数据/终端过闸/分终端汇总工作流/dws_monthly_report_branch_terminal_summary_d_i（EMR_SPARK_SQL，cron 00 05 00 * * ?）
--   · … 另 5 个
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：inout = dwd.dwd_trf_scenic_inout_di（闸机进出流水，闸机组取自 dim_trf_gate_f）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_trf_scenic_inout_hrs PARTITION (travel_date = '${bizdate}')
SELECT
    scenic_id,
    gate_group_id,
    terminal_no,
    stat_hour,
    SUM(enter_qty)                                               AS enter_qty,
    SUM(exit_qty)                                                AS exit_qty,
    SUM(SUM(in_park_qty)) OVER (PARTITION BY scenic_id, gate_group_id, terminal_no ORDER BY stat_hour) AS in_park_qty,   -- 在园 = 当日累计入园 − 累计出园（截至该小时）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- inout：闸机进出流水，闸机组取自 dim_trf_gate_f
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,
        COALESCE(gate_group_id, CAST(-1 AS BIGINT))                  AS gate_group_id,
        terminal_no,
        COALESCE(HOUR(inout_time), CAST(-1 AS INT))                  AS stat_hour,
        SUM(IF(inout_type = 'IN', person_qty, 0))                    AS enter_qty,
        SUM(IF(inout_type = 'OUT', person_qty, 0))                   AS exit_qty,
        SUM(CASE inout_type WHEN 'IN' THEN person_qty WHEN 'OUT' THEN -person_qty ELSE 0 END) AS in_park_qty
    FROM (
        SELECT /*+ BROADCAST(g) */ i.*, g.gate_group_id
        FROM dwd.dwd_trf_scenic_inout_di i
        LEFT JOIN (SELECT terminal_no, MAX(gate_group_id) AS gate_group_id FROM dim.dim_trf_gate_f GROUP BY terminal_no) g
               ON g.terminal_no = i.terminal_no
        WHERE i.travel_date = '${bizdate}'
    ) t
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)), COALESCE(gate_group_id, CAST(-1 AS BIGINT)), terminal_no, COALESCE(HOUR(inout_time), CAST(-1 AS INT))
) u
GROUP BY scenic_id, gate_group_id, terminal_no, stat_hour
