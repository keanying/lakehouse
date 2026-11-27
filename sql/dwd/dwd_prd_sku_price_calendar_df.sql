-- dwd.dwd_prd_sku_price_calendar_df  SKU每日生效价日历
-- 粒度：1行=1个SKU×1个日期×1个渠道×1组扩展维度
-- 来源：ods_prd_price_point_di（全部历史取最新）+ ods_prd_pricing_rule_df + dim_opr_date_f
-- 生成方式：手写（结构不适合按字段自动翻译）；业务规则：
--   · 日历：统计日起未来 90 天 × 每个 SKU × 渠道 × 扩展维度
--   · 命中价格点：在生效期内，按 单日价（10）> 区间价（5）> 星期价（3）> 默认价（0）取类别最高、再按优先级最高的一条
--   · 星期掩码 bit0 = 周一 … bit6 = 周日
--   · 规则价：同 SKU 生效期内优先级最高的定价规则；PERCENT 按比例、FIXED 按固定加减；口径说明：params 的 JSON 键名（percent / amount）待研发确认，MATRIX 暂不计算
-- 性能：
--   · 价格点表小，取全部历史分区按主键取最新；日期维表广播

WITH pp AS (                                                                      -- 价格点最新状态
    SELECT id, price_no, sku_id, channel, date_single, date_from, date_to, weekday_mask, ext_dims, price, priority, effective_from, effective_to, tenant_id
    FROM (
        SELECT p.*, ROW_NUMBER() OVER (PARTITION BY id ORDER BY binlog_time DESC) AS rn  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM ods.ods_prd_price_point_di p WHERE travel_date <= '${bizdate}'       -- 累计口径：取截至统计日的全部分区
    ) z
    WHERE rn = 1 AND binlog_op_type <> 'DELETE'                                   -- 剔除源库已删除的记录
),
d AS (                                                                            -- 未来 90 天
    SELECT date_code AS price_date
    FROM dim.dim_opr_date_f
    WHERE date_code BETWEEN '${bizdate_dash}' AND DATE_FORMAT(DATE_ADD(TO_DATE('${bizdate_dash}'), 89), 'yyyy-MM-dd')
),
hit AS (
    SELECT /*+ BROADCAST(d) */ pp.sku_id, d.price_date, COALESCE(pp.channel, 'DEFAULT') AS price_channel_code, COALESCE(pp.ext_dims, '') AS ext_dim_desc,
           pp.price_no, pp.price, pp.priority, pp.tenant_id,
           CASE WHEN pp.date_single IS NOT NULL THEN 10 WHEN pp.date_from IS NOT NULL THEN 5 WHEN pp.weekday_mask IS NOT NULL THEN 3 ELSE 0 END AS cls
    FROM pp CROSS JOIN d
    WHERE (pp.effective_from IS NULL OR TO_DATE(pp.effective_from) <= d.price_date)
      AND (pp.effective_to IS NULL OR TO_DATE(pp.effective_to) >= d.price_date)
      AND (pp.date_single IS NULL OR TO_DATE(pp.date_single) = d.price_date)
      AND (pp.date_from IS NULL OR d.price_date BETWEEN TO_DATE(pp.date_from) AND TO_DATE(pp.date_to))
      AND (pp.weekday_mask IS NULL OR (SHIFTRIGHT(pp.weekday_mask, (DAYOFWEEK(d.price_date) + 5) % 7) & 1) = 1)
),
best AS (
    SELECT * FROM (
        SELECT hit.*, ROW_NUMBER() OVER (PARTITION BY sku_id, price_date, price_channel_code, ext_dim_desc ORDER BY cls DESC, priority DESC) AS rk FROM hit  -- 同一主键多次变更，按 binlog 时间倒序编号
    ) z WHERE rk = 1
),
rule AS (
    SELECT rule_no, sku_id, calculator, params, priority, effective_from, effective_to
    FROM ods.ods_prd_pricing_rule_df WHERE travel_date = '${bizdate}'
),
rule_hit AS (
    SELECT * FROM (
        SELECT b.sku_id, b.price_date, b.price_channel_code, b.ext_dim_desc, r.rule_no, r.calculator, r.params,
               ROW_NUMBER() OVER (PARTITION BY b.sku_id, b.price_date, b.price_channel_code, b.ext_dim_desc ORDER BY r.priority DESC) AS rk  -- 同一主键多次变更，按 binlog 时间倒序编号
        FROM best b
        JOIN rule r ON r.sku_id = b.sku_id
         AND (r.effective_from IS NULL OR TO_DATE(r.effective_from) <= b.price_date)
         AND (r.effective_to IS NULL OR TO_DATE(r.effective_to) >= b.price_date)
    ) z WHERE rk = 1
)
INSERT OVERWRITE TABLE dwd.dwd_prd_sku_price_calendar_df PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
    b.sku_id, b.price_date, b.price_channel_code, b.ext_dim_desc,
    b.price_no                                                    AS hit_price_no,  -- 命中的价格点编号
    b.cls                                                         AS hit_priority_no,  -- 命中优先级
    ROUND(b.price / 100, 2)                                       AS list_price_amt,  -- 当日生效挂牌价（元）
    rh.rule_no                                                    AS pricing_rule_no,  -- 叠加的定价规则编号
    IF(rh.rule_no IS NULL, 0, 1)                                  AS rule_price_type,  -- 是否 L2 规则价
    ROUND(CASE rh.calculator
            WHEN 'PERCENT' THEN b.price / 100 * CAST(GET_JSON_OBJECT(rh.params, '$.percent') AS DECIMAL(18,4)) / 100
            WHEN 'FIXED'   THEN b.price / 100 + CAST(GET_JSON_OBJECT(rh.params, '$.amount') AS DECIMAL(18,2)) / 100
            ELSE b.price / 100 END, 2)                            AS final_price_amt,  -- 规则计算后成交参考价（元）
    b.tenant_id,                                                                  -- 租户ID（分库维度）
    CURRENT_TIMESTAMP() AS etl_time                                               -- ETL 加载时间
FROM best b
LEFT JOIN rule_hit rh ON rh.sku_id = b.sku_id AND rh.price_date = b.price_date AND rh.price_channel_code = b.price_channel_code AND rh.ext_dim_desc = b.ext_dim_desc;
