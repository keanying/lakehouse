-- dim.dim_fin_bank_card_df  银行卡维度（脱敏）
-- 粒度：1行=1张卡
-- 来源：ods_fin_bank_card_df
-- 生成方式：Spark SQL / Hive；字段 14 个：直接翻译 14 · 规则翻译 0 · 待确认 0
-- 每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
bank_card_src AS (                             -- 主表「银行卡」，只取用到的列
  SELECT bank_code, bank_name, branch_name, card_holder, card_no, card_status, card_tail_no, card_type,
         create_time, id, subject_id, tenant_id, update_time
  FROM ods.ods_fin_bank_card_df
  WHERE travel_date = '${bizdate}'             -- 只取当日分区
)
INSERT OVERWRITE TABLE dim.dim_fin_bank_card_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  bank_card_src.id           AS bank_card_id,  -- 银行卡ID（源表主键 id）
  bank_card_src.card_no      AS card_no,       -- 银行卡编号（系统内ID）
  bank_card_src.subject_id   AS subject_id,    -- 归属主体ID（商户/分销商）
  bank_card_src.bank_name    AS bank_name,     -- 银行名称
  bank_card_src.bank_code    AS bank_code,     -- 银行代码
  bank_card_src.card_holder  AS card_holder_name,  -- 持卡人姓名（脱敏）
  bank_card_src.card_type    AS card_type,     -- 卡类型
  bank_card_src.branch_name  AS branch_name,   -- 开户支行
  bank_card_src.card_status  AS card_status,   -- 状态
  bank_card_src.tenant_id    AS tenant_id,     -- 租户ID（分库维度）
  bank_card_src.create_time  AS create_time,   -- 创建时间
  bank_card_src.update_time  AS update_time,   -- 更新时间
  bank_card_src.card_tail_no AS card_tail_no,  -- 卡号后 4 位
  CURRENT_TIMESTAMP()        AS etl_time       -- ETL 加载时间
FROM bank_card_src;
