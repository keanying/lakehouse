-- ================================================================================================
-- dwd.dwd_opr_module_open_di  应用模块开通明细
-- 粒度：1行=1次模块开通（当日新开通）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_opr_module_used_df、ods_opr_module_used_ext_df、ods_opr_module_used_log_df、ods_opr_module_price_df、dim_opr_module_package_df、dim_sup_staff_df
-- 替代旧任务 3 个（上线对数一致后下线）：
--   · 数据中台/数仓明细层(DWD)/dwd_用户域/购买套餐、应用模块/dwd_user_module_d_f（EMR_SPARK_SQL，cron 00 10 00 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dwd_mkt_module_combo_open_df（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_user_module_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
-- 业务规则 / 修正：
--   · 金额在扩展表 details（JSON：receipt 实收 / agree 开票 / achievement_money 业绩 / real_money 终止实际消费，单位分），按 JSON 解析（旧系统按字符串截取）
--   · 签单人部门原取 OA 人员表（OA 下线），改为平台员工组
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_opr_module_open_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS module_open_id,  -- 模块开通记录ID
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 开通商户ID
    CAST(module_id AS BIGINT)                                    AS module_id,    -- 模块ID
    module_name,                                                                  -- 模块名称
    CAST(type AS INT)                                            AS open_type,    -- 开通方式
    CAST(status AS INT)                                          AS module_status,  -- 状态
    CAST(use_free AS INT)                                        AS free_trial_flag,  -- 是否试用过免费期
    CAST(buy_no AS INT)                                          AS buy_no,       -- 该商户该模块第几次开通
    FROM_UNIXTIME(create_time)                                   AS open_time,    -- 开通时间
    COALESCE(FROM_UNIXTIME(CAST(GET_JSON_OBJECT(time_details, '$.start_time') AS BIGINT)),
             FROM_UNIXTIME(begin_time)) AS valid_start_time,                      -- 有效期开始
    COALESCE(FROM_UNIXTIME(CAST(GET_JSON_OBJECT(time_details, '$.end_time') AS BIGINT)),
             FROM_UNIXTIME(expire_time)) AS valid_end_time,                       -- 有效期结束
    CAST(stop_type AS INT)                                       AS stop_type,    -- 终止类型
    FROM_UNIXTIME(CAST(GET_JSON_OBJECT(time_details, IF(
        stop_type = 1,
        '$.stop_time',
        '$.end_time'
    )) AS BIGINT)) AS stop_time,                                                  -- 终止时间
    CASE price_mode WHEN 1 THEN 365 WHEN 2 THEN 90 WHEN 3 THEN 30 END AS period_days,  -- 资费周期天数
    CAST(price_fee AS DECIMAL(18,2)) / 100                       AS module_price_amt,  -- 开通时资费（元）
    contract_no,                                                                  -- 合同编号
    COALESCE(ext_trade_no, log_trade_no)                         AS out_trade_no,  -- 支付流水号
    IF(sign_time > 0, FROM_UNIXTIME(sign_time), NULL)            AS sign_time,    -- 签约时间
    CAST(saleman AS BIGINT)                                      AS sale_man_id,  -- 签单人员工ID
    staff_name                                                   AS sale_man_name,  -- 签单人姓名
    staff_group_name                                             AS sale_man_group,  -- 签单人员工组
    CAST(GET_JSON_OBJECT(details, '$.receipt') AS DECIMAL(18,2)) / 100 AS module_pay_amt,  -- 实收金额（元）
    CAST(GET_JSON_OBJECT(details, '$.agree') AS DECIMAL(18,2)) / 100 AS module_invoice_amt,  -- 开票金额（元）
    CAST(GET_JSON_OBJECT(details, '$.achievement_money') AS DECIMAL(18,2)) / 100 AS module_performance_amt,  -- 业绩金额（元）
    CAST(GET_JSON_OBJECT(details, '$.real_money') AS DECIMAL(18,2)) / 100 AS module_actual_amt,  -- 终止时实际消费金额（元）
    repayment_record,                                                             -- 回款记录
    sign_remark,                                                                  -- 签单备注
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT u.*,
               mp.module_name,                                                    -- 模块名称
               e.contract_no,                                                     -- 合同编号
               e.out_trade_no AS ext_trade_no,
               e.sign_time,                                                       -- 签约时间
               e.saleman,
               e.details,
               e.time_details,
               e.stop_type,                                                       -- 终止类型
               e.repayment_record,                                                -- 回款记录
               e.sign_remark,                                                     -- 签单备注
               lg.out_trade_no AS log_trade_no,
               pr.fee AS price_fee,
               pr.mode AS price_mode,
               st.staff_name,
               st.staff_group_name
        FROM (SELECT *, ROW_NUMBER() OVER (                                       -- 同一主键多次变更，按 binlog 时间倒序编号｜全量快照上算第几次开通
            PARTITION BY member_id,
            module_id ORDER BY create_time,
            id
        ) AS buy_no                                                               -- 该商户该模块第几次开通
              FROM ods.ods_opr_module_used_df WHERE travel_date = '${bizdate}') u
        LEFT JOIN (SELECT module_id, MAX(module_name) AS module_name FROM dim.dim_opr_module_package_df GROUP BY module_id) mp  -- 关联「应用模块与套餐维度」按键聚合
          ON mp.module_id = u.module_id                                           -- 按 module_id 关联
        LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY member_id, module_id ORDER BY update_time DESC) AS rk FROM ods.ods_opr_module_used_ext_df
                   WHERE travel_date = '${bizdate}'                               -- 只取当日分区｜合同 / 金额扩展，取最新
                     AND module_type = 1) e ON e.member_id = u.member_id AND e.module_id = u.module_id AND e.rk = 1
        LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY member_id, module_id ORDER BY add_time DESC) AS rk FROM ods.ods_opr_module_used_log_df
                   WHERE travel_date = '${bizdate}'                               -- 只取当日分区｜最近一次已支付开通
                     AND type = 1
                     AND status = 2) lg ON lg.member_id = u.member_id AND lg.module_id = u.module_id AND lg.rk = 1
        LEFT JOIN ods.ods_opr_module_price_df pr ON pr.id = lg.price_id AND pr.travel_date = '${bizdate}'  -- 开通时资费
        LEFT JOIN dim.dim_sup_staff_df st ON st.staff_id = e.saleman              -- 签单人
        WHERE FROM_UNIXTIME(u.create_time, 'yyyyMMdd') = '${bizdate}'             -- 当日新开通
    ) t
