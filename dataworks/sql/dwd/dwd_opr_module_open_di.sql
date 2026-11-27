-- ================================================================================================
-- dwd.dwd_opr_module_open_di  应用模块开通明细
-- 粒度：1行=1次模块 / 套餐开通或续费
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_opr_module_used_df、ods_opr_module_used_ext_df、ods_opr_module_package_log_df、dim_opr_module_package_df
-- 替代旧任务 4 个（上线对数一致后下线）：
--   · 数据中台/数仓明细层(DWD)/dwd_用户域/购买套餐、应用模块/dwd_user_module_d_f（EMR_SPARK_SQL，cron 00 10 00 * * ?）
--   · 数据中台/数仓明细层(DWD)/dwd_用户域/购买套餐、应用模块/dwd_user_package_d_f（EMR_SPARK_SQL，cron 00 00 02 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dwd_mkt_module_combo_open_df（SERVERLESS_SPARK_SQL，cron 00 00 00 * * ?）
--   · 数据中台/数据维度(DIM)/dim_用户域/dim_user_module_d_f（EMR_SPARK_SQL，cron 00 30 00 * * ?）
-- 业务规则 / 修正：
--   · 模块开通记录（module_used 全量快照，按开通创建日 = bizdate 取当日事件）；合同 / 销售信息在 module_used_ext，待按 member_id + module_id 补关联
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_opr_module_open_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    CAST(module_id AS BIGINT)                                    AS module_id,    -- 应用模块id
    CAST(member_id AS BIGINT)                                    AS member_id,    -- 游客ID
    begin_time                                                   AS open_time,    -- 开通时间
    expire_time,                                                                  -- 到期时间
    '${bizdate}'                                                 AS stat_date,    -- 统计日期
    CAST(member_id AS BIGINT)                                    AS user_id,      -- 用户id
    CAST(NULL AS STRING)                                         AS module_name,  -- 应用模块名称｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS contract_no,  -- 合同编号｜待确认：来源未同步（旧字段 dwd_user_module_d_f.contract_no）
    CAST(NULL AS STRING)                                         AS out_trade_no,  -- 支付流水｜待确认：来源未同步（旧字段 dwd_user_module_d_f.out_trade_no）
    CAST(NULL AS STRING)                                         AS sign_time,    -- 签约时间｜待确认：来源未同步（旧字段 dwd_user_module_d_f.sign_time）
    CAST(NULL AS STRING)                                         AS sale_man_id,  -- 签单人id｜待确认：来源未同步（旧字段 dwd_user_module_d_f.sale_man_id）
    CAST(NULL AS STRING)                                         AS sale_man_name,  -- 签单人姓名｜冗余维度属性：查询时关联维表，建议从明细移除
    CAST(NULL AS STRING)                                         AS sale_man_department,  -- 签单人部门｜待确认：来源未同步（旧字段 dwd_user_module_d_f.sale_man_department）
    CAST(NULL AS BIGINT)                                         AS buy_no,       -- 购买序号｜待确认：来源未同步（旧字段 dwd_user_module_d_f.buy_no）
    CAST(NULL AS BIGINT)                                         AS open_type,    -- 开通类型id｜待确认：来源未同步（旧字段 dwd_user_module_d_f.open_type）
    CAST(NULL AS BIGINT)                                         AS module_price,  -- 模块单价（分）｜待确认：来源未同步（旧字段 dwd_user_module_d_f.module_price）
    CAST(NULL AS BIGINT)                                         AS module_pay_amt,  -- 模块支付金额（分）｜待确认：来源未同步（旧字段 dwd_user_module_d_f.module_pay_amount）
    CAST(NULL AS BIGINT)                                         AS module_negotiated_price,  -- 模块开票金额（分）｜待确认：来源未同步（旧字段 dwd_user_module_d_f.module_negotiated_price）
    CAST(NULL AS BIGINT)                                         AS module_performance_amt,  -- 模块业绩金额（分）｜待确认：来源未同步（旧字段 dwd_user_module_d_f.module_performance_amount）
    CAST(NULL AS BIGINT)                                         AS module_actual_amt,  -- 模块终止时实际消费金额（分）｜待确认：来源未同步（旧字段 dwd_user_module_d_f.module_actual_amount）
    create_time                                                  AS add_time,     -- 开通日期
    begin_time                                                   AS valid_start_time,  -- 模块开始日期
    expire_time                                                  AS valid_end_time,  -- 模块结束日期
    CAST(NULL AS STRING)                                         AS stop_time,    -- 模块终止日期｜待确认：来源未同步（旧字段 dwd_user_module_d_f.stop_time）
    CAST(NULL AS STRING)                                         AS stop_type,    -- 终止类型｜待确认：来源未同步（旧字段 dwd_user_module_d_f.stop_type）
    CAST(NULL AS BIGINT)                                         AS period_days,  -- 期限（天）｜待确认：来源未同步（旧字段 dwd_user_module_d_f.period_days）
    status                                                       AS module_status,  -- 模块状态   过期/当前/未到
    CAST(NULL AS STRING)                                         AS remark,       -- 备注｜待确认：来源未同步（旧字段 dwd_user_module_d_f.remark）
    CAST(NULL AS STRING)                                         AS back_detail,  -- 回款明细｜待确认：来源未同步（旧字段 dwd_user_module_d_f.back_detail）
    CAST(NULL AS BIGINT)                                         AS customer_service_id,  -- 客户成功经理平台账户id｜待确认：来源未同步（旧字段 dwd_user_package_d_f.customer_service_id）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM ods.ods_opr_module_used_df
WHERE travel_date = '${bizdate}'                                                  -- 只取当日分区
  AND DATE_FORMAT(create_time, 'yyyyMMdd') = '${bizdate}'                         -- 全量快照取当日事件
