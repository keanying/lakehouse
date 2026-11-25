-- dim.dim_opr_currency_f  币种维度
-- 粒度：1行=1个币种
-- 来源：ods_opr_i18n_currency_df
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 10 · 规则翻译 0 · 待确认 1
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dim.dim_opr_currency_f
SELECT
  a.id                   AS currency_id,
  a.currency_code        AS currency_code,
  a.currency_name        AS currency_name,
  a.currency_name_en     AS currency_en_name,
  a.currency_symbol      AS currency_symbol_code,
  a.exchange_rate_to_cny AS exchange_to_cny_rate,
  a.currency_status      AS currency_status,
  a.create_time          AS create_time,
  a.update_time          AS update_time,
  NULL                   AS decimal_digit_qty,  -- 待确认：常量映射（JPY=0，其余=2）
  CURRENT_TIMESTAMP()    AS etl_time
FROM ods.ods_opr_i18n_currency_df a
WHERE a.travel_date = '${bizdate}';
