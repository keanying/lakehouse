-- ================================================================================================
-- dwd.dwd_sup_customer_visit_di  客户拜访 / 接待明细
-- 粒度：1行=1条客户拜访接待登记（OA 建模表单）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_sup_oa_customer_visit_ledger_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据平台/平台湖仓工作流/经营数据/dwd_mkt_oa_customer_reception_detail_df（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · OA 拼音缩写字段（gslx / jq / lhs …）含义未确认，未纳入；平台ID 字段为文本，取其中数字作为商户ID
--   · 旧表来自 OA 接待明细中间表，改为直接读登记台账 ODS
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_sup_customer_visit_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS visit_id,     -- 登记记录ID
    CAST(requestid AS BIGINT)                                    AS request_id,   -- OA 流程请求ID
    lcbh                                                         AS flow_no,      -- OA 流程编号
    khmc                                                         AS customer_name,  -- 客户名称
    CAST(REGEXP_EXTRACT(ptid, '(\\d+)', 1) AS BIGINT)            AS member_id,    -- 客户平台账号ID
    CAST(hzlx AS INT)                                            AS cooperation_type,  -- 合作类型（OA 选项值）
    CAST(s AS INT)                                               AS visit_type,   -- 登记类型（OA 选项值）
    CAST(tc AS INT)                                              AS commission_flag,  -- 是否计提成（OA 选项值）
    CAST(ddyc AS INT)                                            AS order_abnormal_flag,  -- 是否订单异常（OA 选项值）
    CAST(je AS DECIMAL(18,2))                                    AS amount,       -- 金额（元）
    CAST(modedatacreater AS BIGINT)                              AS staff_id,     -- 登记人（OA 人员ID）
    CONCAT(modedatacreatedate, ' ', modedatacreatetime)          AS visit_time,   -- 登记时间
    modedatamodifydatetime                                       AS modify_time,  -- 最后修改时间
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_sup_oa_customer_visit_ledger_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
  AND REGEXP_REPLACE(modedatacreatedate, '-', '') = '${bizdate}'                  -- 全量快照取当日事件
