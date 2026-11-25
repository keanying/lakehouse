-- dim.dim_opr_holiday_period_f  节假日放假区间
-- 人工维护：每年 12 月国务院公布次年放假安排后追加。以下为 2024–2026 年数据。
INSERT OVERWRITE TABLE dim.dim_opr_holiday_period_f
SELECT holiday_period_code, year_no, holiday_code, holiday_name, start_date, end_date,
       DATEDIFF(TO_DATE(end_date, 'yyyyMMdd'), TO_DATE(start_date, 'yyyyMMdd')) + 1 AS holiday_day_qty,
       adjust_workday_desc, last_year_period_code, CURRENT_TIMESTAMP() AS etl_time
FROM VALUES
  ('2024_new_year',        2024, 'new_year',        '元旦',          '20240101', '20240101', '',                  ''),
  ('2024_spring_festival', 2024, 'spring_festival', '春节',          '20240210', '20240217', '20240204,20240218', ''),
  ('2024_qingming',        2024, 'qingming',        '清明节',        '20240404', '20240406', '20240407',          ''),
  ('2024_labour_day',      2024, 'labour_day',      '劳动节',        '20240501', '20240505', '20240428,20240511', ''),
  ('2024_dragon_boat',     2024, 'dragon_boat',     '端午节',        '20240608', '20240610', '',                  ''),
  ('2024_mid_autumn',      2024, 'mid_autumn',      '中秋节',        '20240915', '20240917', '20240914',          ''),
  ('2024_national_day',    2024, 'national_day',    '国庆节',        '20241001', '20241007', '20240929,20241012', ''),
  ('2025_new_year',        2025, 'new_year',        '元旦',          '20250101', '20250101', '',                  '2024_new_year'),
  ('2025_spring_festival', 2025, 'spring_festival', '春节',          '20250128', '20250204', '20250126,20250208', '2024_spring_festival'),
  ('2025_qingming',        2025, 'qingming',        '清明节',        '20250404', '20250406', '',                  '2024_qingming'),
  ('2025_labour_day',      2025, 'labour_day',      '劳动节',        '20250501', '20250505', '20250427',          '2024_labour_day'),
  ('2025_dragon_boat',     2025, 'dragon_boat',     '端午节',        '20250531', '20250602', '',                  '2024_dragon_boat'),
  ('2025_national_day',    2025, 'national_day',    '国庆节·中秋节', '20251001', '20251008', '20250928,20251011', '2024_national_day'),
  ('2026_new_year',        2026, 'new_year',        '元旦',          '20260101', '20260103', '20260104',          '2025_new_year'),
  ('2026_spring_festival', 2026, 'spring_festival', '春节',          '20260215', '20260223', '20260214,20260228', '2025_spring_festival'),
  ('2026_qingming',        2026, 'qingming',        '清明节',        '20260404', '20260406', '',                  '2025_qingming'),
  ('2026_labour_day',      2026, 'labour_day',      '劳动节',        '20260501', '20260505', '20260509',          '2025_labour_day'),
  ('2026_dragon_boat',     2026, 'dragon_boat',     '端午节',        '20260619', '20260621', '',                  '2025_dragon_boat'),
  ('2026_mid_autumn',      2026, 'mid_autumn',      '中秋节',        '20260925', '20260927', '',                  ''),
  ('2026_national_day',    2026, 'national_day',    '国庆节',        '20261001', '20261007', '20260920,20261010', '2025_national_day')
AS v(holiday_period_code, year_no, holiday_code, holiday_name, start_date, end_date, adjust_workday_desc, last_year_period_code);
-- 调休上班日以国务院当年通知为准，上线前核对
