# 票付通价格体系模型 v2

> 基于真实业务抽象，覆盖旅游票务/电商/分销场景。
> 核心结论：价格是"某个维度组合下的一个金额"，所有维度（渠道/日期/房型/时段等）平等对待。

---

## 一、核心抽象

### 1.1 价格是什么

**价格 = 一笔交易成立时，买卖双方同意的金额。只有一个价格真正有意义：成交价。**

本方案只设计**售价体系**（卖给游客/渠道的金额）。成本价（`costPrice`）是供应商商品的属性，不在售价体系内，定价时作为参考，但不参与售价计算。

"零售价""窗口价"不是独立的价格点，而是**不同维度组合下的不同价格点**（L0/L1）。

### 1.2 成本与售价体系的关系

**`costPrice`（成本价）不在价格体系内，是定价参考。**

```
┌─────────────────────────────────────────────────────────┐
│                    SupplierProduct                      │
│  costPrice: 50元  ← 供应商成本，定价时参考，游客不可见   │
└─────────────────────────────────────────────────────────┘
```

成本价由供应商设定，是进货/采购成本。售价体系（L0/L1/L2）由商户/分销商独立设定，两者是**平行关系**，不是叠加关系。

---

### 1.3 售价体系三层结构

售价体系只关心"卖给游客/渠道的金额"，与成本价无关：

```
┌─────────────────────────────────────────────────────────┐
│              L0 默认价格点（无维度键）                   │
│  定义：这个 SKU 的默认售价，不依赖任何维度。             │
│  一个 SKU 一个 L0，所有维度列 = NULL                     │
└─────────────────────────────────────────────────────────┘
                          │ 维度覆盖
                          ▼
┌─────────────────────────────────────────────────────────┐
│          L1 维度价格点（有维度键，直接写金额）            │
│  定义：某些维度下，直接定义新价格点，覆盖 L0。           │
│  不是"在 L0 上加价"，是直接写新金额。                   │
│  维度组合可以是（固定列 + ext_dims JSON）：               │
│    {date} / {dateRange} / {weekday} / {channel} /      │
│    {date, channel} / {date, ext_dims.roomType} / ...    │
└─────────────────────────────────────────────────────────┘
                          │ 交易时计算
                          ▼
┌─────────────────────────────────────────────────────────┐
│          L2 定价规则（可选，少数场景用参考计算）          │
│  定义：某些场景下，不想直接写金额，而是"参考另一个价格   │
│        来算"。这是可选的便利工具，不是必须的。           │
│  例：分销结算价 = retail × 0.85                         │
└─────────────────────────────────────────────────────────┘
```

**关键设计决策：**

- 渠道、日期、房型、座位等级——都是 L1 的维度键，完全平等
- L0/L1 覆盖所有"直接定价"场景，L2 规则覆盖"参考计算"场景
- 新增维度 = 写入 `ext_dims` JSON，不改表结构
- `costPrice` 是供应商商品的属性，**不是售价体系的一部分**

---

## 二、数据模型

### 2.1 SupplierProduct（供应商商品，成本基础）

`costPrice` 是供应商商品的属性，**不是售价体系的一部分**。它是定价时的成本参考，定价时商户会在 `costPrice` 之上加毛利来确定 L0 默认价，但两者存储和计算完全独立。

```
SupplierProduct（供应商商品）
├── skuId:      所属 SKU
├── costPrice:  成本价（分），定价参考，不在售价体系内
└── supplierId: 供应商 ID
```

**说明：** `costPrice` 是供应商的进货/采购成本，游客不可见，不参与售价计算。定价时商户自行决定在成本价之上加多少毛利，写入 L0 默认价。

---

---

### 2.2 PricePoint（价格点，售价体系 L0/L1）

#### 领域模型

**价格点 = 某个维度组合下的一个金额。** 每条价格点记录对应一个维度组合，直接存储最终售价，不存差价、不加计算。

```
PricePoint（价格点）
├── skuId:         所属 SKU
├── 固定维度（独立列，可索引）:
│   ├── channel:       渠道（如 retail / counter / ota_meituan）, NULL=L0默认价
│   ├── dateSingle:    单日精确匹配（如 2026-07-05）
│   ├── dateFrom:      日期区间起始（如 2026-07-01）
│   ├── dateTo:        日期区间终止（如 2026-09-30）
│   ├── weekdayMask:   星期掩码（bit0=周一..bit6=周日, 工作日=31/周末=96）, NULL=不限
│   └── extDims:       动态维度（JSON，如 {"roomType":"大床房","seatLevel":"A区"}）
├── price:          金额（分）
├── priority:       优先级（数值大优先）
└── effectiveFrom / effectiveTo: 生效时间范围
```

**字段说明：**

| 字段                              | 说明                                                                                                                         |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `skuId`                         | 所属 SKU                                                                                                                     |
| `dimensionKey`                  | 维度键，决定这条价格点在什么条件下生效。L0 默认价 = 所有维度列均为 NULL。固定维度（channel/date_single/date_from/date_to/weekday_mask）为独立列，动态维度在 ext_dims JSON |
| `price`                         | 该维度组合下的售价（分），直接存最终金额，不存差价                                                                                                  |
| `priority`                      | 优先级，数值大优先。多个价格点同时命中时，取 priority 最高的                                                                                        |
| `effectiveFrom` / `effectiveTo` | 生效时间范围，支持按时间启用/停用价格点                                                                                                       |
| `version`                       | 版本号，支持定价规则的生效与撤销                                                                                                           |

**维度键说明：**

| 维度类型 | 字段                    | 示例                                   | 说明                         |
| ---- | --------------------- | ------------------------------------ | -------------------------- |
| 单日   | `dateSingle`          | `2026-07-05`                         | 节假日特殊价、演出逐日价               |
| 日期区间 | `dateFrom` + `dateTo` | `2026-07-01 ~ 2026-09-30`            | 旺季统一定价                     |
| 星期几  | `weekdayMask`         | `31`(工作日) / `96`(周末)                 | bit0=周一..bit6=周日, 应用层位运算匹配 |
| 渠道   | `channel`             | `retail` / `counter` / `ota_meituan` | 渠道专属价                      |
| 动态维度 | `extDims`（JSON）       | `{"roomType":"大床房"}`                 | 房型/座位等级/舱位等，业态相关           |

**priority 默认值：**

- 单日精确匹配：10
- 日期区间匹配：5
- 星期匹配：3
- 无维度键（L0 默认价）：0

数值越大，优先级越高。商户可手动调整。

> **物理实现**：5 个固定维度提取为独立列（channel/date_single/date_from/date_to/weekday_mask），支持索引粗筛。
> weekday_mask 不走 SQL 过滤（位运算无法走 B-tree 索引），在应用层对 <10 行候选集做位运算匹配。

---

#### L0 与 L1 的关系

```
L0 默认价：所有维度列 = NULL（无维度约束）
          price = 10000（兜底价）

L1 维度价格点：channel = "ota_meituan"（其他维度列 NULL）
               price = 11000（覆盖 L0，只影响 OTA 渠道）
```

L1 不是"在 L0 上加价"，是**直接写新金额**。查询时，命中 L1 就用 L1 的金额，完全不碰 L0。

---

### 2.3 定价规则（L2，可选）

#### 统一领域模型

**定价规则 = 对基准价施加一种计算，得到最终价。**

三类规则（分销结算 / 预约加价 / 会员折扣）共用一个模型，通过 `ruleType` + `calculator` 区分行为。

```
PricingRule（定价规则）
├── ruleType:       规则类型（MARGIN / SURCHARGE / DISCOUNT / MEMBER_DISCOUNT）
├── basePriceRef:   基准价引用（RETAIL / COUNTER / BASE / CURRENT）
├── calculator:     计算方式（PERCENT / FIXED / MATRIX）
├── params:         计算参数（JSON，结构随 ruleType + calculator 变化）
├── priority:       优先级（数值大优先）
└── effectiveFrom / effectiveTo: 生效时间范围
```

**字段说明：**

| 字段                              | 说明                                                                              |
| ------------------------------- | ------------------------------------------------------------------------------- |
| `ruleType`                      | 规则类型：`MARGIN`（分销结算）/ `SURCHARGE`（预约加价）/ `DISCOUNT`（折扣）/ `MEMBER_DISCOUNT`（会员折扣） |
| `basePriceRef`                  | 基准价引用：`RETAIL`（零售价）/ `COUNTER`（窗口价）/ `BASE`（期票基础价）/ `CURRENT`（当前价）              |
| `calculator`                    | 计算方式：`PERCENT`（按比例）/ `FIXED`（固定金额）/ `MATRIX`（日历矩阵）                              |
| `params`                        | 计算参数，JSON 结构随规则类型变化                                                             |
| `priority`                      | 规则优先级，数值大优先。多个规则同时命中时，按 priority 决定生效顺序                                         |
| `effectiveFrom` / `effectiveTo` | 生效时间范围                                                                          |

---

#### params 结构示例

**分销结算（MARGIN + PERCENT）**

```json
{
  "distributorId": "meituan",
  "calculator": "PERCENT",
  "percent": 0.15
}
```

含义：结算价 = 基准价 × (1 - 0.15)

---

**预约加价（SURCHARGE + MATRIX）**

```json
{
  "basePrice": 10000,
  "calculator": "MATRIX",
  "matrix": {
    "2026-07-05": 2000,
    "2026-10-01": 5000
  }
}
```

含义：最终价 = 基础价 + matrix[预约日期]

---

**会员折扣（MEMBER_DISCOUNT + PERCENT）**

```json
{
  "memberLevel": "GOLD",
  "calculator": "PERCENT",
  "percent": 0.1
}
```

含义：折扣价 = 当前价 × (1 - 0.1)

---

#### 计算引擎

```
function applyRule(rule, basePrice, context):
    if rule.calculator == "PERCENT":
        return basePrice × (1 - rule.params.percent)
    if rule.calculator == "FIXED":
        return basePrice + rule.params.fixedAmount
    if rule.calculator == "MATRIX":
        return basePrice + rule.params.matrix[context.date]
```

---

---

## 三、价格查询逻辑

### 3.1 单日价格查询

**目标：** 给定 `skuId` + `date` + `channel` + `ext_dims`，返回最匹配的价格。

**步骤：**

```
function queryPrice(skuId, date, channel, extDims):
    // step1: 用固定维度列走索引，粗筛候选集
    candidates = DB.query("""
        SELECT * FROM price_point
        WHERE sku_id = ?
          AND effective_from <= NOW() AND effective_to >= NOW()
          AND (
            date_single = ?                           -- 单日精确匹配
            OR (date_from <= ? AND date_to >= ?)      -- 区间匹配
            OR (weekday_mask & ? != 0)                -- 星期匹配
            OR (date_single IS NULL AND date_from IS NULL AND weekday_mask IS NULL)  -- L0 默认价
          )
        ORDER BY priority DESC
    """, [skuId, date, date, date, weekdayMask(date)])

    // step2: 应用层精筛（channel + ext_dims）
    for candidate in candidates:
        if matchChannel(candidate.channel, channel) 
           AND matchExtDims(candidate.ext_dims, extDims):
            return candidate.price

    // step3: 未命中，返回 null（调用方决定是报错还是回退）
    return null
```

**matchChannel 逻辑：**

```
若 candidate.channel 为空 → 匹配任何 channel（L0 默认价）
若 candidate.channel = 查询 channel → 匹配
否则 → 不匹配
```

**matchExtDims 逻辑：**

```
若 candidate.ext_dims 为空 → 匹配任何 extDims
若 candidate.ext_dims 包含查询 extDims 的所有键值 → 匹配
否则 → 不匹配
```

### 3.2 批量日历价格查询（30天）

**目标：** 给定 `skuId` + `dateFrom` + `dateTo` + `channel` + `extDims`，返回每天的价格。

**步骤：**

```
function queryCalendarPrices(skuId, dateFrom, dateTo, channel, extDims):
    // step1: 一次性查出所有候选价格点
    candidates = DB.query("""
        SELECT * FROM price_point
        WHERE sku_id = ?
          AND effective_to >= ?
          AND effective_from <= ?
          AND (
            date_single BETWEEN ? AND ?
            OR (date_from <= ? AND date_to >= ?)
            OR weekday_mask IS NOT NULL
            OR (date_single IS NULL AND date_from IS NULL AND weekday_mask IS NULL)
          )
        ORDER BY priority DESC
    """, [skuId, dateFrom, dateTo, dateFrom, dateTo, dateFrom, dateTo])

    // step2: 逐天匹配
    result = []
    for date in dateRange(dateFrom, dateTo):
        price = matchBestPrice(candidates, date, channel, extDims)
        result.append({date, price})

    return result
```

**性能：** 一次查询 + 应用层逐天匹配，30天 <50ms。

### 3.3 分销商结算价查询

**目标：** 给定 `skuId` + `distributorId` + `date`，返回结算价。

**步骤：**

```
function queryDistributorSettlePrice(skuId, distributorId, date):
    // step1: 优先查 FIXED 模式（L1 价格点）
    pricePoint = queryPrice(skuId, date, channel="dist_" + distributorId, extDims={})
    if pricePoint exists:
        return pricePoint

    // step2: 查 MARGIN 模式（L2 规则）
    pricingRule = DB.query(PricingRule, {skuId, ruleType: "MARGIN", distributorId})
    if pricingRule exists:
        basePrice = queryPrice(skuId, date, channel=pricingRule.basePriceRef, extDims={})
        if marginRule.ruleType == "MARGIN_FIXED":
            return basePrice - marginRule.ruleParam
        else if marginRule.ruleType == "MARGIN_PERCENT":
            return basePrice * (1 - marginRule.ruleParam)

    // step3: 均无，回退零售价或报错
    return queryPrice(skuId, date, channel="retail", extDims={})
```

---

## 四、场景验证

### 4.1 设置场景

#### S01：景区门票，按区间+星期设置价格

> 商户说：6月工作日50元，周末80元；7-9月工作日80元，周末120元

**L0 默认价（6月工作日）：**

```json
{"sku_id": "SKU_001", "date_single": null, "date_from": null, "date_to": null, "weekday_mask": 31, "channel": null, "ext_dims": null, "price": 5000, "priority": 3}
```

**6月周末价：**

```json
{"sku_id": "SKU_001", "weekday_mask": 96, "price": 8000, "priority": 3}
```

**7-9月区间价（覆盖6月）：**

```json
{"sku_id": "SKU_001", "date_from": "2026-07-01", "date_to": "2026-09-30", "weekday_mask": 31, "price": 8000, "priority": 5}
```

**7-9月周末价：**

```json
{"sku_id": "SKU_001", "date_from": "2026-07-01", "date_to": "2026-09-30", "weekday_mask": 96, "price": 12000, "priority": 5}
```

**查询 7月5日（周日）：**

- 区间+周末匹配，priority=5 → 12000

**查询 7月2日（周四）：**

- 区间+工作日匹配，priority=5 → 8000

✅ 覆盖。

#### S02：景区门票，按具体日期设置价格

> 商户说：10月1日-10月7日每天150元；其中10月3日特殊，180元

**区间价：**

```json
{"sku_id": "SKU_001", "date_from": "2026-10-01", "date_to": "2026-10-07", "price": 15000, "priority": 5}
```

**单日特殊价：**

```json
{"sku_id": "SKU_001", "date_single": "2026-10-03", "price": 18000, "priority": 10}
```

**查询 10月3日：**

- 单日匹配，priority=10 > 区间 priority=5 → 18000

✅ 覆盖。

#### S03：酒店，按房型+区间+星期设置价格

> 商户说：7月1日-9月30日，工作日大床房300元、标间250元；周末大床房350元、标间300元

**工作日大床房：**

```json
{"sku_id": "SKU_005", "date_from": "2026-07-01", "date_to": "2026-09-30", "weekday_mask": 31, "ext_dims": {"roomType": "大床房"}, "price": 30000, "priority": 5}
```

**工作日标间：**

```json
{"sku_id": "SKU_005", "date_from": "2026-07-01", "date_to": "2026-09-30", "weekday_mask": 31, "ext_dims": {"roomType": "标间"}, "price": 25000, "priority": 5}
```

**周末大床房：**

```json
{"sku_id": "SKU_005", "date_from": "2026-07-01", "date_to": "2026-09-30", "weekday_mask": 96, "ext_dims": {"roomType": "大床房"}, "price": 35000, "priority": 5}
```

✅ 覆盖。

#### S04：渠道专属价

> 商户说：OTA渠道（美团）价格比零售价高5%

**方案A：FIXED 模式，直接写 OTA 渠道价格点**

```json
{"sku_id": "SKU_001", "channel": "ota_meituan", "price": 6300, "priority": 1}
```

**方案B：MARGIN 模式，L2 规则**

```json
{"sku_id": "SKU_001", "distributor_id": "meituan", "rule_type": "MARGIN_PERCENT", "rule_param": 0.05, "base_price_ref": "retail"}
```

✅ 覆盖，两种方案可选。

### 4.2 使用场景

#### U01：列表页展示双价（当前渠道价 + 划线价）

> 用户在分销商A的小程序里看商品列表，展示当前渠道价 + retailPrice 划线

**查询逻辑：**

1. 批量查当前渠道价 → `queryPrice(skuId, date, channel="dist_A", extDims)`
2. 批量查 retailPrice → `queryPrice(skuId, date, channel="retail", extDims)`
3. 前端展示：当前渠道价粗体，retailPrice 划线

✅ 覆盖。

#### U02：商品详情页，日历每天价格

> 用户进入景区门票详情页，点开日历，看到每天的价格

**查询逻辑：**

1. `queryCalendarPrices(skuId, dateFrom, dateTo, channel, extDims)`
2. 联合库存查询，过滤无库存日期
3. 前端渲染日历

**返回示例：**

```json
{
  "skuId": "SKU_001",
  "calendar": [
    {"date": "2026-07-01", "price": 8000, "hasStock": true},
    {"date": "2026-07-02", "price": 8000, "hasStock": true},
    {"date": "2026-07-05", "price": 12000, "hasStock": false}
  ]
}
```

✅ 覆盖。

#### U03：演出详情页，按天展示场次+价格

> 用户进入演出详情页，点开日历，看到某天有哪些场次，每场的价格（按座位等级）

**查询逻辑：**

1. 查某日期的所有价格点 → `WHERE sku_id = ? AND (date_single = ? OR date_from <= ? AND date_to >= ?)`
2. 按 `timeSlot` 分组（从 `ext_dims` 提取）
3. 每个场次按 `ext_dims.seatLevel` 展示价格

**返回示例：**

```json
{
  "date": "2026-07-05",
  "shows": [
    {
      "timeSlot": "14:00",
      "prices": [
        {"seatLevel": "A区", "price": 30000, "hasStock": true},
        {"seatLevel": "B区", "price": 20000, "hasStock": true}
      ]
    }
  ]
}
```

✅ 覆盖。

#### U04：期票预约加价

> 用户买了一张期票（基础价100元），预约7月5日入园，看到加价20元

**查询逻辑：**

1. 读 L0 基础价 → `queryPrice(skuId, anyDate, channel="retail", extDims={})`
2. 查 L2 `PricingRule(ruleType=SURCHARGE)` → `params.matrix["2026-07-05"]` = 2000
3. 展示：基础价100 + 加价20 = 120

✅ 覆盖。

---

## 五、全业态适配验证

| 业态        | L0 默认价 | L1 维度键                                            | L2 规则                          | 说明          |
| --------- | ------ | ------------------------------------------------- | ------------------------------ | ----------- |
| 景区门票      | L0默认价  | `{date}` / `{dateRange}` / `{weekday}`            | 无                              | 日历价覆盖       |
| 酒店        | L0默认价  | `{dateRange, weekday, ext_dims.roomType}`         | 连住折扣（L2）                       | 每日每房型独立价    |
| 剧场演出      | L0默认价  | `{date, ext_dims.seatLevel}` 或 `{date, timeSlot}` | 无                              | 每场次每座位等级独立价 |
| 游船轮渡      | L0默认价  | `{date, ext_dims.cabinClass}`                     | 无                              | 每航次每舱位等级独立价 |
| 餐饮产品      | L0默认价  | `{ext_dims.mealPeriod}`                           | 无                              | 按时段定价       |
| 电影票       | L0默认价  | `{weekday, ext_dims.timeSlot}`                    | 无                              | 星期+时段       |
| 旅游线路      | L0默认价  | `{date, ext_dims.segment}`                        | 无                              | 按行程段定价      |
| 年卡/旅游券    | L0默认价  | 无                                                 | 无                              | SKU级固定价     |
| 分销 FIXED  | —      | `{channel: "dist_*"}`                             | 无                              | 分销商固定结算价    |
| 分销 MARGIN | —      | —                                                 | `PricingRule(ruleType=MARGIN)` | 分销商相对结算价    |

---

## 六、缓存策略

### 6.1 热点价格缓存

```
Redis Key: price:{skuId}:{date}:{channel}:{extDims_hash}
TTL: 5分钟

示例：
price:SKU_001:2026-07-05:retail:null → 8000
price:SKU_001:2026-07-05:counter:null → 7000
price:SKU_005:2026-07-05:retail:roomType=大床房 → 30000
```

### 6.2 日历价格缓存

```
Redis Key: price:calendar:{skuId}:{month}:{channel}:{extDims_hash}
TTL: 5分钟

示例：
price:calendar:SKU_001:2026-07:retail:null → [{"date":"2026-07-01","price":8000}, ...]
```

### 6.3 缓存失效

- 价格点新增/更新/删除 → 主动失效相关缓存键
- 定时任务：每天凌晨清理过期缓存

---

## 七、与现有系统的对照

| 现有字段/表              | 对应新模型                                                                 | 说明                     |
| ------------------- | --------------------------------------------------------------------- | ---------------------- |
| `sku.retail_price`  | `PricePoint(channel=NULL, 日期全NULL).price`                             | L0 默认价                 |
| `sku.counter_price` | `PricePoint(channel="counter", 日期全NULL).price`                        | L1 渠道维度价               |
| `sku.cost_price`    | `SupplierProduct.costPrice`                                           | 不是价格体系                 |
| 日历价表                | `PricePoint(date_from/date_to 非空)`                                    | L1 维度价格点               |
| 分销结算价表              | `PricePoint(channel="dist_*").price` 或 `PricingRule(ruleType=MARGIN)` | FIXED = L1，MARGIN = L2 |

---

## 八、待讨论问题

1. **`ext_dims` JSON 的查询性能**：如果某个 SKU 有 1000+ 价格点，应用层遍历精筛会不会慢？
   
   - **答**：固定维度已提取为独立列（channel/date_single/date_from/date_to/weekday_mask），SQL 走索引粗筛后候选集通常 <10 条。weekday_mask 位运算 + ext_dims JSON 匹配在 <10 行上开销可忽略。
   - 如果业态真的有 1000+ 价格点，考虑把该维度升为固定列

2. **价格快照 `OrderPriceSnapshot`**：下单时快照最终价，历史订单不受后续调价影响
   
   - 本方案未包含，需补充

3. **价格变更审计**：谁在什么时候改了价格，改前改后是什么
   
   - 建议用 `version` 字段 + 价格变更日志表

4. **与库存的联合查询**："最早有库存+有价格的日期"
   
   - 本方案未包含，需独立设计查询接口

---

## 附录：时段（timeSlot）的查询逻辑

**结论：时段不需要升为固定列，查询逻辑是先找到 SKU 的价格，再按时段提取。**

**原因：**

1. 没有"按时段搜索价格"的场景，都是"找到 SKU → 看这个 SKU 有哪些时段的价格"
2. 时段是 `ext_dims` 里的一个字段，跟 `roomType`/`seatLevel` 同构
3. 升为固定列会增加表的固定列数量，但查询性能提升有限（因为都是先按 SKU+日期过滤）

**示例：查演出 7月5日 19:00 场 A区价格**

```sql
-- step1: 粗筛（走索引）
SELECT * FROM price_point
WHERE sku_id = 'SKU_006'
  AND (date_single = '2026-07-05' OR (date_from <= '2026-07-05' AND date_to >= '2026-07-05'))
ORDER BY priority DESC;
```

**应用层精筛：**

```python
target_dims = {"timeSlot": "19:00", "seatLevel": "A区"}
for candidate in candidates:
    if candidate.ext_dims matches target_dims:
        return candidate.price
```

✅ 覆盖，不需要升为固定列。
