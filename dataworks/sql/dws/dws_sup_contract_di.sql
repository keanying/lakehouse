-- ================================================================================================
-- dws.dws_sup_contract_di  合同日汇总
-- 粒度：1行=1天×合同
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWD 当日分区
-- 上游：dwd_sup_contract_event_di、dim_sup_contract_df
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 业务工厂/内部信息/DWS/dws_contract_d_f_workflow/dws_contract_bill_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/DWS/dws_contract_d_f_workflow/dws_contract_by_post_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/DWS/dws_contract_d_f_workflow/dws_contract_call_back_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
--   · 业务工厂/内部信息/DWS/dws_contract_d_f_workflow/dws_contract_check_d_f（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 性能：
--   · 同一来源的指标在一个子查询里预聚合（一次扫描），各来源 UNION ALL 后按粒度汇总，不做明细级 JOIN
--   · 来源：contract = dwd.dwd_sup_contract_event_di（合同事件）
-- ================================================================================================
INSERT OVERWRITE TABLE dws.dws_sup_contract_di PARTITION (travel_date = '${bizdate}')
SELECT
    contract_no,
    SUM(contract_amt)                                            AS contract_amt,
    SUM(invoice_amt)                                             AS invoice_amt,
    SUM(payback_amt)                                             AS payback_amt,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- contract：合同事件
    SELECT
        contract_no,
        SUM(IF(event_type = 'SIGN', event_amt, 0))                   AS contract_amt,
        SUM(IF(event_type = 'INVOICE', event_amt, 0))                AS invoice_amt,
        SUM(IF(event_type = 'PAYBACK', event_amt, 0))                AS payback_amt
    FROM dwd.dwd_sup_contract_event_di
    WHERE travel_date = '${bizdate}'
    GROUP BY contract_no
) u
GROUP BY contract_no
