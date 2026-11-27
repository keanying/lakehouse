-- dim.dim_opr_currency_f  币种维度
-- 粒度：1行=1个币种
-- 来源：ods_opr_i18n_currency_df
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 10 · 规则翻译 1 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
i18n_currency_src AS (                                             -- 主表「支持币种」，只取用到的列
  SELECT create_time, currency_code, currency_name, currency_name_en, currency_status, currency_symbol,
         exchange_rate_to_cny, id, update_time
  FROM ods.ods_opr_i18n_currency_df
  WHERE travel_date = '${bizdate}'                                 -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_opr_currency_f                      -- 整表覆盖写入
SELECT
  i18n_currency_src.id                   AS currency_id,           -- 支持币种ID（源表主键 id）
  i18n_currency_src.currency_code        AS currency_code,         -- 币种代码
  i18n_currency_src.currency_name        AS currency_name,         -- 币种名称（中文）
  i18n_currency_src.currency_name_en     AS currency_en_name,      -- 币种名称（英文）
  i18n_currency_src.currency_symbol      AS currency_symbol_code,  -- 币种符号（¥/$/¥/₩等）
  i18n_currency_src.exchange_rate_to_cny AS exchange_to_cny_rate,  -- 对CNY-人民币汇率
  i18n_currency_src.currency_status      AS currency_status,       -- 状态
  i18n_currency_src.create_time          AS create_time,           -- 创建时间
  i18n_currency_src.update_time          AS update_time,           -- 更新时间
  CASE WHEN i18n_currency_src.currency_code IN ('JPY', 'KRW') THEN 0 ELSE 2 END AS decimal_digit_qty,  -- 金额小数位数｜口径：ISO 4217：日元、韩元无小数，其余 2 位
  CURRENT_TIMESTAMP()                    AS etl_time               -- ETL 加载时间
FROM i18n_currency_src;
