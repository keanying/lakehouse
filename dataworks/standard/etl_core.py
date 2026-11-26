"""核心表加工逻辑（手写）：实体维度 + 订单域明细。

按旧系统真实业务规则重写（规则出处见每段注释），并做性能优化：
- 只读需要的列与分区（旧任务大量 SELECT *、全表 pt 扫描）
- 增量：订单按 update_time 采变更，只重算受影响的下单日分区（旧任务按下单日全量重跑，下单后的状态变化漏采）
- 订单属性在 DWD 一次性退化到操作 / 核销明细，DWS 不再回表关联订单
- 小维表 BROADCAST；码值统一查 dim_opr_dict_f，不再在每个脚本里写 CASE WHEN

返回 {表名: (SQL, [替代说明], [优化说明])}；字段顺序与字典字段清单一致（build 时自动校验）。
"""

P = "travel_date = '${bizdate}'"
NOW = "DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time"

# ODS 脱敏格式（见 ODS 同步任务）：手机号 = 前 7 位号段 + '#' + SHA256；证件号 = 前 6 位地区码 + 4 位出生年 + 1 位性别位 + '#' + SHA256
HASH = "SUBSTRING_INDEX({c}, '#', -1)"
PREFIX = "SUBSTRING_INDEX({c}, '#', 1)"

SQL = {}


def sql(name, why=(), perf=()):
    def deco(f):
        SQL[name] = (f().strip('\n'), list(why), list(perf))
        return f
    return deco


# ============================================================================ 码表
@sql('dim_opr_dict_f', why=['旧系统码值散落在 40+ 个脚本的 CASE WHEN（账号类型、订单操作、景区类型、主子单 …），同一码值多处写法不一'],
     perf=['码值集中一张表，下游 BROADCAST 关联'])
def _():
    return f"""
INSERT OVERWRITE TABLE dim.dim_opr_dict_f
SELECT dict_type, dict_code, dict_name, {NOW}
FROM (
    -- ① 业务库通用码表（逻辑删除的不要）
    SELECT dict_type, CAST(code AS STRING) AS dict_code, name AS dict_name
    FROM ods.ods_opr_common_dict_df
    WHERE {P} AND COALESCE(del_flag, '0') = '0'
    UNION ALL
    -- ② 订单状态
    SELECT 'order_status', CAST(order_status AS STRING), order_status_name FROM ods.ods_opr_order_status_df WHERE {P}
    UNION ALL
    -- ③ 景区主题
    SELECT 'scenic_topic', land_topic, land_topic_name FROM ods.ods_opr_land_topic_df WHERE {P}
    UNION ALL
    -- ④ 景区类型：A-景区 B-线路 C-酒店 F-套票 G-餐饮 H-演出 I-年卡 J-特产 K-计时产品
    SELECT 'scenic_type', resource_type, resource_type_name FROM ods.ods_opr_resource_type_df WHERE {P}
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
"""


# ============================================================================ 会员（平台账号）
@sql('dim_sup_member_df', why=['替代 dim_user_d_f 等：旧任务同步了银行卡号 / 支付宝账号等敏感字段并全部落维表，这里不再引入',
                               '旧测试账号判定有三种写法（分组 / 名称含“测试” / 测试用户库），统一为 group_id IN (2,3)'],
     perf=['分销平台识别是 LIKE 非等值关联：模式表很小，BROADCAST 后按最长匹配取一条，避免一账号多行',
           '供应商 / 分销商 / 大屏 / 淘宝标识用 LEFT SEMI 风格的去重子查询，避免一对多放大'])
def _():
    return f"""
WITH member AS (
    SELECT CAST(id AS BIGINT) AS member_id, dname, account, dtype, status, dcodeurl, CAST(customer_id AS BIGINT) AS customer_id,
           mobile, reg_source, creattime, lasttime, group_id
    FROM ods.ods_sup_member_df
    WHERE {P}
),
ext AS (
    SELECT CAST(fid AS BIGINT) AS member_id, com_name FROM ods.ods_sup_member_ext_df WHERE {P}
),
-- 对接分销平台：账号二维码链接匹配平台特征串；多条命中取特征串最长（最具体）的一条
dsys AS (
    SELECT member_id, distribute_system_type
    FROM (
        SELECT /*+ BROADCAST(p) */ m.member_id, p.distribute_system_type,
               ROW_NUMBER() OVER (PARTITION BY m.member_id ORDER BY LENGTH(p.dcodeurl_like) DESC) AS rn
        FROM member m
        JOIN (SELECT dcodeurl_like, distribute_system_type FROM ods.ods_opr_distribute_system_type_df WHERE {P} AND dcodeurl_like <> '') p
          ON m.dcodeurl LIKE CONCAT('%', p.dcodeurl_like, '%')
        WHERE m.dcodeurl <> ''
    ) t
    WHERE rn = 1
),
supplier AS (   -- 发布过景区即为供应商（不依赖 dim_prd_scenic_df，避免维表互相依赖）
    SELECT DISTINCT CAST(apply_did AS BIGINT) AS member_id FROM ods.ods_prd_scenic_df WHERE {P}
),
distributor AS (   -- 存在有效（status=0）分销关系的下级
    SELECT DISTINCT CAST(son_id AS BIGINT) AS member_id FROM ods.ods_sup_member_relation_df WHERE {P} AND status = '0'
),
datav AS (SELECT DISTINCT CAST(user_id AS BIGINT) AS member_id FROM ods.ods_opr_datav_auth_df WHERE {P}),
taobao AS (SELECT DISTINCT CAST(id2 AS BIGINT) AS member_id FROM ods.ods_trf_tb_bind_df WHERE {P}),
collect AS (   -- 独立收款渠道可能多条：合并成一个字段
    SELECT CAST(member_id AS BIGINT) AS member_id, CONCAT_WS('、', SORT_ARRAY(COLLECT_SET(channel_name))) AS self_collect_way
    FROM ods.ods_fin_merchant_payment_method_df
    WHERE {P}
    GROUP BY CAST(member_id AS BIGINT)
)
INSERT OVERWRITE TABLE dim.dim_sup_member_df
SELECT
    m.member_id,
    m.dname                                                          AS member_name,
    m.account,
    m.dtype                                                          AS member_type_code,
    m.status                                                         AS member_status,
    IF(s.member_id IS NOT NULL, 1, 0)                                AS supplier_flag,
    IF(d.member_id IS NOT NULL, 1, 0)                                AS distributor_flag,
    -- 3034 为南京途牛（历史硬编码，保留）；其余按对接平台类型
    IF(m.member_id = 3034 OR ds.distribute_system_type = 'OTA', 1, 0) AS ota_flag,
    CASE WHEN m.member_id = 3034 THEN 'OTA'
         WHEN m.dcodeurl <> '' THEN COALESCE(ds.distribute_system_type, 'OTHER')
    END                                                              AS distribute_system_code,
    m.customer_id,
    e.com_name                                                       AS company_name,
    {HASH.format(c='m.mobile')}                               AS contact_phone_hash,
    m.reg_source                                                     AS register_source,
    m.creattime                                                      AS register_time,
    m.lasttime                                                       AS last_login_time,
    IF(dv.member_id IS NOT NULL, 1, 0)                               AS datav_open_flag,
    IF(tb.member_id IS NOT NULL, 1, 0)                               AS taobao_bind_flag,
    c.self_collect_way,
    IF(m.group_id IN ('2', '3'), 1, 0)                               AS test_flag,
    {NOW}
FROM member m
LEFT JOIN ext         e  ON e.member_id  = m.member_id
LEFT JOIN dsys        ds ON ds.member_id = m.member_id
LEFT JOIN supplier    s  ON s.member_id  = m.member_id
LEFT JOIN distributor d  ON d.member_id  = m.member_id
LEFT JOIN datav       dv ON dv.member_id = m.member_id
LEFT JOIN taobao      tb ON tb.member_id = m.member_id
LEFT JOIN collect     c  ON c.member_id  = m.member_id
"""


# ============================================================================ 景区
@sql('dim_prd_scenic_df', why=['替代 dim_land_d_f、dim_attr_scenic_info_df 等 5 张',
                               '修正：业态景区名称被 CAST 成 INT（恒为空）；测试景区把 is_test_user=0 当测试；地区名两套城市表各取一半'],
     perf=['地区、码表、业态映射均为小表，BROADCAST', '业态映射多版本取最新一条，先去重再关联，避免景区行放大'])
def _():
    return f"""
WITH land AS (
    SELECT CAST(id AS BIGINT) AS scenic_id, title, status, CAST(apply_did AS BIGINT) AS supplier_id, p_type, jtype, topic,
           SPLIT(area, '\\\\|')                                     AS area_parts,     -- 省|市|区县
           address, lng_lat_pos, oversea, reception_ability, resourceid, addtime
    FROM ods.ods_prd_scenic_df
    WHERE {P}
),
resource_map AS (   -- 景区 → 业态景区：同一景区多次映射取最新
    SELECT land_id, mt_id
    FROM (
        SELECT CAST(land_id AS BIGINT) AS land_id, CAST(mt_id AS BIGINT) AS mt_id,
               ROW_NUMBER() OVER (PARTITION BY land_id ORDER BY CAST(id AS BIGINT) DESC) AS rn
        FROM ods.ods_prd_management_resource_df
        WHERE {P}
    ) t
    WHERE rn = 1
),
resource_land AS (SELECT CAST(id AS BIGINT) AS mt_id, title FROM ods.ods_prd_management_land_df WHERE {P} AND COALESCE(is_del, '0') = '0'),
region AS (SELECT region_code, region_name FROM dim.dim_opr_region_f),
area_belong AS (SELECT province, MAX(district) AS district FROM ods.ods_opr_resource_center_district_df WHERE {P} GROUP BY province),
dict AS (SELECT dict_type, dict_code, dict_name FROM dim.dim_opr_dict_f WHERE dict_type IN ('scenic_type', 'scenic_topic'))
INSERT OVERWRITE TABLE dim.dim_prd_scenic_df
SELECT /*+ BROADCAST(rl, rp, rc, rd, ab, dt, dp, mb) */
    l.scenic_id,
    l.title                                                          AS scenic_name,
    l.status                                                         AS scenic_status,
    l.supplier_id,
    l.p_type                                                         AS scenic_type_code,
    dt.dict_name                                                     AS scenic_type_name,
    l.jtype                                                          AS scenic_level,
    COALESCE(dp.dict_name, SPLIT(l.topic, ',')[0])                   AS scenic_topic,      -- 多主题取第一个
    l.topic                                                          AS scenic_topic_list,
    l.area_parts[0]                                                  AS province_code,
    rp.region_name                                                   AS province_name,
    l.area_parts[1]                                                  AS city_code,
    rc.region_name                                                   AS city_name,
    l.area_parts[2]                                                  AS district_code,
    rd.region_name                                                   AS district_name,
    ab.district                                                      AS belong_area,       -- 大区（华东 / 华南 …）
    l.address,
    CAST(SPLIT(l.lng_lat_pos, ',')[0] AS DECIMAL(10,6))              AS longitude,
    CAST(SPLIT(l.lng_lat_pos, ',')[1] AS DECIMAL(10,6))              AS latitude,
    CAST(l.oversea AS INT)                                           AS oversea_flag,
    CAST(l.reception_ability AS BIGINT)                              AS reception_capacity_qty,
    CAST(l.resourceid AS BIGINT)                                     AS resource_id,
    rm.mt_id                                                         AS resource_scenic_id,
    rl.title                                                         AS resource_scenic_name,   -- 旧逻辑 CAST(title AS INT) 恒为空，已修正
    l.addtime                                                        AS create_time,
    IF(l.title LIKE '%测试%' OR l.title LIKE '%压测%' OR mb.test_flag = 1, 1, 0) AS test_flag,
    {NOW}
FROM land l
LEFT JOIN resource_map rm ON rm.land_id = l.scenic_id
LEFT JOIN resource_land rl ON rl.mt_id = rm.mt_id
LEFT JOIN region rp ON rp.region_code = l.area_parts[0]
LEFT JOIN region rc ON rc.region_code = l.area_parts[1]
LEFT JOIN region rd ON rd.region_code = l.area_parts[2]
LEFT JOIN area_belong ab ON ab.province = rp.region_name
LEFT JOIN dict dt ON dt.dict_type = 'scenic_type' AND dt.dict_code = l.p_type
LEFT JOIN dict dp ON dp.dict_type = 'scenic_topic' AND dp.dict_code = SPLIT(l.topic, ',')[0]
LEFT JOIN (SELECT member_id, test_flag FROM dim.dim_sup_member_df) mb ON mb.member_id = l.supplier_id
"""


# ============================================================================ 票
@sql('dim_prd_ticket_df', why=['替代 dim_prod_d_f、dim_attr_ticket_info_df 等；套票角色原来在 6 个下游脚本里各自用 pft_package_tickets 判断'],
     perf=['套票关系先聚合成「票 → 角色」一行一票，再关联'])
def _():
    return f"""
WITH ticket AS (
    SELECT CAST(id AS BIGINT) AS ticket_id, title, CAST(pid AS BIGINT) AS product_id, CAST(landid AS BIGINT) AS scenic_id,
           CAST(apply_did AS BIGINT) AS supplier_id, CAST(gid AS BIGINT) AS goods_id, tprice, status, delaydays, max_expiration_date,
           order_start, order_end, buy_limit_low, buy_limit_up, refund_rule, refund_audit, update_time
    FROM ods.ods_prd_ticket_df
    WHERE {P}
),
package_role AS (   -- 1 = 套票主票（作为 parent_tid 出现），2 = 套票子票；同时出现按主票
    SELECT ticket_id, MIN(role) AS package_role
    FROM (
        SELECT CAST(parent_tid AS BIGINT) AS ticket_id, 1 AS role FROM ods.ods_prd_package_tickets_df WHERE {P}
        UNION ALL
        SELECT CAST(tid AS BIGINT), 2 FROM ods.ods_prd_package_tickets_df WHERE {P}
    ) t
    GROUP BY ticket_id
)
INSERT OVERWRITE TABLE dim.dim_prd_ticket_df
SELECT /*+ BROADCAST(pr) */
    t.ticket_id,
    t.title                                                          AS ticket_name,
    CONCAT_WS('-', s.scenic_name, t.title)                           AS ticket_full_name,
    t.product_id,
    t.scenic_id,
    t.supplier_id,
    t.goods_id,
    CAST(t.tprice AS DECIMAL(18,2)) / 100                            AS market_price_amt,     -- 分 → 元
    t.status                                                         AS ticket_status,        -- 1-上架 2-下架 6-删除
    COALESCE(pr.package_role, 0)                                     AS package_role,
    CAST(t.delaydays AS INT)                                         AS valid_day_qty,
    t.max_expiration_date,
    t.order_start                                                    AS order_start_time,
    t.order_end                                                      AS order_end_time,
    CAST(t.buy_limit_low AS INT)                                     AS buy_limit_low_qty,
    CAST(t.buy_limit_up AS INT)                                      AS buy_limit_up_qty,
    t.refund_rule,
    CAST(t.refund_audit AS INT)                                      AS refund_audit_flag,
    FROM_UNIXTIME(CAST(t.update_time AS BIGINT))                     AS update_time,
    IF(t.title LIKE '%测试%' OR s.test_flag = 1, 1, 0)               AS test_flag,
    {NOW}
FROM ticket t
LEFT JOIN (SELECT scenic_id, scenic_name, test_flag FROM dim.dim_prd_scenic_df) s ON s.scenic_id = t.scenic_id
LEFT JOIN package_role pr ON pr.ticket_id = t.ticket_id
"""


# ============================================================================ 产品
@sql('dim_prd_product_df', why=['旧系统没有产品维度，产品属性散在票维表；pid 与景区 1:1，名称 / 类型取景区'],
     perf=['直接由已标准化的票维度聚合，不再回读 ODS'])
def _():
    return f"""
WITH t AS (
    SELECT product_id, scenic_id, supplier_id, ticket_id, ticket_status, market_price_amt, update_time, package_role, test_flag
    FROM dim.dim_prd_ticket_df
    WHERE product_id IS NOT NULL
)
INSERT OVERWRITE TABLE dim.dim_prd_product_df
SELECT
    t.product_id,
    MAX(t.scenic_id)                                                 AS scenic_id,
    MAX(t.supplier_id)                                               AS supplier_id,
    MAX(s.scenic_type_code)                                          AS product_type_code,
    MAX(s.scenic_name)                                               AS product_name,
    COUNT(1)                                                         AS ticket_qty,
    SUM(IF(t.ticket_status = '1', 1, 0))                             AS onsale_ticket_qty,
    MIN(IF(t.ticket_status = '1', t.market_price_amt, NULL))         AS min_price_amt,   -- 只看在售票
    MAX(IF(t.ticket_status = '1', t.market_price_amt, NULL))         AS max_price_amt,
    MAX(IF(t.package_role = 1, 1, 0))                                AS package_flag,
    MAX(t.update_time)                                               AS last_update_time,
    MAX(GREATEST(t.test_flag, COALESCE(s.test_flag, 0)))             AS test_flag,
    {NOW}
FROM t
LEFT JOIN (SELECT scenic_id, scenic_name, scenic_type_code, test_flag FROM dim.dim_prd_scenic_df) s ON s.scenic_id = t.scenic_id
GROUP BY t.product_id
"""


# ============================================================================ 供应商（租户）
@sql('dim_sup_supplier_df', why=['替代 dim_user_d_f 中供应商部分与 dws_cus_company_prod_d_f 的产品统计；sid = 供应商ID（租户ID）'],
     perf=['景区数 / 在售票数 / 分销商数各自先按供应商聚合成一行，再与供应商关联（旧任务先关联后 COUNT DISTINCT）'])
def _():
    return f"""
WITH sup AS (
    SELECT member_id AS supplier_id, member_name, customer_id, register_time, test_flag
    FROM dim.dim_sup_member_df
    WHERE supplier_flag = 1 OR member_type_code = '0'
),
ext AS (
    SELECT CAST(fid AS BIGINT) AS supplier_id, com_name, short_company_name, corp_kind, format_type, types, province, city, contract_model
    FROM ods.ods_sup_member_ext_df WHERE {P}
),
member_raw AS (SELECT CAST(id AS BIGINT) AS supplier_id, CAST(salesid AS BIGINT) AS signer_id, CAST(kefuid AS BIGINT) AS servicer_id FROM ods.ods_sup_member_df WHERE {P}),
cert AS (   -- 同一客户多次提交认证，取最近一次
    SELECT customer_id, certi_status
    FROM (SELECT CAST(customer_id AS BIGINT) AS customer_id, certi_status, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY apply_time DESC) AS rn
          FROM ods.ods_sup_customer_certification_df WHERE {P}) t
    WHERE rn = 1
),
enable AS (SELECT CAST(fid AS BIGINT) AS supplier_id, MIN(enable_time) AS enable_time FROM ods.ods_sup_supplier_extinfo_df WHERE {P} GROUP BY CAST(fid AS BIGINT)),
scenic AS (SELECT supplier_id, COUNT(1) AS scenic_qty FROM dim.dim_prd_scenic_df GROUP BY supplier_id),
ticket AS (
    SELECT supplier_id, SUM(IF(ticket_status = '1', 1, 0)) AS onsale_ticket_qty, MIN(update_time) AS first_ticket_time
    FROM dim.dim_prd_ticket_df GROUP BY supplier_id
),
distributor AS (   -- 拉链表当前有效：end_date = '99991231'
    SELECT supplier_id, COUNT(DISTINCT distributor_id) AS distributor_qty
    FROM dim.dim_sup_member_relation_zip WHERE end_date = '99991231' GROUP BY supplier_id
)
INSERT OVERWRITE TABLE dim.dim_sup_supplier_df
SELECT
    s.supplier_id,
    s.member_name                                                    AS supplier_name,
    e.com_name                                                       AS company_name,
    e.short_company_name                                             AS company_short_name,
    s.customer_id,
    e.corp_kind                                                      AS company_type_code,
    e.format_type                                                    AS business_type,
    e.types                                                          AS supplier_level,
    e.province                                                       AS province_code,
    e.city                                                           AS city_code,
    c.certi_status                                                   AS certify_status,
    e.contract_model,
    en.enable_time                                                   AS enable_date,
    s.register_time,
    mr.signer_id,
    mr.servicer_id,
    COALESCE(sc.scenic_qty, 0)                                       AS scenic_qty,
    COALESCE(tk.onsale_ticket_qty, 0)                                AS onsale_ticket_qty,
    COALESCE(d.distributor_qty, 0)                                   AS distributor_qty,
    tk.first_ticket_time,
    s.test_flag,
    {NOW}
FROM sup s
LEFT JOIN ext e          ON e.supplier_id  = s.supplier_id
LEFT JOIN member_raw mr  ON mr.supplier_id = s.supplier_id
LEFT JOIN cert c         ON c.customer_id  = s.customer_id
LEFT JOIN enable en      ON en.supplier_id = s.supplier_id
LEFT JOIN scenic sc      ON sc.supplier_id = s.supplier_id
LEFT JOIN ticket tk      ON tk.supplier_id = s.supplier_id
LEFT JOIN distributor d  ON d.supplier_id  = s.supplier_id
"""


# ============================================================================ 订单明细
@sql('dwd_ord_order_di', why=[
    '替代 dwd_order_d_i、dwd_order_split_d_i、dim_order_d_i 等 17 张：旧系统同一张订单在 8 个任务里各算一遍',
    '旧同步按 ordertime 只取当日下单，下单后的支付 / 取消 / 验证变化漏采；改为按 update_time 采变更',
    '修正：测试订单两种判定（group_id=2 / 名称含“测试”）不一致，统一为 票 / 景区 / 供应商任一为测试',
    '保留旧规则：年卡特权支付（ordermode=18 AND paymode=13）单价置零，负单价置零；原始票数取 下单 + 加票'],
    perf=['只重算当日有变更的下单日分区（动态分区覆盖），不再全量重跑',
          '变更订单先按 update_time 取最新一条；附加表 / 价格表 / 分销表只读当日增量，没变的字段沿用 DWD 旧值',
          '票、景区、渠道、归属地等维表 BROADCAST；归属地按号段 / 证件前 6 位等值关联（ODS 脱敏时保留了前缀）',
          'Spark 不允许同表边读边覆盖：先落临时表再写回'])
def _():
    return f"""
-- 参数：spark.sql.sources.partitionOverwriteMode=dynamic（只覆盖本次写到的下单日分区）
DROP TABLE IF EXISTS tmp.dwd_ord_order_di_${{bizdate}};

CREATE TABLE tmp.dwd_ord_order_di_${{bizdate}} STORED AS ORC AS
WITH changed AS (   -- ① 今日变更的订单（ODS 按 update_time 增量），同一订单多次变更取最新
    SELECT *
    FROM (
        SELECT o.*, ROW_NUMBER() OVER (PARTITION BY ordernum ORDER BY update_time DESC, id DESC) AS rn
        FROM ods.ods_ord_order_di o
        WHERE {P}
    ) t
    WHERE rn = 1
),
touched AS (   -- ② 受影响的下单日分区（通常只有近几天 + 少量历史日）
    SELECT DISTINCT DATE_FORMAT(ordertime, 'yyyyMMdd') AS order_date FROM changed
),
prev AS (   -- ③ 变更订单在 DWD 的现有行：附加表当天没变时沿用旧值
    SELECT d.*
    FROM dwd.dwd_ord_order_di d
    LEFT SEMI JOIN changed c ON c.ordernum = d.order_no
    WHERE d.travel_date IN (SELECT order_date FROM touched)
),
addon AS (   -- 套票主子关系
    SELECT orderid, pack_order, ifpack
    FROM (SELECT orderid, pack_order, CAST(ifpack AS BIGINT) AS ifpack, ROW_NUMBER() OVER (PARTITION BY orderid ORDER BY update_time DESC) AS rn
          FROM ods.ods_ord_order_addon_di WHERE {P}) t
    WHERE rn = 1
),
apply AS (   -- 实际售价、原始 / 已验证 / 已退票数
    SELECT orderid, sale_price, aprice, origin_num, verified_num, refund_num
    FROM (SELECT orderid, sale_price, aprice, origin_num, verified_num, refund_num, ROW_NUMBER() OVER (PARTITION BY orderid ORDER BY update_time DESC) AS rn
          FROM ods.ods_ord_order_apply_di WHERE {P}) t
    WHERE rn = 1
),
dist AS (   -- 分销链：总级数、一级分销商（level IN (0,1) 为第一级）
    SELECT orderid,
           COUNT(1)                                         AS distribute_level_qty,
           MAX(IF(level IN (0, 1), buyerid, NULL))          AS distributor_id,
           MAX(IF(level IN (0, 1), cost_money, NULL))       AS first_cost_money
    FROM ods.ods_ord_order_distribution_split_di
    WHERE {P}
    GROUP BY orderid
),
track_qty AS (   -- 原始票数 = 下单 + 加票（旧 dim_order_d_i 规则）
    SELECT ordernum, SUM(tnum) AS booking_qty
    FROM ods.ods_ord_order_track_di
    WHERE {P} AND action IN (0, 16)
    GROUP BY ordernum
),
team AS (   -- 团队单子单 → 团单号（团单客源地优先）
    SELECT son_ordernum, main_ordernum
    FROM (SELECT son_ordernum, main_ordernum, ROW_NUMBER() OVER (PARTITION BY son_ordernum ORDER BY update_time DESC) AS rn
          FROM ods.ods_ord_team_order_link_df WHERE {P}) t
    WHERE rn = 1
),
team_area AS (SELECT ordernum, province_code, city_code, county_code FROM ods.ods_ord_team_order_df WHERE {P}),
taker AS (   -- 独立取票人表（有则优先）
    SELECT ordernum, ordertel, personid
    FROM (SELECT ordernum, ordertel, personid, ROW_NUMBER() OVER (PARTITION BY ordernum ORDER BY id DESC) AS rn
          FROM ods.ods_ord_order_ticket_taker_di WHERE {P}) t
    WHERE rn = 1
),
base AS (
    SELECT
        o.*,
        a.pack_order, a.ifpack,
        ap.sale_price, ap.aprice, ap.origin_num, ap.verified_num, ap.refund_num,
        ds.distribute_level_qty, ds.distributor_id, ds.first_cost_money,
        tq.booking_qty,
        tm.main_ordernum                             AS team_order_no,
        COALESCE(tk.ordertel, o.ordertel)            AS taker_tel,
        COALESCE(tk.personid, o.personid)            AS taker_idcard,
        ta.province_code AS team_province_code, ta.city_code AS team_city_code, ta.county_code AS team_district_code,
        -- 单价规则（旧 ods_order_update_d_i）：年卡特权支付置零；负数置零
        IF(o.ordermode = 18 AND o.paymode = 13, 0, GREATEST(o.tprice, 0)) AS unit_price_fen,
        p.order_role AS p_order_role, p.main_order_no AS p_main_order_no, p.sale_price_amt AS p_sale_price_amt, p.cost_price_amt AS p_cost_price_amt,
        p.origin_ticket_qty AS p_origin_ticket_qty, p.verified_ticket_qty AS p_verified_ticket_qty, p.refund_ticket_qty AS p_refund_ticket_qty,
        p.distributor_id AS p_distributor_id, p.distribute_level_qty AS p_distribute_level_qty
    FROM changed o
    LEFT JOIN prev p        ON p.order_no      = o.ordernum
    LEFT JOIN addon a       ON a.orderid       = o.ordernum
    LEFT JOIN apply ap      ON ap.orderid      = o.ordernum
    LEFT JOIN dist ds       ON ds.orderid      = o.ordernum
    LEFT JOIN track_qty tq  ON tq.ordernum     = o.ordernum
    LEFT JOIN team tm       ON tm.son_ordernum = o.ordernum
    LEFT JOIN team_area ta  ON ta.ordernum     = tm.main_ordernum
    LEFT JOIN taker tk      ON tk.ordernum     = o.ordernum
)
SELECT /*+ BROADCAST(t, s, mb, ms, ph, ic) */
    b.ordernum                                                       AS order_no,
    COALESCE(b.pack_order, b.p_main_order_no, b.ordernum)            AS main_order_no,
    CASE WHEN b.ifpack > 1 THEN 'SUB' WHEN b.ifpack IS NOT NULL THEN 'MAIN' ELSE COALESCE(b.p_order_role, 'MAIN') END AS order_role,  -- ifpack：1 主票，>1 子票
    b.team_order_no,
    IF(b.team_order_no IS NOT NULL, 1, 0)                            AS team_flag,
    b.trade_order_id                                                 AS trade_order_no,
    b.remotenum                                                      AS remote_order_no,
    b.lid                                                            AS scenic_id,
    b.tid                                                            AS ticket_id,
    b.pid                                                            AS product_id,
    s.scenic_type_code                                               AS product_type,
    b.aid                                                            AS supplier_id,
    b.apply_did                                                      AS origin_supplier_id,
    b.member                                                         AS buyer_id,
    mb.member_type_code                                              AS buyer_type,
    b.salerid                                                        AS seller_id,
    COALESCE(b.distributor_id, b.p_distributor_id)                   AS distributor_id,
    COALESCE(b.distribute_level_qty, b.p_distribute_level_qty)       AS distribute_level_qty,
    b.ordermode                                                      AS order_mode,
    IF(b.ordermode = 17, 'OTA', mb.distribute_system_code)           AS distribute_system_code,   -- 17 = 淘宝 / 飞猪
    CAST(NULL AS STRING)                                             AS purchase_system_code,     -- 待确认：采购平台订单表（旧 ods_third_purchase_order_d_f）未纳入同步
    b.paymode                                                        AS pay_mode,
    CAST(NULL AS STRING)                                             AS pay_account_type,         -- 待确认：资金账户类型不在订单表
    CAST(b.status AS STRING)                                         AS order_status,
    CAST(b.pay_status AS STRING)                                     AS pay_status,
    b.tnum                                                           AS ticket_qty,
    COALESCE(b.origin_num, b.p_origin_ticket_qty, GREATEST(COALESCE(b.booking_qty, 0), b.tnum)) AS origin_ticket_qty,
    COALESCE(b.verified_num, b.p_verified_ticket_qty, 0)             AS verified_ticket_qty,
    COALESCE(b.refund_num, b.p_refund_ticket_qty, 0)                 AS refund_ticket_qty,
    CAST(b.unit_price_fen AS DECIMAL(18,2)) / 100                    AS ticket_price_amt,
    COALESCE(CAST(IF(b.ordermode = 18 AND b.paymode = 13, 0, GREATEST(b.sale_price, 0)) AS DECIMAL(18,2)) / 100,
             b.p_sale_price_amt, CAST(b.unit_price_fen AS DECIMAL(18,2)) / 100) AS sale_price_amt,
    COALESCE(CAST(COALESCE(b.first_cost_money, b.aprice) AS DECIMAL(18,2)) / 100, b.p_cost_price_amt) AS cost_price_amt,
    CAST(b.totalmoney AS DECIMAL(18,2)) / 100                        AS order_amt,
    -- 已支付金额：未支付（2）或 取消（3）/ 撤销（6）/ 删除（9）为 0
    IF(b.pay_status = 2 OR b.status IN (3, 6, 9), 0, CAST(b.unit_price_fen * b.tnum AS DECIMAL(18,2)) / 100) AS pay_amt,
    IF(b.onsale = 1, 1, 0)                                           AS use_coupon_flag,
    IF(b.unioncheck = 1, 1, 0)                                       AS non_refundable_flag,
    b.ordertime                                                      AS order_time,
    IF(b.pay_time > 0, FROM_UNIXTIME(b.pay_time), NULL)              AS pay_time,
    SUBSTR(b.playtime, 1, 10)                                        AS play_date,
    DATEDIFF(TO_DATE(b.playtime), TO_DATE(b.ordertime))              AS advance_day_qty,
    b.begintime                                                      AS valid_start_time,
    b.endtime                                                        AS valid_end_time,
    NULLIF(b.dtime, '0000-00-00 00:00:00')                           AS first_verify_time,
    NULLIF(b.ctime, '0000-00-00 00:00:00')                           AS cancel_time,
    CAST(b.code AS STRING)                                           AS voucher_code,
    CONCAT(SUBSTR(b.ordername, 1, 1), '**')                          AS taker_name_mask,
    {HASH.format(c='b.taker_tel')}                          AS taker_phone_hash,
    {HASH.format(c='b.taker_idcard')}                       AS taker_id_card_hash,
    -- 证件号第 17 位（ODS 前缀第 11 位）奇男偶女；年龄 = 下单年 − 出生年
    IF(LENGTH({PREFIX.format(c='b.taker_idcard')}) = 11, IF(CAST(SUBSTR(b.taker_idcard, 11, 1) AS INT) % 2 = 1, 'M', 'F'), 'U') AS taker_gender,
    IF(LENGTH({PREFIX.format(c='b.taker_idcard')}) = 11, YEAR(TO_DATE(b.ordertime)) - CAST(SUBSTR(b.taker_idcard, 7, 4) AS INT), NULL) AS taker_age,
    -- 客源地：团单 > 手机号段 > 证件地区（旧 ticket_taker_province 规则）
    COALESCE(b.team_province_code, ph.province_code, ic.province_code) AS taker_province_code,
    COALESCE(b.team_city_code, ph.city_code, ic.city_code)           AS taker_city_code,
    COALESCE(b.team_district_code, ic.area_code)                     AS taker_district_code,
    b.certnum                                                        AS resource_id,
    CAST(NULL AS BIGINT)                                             AS resource_center_supplier_id,   -- 资源中心订单见 dwd_prd_resource_order_di
    CAST(NULL AS BIGINT)                                             AS resource_center_purchase_id,
    CAST(NULL AS BIGINT)                                             AS mall_supplier_id,
    IF(t.test_flag = 1 OR s.test_flag = 1 OR ms.test_flag = 1, 1, 0) AS test_flag,
    {NOW},
    DATE_FORMAT(b.ordertime, 'yyyyMMdd')                             AS travel_date      -- 分区 = 下单日
FROM base b
LEFT JOIN (SELECT ticket_id, test_flag FROM dim.dim_prd_ticket_df) t ON t.ticket_id = b.tid
LEFT JOIN (SELECT scenic_id, scenic_type_code, test_flag FROM dim.dim_prd_scenic_df) s ON s.scenic_id = b.lid
LEFT JOIN (SELECT member_id, member_type_code, distribute_system_code FROM dim.dim_sup_member_df) mb ON mb.member_id = b.member
LEFT JOIN (SELECT member_id, test_flag FROM dim.dim_sup_member_df) ms ON ms.member_id = b.aid
LEFT JOIN (SELECT phone_prefix, province_code, city_code FROM dim.dim_opr_phone_area_f) ph ON ph.phone_prefix = {PREFIX.format(c='b.taker_tel')}
LEFT JOIN (SELECT area_code, province_code, city_code FROM dim.dim_opr_idcard_area_f) ic ON ic.area_code = SUBSTR(b.taker_idcard, 1, 6)
UNION ALL
-- ④ 受影响分区里今天没变的订单：原样写回（动态分区覆盖会整分区替换）
SELECT d.*
FROM dwd.dwd_ord_order_di d
LEFT ANTI JOIN changed c ON c.ordernum = d.order_no
WHERE d.travel_date IN (SELECT DISTINCT DATE_FORMAT(ordertime, 'yyyyMMdd') FROM changed);

INSERT OVERWRITE TABLE dwd.dwd_ord_order_di PARTITION (travel_date)
SELECT * FROM tmp.dwd_ord_order_di_${{bizdate}};

DROP TABLE IF EXISTS tmp.dwd_ord_order_di_${{bizdate}};
"""


# ============================================================================ 订单操作明细
TRACK_CODE = """CASE t.action
        WHEN 0 THEN 'BOOK' WHEN 1 THEN 'MODIFY' WHEN 2 THEN 'CANCEL' WHEN 3 THEN 'PRINT' WHEN 4 THEN 'PAY' WHEN 5 THEN 'VERIFY'
        WHEN 6 THEN 'REVOKE' WHEN 7 THEN 'REVOKE_MODIFY' WHEN 8 THEN 'REPRINT' WHEN 12 THEN 'EXPIRE' WHEN 16 THEN 'ADD_TICKET'
        WHEN 17 THEN 'FINISH' WHEN 33 THEN 'VERIFY' WHEN 38 THEN 'AFTER_SALE' ELSE 'OTHER' END"""

ORDER_JOIN = """-- 关联订单取单价与退化维度：ON 带上下单日分区（ODS 轨迹自带逻辑下单时间），Spark 动态分区裁剪只扫涉及的下单日
LEFT JOIN (
    SELECT order_no, travel_date, sale_price_amt, cost_price_amt, order_role, supplier_id, distributor_id, order_mode, pay_mode,
           team_flag, taker_province_code, taker_city_code, taker_district_code, scenic_id, main_order_no, test_flag
    FROM dwd.dwd_ord_order_di
) o ON o.travel_date = t.order_date AND o.order_no = t.ordernum"""


@sql('dwd_ord_order_track_di', why=['替代 dwd_order_track_d_i、ods_track_tnum_d_i 等：取消 / 撤销 / 完结 / 取票 / 售后票数原来在 5 个脚本各自按 action 拆列',
                                    '操作码统一转标准编码（码表 track_action），下游不再写数字码'],
     perf=['轨迹按操作日增量，一天一分区，只追加不回改', '关联订单带下单日分区条件，触发动态分区裁剪（旧任务全表关联订单宽表）',
           '订单退化维度在这里一次带齐，DWS 直接聚合'])
def _():
    return f"""
WITH t AS (
    SELECT id, ordernum, action, tid, tnum, left_num, terminal, oper_member, ext_content, inserttime,
           FROM_UNIXTIME(order_time, 'yyyyMMdd') AS order_date
    FROM ods.ods_ord_order_track_di
    WHERE {P}
      AND tnum > 0          -- 旧规则：变更票数为 0 的轨迹不出指标
)
INSERT OVERWRITE TABLE dwd.dwd_ord_order_track_di PARTITION (travel_date = '${{bizdate}}')
SELECT
    t.id                                                             AS track_id,
    t.ordernum                                                       AS order_no,
    {TRACK_CODE}                                                     AS track_action,
    t.inserttime                                                     AS action_time,
    t.tnum                                                           AS ticket_qty,
    t.left_num                                                       AS left_ticket_qty,
    CAST(t.tnum * o.sale_price_amt AS DECIMAL(18,2))                 AS sale_amt,
    CAST(t.tnum * o.cost_price_amt AS DECIMAL(18,2))                 AS cost_amt,
    -- 待确认：旧系统售后金额取业务库报表 report_checked 预计算，明细里只有 ext_content；JSON 键名上线前与业务库核对
    IF(t.action = 38, CAST(GET_JSON_OBJECT(t.ext_content, '$.refund_money') AS DECIMAL(18,2)) / 100, 0) AS refund_amt,
    IF(t.action = 38, CAST(GET_JSON_OBJECT(t.ext_content, '$.service_money') AS DECIMAL(18,2)) / 100, 0) AS service_fee_amt,
    t.oper_member                                                    AS operator_id,
    CAST(t.terminal AS STRING)                                       AS terminal_no,
    o.scenic_id,
    t.tid                                                            AS ticket_id,
    o.order_role,
    o.supplier_id,
    o.distributor_id,
    o.order_mode,
    o.pay_mode,
    o.team_flag,
    o.taker_province_code,
    o.taker_city_code,
    o.taker_district_code,
    COALESCE(o.test_flag, 0)                                         AS test_flag,
    {NOW}
FROM t
{ORDER_JOIN}
"""


# ============================================================================ 核销明细
@sql('dwd_ord_verify_di', why=['替代 dwd_order_verify_d_i、dwd_tourist_verify_d_i 等 7 张',
                               '验证票数规则沿用旧 ods_track_tnum_d_i：action=5 时有 need_write_num 取之，否则非 53/54/32/85 来源取 tnum；action=33 且来源 32/85 取 tnum',
                               '修正：旧 dwd_order_verify_d_i 读的是 pt=\'pt\'（字面量），实际取不到分区'],
     perf=['只读当日轨迹中的验证动作', '游客核销人数先按订单聚合再关联'])
def _():
    return f"""
WITH t AS (
    SELECT id, ordernum, action, source, tid, terminal, branchterminal, oper_member, inserttime,
           FROM_UNIXTIME(order_time, 'yyyyMMdd') AS order_date,
           CASE WHEN action = 5 AND CAST(GET_JSON_OBJECT(ext_content, '$.need_write_num') AS INT) > 0
                     THEN CAST(GET_JSON_OBJECT(ext_content, '$.need_write_num') AS INT)
                WHEN (action = 5 AND source NOT IN (53, 54, 32, 85)) OR (action = 33 AND source IN (32, 85)) THEN tnum
                ELSE 0 END AS verify_qty,
           GET_JSON_OBJECT(ext_content, '$.card_no') AS card_no
    FROM ods.ods_ord_order_track_di
    WHERE {P} AND action IN (5, 33) AND tnum > 0
),
traveler AS (   -- 当日核销的游客人数（游客轨迹 track_action=1 为入园核销）
    SELECT ordernum, COUNT(DISTINCT idx) AS traveler_qty
    FROM ods.ods_ord_order_traveler_track_di
    WHERE {P} AND track_action = 1
    GROUP BY ordernum
)
INSERT OVERWRITE TABLE dwd.dwd_ord_verify_di PARTITION (travel_date = '${{bizdate}}')
SELECT /*+ BROADCAST(tv) */
    t.id                                                             AS verify_id,
    t.ordernum                                                       AS order_no,
    o.main_order_no,
    o.order_role,
    o.scenic_id,
    t.tid                                                            AS ticket_id,
    o.supplier_id,
    o.distributor_id,
    o.order_mode,
    t.inserttime                                                     AS verify_time,
    t.verify_qty                                                     AS verify_ticket_qty,
    CAST(t.verify_qty * o.sale_price_amt AS DECIMAL(18,2))           AS verify_sale_amt,
    CAST(t.verify_qty * o.cost_price_amt AS DECIMAL(18,2))           AS verify_cost_amt,
    CASE WHEN t.card_no IS NOT NULL THEN 'ANNUAL_CARD'
         WHEN t.action = 33 THEN 'OTA_CALLBACK'                      -- 外部平台回传验证
         ELSE CAST(t.source AS STRING) END                           AS verify_type,
    CAST(t.terminal AS STRING)                                       AS terminal_no,
    CAST(t.branchterminal AS STRING)                                 AS branch_terminal_no,
    t.oper_member                                                    AS operator_id,
    IF(t.card_no IS NOT NULL, 1, 0)                                  AS annual_card_flag,
    COALESCE(tv.traveler_qty, 0)                                     AS traveler_qty,
    o.pay_mode,
    o.team_flag,
    o.taker_province_code,
    o.taker_city_code,
    o.taker_district_code,
    COALESCE(o.test_flag, 0)                                         AS test_flag,
    {NOW}
FROM t
{ORDER_JOIN}
LEFT JOIN traveler tv ON tv.ordernum = t.ordernum
WHERE t.verify_qty > 0
"""


# ============================================================================ 订单游客明细
@sql('dwd_ord_traveler_di', why=['替代 28 个透视列的游客画像中间表：画像维度（性别 / 年龄段 / 客源地）在明细上算一次'],
     perf=['归属地按证件前 6 位 / 号段等值 BROADCAST 关联', '同一游客记录多次变更取最新', '关联订单带下单日分区条件（动态分区裁剪）'])
def _():
    return f"""
WITH tr AS (
    SELECT orderid, idx, lid, tourist, idcard, voucher_type, mobile, check_time,
           FROM_UNIXTIME(CAST(order_time AS BIGINT), 'yyyyMMdd') AS order_date,
           -- ODS 证件号前缀 11 位 = 地区 6 + 出生年 4 + 性别位 1（仅 18 位身份证）
           IF(LENGTH({PREFIX.format(c='idcard')}) = 11, YEAR(CURRENT_DATE()) - CAST(SUBSTR(idcard, 7, 4) AS INT), NULL) AS age,
           IF(LENGTH({PREFIX.format(c='idcard')}) = 11, IF(CAST(SUBSTR(idcard, 11, 1) AS INT) % 2 = 1, 'M', 'F'), 'U') AS gender
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY orderid, idx ORDER BY update_time DESC) AS rn
          FROM ods.ods_ord_order_traveler_di WHERE {P}) t
    WHERE rn = 1
),
fellow AS (SELECT orderid, COUNT(1) AS fellow_qty FROM tr GROUP BY orderid)   -- 同行人数 = 同订单游客数
INSERT OVERWRITE TABLE dwd.dwd_ord_traveler_di PARTITION (travel_date = '${{bizdate}}')
SELECT /*+ BROADCAST(ic, ph) */
    tr.orderid                                                       AS order_no,
    CAST(tr.idx AS INT)                                              AS traveler_seq,
    CAST(tr.lid AS BIGINT)                                           AS scenic_id,
    o.ticket_id,
    o.order_role,
    COALESCE(o.team_flag, 0)                                         AS team_flag,
    CONCAT(SUBSTR(tr.tourist, 1, 1), '**')                           AS traveler_name_mask,
    {HASH.format(c='tr.idcard')}                                   AS id_card_hash,
    tr.voucher_type                                                  AS id_card_type,
    {HASH.format(c='tr.mobile')}                                   AS phone_hash,
    tr.gender,
    tr.age,
    CASE WHEN tr.age IS NULL THEN '未知' WHEN tr.age <= 7 THEN '0-7' WHEN tr.age <= 17 THEN '8-17' WHEN tr.age <= 27 THEN '18-27'
         WHEN tr.age <= 40 THEN '28-40' WHEN tr.age <= 60 THEN '41-60' ELSE '61+' END AS age_group,
    COALESCE(ic.province_code, ph.province_code)                     AS province_code,   -- 证件地区优先，手机号段次之
    COALESCE(ic.city_code, ph.city_code)                             AS city_code,
    ic.area_code                                                     AS district_code,
    IF(ic.area_code IS NOT NULL OR ph.province_code IS NOT NULL, 'CN', NULL) AS country_code,
    f.fellow_qty,
    o.order_time,
    NULLIF(tr.check_time, '0')                                       AS verify_time,
    COALESCE(o.test_flag, 0)                                         AS test_flag,
    {NOW}
FROM tr
LEFT JOIN fellow f ON f.orderid = tr.orderid
LEFT JOIN (SELECT order_no, travel_date, ticket_id, order_role, team_flag, order_time, test_flag FROM dwd.dwd_ord_order_di) o
       ON o.travel_date = tr.order_date AND o.order_no = tr.orderid
LEFT JOIN (SELECT area_code, province_code, city_code FROM dim.dim_opr_idcard_area_f) ic ON ic.area_code = SUBSTR(tr.idcard, 1, 6)
LEFT JOIN (SELECT phone_prefix, province_code, city_code FROM dim.dim_opr_phone_area_f) ph ON ph.phone_prefix = {PREFIX.format(c='tr.mobile')}
"""


# ============================================================================ 分销链明细
@sql('dwd_ord_order_distribution_di', why=['替代 dwd_split_d_i、dwd_order_split_d_i 等 7 张拆单表',
                                           '旧「本层具体分销层级」用 4 层嵌套 IF 推算，改为按链上顺序 ROW_NUMBER'],
     perf=['一次窗口排序得到层级，去掉旧任务对同一张拆单表的 4 次自关联', '关联订单带下单日分区条件（动态分区裁剪）'])
def _():
    return f"""
WITH s AS (
    SELECT orderid, buyerid, sellerid, level, pmode, cost_money, sale_money, id, FROM_UNIXTIME(order_time, 'yyyyMMdd') AS order_date
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY orderid, sellerid, buyerid ORDER BY update_time DESC) AS rn
          FROM ods.ods_ord_order_distribution_split_di WHERE {P}) t
    WHERE rn = 1
),
ranked AS (   -- level：1 / 0 为第一级，2 中间，-1 末级 → 排序键 1 < 2 < -1
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY orderid ORDER BY CASE WHEN level IN (0, 1) THEN 0 WHEN level = -1 THEN 2 ELSE 1 END, id) AS distribute_level
    FROM s
)
INSERT OVERWRITE TABLE dwd.dwd_ord_order_distribution_di PARTITION (travel_date = '${{bizdate}}')
SELECT
    r.orderid                                                        AS order_no,
    r.distribute_level,
    r.sellerid                                                       AS seller_id,
    r.buyerid                                                        AS buyer_id,
    CAST(r.sale_money AS DECIMAL(18,2)) / 100                        AS price_amt,
    CAST(r.cost_money AS DECIMAL(18,2)) / 100                        AS cost_price_amt,
    o.ticket_qty,
    CAST(r.sale_money * o.ticket_qty AS DECIMAL(18,2)) / 100         AS settle_amt,
    CAST(r.pmode AS INT)                                             AS pay_mode,
    o.scenic_id,
    o.ticket_id,
    o.order_time,
    COALESCE(o.test_flag, 0)                                         AS test_flag,
    {NOW}
FROM ranked r
LEFT JOIN (SELECT order_no, travel_date, scenic_id, ticket_id, ticket_qty, order_time, test_flag FROM dwd.dwd_ord_order_di) o
       ON o.travel_date = r.order_date AND o.order_no = r.orderid      -- 带下单日分区：动态分区裁剪
"""


# ============================================================================ 游客维度
@sql('dim_cus_tourist_df', why=['旧系统没有游客维度，复购 / 首游等在各 ADS 里临时 COUNT DISTINCT personid'],
     perf=['增量累计：当前维表 + 今日新增明细合并，不再每天扫全部历史订单', 'Spark 不允许同表边读边覆盖：先落临时表再写回'])
def _():
    age = "YEAR(CURRENT_DATE()) - birth_year"
    return f"""
DROP TABLE IF EXISTS tmp.dim_cus_tourist_df_${{bizdate}};

CREATE TABLE tmp.dim_cus_tourist_df_${{bizdate}} STORED AS ORC AS
WITH today AS (   -- 今日新增的游客明细（排除测试订单）
    SELECT id_card_hash AS tourist_key, id_card_type, gender, YEAR(CURRENT_DATE()) - age AS birth_year, province_code, city_code, phone_hash,
           SUBSTR(order_time, 1, 10) AS order_date, SUBSTR(verify_time, 1, 10) AS visit_date, order_no, scenic_id
    FROM dwd.dwd_ord_traveler_di
    WHERE {P} AND id_card_hash IS NOT NULL AND test_flag = 0
),
n AS (
    SELECT tourist_key, MAX(id_card_type) AS id_card_type, MAX(gender) AS gender, MAX(birth_year) AS birth_year,
           MAX(province_code) AS source_province_code, MAX(city_code) AS source_city_code, MAX(phone_hash) AS phone_hash,
           MIN(order_date) AS first_order_date, MAX(order_date) AS last_order_date,
           MIN(visit_date) AS first_visit_date, MAX(visit_date) AS last_visit_date,
           COUNT(DISTINCT order_no) AS order_qty, COUNT(visit_date) AS visit_qty,
           COUNT(DISTINCT IF(visit_date IS NOT NULL, scenic_id, NULL)) AS visit_scenic_qty
    FROM today
    GROUP BY tourist_key
),
auth AS (   -- 实名认证：tourist_info 证件号在 ODS 已哈希，取哈希段关联
    SELECT {HASH.format(c='i.certificate_no')} AS tourist_key, MAX(IF(a.status = '1', 1, 0)) AS real_name_flag
    FROM ods.ods_cus_tourist_info_df i
    JOIN ods.ods_cus_tourist_auth_info_df a ON a.tourist_id = i.id AND a.travel_date = '${{bizdate}}'
    WHERE i.travel_date = '${{bizdate}}'
    GROUP BY {HASH.format(c='i.certificate_no')}
),
m AS (
    SELECT
        COALESCE(n.tourist_key, h.tourist_key)                         AS tourist_key,
        COALESCE(n.id_card_type, h.id_card_type)                       AS id_card_type,
        COALESCE(h.gender, n.gender)                                   AS gender,
        COALESCE(h.birth_year, n.birth_year)                           AS birth_year,
        COALESCE(h.source_province_code, n.source_province_code)       AS source_province_code,
        COALESCE(h.source_city_code, n.source_city_code)               AS source_city_code,
        h.phone_province_code,                                         -- 待确认：维表只存手机号哈希，号段归属需在 DWD 单独带出后再累计
        COALESCE(n.phone_hash, h.phone_hash)                           AS phone_hash,           -- 取最近一次
        GREATEST(COALESCE(h.real_name_flag, 0), COALESCE(au.real_name_flag, 0)) AS real_name_flag,
        CASE WHEN h.first_order_date IS NULL OR n.first_order_date < h.first_order_date THEN n.first_order_date ELSE h.first_order_date END AS first_order_date,
        CASE WHEN h.last_order_date IS NULL OR n.last_order_date > h.last_order_date THEN n.last_order_date ELSE h.last_order_date END AS last_order_date,
        CASE WHEN h.first_visit_date IS NULL OR n.first_visit_date < h.first_visit_date THEN n.first_visit_date ELSE h.first_visit_date END AS first_visit_date,
        CASE WHEN h.last_visit_date IS NULL OR n.last_visit_date > h.last_visit_date THEN n.last_visit_date ELSE h.last_visit_date END AS last_visit_date,
        COALESCE(h.order_qty, 0) + COALESCE(n.order_qty, 0)            AS order_qty,
        COALESCE(h.visit_qty, 0) + COALESCE(n.visit_qty, 0)            AS visit_qty,
        -- 近似：跨日同一景区会重复计；精确去重需按 游客 × 景区 累计表
        COALESCE(h.visit_scenic_qty, 0) + COALESCE(n.visit_scenic_qty, 0) AS visit_scenic_qty
    FROM n
    FULL OUTER JOIN dim.dim_cus_tourist_df h ON h.tourist_key = n.tourist_key      -- 当前维表（昨日结果）
    LEFT JOIN auth au ON au.tourist_key = COALESCE(n.tourist_key, h.tourist_key)
)
SELECT
    tourist_key, id_card_type, gender, birth_year,
    CASE WHEN birth_year IS NULL THEN '未知' WHEN {age} <= 7 THEN '0-7' WHEN {age} <= 17 THEN '8-17' WHEN {age} <= 27 THEN '18-27'
         WHEN {age} <= 40 THEN '28-40' WHEN {age} <= 60 THEN '41-60' ELSE '61+' END AS age_group,
    source_province_code, source_city_code, phone_province_code, phone_hash, real_name_flag,
    first_order_date, last_order_date, first_visit_date, last_visit_date, order_qty, visit_qty, visit_scenic_qty,
    {NOW}
FROM m;

INSERT OVERWRITE TABLE dim.dim_cus_tourist_df
SELECT * FROM tmp.dim_cus_tourist_df_${{bizdate}};

DROP TABLE IF EXISTS tmp.dim_cus_tourist_df_${{bizdate}};
"""


# ============================================================================ 统一用户
@sql('dim_cus_user_df', why=['旧系统游客、会员、CRM 客户三套 ID 各自统计，没有统一用户视图'],
     perf=['三类用户 UNION ALL，无关联'])
def _():
    return f"""
INSERT OVERWRITE TABLE dim.dim_cus_user_df
SELECT user_key, user_type, source_id, user_name_mask, member_id, customer_id, province_code, first_active_date, last_active_date, status, test_flag, {NOW}
FROM (
    -- 游客：证件号哈希
    SELECT CONCAT('T:', tourist_key) AS user_key, 'TOURIST' AS user_type, tourist_key AS source_id, CAST(NULL AS STRING) AS user_name_mask,
           CAST(NULL AS BIGINT) AS member_id, CAST(NULL AS BIGINT) AS customer_id, source_province_code AS province_code,
           first_order_date AS first_active_date, GREATEST(COALESCE(last_order_date, ''), COALESCE(last_visit_date, '')) AS last_active_date,
           'ACTIVE' AS status, 0 AS test_flag
    FROM dim.dim_cus_tourist_df
    UNION ALL
    -- 会员：平台账号
    SELECT CONCAT('M:', member_id), 'MEMBER', CAST(member_id AS STRING), CONCAT(SUBSTR(member_name, 1, 1), '**'),
           member_id, customer_id, CAST(NULL AS STRING), SUBSTR(register_time, 1, 10), SUBSTR(last_login_time, 1, 10), member_status, test_flag
    FROM dim.dim_sup_member_df
    UNION ALL
    -- CRM 客户
    SELECT CONCAT('C:', company_id), 'CUSTOMER', CAST(company_id AS STRING), CONCAT(SUBSTR(company_name, 1, 1), '**'),
           user_id, user_customer_id, customer_province, SUBSTR(user_regist_time, 1, 10), SUBSTR(user_login_lasttime, 1, 10), user_status,
           IF(user_is_test = '测试', 1, 0)
    FROM dim.dim_sup_company_df
) u
"""
