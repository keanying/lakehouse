-- ================================================================================================
-- dwd.dwd_opr_package_open_di  套餐开通明细
-- 粒度：1行=1次套餐开通 / 续费 / 升级（当日新增）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_opr_module_package_log_df、ods_opr_module_package_log_ext_df、dim_opr_module_package_df、dim_sup_staff_df
-- 替代旧任务 1 个（上线对数一致后下线）：
--   · 数据中台/数仓明细层(DWD)/dwd_用户域/购买套餐、应用模块/dwd_user_package_d_f（EMR_SPARK_SQL，cron 00 00 02 * * ?）
-- 业务规则 / 修正：
--   · 套餐状态（有效 / 到期）查询时按 valid_end_time 与统计日比较得到，不在明细落；客服部门原取 OA（下线），改为员工组
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_opr_package_open_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(id AS BIGINT)                                           AS package_open_id,  -- 套餐开通记录ID
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 开通商户ID
    CAST(package_id AS BIGINT)                                   AS package_id,   -- 套餐ID
    package_name,                                                                 -- 套餐名称
    CAST(package_role AS INT)                                    AS package_role,  -- 套餐适用角色
    CAST(package_fee_amt AS DECIMAL(18,2))                       AS package_price_amt,  -- 套餐标价（元）
    CAST(is_update AS INT)                                       AS upgrade_flag,  -- 是否升级
    CAST(cooperation_mode AS INT)                                AS cooperation_mode,  -- 合作模式
    CAST(open_type AS INT)                                       AS open_type,    -- 开通类型
    CAST(is_pay AS INT)                                          AS pay_back_flag,  -- 是否回款
    CAST(stop_type AS INT)                                       AS stop_type,    -- 终止类型
    FROM_UNIXTIME(begin_time)                                    AS valid_start_time,  -- 开始时间
    FROM_UNIXTIME(end_time)                                      AS valid_end_time,  -- 结束时间
    CAST(DATEDIFF(FROM_UNIXTIME(end_time), FROM_UNIXTIME(begin_time)) AS INT) AS period_days,  -- 周期天数 = 结束 − 开始
    FROM_UNIXTIME(CAST(GET_JSON_OBJECT(time_details, IF(
        stop_type = 1,
        '$.stop_time',
        '$.end_time'
    )) AS BIGINT)) AS stop_time,                                                  -- 终止时间
    FROM_UNIXTIME(add_time)                                      AS open_time,    -- 开通时间
    contract_no,                                                                  -- 合同编号
    IF(sign_time > 0, FROM_UNIXTIME(sign_time), NULL)            AS sign_time,    -- 签约时间
    out_trade_no,                                                                 -- 支付流水号
    CAST(saleman AS BIGINT)                                      AS sale_man_id,  -- 签单人员工ID
    sale_name                                                    AS sale_man_name,  -- 签单人姓名
    sale_group                                                   AS sale_man_group,  -- 签单人员工组
    CAST(customer_service AS BIGINT)                             AS customer_service_id,  -- 客服员工ID
    cs_name                                                      AS customer_service_name,  -- 客服姓名
    cs_group                                                     AS customer_service_group,  -- 客服员工组
    CAST(GET_JSON_OBJECT(details, '$.receipt') AS DECIMAL(18,2)) / 100 AS package_pay_amt,  -- 实收金额（元）
    CAST(GET_JSON_OBJECT(details, '$.agree') AS DECIMAL(18,2)) / 100 AS package_invoice_amt,  -- 开票（协议）金额（元）
    CAST(GET_JSON_OBJECT(details, '$.achievement_money') AS DECIMAL(18,2)) / 100 AS package_performance_amt,  -- 业绩金额（元）
    repayment_record,                                                             -- 回款记录
    remarks                                                      AS remark,       -- 备注
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM (
        SELECT l.*,
               x.stop_type,                                                       -- 终止类型
               x.time_details,
               x.contract_no,                                                     -- 合同编号
               x.sign_time,                                                       -- 签约时间
               x.repayment_record,                                                -- 回款记录
               x.cooperation_mode,                                                -- 合作模式
               x.open_type,                                                       -- 开通类型
               pk.package_name,                                                   -- 套餐名称
               pk.package_role,                                                   -- 套餐适用角色
               pk.package_fee_amt,
               s1.staff_name AS sale_name,
               s1.staff_group_name AS sale_group,
               s2.staff_name AS cs_name,
               s2.staff_group_name AS cs_group
        FROM ods.ods_opr_module_package_log_df l
        LEFT JOIN ods.ods_opr_module_package_log_ext_df x                         -- 关联「用户开通套餐情况扩展表」｜合同 / 合作模式扩展
          ON x.package_log_id = l.id AND x.travel_date = '${bizdate}'             -- 按 id→package_log_id 关联
        LEFT JOIN (SELECT package_id, MAX(package_name) AS package_name, MAX(package_role) AS package_role, MAX(package_fee_amt) AS package_fee_amt
                   FROM dim.dim_opr_module_package_df WHERE package_id > 0 GROUP BY package_id) pk ON pk.package_id = l.package_id
        LEFT JOIN dim.dim_sup_staff_df s1 ON s1.staff_id = l.saleman              -- 签单人
        LEFT JOIN dim.dim_sup_staff_df s2 ON s2.staff_id = l.customer_service     -- 客服
        WHERE l.travel_date = '${bizdate}' AND FROM_UNIXTIME(l.add_time, 'yyyyMMdd') = '${bizdate}'  -- 只取当日分区，并按条件过滤｜全量快照取当日开通
    ) t
