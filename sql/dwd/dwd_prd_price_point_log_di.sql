-- dwd.dwd_prd_price_point_log_di  价格点变更明细
-- 粒度：1行=1次价格点新增/修改/删除
-- 来源：ods_prd_price_point_di（binlog）
-- 生成方式：Spark SQL / Hive；字段 20 个：直接翻译 18 · 规则翻译 2 · 待确认 0
-- 流水/状态变更类：保留每条变更记录；每个 WITH 逻辑块只取用到的列并先过滤分区

WITH
price_point_chg AS (                                                              -- 主表「价格点」：保留每条变更记录，只取用到的列
  SELECT binlog_op_type, binlog_time, channel, create_time, date_from, date_single, date_to,
         effective_from, effective_to, ext_dims, id, price, price_no, priority, sku_id, tenant_id,
         update_time, weekday_mask
  FROM ods.ods_prd_price_point_di
  WHERE travel_date = '${bizdate}'                                                -- 只取当日分区
)
INSERT OVERWRITE TABLE dwd.dwd_prd_price_point_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  price_point_chg.id                                           AS price_point_id,  -- 价格点ID（源表主键 id）
  price_point_chg.price_no                                     AS price_no,       -- 价格点编号
  price_point_chg.sku_id                                       AS sku_id,         -- SKU ID
  price_point_chg.channel                                      AS price_channel_code,  -- 价格渠道
  price_point_chg.date_single                                  AS price_date,     -- 单日精确匹配(节假日特殊价)
  price_point_chg.date_from                                    AS price_start_date,  -- 日期区间起始
  price_point_chg.date_to                                      AS price_end_date,  -- 日期区间终止
  price_point_chg.weekday_mask                                 AS weekday_mask_code,  -- 星期掩码 bit0=周一..bit6=周日(工作日=3…
  price_point_chg.ext_dims                                     AS ext_dim_desc,   -- 动态维度
  price_point_chg.priority                                     AS priority_no,    -- 优先级（数值大优先）
  price_point_chg.effective_from                               AS effective_start_time,  -- 生效起始
  price_point_chg.effective_to                                 AS effective_end_time,  -- 生效终止
  price_point_chg.tenant_id                                    AS tenant_id,      -- 租户ID（分库维度）
  price_point_chg.create_time                                  AS create_time,    -- 创建时间
  price_point_chg.update_time                                  AS update_time,    -- 更新时间
  price_point_chg.binlog_op_type                               AS change_type,    -- 变更类型
  LAG(price_point_chg.price) OVER (PARTITION BY price_point_chg.id ORDER BY price_point_chg.binlog_time) AS before_price_amt,  -- 变更前价格（元）
  price_point_chg.price                                        AS after_price_amt,  -- 变更后价格（元）
  price_point_chg.binlog_time                                  AS change_time,    -- 变更时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM price_point_chg;
