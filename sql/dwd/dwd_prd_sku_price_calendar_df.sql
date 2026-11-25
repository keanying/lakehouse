-- dwd.dwd_prd_sku_price_calendar_df  SKU每日生效价日历
-- 粒度：1行=1个SKU×1个日期×1个渠道×1组扩展维度
-- 来源：ods_prd_price_point_di + ods_prd_pricing_rule_df
-- 生成方式：Spark SQL / Hive；字段 13 个：直接翻译 9 · 规则翻译 0 · 待确认 4
-- ODS 增量按主键取最新一条（ROW_NUMBER），剔除删除记录
-- 标「待确认」的字段：加工说明是业务描述，这里给出近似写法，上线前需人工核对

INSERT OVERWRITE TABLE dwd.dwd_prd_sku_price_calendar_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.sku_id                                           AS sku_id,           -- SKU ID
  j1.date_code                                       AS price_date,       -- 价格日期（日历展开
  a.channel                                          AS price_channel_code,  -- 价格渠道编码
  a.ext_dims                                         AS ext_dim_desc,     -- 扩展维度组合（JSON 字符串
  a.price_no                                         AS hit_price_no,     -- 命中的价格点编号｜待确认：ods_prd_price_point_di.price_no 按优先级取第一
  a.priority                                         AS hit_priority_no,  -- 命中优先级
  ROUND(a.price / 100, 2)                            AS list_price_amt,   -- 当日生效挂牌价（元）
  j2.rule_no                                         AS pricing_rule_no,  -- 叠加的定价规则编号
  CASE WHEN j2.rule_no IS NOT NULL THEN 1 ELSE 0 END AS rule_price_type,  -- 是否 L2 规则价｜待确认：ods_prd_pricing_rule_df.rule_no 是否命中
  j2.calculator                                      AS final_price_amt,  -- 规则计算后成交参考价（元）｜待确认：list_price_amt 按 ods_prd_pricing_rule_df.calculator 计算
  a.tenant_id                                        AS tenant_id,        -- 租户ID（分库维度）
  CURRENT_TIMESTAMP()                                AS etl_time          -- ETL 加载时间
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
  FROM ods.ods_prd_price_point_di
  WHERE travel_date = '${bizdate}'                                        -- 只取当日分区
) a                                                                       -- 主表当日增量，按主键取最新一条
LEFT JOIN dim.dim_opr_date_f j1                                           -- 关联「日期维度」，取 价格日期（日历展开
  ON j1.date_code = a.id                                                  -- 按 id→date_code 关联｜待确认：关联键
LEFT JOIN ods.ods_prd_pricing_rule_df j2                                  -- 关联「定价规则」，取 叠加的定价规则编号、是否 L2 规则价、规则计算后成交参考价（元）
  ON j2.sku_id = a.sku_id                                                 -- 按 sku_id 关联
 AND j2.travel_date = '${bizdate}'                                        -- 只取当日分区
WHERE a.rn = 1                                                            -- 只保留每个主键的最新一条
  AND a.binlog_op_type <> 'DELETE';                                       -- 剔除源库已删除的记录
