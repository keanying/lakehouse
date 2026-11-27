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
--   · 来源：inout = dwd.dwd_trf_scenic_inout_di（闸机进出流水，闸机组取自 dim_trf_gate_f）；vfy = dwd.dwd_ord_verify_di（核销：验证日分区 = bizdate）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_trf_scenic_inout_hrs PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    scenic_id,                                                                    -- 景区ID
    gate_group_id,                                                                -- 闸机组ID
    terminal_no,                                                                  -- 终端号（闸机 / 手持机）
    stat_hour,                                                                    -- 小时
    ticket_id,                                                                    -- 票ID
    SUM(enter_qty)                                               AS enter_qty,    -- 入园人次
    SUM(exit_qty)                                                AS exit_qty,     -- 出园人次
    SUM(SUM(in_park_qty)) OVER (                                                  -- 在园 = 当日累计入园 − 累计出园（截至该小时）
        PARTITION BY scenic_id,
        gate_group_id,                                                            -- 闸机组ID
        terminal_no,                                                              -- 终端号（闸机 / 手持机）
        ticket_id ORDER BY stat_hour
    ) AS in_park_qty,                                                             -- 在园人数
    SUM(verify_order_qty)                                        AS verify_order_qty,  -- 验证订单数
    SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数
    SUM(verify_person_qty)                                       AS verify_person_qty,  -- 核销人数
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
    -- inout：闸机进出流水，闸机组取自 dim_trf_gate_f
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        COALESCE(gate_group_id, CAST(-1 AS BIGINT))                  AS gate_group_id,  -- 闸机组ID
        terminal_no,                                                              -- 终端号（闸机 / 手持机）
        COALESCE(HOUR(inout_time), CAST(-1 AS INT))                  AS stat_hour,  -- 小时
        CAST(-1 AS BIGINT)                                           AS ticket_id,  -- 票ID｜该来源无此维度，取默认值
        SUM(IF(inout_type = 'IN', person_qty, 0))                    AS enter_qty,  -- 入园人次
        SUM(IF(inout_type = 'OUT', person_qty, 0))                   AS exit_qty,  -- 出园人次
        SUM(CASE inout_type WHEN 'IN' THEN person_qty WHEN 'OUT' THEN -person_qty ELSE 0 END) AS in_park_qty,  -- 在园人数
        CAST(0 AS BIGINT)                                            AS verify_order_qty,  -- 验证订单数
        CAST(0 AS BIGINT)                                            AS verify_ticket_qty,  -- 验证票数
        CAST(0 AS BIGINT)                                            AS verify_person_qty  -- 核销人数
    FROM (
        SELECT /*+ BROADCAST(g) */ i.*, g.gate_group_id
        FROM dwd.dwd_trf_scenic_inout_di i
        LEFT JOIN (SELECT terminal_no, MAX(gate_group_id) AS gate_group_id FROM dim.dim_trf_gate_f GROUP BY terminal_no) g  -- 关联「闸机 / 终端维度」按键聚合
               ON g.terminal_no = i.terminal_no                                   -- 按 terminal_no 关联
        WHERE i.travel_date = '${bizdate}'                                        -- 只取当日分区
    ) t
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             COALESCE(gate_group_id, CAST(-1 AS BIGINT)),
             terminal_no,                                                         -- 终端号（闸机 / 手持机）
             COALESCE(HOUR(inout_time), CAST(-1 AS INT))
    UNION ALL
    -- vfy：核销：验证日分区 = bizdate
    SELECT
        COALESCE(scenic_id, CAST(-1 AS BIGINT))                      AS scenic_id,  -- 景区ID
        CAST(-1 AS BIGINT)                                           AS gate_group_id,  -- 闸机组ID｜该来源无此维度，取默认值
        terminal_no,                                                              -- 终端号（闸机 / 手持机）
        COALESCE(HOUR(verify_time), CAST(-1 AS INT))                 AS stat_hour,  -- 小时
        COALESCE(ticket_id, CAST(-1 AS BIGINT))                      AS ticket_id,  -- 票ID
        CAST(0 AS BIGINT)                                            AS enter_qty,  -- 入园人次
        CAST(0 AS BIGINT)                                            AS exit_qty,  -- 出园人次
        CAST(NULL AS BIGINT)                                         AS in_park_qty,  -- 在园人数
        COUNT(DISTINCT order_no)                                     AS verify_order_qty,  -- 验证订单数
        SUM(verify_ticket_qty)                                       AS verify_ticket_qty,  -- 验证票数
        SUM(COALESCE(traveler_qty, verify_ticket_qty))               AS verify_person_qty  -- 核销人数
    FROM dwd.dwd_ord_verify_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND test_flag = 0
    GROUP BY COALESCE(scenic_id, CAST(-1 AS BIGINT)),                             -- 按粒度键汇总
             terminal_no,                                                         -- 终端号（闸机 / 手持机）
             COALESCE(HOUR(verify_time), CAST(-1 AS INT)),
             COALESCE(ticket_id, CAST(-1 AS BIGINT))
) u                                                                               -- 各来源合并后的明细
GROUP BY scenic_id, gate_group_id, terminal_no, stat_hour, ticket_id              -- 按粒度键汇总
