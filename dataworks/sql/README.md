# 标准化数仓加工逻辑

由 `python3 dataworks/standard/build.py` 生成，与字典页「表清单 → 加工逻辑」一致；每段都经 sqlglot（spark）解析，输出列与字典字段清单逐一核对。

| 层 | 脚本数 | 待确认字段 |
|---|---|---|
| ODS | 290 | 0 |
| DIM | 24 | 102 |
| DWD | 18 | 86 |
| DWS | 15 | 8 |
| ADS | 18 | 0 |

## 约定

- 调度参数：`bizdate` = 业务日期（yyyyMMdd，DataWorks `$[yyyymmdd-1]`）；分区统一 `travel_date`。
- ODS：`ods/*.json` 为数据集成脚本模式配置。增量表按 `update_time`（无则创建时间）取当天变更；只同步字典里的列；分表多表读取；历史库只在初始化时补一次。
- 脱敏在读端完成，明文不落数仓：
  - 手机号 = 前 7 位号段 + `#` + SHA256；
  - 证件号（18 位）= 地区 6 位 + 出生年 4 位 + 性别位 + `#` + SHA256；
  - DWD 用 `SUBSTRING_INDEX(x, '#', -1)` 取哈希、`SUBSTRING_INDEX(x, '#', 1)` 取前缀（归属地 / 性别 / 年龄）。
- Spark 参数：订单明细按下单日动态分区覆盖，需 `spark.sql.sources.partitionOverwriteMode=dynamic`；明细关联订单时带下单日分区条件，依赖动态分区裁剪（Spark 3 默认开启）。
- 去重类指标存位图：`TO_BITMAP / BITMAP_UNION / BITMAP_COUNT` 与 PFT3.0 同一套 UDF。
- 累计维表、订单明细先写 `tmp` 临时表再覆盖（Spark 不允许同表边读边覆盖），需要 `tmp` 库。
- 「待确认」：源字段未同步或码值需业务确认；「过渡期从旧表平移」：旧宽表逻辑分散在多张中间表，先平移保证下游切换，再逐字段改为从 ODS 计算。

## 上线顺序

ODS（同步）→ `dim_opr_dict_f`、地区 / 号段 / 证件地区码表 → `dim_sup_member_df` → `dim_prd_scenic_df` → `dim_prd_ticket_df` → `dim_prd_product_df`
→ `dwd_ord_order_di` → 轨迹 / 核销 / 游客 / 分销 → `dim_sup_member_relation_zip` → `dim_sup_supplier_df`、`dim_cus_tourist_df` → `dim_cus_user_df` → DWS → ADS。

每张表上线后与它替代的旧任务并行跑 7 天、按日对数（脚本头部列出了替代的旧任务），一致后下线旧任务。
