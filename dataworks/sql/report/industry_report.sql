-- ================================================================================================
-- 景区票务行业报告取数（基于标准化数仓 ADS + 时间表）
-- 取数方案与口径说明见 dataworks/docs/行业报告取数方案.md
--
-- 参数（DataWorks 节点参数，yyyyMMdd）：
--   report_code   报告编码，如 2026_national_day / 2026_h1
--   report_start  报告期开始日        report_end  报告期结束日
--   base_start    对比期开始日        base_end    对比期结束日
--   节假日报告：报告期 = dim_opr_holiday_period_f 本年区间，对比期 = last_year_period_code 对应的去年同一假期（天数可能不同，比较日均）
--   常规期间：对比期 = 去年公历同期（dim_opr_period_f.ly_start_date_no / ly_end_date_no）
--
-- 输出：ads.ads_opr_industry_report_metric（报告指标竖表），一行 = 报告 × 章节 × 指标 × 维度值，含本期 / 对比期 / 同比 / 样本量 / 是否抑制
-- 所有数据只取聚合结果；景区明细不出报告（榜单仅出类型 / 地区，或经景区授权后实名）
-- ================================================================================================

CREATE TABLE IF NOT EXISTS ads.ads_opr_industry_report_metric (
    section_code        STRING          COMMENT '章节：S1 市场总览 / S2 供给 / S3 客群 / S4 预订行为 / S5 渠道 / S6 履约与客流 / S7 价格 / S8 区域',
    metric_code         STRING          COMMENT '指标编码',
    metric_name         STRING          COMMENT '指标名称',
    dim_type            STRING          COMMENT '维度类型：ALL / scenic_type / scenic_level / province / age_group / channel …',
    dim_value           STRING          COMMENT '维度值（已转中文名称）',
    sample_type         STRING          COMMENT '样本：ALL-全部景区 / COMPARABLE-可比景区（两期都有交易）',
    cur_value           DECIMAL(24,4)   COMMENT '本期值',
    base_value          DECIMAL(24,4)   COMMENT '对比期值',
    yoy_rate            DECIMAL(20,6)   COMMENT '同比（%）= (本期 − 对比期) / 对比期 × 100；占比类指标为百分点差',
    sample_scenic_qty   BIGINT          COMMENT '该格子的景区样本数',
    suppress_flag       INT             COMMENT '是否抑制：1-样本不足（景区 < 5 或 游客 < 1000），报告中不展示',
    etl_time            STRING          COMMENT 'ETL 加载时间'
) COMMENT '行业报告指标竖表'
PARTITIONED BY (report_code STRING COMMENT '报告编码')
STORED AS ORC;

-- ------------------------------------------------------------------------------------------------
-- 0. 样本景区：正式景区 + 两期交易情况；可比景区 = 两期都有预订（剔除平台新接入 / 流失带来的增长假象）
-- ------------------------------------------------------------------------------------------------
CREATE OR REPLACE TEMPORARY VIEW rpt_scenic AS
WITH cur AS (
    SELECT scenic_id, SUM(order_ticket_qty) AS ticket_qty, MAX(order_ticket_qty) AS max_day_ticket
    FROM (SELECT scenic_id, travel_date, SUM(order_ticket_qty) AS order_ticket_qty
          FROM ads.ads_ord_scenic_trade_overview_di
          WHERE travel_date BETWEEN '${report_start}' AND '${report_end}'
          GROUP BY scenic_id, travel_date) d
    GROUP BY scenic_id
),
base AS (
    SELECT scenic_id, SUM(order_ticket_qty) AS ticket_qty
    FROM ads.ads_ord_scenic_trade_overview_di
    WHERE travel_date BETWEEN '${base_start}' AND '${base_end}'
    GROUP BY scenic_id
),
hist AS (   -- 近 90 日日均：识别冲量 / 异常大单
    SELECT scenic_id, SUM(order_ticket_qty) / 90 AS avg_day_ticket
    FROM ads.ads_ord_scenic_trade_overview_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${report_start}', 'yyyyMMdd'), 90), 'yyyyMMdd')
                          AND DATE_FORMAT(DATE_SUB(TO_DATE('${report_start}', 'yyyyMMdd'), 1), 'yyyyMMdd')
    GROUP BY scenic_id
)
SELECT
    s.scenic_id, s.scenic_type_code, s.scenic_type_name, s.scenic_level, s.scenic_topic, s.province_code, s.province_name, s.city_code, s.city_name,
    s.reception_capacity_qty,
    COALESCE(c.ticket_qty, 0)                                        AS cur_ticket_qty,
    COALESCE(b.ticket_qty, 0)                                        AS base_ticket_qty,
    IF(c.ticket_qty > 0 AND b.ticket_qty > 0, 1, 0)                  AS comparable_flag,
    -- 异常：报告期单日票数 > 近 90 日日均 × 20 且 > 5000 张，人工核查后决定是否剔除
    IF(c.max_day_ticket > GREATEST(COALESCE(h.avg_day_ticket, 0) * 20, 5000), 1, 0) AS outlier_flag
FROM dim.dim_prd_scenic_df s
LEFT JOIN cur c  ON c.scenic_id = s.scenic_id
LEFT JOIN base b ON b.scenic_id = s.scenic_id
LEFT JOIN hist h ON h.scenic_id = s.scenic_id
WHERE s.test_flag = 0
  AND (c.ticket_qty > 0 OR b.ticket_qty > 0);

-- 报告期 / 对比期逐日交易（已剔除测试、异常；sample_type 两套口径同时出）
CREATE OR REPLACE TEMPORARY VIEW rpt_trade AS
SELECT
    IF(t.travel_date BETWEEN '${report_start}' AND '${report_end}', 'CUR', 'BASE') AS period,
    t.travel_date, t.scenic_id, t.ticket_id, t.order_mode, t.distributor_id, t.order_role,
    s.scenic_type_name, s.scenic_level, s.province_name, s.city_name, s.comparable_flag,
    t.order_order_qty, t.order_ticket_qty, t.order_sale_amt, t.cancel_ticket_qty, t.verify_ticket_qty, t.enter_qty, t.buyer_bitmap
FROM ads.ads_ord_scenic_trade_overview_di t
JOIN rpt_scenic s ON s.scenic_id = t.scenic_id AND s.outlier_flag = 0
WHERE (t.travel_date BETWEEN '${report_start}' AND '${report_end}') OR (t.travel_date BETWEEN '${base_start}' AND '${base_end}');

-- 景区份额（集中度用）：只在聚合里用排名，不输出景区
CREATE OR REPLACE TEMPORARY VIEW sc_share AS
SELECT scenic_id, cur_share, base_share,
       ROW_NUMBER() OVER (ORDER BY cur_share DESC)  AS cur_rk,
       ROW_NUMBER() OVER (ORDER BY base_share DESC) AS base_rk
FROM (
    SELECT scenic_id,
           SUM(IF(period = 'CUR', order_ticket_qty, 0)) / SUM(SUM(IF(period = 'CUR', order_ticket_qty, 0))) OVER ()   AS cur_share,
           SUM(IF(period = 'BASE', order_ticket_qty, 0)) / SUM(SUM(IF(period = 'BASE', order_ticket_qty, 0))) OVER () AS base_share
    FROM rpt_trade
    GROUP BY scenic_id
) t;

-- 景区日峰值在园 / 最大接待能力：小时级在园先按景区合并闸机组，再取当日最大值
CREATE OR REPLACE TEMPORARY VIEW flow_day AS
SELECT IF(h.travel_date BETWEEN '${report_start}' AND '${report_end}', 'CUR', 'BASE') AS period, h.scenic_id, h.travel_date,
       MAX(h.in_park_qty) * 100 / MAX(s.reception_capacity_qty) AS day_rate
FROM (SELECT scenic_id, travel_date, stat_hour, SUM(in_park_qty) AS in_park_qty
      FROM dws.dws_trf_scenic_inout_hrs
      WHERE (travel_date BETWEEN '${report_start}' AND '${report_end}') OR (travel_date BETWEEN '${base_start}' AND '${base_end}')
      GROUP BY scenic_id, travel_date, stat_hour) h
JOIN rpt_scenic s ON s.scenic_id = h.scenic_id AND s.reception_capacity_qty > 0     -- 只统计填了最大接待能力的景区
GROUP BY 1, h.scenic_id, h.travel_date;

CREATE OR REPLACE TEMPORARY VIEW flow_peak AS
SELECT period, scenic_id, MAX(day_rate) AS peak_rate FROM flow_day GROUP BY period, scenic_id;

-- ------------------------------------------------------------------------------------------------
-- 1~8 章指标 → 竖表
-- ------------------------------------------------------------------------------------------------
INSERT OVERWRITE TABLE ads.ads_opr_industry_report_metric PARTITION (report_code = '${report_code}')
SELECT
    section_code, metric_code, metric_name, dim_type, dim_value, sample_type,
    cur_value, base_value,
    CASE WHEN metric_code LIKE '%_share' OR metric_code LIKE '%_rate' THEN cur_value - base_value          -- 占比 / 比率：百分点差
         ELSE CAST((cur_value - base_value) * 100 / NULLIF(base_value, 0) AS DECIMAL(20,6)) END AS yoy_rate,
    sample_scenic_qty,
    IF(sample_scenic_qty < 5, 1, 0)                                  AS suppress_flag,
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss')          AS etl_time
FROM (
    -- S1 市场总览：全部景区 / 可比景区 两套口径
    SELECT 'S1' AS section_code, m.metric_code, m.metric_name, 'ALL' AS dim_type, '全部' AS dim_value, x.sample_type,
           CASE m.metric_code WHEN 'ticket_qty' THEN x.cur_ticket WHEN 'sale_amt' THEN x.cur_amt WHEN 'order_qty' THEN x.cur_order
                              WHEN 'buyer_qty' THEN x.cur_buyer WHEN 'avg_price' THEN x.cur_amt / NULLIF(x.cur_ticket, 0)
                              WHEN 'cancel_rate' THEN x.cur_cancel * 100 / NULLIF(x.cur_ticket, 0) WHEN 'verify_rate' THEN x.cur_verify * 100 / NULLIF(x.cur_ticket, 0)
                              WHEN 'day_avg_ticket_qty' THEN x.cur_ticket / x.cur_days END AS cur_value,
           CASE m.metric_code WHEN 'ticket_qty' THEN x.base_ticket WHEN 'sale_amt' THEN x.base_amt WHEN 'order_qty' THEN x.base_order
                              WHEN 'buyer_qty' THEN x.base_buyer WHEN 'avg_price' THEN x.base_amt / NULLIF(x.base_ticket, 0)
                              WHEN 'cancel_rate' THEN x.base_cancel * 100 / NULLIF(x.base_ticket, 0) WHEN 'verify_rate' THEN x.base_verify * 100 / NULLIF(x.base_ticket, 0)
                              WHEN 'day_avg_ticket_qty' THEN x.base_ticket / x.base_days END AS base_value,
           x.scenic_qty AS sample_scenic_qty
    FROM (
        SELECT sample_type,
               SUM(IF(period = 'CUR', order_ticket_qty, 0))  AS cur_ticket,  SUM(IF(period = 'BASE', order_ticket_qty, 0))  AS base_ticket,
               SUM(IF(period = 'CUR', order_sale_amt, 0))    AS cur_amt,     SUM(IF(period = 'BASE', order_sale_amt, 0))    AS base_amt,
               SUM(IF(period = 'CUR', order_order_qty, 0))   AS cur_order,   SUM(IF(period = 'BASE', order_order_qty, 0))   AS base_order,
               SUM(IF(period = 'CUR', cancel_ticket_qty, 0)) AS cur_cancel,  SUM(IF(period = 'BASE', cancel_ticket_qty, 0)) AS base_cancel,
               SUM(IF(period = 'CUR', verify_ticket_qty, 0)) AS cur_verify,  SUM(IF(period = 'BASE', verify_ticket_qty, 0)) AS base_verify,
               BITMAP_COUNT(BITMAP_UNION(IF(period = 'CUR', buyer_bitmap, NULL)))  AS cur_buyer,     -- 区间去重：位图合并后计数，不能日值相加
               BITMAP_COUNT(BITMAP_UNION(IF(period = 'BASE', buyer_bitmap, NULL))) AS base_buyer,
               DATEDIFF(TO_DATE('${report_end}', 'yyyyMMdd'), TO_DATE('${report_start}', 'yyyyMMdd')) + 1 AS cur_days,
               DATEDIFF(TO_DATE('${base_end}', 'yyyyMMdd'), TO_DATE('${base_start}', 'yyyyMMdd')) + 1   AS base_days,
               COUNT(DISTINCT IF(period = 'CUR', scenic_id, NULL)) AS scenic_qty
        FROM (SELECT t.*, 'ALL' AS sample_type FROM rpt_trade t
              UNION ALL
              SELECT t.*, 'COMPARABLE' FROM rpt_trade t WHERE comparable_flag = 1) u
        GROUP BY sample_type
    ) x
    CROSS JOIN (SELECT * FROM VALUES ('ticket_qty', '预订票数（张）'), ('sale_amt', '预订金额（元）'), ('order_qty', '预订订单数（单）'), ('buyer_qty', '购票人数（人，去重）'),
                                     ('avg_price', '票均价（元）'), ('cancel_rate', '退票率（%）'), ('verify_rate', '核销率（%）'), ('day_avg_ticket_qty', '日均预订票数（张）')
                AS v(metric_code, metric_name)) m

    UNION ALL
    -- S2 供给结构：景区类型 / 等级 / 省份的票数占比（可比口径看增长，全部口径看规模）
    SELECT 'S2', 'ticket_share', '预订票数占比（%）', d.dim_type, d.dim_value, 'ALL',
           d.cur_ticket * 100 / NULLIF(SUM(d.cur_ticket) OVER (PARTITION BY d.dim_type), 0),
           d.base_ticket * 100 / NULLIF(SUM(d.base_ticket) OVER (PARTITION BY d.dim_type), 0),
           d.scenic_qty
    FROM (
        SELECT dim_type, dim_value,
               SUM(IF(period = 'CUR', order_ticket_qty, 0)) AS cur_ticket, SUM(IF(period = 'BASE', order_ticket_qty, 0)) AS base_ticket,
               COUNT(DISTINCT IF(period = 'CUR', scenic_id, NULL)) AS scenic_qty
        FROM rpt_trade
        LATERAL VIEW STACK(3, 'scenic_type', COALESCE(scenic_type_name, '未知'), 'scenic_level', COALESCE(scenic_level, '未评级'),
                              'province', COALESCE(province_name, '未知')) dv AS dim_type, dim_value
        GROUP BY dim_type, dim_value
    ) d

    UNION ALL
    -- S2 集中度：CR10（头部 10 家景区票数占比）、HHI（Σ份额² × 10000）；只出数值，不出景区名
    SELECT 'S2', c.metric_code, c.metric_name, 'ALL', '全部', 'ALL', c.cur_value, c.base_value, c.scenic_qty
    FROM (
        SELECT 'cr10_share' AS metric_code, '头部 10 景区份额 CR10（%）' AS metric_name,
               SUM(IF(cur_rk <= 10, cur_share, 0)) * 100 AS cur_value, SUM(IF(base_rk <= 10, base_share, 0)) * 100 AS base_value, COUNT(1) AS scenic_qty
        FROM sc_share
        UNION ALL
        SELECT 'hhi', '市场集中度 HHI', SUM(cur_share * cur_share) * 10000, SUM(base_share * base_share) * 10000, COUNT(1)
        FROM sc_share
    ) c

    UNION ALL
    -- S3 客群：客源地距离（本市 / 省内 / 跨省）、年龄段、性别、同行人数段；按核销（实际到访）游客
    SELECT 'S3', 'traveler_share', '到访游客占比（%）', p.dim_type, p.dim_value, 'ALL',
           p.cur_qty * 100 / NULLIF(SUM(p.cur_qty) OVER (PARTITION BY p.dim_type), 0),
           p.base_qty * 100 / NULLIF(SUM(p.base_qty) OVER (PARTITION BY p.dim_type), 0),
           p.scenic_qty
    FROM (
        SELECT dim_type, dim_value,
               SUM(IF(period = 'CUR', traveler_qty, 0)) AS cur_qty, SUM(IF(period = 'BASE', traveler_qty, 0)) AS base_qty,
               COUNT(DISTINCT IF(period = 'CUR', scenic_id, NULL)) AS scenic_qty
        FROM (
            SELECT IF(f.travel_date BETWEEN '${report_start}' AND '${report_end}', 'CUR', 'BASE') AS period, f.scenic_id, f.traveler_qty,
                   CASE WHEN f.city_code IS NULL THEN '未知' WHEN f.city_code = s.city_code THEN '本市' WHEN f.province_code = s.province_code THEN '省内跨市' ELSE '跨省' END AS distance_group,
                   f.age_group, CASE f.gender WHEN 'M' THEN '男' WHEN 'F' THEN '女' ELSE '未知' END AS gender_name, f.fellow_group,
                   IF(f.team_type = 'TEAM', '团队', '散客') AS team_name
            FROM ads.ads_cus_scenic_traveler_profile_di f
            JOIN rpt_scenic s ON s.scenic_id = f.scenic_id AND s.outlier_flag = 0
            WHERE f.behavior_type = 'VERIFY'
              AND ((f.travel_date BETWEEN '${report_start}' AND '${report_end}') OR (f.travel_date BETWEEN '${base_start}' AND '${base_end}'))
        ) t
        LATERAL VIEW STACK(5, 'distance', distance_group, 'age_group', age_group, 'gender', gender_name, 'fellow_group', fellow_group, 'team', team_name) dv AS dim_type, dim_value
        GROUP BY dim_type, dim_value
    ) p

    UNION ALL
    -- S4 预订行为：提前预订天数（按游玩日）
    SELECT 'S4', 'advance_share', '提前预订天数分布（%）', 'advance_day_group', b.advance_day_group, 'ALL',
           b.cur_qty * 100 / NULLIF(SUM(b.cur_qty) OVER (), 0), b.base_qty * 100 / NULLIF(SUM(b.base_qty) OVER (), 0), b.scenic_qty
    FROM (
        SELECT p.advance_day_group,
               SUM(IF(p.travel_date BETWEEN '${report_start}' AND '${report_end}', p.order_ticket_qty, 0)) AS cur_qty,
               SUM(IF(p.travel_date BETWEEN '${base_start}' AND '${base_end}', p.order_ticket_qty, 0))     AS base_qty,
               COUNT(DISTINCT p.scenic_id) AS scenic_qty
        FROM ads.ads_ord_scenic_pre_booking_di p
        JOIN rpt_scenic s ON s.scenic_id = p.scenic_id AND s.outlier_flag = 0
        WHERE (p.travel_date BETWEEN '${report_start}' AND '${report_end}') OR (p.travel_date BETWEEN '${base_start}' AND '${base_end}')
        GROUP BY p.advance_day_group
    ) b

    UNION ALL
    -- S4 下单时段（小时）
    SELECT 'S4', 'hour_share', '下单时段分布（%）', 'stat_hour', LPAD(CAST(h.stat_hour AS STRING), 2, '0'), 'ALL',
           h.cur_qty * 100 / NULLIF(SUM(h.cur_qty) OVER (), 0), h.base_qty * 100 / NULLIF(SUM(h.base_qty) OVER (), 0), h.scenic_qty
    FROM (
        SELECT d.stat_hour,
               SUM(IF(d.travel_date BETWEEN '${report_start}' AND '${report_end}', d.order_order_qty, 0)) AS cur_qty,
               SUM(IF(d.travel_date BETWEEN '${base_start}' AND '${base_end}', d.order_order_qty, 0))     AS base_qty,
               COUNT(DISTINCT d.scenic_id) AS scenic_qty
        FROM dws.dws_ord_scenic_ticket_trade_hrs d
        JOIN rpt_scenic s ON s.scenic_id = d.scenic_id AND s.outlier_flag = 0
        WHERE (d.travel_date BETWEEN '${report_start}' AND '${report_end}') OR (d.travel_date BETWEEN '${base_start}' AND '${base_end}')
        GROUP BY d.stat_hour
    ) h

    UNION ALL
    -- S5 渠道结构：OTA / 分销 / 直销（一级分销商对接平台类型 + 是否自购），以及下单渠道（小程序、窗口、自助机 …）
    SELECT 'S5', 'channel_share', '渠道票数占比（%）', c.dim_type, c.dim_value, 'ALL',
           c.cur_qty * 100 / NULLIF(SUM(c.cur_qty) OVER (PARTITION BY c.dim_type), 0),
           c.base_qty * 100 / NULLIF(SUM(c.base_qty) OVER (PARTITION BY c.dim_type), 0), c.scenic_qty
    FROM (
        SELECT dim_type, dim_value,
               SUM(IF(period = 'CUR', order_ticket_qty, 0)) AS cur_qty, SUM(IF(period = 'BASE', order_ticket_qty, 0)) AS base_qty,
               COUNT(DISTINCT IF(period = 'CUR', scenic_id, NULL)) AS scenic_qty
        FROM (
            SELECT /*+ BROADCAST(ch, mb) */ t.period, t.scenic_id, t.order_ticket_qty,
                   CASE WHEN mb.distribute_system_code = 'OTA' OR t.order_mode = 17 THEN 'OTA'
                        WHEN t.distributor_id IS NULL OR t.distributor_id = -1 OR mb.member_type_code = '5' THEN '直销（自有渠道）'
                        ELSE '分销（旅行社 / 平台）' END AS channel_group,
                   COALESCE(ch.channel_name, '其他') AS order_channel
            FROM rpt_trade t
            LEFT JOIN dim.dim_sup_member_df mb ON mb.member_id = t.distributor_id
            LEFT JOIN dim.dim_trf_channel_f ch ON ch.order_channel_id = t.order_mode
        ) x
        LATERAL VIEW STACK(2, 'channel_group', channel_group, 'order_channel', order_channel) dv AS dim_type, dim_value
        GROUP BY dim_type, dim_value
    ) c

    UNION ALL
    -- S6 客流与承载：峰值日入园、峰值在园 / 最大接待能力（承载率），承载率 ≥ 80% 的景区天数占比
    SELECT 'S6', f.metric_code, f.metric_name, 'ALL', '全部', 'ALL', f.cur_value, f.base_value, f.scenic_qty
    FROM (
        SELECT 'peak_load_rate' AS metric_code, '景区峰值承载率均值（%）' AS metric_name,
               AVG(IF(period = 'CUR', peak_rate, NULL)) AS cur_value, AVG(IF(period = 'BASE', peak_rate, NULL)) AS base_value,
               COUNT(DISTINCT IF(period = 'CUR', scenic_id, NULL)) AS scenic_qty
        FROM flow_peak
        UNION ALL
        SELECT 'crowded_day_share', '承载率 ≥ 80% 的景区日占比（%）',
               SUM(IF(period = 'CUR' AND day_rate >= 80, 1, 0)) * 100 / NULLIF(SUM(IF(period = 'CUR', 1, 0)), 0),
               SUM(IF(period = 'BASE' AND day_rate >= 80, 1, 0)) * 100 / NULLIF(SUM(IF(period = 'BASE', 1, 0)), 0),
               COUNT(DISTINCT IF(period = 'CUR', scenic_id, NULL))
        FROM flow_day
    ) f

    UNION ALL
    -- S7 价格带：按票的报告期票均价分档，看票数分布
    SELECT 'S7', 'price_band_share', '价格带票数占比（%）', 'price_band', pb.price_band, 'ALL',
           pb.cur_qty * 100 / NULLIF(SUM(pb.cur_qty) OVER (), 0), pb.base_qty * 100 / NULLIF(SUM(pb.base_qty) OVER (), 0), pb.scenic_qty
    FROM (
        SELECT CASE WHEN avg_price <= 0 THEN '免费 / 0 元' WHEN avg_price < 50 THEN '0-50 元' WHEN avg_price < 100 THEN '50-100 元'
                    WHEN avg_price < 200 THEN '100-200 元' ELSE '200 元以上' END AS price_band,
               SUM(IF(period = 'CUR', ticket_qty, 0)) AS cur_qty, SUM(IF(period = 'BASE', ticket_qty, 0)) AS base_qty,
               COUNT(DISTINCT IF(period = 'CUR', scenic_id, NULL)) AS scenic_qty
        FROM (SELECT period, scenic_id, ticket_id, SUM(order_ticket_qty) AS ticket_qty, SUM(order_sale_amt) / NULLIF(SUM(order_ticket_qty), 0) AS avg_price
              FROM rpt_trade GROUP BY period, scenic_id, ticket_id) p
        GROUP BY 1
    ) pb

    UNION ALL
    -- S8 区域：省份规模与可比增长（城市榜单同理，换 city_name）
    SELECT 'S8', 'province_ticket_qty', '省份预订票数（张，可比景区）', 'province', COALESCE(province_name, '未知'), 'COMPARABLE',
           SUM(IF(period = 'CUR', order_ticket_qty, 0)), SUM(IF(period = 'BASE', order_ticket_qty, 0)), COUNT(DISTINCT IF(period = 'CUR', scenic_id, NULL))
    FROM rpt_trade
    WHERE comparable_flag = 1
    GROUP BY COALESCE(province_name, '未知')
) r;
