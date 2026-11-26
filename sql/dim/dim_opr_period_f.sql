-- dim.dim_opr_period_f  统计周期时间表
-- 每个截止日 T × 每种统计周期一行：本期 / 环比基期 / 同比基期区间。一次生成 2020–2035 年，之后每年 12 月补一年。
-- 依赖 dim_opr_date_f（日期）与 dim_opr_holiday_period_f（节假日放假区间）；每类周期一个 WITH 逻辑块，最后合并
WITH
anchor_day AS (            -- 全部截止日 T，并预先算好周/月/季/半年/年的首日
  SELECT TO_DATE(date_code)                                                      AS t,
         DATE_SUB(TO_DATE(date_code), PMOD(DATEDIFF(TO_DATE(date_code), '1900-01-01'), 7)) AS week_start,   -- 本周一
         TRUNC(TO_DATE(date_code), 'MM')                                         AS month_start,
         TRUNC(TO_DATE(date_code), 'Q')                                          AS quarter_start,
         IF(MONTH(TO_DATE(date_code)) <= 6, TRUNC(TO_DATE(date_code), 'YYYY'),
            ADD_MONTHS(TRUNC(TO_DATE(date_code), 'YYYY'), 6))                    AS half_start,
         TRUNC(TO_DATE(date_code), 'YYYY')                                       AS year_start
  FROM dim.dim_opr_date_f
),
period_rolling AS (        -- 当日、近 N 日：环比 = 前 N 天，同比 = 去年同期
  SELECT d.t, p.code AS period_type_code, p.name AS period_name, CAST(NULL AS STRING) AS holiday_period_code,
         DATE_SUB(d.t, p.n - 1) AS s, d.t AS e,
         DATE_SUB(d.t, 2 * p.n - 1) AS ps, DATE_SUB(d.t, p.n) AS pe,
         ADD_MONTHS(DATE_SUB(d.t, p.n - 1), -12) AS ls, ADD_MONTHS(d.t, -12) AS le
  FROM anchor_day d
  CROSS JOIN (SELECT 'D1' AS code, '当日' AS name, 1 AS n UNION ALL SELECT 'N7', '近7日', 7 UNION ALL SELECT 'N30', '近30日', 30
              UNION ALL SELECT 'N90', '近90日', 90 UNION ALL SELECT 'N180', '近半年', 180 UNION ALL SELECT 'N365', '近1年', 365) p
),
period_start AS (          -- 自然周期的首日与月数步长（周按 7 天单独处理）
  SELECT t, 'MTD' AS td_code, '本月' AS td_name, 'LM' AS full_code, '上月' AS full_name, month_start AS s, 1 AS k FROM anchor_day
  UNION ALL SELECT t, 'QTD', '本季度', 'LQ', '上季度', quarter_start, 3 FROM anchor_day
  UNION ALL SELECT t, 'HTD', '本半年', 'LH', '上半年度', half_start, 6 FROM anchor_day
  UNION ALL SELECT t, 'YTD', '本年', 'LY', '上年度', year_start, 12 FROM anchor_day
),
period_to_date AS (        -- 本月/本季度/本半年/本年（至今）：环比取上一周期相同天数，同比取去年同期
  SELECT t, td_code AS period_type_code, td_name AS period_name, CAST(NULL AS STRING) AS holiday_period_code,
         s, t AS e,
         IF(td_code = 'YTD', ADD_MONTHS(s, -12), ADD_MONTHS(s, -k)) AS ps,
         IF(td_code = 'YTD', ADD_MONTHS(t, -12), LEAST(DATE_ADD(ADD_MONTHS(s, -k), DATEDIFF(t, s)), DATE_SUB(s, 1))) AS pe,
         ADD_MONTHS(s, -12) AS ls, ADD_MONTHS(t, -12) AS le
  FROM period_start
),
period_full AS (           -- 上月/上季度/上半年度/上年度（完整周期）
  SELECT t, full_code AS period_type_code, full_name AS period_name, CAST(NULL AS STRING) AS holiday_period_code,
         ADD_MONTHS(s, -k) AS s, DATE_SUB(s, 1) AS e,
         ADD_MONTHS(s, -2 * k) AS ps, DATE_SUB(ADD_MONTHS(s, -k), 1) AS pe,
         ADD_MONTHS(s, -k - 12) AS ls, DATE_SUB(ADD_MONTHS(s, -12), 1) AS le
  FROM period_start
),
period_week AS (           -- 本周（至今）与上周（完整）：同比按 52 周对齐（同星期）
  SELECT t, 'WTD' AS period_type_code, '本周' AS period_name, CAST(NULL AS STRING) AS holiday_period_code,
         week_start AS s, t AS e, DATE_SUB(week_start, 7) AS ps, DATE_SUB(t, 7) AS pe,
         DATE_SUB(week_start, 364) AS ls, DATE_SUB(t, 364) AS le
  FROM anchor_day
  UNION ALL
  SELECT t, 'LW', '上周', NULL,
         DATE_SUB(week_start, 7), DATE_SUB(week_start, 1), DATE_SUB(week_start, 14), DATE_SUB(week_start, 8),
         DATE_SUB(week_start, 371), DATE_SUB(week_start, 365)
  FROM anchor_day
),
period_holiday AS (        -- 节假日：截止日已开始的假期（本年及上年）；本期 = 首日 ~ min(末日, T)，环比 = 节前同等天数，同比 = 去年同一假期对应天数
  SELECT d.t, 'HOL' AS period_type_code, CONCAT(h.year_no, ' ', h.holiday_name) AS period_name, h.holiday_period_code,
         TO_DATE(h.start_date, 'yyyyMMdd') AS s,
         LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t) AS e,
         DATE_SUB(TO_DATE(h.start_date, 'yyyyMMdd'), DATEDIFF(LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t), TO_DATE(h.start_date, 'yyyyMMdd')) + 1) AS ps,
         DATE_SUB(TO_DATE(h.start_date, 'yyyyMMdd'), 1) AS pe,
         COALESCE(TO_DATE(ly.start_date, 'yyyyMMdd'), ADD_MONTHS(TO_DATE(h.start_date, 'yyyyMMdd'), -12)) AS ls,
         COALESCE(LEAST(TO_DATE(ly.end_date, 'yyyyMMdd'),
                        DATE_ADD(TO_DATE(ly.start_date, 'yyyyMMdd'), DATEDIFF(LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t), TO_DATE(h.start_date, 'yyyyMMdd')))),
                  ADD_MONTHS(LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t), -12)) AS le
  FROM anchor_day d
  JOIN dim.dim_opr_holiday_period_f h
    ON TO_DATE(h.start_date, 'yyyyMMdd') <= d.t AND h.year_no >= YEAR(d.t) - 1
  LEFT JOIN dim.dim_opr_holiday_period_f ly
    ON ly.holiday_period_code = h.last_year_period_code
),
all_period AS (            -- 合并全部周期
  SELECT * FROM period_rolling
  UNION ALL SELECT * FROM period_to_date
  UNION ALL SELECT * FROM period_full
  UNION ALL SELECT * FROM period_week
  UNION ALL SELECT * FROM period_holiday
)
INSERT OVERWRITE TABLE dim.dim_opr_period_f
SELECT
  DATE_FORMAT(t, 'yyyyMMdd')                     AS anchor_date_no,       -- 统计截止日 T
  period_type_code,                                                       -- 统计周期编码
  period_name,                                                            -- 统计周期名称
  holiday_period_code,                                                    -- 节假日区间编码
  DATE_FORMAT(s, 'yyyyMMdd')                     AS start_date_no,        -- 本期开始日
  DATE_FORMAT(e, 'yyyyMMdd')                     AS end_date_no,          -- 本期结束日
  DATEDIFF(e, s) + 1                             AS period_day_qty,       -- 本期天数
  DATE_FORMAT(ps, 'yyyyMMdd')                    AS prev_start_date_no,   -- 环比基期开始日
  DATE_FORMAT(pe, 'yyyyMMdd')                    AS prev_end_date_no,     -- 环比基期结束日
  DATE_FORMAT(ls, 'yyyyMMdd')                    AS ly_start_date_no,     -- 同比基期开始日
  DATE_FORMAT(le, 'yyyyMMdd')                    AS ly_end_date_no,       -- 同比基期结束日
  IF(period_type_code = 'D1', DATE_FORMAT(DATE_SUB(t, 7), 'yyyyMMdd'), NULL) AS wow_date_no,  -- 周同比基准日（仅当日）
  DATE_FORMAT(LEAST(s, ps, ls), 'yyyyMMdd')      AS scan_start_date_no,   -- 查询需扫描的最早分区
  DATE_FORMAT(s, 'yyyy-MM-dd')                   AS start_date,           -- 本期开始日（展示）
  DATE_FORMAT(e, 'yyyy-MM-dd')                   AS end_date,             -- 本期结束日（展示）
  CURRENT_TIMESTAMP()                            AS etl_time              -- ETL 加载时间
FROM all_period;
