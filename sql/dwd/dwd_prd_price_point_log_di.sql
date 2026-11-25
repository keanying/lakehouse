-- dwd.dwd_prd_price_point_log_di  价格点变更明细
-- 粒度：1行=1次价格点新增/修改/删除
-- 来源：ods_prd_price_point_di（binlog）
-- 生成方式：Spark SQL / Hive；字段 20 个：直接翻译 18 · 规则翻译 2 · 待确认 0
-- 流水/状态变更类：保留每条变更记录

INSERT OVERWRITE TABLE dwd.dwd_prd_price_point_log_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT
  a.id                                                         AS price_point_id,  -- 价格点ID（源表主键 id）
  a.price_no                                                   AS price_no,       -- 价格点编号
  a.sku_id                                                     AS sku_id,         -- SKU ID
  a.channel                                                    AS price_channel_code,  -- 价格渠道
  a.date_single                                                AS price_date,     -- 单日精确匹配(节假日特殊价)
  a.date_from                                                  AS price_start_date,  -- 日期区间起始
  a.date_to                                                    AS price_end_date,  -- 日期区间终止
  a.weekday_mask                                               AS weekday_mask_code,  -- 星期掩码 bit0=周一..bit6=周日(工作日=3…
  a.ext_dims                                                   AS ext_dim_desc,   -- 动态维度
  a.priority                                                   AS priority_no,    -- 优先级（数值大优先）
  a.effective_from                                             AS effective_start_time,  -- 生效起始
  a.effective_to                                               AS effective_end_time,  -- 生效终止
  a.tenant_id                                                  AS tenant_id,      -- 租户ID（分库维度）
  a.create_time                                                AS create_time,    -- 创建时间
  a.update_time                                                AS update_time,    -- 更新时间
  a.binlog_op_type                                             AS change_type,    -- 变更类型
  LAG(a.price) OVER (PARTITION BY a.id ORDER BY a.binlog_time) AS before_price_amt,  -- 变更前价格（元）
  a.price                                                      AS after_price_amt,  -- 变更后价格（元）
  a.binlog_time                                                AS change_time,    -- 变更时间
  CURRENT_TIMESTAMP()                                          AS etl_time        -- ETL 加载时间
FROM ods.ods_prd_price_point_di a                                                 -- 主表「价格点」
WHERE a.travel_date = '${bizdate}';                                               -- 只取当日分区
