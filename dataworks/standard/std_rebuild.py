"""旧数仓标准化：之前「过渡期读旧表」或字段留空（待确认 / 冗余）的 DIM / DWD，全部改为从 ODS 显式加工。

原则：
- 每个字段给出来源表达式；名称 / 地区等冗余属性按键关联维表补齐（不再留空）；
- 旧表里只是技术残留的列（与分区重复的 stat_date、去重序号 rn、与主键重复的 *_id_mask）不再保留，原因写进表说明；
- 个人敏感明文（姓名 / 手机 / 证件 / 审核材料）不进 DWD；
- 用 proc_model.proc 登记，同名表原位替换（保留原来归并的旧表），ETL 走 proc_model.core() 显式映射。
"""
import json
import pathlib

import proc_model as pm

proc = pm.proc
ts, day, yuan, B, I, S, DEC, NUL = pm.ts, pm.day, pm.yuan, pm.B, pm.I, pm.S, pm.DEC, pm.NUL
BIZ = "'${bizdate}'"
P = "travel_date = '${bizdate}'"
BIZ_TS = "UNIX_TIMESTAMP('${bizdate}', 'yyyyMMdd')"


def q(sql):
    """子查询包装：from 覆盖要求返回 ( … ) t"""
    return "(\n" + '\n'.join('        ' + l for l in sql.strip('\n').split('\n')) + "\n    ) t"


# ============================================================================ DIM
proc('dim_sup_staff_df', '员工维度', '1行=1个平台员工（签单 / 客服 / 区域人员）', 'ods_sup_staff_df、ods_opr_staff_group_df',
     '平台员工（签单人员、客服、区域负责人）与员工组；OA 部门 / 团队属性随 OA 链路下线（客户确认），不再提供',
     ['ods_sup_staff_df'], [
         ('staff_id', B, '主键', '员工ID', 'id'),
         ('staff_member_id', B, '外键', '员工在平台的账号ID（关联 dim_sup_member_df）', 'st_memberid'),
         ('staff_name', S, '维度属性', '员工姓名', 'st_name'),
         ('staff_type', I, '状态类型', '人员类型：0-签单人员 1-客服 2-区域负责人', 'st_type'),
         ('staff_status', I, '状态类型', '状态：0-正常 1-离职 2-已删除', 'st_status'),
         ('staff_group_id', B, '外键', '员工组ID', 'st_group'),
         ('staff_group_name', S, '维度属性', '员工组名称', 'staff_group_name'),
     ], part='',
     frm={'ods_sup_staff_df': q("""
SELECT s.*, g.staff_group_name
FROM ods.ods_sup_staff_df s
LEFT JOIN (SELECT staff_group_id, MAX(staff_group_name) AS staff_group_name FROM ods.ods_opr_staff_group_df
           WHERE travel_date = '${bizdate}' GROUP BY staff_group_id) g ON g.staff_group_id = s.st_group   -- 员工组码表，先去重
WHERE s.travel_date = '${bizdate}'""")},
     notes=['旧 dim_plat_staff_d_f 的 OA 部门 / 一二级团队来自 OA 人员表，OA 链路客户确认下线，这些列不再提供；平台侧部门以员工组代替',
            '旧表 stat_date（统计日期）与分区重复，不再保留'])

_PRICE = """SELECT type, target_id, fee, mode, ROW_NUMBER() OVER (PARTITION BY type, target_id ORDER BY rank DESC, begin_time DESC) AS rk
FROM ods.ods_opr_module_price_df
WHERE travel_date = '${bizdate}' AND begin_time <= %s AND (end_time = 0 OR end_time >= %s)""" % (BIZ_TS, BIZ_TS)
proc('dim_opr_module_package_df', '应用模块与套餐维度', '1行=1个套餐×1个包含模块（单独售卖的模块 package_id = 0）',
     'ods_opr_module_df、ods_opr_module_package_df、ods_opr_module_package_detail_df、ods_opr_module_package_classify_df、ods_opr_module_price_df',
     '平台售卖给商户的应用模块、套餐、套餐分类与当前资费；模块开通明细按 module_id / package_id 关联取名称、价格',
     ['ods_opr_module_df'], [
         ('package_id', B, '主键', '套餐ID（0 = 不属于套餐、单独售卖的模块）', 'package_id'),
         ('module_id', B, '主键', '模块ID', 'module_id'),
         ('module_name', S, '维度属性', '模块名称', 'module_name'),
         ('module_category', I, '状态类型', '模块分类：1-直销 2-营销 3-…', 'category'),
         ('module_status', I, '状态类型', '模块状态：0-下架 1-上架', 'module_status'),
         ('module_free_day_qty', I, '维度属性', '模块免费天数（0 = 不免费）', 'free_day'),
         ('module_online_time', S, '时间', '模块上线时间', "IF(online_time > 0, FROM_UNIXTIME(online_time), NULL)"),
         ('module_price_amt', DEC, '维度属性', '模块当前资费（元，按当日生效的资费配置）', yuan('module_fee')),
         ('package_name', S, '维度属性', '套餐名称', 'package_name'),
         ('package_role', I, '状态类型', '套餐适用角色：0-供应商 1-分销商', 'role'),
         ('package_fee_amt', DEC, '维度属性', '套餐标价（元）', yuan('package_list_fee')),
         ('package_month_qty', I, '维度属性', '套餐时长（月）', 'unit'),
         ('package_status', I, '状态类型', '套餐状态：1-有效 2-无效', 'package_status'),
         ('package_price_amt', DEC, '维度属性', '套餐当前资费（元，按当日生效的资费配置）', yuan('package_fee')),
         ('package_classify_name', S, '维度属性', '套餐分类名称', 'classify_name'),
         ('operator_id', B, '外键', '套餐分类最后操作人', 'classify_op_id'),
         ('operate_time', S, '时间', '套餐分类最后更新时间', "IF(classify_update_time > 0, FROM_UNIXTIME(classify_update_time), NULL)"),
     ], part='',
     frm={'ods_opr_module_df': q(f"""
SELECT x.package_id, x.module_id, m.name AS module_name, m.category, m.status AS module_status, m.free_day, m.online_time,
       pm.fee AS module_fee, p.name AS package_name, p.role, p.fee AS package_list_fee, p.unit, p.status AS package_status,
       pp.fee AS package_fee, c.classify_name, c.op_id AS classify_op_id, c.update_time AS classify_update_time
FROM (SELECT package_id, module_id FROM ods.ods_opr_module_package_detail_df WHERE travel_date = '${{bizdate}}'
      UNION ALL
      SELECT 0 AS package_id, id AS module_id FROM ods.ods_opr_module_df WHERE travel_date = '${{bizdate}}') x   -- 套餐内模块 + 单独售卖的模块
JOIN ods.ods_opr_module_df m ON m.id = x.module_id AND m.travel_date = '${{bizdate}}'
LEFT JOIN ods.ods_opr_module_package_df p ON p.id = x.package_id AND p.travel_date = '${{bizdate}}'
LEFT JOIN ({_PRICE}) pm ON pm.type = 1 AND pm.target_id = x.module_id AND pm.rk = 1     -- 模块当日生效资费
LEFT JOIN ({_PRICE}) pp ON pp.type = 2 AND pp.target_id = x.package_id AND pp.rk = 1    -- 套餐当日生效资费
LEFT JOIN (SELECT CAST(pid AS BIGINT) AS package_id, MAX(classify_name) AS classify_name, MAX(op_id) AS op_id, MAX(update_time) AS update_time
           FROM ods.ods_opr_module_package_classify_df LATERAL VIEW EXPLODE(SPLIT(package_ids, ',')) e AS pid
           WHERE travel_date = '${{bizdate}}' AND is_delete = 0 GROUP BY CAST(pid AS BIGINT)) c ON c.package_id = x.package_id   -- 分类里的套餐列表拆行""")},
     notes=['资费按 资费配置（module_price）当日生效版本取：开始时间 ≤ 统计日、结束时间为 0 或 ≥ 统计日，同一目标取排序值最高的一条',
            '套餐分类表 package_ids 为逗号分隔的套餐列表，拆行后按套餐关联'])

proc('dim_prd_resource_df', '资源中心资源维度', '1行=1个资源中心上架产品（供应商 × 门票）',
     'ods_prd_resource_product_df、ods_prd_resource_land_df、ods_prd_resource_land_attr_df、ods_prd_resource_purchase_df、ods_opr_province_df、ods_opr_resource_center_district_df',
     '资源中心上架的产品：供应商、门票、景区（名称 / 等级 / 类型 / 省市 / 考核区域）、差价、上架状态、采购情况；替代旧 dim_resource_center_purchase_d_f',
     ['ods_prd_resource_product_df'], [
         ('resource_id', B, '主键', '资源ID（资源中心上架记录）', 'id'),
         ('supplier_id', B, '外键', '上架供应商ID，关联 dim_sup_member_df', 'sid'),
         ('product_id', B, '外键', '产品ID', 'pid'), ('ticket_id', B, '外键', '票ID，关联 dim_prd_ticket_df', 'ticket_id'),
         ('ticket_name', S, '维度属性', '门票名称', 'ticket_name'),
         ('scenic_id', B, '外键', '景区ID，关联 dim_prd_scenic_df', 'lid'),
         ('scenic_name', S, '维度属性', '景区名称（资源中心景区）', 'land_name'),
         ('scenic_level', S, '维度属性', '景区等级', 'land_level'),
         ('scenic_type_code', S, '状态类型', '景区类型：A-景区 B-线路 C-酒店 F-套票 …', 'p_type'),
         ('province_code', S, '外键', '景区所在省编码', 'CAST(land_province_code AS STRING)'),
         ('province_name', S, '维度属性', '景区所在省', 'province_name'),
         ('city_code', S, '外键', '景区所在市编码', 'CAST(land_city_code AS STRING)'),
         ('belong_area', S, '维度属性', '资源中心考核区域（按景区所在省）', 'district'),
         ('import_province_flag', I, '状态类型', '是否重点关注省：1-是', 'CAST(import_province AS INT)'),
         ('resource_type', I, '状态类型', '资源选项：0-未知 1-第三方 2-…', 'resource_type'),
         ('price_spread_amt', DEC, '维度属性', '分销差价（元）', yuan('price_spread')),
         ('sale_channel', S, '维度属性', '销售渠道', 'shop'),
         ('advance_day_qty', I, '维度属性', '提前下单天数', 'ddays'),
         ('refund_rule', I, '状态类型', '退票规则', 'refund_rule'), ('billing_state', I, '状态类型', '开票状态：0-无 1-可开发票 2-…', 'billing_state'),
         ('resource_status', I, '状态类型', '是否仍在资源中心分销：1-是 0-否', 'status'),
         ('platform_status', I, '状态类型', '平台状态：1-有效 0-无效', 'platform_status'),
         ('max_expiration_date', S, '时间', '门票最大有效日期', 'max_expiration_date'),
         ('purchase_member_qty', B, '度量', '已采购的分销商数（采购状态 = 已采购）', 'COALESCE(purchase_member_qty, 0)'),
         ('scenic_sales_qty', B, '度量', '景区累计销量（资源中心统计）', 'scenic_sales'),
         ('scenic_purchase_qty', B, '度量', '景区被采购数（资源中心统计）', 'scenic_purchase_num'),
         ('operator_id', B, '外键', '最后操作员ID', 'opid'),
         ('add_time', S, '时间', '上架时间', ts('add_time')), ('update_time', S, '时间', '最后更新时间', ts('update_time')),
     ], part='',
     frm={'ods_prd_resource_product_df': q("""
SELECT r.*, l.land_name, l.land_level, l.p_type, l.province_code AS land_province_code, l.city_code AS land_city_code,
       pv.province_name, d.district, d.import_province, la.resource_type, la.sales AS scenic_sales, la.purchase_num AS scenic_purchase_num,
       pc.purchase_member_qty
FROM ods.ods_prd_resource_product_df r
LEFT JOIN ods.ods_prd_resource_land_df l ON l.sid = r.sid AND l.lid = r.lid AND l.travel_date = '${bizdate}'           -- 资源中心景区
LEFT JOIN ods.ods_prd_resource_land_attr_df la ON la.sid = r.sid AND la.lid = r.lid AND la.travel_date = '${bizdate}'  -- 景区统计属性
LEFT JOIN ods.ods_opr_province_df pv ON pv.province_code = l.province_code AND pv.travel_date = '${bizdate}'          -- 省编码 → 省名
LEFT JOIN ods.ods_opr_resource_center_district_df d ON d.province = pv.province_name AND d.travel_date = '${bizdate}' -- 省 → 考核区域
LEFT JOIN (SELECT sid, ticket_id, COUNT(DISTINCT fid) AS purchase_member_qty FROM ods.ods_prd_resource_purchase_df
           WHERE travel_date = '${bizdate}' AND status = 1 GROUP BY sid, ticket_id) pc ON pc.sid = r.sid AND pc.ticket_id = r.ticket_id
WHERE r.travel_date = '${bizdate}'""")},
     notes=['考核区域：景区所在省（省编码 → 省名）对资源中心区域配置表；采购数：采购关系中状态为已采购的分销商去重',
            '旧表的采购链路有效期、自动采购等列来自旧中间表的采购关系，已在 dwd_prd_resource_purchase_di（采购明细）中提供，维度不再重复'])

proc('dim_trf_gate_f', '闸机 / 终端维度', '1行=1个终端（闸机 / 手持机，按设备特征码）', 'ods_trf_device_inout_journal_di',
     '终端清单：所属景区、供应商、节点（闸机组）、站点，以及首次 / 最近出现时间；昨日维表 + 今日出入园流水滚动合并（流水无独立设备主表）',
     ['ods_trf_device_inout_journal_di'], [
         ('terminal_no', S, '主键', '终端编号（设备特征码）', 'device_key'),
         ('gate_group_id', B, '外键', '闸机组（节点）ID', 'node_id'),
         ('scenic_id', B, '外键', '所属景区ID，关联 dim_prd_scenic_df', 'land_id'),
         ('supplier_id', B, '外键', '所属供应商ID', 'sid'),
         ('site_id', B, '外键', '站点ID', 'site_id'),
         ('first_seen_time', S, '时间', '首次出现时间（首条出入园记录）', 'first_seen_time'),
         ('last_seen_time', S, '时间', '最近出现时间', 'last_seen_time'),
     ], part='',
     frm={'ods_trf_device_inout_journal_di': q("""
SELECT device_key, MAX(node_id) AS node_id, MAX(land_id) AS land_id, MAX(sid) AS sid, MAX(site_id) AS site_id,
       MIN(first_seen_time) AS first_seen_time, MAX(last_seen_time) AS last_seen_time
FROM (SELECT terminal_no AS device_key, gate_group_id AS node_id, scenic_id AS land_id, supplier_id AS sid, site_id, first_seen_time, last_seen_time
      FROM dim.dim_trf_gate_f                                                     -- 昨日维表（全量）
      UNION ALL
      SELECT device_key, node_id, land_id, sid, site_id, FROM_UNIXTIME(create_time) AS first_seen_time, FROM_UNIXTIME(create_time) AS last_seen_time
      FROM ods.ods_trf_device_inout_journal_di WHERE travel_date = '${bizdate}') u   -- 今日流水
GROUP BY device_key""")},
     notes=['流水只有设备特征码、没有设备主表：维表按「昨日维表 ∪ 今日流水」滚动，属性取最新非空，首次上线用全量历史流水初始化一次',
            '旧表的 单次数量 / 进出类型 / 创建时间 等是流水字段，在 dwd_trf_scenic_inout_di（出入园明细）'])

proc('dim_opr_region_f', '行政区划维度', '1行=1个行政区划（省 / 市 / 区县）', 'ods_opr_region_area_df、ods_opr_country_region_df',
     '统一行政区划，带出所属省 / 市 / 区县三级编码、名称、邮编、经纬度与国家；替代旧 dim_city_d_f、dim_city_fixed_d_f 与省表',
     ['ods_opr_region_area_df'], [
         ('region_code', S, '主键', '行政区划代码（如 110000）', 'area_code'),
         ('region_name', S, '维度属性', '区划名称', 'area_name'),
         ('short_name', S, '维度属性', '简称', 'short_name'), ('full_name', S, '维度属性', '级联全称（如 福建省 厦门市 思明区）', 'join_name'),
         ('parent_code', S, '外键', '上级区划代码', 'parent_code'),
         ('region_level', I, '状态类型', '级别：1-省 / 直辖市 / 特别行政区 2-市 3-区县', 'level'),
         ('country_id', B, '外键', '国家ID', 'country_id'), ('country_name', S, '维度属性', '国家名称', 'country_name'),
         ('province_code', S, '外键', '所属省代码', 'prov_code'), ('province_name', S, '维度属性', '所属省名称', 'prov_name'),
         ('province_zip_code', S, '维度属性', '省邮编', 'prov_zip'), ('province_lng', S, '维度属性', '省经度', 'prov_lng'), ('province_lat', S, '维度属性', '省纬度', 'prov_lat'),
         ('city_id', B, '外键', '所属市区划记录ID', 'city_id'),
         ('city_code', S, '外键', '所属市代码', 'cty_code'), ('city_name', S, '维度属性', '所属市名称', 'cty_name'),
         ('city_zip_code', S, '维度属性', '市邮编', 'cty_zip'), ('city_lng', S, '维度属性', '市经度', 'cty_lng'), ('city_lat', S, '维度属性', '市纬度', 'cty_lat'),
         ('district_code', S, '外键', '区县代码（区县级才有）', 'dst_code'), ('district_name', S, '维度属性', '区县名称', 'dst_name'),
         ('district_zip_code', S, '维度属性', '区县邮编', 'dst_zip'), ('district_lng', S, '维度属性', '区县经度', 'dst_lng'), ('district_lat', S, '维度属性', '区县纬度', 'dst_lat'),
         ('phone_area_code', S, '维度属性', '电话区号', 'phone_area_code'),
         ('zip_code', S, '维度属性', '本级邮编', 'CAST(zip_code AS STRING)'), ('lng', S, '维度属性', '本级经度', 'CAST(lng AS STRING)'), ('lat', S, '维度属性', '本级纬度', 'CAST(lat AS STRING)'),
     ], part='',
     frm={'ods_opr_region_area_df': q("""
SELECT a.*, a.city_code AS phone_area_code, c.name_zh AS country_name,
       -- 按本级级别定位省 / 市 / 区县：1 级本身是省；2 级本身是市、上级是省；3 级本身是区县、上级是市、上上级是省
       CASE a.level WHEN 1 THEN a.area_code WHEN 2 THEN p1.area_code ELSE p2.area_code END AS prov_code,
       CASE a.level WHEN 1 THEN a.area_name WHEN 2 THEN p1.area_name ELSE p2.area_name END AS prov_name,
       CAST(CASE a.level WHEN 1 THEN a.zip_code WHEN 2 THEN p1.zip_code ELSE p2.zip_code END AS STRING) AS prov_zip,
       CAST(CASE a.level WHEN 1 THEN a.lng WHEN 2 THEN p1.lng ELSE p2.lng END AS STRING) AS prov_lng,
       CAST(CASE a.level WHEN 1 THEN a.lat WHEN 2 THEN p1.lat ELSE p2.lat END AS STRING) AS prov_lat,
       CASE a.level WHEN 2 THEN a.id WHEN 3 THEN p1.id END AS city_id,
       CASE a.level WHEN 2 THEN a.area_code WHEN 3 THEN p1.area_code END AS cty_code,
       CASE a.level WHEN 2 THEN a.area_name WHEN 3 THEN p1.area_name END AS cty_name,
       CAST(CASE a.level WHEN 2 THEN a.zip_code WHEN 3 THEN p1.zip_code END AS STRING) AS cty_zip,
       CAST(CASE a.level WHEN 2 THEN a.lng WHEN 3 THEN p1.lng END AS STRING) AS cty_lng,
       CAST(CASE a.level WHEN 2 THEN a.lat WHEN 3 THEN p1.lat END AS STRING) AS cty_lat,
       IF(a.level = 3, a.area_code, NULL) AS dst_code, IF(a.level = 3, a.area_name, NULL) AS dst_name,
       IF(a.level = 3, CAST(a.zip_code AS STRING), NULL) AS dst_zip, IF(a.level = 3, CAST(a.lng AS STRING), NULL) AS dst_lng, IF(a.level = 3, CAST(a.lat AS STRING), NULL) AS dst_lat
FROM ods.ods_opr_region_area_df a
LEFT JOIN ods.ods_opr_region_area_df p1 ON p1.area_code = a.parent_code AND p1.travel_date = '${bizdate}'   -- 上级
LEFT JOIN ods.ods_opr_region_area_df p2 ON p2.area_code = p1.parent_code AND p2.travel_date = '${bizdate}'  -- 上上级
LEFT JOIN ods.ods_opr_country_region_df c ON c.id = a.country_id AND c.travel_date = '${bizdate}'           -- 国家
WHERE a.travel_date = '${bizdate}' AND a.status = 1                                                          -- 只取正常（1）；撤消 / 合并的不要""")},
     notes=['上级链自关联两次得到省 / 市；修正：原条件 status = 0 实际取的是非正常记录，源表 1 = 正常',
            '旧表 stat_date（与分区重复）、*_adcode（与区划代码相同）不再保留；area_code 统一为 region_code'])

proc('dim_opr_phone_area_f', '手机号段 / 国际区号维度', '1行=1个手机号段（前 7 位）或 1 个国际电话区号',
     'ods_opr_city_phone_df、ods_opr_global_phone_area_df、ods_opr_country_region_df',
     '国内手机号段 → 运营商、省市；国际电话区号 → 国家（中英文名、ISO 代码）；DWD 按号码前缀等值关联',
     ['ods_opr_city_phone_df', 'ods_opr_global_phone_area_df'], [
         ('phone_prefix_type', S, '主键', '前缀类型：SEGMENT-国内手机号段 / COUNTRY_CODE-国际区号', ("'SEGMENT'", "'COUNTRY_CODE'")),
         ('phone_prefix', S, '主键', '前缀：号段前 7 位 / 国际区号（如 86、852）', ('CAST(number AS STRING)', 'phone_area_code')),
         ('carrier_type', I, '状态类型', '运营商：1-移动 2-联通 3-电信 4-…（号段）', ('CAST(type AS INT)', NUL[I])),
         ('province_code', S, '外键', '省编码', ('CAST(province_code AS STRING)', NUL[S])), ('province_name', S, '维度属性', '省名称', ('province_name', NUL[S])),
         ('city_code', S, '外键', '市编码', ('CAST(city_code AS STRING)', NUL[S])), ('city_name', S, '维度属性', '市名称', ('city_name', NUL[S])),
         ('area_code', S, '维度属性', '区域编码（平台区域码）', ('COALESCE(pft_area_code, CAST(area_code AS STRING))', NUL[S])),
         ('zip_code', S, '维度属性', '邮编', ('zip_code', NUL[S])),
         ('country_code', S, '外键', '国家编码', ('CAST(country_code AS STRING)', 'CAST(country_id AS STRING)')),
         ('country_name', S, '维度属性', '国家名称（中文）', ('country_name', 'name_zh')),
         ('country_name_en', S, '维度属性', '国家名称（英文）', (NUL[S], 'name_en')),
         ('country_full_name', S, '维度属性', '国家中文全称', (NUL[S], 'full_name_zh')), ('country_full_name_en', S, '维度属性', '国家英文全称', (NUL[S], 'full_name_en')),
         ('is_country', I, '状态类型', '是否独立国家：0-否 1-是', (NUL[I], 'is_country')),
         ('alpha_2_code', S, '维度属性', 'ISO 3166-1 二位字母码', (NUL[S], 'alpha_2_code')), ('alpha_3_code', S, '维度属性', 'ISO 3166-1 三位字母码', (NUL[S], 'alpha_3_code')),
         ('numeric_3_code', S, '维度属性', 'ISO 3166-1 三位数字码', (NUL[S], 'numeric_3_code')),
         ('lng', S, '维度属性', '经度', ('lng', NUL[S])), ('lat', S, '维度属性', '纬度', ('lat', NUL[S])),
     ], part='',
     frm={'ods_opr_global_phone_area_df': q("""
SELECT g.*, c.name_zh, c.name_en, c.full_name_zh, c.full_name_en, c.is_country, c.alpha_2_code, c.alpha_3_code, c.numeric_3_code
FROM ods.ods_opr_global_phone_area_df g
LEFT JOIN ods.ods_opr_country_region_df c ON c.id = g.country_id AND c.travel_date = '${bizdate}'   -- 国家码表
WHERE g.travel_date = '${bizdate}'""")},
     notes=['号段与国际区号两类 UNION ALL（phone_prefix_type 区分）；号段到地市级，没有区县',
            '旧表 phone_city_id / phone_number（与主键、号段重复）、stat_date 不再保留；号段、区号是编码不是个人号码，ODS 不再误脱敏'])

proc('dim_opr_idcard_area_f', '身份证地区维度', '1行=1个身份证前 6 位地区码', 'ods_opr_idcard_city_df、ods_opr_region_area_df',
     '身份证前 6 位 → 省 / 市 / 区县名称与编码、邮编、经纬度；游客客源地解析用',
     ['ods_opr_idcard_city_df'], [
         ('area_code', S, '主键', '身份证前 6 位地区码', 'LPAD(CAST(idcard AS STRING), 6, \'0\')'),
         ('province_code', S, '外键', '省编码（前 2 位补 0）', "CONCAT(SUBSTR(LPAD(CAST(idcard AS STRING), 6, '0'), 1, 2), '0000')"),
         ('province_name', S, '维度属性', '省名称', 'province'),
         ('city_code', S, '外键', '市编码（前 4 位补 0）', "CONCAT(SUBSTR(LPAD(CAST(idcard AS STRING), 6, '0'), 1, 4), '00')"),
         ('city_name', S, '维度属性', '市名称', 'city'),
         ('district_name', S, '维度属性', '区县名称', 'country'),
         ('country_name', S, '维度属性', '国家（身份证地区码均为中国大陆）', "'中国'"),
         ('zip_code', S, '维度属性', '邮编（按地区码关联行政区划）', 'CAST(zip_code AS STRING)'),
         ('lng', S, '维度属性', '经度', 'CAST(lng AS STRING)'), ('lat', S, '维度属性', '纬度', 'CAST(lat AS STRING)'),
     ], part='',
     frm={'ods_opr_idcard_city_df': q("""
SELECT i.*, r.zip_code, r.lng, r.lat
FROM ods.ods_opr_idcard_city_df i
LEFT JOIN ods.ods_opr_region_area_df r ON r.area_code = LPAD(CAST(i.idcard AS STRING), 6, '0') AND r.travel_date = '${bizdate}'   -- 地区码 = 行政区划代码
WHERE i.travel_date = '${bizdate}'""")},
     notes=['源表字段 country 实为区县名；旧表 idcard_city_id / id_card_no（与主键重复）、stat_date 不再保留'])

proc('dim_trf_channel_f', '下单渠道 / 分销平台维度', '1行=1个渠道（下单渠道 / 第三方分销系统 / 第三方采购系统）',
     'ods_opr_channel_df、ods_opr_distribute_system_type_df、ods_opr_third_purchase_system_df',
     '订单下单渠道（ordermode）、对接的第三方分销系统（按账号）、第三方采购系统三类渠道统一一张维表（channel_type 区分）',
     ['ods_opr_channel_df', 'ods_opr_distribute_system_type_df', 'ods_opr_third_purchase_system_df'], [
         ('channel_type', S, '主键', '渠道类型：ORDER_CHANNEL-下单渠道 / DISTRIBUTE_SYSTEM-分销系统 / PURCHASE_SYSTEM-采购系统',
          ("'ORDER_CHANNEL'", "'DISTRIBUTE_SYSTEM'", "'PURCHASE_SYSTEM'")),
         ('channel_code', S, '主键', '渠道编码：下单渠道 ID / 分销系统类型 / 采购系统 ID',
          ('CAST(order_channel_id AS STRING)', 'distribute_system_type', 'CAST(coopb AS STRING)')),
         ('channel_name', S, '维度属性', '渠道名称', ('channel_name', 'distribute_system_name', 'system_name')),
         ('channel_aggregation_name', S, '维度属性', '渠道大类：线上 / 线下 / 第三方分销 / 第三方采购',
          ("IF(is_line_off = 1, '线下', '线上')", "'第三方分销'", "'第三方采购'")),
         ('order_channel_id', B, '外键', '订单表渠道ID（下单渠道）', ('order_channel_id', NUL[B], NUL[B])),
         ('track_source_id', B, '外键', '轨迹表来源ID', ('track_source_id', NUL[B], NUL[B])),
         ('is_line_off', I, '状态类型', '0-线上 1-线下', ('CAST(is_line_off AS INT)', NUL[I], NUL[I])),
         ('is_group', I, '状态类型', '是否组', ('CAST(is_group AS INT)', NUL[I], NUL[I])),
         ('member_id', B, '外键', '分销系统对应的平台账号ID', (NUL[B], 'user_id', NUL[B])),
         ('account', S, '维度属性', '分销系统对应的平台账号', (NUL[S], 'account', NUL[S])),
         ('rule_code', S, '维度属性', '识别规则：对接 URL 标志', (NUL[S], 'dcodeurl_like', NUL[S])),
     ], part='',
     notes=['三类渠道 UNION ALL；旧 OTA 渠道配置表的回调地址（loopback_address）为对接配置、target_id 无业务含义，不进维度；stat_date 与分区重复不保留'])

_PAY = json.loads((pathlib.Path(__file__).with_name('pay_channel_codes.json')).read_text(encoding='utf-8'))
_VALS = ',\n'.join(f"       ({a}, {b}, '{c}', '{d}')" for a, b, c, d in _PAY)
proc('dim_fin_pay_channel_f', '支付方式维度', '1行=1种支付方式（订单 paymode）', '码表（旧 dim_pay_channel_o_f 手工维护，迁入 dataworks/standard/pay_channel_codes.json）',
     '订单支付方式编码 → 名称，以及汇总口径的映射（线下收款 1 / 2 / 3 → 线下收款）；码表随仓库版本管理，新增支付方式改 json 后重跑',
     ['pay_channel_codes'], [
         ('pay_mode', I, '主键', '支付方式编码（订单 paymode）', 'pay_mode'),
         ('pay_mode_name', S, '维度属性', '支付方式名称', 'pay_mode_name'),
         ('pay_channel_id', I, '外键', '支付渠道ID（同支付方式编码）', 'pay_mode'),
         ('pay_channel_name', S, '维度属性', '支付渠道名称', 'pay_mode_name'),
         ('pay_channel_mapping_id', I, '外键', '汇总映射ID（多种同类方式归一，如 76 / 77 / 78 → 7685）', 'mapping_id'),
         ('pay_channel_mapping_name', S, '维度属性', '汇总映射名称', 'mapping_name'),
     ], part='',
     frm={'pay_channel_codes': "(\n        SELECT * FROM VALUES\n" + _VALS + "\n        AS v(pay_mode, mapping_id, pay_mode_name, mapping_name)\n    ) t"},
     notes=[f'共 {len(_PAY)} 种支付方式；旧系统为手工 INSERT VALUES 维护，原样迁入（不依赖商户收款方式表）'])

proc('dim_fin_account_subject_f', '账本科目维度', '1行=1个账本科目', 'ods_fin_account_book_subject_df',
     '账户流水的科目属性：类型、单位、可提现 / 可开票 / 可积分、优先级、退款期限与上限、是否第三方、交易类型；流水按 subject_code 关联',
     ['ods_fin_account_book_subject_df'], [
         ('subject_code', S, '主键', '账本科目编码', 'CAST(subject_code AS STRING)'), ('subject_name', S, '维度属性', '科目名称', 'subject_name'),
         ('subject_type', I, '状态类型', '科目类型：1-平台余额类 2-授信类 …', 'type'), ('unit', S, '维度属性', '单位', 'unit'),
         ('can_withdraw', I, '状态类型', '是否可提现：0-否 1-是', 'can_withdraw'), ('can_invoice', I, '状态类型', '是否可开发票', 'can_invoice'),
         ('can_integral', I, '状态类型', '是否可计算积分', 'can_integral'), ('is_default', I, '状态类型', '是否默认创建', 'is_default'),
         ('priority', I, '维度属性', '优先级（越大越优先）', 'priority'), ('repeatable', I, '状态类型', '是否可多条记录', 'repeatable'),
         ('refund_expire_hour_qty', B, '维度属性', '退款期限（小时）', 'refund_expires'),
         ('refund_limit_amt', DEC, '维度属性', '退款上限（元）', yuan('refund_limit')), ('remaining_limit_amt', DEC, '维度属性', '余额上限（元）', yuan('remaining_limit')),
         ('third_party_flag', I, '状态类型', '是否第三方支付', 'third_party'), ('trade_type', I, '状态类型', '交易类型：0-普通 1-授信 2-押金 …', 'trade_type'),
         ('ext_rule', S, '维度属性', '扩展规则', 'ext'), ('remark', S, '维度属性', '备注', 'remark'),
         ('add_time', S, '时间', '创建时间', ts('add_time')), ('update_time', S, '时间', '更新时间', ts('update_time')),
     ], part='', notes=['原来混在账户流水明细里的 18 个科目属性移到本维表（流水只留 subject_code），不再每条流水重复存'])

proc('dim_prd_ticket_price_zip', '门票价格', '1行=1张门票×1个价格配置（平日 / 特殊日期区间）', 'ods_prd_ticket_price_df、ods_prd_ticket_df',
     '门票价格配置：平日价 / 周末价 / 特殊价 / 零售价 / 窗口价、生效日期区间与适用星期；成本价 = 特殊日期取特殊价否则取平日价，零售价 = l_price（同旧 dim_prod_price_d_f）',
     ['ods_prd_ticket_price_df'], [
         ('ticket_id', B, '主键', '票ID', 'ticket_id'), ('price_id', B, '主键', '价格配置ID', 'id'),
         ('product_id', B, '外键', '产品ID', 'pid'), ('scenic_id', B, '外键', '景区ID（关联票维度）', 'landid'),
         ('price_type', I, '状态类型', '价格类型：0-平时 1-特殊日期', 'ptype'),
         ('start_date', S, '时间', '生效开始日期', 'start_date'), ('end_date', S, '时间', '生效结束日期', 'end_date'),
         ('weekdays', S, '维度属性', '适用星期（0-6，逗号分隔）', 'weekdays'),
         ('weekday_price_amt', DEC, '维度属性', '平日价（元）', yuan('n_price')), ('weekend_price_amt', DEC, '维度属性', '周末价（元）', yuan('m_price')),
         ('special_price_amt', DEC, '维度属性', '特殊日期价（元）', yuan('s_price')),
         ('cost_price_amt', DEC, '维度属性', '成本价（元）= 特殊日期取特殊价，否则平日价', f"IF(ptype = 1, {yuan('s_price')}, {yuan('n_price')})"),
         ('sale_price_amt', DEC, '维度属性', '零售价（元）', yuan('l_price')), ('window_price_amt', DEC, '维度属性', '窗口价（元）', yuan('window_price')),
         ('price_status', I, '状态类型', '审核状态：0-未审核 1-被拒绝 2-已审核', 'status'),
         ('storage_qty', B, '维度属性', '库存', 'storage'),
         ('curr_price_rank', I, '维度属性', '统计日适用顺序：1 = 统计日命中的价格（特殊日期优先，其次离统计日最近的区间）', 'CAST(curr_price_rank AS INT)'),
         ('update_time', S, '时间', '最后更新时间', ts('update_time')), ('operator_id', B, '外键', '最后操作员', 'operater_id'),
     ], part='',
     frm={'ods_prd_ticket_price_df': q("""
SELECT p.*, t.landid,
       ROW_NUMBER() OVER (PARTITION BY p.ticket_id
                          ORDER BY IF(TO_DATE(p.start_date) <= TO_DATE('${bizdate}', 'yyyyMMdd') AND TO_DATE(p.end_date) >= TO_DATE('${bizdate}', 'yyyyMMdd'), 0, 1),
                                   p.ptype DESC, ABS(DATEDIFF(TO_DATE(p.end_date), TO_DATE('${bizdate}', 'yyyyMMdd')))) AS curr_price_rank
FROM ods.ods_prd_ticket_price_df p
LEFT JOIN (SELECT id, MAX(landid) AS landid FROM ods.ods_prd_ticket_df WHERE travel_date = '${bizdate}' GROUP BY id) t ON t.id = p.ticket_id   -- 票 → 景区
WHERE p.travel_date = '${bizdate}' AND p.status = 2""")},
     notes=['只取审核通过的价格配置；当日命中价格：区间包含统计日优先、特殊日期优先、再按离统计日最近（同旧 curr_price_rank）',
            '旧拉链表的 order_status、price（旧 dws 拉链的单一价）由 成本价 / 零售价 两列代替；stat_date 不保留'])

# ============================================================================ DWD
proc('dwd_sup_service_merchant_di', '商户其他合作明细', '1行=1条商户其他合作（硬件 / 软件 / 其他）记录',
     'ods_sup_cooperation_other_df、dim_sup_member_df',
     '平台对商户的其他合作项目：合作类型、合作金额、合作 / 回款日期、签单人；替代旧服务商户表',
     ['ods_sup_cooperation_other_df'], [
         ('cooperation_id', B, '主键', '合作记录ID', 'id'),
         ('member_id', B, '外键', '商户ID，关联 dim_sup_member_df', 'member_id'),
         ('member_name', S, '维度属性', '商户名称（关联商户维度）', 'member_name'),
         ('member_type_code', S, '状态类型', '商户类型（关联商户维度）', 'member_type_code'),
         ('cooperation_type', I, '状态类型', '合作类型：1-硬件 2-软件 3-其他', 'cooperat_type'),
         ('cooperation_amt', DEC, '度量', '合作金额（元）', yuan('cooperat_money')),
         ('cooperation_date', S, '时间', '合作日期', "FROM_UNIXTIME(cooperat_time, 'yyyy-MM-dd')"),
         ('repayment_date', S, '时间', '回款日期', "IF(repayment_time > 0, FROM_UNIXTIME(repayment_time, 'yyyy-MM-dd'), NULL)"),
         ('sales_id', B, '外键', '签单人ID，关联 dim_sup_staff_df', 'sales_id'),
         ('remark', S, '维度属性', '备注', 'remark'),
         ('create_time', S, '时间', '登记时间', ts('create_time')), ('update_time', S, '时间', '更新时间', ts('update_time')),
     ],
     frm={'ods_sup_cooperation_other_df': q("""
SELECT c.*, m.member_name, m.member_type_code
FROM ods.ods_sup_cooperation_other_df c
LEFT JOIN dim.dim_sup_member_df m ON m.member_id = c.member_id                    -- 商户名称 / 类型
WHERE c.travel_date = '${bizdate}' AND c.is_delete = 0
  AND (FROM_UNIXTIME(c.create_time, 'yyyyMMdd') = '${bizdate}' OR FROM_UNIXTIME(c.update_time, 'yyyyMMdd') = '${bizdate}')   -- 全量快照取当日新增 / 变更""")},
     notes=['旧表的 服务起止时间 = 合作日期 / 回款日期；省市来自旧客户属性宽表，商户所在地在 dim_sup_company_df'])

proc('dwd_sup_customer_visit_di', '客户拜访 / 接待明细', '1行=1条客户拜访接待登记（OA 建模表单）', 'ods_sup_oa_customer_visit_ledger_df',
     '销售拜访 / 接待客户的登记：客户、平台账号、合作类型、金额、登记人与时间；按登记日 = 统计日取当日',
     ['ods_sup_oa_customer_visit_ledger_df'], [
         ('visit_id', B, '主键', '登记记录ID', 'id'), ('request_id', B, '外键', 'OA 流程请求ID', 'requestid'),
         ('flow_no', S, '业务主键', 'OA 流程编号', 'lcbh'),
         ('customer_name', S, '维度属性', '客户名称', 'khmc'),
         ('member_id', B, '外键', '客户平台账号ID（关联 dim_sup_member_df）', "CAST(REGEXP_EXTRACT(ptid, '(\\\\d+)', 1) AS BIGINT)"),
         ('cooperation_type', I, '状态类型', '合作类型（OA 选项值）', 'CAST(hzlx AS INT)'),
         ('visit_type', I, '状态类型', '登记类型（OA 选项值）', 'CAST(s AS INT)'),
         ('commission_flag', I, '状态类型', '是否计提成（OA 选项值）', 'CAST(tc AS INT)'),
         ('order_abnormal_flag', I, '状态类型', '是否订单异常（OA 选项值）', 'CAST(ddyc AS INT)'),
         ('amount', DEC, '度量', '金额（元）', 'CAST(je AS DECIMAL(18,2))'),
         ('staff_id', B, '外键', '登记人（OA 人员ID）', 'modedatacreater'),
         ('visit_time', S, '时间', '登记时间', "CONCAT(modedatacreatedate, ' ', modedatacreatetime)"),
         ('modify_time', S, '时间', '最后修改时间', 'modedatamodifydatetime'),
     ], event={'ods_sup_oa_customer_visit_ledger_df': "REGEXP_REPLACE(modedatacreatedate, '-', '')"},
     notes=['OA 拼音缩写字段（gslx / jq / lhs …）含义未确认，未纳入；平台ID 字段为文本，取其中数字作为商户ID',
            '旧表来自 OA 接待明细中间表，改为直接读登记台账 ODS'])

# ---------------------------------------------------------------- 已有 DWD：补字段 / 修正
DWD_FIX = {}   # 表 -> {'drop': {字段: 原因}}（build.py 生成字段时跳过）
DWD_FIX['dwd_fin_trade_journal_di'] = {'drop': {c: '科目属性，移到 dim_fin_account_subject_f（按 subject_code 关联）' for c in (
    'subject_name', 'type', 'unit', 'can_withdraw', 'can_invoice', 'can_integral', 'is_default', 'priority', 'repeatable', 'refund_expires',
    'refund_limit', 'remaining_limit', 'third_party', 'trade_type', 'ext', 'remark', 'add_time', 'update_time')}}


# ---------------------------------------------------------------- 年卡交易（修正交易类型码值 + 激活申请）
_TK = ("LEFT JOIN (SELECT ticket_id, MAX(scenic_id) AS t_scenic_id FROM dim.dim_prd_ticket_df GROUP BY ticket_id) tk ON tk.ticket_id = a.{c}   -- 票 → 景区")
proc('dwd_ord_annual_card_trade_di', '年卡交易明细', '1行=1笔年卡交易（售卡 / 续费 / 补卡 / 取消 / 激活 / 特权支付）或 1 次激活申请',
     'ods_ord_annual_card_trade_di、ods_ord_annual_card_active_apply_df、dim_prd_ticket_df',
     '年卡交易流水与激活申请 UNION ALL（trade_source 区分）；景区由年卡门票带出；申请人姓名 / 手机 / 证件 / 审核材料不进事实表',
     ['ods_ord_annual_card_trade_di', 'ods_ord_annual_card_active_apply_df'], [
         ('trade_source', S, '主键', '来源：TRADE-年卡交易 / ACTIVE_APPLY-激活申请', ("'TRADE'", "'ACTIVE_APPLY'")),
         ('trade_id', B, '主键', '记录ID（与来源联合唯一）', ('id', 'id')),
         ('trade_no', S, '业务主键', '交易订单号（激活申请为申请ID）', ('ordernum', 'CAST(id AS STRING)')),
         ('order_no', S, '外键', '平台订单号（售卡 / 续费订单）', ('ordernum', NUL[S])),
         ('card_id', B, '外键', '年卡ID', ('card_id', 'annual_id')),
         ('card_product_id', B, '外键', '年卡产品ID', ('pid', NUL[B])),
         ('card_package_name', S, '维度属性', '卡套餐名称', ('p_name', NUL[S])),
         ('trade_type', S, '状态类型', '交易类型：SELL-售卡 RENEW-续费 REISSUE-补卡 CANCEL-取消 ACTIVE-激活 PRIVILEGE_PAY-验证（特权支付）/ ACTIVE_APPLY-激活申请',
          ("CASE type WHEN 0 THEN 'SELL' WHEN 1 THEN 'RENEW' WHEN 2 THEN 'REISSUE' WHEN 3 THEN 'CANCEL' WHEN 4 THEN 'ACTIVE' WHEN 5 THEN 'PRIVILEGE_PAY' ELSE CAST(type AS STRING) END",
           "'ACTIVE_APPLY'")),
         ('ticket_id', B, '外键', '年卡门票ID', ('ticket_id', 'tid')),
         ('scenic_id', B, '外键', '景区ID（年卡门票所属景区）', ('t_scenic_id', 't_scenic_id')),
         ('supplier_id', B, '外键', '供应商ID（租户ID）', ('sid', 'sid')),
         ('member_id', B, '外键', '持卡会员ID', ('member_id', NUL[B])),
         ('pay_way', I, '状态类型', '支付方式', ('payway', NUL[I])),
         ('trade_channel', I, '状态类型', '交易来源：0-平台 10-云票务 …', ('source', NUL[I])),
         ('trade_qty', B, '度量', '数量', ('num', NUL[B])),
         ('trade_amt', DEC, '度量', '支付金额（元）', (yuan('pay_money'), NUL[DEC])),
         ('card_no_mask', S, '维度属性', '实体卡号（ODS 已脱敏）', ('card_no', NUL[S])),
         ('virtual_no', S, '维度属性', '虚拟卡号', ('virtual_no', NUL[S])), ('physics_no', S, '维度属性', '物理卡号', ('physics_no', NUL[S])),
         ('audit_status', I, '状态类型', '激活申请审核状态：0-审核中 1-通过 2-拒绝', (NUL[I], 'state')),
         ('apply_remark', S, '维度属性', '激活申请备注', (NUL[S], 'apply_remark')), ('audit_remark', S, '维度属性', '激活审核备注', (NUL[S], 'audit_remark')),
         ('remark', S, '维度属性', '交易备注', ('remark', NUL[S])),
         ('operator_id', B, '外键', '操作员 / 审核人ID', ('operator_id', 'op_id')),
         ('trade_time', S, '时间', '交易 / 申请时间', (ts('add_time'), 'create_time')), ('update_time', S, '时间', '更新时间', (ts('update_time'), 'update_time')),
     ], legacy=[],
     event={'ods_ord_annual_card_active_apply_df': "REGEXP_REPLACE(SUBSTR(create_time, 1, 10), '-', '')"},
     frm={'ods_ord_annual_card_trade_di': q("SELECT a.*, tk.t_scenic_id\nFROM ods.ods_ord_annual_card_trade_di a\n" + _TK.format(c='ticket_id') + "\nWHERE a.travel_date = '${bizdate}'"),
          'ods_ord_annual_card_active_apply_df': q("SELECT a.*, tk.t_scenic_id\nFROM ods.ods_ord_annual_card_active_apply_df a\n" + _TK.format(c='tid') +
                                                    "\nWHERE a.travel_date = '${bizdate}' AND REGEXP_REPLACE(SUBSTR(a.create_time, 1, 10), '-', '') = '${bizdate}'   -- 全量快照取当日申请")},
     notes=['修正交易类型码值：源表 0 售卡 1 续费 2 补卡 3 取消 4 激活 5 验证（特权支付），原映射把 2（补卡）当激活',
            '激活申请人姓名 / 手机 / 证件、审核材料（证件照片）、激活参数报文属个人信息，不进事实表'])

# ---------------------------------------------------------------- 出入园（修正进出方向）
proc('dwd_trf_scenic_inout_di', '出入园明细', '1行=1次过闸（入园 / 离园）', 'ods_trf_device_inout_journal_di',
     '闸机 / 手持机出入园流水：景区、票、终端、闸机组、进出方向、人数，以及当日按景区累计的进 / 出人数',
     ['ods_trf_device_inout_journal_di'], [
         ('inout_id', B, '主键', '流水ID', 'id'),
         ('scenic_id', B, '外键', '景区ID', 'land_id'), ('supplier_id', B, '外键', '供应商ID', 'sid'), ('ticket_id', B, '外键', '票ID', 'tid'),
         ('terminal_no', S, '外键', '终端编号（设备特征码），关联 dim_trf_gate_f', 'device_key'),
         ('gate_group_id', B, '外键', '闸机组（节点）ID', 'node_id'), ('site_id', B, '外键', '站点ID', 'site_id'),
         ('inout_type', S, '状态类型', '进出方向：IN-入园 / OUT-离园', "CASE roll_type WHEN 0 THEN 'IN' WHEN 1 THEN 'OUT' ELSE 'OTHER' END"),
         ('person_qty', B, '度量', '本次通过人数', 'num'),
         ('inout_time', S, '时间', '过闸时间', ts('create_time')),
         ('visit_date', S, '时间', '游览日期', "FROM_UNIXTIME(create_time, 'yyyy-MM-dd')"),
         ('visit_hour', I, '时间', '过闸小时（0-23）', "CAST(FROM_UNIXTIME(create_time, 'H') AS INT)"),
         ('day_cum_qty', B, '度量', '当日截至本次的累计人数（同景区、同方向）', 'day_cum_qty'),
     ],
     frm={'ods_trf_device_inout_journal_di': q("""
SELECT j.*, SUM(num) OVER (PARTITION BY land_id, roll_type ORDER BY create_time, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS day_cum_qty
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY create_time DESC) AS rn FROM ods.ods_trf_device_inout_journal_di WHERE travel_date = '${bizdate}') j
WHERE j.rn = 1                                                                    -- 同一流水重复同步取一条""")},
     notes=['修正进出方向：源表 roll_type 0 = 入园、1 = 离园（原映射为 1 进 2 出，进出人数整体错位）',
            '当日累计（旧 all_num 来自报表库预计算 dc_daycount）改为按流水窗口累加，不再依赖预计算表'])

# ---------------------------------------------------------------- 应用模块开通
_JSON = lambda k: f"CAST(GET_JSON_OBJECT(details, '$.{k}') AS DECIMAL(18,2)) / 100"
proc('dwd_opr_module_open_di', '应用模块开通明细', '1行=1次模块开通（当日新开通）',
     'ods_opr_module_used_df、ods_opr_module_used_ext_df、ods_opr_module_used_log_df、ods_opr_module_price_df、dim_opr_module_package_df、dim_sup_staff_df',
     '商户开通应用模块：开通方式、有效期、合同 / 支付流水、签单人、实收 / 开票 / 业绩 / 终止实际消费金额、终止信息、第几次购买',
     ['ods_opr_module_used_df'], [
         ('module_open_id', B, '主键', '模块开通记录ID', 'id'),
         ('member_id', B, '外键', '开通商户ID，关联 dim_sup_member_df', 'member_id'),
         ('module_id', B, '外键', '模块ID，关联 dim_opr_module_package_df', 'module_id'),
         ('module_name', S, '维度属性', '模块名称', 'module_name'),
         ('open_type', I, '状态类型', '开通方式：0-自助开通 1-管理员开通', 'type'),
         ('module_status', I, '状态类型', '状态：1-正常使用 2-过期', 'status'),
         ('free_trial_flag', I, '状态类型', '是否试用过免费期：0-否 1-是', 'use_free'),
         ('buy_no', I, '维度属性', '该商户该模块第几次开通', 'CAST(buy_no AS INT)'),
         ('open_time', S, '时间', '开通时间', ts('create_time')),
         ('valid_start_time', S, '时间', '有效期开始（终止记录优先，否则模块开始时间）', "COALESCE(FROM_UNIXTIME(CAST(GET_JSON_OBJECT(time_details, '$.start_time') AS BIGINT)), FROM_UNIXTIME(begin_time))"),
         ('valid_end_time', S, '时间', '有效期结束', "COALESCE(FROM_UNIXTIME(CAST(GET_JSON_OBJECT(time_details, '$.end_time') AS BIGINT)), FROM_UNIXTIME(expire_time))"),
         ('stop_type', I, '状态类型', '终止类型：1-作废 2-提前终止', 'stop_type'),
         ('stop_time', S, '时间', '终止时间（作废取 stop_time，否则取结束时间）',
          "FROM_UNIXTIME(CAST(GET_JSON_OBJECT(time_details, IF(stop_type = 1, '$.stop_time', '$.end_time')) AS BIGINT))"),
         ('period_days', I, '维度属性', '资费周期天数：年 365 / 季 90 / 月 30', "CASE price_mode WHEN 1 THEN 365 WHEN 2 THEN 90 WHEN 3 THEN 30 END"),
         ('module_price_amt', DEC, '度量', '开通时资费（元）', yuan('price_fee')),
         ('contract_no', S, '外键', '合同编号', 'contract_no'), ('out_trade_no', S, '外键', '支付流水号', 'COALESCE(ext_trade_no, log_trade_no)'),
         ('sign_time', S, '时间', '签约时间', "IF(sign_time > 0, FROM_UNIXTIME(sign_time), NULL)"),
         ('sale_man_id', B, '外键', '签单人员工ID，关联 dim_sup_staff_df', 'saleman'),
         ('sale_man_name', S, '维度属性', '签单人姓名', 'staff_name'), ('sale_man_group', S, '维度属性', '签单人员工组', 'staff_group_name'),
         ('module_pay_amt', DEC, '度量', '实收金额（元）', _JSON('receipt')), ('module_invoice_amt', DEC, '度量', '开票金额（元）', _JSON('agree')),
         ('module_performance_amt', DEC, '度量', '业绩金额（元）', _JSON('achievement_money')),
         ('module_actual_amt', DEC, '度量', '终止时实际消费金额（元）', _JSON('real_money')),
         ('repayment_record', S, '维度属性', '回款记录', 'repayment_record'), ('sign_remark', S, '维度属性', '签单备注', 'sign_remark'),
     ],
     frm={'ods_opr_module_used_df': q("""
SELECT u.*, mp.module_name, e.contract_no, e.out_trade_no AS ext_trade_no, e.sign_time, e.saleman, e.details, e.time_details, e.stop_type,
       e.repayment_record, e.sign_remark, lg.out_trade_no AS log_trade_no, pr.fee AS price_fee, pr.mode AS price_mode, st.staff_name, st.staff_group_name
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY member_id, module_id ORDER BY create_time, id) AS buy_no   -- 全量快照上算第几次开通
      FROM ods.ods_opr_module_used_df WHERE travel_date = '${bizdate}') u
LEFT JOIN (SELECT module_id, MAX(module_name) AS module_name FROM dim.dim_opr_module_package_df GROUP BY module_id) mp ON mp.module_id = u.module_id
LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY member_id, module_id ORDER BY update_time DESC) AS rk FROM ods.ods_opr_module_used_ext_df
           WHERE travel_date = '${bizdate}' AND module_type = 1) e ON e.member_id = u.member_id AND e.module_id = u.module_id AND e.rk = 1   -- 合同 / 金额扩展，取最新
LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY member_id, module_id ORDER BY add_time DESC) AS rk FROM ods.ods_opr_module_used_log_df
           WHERE travel_date = '${bizdate}' AND type = 1 AND status = 2) lg ON lg.member_id = u.member_id AND lg.module_id = u.module_id AND lg.rk = 1   -- 最近一次已支付开通
LEFT JOIN ods.ods_opr_module_price_df pr ON pr.id = lg.price_id AND pr.travel_date = '${bizdate}'                     -- 开通时资费
LEFT JOIN dim.dim_sup_staff_df st ON st.staff_id = e.saleman                                                          -- 签单人
WHERE FROM_UNIXTIME(u.create_time, 'yyyyMMdd') = '${bizdate}'                                                        -- 当日新开通""")},
     notes=['金额在扩展表 details（JSON：receipt 实收 / agree 开票 / achievement_money 业绩 / real_money 终止实际消费，单位分），按 JSON 解析（旧系统按字符串截取）',
            '签单人部门原取 OA 人员表（OA 下线），改为平台员工组'])

proc('dwd_opr_package_open_di', '套餐开通明细', '1行=1次套餐开通 / 续费 / 升级（当日新增）',
     'ods_opr_module_package_log_df、ods_opr_module_package_log_ext_df、dim_opr_module_package_df、dim_sup_staff_df',
     '商户开通套餐：套餐、合作模式、开通类型、有效期、签单人 / 客服、是否回款、合同、实收 / 开票 / 业绩金额；替代旧 dwd_user_package_d_f',
     ['ods_opr_module_package_log_df'], [
         ('package_open_id', B, '主键', '套餐开通记录ID', 'id'),
         ('member_id', B, '外键', '开通商户ID', 'member_id'), ('package_id', B, '外键', '套餐ID', 'package_id'),
         ('package_name', S, '维度属性', '套餐名称', 'package_name'), ('package_role', I, '状态类型', '套餐适用角色：0-供应商 1-分销商', 'package_role'),
         ('package_price_amt', DEC, '度量', '套餐标价（元）', 'package_fee_amt'),
         ('upgrade_flag', I, '状态类型', '是否升级：0-否 1-是', 'is_update'),
         ('cooperation_mode', I, '状态类型', '合作模式：1-套餐 2-项目 3-订…', 'cooperation_mode'),
         ('open_type', I, '状态类型', '开通类型：1-新开通 2-未到期续费 …', 'open_type'),
         ('pay_back_flag', I, '状态类型', '是否回款：0-未回款 1-已回款', 'is_pay'),
         ('stop_type', I, '状态类型', '终止类型：1-作废 2-提前终止', 'stop_type'),
         ('valid_start_time', S, '时间', '开始时间', ts('begin_time')), ('valid_end_time', S, '时间', '结束时间', ts('end_time')),
         ('period_days', I, '维度属性', '周期天数 = 结束 − 开始', 'CAST(DATEDIFF(FROM_UNIXTIME(end_time), FROM_UNIXTIME(begin_time)) AS INT)'),
         ('stop_time', S, '时间', '终止时间（作废取 stop_time，否则取结束时间）',
          "FROM_UNIXTIME(CAST(GET_JSON_OBJECT(time_details, IF(stop_type = 1, '$.stop_time', '$.end_time')) AS BIGINT))"),
         ('open_time', S, '时间', '开通时间', ts('add_time')),
         ('contract_no', S, '外键', '合同编号', 'contract_no'), ('sign_time', S, '时间', '签约时间', "IF(sign_time > 0, FROM_UNIXTIME(sign_time), NULL)"),
         ('out_trade_no', S, '外键', '支付流水号', 'out_trade_no'),
         ('sale_man_id', B, '外键', '签单人员工ID', 'saleman'), ('sale_man_name', S, '维度属性', '签单人姓名', 'sale_name'),
         ('sale_man_group', S, '维度属性', '签单人员工组', 'sale_group'),
         ('customer_service_id', B, '外键', '客服员工ID', 'customer_service'), ('customer_service_name', S, '维度属性', '客服姓名', 'cs_name'),
         ('customer_service_group', S, '维度属性', '客服员工组', 'cs_group'),
         ('package_pay_amt', DEC, '度量', '实收金额（元）', _JSON('receipt')), ('package_invoice_amt', DEC, '度量', '开票（协议）金额（元）', _JSON('agree')),
         ('package_performance_amt', DEC, '度量', '业绩金额（元）', _JSON('achievement_money')),
         ('repayment_record', S, '维度属性', '回款记录', 'repayment_record'), ('remark', S, '维度属性', '备注', 'remarks'),
     ],
     frm={'ods_opr_module_package_log_df': q("""
SELECT l.*, x.stop_type, x.time_details, x.contract_no, x.sign_time, x.repayment_record, x.cooperation_mode, x.open_type,
       pk.package_name, pk.package_role, pk.package_fee_amt, s1.staff_name AS sale_name, s1.staff_group_name AS sale_group, s2.staff_name AS cs_name, s2.staff_group_name AS cs_group
FROM ods.ods_opr_module_package_log_df l
LEFT JOIN ods.ods_opr_module_package_log_ext_df x ON x.package_log_id = l.id AND x.travel_date = '${bizdate}'        -- 合同 / 合作模式扩展
LEFT JOIN (SELECT package_id, MAX(package_name) AS package_name, MAX(package_role) AS package_role, MAX(package_fee_amt) AS package_fee_amt
           FROM dim.dim_opr_module_package_df WHERE package_id > 0 GROUP BY package_id) pk ON pk.package_id = l.package_id
LEFT JOIN dim.dim_sup_staff_df s1 ON s1.staff_id = l.saleman                                                          -- 签单人
LEFT JOIN dim.dim_sup_staff_df s2 ON s2.staff_id = l.customer_service                                                 -- 客服
WHERE l.travel_date = '${bizdate}' AND FROM_UNIXTIME(l.add_time, 'yyyyMMdd') = '${bizdate}'                          -- 全量快照取当日开通""")},
     legacy=['dwd_user_package_d_f'],
     notes=['套餐状态（有效 / 到期）查询时按 valid_end_time 与统计日比较得到，不在明细落；客服部门原取 OA（下线），改为员工组'])

# ---------------------------------------------------------------- 资源中心订单（冗余属性按维表补齐）
proc('dwd_prd_resource_order_di', '资源中心订单明细', '1行=1张经资源中心采购商品产生的订单（当日下单，按唯一订单号去重）',
     'dwd_ord_order_di、ods_prd_resource_purchase_df、dwd_ord_order_distribution_di、dwd_trf_api_order_di、dim_prd_scenic_df、dim_prd_ticket_df、dim_sup_member_df、dim_trf_channel_f、dim_opr_region_f、ods_opr_resource_center_district_df',
     '资源中心订单 = 订单明细 ∩ 资源中心采购关系；景区 / 票 / 上架商 / 采购商 / 渠道 / 取票人地区名称按维表补齐，采购成本取分销链采购商一级买入价，失败原因取对接订单',
     ['dwd_ord_order_di'], [
         ('order_no', S, '主键', '订单号', 'order_no'), ('remote_order_no', S, '外键', '远端订单号', 'remote_order_no'),
         ('order_status', S, '状态类型', '订单状态', 'order_status'), ('ticket_qty', B, '度量', '票数', 'ticket_qty'),
         ('order_time', S, '时间', '下单时间', 'order_time'), ('verify_time', S, '时间', '首次核销时间', 'first_verify_time'),
         ('scenic_id', B, '外键', '景区ID', 'scenic_id'), ('scenic_name', S, '维度属性', '景区名称', 'scenic_name'),
         ('scenic_type_code', S, '状态类型', '产品类型编码', 'scenic_type_code'), ('scenic_type_name', S, '维度属性', '产品类型', 'scenic_type_name'),
         ('scenic_province_name', S, '维度属性', '景区所在省', 's_province'), ('scenic_city_name', S, '维度属性', '景区所在市', 's_city'),
         ('belong_area', S, '维度属性', '产品归属考核区域', 's_area'), ('scenic_topic', S, '维度属性', '景区主题', 'scenic_topic'),
         ('resource_land_id', B, '外键', '业态景区ID', 'resource_scenic_id'), ('resource_land_name', S, '维度属性', '业态景区名称', 'resource_scenic_name'),
         ('ticket_id', B, '外键', '票ID', 'ticket_id'), ('ticket_name', S, '维度属性', '票全称', 'ticket_full_name'),
         ('resource_id', B, '外键', '资源中心资源ID', 'resource_id'),
         ('distribute_system_code', S, '外键', '对接分销平台编码', 'distribute_system_code'), ('distribute_system_name', S, '维度属性', '对接分销平台名称', 'dsys_name'),
         ('booking_channel', I, '外键', '下单渠道', 'order_mode'), ('booking_channel_name', S, '维度属性', '下单渠道名称', 'channel_name'),
         ('booking_price', DEC, '度量', '下单单价（元）', 'ticket_price_amt'), ('booking_qty', B, '度量', '下单票数', 'origin_ticket_qty'),
         ('booking_pay_amt', DEC, '度量', '下单金额（元）= 下单票数 × 销售单价', 'CAST(origin_ticket_qty * sale_price_amt AS DECIMAL(18,2))'),
         ('order_pay_amt', DEC, '度量', '订单实付（元）', 'pay_amt'),
         ('cost_price', DEC, '度量', '结算单价（元）', 'cost_price_amt'), ('sale_price', DEC, '度量', '销售单价（元）', 'sale_price_amt'),
         ('resource_center_purchase_price', DEC, '度量', '采购商采购成本（元，分销链中采购商作为买方的一级买入价 × 票数）', 'purchase_cost_amt'),
         ('distributor_id', B, '外键', '一级分销商ID', 'distributor_id'), ('seller_id', B, '外键', '卖方ID', 'seller_id'), ('buyer_id', B, '外键', '买方ID', 'buyer_id'),
         ('ticket_taker_province', S, '维度属性', '取票人省', 'taker_province'), ('ticket_taker_city', S, '维度属性', '取票人市', 'taker_city'),
         ('fail_code', S, '状态类型', '对接下单失败处理码', 'fail_code'), ('fail_reason', S, '维度属性', '对接下单失败原因', 'fail_reason'),
         ('supplier_id', B, '外键', '资源中心上架商ID', 'rc_supplier_id'),
         ('resource_center_supplier_account', S, '维度属性', '上架商账号', 'ms_account'), ('resource_center_supplier_name', S, '维度属性', '上架商名称', 'ms_name'),
         ('resource_center_supplier_province', S, '维度属性', '上架商所在省', 'ms_province'), ('resource_center_supplier_city', S, '维度属性', '上架商所在市', 'ms_city'),
         ('resource_center_supplier_belong_area', S, '维度属性', '上架商考核区域', 'ms_area'),
         ('resource_center_supplier_is_test', I, '状态类型', '上架商是否测试账号', 'ms_test'),
         ('resource_center_supplier_type', S, '状态类型', '上架商账号类型', 'ms_type'),
         ('purchase_member_id', B, '外键', '资源中心采购商ID', 'rc_purchase_id'),
         ('resource_center_purchase_account', S, '维度属性', '采购商账号', 'mp_account'), ('resource_center_purchase_name', S, '维度属性', '采购商名称', 'mp_name'),
         ('resource_center_purchase_province', S, '维度属性', '采购商所在省', 'mp_province'), ('resource_center_purchase_city', S, '维度属性', '采购商所在市', 'mp_city'),
         ('resource_center_purchase_belong_area', S, '维度属性', '采购商考核区域', 'mp_area'),
         ('resource_center_purchase_is_test', I, '状态类型', '采购商是否测试账号', 'mp_test'),
         ('resource_center_purchase_type', S, '状态类型', '采购商账号类型', 'mp_type'),
         ('order_no_supplier', B, '维度属性', '上架商第几张资源中心订单（近 2 年）', 'seq_supplier'),
         ('order_no_purchase', B, '维度属性', '采购商第几张资源中心订单（近 2 年）', 'seq_purchase'),
         ('order_no_land', B, '维度属性', '景区第几张资源中心订单（近 2 年）', 'seq_land'),
     ],
     frm={'dwd_ord_order_di': q("""
SELECT o.*, s.scenic_name, s.scenic_type_code, s.scenic_type_name, s.province_name AS s_province, s.city_name AS s_city, s.belong_area AS s_area,
       s.scenic_topic, s.resource_scenic_id, s.resource_scenic_name, tk.ticket_full_name, cd.channel_name AS dsys_name, co.channel_name,
       rp.region_name AS taker_province, rc.region_name AS taker_city, api.fail_code, api.fail_reason, dist.purchase_cost_amt,
       ms.account AS ms_account, ms.member_name AS ms_name, ms.province_name AS ms_province, ms.city_name AS ms_city, ds.district AS ms_area,
       ms.test_flag AS ms_test, ms.member_type_code AS ms_type,
       mp.account AS mp_account, mp.member_name AS mp_name, mp.province_name AS mp_province, mp.city_name AS mp_city, dp.district AS mp_area,
       mp.test_flag AS mp_test, mp.member_type_code AS mp_type
FROM (
    SELECT a.*,
           ROW_NUMBER() OVER (PARTITION BY a.rc_supplier_id ORDER BY a.order_time) AS seq_supplier,   -- 近 2 年内序号（同旧口径）
           ROW_NUMBER() OVER (PARTITION BY a.rc_purchase_id ORDER BY a.order_time) AS seq_purchase,
           ROW_NUMBER() OVER (PARTITION BY a.scenic_id ORDER BY a.order_time) AS seq_land
    FROM (
        SELECT /*+ BROADCAST(p) */ o.*, p.sid AS rc_supplier_id, p.fid AS rc_purchase_id,
               ROW_NUMBER() OVER (PARTITION BY COALESCE(NULLIF(o.remote_order_no, ''), o.order_no) ORDER BY o.travel_date DESC) AS rn_one   -- OTA 重试：远端单号唯一
        FROM dwd.dwd_ord_order_di o
        JOIN (SELECT DISTINCT CAST(sid AS BIGINT) AS sid, CAST(fid AS BIGINT) AS fid, CAST(ticket_id AS BIGINT) AS ticket_id
              FROM ods.ods_prd_resource_purchase_df WHERE travel_date = '${bizdate}') p
          ON p.ticket_id = o.ticket_id AND p.fid = o.buyer_id                     -- 采购商用资源中心采购的票下单
        WHERE o.travel_date >= DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 732), 'yyyyMMdd') AND o.test_flag = 0 AND o.pay_status <> '2'
    ) a
    WHERE a.rn_one = 1
) o
LEFT JOIN dim.dim_prd_scenic_df s ON s.scenic_id = o.scenic_id
LEFT JOIN dim.dim_prd_ticket_df tk ON tk.ticket_id = o.ticket_id
LEFT JOIN dim.dim_trf_channel_f co ON co.channel_type = 'ORDER_CHANNEL' AND co.channel_code = CAST(o.order_mode AS STRING)
LEFT JOIN dim.dim_trf_channel_f cd ON cd.channel_type = 'DISTRIBUTE_SYSTEM' AND cd.channel_code = o.distribute_system_code
LEFT JOIN dim.dim_opr_region_f rp ON rp.region_code = o.taker_province_code
LEFT JOIN dim.dim_opr_region_f rc ON rc.region_code = o.taker_city_code
LEFT JOIN dim.dim_sup_member_df ms ON ms.member_id = o.rc_supplier_id
LEFT JOIN dim.dim_sup_member_df mp ON mp.member_id = o.rc_purchase_id
LEFT JOIN ods.ods_opr_resource_center_district_df ds ON ds.province = ms.province_name AND ds.travel_date = '${bizdate}'
LEFT JOIN ods.ods_opr_resource_center_district_df dp ON dp.province = mp.province_name AND dp.travel_date = '${bizdate}'
LEFT JOIN (SELECT order_no, MAX(CAST(handle_status AS STRING)) AS fail_code, MAX(error_msg) AS fail_reason FROM dwd.dwd_trf_api_order_di
           WHERE travel_date = '${bizdate}' AND fail_flag = 1 GROUP BY order_no) api ON api.order_no = o.order_no
LEFT JOIN (SELECT order_no, buyer_id, SUM(price_amt * ticket_qty) AS purchase_cost_amt FROM dwd.dwd_ord_order_distribution_di
           WHERE travel_date = '${bizdate}' GROUP BY order_no, buyer_id) dist ON dist.order_no = o.order_no AND dist.buyer_id = o.rc_purchase_id
WHERE o.travel_date = '${bizdate}'                                                -- 序号在近 2 年上算好后，只落当日下单""")},
     notes=['唯一订单：OTA 下单失败会重试，按 远端单号（无则平台单号）去重；上架商 / 采购商 / 景区的第几单在近 2 年订单上编号（同旧口径）',
            '名称、地区、类型等属性按维表关联补齐（旧系统同样来自用户 / 景区维表）'])

# ---------------------------------------------------------------- 零售：落到商品行
_RET_COLS = [
    ('retail_vendor', S, '主键', '零售系统：yinbao-银豹 / sixun-思迅 / xisland-小岛', ("'yinbao'", "'sixun'", "'xisland'", "'xisland'")),
    ('item_id', B, '主键', '商品行记录ID（与零售系统、退货标志联合唯一）', ('id', 'id', 'id', 'id')),
    ('order_no', S, '外键', '零售单据号', ('sn', 'order_no', 'order_code', 'order_code')),
    ('refund_no', S, '外键', '退款单号（退货行）', (NUL[S], NUL[S], NUL[S], 'refund_code')),
    ('member_id', B, '外键', '供应商ID（零售系统绑定的商户）', ('member_id', 'member_id', 'member_id', 'member_id')),
    ('con_sys_bind', B, '外键', '对接系统绑定ID', ('con_sys_bind', 'con_sys_bind', 'con_sys_bind', 'con_sys_bind')),
    ('shop_code', S, '外键', '门店编码 / 名称', ('CAST(app_id AS STRING)', 'shop_code', 'store_name', 'store_name')),
    ('shop_category', S, '维度属性', '门店分类（思迅门店表；其余系统为业务类型）', ('business_category', 'shop_category', 'business_type', 'business_type')),
    ('goods_code', S, '外键', '商品编码（银豹商品 UID / 条码；思迅、小岛按商品名称）', ('COALESCE(product_barcode, CAST(product_uid AS STRING))', 'product_name', 'product_name', 'product_name')),
    ('goods_name', S, '维度属性', '商品名称', ('name', 'product_name', 'product_name', 'product_name')),
    ('goods_category', S, '维度属性', '商品分类', (NUL[S], NUL[S], 'class_name', 'class_name')),
    ('refund_flag', I, '状态类型', '是否退货：1-退货 / 退款行', ("IF(ticket_type = 'SELL_RETURN', 1, 0)", "IF(order_status = '2', 1, 0)", '0', '1')),
    ('invalid_flag', I, '状态类型', '单据是否作废（银豹）', ('CAST(invalid AS INT)', '0', '0', '0')),
    ('item_qty', DEC, '度量', '数量', ('CAST(quantity AS DECIMAL(18,2))', 'CAST(sale_num AS DECIMAL(18,2))', 'CAST(quantity AS DECIMAL(18,2))', 'CAST(quantity AS DECIMAL(18,2))')),
    ('unit_price', DEC, '度量', '单价（元）', ('CAST(sell_price AS DECIMAL(18,2))', NUL[DEC], 'CAST(unit_price AS DECIMAL(18,2))', 'CAST(unit_price AS DECIMAL(18,2))')),
    ('sale_amt', DEC, '度量', '应收金额（元；退货行为退款金额）',
     ('CAST(sell_price * quantity AS DECIMAL(18,2))', 'CAST(sale_money AS DECIMAL(18,2))', 'CAST(amount AS DECIMAL(18,2))', 'CAST(refund_amount AS DECIMAL(18,2))')),
    ('pay_amt', DEC, '度量', '实付金额（元；思迅按单头实付按金额比例分摊到行）',
     ('CAST(total_amount AS DECIMAL(18,2))', 'CAST(sale_money * h_pay / NULLIF(h_sale, 0) AS DECIMAL(18,2))', 'CAST(pay_amount AS DECIMAL(18,2))', 'CAST(refund_amount AS DECIMAL(18,2))')),
    ('discount_amt', DEC, '度量', '优惠金额（元）',
     ('CAST(sell_price * quantity - total_amount AS DECIMAL(18,2))', 'CAST(sale_money - sale_money * h_pay / NULLIF(h_sale, 0) AS DECIMAL(18,2))', 'CAST(discount_amount AS DECIMAL(18,2))', 'CAST(0 AS DECIMAL(18,2))')),
    ('profit_amt', DEC, '度量', '利润（元，仅银豹提供）', ('CAST(total_profit AS DECIMAL(18,2))', NUL[DEC], NUL[DEC], NUL[DEC])),
    ('number_of_people', B, '度量', '消费人数（单头值，只记在每单第一行）', ('h_people', 'h_people', '0', '0')),
    ('operator', S, '维度属性', '收银 / 操作人', ('cashier', 'operator', 'create_name', 'create_name')),
    ('order_time', S, '时间', '单据时间', ('date_time', 'sale_time', 'order_create_time', 'refund_create_time')),
]
proc('dwd_opr_retail_order_di', '零售订单商品明细', '1行=1个零售单据商品行（含退货 / 退款行）',
     'ods_opr_retail_yinbao_ticket_item_di、ods_opr_retail_yinbao_ticket_di、ods_opr_retail_sixun_order_sale_detail_di、ods_opr_retail_sixun_order_di、ods_opr_retail_sixun_shop_df、'
     'ods_opr_retail_xisland_order_item_di、ods_opr_retail_xisland_order_di、ods_opr_retail_xisland_refund_order_item_di、ods_opr_retail_xisland_refund_order_di',
     '银豹 / 思迅 / 小岛三套零售系统的商品行（销售与退货）归一：门店、商品、数量、应收、实付、优惠、利润；单头的人数只记一次',
     ['ods_opr_retail_yinbao_ticket_item_di', 'ods_opr_retail_sixun_order_sale_detail_di', 'ods_opr_retail_xisland_order_item_di', 'ods_opr_retail_xisland_refund_order_item_di'],
     _RET_COLS,
     frm={'ods_opr_retail_yinbao_ticket_item_di': q("""
SELECT i.*, h.app_id, h.ticket_type, h.date_time, h.invalid, h.cashier, '' AS business_category,
       IF(ROW_NUMBER() OVER (PARTITION BY i.uid ORDER BY i.id) = 1, CAST(GET_JSON_OBJECT(h.ticket_spend_detail, '$.peopleNum') AS BIGINT), 0) AS h_people   -- 人数只记首行
FROM ods.ods_opr_retail_yinbao_ticket_item_di i
JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY uid ORDER BY sys_update_time DESC) AS rn FROM ods.ods_opr_retail_yinbao_ticket_di WHERE travel_date = '${bizdate}') h
  ON h.uid = i.uid AND h.rn = 1                                                   -- 单头：类型 / 时间 / 门店
WHERE i.travel_date = '${bizdate}'"""),
          'ods_opr_retail_sixun_order_sale_detail_di': q("""
SELECT d.*, h.status AS order_status, h.payment_money AS h_pay, h.sale_money AS h_sale, sh.shop_category,
       IF(ROW_NUMBER() OVER (PARTITION BY d.order_no ORDER BY d.seq_no) = 1, h.number_of_people, 0) AS h_people
FROM ods.ods_opr_retail_sixun_order_sale_detail_di d
LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_no ORDER BY sync_update_time DESC) AS rn FROM ods.ods_opr_retail_sixun_order_di WHERE travel_date = '${bizdate}') h
  ON h.order_no = d.order_no AND h.rn = 1                                         -- 单头：状态 / 实付 / 人数
LEFT JOIN (SELECT shop_code, MAX(shop_category) AS shop_category FROM ods.ods_opr_retail_sixun_shop_df WHERE travel_date = '${bizdate}' GROUP BY shop_code) sh
  ON sh.shop_code = d.shop_code                                                   -- 门店分类
WHERE d.travel_date = '${bizdate}'"""),
          'ods_opr_retail_xisland_order_item_di': q("""
SELECT i.*, h.store_name, h.business_type, h.create_name
FROM ods.ods_opr_retail_xisland_order_item_di i
LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_code ORDER BY sync_update_time DESC) AS rn FROM ods.ods_opr_retail_xisland_order_di WHERE travel_date = '${bizdate}') h
  ON h.order_code = i.order_code AND h.rn = 1
WHERE i.travel_date = '${bizdate}'"""),
          'ods_opr_retail_xisland_refund_order_item_di': q("""
SELECT i.*, h.store_name, h.business_type, h.create_name
FROM ods.ods_opr_retail_xisland_refund_order_item_di i
LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY refund_code ORDER BY sync_update_time DESC) AS rn FROM ods.ods_opr_retail_xisland_refund_order_di WHERE travel_date = '${bizdate}') h
  ON h.refund_code = i.refund_code AND h.rn = 1
WHERE i.travel_date = '${bizdate}' AND h.refund_status <> 2                       -- 剔除退款失败""")},
     notes=['原表只到单头（件数、商品为空），改为商品行；银豹人数取单头就餐人数报文，思迅取单头人数，均只记在每单第一行，按行求和不重复',
            '思迅商品行没有实付，按单头 实付 / 应收 比例分摊；待确认：银豹就餐人数报文的键名（peopleNum）上线前核对'])

# ---------------------------------------------------------------- CRM 客户公司（纷享销客客户）
proc('dim_sup_company_df', 'CRM 客户公司维度', '1行=1个 CRM 客户公司（纷享销客客户，未删除）', 'ods_sup_crm_account_df、ods_opr_crm_home_area_df',
     '签约客户主体：编号、名称、对应平台账号、分类 / 级别 / 合作属性、行业、景区类型与等级、所在地、负责人与归属区域团队、成交与跟进状态；'
     '平台账号维度的客户属性宽表见 ads_sup_customer_company_df',
     ['ods_sup_crm_account_df'], [
         ('company_id', B, '主键', 'CRM 客户ID', 'id'), ('company_no', S, '业务主键', 'CRM 客户编号', 'account_no'),
         ('company_name', S, '维度属性', '客户名称', 'name'),
         ('platform_account', S, '维度属性', '平台账号 / ID / 手机（CRM 录入原文）', 'field_0w21l__c'),
         ('member_id', B, '外键', '平台账号ID（平台账号原文为纯数字时），关联 dim_sup_member_df', "IF(field_0w21l__c RLIKE '^[0-9]{3,10}$', CAST(field_0w21l__c AS BIGINT), NULL)"),
         ('account_type', S, '状态类型', '客户分类', 'account_type'), ('account_level', S, '状态类型', '客户类型（合作客户等级）', 'account_level'),
         ('customer_attribute', S, '维度属性', '客户属性', 'field_41liw__c'), ('cooperation_attribute', S, '维度属性', '合作属性', 'field_mvq72__c'),
         ('record_type', S, '状态类型', '业务类型', 'record_type'), ('account_source', S, '维度属性', '客户来源', 'account_source'),
         ('industry_level1', S, '维度属性', '一级行业', 'industry_level1'), ('industry_level2', S, '维度属性', '二级行业', 'industry_level2'),
         ('main_category', S, '维度属性', '主营类目', 'field_nz4yo__c'), ('scenic_type', S, '维度属性', '景区类型', 'field_4h84y__c'),
         ('scenic_level', S, '维度属性', '景区等级', 'field_0ut89__c'), ('travel_agency_type', S, '维度属性', '旅行社类型', 'field_5q3iq__c'),
         ('country_name', S, '维度属性', '国家', 'country__r'), ('province_code', S, '外键', '省编码', 'province'), ('province_name', S, '维度属性', '省', 'province__r'),
         ('city_code', S, '外键', '市编码', 'city'), ('city_name', S, '维度属性', '市', 'city__r'), ('district_name', S, '维度属性', '区县', 'district__r'),
         ('owner_name', S, '维度属性', '负责人', 'owner__r'), ('owner_department', S, '维度属性', '负责人主属部门', 'owner_department'),
         ('home_area_group', S, '维度属性', '归属区域组（按负责人部门）', 'home_area_group'), ('lv1_team', S, '维度属性', '一级团队', 'lv1_team'),
         ('lv2_team', S, '维度属性', '二级团队', 'lv2_team'), ('lv3_team', S, '维度属性', '三级团队', 'lv3_team'),
         ('deal_status', S, '状态类型', '成交状态', 'deal_status'), ('life_status', S, '状态类型', '生命状态', 'life_status'), ('biz_status', S, '状态类型', '分配状态', 'biz_status'),
         ('first_deal_date', S, '时间', '首签成单日期', 'field_tkx02__c'), ('last_deal_time', S, '时间', '最后一次成交时间', 'last_deal_closed_time'),
         ('last_deal_amt', DEC, '度量', '最后一次成交金额（元）', 'CAST(last_deal_closed_amount AS DECIMAL(18,2))'),
         ('last_followed_time', S, '时间', '最后跟进时间', 'last_followed_time'), ('high_seas_name', S, '维度属性', '所属公海', 'high_seas_name'),
         ('credit_code', S, '维度属性', '统一社会信用代码', 'uniform_social_credit_code'),
         ('create_time', S, '时间', '创建时间', 'create_time'), ('last_modified_time', S, '时间', '最后修改时间', 'last_modified_time'),
     ], part='', legacy=['dim_crm_home_area_d_f', 'dws_cus_pft_crm_account_d_f'],
     frm={'ods_sup_crm_account_df': q("""
SELECT a.*, h.home_area_group, h.lv1_team, h.lv2_team, h.lv3_team
FROM ods.ods_sup_crm_account_df a
LEFT JOIN (SELECT department, MAX(home_area_group) AS home_area_group, MAX(lv1_team) AS lv1_team, MAX(lv2_team) AS lv2_team, MAX(lv3_team) AS lv3_team
           FROM ods.ods_opr_crm_home_area_df WHERE travel_date = '${bizdate}' GROUP BY department) h ON h.department = a.owner_department   -- 部门 → 归属区域 / 团队
WHERE a.travel_date = '${bizdate}' AND COALESCE(a.is_deleted, 0) = 0""")},
     notes=['原表把平台账号级的客户属性宽表（套餐 / 登录 / 合作伙伴 / 产品 / 应用开通）挂在本维度，按粒度拆开：本表只放 CRM 客户公司属性，宽表移到 ads_sup_customer_company_df',
            'CRM 表 174 列中自定义备用列（option1~ 等）与联系人电话 / 地址（个人信息）不进维度'])


# ---------------------------------------------------------------- 账号标签（旧 SQL 硬编码的新媒体 / OTA 账号清单）
_TAG = json.loads((pathlib.Path(__file__).with_name('account_tags.json')).read_text(encoding='utf-8'))
_TV = ',\n'.join(f"       ({a}, '{b}', '{c}', '{d}')" for a, b, c, d in _TAG)
proc('dim_trf_account_tag_f', '分销账号标签', '1行=1个平台账号×1个标签', '配置（旧 channel_aids SQL 硬编码的账号清单，迁入 dataworks/standard/account_tags.json）',
     '按固定账号识别的渠道：新媒体（抖音 / 快手 / 抖店 …）与各 OTA 平台；订单买方或卖方是这些账号即打标签；新增账号改 json 后重跑',
     ['account_tags'], [
         ('member_id', B, '主键', '平台账号ID', 'member_id'), ('tag_group', S, '状态类型', '标签组：NEW_MEDIA-新媒体 / OTA', 'tag_group'),
         ('tag_code', S, '主键', '标签编码', 'tag_code'), ('tag_name', S, '维度属性', '标签名称', 'tag_name'),
     ], part='',
     frm={'account_tags': "(\n        SELECT * FROM VALUES\n" + _TV + "\n        AS v(member_id, tag_group, tag_code, tag_name)\n    ) t"},
     notes=[f'共 {len(_TAG)} 个账号；名称按旧字段缩写整理（dylk、ksbdsh、mtqq 等缩写含义待业务核对）'])
