-- dim.dim_opr_currency_f  币种维度
-- 粒度：1行=1个币种
-- 来源：ods_opr_i18n_currency_df
-- 生成方式：Spark SQL / Hive；字段 11 个：直接翻译 10 · 规则翻译 0 · 待确认 1
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dim.dim_opr_currency_f   -- 整表覆盖写入
SELECT
  a.id                   AS currency_id,        -- 支持币种ID（源表主键 id）
  a.currency_code        AS currency_code,      -- 币种代码（CNY-人民币
  a.currency_name        AS currency_name,      -- 币种名称（中文）
  a.currency_name_en     AS currency_en_name,   -- 币种名称（英文）
  a.currency_symbol      AS currency_symbol_code,  -- 币种符号（¥/$/¥/₩等）
  a.exchange_rate_to_cny AS exchange_to_cny_rate,  -- 对CNY-人民币汇率
  a.currency_status      AS currency_status,    -- 状态
  a.create_time          AS create_time,        -- 创建时间
  a.update_time          AS update_time,        -- 更新时间
  NULL                   AS decimal_digit_qty,  -- 金额小数位数｜待确认：常量映射（JPY=0，其余=2）
  CURRENT_TIMESTAMP()    AS etl_time            -- ETL 加载时间
FROM ods.ods_opr_i18n_currency_df a             -- 主表「支持币种」
WHERE a.travel_date = '${bizdate}';             -- 只取当日分区
