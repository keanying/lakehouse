# lakehouse

PFT3.0 数仓（文旅票务）资料与数仓字典展示页。

## 打开字典页

`dw-dict/dist/index.html` 是单文件静态页，双击用浏览器打开即可，也可以放到任意静态服务器。

| 模块 | 内容 |
|---|---|
| 总览 / 分层 / 表清单 / 字段 | 已按改造后的字典展示：ADS 保持日粒度，按周期写死的指标列合并为日字段（762 列 → 326 列；比率存分子分母、去重存位图）；6 张 DWS 补去重位图列；新增时间表 dim_opr_period_f 和节假日区间表，日期维表补 7 个字段。表清单可「只看改造」，表详情有「改造前字段」对照；DDL 补上分区子句 |
| 指标口径 | 新增「指标目录（按口径）」：212 个口径一行一个，不再按周期平铺 913 行；点开可看任意区间的取数 SQL |
| ADS 指标体系 | ADS 只存日数据，查询时关联时间表按统计周期汇总：当日、本周/上周、本月/上月、本季/上季、本半年/上半年度、本年/上年度、近7/30/90日、近半年、近1年、节假日、自定义区间；派生出本期值、日均、上期值、环比、去年同期值、同比、周同比、占比。含业务指标清单（每条带取数 SQL）、日粒度 DDL 与查询模板，完整清单导出为 `dw-dict/dist/ADS指标体系.xlsx` |
| 表详情 ·「加工逻辑」 | 每张 DWD / DIM / DWS / ADS 表（含实时）的加工 SQL，按字段清单的「加工 / 来源」「上游字段」生成；标注直接翻译 / 规则翻译 / 待确认字段数，可一键定位待确认行 |
| 调度与治理 | 调度工作流、质量规则、总线矩阵、质量体检、待确认事项（原页面未展示的 5 个工作表） |
| 核对报告 | 对客户交付字典的自动核对结果，同时输出 [`docs/核对报告.md`](docs/核对报告.md) |

## 目录

```
dw-dict/
  data/      客户交付的 Excel（PFT3.0_数仓分层表清单与指标字典.xlsx）
  src/       页面模板（客户原版基础上扩展）
  build.py   读 Excel → 生成 dist/index.html、dist/*_改造版.xlsx（改造后的完整字典，改动行标黄）、dist/ADS指标体系.xlsx 与 docs/核对报告.md
  checks.py  核对规则（命名规范、源库 DDL 对照、血缘/口径/ADS 交叉校验、指标聚合方式分类）
  etl_gen.py    加工逻辑生成（DWD/DIM 行级加工与拉链、DWS/ADS 多来源汇总、实时 Flink / StarRocks）
  ads_model.py  ADS 指标体系生成（统计周期、派生方式、业务指标清单、改造后 DDL/ETL、Excel 导出）
  dist/      构建产物
sql/                离线加工脚本（路径与调度工作流「执行」列一致，如 sql/dwd/dwd_ord_order_di.sql）
  dwd/ dim/ dws/ ads/  Spark SQL / Hive，INSERT OVERWRITE … PARTITION (travel_date='${bizdate}')
  flink/            实时 DWD / DWS：Flink SQL（CDC 源 → StarRocks，维表 Lookup Join，1 分钟窗口）
  starrocks/        实时 ADS：StarRocks 异步物化视图（每分钟刷新）
docs/
  规范/       数仓命名规范
  source/    业务系统设计文档（HLD、数据库 DDL、核心模型、应用架构、价格模型）
  核对报告.md  构建时生成
```

## 更新数据

```bash
pip install openpyxl
```

```bash
python3 dw-dict/build.py
```

换新版 Excel 时把文件路径作为参数传入；工作表名和表头需与现有 Excel 一致。核对针对客户原版 Excel 运行，页面与改造版 Excel 展示改造后的结果，每次构建都会重新生成。

## 加工逻辑说明

`sql/` 下 176 个脚本由 `dw-dict/etl_gen.py` 生成，每个文件开头写明粒度、来源和字段翻译情况：

- **直接翻译**：加工说明是「表.字段 / 改名 / ÷100 / 按键关联」，原样转成 SQL；
- **规则翻译**：前后差（LAG）、JSON 展开、状态变更时间、聚合 where 条件、修饰词条件（如 渠道类型=小程序 → `channel_type='MP'`）等；
- **待确认**：加工说明是业务描述（递归层级、证件号映射、定价规则计算等）或引用了上游不存在的字段，SQL 里该行带 `-- 待确认：原说明`，给出可运行的占位写法，上线前需人工补齐。

参数：`${bizdate}`（YYYYMMDD）、`${bizdate_dash}`（yyyy-MM-dd）、`${bizdate_prev}` / `${bizdate_prev_dash}`（前一天），周报 / 月报用 `${last_week_*}` / `${last_month_*}`。
全部脚本已用 sqlglot 做过语法检查（Spark / StarRocks 方言；Flink 专有语法替换后检查）。
