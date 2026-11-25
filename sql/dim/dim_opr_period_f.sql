-- dim.dim_opr_period_f  统计周期时间表
-- 每个截止日 T × 每种统计周期一行：本期 / 环比基期 / 同比基期区间。一次生成 2020–2035 年，之后每年 12 月补一年。
-- 依赖 dim_opr_date_f（日期属性）与 dim_opr_holiday_period_f（节假日放假区间）
INSERT OVERWRITE TABLE dim.dim_opr_period_f
SELECT
  DATE_FORMAT(x.t, 'yyyyMMdd')                     AS anchor_date_no,
  x.period_type_code,
  x.period_name,
  x.holiday_period_code,
  DATE_FORMAT(x.s, 'yyyyMMdd')                     AS start_date_no,
  DATE_FORMAT(x.e, 'yyyyMMdd')                     AS end_date_no,
  DATEDIFF(x.e, x.s) + 1                           AS period_day_qty,
  DATE_FORMAT(x.ps, 'yyyyMMdd')                    AS prev_start_date_no,
  DATE_FORMAT(x.pe, 'yyyyMMdd')                    AS prev_end_date_no,
  DATE_FORMAT(x.ls, 'yyyyMMdd')                    AS ly_start_date_no,
  DATE_FORMAT(x.le, 'yyyyMMdd')                    AS ly_end_date_no,
  IF(x.period_type_code = 'D1', DATE_FORMAT(DATE_SUB(x.t, 7), 'yyyyMMdd'), NULL) AS wow_date_no,
  DATE_FORMAT(LEAST(x.s, x.ps, x.ls), 'yyyyMMdd')  AS scan_start_date_no,
  DATE_FORMAT(x.s, 'yyyy-MM-dd')                   AS start_date,
  DATE_FORMAT(x.e, 'yyyy-MM-dd')                   AS end_date,
  CURRENT_TIMESTAMP()                              AS etl_time
FROM (
  -- 当日、滚动 N 日
  SELECT t, p.code AS period_type_code, p.name AS period_name, CAST(NULL AS STRING) AS holiday_period_code,
         DATE_SUB(t, p.n - 1) AS s, t AS e,
         DATE_SUB(t, 2 * p.n - 1) AS ps, DATE_SUB(t, p.n) AS pe,
         ADD_MONTHS(DATE_SUB(t, p.n - 1), -12) AS ls, ADD_MONTHS(t, -12) AS le
  FROM (SELECT TO_DATE(date_code) AS t FROM dim.dim_opr_date_f) d
  CROSS JOIN (SELECT 'D1' code, '当日' name, 1 n UNION ALL SELECT 'N7', '近7日', 7 UNION ALL SELECT 'N30', '近30日', 30
              UNION ALL SELECT 'N90', '近90日', 90 UNION ALL SELECT 'N180', '近半年', 180 UNION ALL SELECT 'N365', '近1年', 365) p
  UNION ALL
  -- 本周 / 本月 / 本季度 / 本半年 / 本年（至今）：环比取上一周期相同天数，同比取去年同期（周按 52 周对齐）
  SELECT t, code, name, NULL, s, t,
         CASE WHEN code = 'YTD' THEN ADD_MONTHS(s, -12) ELSE ADD_MONTHS(s, -k) END AS ps,
         CASE WHEN code = 'YTD' THEN ADD_MONTHS(t, -12) ELSE LEAST(DATE_ADD(ADD_MONTHS(s, -k), DATEDIFF(t, s)), DATE_SUB(s, 1)) END AS pe,
         ADD_MONTHS(s, -12), ADD_MONTHS(t, -12)
  FROM (
    SELECT t, 'MTD' code, '本月' name, TRUNC(t, 'MM') s, 1 k FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
    UNION ALL SELECT t, 'QTD', '本季度', TRUNC(t, 'Q'), 3 FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
    UNION ALL SELECT t, 'HTD', '本半年', IF(MONTH(t) <= 6, TRUNC(t, 'YYYY'), ADD_MONTHS(TRUNC(t, 'YYYY'), 6)), 6 FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
    UNION ALL SELECT t, 'YTD', '本年', TRUNC(t, 'YYYY'), 12 FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
  ) q
  UNION ALL
  SELECT t, 'WTD', '本周', NULL, DATE_SUB(t, DAYOFWEEK(t) - 2 + IF(DAYOFWEEK(t) = 1, 7, 0)) s, t,
         DATE_SUB(DATE_SUB(t, DAYOFWEEK(t) - 2 + IF(DAYOFWEEK(t) = 1, 7, 0)), 7), DATE_SUB(t, 7),
         DATE_SUB(DATE_SUB(t, DAYOFWEEK(t) - 2 + IF(DAYOFWEEK(t) = 1, 7, 0)), 364), DATE_SUB(t, 364)
  FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
  UNION ALL
  -- 上周 / 上月 / 上季度 / 上半年度 / 上年度（完整周期）
  SELECT t, code, name, NULL, s, e, ADD_MONTHS(s, -k), DATE_SUB(s, 1), ADD_MONTHS(s, -12), DATE_SUB(ADD_MONTHS(s, k - 12), 1)
  FROM (
    SELECT t, 'LM' code, '上月' name, ADD_MONTHS(TRUNC(t, 'MM'), -1) s, DATE_SUB(TRUNC(t, 'MM'), 1) e, 1 k FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
    UNION ALL SELECT t, 'LQ', '上季度', ADD_MONTHS(TRUNC(t, 'Q'), -3), DATE_SUB(TRUNC(t, 'Q'), 1), 3 FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
    UNION ALL SELECT t, 'LH', '上半年度', ADD_MONTHS(IF(MONTH(t) <= 6, TRUNC(t, 'YYYY'), ADD_MONTHS(TRUNC(t, 'YYYY'), 6)), -6),
                     DATE_SUB(IF(MONTH(t) <= 6, TRUNC(t, 'YYYY'), ADD_MONTHS(TRUNC(t, 'YYYY'), 6)), 1), 6 FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
    UNION ALL SELECT t, 'LY', '上年度', ADD_MONTHS(TRUNC(t, 'YYYY'), -12), DATE_SUB(TRUNC(t, 'YYYY'), 1), 12 FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
  ) q
  UNION ALL
  SELECT t, 'LW', '上周', NULL, DATE_SUB(t, DAYOFWEEK(t) + 5 + IF(DAYOFWEEK(t) = 1, 7, 0)) s, DATE_SUB(t, DAYOFWEEK(t) - 1 + IF(DAYOFWEEK(t) = 1, 7, 0)) e,
         DATE_SUB(t, DAYOFWEEK(t) + 12 + IF(DAYOFWEEK(t) = 1, 7, 0)), DATE_SUB(t, DAYOFWEEK(t) + 6 + IF(DAYOFWEEK(t) = 1, 7, 0)),
         DATE_SUB(t, DAYOFWEEK(t) + 369 + IF(DAYOFWEEK(t) = 1, 7, 0)), DATE_SUB(t, DAYOFWEEK(t) + 363 + IF(DAYOFWEEK(t) = 1, 7, 0))
  FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
  UNION ALL
  -- 节假日：截止日 T 已开始的每个假期（本年及上年），本期 = 假期首日 ~ min(假期末日, T)；环比 = 节前同等天数；同比 = 去年同一假期对应天数
  SELECT d.t, 'HOL', CONCAT(h.year_no, ' ', h.holiday_name), h.holiday_period_code,
         TO_DATE(h.start_date, 'yyyyMMdd') s, LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t) e,
         DATE_SUB(TO_DATE(h.start_date, 'yyyyMMdd'), DATEDIFF(LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t), TO_DATE(h.start_date, 'yyyyMMdd')) + 1),
         DATE_SUB(TO_DATE(h.start_date, 'yyyyMMdd'), 1),
         COALESCE(TO_DATE(ly.start_date, 'yyyyMMdd'), ADD_MONTHS(TO_DATE(h.start_date, 'yyyyMMdd'), -12)),
         COALESCE(LEAST(TO_DATE(ly.end_date, 'yyyyMMdd'), DATE_ADD(TO_DATE(ly.start_date, 'yyyyMMdd'), DATEDIFF(LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t), TO_DATE(h.start_date, 'yyyyMMdd')))),
                  ADD_MONTHS(LEAST(TO_DATE(h.end_date, 'yyyyMMdd'), d.t), -12))
  FROM (SELECT TO_DATE(date_code) t FROM dim.dim_opr_date_f) d
  JOIN dim.dim_opr_holiday_period_f h
    ON TO_DATE(h.start_date, 'yyyyMMdd') <= d.t AND h.year_no >= YEAR(d.t) - 1
  LEFT JOIN dim.dim_opr_holiday_period_f ly ON ly.holiday_period_code = h.last_year_period_code
) x;
