-- ================================================================================================
-- dim.dim_opr_dict_f  公共码表
-- 粒度：1行=1个码值
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：ods_opr_common_dict_df、ods_opr_order_status_df、ods_opr_land_topic_df、ods_opr_resource_type_df
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据中台/同步任务/MySQL_to_Hive/同步-其他/s_dim_order_status_o_f（DI，cron 00 27 00 * * ?）
--   · 数据平台/平台湖仓工作流/经营数据/dwd_opr_dashboard_user_auth_df（EMR_SPARK_SQL，cron 00 00 00 * * ?）
-- 业务规则 / 修正：
--   · 旧系统码值散落在 40+ 个脚本的 CASE WHEN（账号类型、订单操作、景区类型、主子单 …），同一码值多处写法不一
-- 性能：
--   · 码值集中一张表，下游 BROADCAST 关联
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_opr_dict_f
SELECT dict_type, dict_code, dict_name, DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM (
    -- ① 业务库通用码表（逻辑删除的不要）
    SELECT dict_type, CAST(code AS STRING) AS dict_code, name AS dict_name
    FROM ods.ods_opr_common_dict_df
    WHERE travel_date = '${bizdate}' AND COALESCE(del_flag, '0') = '0'
    UNION ALL
    -- ② 订单状态
    SELECT 'order_status', CAST(order_status AS STRING), order_status_name FROM ods.ods_opr_order_status_df WHERE travel_date = '${bizdate}'
    UNION ALL
    -- ③ 景区主题
    SELECT 'scenic_topic', land_topic, land_topic_name FROM ods.ods_opr_land_topic_df WHERE travel_date = '${bizdate}'
    UNION ALL
    -- ④ 景区类型：A-景区 B-线路 C-酒店 F-套票 G-餐饮 H-演出 I-年卡 J-特产 K-计时产品
    SELECT 'scenic_type', resource_type, resource_type_name FROM ods.ods_opr_resource_type_df WHERE travel_date = '${bizdate}'
    UNION ALL
    -- ⑤ 平台内置码值：原来写死在各脚本里，统一收口
    SELECT dict_type, dict_code, dict_name FROM VALUES
        -- 订单操作（uu_order_track.action → 标准编码，dwd_ord_order_track_di.track_action 用标准编码）
        ('track_action', 'BOOK', '下单'), ('track_action', 'MODIFY', '修改（减票）'), ('track_action', 'CANCEL', '取消'),
        ('track_action', 'PRINT', '取票（出票）'), ('track_action', 'PAY', '支付'), ('track_action', 'VERIFY', '验证'),
        ('track_action', 'REVOKE', '撤销'), ('track_action', 'REVOKE_MODIFY', '撤改'), ('track_action', 'REPRINT', '重打印'),
        ('track_action', 'EXPIRE', '过期'), ('track_action', 'ADD_TICKET', '加票'), ('track_action', 'FINISH', '完结'),
        ('track_action', 'AFTER_SALE', '售后'), ('track_action', 'OTHER', '其他（退票申请处理、离线下载等，不出指标）'),
        -- 账号类型（pft_member.dtype）
        ('member_type', '0', '供应商'), ('member_type', '1', '分销商'), ('member_type', '2', '资源方'), ('member_type', '3', '合并终端后的资源方'),
        ('member_type', '5', '普通用户'), ('member_type', '6', '员工'), ('member_type', '7', '集团账号'), ('member_type', '9', '平台管理员'),
        -- 票状态（uu_jq_ticket.status）
        ('ticket_status', '1', '上架'), ('ticket_status', '2', '下架'), ('ticket_status', '6', '删除'),
        -- 支付状态（uu_ss_order.pay_status）
        ('pay_status', '0', '现场支付'), ('pay_status', '1', '已支付'), ('pay_status', '2', '未支付'),
        -- 套票角色（pft_package_tickets）
        ('package_role', '0', '普通票'), ('package_role', '1', '套票主票'), ('package_role', '2', '套票子票'),
        -- 标准化维度值
        ('order_role', 'MAIN', '主票（含单票）'), ('order_role', 'SUB', '套票子票'),
        ('team_type', 'TEAM', '团队'), ('team_type', 'INDIVIDUAL', '散客'),
        ('user_type', 'TOURIST', '游客'), ('user_type', 'MEMBER', '平台会员（商户账号）'), ('user_type', 'CUSTOMER', 'CRM 客户')
        AS v(dict_type, dict_code, dict_name)
) d
