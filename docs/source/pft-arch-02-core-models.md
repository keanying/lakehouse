# PFT 2.0 核心模型

> **CHAPTER 02 · CORE MODELS**

> 核心数据长什么样？本文档定义订单/票/凭证/权益四层模型、票属性元数据、库存四层分层抽象、基准价+维度覆盖价格体系、统一账户与票级冻结。

## 四层模型 · 票是一等公民 · 属性元数据 · 库存四层分层 · 价格体系 · 资金模型

> 所有交易复杂性的根源——套票、补录实名、按票核销、按票冻结——都汇聚到"订单 → 票 → 权益 / 凭证"这条主轴上。本节是整个架构的核心。

---

## § 3.1 订单 · 票 · 凭证 · 权益 四层模型

> OrderGroup → Order → Ticket → Entitlement + Credential

### 完整模型树

```text
═══════════════════════════════════════════════════════════════════════
【订单树】OrderGroup → Order → Ticket（TicketCredential + Person + Entitlement）
═══════════════════════════════════════════════════════════════════════

OrderGroup（聚合单）                            ◄── 一次购物车结算，多 SKU 一起下单容器
├── sellerTenantId          卖家租户（商品归属）     ◄── 聚合单冗余，与子单同值
├── channelId               入口端ID              ◄── Channel-First模型，指向 t_channel
├── channelRef              端内子标识             ◄── 小程序=mp_config_id / API=子渠道号 / 其他=空
├── operatorType            操作人类型             ◄── CUSTOMER / TENANT_STAFF
├── operatorId              操作人ID               ◄── 多态：customer_id 或 tenant_staff_id
├── operatorTenantId        操作人所属租户         ◄── =会话 tenant_context_id
├── buyerType               付款方类型             ◄── CUSTOMER / ANONYMOUS
├── buyerId                 付款方ID               ◄── 多态；ANONYMOUS 时=0
├── buyerCustomerId         C端筛选冗余（带索引）  ◄── buyerType=CUSTOMER 时 =buyerId，否则=0
├── contact                 取票人/联系人           ◄── 订单层概念
├── paymentRecords[]        支付记录列表            ◄── 支持组合支付
└── currency                币种（=卖家租户配置）
│
└── Order（子单）                                ◄── 每种SKU一条，套票拆主+N子
    ├── parentOrderNo        套票子单指向主单号     ◄── 非套票子单=空串，套票主单=空串，套票子项=主单号
    ├── comboFlag              是否套票主单           ◄── true=套票主单，false/null=普通
    ├── sellerTenantId      卖家商户             ◄── 每个子单归属一个商户（支持购物车多商户）
    ├── skuId / skuName / quantity / unitPrice
    ├── orderStatus          PENDING_PAY → PAID → ... → REFUNDED
    │
    └── Ticket（票，一等公民）                   ◄── 1:N，每张票独立生命周期
        ├── ticketStatus     AVAILABLE → PARTIALLY_USED → USED → EXPIRED → REFUNDED
        ├── validPeriod      有效期 {start,end}（出票时确定 或 首次核销时延迟确定start）
        ├── passPolicy       放行策略（从SKU继承）
        ├── metadata         业态扩展字段（演出游船seatInfo等业态特有字段均在此）
        │
        ├── TicketCredential[]（票凭证）           ◄── 路径一：随票生灭的码值，出票时码池分配
        │   ├── credentialType   QR_CODE / BAR_CODE
        │   ├── codeValue        码值（码池分配）
        │   ├── codePoolId       归属码池
        │   └── status           ACTIVE / EXPIRED / REVOKED
        │
        ├── Person[]（票上的人）                  ◄── 0~N人，通过 globalCustomerId 关联到 Customer
        │   ├── personId / name / idType / idNumber / phone
        │   ├── globalCustomerId → 关联到 Customer（首次登录才建 Customer，未登录=0）
        │   └── isPrimary     是否主游客
        │
        ├── Entitlement[]（权益列表）              ◄── 核销最小单元，6种类型，类型特有参数在entitlement_detail JSON中
        │   ├── FIXED        固定型：核销1次即完成（detail={}）
        │   ├── SELECTABLE   选择型：N选M（detail含maxCount+candidateRefs）
        │   ├── COUNTED      计次型：可用N次（detail含maxCount）
        │   ├── TIMED        计时型：首次核销启动计时（detail含durationMinutes）
        │   ├── UNLIMITED    不限次型：有效期内无限次（detail={}）
        │   └── QUOTA        额度型：扣减额度（detail含quotaAmount）
        │
        └── PersonEntitlementBinding[]（人-权益绑定）  ◄── 三角关系核心
            ├── personId         null=开放争抢
            ├── entitlementNo
            └── bindingType      EXCLUSIVE / SHARED / OPEN

═══════════════════════════════════════════════════════════════════════
【用户树】Customer（C端）+ TenantStaff（B端）+ Channel（接入端）
═══════════════════════════════════════════════════════════════════════

Customer（C端主账号）                            ◄── 租户内识别（self-tenant 隔离），广播表
├── customerNo             全局客户编号
├── customerKind           REAL / TENANT_DEFAULT ◄── REAL=真人注册账号；TENANT_DEFAULT=业务租户代下单占位买家（非真用户，是订单buyer字段占位符）；PLATFORM租户不设占位买家（default_customer_id=0）
├── 强识别字段              wechatUnionid/alipayUserId/phone/idNumber（NULL允许并存）
├── authStatus             UNAUTHENTICATED / PHONE_VERIFIED / PERSON_CERTIFIED
│
├── identities[]（多渠道身份识别）              ◄── 一个 Customer 可有 N 个渠道 openid
│   ├── identityType       WECHAT_OPENID / DOUYIN_OPENID / OTA_UID / ALIPAY_OPENID
│   ├── identityValue      具体标识值
│   ├── bindChannelId      产生该标识的接入端
│   └── bindTenantId       产生该标识的租户上下文
│
├── tenantBindings[]（游客-租户绑定）           ◄── 游客在每个租户下唯一一条
│   ├── tenantId
│   ├── tenantOpenid       在该租户小程序的 openid
│   └── bindingStatus      ACTIVE / REVOKED
│
└── credentials[]（个人凭证）                   ◄── 路径二：人脸/身份证，跨订单复用
    ├── credentialType   ID_CARD / FACE
    ├── codeValue        证件号 / faceToken
    └── status           ACTIVE / REVOKED

TenantStaff（B端员工，含平台员工）               ◄── 按 tenant_id 分片
├── staffNo / tenantId / name / phone / passwordHash
├── isOwner               商户主账号标识（每租户默认1个）
├── staffType             OWNER/ADMIN/OPERATOR/VERIFIER/FINANCE/SUPER_ADMIN/OPS/CUSTOMER_SERVICE
└── mfaEnabled           （平台租户员工建议开启）
    └── 超管判定（双因子）：tenant_no='PLATFORM' 租户下的员工 AND RBAC SUPER_ADMIN 角色 → 平台超管

Tenant（租户，广播表）
├── tenantNo / tenantName  (平台租户约定 tenant_no='PLATFORM')
├── defaultCustomerId       该租户默认散客账号ID（业务租户→TENANT_DEFAULT代下单占位；PLATFORM租户=0 不设占位）
└── currency/locale     商户配置币种与locale

Channel（接入端，广播表；Channel-First 统一接入）
├── channelCode         MP_TENANT_HOSTED / MP_PLATFORM / PC_TENANT / PC_PLATFORM / OFFLINE / API_XXX
├── channelType         MP / PC / API / OFFLINE / H5
├── channelScope        PLATFORM(服务商级) / TENANT(租户级如API对接)
├── ownerTenantId       端归属租户（scope=TENANT时必填）
├── appKey / appSecret  接入密钥（API端必填）
└── defaultOperatorStaffId  API端必填，无 staffCode 时兜底

TenantMpConfig（租户小程序 appId 配置，广播表）
├── tenantId
├── mpType              WECHAT_MP / WECHAT_MINI / ALIPAY_MINI / DOUYIN_MINI
└── appId / appSecret   小程序凭证（appId 全平台唯一）

═══════════════════════════════════════════════════════════════════════
【两条核销路径】
═══════════════════════════════════════════════════════════════════════

路径一·二维码：扫码 → TicketCredential → Ticket → Entitlement → 核销
路径二·人脸：  刷脸 → Customer.credentials → Customer → Person(globalCustomerId) → Ticket → Entitlement → 核销
```

### LAYER 01 · ORDER_GROUP — 聚合单

一次"购物车结算"的根聚合，承载支付、票务集合、营销活动归集。`orderGroupNo` 是支付幂等键的来源，财务对账以此为顶层维度。

| 字段               | 说明                                                                                     |
| ---------------- | -------------------------------------------------------------------------------------- |
| orderGroupNo     | 聚合单号，支付幂等键来源，格式OG+yyyyMMdd+6位随机                                                        |
| sellerTenantId   | 卖家租户（商品归属租户；子单同值，聚合单层冗余便于报表）                                                           |
| channelId        | 入口端ID（指向 t_channel：MP_TENANT_HOSTED/MP_PLATFORM/PC_TENANT/PC_PLATFORM/OFFLINE/API_XXX） |
| channelRef       | 端内子标识（小程序=tenant_mp_config_id / API=子渠道号 / 其他=空串）                                      |
| operatorType     | 操作人类型：CUSTOMER(C端会员) / TENANT_STAFF(B端员工含平台员工)                                         |
| operatorId       | 操作人ID（多态：customer_id 或 tenant_staff_id）                                                |
| operatorTenantId | 操作人所属租户ID（=会话 tenant_context_id；C端时=渠道端所属租户或=sellerTenantId）                           |
| buyerType        | 付款方类型：CUSTOMER(会员或业务租户默认散客占位) / ANONYMOUS(线下现金无主体)                                     |
| buyerId          | 付款方ID（多态；ANONYMOUS=0）                                                                  |
| buyerCustomerId  | C端筛选冗余：buyerType=CUSTOMER 时 =buyerId，否则=0（带索引报表用）                                      |
| contact          | 取票人/联系人（姓名+手机+可选证件）                                                                    |
| totalAmount      | 总金额（=各paymentRecords金额之和）                                                              |
| currency         | 币种（=卖家租户配置币种，MVP阶段不做换算）                                                                |
| paymentRecords   | 支付记录列表（支持组合支付：每笔含支付方式/金额/流水号/支付时间，如微信100+现金50）                                         |
| payStatus        | 支付状态                                                                                   |
| createTime       | 创建时间                                                                                   |

> **代下单归属**：员工代客户下单时，`buyerType=CUSTOMER` + `buyerId=业务租户.defaultCustomerId`（TENANT_DEFAULT 占位）。平台客服代下单时，游客已在 PFT 平台强制注册为 REAL 账号，直接用其 `customer_id`（不走 PLATFORM 占位）。OTA API 代下单（美团/携程）走 `ANONYMOUS`（buyer_id=0，OTA 那边有用户）。

> **卖家在子单**：以下"卖家商户不在聚合单层"的说明为历史结论，实际 v2 已在聚合单层冗余 `sellerTenantId`（值=各 Order.sellerTenantId；购物车多商户是极端场景，聚合单本身单商户）。分账仍按各 Order.sellerTenantId 拆分。跨商户不在 OrderGroup 设计意图内；如需跨商户，本版本要求分单。

### LAYER 02 · ORDER — 订单 / 子单

每一种 SKU（含套票主子）一条 Order；套票拆出主单 + N 个子单；子单是"业务流程的承载"，状态机覆盖待支付 → 已支付 → 部分核销 → 全核销 → 退款等。

> **套票主单定位澄清**：套票的主单是 Order（子单层），**不是 OrderGroup（聚合单层）**。OrderGroup 的语义是"一次购物车结算/支付行为"，与是否套票无关；套票主单的语义是"一种套票 SKU 的业务实体"，有自己的 sellerTenantId 和状态机。购物车同时买套票+单票时，两者平等地挂在同一个 OrderGroup 下。
> 
> **套票拆单规则**：不管子项是否跨商户，一律拆出主 Order + N 个子 Order。统一规则，无分支判断，模型简单、程序简单、处理简单。主 Order 承载套票 SKU（comboFlag=true）、套餐总价、编排定义；每个子 Order 承载一个子项 SKU、分摊价、独立 sellerTenantId（支持跨商户分账）。子 Order 通过 `parentOrderNo` 指向主 Order。

| 字段             | 说明                                                                     |
| -------------- | ---------------------------------------------------------------------- |
| orderNo        | 子单号，格式ORD+yyyyMMdd+6位随机                                                |
| orderGroupNo   | 归属聚合单号                                                                 |
| parentOrderNo  | 套票子单指向主单号，非套票子单=空串                                                     |
| comboFlag      | 是否套票主单（true=套票主单，false/null=普通子单或套票子项子单）                               |
| sellerTenantId | 卖家商户（每个子单归属一个商户，支持购物车多商户）                                              |
| skuId          | SKU标识                                                                  |
| skuName        | SKU名称                                                                  |
| quantity       | 购买数量                                                                   |
| unitPrice      | 单价（套票主单=套餐总价，套票子单=分摊价）                                                 |
| orderStatus    | 状态：PENDING_PAY → PAID → PARTIALLY_VERIFIED → FULLY_VERIFIED → REFUNDED |

**套票订单结构示例 · 酒景套票（1晚酒店+2张门票）**：

```text
OrderGroup（聚合单）                       ◄── 一次支付行为，支付幂等键
├── buyerId: 游客张三
├── totalAmount: 500元
├── paymentRecords: [{微信, 500元}]
│
├── Order-COMBO（套票主单）                  ◄── 套票SKU，comboFlag=true
│   ├── parentOrderNo: null                ◄── 主单无父
│   ├── sellerTenantId: 套票发布商户
│   ├── skuId: SKU-COMBO-001
│   ├── quantity: 1, unitPrice: 500元       ◄── 套餐总价
│   ├── comboFlag: true
│   ├── orderStatus: PAID
│   └── Ticket-COMBO-01（主票）              ◄── 承载编排定义+整体有效期
│       ├── persons: [张三, 李四]
│       ├── entitlements: []               ◄── 主票不含具体权益，权益下沉到子票
│       ├── validPeriod: {6.25, 6.26}      ◄── 套票整体有效期边界
│       └── ticketCredentials: [套票码]     ◄── 从套票码池发码
│
├── Order-HOTEL（酒店子单）                   ◄── 酒店SKU，套票子项
│   ├── parentOrderNo: Order-COMBO.orderNo       ◄── ★ 指向套票主单号
│   ├── sellerTenantId: 酒店商户             ◄── 可与主单不同商户
│   ├── skuId: SKU-HOTEL-001
│   ├── quantity: 1, unitPrice: 300元       ◄── 分摊价
│   ├── orderStatus: PAID
│   └── Ticket-HOTEL-01
│       ├── persons: [张三, 李四]
│       ├── entitlements: [FIXED 住宿1晚]
│       ├── personEntitlements: [张三→住宿 SHARED, 李四→住宿 SHARED]
│       ├── validPeriod: {6.25晚}           ◄── 收窄：仅25日晚
│       └── ticketCredentials: [住宿码]
│
└── Order-TICKET（门票子单）                   ◄── 门票SKU，套票子项
    ├── parentOrderNo: Order-COMBO.orderNo       ◄── ★ 指向套票主单号
    ├── sellerTenantId: 景区商户             ◄── 可与主单不同商户
    ├── skuId: SKU-TICKET-001
    ├── quantity: 2, unitPrice: 100元       ◄── 分摊价
    ├── orderStatus: PAID
    ├── Ticket-TICKET-01
    │   ├── persons: [张三]
    │   ├── entitlements: [FIXED 成人入园]
    │   ├── personEntitlements: [张三→入园 EXCLUSIVE]
    │   ├── validPeriod: {6.25~6.26}
    │   └── ticketCredentials: [门票码1]
    └── Ticket-TICKET-02
        ├── persons: [李四]
        ├── entitlements: [FIXED 成人入园]
        ├── personEntitlements: [李四→入园 EXCLUSIVE]
        ├── validPeriod: {6.25~6.26}
        └── ticketCredentials: [门票码2]
```

> **为什么主票不承载具体权益**：套票主票只承载编排定义（哪些子项、整体有效期）和套票码（一码通/索引码）。具体权益下沉到各子票的 Entitlement，这样每个子票的核销、退款、冻结都是独立的——酒店子票核销不影响门票子票，门票部分退款只释放门票子票的冻结记录。主票状态由子票聚合计算。
> 
> **主票也有一种用法**：如果套票所有子项同商户、且游客希望"扫一个码就能看到所有权益"，主票也可以承载全部 Entitlement（如家庭票示例），此时不拆子 Order，只有主 Order+主票。但**默认规则是拆子单**，主票承载权益仅作为简化特例，适用于同商户+不需独立退款/核销的场景。

### LAYER 03 · TICKET — 票（独立实体）

**票作为独立实体是一等公民**。1 个 Order 在不实名时即可生成 N 张 Ticket，每张票有独立 `ticketNo`、独立的 Persons 与 Entitlements 绑定关系、独立核销状态、独立利润冻结记录。补录实名只更新 Ticket.persons，不破坏 Order。

| 字段                   | 说明                                                                                  |
| -------------------- | ----------------------------------------------------------------------------------- |
| ticketNo             | 票号，格式TKT+yyyyMMdd+6位随机                                                              |
| orderNo              | 归属子单号                                                                               |
| ticketStatus         | AVAILABLE → PARTIALLY_USED → USED → EXPIRED → REFUNDED                              |
| persons[]            | 票上所有人（替代原 visitor 单字段），每项含 personId/name/idType/idNumber/phone/isPrimary            |
| entitlements[]       | 权益列表（见 LAYER 04）                                                                    |
| personEntitlements[] | 人-权益绑定关系：personId(null=开放争抢) → entitlementNo + bindingType(EXCLUSIVE\|SHARED\|OPEN) |
| ticketCredentials[]  | 票凭证列表（二维码/条形码，随票生灭，码池资源），每项含 credentialType/codeValue/codePoolId/status             |
| passPolicy           | 放行策略（从SKU票属性继承）                                                                     |
| validPeriod          | 有效期 `{start, end}`：票整体有效期边界，出票时确定（普通门票）或首次核销时延迟确定start（两天有效/年卡等场景）。展示与退款依据          |
| metadata             | 业态扩展字段（JSON，承载业态特有数据，由票属性元数据定义哪些字段必填）                                               |

**metadata 业态扩展字段定义**：

> 以下字段不属于 Ticket 核心模型，是特定业态的扩展数据，统一放入 `metadata` JSON 中。核心层不感知这些字段的结构和语义，仅透传存储；编排层各业态 Adapter 负责读写和校验。

| 扩展字段              | 适用业态      | 说明                      | 数据结构示例                                                 |
| ----------------- | --------- | ----------------------- | ------------------------------------------------------ |
| `seatInfo`        | 剧场演出、游船轮渡 | 座位/舱位信息，含排/列/号或舱位等级     | `{row:5, col:8, zone:"VIP"}` 或 `{cabin:"头等舱", deck:2}` |
| `cabinInfo`       | 游船轮渡      | 航次+舱位信息（与seatInfo合并或独立） | `{cruiseNo:"CR20260625", cabinType:"DELUXE"}`          |
| `routeSegments`   | 旅游线路      | 多日多段行程信息                | `[{day:1, poi:"景区A"}, {day:2, poi:"景区B"}]`             |
| `logistics`       | 旅游特产      | 物流发货信息（快递公司+单号）         | `{carrier:"SF", trackingNo:"SF123456"}`                |
| `reservationDate` | 预售券       | 预约后的具体游玩日期              | `"2026-10-01"`                                         |
| `scheduleTime`    | 剧场演出      | 场次时间                    | `"2026-06-25T19:30:00"`                                |

> **设计原则**：Ticket 核心字段只保留**所有业态共有的属性**（ticketNo / orderNo / ticketStatus / validPeriod / passPolicy / persons[] / entitlements[] / personEntitlements[] / ticketCredentials[] / metadata）。任何仅特定业态需要的字段一律放入 `metadata`，由票属性元数据（§ 3.2）声明该业态下 `metadata` 的必填字段 schema，编排层 Adapter 负责按 schema 校验和读写。
> 
> **关于有效期**：年卡"激活时间"、门票"入园后两天有效"等场景，不需要额外扩展字段——它们都是 `Ticket.validPeriod.start` 延迟确定的语义，首次核销时回填 start 并计算 end，统一收敛到核心字段。

**Person — 票上的人（一等公民）**：

```
📦 Person
├── personId           // 票内唯一标识
├── name               // 姓名
├── idType             // 证件类型
├── idNumber           // 证件号
├── phone              // 手机号
└── isPrimary          // 是否为主游客（用于联系/通知/客服查询，一张票最多一个）
```

**PersonEntitlementBinding — 人-权益绑定（三角关系核心）**：

```
📦 PersonEntitlementBinding
├── personId           // 绑定到哪个人，null=不绑定人（开放争抢）
├── entitlementNo      // 绑定到哪个权益
└── bindingType        // 绑定策略
    ├── EXCLUSIVE      // 专属绑定：该权益只属于此人，核销时校验身份匹配
    ├── SHARED         // 共享绑定：多人共享同一权益，任一绑定人核销即可消耗
    └── OPEN           // 开放争抢：不绑定具体人，谁持码谁消耗（计次/计时/额度型）
```

> **绑定策略可扩展**：三种策略覆盖当前全部业态场景，后续可按需新增（如 TRANSFERABLE 可转让、PRIORITY 优先级抢占等），通过 bindingType 枚举扩展，不破坏现有模型。

**游客信息归属原则**：

- `contact`（取票人）是 OrderGroup 层概念 — 谁来取票、联系电话
- `persons[]`（票上所有人）是 Ticket 层概念 — 谁持有这张票、享有哪些权益
- `personEntitlements[]`（人-权益绑定）是 Ticket 层概念 — 哪个人能用哪个权益、绑定策略是什么
- Entitlement（权益）层不直接记录游客信息 — 权益只管"能不能用、用了没"，通过绑定关系间接关联人

**Person-Entitlement 三角关系**：

> 当前模型的核心创新：`visitor` 不再是 Ticket 的单字段，而是升级为 `persons[]` 独立实体 + `personEntitlements[]` 绑定关系。一张票可以有多个 Person，每个 Person 通过绑定关系与 Entitlement 建立连接。

```
Ticket
├── persons[]                    // 票上的人（1~N）
│   ├── 父亲（isPrimary=true）
│   ├── 母亲
│   └── 孩子
├── entitlements[]               // 权益列表
│   ├── FIXED 成人门票#1
│   ├── FIXED 成人门票#2
│   ├── FIXED 儿童门票
│   └── FIXED 家庭午餐
└── personEntitlements[]         // 人-权益绑定（三角关系）
    ├── 父亲 → 成人门票#1  EXCLUSIVE   // 专属，核销校验父亲身份
    ├── 母亲 → 成人门票#2  EXCLUSIVE   // 专属，核销校验母亲身份
    ├── 孩子 → 儿童门票    EXCLUSIVE   // 专属，核销校验孩子身份
    ├── 父亲 → 家庭午餐    SHARED      // 共享，三人任一核销即可
    ├── 母亲 → 家庭午餐    SHARED
    └── 孩子 → 家庭午餐    SHARED
```

**三种绑定策略**：

| 策略            | 语义          | 核销校验逻辑                              | 典型场景                                          |
| ------------- | ----------- | ----------------------------------- | --------------------------------------------- |
| **EXCLUSIVE** | 权益专属某人      | 核销时校验 personId 身份匹配（人脸/证件），不匹配拒绝    | 家庭套票中父亲的成人票、景区实名票、年卡每人独立入园权益                  |
| **SHARED**    | 多人共享同一权益    | 任一绑定人核销即可消耗该权益，首次核销标记 USED，后续拒绝（去重） | 酒店入住人共享间夜、家庭午餐3人共享、套票必含项目共享                   |
| **OPEN**      | 不绑定人，谁持码谁消耗 | 不校验身份，校验码值+权益剩余次数/额度/时长             | 次卡不限人使用（COUNTED）、计时产品不限人（TIMED）、消费金不限人（QUOTA） |

> **核销流程变化**：原流程 `扫码→码值→Ticket→Entitlement→核销`，新流程分两条路径：
> 
> - **二维码核销**：`扫码→码值→查TicketCredential→Ticket→Entitlement→查PersonEntitlementBinding→EXCLUSIVE则校验身份匹配→核销`
> - **人脸/身份证核销**：`刷脸/刷卡→查CustomerCredential→全局Customer→查PersonEntitlementBinding(所有ACTIVE票)→匹配Entitlement→核销`

**放行策略 · PassPolicy**：

```
📦 PassPolicy（配置在 SKU 票属性上，出票时快照到 Ticket）
├── mode: MANUAL | AUTO          // 放行模式
│   ├── MANUAL: 系统记录核销，工作人员自行放行N人
│   └── AUTO: 系统记录核销 + 发送放行指令给闸机
├── passCount: number            // 放行人数（如双人票=2）
└── description: string          // 展示用（如"双人票，请放行2人"）
```

PassPolicy 层级继承规则：

- **主体在 Ticket 层**：从 SKU 票属性继承，覆盖 95% 场景（如"双人票全部放2人"）
- **权益层可选覆盖**：Entitlement 可设 `passCountOverride`，用于极少数特殊项目（如VR体验仅限1人）
- 核销取值逻辑：`entitlement.passCountOverride ?? ticket.passPolicy.passCount`

### LAYER 04 · ENTITLEMENT — 权益项（6 种类型）

每张 Ticket 包含 N 个 Entitlement，**权益是核销的最小单元**。权益类型决定核销行为。

#### 权益类型枚举

| 类型   | 英文           | 语义                 | 典型场景                   |
| ---- | ------------ | ------------------ | ---------------------- |
| 固定型  | `FIXED`      | 确定项目/服务，核销1次即完成    | 套票必含项目、门票入园、酒店间夜、餐饮兑换  |
| 选择型  | `SELECTABLE` | N个候选选M个，不可重复       | 18选10畅玩项目、自助餐N选M       |
| 计次型  | `COUNTED`    | 同一项目/入口可用N次        | 年卡入园30次、次卡游泳10次、停车365次 |
| 计时型  | `TIMED`      | 首次核销启动计时，时段内不限次    | 4小时水乐园、计时桌游、按时收费项目     |
| 不限次型 | `UNLIMITED`  | 有效期内无限次使用          | 年卡全年不限次入园、当日畅玩通票       |
| 额度型  | `QUOTA`      | 每次核销扣减不同数值，总额度用完截止 | 园区消费金¥100、游戏币200点      |

#### 有效期 · 双层机制

> "买了张票，两天有效"——有效期本质约束的是**权益在什么时间窗内可核销**，是核销规则的一部分。但票层需要一个有效期边界用于展示和退款计算。因此采用双层设计：

| 层级                        | 字段             | 语义       | 用途                                         |
| ------------------------- | -------------- | -------- | ------------------------------------------ |
| `Ticket.validPeriod`      | `{start, end}` | 票整体有效期边界 | 游客展示（"您的票6.25-6.26有效"）、退款计算（未过期可退）、票生命周期管理 |
| `Entitlement.validPeriod` | `{start, end}` | 权益核销时间窗  | 核销时校验 `now ∈ validPeriod`                  |

**约束规则**：`Entitlement.validPeriod ⊆ Ticket.validPeriod`（权益有效期必须在票有效期内，可收窄不可超出）

**核销校验**：`now ∈ Ticket.validPeriod`（兜底）且 `now ∈ Entitlement.validPeriod`（主判据）

**同一张票不同权益有效期不同**（套票场景）：

```
Ticket.validPeriod = {start: 6.25, end: 6.26}     // 两天有效
├── Entitlement 门票 UNLIMITED   validPeriod = {6.25, 6.26}    // 两天不限次
├── Entitlement 住宿 FIXED       validPeriod = {6.25, 6.25}    // 仅25日晚
└── Entitlement 早餐 FIXED       validPeriod = {6.26, 6.26}    // 仅26日早上
```

**validPeriod.start 的两种确定时机**：

| 场景              | start 确定时机 | 说明                                               |
| --------------- | ---------- | ------------------------------------------------ |
| 普通门票（当天/指定日有效）  | 出票时确定      | start = 游玩日期，end = start 或 start+N天              |
| 预售券（先买后约）       | 预约时确定      | start = 预约日期，出票时为 null                           |
| **入园后两天有效**     | 首次核销时确定    | start = 首次入园时间，end = start+2天。出票时 start=null     |
| **年卡（激活后365天）** | 首次核销时确定    | start = 首次使用激活时间，end = start+365天。出票时 start=null |

> 年卡"激活时间"、门票"入园后两天有效"等场景，统一收敛到 `Ticket.validPeriod.start` 延迟确定的语义，首次核销时回填 start 并计算 end，不需要额外扩展字段。

#### 各类型字段定义

**FIXED（固定型）**

```
📦 Entitlement · FIXED
├── entitlementNo
├── ticketNo
├── type: FIXED
├── validPeriod            // 有效期 {start, end}，核销时间窗（⊆ Ticket.validPeriod）
├── projectId              // 绑定的项目/服务
├── projectName            // 项目名称
├── status: AVAILABLE | USED
├── passCountOverride: null | number   // 可选覆盖票级放行人数
```

核销逻辑：now ∈ validPeriod 且 status == AVAILABLE → 标记 USED，记录核销事实。

**SELECTABLE（选择型）**

```
📦 Entitlement · SELECTABLE
├── entitlementNo
├── ticketNo
├── type: SELECTABLE
├── validPeriod            // 有效期 {start, end}，核销时间窗（⊆ Ticket.validPeriod）
├── candidateProjectIds[]  // 候选项目列表（如18个项目ID）
├── maxSelections          // 最多可核销次数（如10）
├── usedCount: 0           // 已核销次数
├── usedProjectIds: []     // 已核销项目ID列表（去重依据）
├── repeatPolicy: NO_REPEAT | ALLOW_REPEAT
├── status: AVAILABLE | PARTIALLY_USED | USED
├── passCountOverride: null | number
└── verifyRecords: []      // 核销明细记录
    // { projectId, verifiedAt, deviceId, operatorId }
```

核销逻辑：

1. now ∈ validPeriod（在有效期内）
2. projectId ∈ candidateProjectIds（是候选项目）
3. projectId ∉ usedProjectIds（未重复选，当 repeatPolicy=NO_REPEAT）
4. usedCount < maxSelections（未超上限）
5. 通过 → usedCount++, usedProjectIds.push(projectId)
6. usedCount == maxSelections → status=USED

**COUNTED（计次型）**

```
📦 Entitlement · COUNTED
├── entitlementNo
├── ticketNo
├── type: COUNTED
├── validPeriod            // 有效期 {start, end}，核销时间窗（⊆ Ticket.validPeriod）
├── projectId | scope      // 绑定的项目 或 scope=ANY
├── totalCount             // 总次数
├── usedCount: 0           // 已用次数
├── status: AVAILABLE | PARTIALLY_USED | USED
├── passCountOverride: null | number
└── verifyRecords: []      // 每次核销记录
```

核销逻辑：now ∈ validPeriod 且 usedCount < totalCount → usedCount++；usedCount == totalCount → status=USED。

**TIMED（计时型）**

```
📦 Entitlement · TIMED
├── entitlementNo
├── ticketNo
├── type: TIMED
├── validPeriod            // 有效期 {start, end}，约束首次核销的时间窗（⊆ Ticket.validPeriod）
├── projectId | scope      // 适用范围
├── duration               // 时长（分钟）
├── startedAt: null        // 首次核销时写入
├── expireAt: null         // startedAt + duration（计时到期，独立于validPeriod）
├── status: AVAILABLE | ACTIVE | EXPIRED
├── passCountOverride: null | number
└── verifyRecords: []
```

核销逻辑：

- 首次扫码：now ∈ validPeriod → startedAt=now, expireAt=now+duration → 放行，status=ACTIVE

- 后续扫码：now < expireAt? → 放行 : 拒绝（status=EXPIRED）
  
  > TIMED 有两个时间约束：validPeriod 约束"何时可以启动计时"，expireAt 约束"启动后多久到期"。两者独立——validPeriod 可能是"当天9-21点可启动"，duration 可能是"启动后4小时"。

**UNLIMITED（不限次型）**

```
📦 Entitlement · UNLIMITED
├── entitlementNo
├── ticketNo
├── type: UNLIMITED
├── validPeriod            // 有效期 {start, end}，核销时间窗（⊆ Ticket.validPeriod）
├── scope: [projectIds] | ALL  // 适用项目范围
├── status: AVAILABLE | ACTIVE | EXPIRED
├── passCountOverride: null | number
└── verifyRecords: []
```

核销逻辑：now ∈ validPeriod → 放行（不扣次），记录核销事实；now > validPeriod.end → status=EXPIRED。

**QUOTA（额度型）**

```
📦 Entitlement · QUOTA
├── entitlementNo
├── ticketNo
├── type: QUOTA
├── validPeriod            // 有效期 {start, end}，核销时间窗（⊆ Ticket.validPeriod）
├── quotaName              // 额度名称（如"园区消费金"）
├── totalQuota             // 总额度
├── usedQuota: 0           // 已消耗
├── remainingQuota         // 剩余 = total - used
├── unit: "元" | "点" | "币"
├── status: AVAILABLE | PARTIALLY_USED | USED
└── consumeRecords: []     // 每次消费记录
    // { amount, projectId, verifiedAt, deviceId }
```

核销逻辑：now ∈ validPeriod 且 remainingQuota ≥ amount → usedQuota+=amount；remainingQuota==0 → status=USED。

### 凭证体系 · 两种凭证的抽象分离

凭证分为两类，本质完全不同：

> **命名说明**：`TicketCredential` 译为"票凭证"，因其**挂在 Ticket 下、随票生灭**。之所以不叫"订单凭证"，是因为它不在 Order 层——出票时才生成，退款时随票回收，生命周期与 Ticket 绑定而非 Order。与之对偶的 `CustomerCredential`（个人凭证）挂在 Customer 下，生命周期独立于任何一笔订单。

| 维度       | TicketCredential（票凭证） | CustomerCredential（个人凭证） |
| -------- | --------------------- | ------------------------ |
| **本质**   | 资源分配产物 — 码池出码         | 身份认证载体 — 用户首次登录后认证       |
| **介质**   | QR_CODE / BAR_CODE    | ID_CARD / FACE           |
| **生命周期** | 随票生灭（出票→退款回收）         | 独立于订单（注册→主动注销）           |
| **复用性**  | 不可复用，每张票独立发码          | 跨订单复用，一次认证长期使用           |
| **归属层级** | 挂在 Ticket 下           | 挂在 Customer 下            |
| **状态驱动** | Ticket 生命周期驱动         | Customer 操作驱动            |

---

#### 路径一 · TicketCredential — 票凭证（二维码/条形码）

**本质**：二维码 / 条形码是**随票生灭的码值资源**。出票时从码池分配，退款时回收到码池。

```
📦 TicketCredential（挂在 Ticket.ticketCredentials[] 下）
├── credentialType     // QR_CODE | BAR_CODE
├── codeValue          // 码值（码池分配）
├── codePoolId         // 归属码池
└── status: ACTIVE | EXPIRED | REVOKED
    ├── ACTIVE   → 凭证有效，扫码可核销
    ├── EXPIRED  → Ticket 过期，凭证自动失效
    └── REVOKED  → 退款解绑，码值回收到码池
```

**录入机制**：

```
下单支付成功 → 出票（生成 Ticket）
    → 码池按商户+票类型分配码值（优先取回收队列，否则号段顺序+加扰+校验位）
    → 创建 TicketCredential，挂在 Ticket.ticketCredentials[] 下，status=ACTIVE
    → 码值写入短信/小程序展示给游客
```

> 关联时机：**出票时**，TicketCredential 天然挂在 Ticket 下，无需额外关联步骤。

**生命周期**：

```
出票(ACTIVE) → Ticket过期(EXPIRED) 或 退款(REVOKED+码值回收)
```

> 完全由 Ticket 驱动，没有独立于 Ticket 的存在意义——票在码在，票亡码亡。

**核销链路**：

```
扫码 → 码值校验位 → 查 TicketCredential(ACTIVE)
    → 定位 Ticket → 校验 Ticket 状态可核销
    → 查 Entitlement + PersonEntitlementBinding
    → EXCLUSIVE? → 校验 personId 身份匹配（走 Customer.credentials）
    → 核销权益
```

---

#### 路径二 · PersonCredential — 个人凭证（人脸/身份证）

**本质**：人脸特征值 / 身份证号是**C端会员的身份标识**，挂在 Customer 下。用户在租户小程序或平台小程序首次登录注册后采集，一次注册跨订单复用。

```
📦 CustomerCredential（挂在 Customer.credentials[] 下）
├── credentialType     // ID_CARD | FACE
├── codeValue          // 证件号（ID_CARD）/ faceToken（FACE）
├── status: ACTIVE | REVOKED
│   ├── ACTIVE   → 身份标识有效，可核销
│   └── REVOKED  → 用户主动注销/人脸模板删除
├── registeredAt       // 注册时间
└── revokedAt          // 注销时间
```

**录入机制**：

```
【场景一：用户提前注册（线上）】
用户在租户小程序或平台小程序登录 → 首次登录建 Customer → 实名认证（上传身份证/采集人脸）
    → 系统创建 CustomerCredential 挂在 Customer.credentials[] 下，status=ACTIVE
    → 此后用户下单任何支持人脸入园的景区，无需重复采集

【场景二：现场购票时采集（窗口/自助机）】
窗口下单 → 员工填写 persons[]（游客信息）→ 出票走完
    → 不主动为 person 建 Customer（下单不建 Customer，代下单也不建）
    → Person.globalCustomerId = 0（未关联）
【场景三：延迟关联】
    → 用户后续通过手机号首次登录小程序 → 建 Customer
    → 后台/客户端可按手机号回填 Person.globalCustomerId
```

> **关联规则**：Person 只在**首次登录时**才建 Customer（延迟建）。核销、代下单、窗口售票均不主动建 Customer。历史 Person 可通过手机号/身份证在用户登录时匹配回填 globalCustomerId。链路 `CustomerCredential → Customer → Person(globalCustomerId) → Ticket → Entitlement` 依然打通，只是关联建立时机推迟。

**生命周期**：

```
注册(ACTIVE) → 用户主动注销 / 人脸模板删除 → REVOKED
```

> 完全独立于订单，跨订单复用。用户更换手机、重新注册不影响已购票（票上 Person 仍关联原 Customer）。

**核销链路**：

```
刷脸/刷卡 → 查 Customer.credentials[](ACTIVE)
    → 定位 Customer → 通过 Person.globalCustomerId 查该 Customer 的所有 ACTIVE Ticket
    → 查 PersonEntitlementBinding，匹配当前闸机 scope 的 Entitlement
    → 校验 Entitlement 状态可核销 → 核销权益
```

---

#### 两条路径对比总结

```
【路径一：二维码核销】                     【路径二：人脸/身份证核销】

  下单出票                                    用户注册
    │                                           │
    ▼                                           ▼
  码池发码                                Customer.credentials[]
    │                                     采集人脸/绑定身份证
    ▼                                           │
  TicketCredential                               │
  挂在 Ticket 下                                 │
    │                                     下单时不主动关联 Customer；
    │                                     首次登录后通过手机号回填 globalCustomerId
    │                                           │
    ▼                                           ▼
  扫码核销                                   刷脸核销
  TicketCredential                           CustomerCredential
    → Ticket                                   → Customer
      → Entitlement                              → Person(globalCustomerId)
        → 核销                                     → Ticket
                                                    → Entitlement
                                                      → 核销
```

> 本质差异：二维码是 **"票凭证 → 票 → 权益"**，自上而下，凭证和票同生共死；人脸是 **"身份 → Customer → 票 → 权益"**，以人为中心向外辐射，凭证独立于任何一笔订单。

**码池 · 票凭证码值资源管理**：码池归属核销域→凭证与码池管理，解决码值唯一性、离线验票码段预分配、码资源回收复用。建池粒度为**商户+票类型**（单票池/套票池，不按SKU建池——码值只是标识符，核销时查Ticket获取票型/游客/权益）。发码优先取回收队列码复用，否则号段顺序分配+加扰置换表+校验位（顺序分配天然不重，O(1)恒定，优于随机生成去重的生日悖论问题）。退款时码回收到回收队列待复用，100万容量的池可支撑远超100万次累计发码。强约束：仅商户可配、单票套票不可混池、跨商户需平台审批、码值不编码业务信息。

### 凭证模型 · 全业态适配验证

> 验证凭证介质类型（QR_CODE/BAR_CODE/ID_CARD/FACE/无码）+ 码池分配策略如何覆盖全部13种业态，每个业态给出具体凭证发放与核验逻辑：

| 业态   | 凭证介质类型                                                         | 凭证发放逻辑                                                                    | 凭证核验逻辑（核销时）                                                                                                                                                  | 业态特化说明                                                              |
| ---- | -------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| 景区门票 | TicketCredential: QR_CODE + CustomerCredential: ID_CARD / FACE | 下单出票从单票码池发码（TicketCredential），或绑定游客身份证号/人脸（CustomerCredential挂在Customer下） | **二维码**：码值校验→查TicketCredential(ACTIVE)→Ticket状态→身份校验（实名票走Customer.credentials匹配）→核销；**人脸/身份证**：查Customer.credentials(ACTIVE)→定位Customer→查绑定→匹配Entitlement→核销 | 支持多介质：二维码扫码入园/身份证刷证入园/人脸识别入园，TicketCredential和CustomerCredential可并存 |
| 预售券  | TicketCredential: QR_CODE                                      | 下单从单票码池发码（TicketCredential），预约后validPeriod.start回填                        | 码值校验→查TicketCredential(ACTIVE)→当前日期在validPeriod范围内+Ticket状态可核销                                                                                               | 纯票凭证，无个人凭证参与                                                        |
| 套票   | TicketCredential: QR_CODE（1个套票码）或 QR_CODE×N（N个子票码）             | 下单从套票码池发码（TicketCredential）：发1个套票码（一码绑多权益）或N个子票码（每子权益1码），按套票编排定义          | 套票码：每次核销校验码+剩余权益计数；子票码：各子码独立校验                                                                                                                               | 套票码池与单票码池隔离（poolType），闸机按poolType判断核销次数策略                           |
| 旅游线路 | TicketCredential: QR_CODE（多日多段凭证）                              | 下单从单票码池发码（TicketCredential），凭证含多日多段行程信息                                   | 按行程天顺序核销，每日校验码+当日行程段匹配+Ticket状态                                                                                                                              | 一码多日多段，凭证metadata承载行程信息                                             |
| 酒店+  | 房卡（物理介质） + TicketCredential: QR_CODE（电子凭证）                     | 下单发TicketCredential电子凭证+办理入住发实体房卡                                         | 每日核销1个间夜权益：校验房卡/电子码+当日日期+Ticket间夜权益状态                                                                                                                        | 房卡为酒店业态特有物理介质，不进入凭证模型                                               |
| 度假酒店 | 房卡 + TicketCredential: QR_CODE + TicketCredential: 消费金码        | 下单发房卡+消费金TicketCredential（独立码），消费金码绑QUOTA权益                               | 间夜核销校验房卡；消费金核销校验消费金码+QUOTA剩余额度                                                                                                                               | 多TicketCredential：房卡（住宿）+消费金码（消费），各绑不同权益                            |
| 剧场演出 | TicketCredential: QR_CODE（含座位信息）                               | 下单编排层SeatMapSelectionActivity锁座后从单票码池发TicketCredential，metadata含seatInfo  | 核销校验码+seatInfo与入场匹配+Ticket状态                                                                                                                                 | 票凭证承载座位信息                                                           |
| 游船轮渡 | TicketCredential: QR_CODE（含航次舱位信息）                             | 下单编排层CruiseScheduleActivity校验航次后发TicketCredential，metadata含cabinInfo      | 核销校验码+航次时间匹配+cabinInfo与登船匹配+Ticket状态                                                                                                                         | 票凭证承载航次+舱位信息                                                        |
| 餐饮产品 | TicketCredential: QR_CODE（兑换凭证）                                | 下单从单票码池发TicketCredential                                                  | 核销校验兑换码+桌型/时段匹配+Ticket状态                                                                                                                                     | 纯票凭证                                                                |
| 年卡套餐 | CustomerCredential: FACE / ID_CARD（人脸/身份证，挂在Customer下）         | 下单发年卡，通过Customer.credentials采集人脸或绑定身份证号（不依赖码池）                            | 查Customer.credentials(ACTIVE)→定位Customer→查所有ACTIVE票绑定→匹配Entitlement→核销校验validPeriod+剩余权益                                                                     | 年卡以CustomerCredential为凭证（非码池码值），首次使用激活（回填validPeriod.start），跨订单复用   |
| 旅游特产 | 物流单号（非凭证模型）                                                    | 下单发物流发货凭证（快递单号），不进入凭证模型                                                   | 签收回执核销：物流签收状态回传作为核销依据                                                                                                                                        | 物流单号不入凭证体系                                                          |
| 计时产品 | TicketCredential: QR_CODE（计时凭证）                                | 下单从单票码池发TicketCredential                                                  | 首次核销启动计时（startedAt）；后续扫码校验码+未超时（now<expireAt）                                                                                                                | 纯票凭证，含计时信息                                                          |
| 旅游券  | TicketCredential: QR_CODE（券码）                                  | 下单从单票码池发券码（TicketCredential）                                              | 核销校验券码+券类型对应权益+Ticket状态                                                                                                                                      | 纯票凭证                                                                |

> 两种凭证覆盖全部业态：**TicketCredential**（票凭证，码池发码）覆盖~80%业态的扫码核销场景；**CustomerCredential**（个人凭证，人脸/身份证）覆盖实名制场景（景区/年卡），跨订单复用。房卡为酒店业态特有物理介质，不入凭证模型。物流单号不入凭证体系。码池按商户+票类型建池（单票池/套票池），核心层只提供通用发码/验码/回收原子能力，业态特化的座位图/航次/物流等凭证信息承载在Ticket.metadata，核心层不感知业态。

### 核心设计原则

**核销与放行解耦**：

- 核销层（系统强控制）：记录"用了什么权益"、去重校验、次数/额度扣减
- 放行层（策略可配）：放行几人由 PassPolicy 决定（MANUAL=人工放行，AUTO=系统指令）
- 两层独立，核销记录不因放行模式不同而有差异

**关键规则 · 不实名场景**：

- 下单时仅产出 Ticket，persons=[]（无绑定人）
- 所有权益绑定策略为 OPEN（不校验身份，谁持码谁消耗）
- 核销时按"先到先用"匹配空闲 Ticket
- 退款按 Ticket 粒度，未使用即可退

**关键规则 · 实名 / 套票 / 多人场景**：

- 下单或补录时填写 persons[]（一票可多人）
- 通过 personEntitlements[] 建立人-权益绑定关系
- EXCLUSIVE 绑定：核销时校验 personId 身份匹配
- SHARED 绑定：任一绑定人核销即可消耗权益（如酒店入住人共享间夜）
- 套票一律拆主 Order + N 个子 Order（不管是否跨商户），子 Order 通过 parentOrderNo 指向主 Order；各子 Order 各自 Ticket，独立核销/退款
- 子单可独立核销 / 退款，主单状态由子单聚合

**核销维度**：

- 最小核销粒度 = Entitlement，不再是 Ticket
- 支持区域闸机绑定 entitlement scope
- 离线核销带 device_id + 时序戳，回连后冲突仲裁

**冻结 / 退款维度**：

- FrozenRecord 按 Ticket 维度，金额 = 票上分摊利润
- 核销 → 解冻；全额退款 → 反向冻结
- 套票部分退按子单 Ticket 释放
- RefundDetail 记录每笔退款用了哪些支付记录、各退多少、支付中心退款流水号（退款去向跟踪）

### 订单角色分层模型

**核心思想：取票人(contact)是订单层概念，票上的人(persons[])是票层概念，两者分离。** 订单参与者采用多态字段组：`operatorType/Id + buyerType/Id/CustomerId + channelId/Ref + operatorTenantId + sellerTenantId`。支付方式通过 PaymentRecord 记录（支持组合支付，一笔订单可含多笔不同支付方式的支付记录），与"付款方主体"严格分离。

#### OrderGroup 层（订单级参与者字段组）

```
├── sellerTenantId    — 卖家租户（商品归属）
├── channelId         — 入口端（Channel-First：MP_TENANT_HOSTED/PC_TENANT/API_XXX 等）
├── channelRef        — 端内子标识（小程序=mp_config_id / API=子渠道号）
├── operatorType      — 操作人类型（CUSTOMER / TENANT_STAFF）
├── operatorId        — 操作人ID（多态）
├── operatorTenantId  — 操作人所属租户（=会话tenant_context_id）
├── buyerType         — 付款方类型（CUSTOMER / ANONYMOUS）
├── buyerId           — 付款方ID（多态；ANONYMOUS=0）
├── buyerCustomerId   — C端筛选冗余（buyerType=CUSTOMER 时=buyerId）
├── contact           — 取票人/联系人（姓名+手机+可选证件）
└── currency          — 币种（=卖家租户配置）
```

#### Ticket 层（票级）

```
├── persons[]           — 票上所有人（替代原visitor单字段，支持一票多人）
│   ├── personId/name/idType/idNumber/phone/isPrimary
│   ├── globalCustomerId — 首次登录后回填（0=未关联Customer）
│   └── 仅当票属性"实名制"开启时 persons[] 必填
├── personEntitlements[] — 人-权益绑定（EXCLUSIVE|SHARED|OPEN）
└── entitlements[]       — 权益列表
```

#### 五个典型场景映射表

| 场景            | channel_id                                    | operator                                          | buyer                                                        | contact / persons[]               |
| ------------- | --------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------ | --------------------------------- |
| 租户A的MP游客自购    | `MP_TENANT_HOSTED`（channelRef=A_mp_config_id） | `CUSTOMER: cust1`, opTenant=A                     | `CUSTOMER: cust1`（buyerCustomerId=cust1）                     | contact=游客C, persons=[C]          |
| 分销商B员工PC代下A的票 | `PC_TENANT`                                   | `TENANT_STAFF: B_staff`, opTenant=B               | `CUSTOMER: B.defaultCustomerId`（散客兜底）                        | contact=导游/游客, persons=[]或[游客...] |
| 美团API下A的票     | `API_MEITUAN`                                 | `TENANT_STAFF: 美团default_staff`, opTenant=美团租户    | `CUSTOMER: 美团租户.defaultCustomerId`                           | contact=张三, persons=[]或含游客        |
| 平台MP用户下A的票    | `MP_PLATFORM`                                 | `CUSTOMER: cust1`, opTenant=平台租户                  | `CUSTOMER: cust1`                                            | contact=cust1, persons=[cust1]    |
| 租户A窗口售A的票     | `OFFLINE`                                     | `TENANT_STAFF: A_staff`, opTenant=A               | `ANONYMOUS`（buyerId=0）                                       | contact=现场客户, persons按业务要求        |
| 平台客服代下A的票     | `PC_PLATFORM`                                 | `TENANT_STAFF: PLATFORM_staff`, opTenant=PLATFORM | `CUSTOMER: 游客自己在PFT注册的customer_id`（**REAL 实名**，不走PLATFORM占位） | contact=游客, persons=[]或[游客...]    |

> **代下单归属统一**：分销商员工/OTA API/平台员工代下单，buyer 一律归到"操作人所属租户的默认散客账号"（buyerType=CUSTOMER, buyerId=operatorTenant.defaultCustomerId）。这是符合业界实践的处理：代下单本身无法保证下单人真实身份，"取票人"和"游客信息"落在 contact 与 persons[] 层，不影响 buyer 分类。
> **分销垫付**：若业务上有"分销商垫付、后续跟客户单独结算"，走财务结算表（t_fund_flow / 应收应付明细），不污染订单 buyer 字段。
> | 酒店入住 | `游客C` | `游客C` | `游客C` | [`张三`,`李四`] | 张三→间夜 SHARED, 李四→间夜 SHARED |
> | 公司团购 | `HR` | `公司` | `HR` | 50个Ticket，各[`员工`] | 每个Ticket：员工→入园 EXCLUSIVE |

#### 实名制属性与角色的关系

| 实名制策略值       | contact（取票人） | ticket.persons[] | 绑定策略              |
| ------------ | ------------ | ---------------- | ----------------- |
| 无需实名         | 必填（至少手机号）    | `[]`             | OPEN（不绑定人）        |
| 需提供一位取票人身份信息 | 必填（姓名+证件）    | `[]`             | OPEN（不绑定人）        |
| 所有游客需填写身份信息  | 必填（手机）       | **每张票必填**（至少1人）  | EXCLUSIVE（按人专属绑定） |
| 取票人与所有游客填写   | 必填（姓名+证件）    | **每张票必填**（至少1人）  | EXCLUSIVE（按人专属绑定） |

### 订单·票·权益模型 · 全业态适配验证

> 验证 OrderGroup→Order→Ticket(Persons+Entitlements+PersonEntitlements) 四层模型 + 6种权益类型 + 3种绑定策略如何覆盖全部13种业态，每个环节给出具体验证逻辑：

| 业态          | 权益+绑定策略                                       | 售（下单校验）                                                         | 取（凭证生成）                                   | 检（核销规则·含身份校验）                                                                                       | 退（退款规则）                          |
| ----------- | --------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------- | --------------------------------------------------------------------------------------------------- | -------------------------------- |
| 景区门票（单人实名）  | FIXED + EXCLUSIVE                             | 选日期+数量，校验库存，persons=[C]，绑定C→FIXED EXCLUSIVE                     | 发码/身份证/人脸，凭证绑定Ticket                      | 查绑定→EXCLUSIVE→校验personId身份匹配→FIXED核销1次；闸机校验凭证+核销权限                                                  | 未核销全额退；已核销按退改策略                  |
| 景区门票（不实名）   | FIXED + OPEN                                  | 选日期+数量，校验库存，persons=[]，绑定null→FIXED OPEN                        | 发码                                        | 查绑定→OPEN→跳过身份校验→FIXED核销1次                                                                           | 未核销全额退                           |
| 预售券         | FIXED + OPEN                                  | 选数量不选日期，校验库存，persons=[]，绑定null→FIXED OPEN                       | 发码，预约后validPeriod.start回填                 | 校验validPeriod+绑定OPEN→FIXED核销1次                                                                      | 未核销在有效期内可退；过期自动退款/作废             |
| 套票（家庭票2大1小） | FIXED×3 + SHARED×1                            | 选套餐，persons=[父,母,孩]，成人票1→父EXCL、成人票2→母EXCL、儿童票→孩EXCL、午餐→三人SHARED | 发1个套票码或N个子票码                              | 成人票核销校验对应personId；午餐任一绑定人核销即消耗SHARED权益                                                              | 部分退：已核销子项不退，未核销子项按分摊价退           |
| 旅游线路        | FIXED×N + EXCLUSIVE                           | 选线路+日期，persons=[游客]，绑定游客→各日FIXED EXCLUSIVE                      | 发线路凭证（多日多段）                               | 按行程天顺序核销，EXCLUSIVE校验身份                                                                              | 按行程进度分摊退                         |
| 酒店+         | FIXED×N(间夜) + SHARED                          | 选入住日期+间夜数，persons=[张三,李四]，间夜→两人SHARED                           | 发房卡凭证                                     | 任一人刷卡核销间夜SHARED权益，退房时检查消费账户结清                                                                       | 未入住全退；已入住按间夜数分摊退                 |
| 度假酒店        | FIXED×N + SELECTABLE/QUOTA + SHARED+EXCLUSIVE | 选套餐，persons=[张,李]，间夜→SHARED，消费金→OPEN，SPA→EXCLUSIVE              | 发房卡+消费金凭证                                 | 间夜SHARED任一人核销；消费金OPEN不校验人；SPA EXCLUSIVE校验身份                                                         | 间夜分摊退；QUOTA已消耗不退；SELECTABLE未核销可退 |
| 剧场演出        | FIXED + EXCLUSIVE                             | 选场次+座位，persons=[游客]，绑定游客→FIXED EXCLUSIVE                        | 发电子票，metadata.seatInfo含座位信息               | EXCLUSIVE校验身份+metadata.seatInfo入场匹配，FIXED核销1次                                                       | 未核销按退改策略退；已核销不可退                 |
| 游船轮渡        | FIXED + EXCLUSIVE                             | 选航次+舱位，persons=[游客]，绑定游客→FIXED EXCLUSIVE                        | 发船票凭证，metadata含航次+舱位信息                    | EXCLUSIVE校验身份+航次时间+metadata.cabinInfo匹配，FIXED核销1次                                                   | 开航前按退改策略退；已开航不可退                 |
| 餐饮产品        | FIXED / SELECTABLE + OPEN                     | 选桌型+时段，校验库存，persons=[]，绑定OPEN                                   | 发兑换凭证                                     | OPEN跳过身份校验→FIXED核销1次兑换套餐；SELECTABLE在候选菜品中选≤maxSelections核销                                          | 未核销按退改策略退；已核销不可退                 |
| 年卡套餐（个人）    | UNLIMITED + COUNTED + QUOTA + EXCLUSIVE       | 选年卡类型，persons=[持卡人]，绑定持卡人→各权益EXCLUSIVE                          | 发年卡凭证（人脸/身份证绑定），出票时validPeriod.start=null | EXCLUSIVE校验持卡人身份→首次核销回填validPeriod.start→UNLIMITED在validPeriod内不限次入园；COUNTED每次usedCount++；QUOTA扣减额度 | 未激活全退；已激活按剩余validPeriod比例退       |
| 年卡套餐（家庭）    | UNLIMITED×3 + EXCLUSIVE×3                     | 选家庭年卡，persons=[父,母,孩]，每人→各自UNLIMITED EXCLUSIVE                  | 每人独立人脸/身份证绑定，出票时validPeriod.start=null    | 核销时校验对应personId身份→各自UNLIMITED在validPeriod内入园，互不干扰                                                   | 未激活全退；已激活按剩余validPeriod比例退       |
| 旅游特产        | FIXED + OPEN                                  | 选数量+收货地址，校验库存，persons=[]，绑定OPEN                                 | 发物流发货凭证（快递单号）                             | 签收回执核销FIXED（编排层LogisticsShipWorkflow跟踪签收状态），OPEN不校验人                                                | 未发货全退；已发货需退货退款                   |
| 计时产品        | TIMED + OPEN                                  | 选项目+数量，校验库存，persons=[]，绑定null→TIMED OPEN                        | 发计时凭证                                     | OPEN跳过身份→首次核销写入startedAt计时启动；超时status=EXPIRED                                                       | 未启动全退；已启动按剩余时长比例退                |
| 旅游券         | FIXED/SELECTABLE/QUOTA + OPEN                 | 选券类型，persons=[]，绑定OPEN                                          | 发券码凭证                                     | OPEN跳过身份→FIXED核销1次；SELECTABLE选核；QUOTA扣减额度                                                           | 未核销在有效期内可退；已核销不可退；过期作废           |

> 模型核心结构无需按业态调整，差异通过 Ticket 层 Persons+PersonEntitlements 绑定策略（EXCLUSIVE/SHARED/OPEN）和权益类型组合表达。上表验证逻辑均由核心层通用原子能力（库存校验/凭证发放/权益核销/身份校验/退款计算）+编排层业态扩展点（座位图/航次/物流等Adapter）协作完成，核心层不感知具体业态。

---

## § 3.2 票属性元数据体系

> 用元数据替代硬编码：每一条票属性都声明它影响哪些流程、与谁互斥。

```
📦 TicketMeta · 元数据定义
├── id            // 全局唯一 Code
├── name          // 显示名
├── value_type    // BOOL / ENUM / NUMBER / DATE / RANGE
├── default       // 默认值
├── scope         // 适用业态：景区/酒店/演出/线路…
├── impacts[]     // 声明式影响链
│   ├── ORDER     // 影响下单流程
│   ├── INVENTORY // 影响库存扣减
│   ├── PRICING   // 影响价格计算
│   ├── VERIFY    // 影响核销规则
│   └── REFUND    // 影响退款规则
├── conflicts[]   // 与哪些属性互斥
├── depends_on[]  // 依赖前置属性
└── ui_hint       // 前端联动规则 (group/show_if)
```

### 设计要点

- **声明优于编码**：新属性 = 新元数据 + 新规则配置，不需要发新版本
- **冲突检测前置**：商家配置 SKU 时即校验 conflicts / depends_on，杜绝运行时矛盾
- **影响链路可追溯**：任一属性变更都能反查影响哪些流程，自动化测试覆盖率可视化
- **前端联动声明化**：`ui_hint.show_if` 控制属性的展示与必填，避免硬编码表单
- **属性版本化**：保留历史版本，老订单按下单时的元数据快照执行

### 新增票属性的开发影响域

> 后台新增一个票属性，按影响范围分三种情况，绝大多数走情况一。

| 情况             | 触发条件               | 核心层                      | 编排层                      | 数据库                  | 典型示例                             |
| -------------- | ------------------ | ------------------------ | ------------------------ | -------------------- | -------------------------------- |
| **情况一**：编排配置   | impacts 已覆盖现有枚举    | **零改动**                  | Adapter 加校验/处理逻辑 + 元数据注册 | 不改（值存 metadata JSON） | 新增"提前预订天数"（impact=ORDER，已有）      |
| **情况二**：影响链扩展  | 引入了新的 impacts 维度   | impacts 枚举新增 + 影响链路引擎加分支 | Adapter 实现新分支逻辑          | 不改                   | 新增"影响通知发送"（需新增 NOTIFICATION 枚举值） |
| **情况三**：核心模型扩展 | 属性需要成为 Ticket 核心字段 | Ticket 模型扩展 + 全流程适配      | Adapter 适配新字段            | 加字段 + 迁移             | 新增一个所有业态共有的必填字段（极少见）             |

> **设计目标**：80%+ 的新增属性走情况一——核心层零改动，编排层 Adapter + 元数据注册即可上线。只有属性影响范围超出 `impacts` 现有枚举才需要动核心层，Ticket 核心字段扩展是最后的选项。

### 属性值类型枚举 · valueType

```
POLICY_CHOICE  // 单选策略（最常见，~80% 属性）
TOGGLE         // 开关 / 复选
NUMERIC        // 数值（人数、天数、金额）
TEXT           // 文本（票说明、短信内容）
DATE_RANGE     // 日期范围
```

### 条件可用性机制

- `enabledWhen`：某属性选项**在何条件下可用**（如「购票限制 → 限制」需先开启购票限制应用）
- `disabledWhen`：某属性选项**在何条件下被禁用**（与互斥属性同时选中时灰化）
- 声明式表达，前端联动与后端校验共享同一份规则定义

> **属性示例**：核销策略（整批/分批）是验证域最重要的票属性分歧点——整批入园按 OrderGroup 级联（一笔订单核销一张即全部核销），分批入园按 Ticket 独立流转。该属性影响状态机、退款分支、利润冻结释放粒度，必须在编排定义阶段固化，不可在运行时切换。

---

## § 3.3 库存模型 · 四层分层抽象

> 旅游行业所有库存，从底向上收敛为 4 层。核心设计原则：**越底层越通用，上层只提供组合能力，不引入新库存类型。**

### Layer 1 · 基础库存原子类型（物理资源的客观分类）

物理世界的资源只有两种形态，对应两种库存原子类型：

| 类型           | 语义                              | 扣减语义                | 典型场景                          |
| ------------ | ------------------------------- | ------------------- | ----------------------------- |
| **COUNTING** | 可数池：资源是 identical 的，不区分个体       | 数字 -N，不区分是哪个        | 景区日总量、酒店房量、餐饮桌数、年卡发售量         |
| **UNIT**     | 可标识池：资源是 distinct 的个体，必须区分"哪一个" | 锁定具体 `unit_no`，区分个体 | 演出座位（A排3座≠B排5座）、酒店具体房号、游船具体舱位 |

> CALENDAR / SHARED 不是独立的库存类型——CALENDAR 是 Layer 2 的维度键组合，SHARED 是 Layer 3 的组合策略。当前文档历史版本将两者列为"库存池策略"，系混淆了层级。

### Layer 2 · 池维度（系统内部机制，配置方不感知）

> 决定"建多少个池，每个池的粒度是多少"。配置方看到的是业务化选项（"按天限量""按场次排座"），系统自动翻译成维度键组合。

**维度键（Dimension Key）**：`(key₁, key₂, ...) → 池的唯一标识`。维度键类型不限时间，包括但不限于：

| 维度键类型 | 具体维度       | 典型场景            | 池标识示例                             |
| ----- | ---------- | --------------- | --------------------------------- |
| 时间    | 日期、时段      | 景区按天、餐饮按时段      | `(date)`                          |
| 事件    | 场次、航次      | 演出按场次、游船按航次     | `(show_id, show_time)`            |
| 空间    | 楼层、区域、场馆   | 演出按场馆分池         | `(venue_section)`                 |
| 实体属性  | 房型、舱位等级、票种 | 酒店按房型、游船按舱位     | `(date, room_type)`               |
| 组合    | 多维度交叉      | 餐饮按(日期, 时段, 桌型) | `(date, meal_period, table_type)` |

**池的生命周期**：按维度键自动建池（如新开一场演出自动建一个 UNIT 池），或按配置手动建池。

### Layer 3 · 多池组合策略（扣减时多个池之间的关系）

> 当一笔订单需要扣减多个池时，定义多个池之间的扣除关系。当前覆盖全部旅游业态的组合策略共 4 种：

| 策略             | 扣除语义                | 典型场景                 |
| -------------- | ------------------- | -------------------- |
| **AND**        | 所有池都有量才成功，任一不足则整体失败 | 套票：各子项库存全部充足才可成交     |
| **SEQUENTIAL** | 先扣 A 池，不足时穿透至 B 池   | 软配额：先扣渠道预留配额，用尽穿透至父池 |
| **RATIO**      | 按固定比例同步扣多个池         | 多渠道按比例分摊库存（较少见，预留扩展） |
| **OR**         | 任一池有量即成功            | 多仓库发货，任选一个有货的池（较少见）  |

### Layer 4 · 业务约束（规则层）

> 在 Layer 1-3 的基础能力之上，定义业务规则。

**配额模式**：

| 模式   | 语义                           |
| ---- | ---------------------------- |
| 硬配额  | 超出即拒绝，配额用尽不退回父池              |
| 软配额  | 用尽时穿透至父池（SEQUENTIAL 策略的具体实现） |
| 滚动配额 | T 时刻起按比例释放，避免囤量              |

**池生命周期管理**（库存池自身状态流转，独立于 Ticket 状态）：

```
可售 → 停售 → 过期
  │        │
  └─ 开售事件触发
           └─ 停售事件触发（手动停售 / 自动到期）
```

**原子操作语义**（Layer 1-3 所有池统一的三个操作）：

| 操作  | 语义          | 触发事件    |
| --- | ----------- | ------- |
| 预扣  | 占位，未最终扣减    | 下单      |
| 确认  | 预扣转正式扣减     | 核销      |
| 回滚  | 释放预扣 / 正式扣减 | 取消 / 退款 |

**并发控制**：

- 主存储 MySQL，热点写入走 Redis 预扣
- 核销 / 取消事件实时回滚预扣
- 分钟级对账，差异自动告警

---

### 库存模型 · 全业态适配验证

> 按 4 层分层逐一验证 13 种业态，每个业态给出 Layer 1-4 的完整映射：

| 业态     | L1 类型    | L2 维度键                                   | L3 组合          | 扣减/确认/回滚逻辑                  | 业态特化说明                                 |
| ------ | -------- | ---------------------------------------- | -------------- | --------------------------- | -------------------------------------- |
| 景区门票   | COUNTING | `(date)`                                 | 无（单池）          | 下单-N；核销不二次扣；退款+N            | 按日总量计数，国庆限流5000人/天即此模式                 |
| 预售券    | COUNTING | 无（永久有效）                                  | 无（单池）          | 下单扣总数；核销不扣；退款回滚             | 与景区门票同池，差异在 Ticket.validPeriod 控制可用日期  |
| 套票     | 各子项各自类型  | 各子项各自维度                                  | **AND**        | 下单逐子项校验+扣减；退款逐项+N回滚         | 下单需全部子项库存充足才可成交                        |
| 旅游线路   | COUNTING | `(date, segment)` 多日多段                   | 无（每段独立池）       | 下单逐日扣减；退款按已出行天数部分回滚         | 编排层 RouteSegmentActivity 协调多段联动        |
| 酒店     | COUNTING | `(date, room_type)`                      | 无（单池×N天）       | 下单逐日扣减；退款按未入住间夜回滚           | 多天=多个(date,room_type)池联动扣减             |
| 度假酒店   | UNIT     | `(date, room_type, unit_no)`             | 无（单池）          | 下单锁定具体房号；退款释放 unit_no 回池    | 需锁定具体房间号，UNIT 池管理实体房间                  |
| 剧场演出   | UNIT     | `(show_time, venue_section, seat_no)`    | 无（单池）          | 下单锁定座位；退款释放 unit_no 回池      | 座位图渲染由编排层 Adapter 承载，核心层只提供 UNIT 池原子能力 |
| 游船轮渡   | UNIT     | `(departure_time, cabin_class, unit_no)` | 无（单池）          | 下单锁定舱位；退款释放 unit_no 回池      | 航次排班逻辑由编排层 Adapter 承载                  |
| 餐饮产品   | COUNTING | `(date, meal_period, table_type)`        | 无（单池）          | 下单扣减；退款回滚                   | 时段过期自动释放预扣                             |
| 年卡套餐   | COUNTING | 无（永久有效）                                  | 无（单池）          | 下单扣发售总数；退款回滚（未激活）           | 年卡使用次数由 Entitlement 管理，与库存池无关          |
| 旅游特产   | COUNTING | 无（SKU 维度）                                | 无（单池）          | 下单扣实物库存；退款回滚（未发货）/退货入库（已发货） | 物流发货模式，签收状态由编排层跟踪                      |
| 计时产品   | COUNTING | 无（永久有效）                                  | 无（单池）          | 下单扣名额；退款回滚（未启动）/不回滚（已启动）    | 计时由 Entitlement.TIMED 管理，与库存池无关        |
| 旅游券    | COUNTING | 无（永久有效）                                  | 无（单池）          | 下单扣券发售总数；退款回滚               | 券使用由 Entitlement 管理，与库存池无关             |
| 分销共享库存 | COUNTING | `(date)` 或各自维度                           | **SEQUENTIAL** | 先扣子池配额，穿透父池                 | 软配额模式，L4 配额约束 + L3 SEQUENTIAL 策略       |

> 核心层只提供 Layer 1（COUNTING/UNIT 原子能力）和 Layer 3（4 种组合策略），不感知业态。Layer 2 维度键由编排层根据业态配置自动生成。业态特化的座位图/航次/线路/物流等逻辑由编排层 Adapter 承载。COUNTING 覆盖 ~70% 业态（纯计数场景），UNIT 覆盖需实体锁定的演出/游船/酒店房型，组合策略覆盖套票（AND）和分销（SEQUENTIAL）场景。

---

## § 3.4 价格体系 · 单金额价格点 + 维度键平等

> **核心结论**：价格 = "某个维度组合下的一个金额"。渠道、日期、房型、座位等级都是维度键，完全平等。三层结构：L0 默认价（无维度键）→ L1 维度价格点（直接定价，覆盖 L0）→ L2 定价规则（可选，参考计算）。

---

### 一、核心抽象

#### 价格是"某个维度组合下的一个金额"

**只有一个价格真正有意义：成交价。**

本方案只设计**售价体系**（卖给游客/渠道的金额）。成本价（`costPrice`）是供应商商品的属性，不在售价体系内，定价时作为参考，但不参与售价计算。

"零售价""窗口价"不是独立的价格点，而是**不同维度组合下的不同价格点**（L0/L1）。例如：

- 零售价 = `channel="retail"` 的价格点（L1）
- 窗口价 = `channel="counter"` 的价格点（L1）
- 某日零售价 = `date_single=2026-07-05, channel="retail"` 的价格点（L1）

#### 成本与售价体系的关系

`costPrice`（成本价）不在售价体系内，是定价参考：

```
┌─────────────────────────────────────────────────────────┐
│                    t_sku.cost_price                     │
│  costPrice: 50元  ← 供应商成本，定价时参考，游客不可见   │
└─────────────────────────────────────────────────────────┘
```

成本价由供应商设定。售价体系（L0/L1/L2）由商户/分销商独立设定，两者是**平行关系**，不是叠加关系。

#### 售价体系三层结构

售价体系只关心"卖给游客/渠道的金额"，与成本价无关：

```
┌─────────────────────────────────────────────────────────┐
│              L0 默认价格点（无维度键）                   │
│  这个 SKU 的默认售价，不依赖任何维度。                   │
│  一个 SKU 一个 L0，所有维度列 = NULL                     │
└─────────────────────────────────────────────────────────┘
                          │ 维度覆盖
                          ▼
┌─────────────────────────────────────────────────────────┐
│          L1 维度价格点（有维度键，直接写金额）            │
│  某些维度下，直接定义新价格点，覆盖 L0。                 │
│  不是"在 L0 上加价"，是直接写新金额。                   │
│  维度组合可以是（固定列 + ext_dims JSON）：               │
│    {date} / {dateRange} / {weekday} / {channel} /      │
│    {date, channel} / {date, ext_dims.roomType} / ...    │
└─────────────────────────────────────────────────────────┘
                          │ 交易时计算
                          ▼
┌─────────────────────────────────────────────────────────┐
│          L2 定价规则（可选，少数场景用参考计算）          │
│  不想直接写金额，而是"参考另一个价格来算"。             │
│  例：分销结算价 = retail × 0.85                         │
└─────────────────────────────────────────────────────────┘
```

**关键设计决策：**

- 渠道、日期、房型、座位等级——都是 L1 的维度键，完全平等
- L0/L1 覆盖所有"直接定价"场景，L2 规则覆盖"参考计算"场景
- 新增维度 = 写入 `ext_dims` JSON，不改表结构
- `costPrice` 是供应商商品的属性，**不是售价体系的一部分**

---

### 二、数据模型

#### 2.1 t_sku.cost_price（成本价，定价参考）

`costPrice` 是 SKU 的属性字段（`t_sku.cost_price`），**不是售价体系的一部分**。它是定价时的成本参考，定价时商户会在 `costPrice` 之上加毛利来确定 L0 默认价，但两者存储和计算完全独立。

```
t_sku（SKU票型）
├── skuId:      SKU ID
├── costPrice:  成本价（分），定价参考，不在售价体系内
└── ...
```

**说明：** `costPrice` 是供应商的进货/采购成本，游客不可见，不参与售价计算。定价时商户自行决定在成本价之上加多少毛利，写入 L0 默认价。

---

#### 2.2 PricePoint（价格点，售价体系 L0/L1）

**价格点 = 某个维度组合下的一个金额。** 每条价格点记录对应一个维度组合，直接存储最终售价。

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

| 字段                              | 说明                                                                              |
| ------------------------------- | ------------------------------------------------------------------------------- |
| `skuId`                         | 所属 SKU                                                                          |
| `dimensionKey`                  | 维度键（逻辑概念），决定价格点在什么条件下生效。L0 默认价 = 所有维度列 NULL。物理上 5 个固定维度为独立列，动态维度在 ext_dims JSON |
| `price`                         | 该维度组合下的售价（分），直接存最终金额                                                            |
| `priority`                      | 优先级，数值大优先                                                                       |
| `effectiveFrom` / `effectiveTo` | 生效时间范围                                                                          |

**维度键说明：**

| 维度类型 | 字段                    | 示例                                   | 说明                         |
| ---- | --------------------- | ------------------------------------ | -------------------------- |
| 单日   | `dateSingle`          | `2026-07-05`                         | 节假日特殊价、演出逐日价               |
| 日期区间 | `dateFrom` + `dateTo` | `2026-07-01 ~ 2026-09-30`            | 旺季统一定价                     |
| 星期几  | `weekdayMask`         | `96`(周末) / `31`(工作日)                 | bit0=周一..bit6=周日, 应用层位运算匹配 |
| 渠道   | `channel`             | `retail` / `counter` / `ota_meituan` | 渠道专属价                      |
| 动态维度 | `extDims`（JSON）       | `{"roomType":"大床房"}`                 | 房型/座位等级/舱位等                |

**priority 默认值：**

- 单日精确匹配：10
- 日期区间匹配：5
- 星期匹配：3
- 无维度键（L0 默认价）：0

---

#### 2.3 定价规则（L2，可选）

**统一领域模型：** 定价规则 = 对基准价施加一种计算，得到最终价。三类规则（分销结算 / 预约加价 / 会员折扣）共用一个模型。

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
| `priority`                      | 规则优先级，数值大优先                                                                     |
| `effectiveFrom` / `effectiveTo` | 生效时间范围                                                                          |

**params 结构示例：**

```json
// 分销结算（MARGIN + PERCENT）
{"distributorId": "meituan", "calculator": "PERCENT", "percent": 0.15}
// 含义：结算价 = 基准价 × (1 - 0.15)

// 预约加价（SURCHARGE + MATRIX）
{"basePrice": 10000, "calculator": "MATRIX", "matrix": {"2026-07-05": 2000}}
// 含义：最终价 = 基础价 + matrix[预约日期]

// 会员折扣（MEMBER_DISCOUNT + PERCENT）
{"memberLevel": "GOLD", "calculator": "PERCENT", "percent": 0.1}
// 含义：折扣价 = 当前价 × (1 - 0.1)
```

---

### 三、价格查询逻辑

#### 3.1 单日价格查询

**目标：** 给定 `skuId` + `date` + `channel` + `ext_dims`，返回最匹配的价格。

**步骤：**

```
1. 固定维度走索引，粗筛候选集（SQL WHERE 条件：date_single/date_from~to/weekday_mask/channel）
2. 应用层精筛：遍历候选集，匹配 channel + ext_dims，取 priority 最高的
3. 未命中返回 null（调用方决定报错或回退）
```

**匹配逻辑：**

- `channel` 匹配：candidate.channel 为空 → 匹配任何 channel（L0 默认价）
- `ext_dims` 匹配：candidate.ext_dims 为空 → 匹配任何 extDims

#### 3.2 批量日历价格查询（30天）

**步骤：**

```
1. 一次性查出所有候选价格点（SQL 用 BETWEEN + OR 覆盖单日/区间/星期）
2. 逐天匹配：对 dateFrom~dateTo 的每一天，调用单日匹配逻辑
3. 返回 [{date, price}, ...]
```

**性能：** 一次查询 + 应用层逐天匹配，30天 <50ms。

#### 3.3 分销商结算价查询

**步骤：**

```
1. 优先查 FIXED 模式（L1 价格点）：channel="dist_" + distributorId
2. 若无，查 MARGIN 模式（L2 规则）：读 PricingRule(ruleType=MARGIN)，按规则计算
3. 均无，回退零售价
```

---

### 四、场景验证

#### S01：景区门票，按区间+星期设置价格

> 商户说：6月工作日50元，周末80元；7-9月工作日80元，周末120元

**数据结构：**

- L0 默认价（6月工作日）：`{weekday_mask: 0b01111100, price: 5000, priority: 3}`
- 6月周末价：`{weekday_mask: 96, price: 8000, priority: 3}`
- 7-9月区间价：`{date_from: 2026-07-01, date_to: 2026-09-30, weekday_mask: 0b01111100, price: 8000, priority: 5}`
- 7-9月周末价：`{date_from: 2026-07-01, date_to: 2026-09-30, weekday_mask: 96, price: 12000, priority: 5}`

**查询 7月5日（周日）：** 区间+周末匹配，priority=5 → 12000 ✅

#### S02：景区门票，按具体日期设置价格

> 商户说：10月1日-10月7日每天150元；其中10月3日特殊，180元

**数据结构：**

- 区间价：`{date_from: 2026-10-01, date_to: 2026-10-07, price: 15000, priority: 5}`
- 单日特殊价：`{date_single: 2026-10-03, price: 18000, priority: 10}`

**查询 10月3日：** 单日匹配，priority=10 > 区间 priority=5 → 18000 ✅

#### S03：酒店，按房型+区间+星期设置价格

> 商户说：7月1日-9月30日，工作日大床房300元、标间250元；周末大床房350元、标间300元

**数据结构：**

- 工作日大床房：`{date_from: 2026-07-01, date_to: 2026-09-30, weekday_mask: 0b01111100, ext_dims: {roomType: "大床房"}, price: 30000, priority: 5}`
- 工作日标间：`{..., ext_dims: {roomType: "标间"}, price: 25000, ...}`
- 周末大床房：`{..., weekday_mask: 96, ext_dims: {roomType: "大床房"}, price: 35000, ...}`

✅ 覆盖。

#### S04：渠道专属价

> 商户说：OTA渠道（美团）价格比零售价高5%

**方案A（FIXED）：** 直接写 OTA 渠道价格点 `{channel: "ota_meituan", price: 6300}`
**方案B（MARGIN）：** L2 规则 `PricingRule {ruleType: MARGIN, calculator: PERCENT, params: {percent: 0.05}, basePriceRef: RETAIL}`

✅ 两种方案可选。

---

### 五、全业态适配验证

| 业态        | L0 默认价 | L1 维度键                                    | L2 规则                          | 说明          |
| --------- | ------ | ----------------------------------------- | ------------------------------ | ----------- |
| 景区门票      | L0默认价  | `{date}` / `{dateRange}` / `{weekday}`    | 无                              | 日历价覆盖       |
| 酒店        | L0默认价  | `{dateRange, weekday, ext_dims.roomType}` | 连住折扣（L2）                       | 每日每房型独立价    |
| 剧场演出      | L0默认价  | `{date, ext_dims.seatLevel}`              | 无                              | 每场次每座位等级独立价 |
| 游船轮渡      | L0默认价  | `{date, ext_dims.cabinClass}`             | 无                              | 每航次每舱位等级独立价 |
| 餐饮产品      | L0默认价  | `{ext_dims.mealPeriod}`                   | 无                              | 按时段定价       |
| 电影票       | L0默认价  | `{weekday, ext_dims.timeSlot}`            | 无                              | 星期+时段       |
| 分销 FIXED  | —      | `{channel: "dist_*"}`                     | 无                              | 分销商固定结算价    |
| 分销 MARGIN | —      | —                                         | `PricingRule(ruleType=MARGIN)` | 分销商相对结算价    |

---

### 六、价格快照机制

下单时快照最终价，历史订单不受后续调价影响：

```
OrderPriceSnapshot
├── orderNo
├── skuId
├── finalPrice        // 最终计算价（游客支付价）
├── settlePrice       // 分销商结算价（若有分销）
├── priceBreakdown    // 价格构成：{basePrice, calendarOverride, surcharge, ...}
└── snapshotAt        // 快照时间
```

退款/售后时以 `snapshot.finalPrice` 为基准计算退款金额，不重新查询实时价格。

---

### 七、与现有系统的对照

| 现有字段/表              | 对应新模型                                                                 | 说明                     |
| ------------------- | --------------------------------------------------------------------- | ---------------------- |
| `sku.retail_price`  | `PricePoint(channel=NULL, 日期全NULL).price`                             | L0 默认价                 |
| `sku.counter_price` | `PricePoint(channel="counter", 日期全NULL).price`                        | L1 渠道维度价               |
| `sku.cost_price`    | `t_sku.cost_price`                                                    | 不是价格体系                 |
| 日历价表                | `PricePoint(date_from/date_to 非空)`                                    | L1 维度价格点               |
| 分销结算价表              | `PricePoint(channel="dist_*").price` 或 `PricingRule(ruleType=MARGIN)` | FIXED = L1，MARGIN = L2 |

---

## § 3.5 资金模型 · 统一账户 + 票级冻结 + 支付渠道适配

> **核心设计原则**：支付中心是所有资金动作的统一入口；冻结随支付请求下发，到账即冻（非二次动作）；财务是纯账本执行者。

### 3.5.1 三层资金架构

```
┌──────────────────────────────────────────────────────────────┐
│  业务层（编排/订单）                                          │
│  • 算冻结金额（利润=售价-结算价）                              │
│  • 遍历分销链，组装批量支付请求（含INBOUND+OUTBOUND+冻结指令）    │
│  • 下单/核销/退款均通过支付中心，不直接碰财务                     │
└────────────────────────┬─────────────────────────────────────┘
                         │ /payment/batch-pay
                         ▼
┌──────────────────────────────────────────────────────────────┐
│  支付中心（pft-payment）                                      │
│  • 守恒校验（ΣINBOUND = ΣOUTBOUND + ΣFREEZE）                 │
│  • 渠道路由（PaymentChannelAdapter 策略模式）                   │
│  • 冻结指令随支付下发 → 渠道适配器翻译为渠道原生能力               │
│  • 两阶段执行：INBOUND到账→事务执行OUTBOUND链                  │
│  • 解冻/退款也是支付中心入口                                   │
└────────────────────────┬─────────────────────────────────────┘
                         │ 原子账务操作
                         ▼
┌──────────────────────────────────────────────────────────────┐
│  财务系统（pft-finance）—— 纯账本执行者                        │
│  • 记资金流水（t_fund_flow）                                  │
│  • 账户扣转/冻结/解冻（t_account.available/frozen）             │
│  • 建冻结记录（t_frozen_record）                               │
│  • 提现/对账                                                  │
│  • 不含业务编排逻辑（守恒校验/依赖顺序在支付中心）                 │
└──────────────────────────────────────────────────────────────┘
```

### 3.5.2 支付渠道适配器 · 冻结能力下沉

不同渠道对"冻结"的实现方式不同，但对支付中心接口契约一致。渠道适配器负责将"支付+冻结"语义翻译为渠道原生能力：

| 渠道类型 | 冻结实现方 | 机制 | 冻结策略 |
|---------|-----------|------|---------|
| 易宝/银联（分账型） | **第三方渠道** | 原生分账+冻结，T+1或解冻指令划账 | 策略A：原生冻结 |
| 平台余额 | **平台财务** | 内部账户间扣转，frozen_balance 冻住 | 策略B：内部冻结 |
| 微信/支付宝（代收型） | **平台财务** | 钱进平台代收户，平台自己冻利润 | 策略B：内部冻结 |
| 授信 | **平台财务** | 占用授信额度（不实际动现金），核销后才记应付 | 策略B：内部冻结 |
| 线下收款 | **平台财务** | 人工确认到账，平台自己冻利润 | 策略B：内部冻结 |

**渠道适配器接口**：

```java
public interface PaymentChannelAdapter {
    /** 执行支付（含冻结指令），渠道自行决定如何实现冻结 */
    PaymentResult pay(PaymentItem item);
    /** 解冻（核销时调用）：原生冻结→调第三方解冻API；内部冻结→调财务解冻 */
    UnfreezeResult unfreeze(UnfreezeRequest req);
    /** 退款+释放冻结（退款时调用） */
    RefundResult refund(RefundRequest req);
}
```

### 3.5.3 统一账户与票级冻结

```
   Account (主体账户)            FrozenRecord (按票冻结)
   ┌─────────────────────┐       ┌──────────────────────────────┐
   │ subject_id          │   1:N │ ticket_no                    │
   │ available_balance   │◀──────│ amount = 利润/采购款/全款      │
   │ frozen_balance      │       │ status = FROZEN/RELEASED      │
   │ kind = MERCHANT|... │       │ freezeType = PROFIT/SETTLEMENT/FULL │
   └─────────────────────┘       │ external_frozen = 0/1        │
            ▲                    │ event = VERIFY/REFUND        │
            │                    └──────────────────────────────┘
   资金流转场景                       
   ┌──────────────────────────────────────────────────────────────┐
   │ ① 下单支付(INBOUND)  → 钱到账即冻（利润/全款），available不变  │
   │ ② 采购扣转(OUTBOUND) → 批量原子：逐级扣转+冻结，事务保证      │
   │ ③ 核销发生           → frozen → available（按 ticket 解冻）  │
   │ ④ 全额退款           → 释放冻结 + 原路退回 + 反向退采购链      │
   │ ⑤ 部分退款           → 释放对应子单 ticket 的 frozen 记录     │
   │ ⑥ 提现申请           → 仅可基于 available_balance 发起       │
   │ ⑦ 授信购买           → 占用授信额度替代实付，核销后才记账     │
   │ ⑧ 0元单             → 走支付流程但不产生资金流水(ZERO_FEE)   │
   └──────────────────────────────────────────────────────────────┘
```

> **冻结随支付下发**：业务层在创建支付请求时已算好冻结金额（基于售价、结算价、分销链路），将冻结指令作为支付请求的一部分下发给支付中心。支付中心在渠道确认到账的瞬间，一次性向财务发起"入账+冻结"原子请求。不存在编排层二次触发冻结的动作。

> **同一张票在多个账户各有独立冻结记录**：4级分销链中，一张票(T001)在分销商D2冻利润15、在分销商D1冻利润5、在供应商S冻采购款80，三者独立记录，加起来=游客实付100（资金守恒）。

### 3.5.4 三类支付场景

| 场景 | INBOUND | OUTBOUND | 冻结 |
|------|---------|----------|------|
| ①供应商直销 | 游客→供应商(线下/在线) | 无（自己买自己卖） | 供应商冻全款(=利润) |
| ②分销商+现金采购 | 游客→分销商(线下) | 分销商→供应商(余额/授信) | 分销商冻利润，供应商冻采购款 |
| ③游客App+分销采购 | 游客→分销商(微信/支付宝) | 分销商→供应商(余额/授信) | 同② |

> 场景②和③的唯一区别在 INBOUND 的 receive_channel（CASH vs WECHAT）和 pay_method（OFFLINE vs WECHAT），资金记账模型完全一致。

### 3.5.5 批量支付 · 分销采购链

批量支付专用于分销采购链场景（单级分销为批量的特例=1条OUTBOUND）。支付中心内部维护依赖图，INBOUND到账后事务执行OUTBOUND链：

```
4级分销链示例（游客售价100 → D2结算价85 → D1结算价80 → S成本价70）：

批量请求:
  P1(INBOUND, WECHAT):  游客→D2, 100元, D2冻利润15
  P2(OUTBOUND, BALANCE): D2→D1, 85元,  D1冻利润5
  P3(OUTBOUND, BALANCE): D1→S,  80元,  S冻采购款80

守恒校验: 游客出100 = D2利润15 + D1利润5 + S收入80 ✓

执行:
  阶段一: P1(微信支付,异步等回调) → 回调到账 → D2收100(冻15, available+=85)
  阶段二(P1成功后,一个事务):
    P2: D2.available-=85, D1冻5(available+=80临时)
    P3: D1.available-=80, S冻80
    全部PaymentRecord=PAID
  任一失败 → 回滚已执行的+退款INBOUND
```

> **全同步渠道简化**：如果batch里全是同步渠道（线下+余额），无需两阶段，支付中心一个事务调财务执行全部扣转+冻结。

---

## § 3.6 风控域核心模型

> 风控是跨业务场景的通用能力，基于审计日志检测异常行为，对各服务暴露统一风控校验接口。覆盖：下单风控、提现风控、异常操作检测、账号封禁、爽约拉黑等。

### 核心模型

```
RiskRule（风控规则）
├── ruleId
├── ruleName          规则名称（如"凌晨操作检测"）
├── ruleType          BLACKLIST /PURCHASE_LIMIT / GEO_FENCE / ABnormal_OP / DEFAULT_BREAK
├── scope             GLOBAL（平台全局）/ TENANT（租户内）
├── dimension         USER_ID / ID_CARD / PHONE / IP / DEVICE_ID
├── dimensionValue    维度值（如身份证号、IP）
├── threshold         阈值（如"1小时内3次"）
├── timeWindow        时间窗口（秒）
├── action            BLOCK（拒绝）/ WARN（预警通知）/ FREEZE（自动冻结）
├── enabled           true/false
├── createdBy         PLATFORM_ADMIN / TENANT_ADMIN / SYSTEM
└── createdAt

Blacklist（黑名单）
├── blacklistId
├── dimension         USER_ID / ID_CARD / PHONE / IP
├── dimensionValue
├── reason            封禁原因
├── scope             GLOBAL / TENANT
├── bannedActions     EnumSet<ActionType>：下单/提现/核销/发品/登录（可组合）
├── expiresAt         过期时间（null=永久）
├── createdBy
└── createdAt

RiskEvent（风控事件日志）
├── eventId
├── eventType         RULE_HIT / MANUAL_BAN / MANUAL_UNBAN / ABNORMAL_OP_DETECTED
├── subjectId         主体ID（用户/商户）
├── dimensionValues   触发维度值集合
├── ruleId            关联规则（若为规则触发）
├── action            执行动作：BLOCK / WARN / FREEZE
├── detail            详细描述（如"身份证 320xxx 命中爽约黑名单"）
├── auditLogId        关联审计日志ID（反查原始操作）
└── createdAt

AccountBan（账号封禁记录）
├── banId
├── subjectId         被封禁主体（用户/商户）
├── banType           LOGIN（登录级）/ BUSINESS（业务操作级）
├── bannedActions     EnumSet<ActionType>
├── reason
├── source            RISK_RULE（规则自动）/ MANUAL（人工）
├── ruleId            关联规则（若自动触发）
├── expiresAt
├── status            ACTIVE / EXPIRED / REVOKED
├── revokedBy         解封人
├── revokedAt         解封时间
└── createdAt
```

### 风控校验接口（供各服务调用）

| 接口                                             | 调用方              | 时机                          |
| ---------------------------------------------- | ---------------- | --------------------------- |
| `POST /risk/check`                             | pft-order        | 下单前                         |
| `POST /risk/check`                             | pft-finance      | 提现申请前                       |
| `POST /risk/check`                             | pft-verification | 核销前（高频核销检测）                 |
| `POST /risk/report`                            | 所有写操作服务          | 操作完成后，写入 RiskEvent + 关联审计日志 |
| `GET /risk/blacklist/check?dimensionValue=xxx` | 所有服务             | 任意操作前，检查维度值是否在黑名单           |

### 与审计日志的关系

```
审计日志（pft-audit）
    ↓ 实时消费（CDC 或 MQ）
风控事件检测（pft-risk）
    ↓ 命中规则
生成 RiskEvent → 写入 Blacklist（如需封禁）→ 通知 pft-notification
```

> 风控强依赖审计日志的完整性。所有写操作必须先写审计日志，pft-risk 通过 CDC 消费审计日志检测异常行为（如"凌晨批量改银行卡""1小时内取消订单5次"）。

### MVP 范围

| 能力               | MVP | P2  | P3  |
| ---------------- | --- | --- | --- |
| 黑名单校验（下单/提现/核销）  | ✅   | ✅   | ✅   |
| 爽约拉黑（核销/退票后触发）   | ✅   | ✅   | ✅   |
| 提现风控（大额/频繁提现检测）  | ✅   | ✅   | ✅   |
| 异常操作检测（凌晨改银行卡等）  |     | ✅   | ✅   |
| 规则引擎外迁（独立规则配置UI） |     | ✅   | ✅   |
| 地理围栏             |     |     | ✅   |
| 机器学习风控模型         |     |     | ✅   |

---

## § 3.7 模型细节 · DDL / API / 状态机

> 概要设计需要落地到建表、写接口、画状态变迁图。本节把02文档定义的"模型长什么样"翻译成"模型怎么存、怎么调、怎么流转"——作为概要设计的直接输入。

---

### 一、DDL 设计 · 核心表结构

> 遵循04文档技术架构：MySQL 8.x、分库策略按租户维度、金额存分（BIGINT）、JSON存可扩展字段、索引覆盖高频查询路径。所有表均为InnoDB，字符集utf8mb4。

#### 1.1 订单层（pft-order 库）

> **命名规范依据**：O-04k 数据库命名规范——主键统一 `id BIGINT AUTO_INCREMENT`，业务ID做 `uk_` 唯一索引；审计字段5个（create_time/update_time/create_by/update_by/deleted）；金额BIGINT（分）；状态VARCHAR(20)；所有字段NOT NULL + DEFAULT。
> **i18n规范依据**：O-04u 国际化开发规范——状态字段存储英文code（如PENDING_PAY），前端按locale从i18n资源包渲染（zh_CN:"待支付"/en_US:"Pending Payment"）；金额字段存储BIGINT(分)，展示由CurrencyRenderUtil按币种+locale渲染；时间字段存储epoch毫秒，展示由TimeRenderUtil按timezone+locale渲染。禁止硬编码中文label。

**t_order_group（聚合单表）**

```sql
CREATE TABLE t_order_group (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    order_group_no      VARCHAR(32)     NOT NULL    COMMENT '聚合单号，支付幂等键来源，由流水号生成器生成',
    seller_tenant_id    BIGINT          NOT NULL    COMMENT '卖家租户ID（商品归属租户，聚合单层冗余，子单同值）',
    channel_id          BIGINT          NOT NULL    COMMENT '入口端ID（指向 t_channel.id）',
    app_id              VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '对接端标识（指向t_channel.app_id，标识订单组创建来源端；空串=未指定，历史数据兼容）',
    app_ref             VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '对接端自定义子标识（app_id对应）：小程序=tenant_mp_config_id；API=子渠道号；其他=空串',
    operator_type       VARCHAR(20)     NOT NULL    COMMENT '操作人类型：CUSTOMER/TENANT_STAFF',
    operator_id         BIGINT          NOT NULL    COMMENT '操作人ID（customer_id 或 tenant_staff_id）',
    operator_tenant_id  BIGINT          NOT NULL    COMMENT '操作人所属租户ID（=会话tenant_context_id）',
    buyer_type          VARCHAR(20)     NOT NULL    COMMENT '付款方类型：CUSTOMER/ANONYMOUS',
    buyer_id            BIGINT          NOT NULL    DEFAULT 0 COMMENT '付款方ID（ANONYMOUS时=0）',
    buyer_customer_id   BIGINT          NOT NULL    DEFAULT 0 COMMENT 'C端筛选冗余：buyer_type=CUSTOMER时=buyer_id，否则0',
    contact_name        VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '联系人姓名',
    contact_phone       VARCHAR(20)     NOT NULL    DEFAULT '' COMMENT '联系人手机',
    contact_id_type     VARCHAR(16)     NOT NULL    DEFAULT '' COMMENT '联系人证件类型：ID_CARD/PASSPORT等',
    contact_id_number   VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '联系人证件号',
    total_amount        BIGINT          NOT NULL    COMMENT '总金额（分）',
    currency            VARCHAR(8)      NOT NULL    DEFAULT 'CNY' COMMENT '币种（=商户配置币种；MVP不做换算）',
    pay_status          VARCHAR(16)     NOT NULL    DEFAULT 'UNPAID' COMMENT '支付状态：UNPAID/PARTIAL_PAID/PAID',
    pay_timeout_at      DATETIME(3)     NOT NULL    DEFAULT '1970-01-01 00:00:00.000' COMMENT '支付超时截止时间（SKU票属性PAY_TIMEOUT驱动，毫秒精度）',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度，=seller_tenant_id）',
    -- 审计字段（O-04k强制5字段）
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_group_no (order_group_no),
    KEY idx_tenant_buyer_customer (tenant_id, buyer_customer_id),
    KEY idx_tenant_channel (tenant_id, channel_id),
    KEY idx_tenant_op_tenant (tenant_id, operator_tenant_id),
    KEY idx_tenant_create (tenant_id, create_time)
) COMMENT='聚合单：一次购物车结算（Channel-First接入模型+多态参与者字段组）';
```

**t_order（子单表）**

```sql
CREATE TABLE t_order (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    order_no            VARCHAR(32)     NOT NULL    COMMENT '子单号，由流水号生成器生成',
    order_group_no      VARCHAR(32)     NOT NULL    COMMENT '归属聚合单号',
    parent_order_no     VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '套票子单指向主单号，非套票=空串',
    combo_flag            TINYINT         NOT NULL    DEFAULT 0 COMMENT '是否套票主单：1=套票主单，0=普通子单或套票子项',
    seller_tenant_id    VARCHAR(32)     NOT NULL    COMMENT '卖家商户ID',
    sku_id              VARCHAR(32)     NOT NULL    COMMENT 'SKU标识',
    sku_name            VARCHAR(200)    NOT NULL    COMMENT 'SKU名称（下单时快照）',
    quantity            INT             NOT NULL    COMMENT '购买数量',
    unit_price          BIGINT          NOT NULL    COMMENT '单价（分）；套票主单=套餐总价，套票子单=分摊价',
    order_status        VARCHAR(20)     NOT NULL    DEFAULT 'PENDING_PAY' COMMENT '状态：PENDING_PAY/PAID/PARTIALLY_VERIFIED/FULLY_VERIFIED/REFUNDED/CANCELLED',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_no (order_no),
    KEY idx_group (order_group_no),
    KEY idx_parent (parent_order_no),
    KEY idx_tenant_sku (tenant_id, sku_id),
    KEY idx_tenant_status (tenant_id, order_status, create_time)
) COMMENT='子单：每种SKU一条，套票拆主+N子';
```

**t_payment_record（支付记录表）**

```sql
CREATE TABLE t_payment_record (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    payment_no          VARCHAR(32)     NOT NULL    COMMENT '支付流水号，由流水号生成器生成',
    order_group_no      VARCHAR(32)     NOT NULL    COMMENT '归属聚合单号',
    pay_method          VARCHAR(16)     NOT NULL    COMMENT '支付方式：BALANCE/WECHAT/ALIPAY/CREDIT等',
    amount              BIGINT          NOT NULL    COMMENT '支付金额（分）',
    transaction_no      VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '第三方流水号',
    pay_time            DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '支付时间',
    pay_status          VARCHAR(16)     NOT NULL    DEFAULT 'CREATED' COMMENT '支付状态：CREATED/PAID/PARTIAL_REFUNDED/REFUNDED',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_payment_no (payment_no),
    KEY idx_group (order_group_no)
) COMMENT='支付记录：支持组合支付';
```

> **pay_status 状态说明（单条PaymentRecord）**：
> 
> - `CREATED`：支付单已创建，等待支付
> - `PAID`：单条支付记录支付成功
> - `PARTIAL_REFUNDED`：部分退款（原支付金额部分退回，如一单多票只退部分票）
> - `REFUNDED`：全额退款（原支付金额全部退回）
>   部分退款场景：一单多票（OrderGroup含N个Order），只退M个票（M<N）→ 对应PaymentRecord部分金额退款 → pay_status=PARTIAL_REFUNDED，此时需新建退款明细记录关联原PaymentRecord。
> 
> **组合支付聚合规则**：OrderGroup.payStatus从UNPAID→PARTIAL_PAID→PAID的变迁由多条PaymentRecord聚合触发：任意一条PaymentRecord回调PAID → OrderGroup进入PARTIAL_PAID；所有PaymentRecord均已PAID且金额之和=totalAmount → OrderGroup进入PAID。PARTIAL_PAID是OrderGroup聚合单层的状态，不是单条PaymentRecord的状态。

#### 1.2 票层（pft-order 库，与订单同库）

**t_ticket（票表）**

```sql
CREATE TABLE t_ticket (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '票号，格式TKT+yyyyMMdd+6位随机',
    order_no            VARCHAR(32)     NOT NULL    COMMENT '归属子单号',
    ticket_status       VARCHAR(20)     NOT NULL    DEFAULT 'AVAILABLE' COMMENT '票状态：AVAILABLE/PARTIALLY_USED/USED/EXPIRED/REFUNDED/CANCELLED',
    valid_start         DATETIME(3)     NOT NULL    DEFAULT '1970-01-01 00:00:00.000' COMMENT '有效期起始（出票时确定 或 首次核销时延迟确定，毫秒精度，核销比较取秒级）',
    valid_end           DATETIME(3)     NOT NULL    DEFAULT '1970-01-01 00:00:00.000' COMMENT '有效期终止（毫秒精度，核销校验now≤valid_end秒级比较优先于异步EXPIRED状态）',
    pass_policy         VARCHAR(16)     NOT NULL    DEFAULT 'SINGLE' COMMENT '放行策略（从SKU继承）：SINGLE/BATCH',
    metadata            JSON            NULL        COMMENT '业态扩展字段（seatInfo/cabinInfo等）',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ticket_no (ticket_no),
    KEY idx_order (order_no),
    KEY idx_tenant_status (tenant_id, ticket_status, create_time)
) COMMENT='票：一等公民，独立生命周期';
```

**t_ticket_person（票上的人）**

```sql
CREATE TABLE t_ticket_person (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '归属票号',
    person_id           VARCHAR(32)     NOT NULL    COMMENT '人ID（票内唯一）',
    global_customer_id  BIGINT          NOT NULL    DEFAULT 0 COMMENT '关联 Customer 全局ID（首次登录才建 Customer，未登录=0）',
    name                VARCHAR(64)     NOT NULL    COMMENT '姓名',
    id_type             VARCHAR(16)     NOT NULL    DEFAULT '' COMMENT '证件类型：ID_CARD/PASSPORT等',
    id_number           VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '证件号',
    phone               VARCHAR(20)     NOT NULL    DEFAULT '' COMMENT '手机号',
    is_primary          TINYINT         NOT NULL    DEFAULT 0 COMMENT '是否主游客：0否/1是',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ticket_person (ticket_no, person_id),
    KEY idx_global (global_customer_id)
) COMMENT='票上的人：0~N人，实名票必填；global_customer_id 首次登录后回填';
```

**t_entitlement（权益表）**

```sql
CREATE TABLE t_entitlement (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    entitlement_no      VARCHAR(32)     NOT NULL    COMMENT '权益号，由流水号生成器生成',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '归属票号',
    entitlement_type    VARCHAR(16)     NOT NULL    COMMENT '权益类型：FIXED/SELECTABLE/COUNTED/TIMED/UNLIMITED/QUOTA',
    entitlement_name    VARCHAR(128)    NOT NULL    COMMENT '权益名称（如"成人入园""住宿1晚"）',
    status              VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '权益状态：ACTIVE/USED/EXPIRED/REFUNDED',
    used_count          INT             NOT NULL    DEFAULT 0 COMMENT '已用次数（所有类型共有）',
    entitlement_detail  JSON            NOT NULL    COMMENT '权益详情（类型特有参数，JSON自描述，新增类型只需扩展schema不加DDL字段。示例：COUNTED→{"maxCount":5}；SELECTABLE→{"maxCount":2,"candidateRefs":["ENT-001"]}；TIMED→{"durationMinutes":480}；QUOTA→{"quotaAmount":50000}；FIXED/UNLIMITED→{}）',
    valid_start         DATETIME(3)     NOT NULL    DEFAULT '1970-01-01 00:00:00.000' COMMENT '权益有效期起始（可收窄于票有效期，毫秒精度）',
    valid_end           DATETIME(3)     NOT NULL    DEFAULT '1970-01-01 00:00:00.000' COMMENT '权益有效期终止（毫秒精度）',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_entitlement_no (entitlement_no),
    KEY idx_ticket (ticket_no),
    KEY idx_tenant_type (tenant_id, entitlement_type)
) COMMENT='权益：核销最小单元，6种类型';
```

**t_person_entitlement_binding（人-权益绑定表）**

```sql
CREATE TABLE t_person_entitlement_binding (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '归属票号',
    person_id           VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '人ID（空串=开放争抢，OPEN模式）',
    entitlement_no      VARCHAR(32)     NOT NULL    COMMENT '权益号',
    binding_type        VARCHAR(16)     NOT NULL    COMMENT '绑定类型：EXCLUSIVE/SHARED/OPEN',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_person_ent (ticket_no, person_id, entitlement_no),
    KEY idx_person (person_id),
    KEY idx_entitlement (entitlement_no)
) COMMENT='人-权益绑定：三角关系核心';
```

#### 1.3 凭证层（pft-verification 库）

**t_ticket_credential（票凭证表）**

```sql
CREATE TABLE t_ticket_credential (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    credential_no       VARCHAR(32)     NOT NULL    COMMENT '凭证号，由流水号生成器生成',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '归属票号',
    credential_type     VARCHAR(16)     NOT NULL    COMMENT '凭证类型：QR_CODE/BAR_CODE/ID_CARD/FACE',
    code_value          VARCHAR(128)    NOT NULL    COMMENT '码值（码池分配）',
    code_pool_id        VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '归属码池ID',
    status              VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/EXPIRED/REVOKED',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_credential_no (credential_no),
    KEY idx_ticket (ticket_no),
    KEY idx_code_value (code_value),
    KEY idx_pool (code_pool_id)
) COMMENT='票凭证：随票生灭的码值';
```

#### 1.4 价格层（pft-pricing 库）

**t_price_point（价格点表）**

```sql
CREATE TABLE t_price_point (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    price_no            VARCHAR(32)     NOT NULL    COMMENT '价格点编号，由流水号生成器生成',
    sku_id              VARCHAR(32)     NOT NULL    COMMENT 'SKU标识',
    -- 固定维度（独立列，可索引）
    channel             VARCHAR(32)     NULL        COMMENT '价格渠道: RETAIL/COUNTER/OTA_MEITUAN等, NULL=L0默认价',
    date_single         DATE            NULL        COMMENT '单日精确匹配(节假日特殊价), NULL=不按单日',
    date_from           DATE            NULL        COMMENT '日期区间起始, NULL=不按区间',
    date_to             DATE            NULL        COMMENT '日期区间终止, NULL=不按区间',
    weekday_mask        TINYINT UNSIGNED NULL        COMMENT '星期掩码 bit0=周一..bit6=周日(工作日=31/周末=96), NULL=不限',
    ext_dims            JSON            NULL        COMMENT '动态维度: {"roomType":"大床房","seatLevel":"A区"}',
    price               BIGINT          NOT NULL    COMMENT '金额（分）',
    priority            INT             NOT NULL    DEFAULT 0 COMMENT '优先级（数值大优先）',
    effective_from      DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '生效起始',
    effective_to        DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT '生效终止',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_price_no (price_no),
    KEY idx_sku_channel_date (sku_id, channel, date_single),
    KEY idx_sku_channel_range (sku_id, channel, date_from, date_to),
    KEY idx_tenant_sku (tenant_id, sku_id)
) COMMENT='价格点：L0默认价 / L1维度价格点（固定维度提取为列，动态维度用ext_dims JSON）';
```

**t_pricing_rule（定价规则表）**

```sql
CREATE TABLE t_pricing_rule (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    rule_no             VARCHAR(32)     NOT NULL    COMMENT '规则编号，格式PR+yyyyMMdd+6位随机',
    sku_id              VARCHAR(32)     NOT NULL    COMMENT 'SKU标识',
    rule_type           VARCHAR(16)     NOT NULL    COMMENT '规则类型：MARGIN/SURCHARGE/DISCOUNT/MEMBER_DISCOUNT',
    base_price_ref      VARCHAR(16)     NOT NULL    COMMENT '基准价引用：RETAIL/COUNTER/BASE/CURRENT',
    calculator          VARCHAR(16)     NOT NULL    COMMENT '计算方式：PERCENT/FIXED/MATRIX',
    params              JSON            NOT NULL    COMMENT '计算参数（JSON，随ruleType+calculator变化）',
    priority            INT             NOT NULL    DEFAULT 0 COMMENT '优先级',
    effective_from      DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '生效起始',
    effective_to        DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT '生效终止',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_rule_no (rule_no),
    KEY idx_sku_type (sku_id, rule_type),
    KEY idx_tenant_sku (tenant_id, sku_id)
) COMMENT='定价规则：L2可选规则（分销结算/预约加价/折扣）';
```

#### 1.5 库存层（pft-inventory 库）

**t_inventory_pool（库存池表）**

```sql
CREATE TABLE t_inventory_pool (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    pool_no             VARCHAR(32)     NOT NULL    COMMENT '库存池编号，由流水号生成器生成',
    sku_id              VARCHAR(32)     NOT NULL    COMMENT 'SKU标识',
    pool_type           VARCHAR(16)     NOT NULL    COMMENT '池类型：COUNTING/UNIT',
    dimension_key       JSON            NULL        COMMENT '维度键组合（如date/roomType/showTime等）',
    total_quantity      BIGINT          NOT NULL    COMMENT '总量（COUNTING池）',
    available_quantity  BIGINT          NOT NULL    COMMENT '可用量（实时）',
    frozen_quantity     BIGINT          NOT NULL    DEFAULT 0 COMMENT '预扣冻结量',
    pool_status         VARCHAR(16)     NOT NULL    DEFAULT 'ON_SALE' COMMENT '池状态：ON_SALE/STOP_SALE/EXPIRED',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_pool_no (pool_no),
    KEY idx_sku_dim (sku_id, dimension_key(128)),
    KEY idx_tenant_sku (tenant_id, sku_id, pool_status)
) COMMENT='库存池：L1 COUNTING / L2 UNIT 按维度键建池';
```

**t_inventory_unit（UNIT池具体资源表，演出座位/酒店房间等）**

```sql
CREATE TABLE t_inventory_unit (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    unit_no             VARCHAR(32)     NOT NULL    COMMENT '资源个体编号（座位号/房号/舱位号）',
    pool_no             VARCHAR(32)     NOT NULL    COMMENT '归属库存池编号',
    unit_status         VARCHAR(16)     NOT NULL    DEFAULT 'AVAILABLE' COMMENT '状态：AVAILABLE/FROZEN/OCCUPIED',
    order_no            VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '锁定子单号（FROZEN/OCCUPIED时）',
    metadata            JSON            NULL        COMMENT '资源属性（座位等级/房型等）',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_unit_no (unit_no),
    KEY idx_pool_status (pool_no, unit_status)
) COMMENT='UNIT池具体资源：需锁定个体的座位/房间/舱位';
```

#### 1.6 资金层（pft-finance 库）

**t_account（账户表）**

```sql
CREATE TABLE t_account (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    account_no          VARCHAR(32)     NOT NULL    COMMENT '账户编号，由流水号生成器生成',
    subject_id          VARCHAR(32)     NOT NULL    COMMENT '主体ID（商户/分销商/平台）',
    account_kind        VARCHAR(16)     NOT NULL    COMMENT '账户类型：MERCHANT/DISTRIBUTOR/PLATFORM',
    available_balance   BIGINT          NOT NULL    DEFAULT 0 COMMENT '可用余额（分）',
    frozen_balance      BIGINT          NOT NULL    DEFAULT 0 COMMENT '冻结余额（分）',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_account_no (account_no),
    UNIQUE KEY uk_subject_kind (subject_id, account_kind)
) COMMENT='统一账户：商户/分销商/平台各一个';
```

**t_frozen_record（冻结记录表）**

```sql
CREATE TABLE t_frozen_record (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    frozen_no           VARCHAR(32)     NOT NULL    COMMENT '冻结记录编号，由流水号生成器生成',
    account_no          VARCHAR(32)     NOT NULL    COMMENT '归属账户编号',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '关联票号（票级冻结）',
    amount              BIGINT          NOT NULL    COMMENT '冻结金额（分）= profit_share',
    frozen_status       VARCHAR(16)     NOT NULL    DEFAULT 'FROZEN' COMMENT '状态：FROZEN/RELEASED',
    frozen_event        VARCHAR(16)     NOT NULL    COMMENT '冻结事件：VERIFY（核销解冻）/REFUND（退款释放）',
    tenant_id           VARCHAR(32)     NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted          TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_frozen_no (frozen_no),
    KEY idx_account (account_no),
    KEY idx_ticket (ticket_no)
) COMMENT='冻结记录：按票冻结，核销解冻/退款释放';
```

#### 1.7 风控层（pft-risk 库）

**t_risk_rule / t_blacklist / t_risk_event / t_account_ban**（风控4表DDL见§3.6风控域核心模型，字段已完整定义，此处不再重复建表SQL）

---

### 二、API 接口清单

> 每个微服务的对外API列表。编排层（pft-orchestration）通过调用这些API组合业务流程，不直接操作数据库。接口风格：RESTful + 幂等键（orderGroupNo / orderNo / ticketNo）。路径参数用业务号（uk唯一索引），内部通过业务号查id再操作。

#### 2.1 pft-order · 订单服务

| #   | 方法   | 路径                                                 | 说明               | 入参关键字段                                                                                                                                    | 出参关键字段                                   |
| --- | ---- | -------------------------------------------------- | ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| T01 | POST | `/order/order-group/create`                        | 创建聚合单            | sellerTenantId, channelId, channelRef, operatorType, operatorId, operatorTenantId, buyerType, buyerId, buyerCustomerId, contact, currency | orderGroupNo                             |
| T02 | GET  | `/order/order-group/{orderGroupNo}`                | 查聚合单详情           | orderGroupNo                                                                                                                              | OrderGroup完整                             |
| T03 | POST | `/order/order/create`                              | 创建子单（含套票主单/子项子单） | orderGroupNo, skuId, quantity, unitPrice, sellerTenantId, parentOrderNo(套票子项), comboFlag                                                  | orderNo                                  |
| T04 | GET  | `/order/order/{orderNo}`                           | 查子单详情            | orderNo                                                                                                                                   | Order完整                                  |
| T05 | GET  | `/order/order-group/{orderGroupNo}/orders`         | 查聚合单下所有子单        | orderGroupNo                                                                                                                              | Order[]                                  |
| T06 | POST | `/order/order/{orderNo}/status-transition`         | 子单状态变迁           | orderNo, targetStatus, reason                                                                                                             | orderNo, newStatus                       |
| T07 | POST | `/order/ticket/create-batch`                       | 批量创建票（下单时调用）     | orderNo, quantity, persons[], entitlements[], bindings[]                                                                                  | ticketNo[]                               |
| T08 | GET  | `/order/ticket/{ticketNo}`                         | 查票详情             | ticketNo                                                                                                                                  | Ticket完整（含persons+entitlements+bindings） |
| T09 | GET  | `/order/order/{orderNo}/tickets`                   | 查子单下所有票          | orderNo                                                                                                                                   | Ticket[]                                 |
| T10 | POST | `/order/ticket/{ticketNo}/add-person`              | 补录实名（添加Person）   | ticketNo, person(name/idType/idNumber/phone/isPrimary)                                                                                    | personId                                 |
| T11 | POST | `/order/ticket/{ticketNo}/bind-person-entitlement` | 绑定人-权益           | ticketNo, personId, entitlementNo, bindingType                                                                                            | bindingId                                |
| T12 | POST | `/order/ticket/{ticketNo}/status-transition`       | 票状态变迁            | ticketNo, targetStatus, reason                                                                                                            | ticketNo, newStatus                      |
| T13 | POST | `/order/refund/create`                             | 创建退款单            | orderGroupNo, refundItems[{orderNo, ticketNos[], amount}]                                                                                 | refundNo                                 |
| T14 | GET  | `/order/refund/{refundNo}`                         | 查退款单详情           | refundNo                                                                                                                                  | Refund完整（含refundDetails[]）               |
| T15 | GET  | `/order/refund/{refundNo}/details`                 | 查退款明细列表          | refundNo                                                                                                                                  | RefundDetail[]                           |

#### 2.2 pft-product · 商品服务

| #   | 方法   | 路径                                 | 说明         | 入参关键字段                                                   | 出参关键字段       |
| --- | ---- | ---------------------------------- | ---------- | -------------------------------------------------------- | ------------ |
| P01 | POST | `/product/sku/create`              | 创建SKU      | skuName, spuId, ticketMetas[], comboConfig(套票), tenantId | skuId        |
| P02 | GET  | `/product/sku/{skuId}`             | 查SKU详情     | skuId                                                    | SKU完整        |
| P03 | GET  | `/product/sku/{skuId}/combo-items` | 查套票SKU子项列表 | skuId                                                    | ComboItem[]  |
| P04 | POST | `/product/ticket-meta/register`    | 注册票属性元数据   | id, name, valueType, scope, impacts[], conflicts[]       | attributeId  |
| P05 | GET  | `/product/ticket-meta/list`        | 列出所有票属性    | scope(业态)                                                | TicketMeta[] |

#### 2.3 pft-pricing · 价格服务

| #    | 方法   | 路径                                  | 说明          | 入参关键字段                                                                            | 出参关键字段             |
| ---- | ---- | ----------------------------------- | ----------- | --------------------------------------------------------------------------------- | ------------------ |
| PR01 | POST | `/pricing/price-point/create`       | 创建价格点       | skuId, channel, dateSingle/dateFrom/dateTo, weekdayMask, extDims, price, priority | priceNo            |
| PR02 | GET  | `/pricing/price-point/query`        | 查询价格（单日）    | skuId, date, channel, extDims                                                     | price              |
| PR03 | GET  | `/pricing/price-point/query-batch`  | 批量日历价格查询    | skuId, dateFrom, dateTo, channel                                                  | [{date, price}]    |
| PR04 | POST | `/pricing/price-snapshot/create`    | 创建价格快照（下单时） | orderNo, skuId, finalPrice, settlePrice, priceBreakdown                           | snapshotNo         |
| PR05 | GET  | `/pricing/price-snapshot/{orderNo}` | 查价格快照       | orderNo                                                                           | OrderPriceSnapshot |
| PR06 | POST | `/pricing/rule/create`              | 创建定价规则      | skuId, ruleType, basePriceRef, calculator, params                                 | ruleNo             |

#### 2.4 pft-inventory · 库存服务

| #   | 方法   | 路径                           | 说明            | 入参关键字段                                 | 出参关键字段            |
| --- | ---- | ---------------------------- | ------------- | -------------------------------------- | ----------------- |
| I01 | POST | `/inventory/pool/pre-deduct` | 预扣库存          | skuId, dimensionKey, quantity, orderNo | poolNo, deducted  |
| I02 | POST | `/inventory/pool/confirm`    | 确认扣减（核销时）     | poolNo, orderNo                        | confirmed         |
| I03 | POST | `/inventory/pool/rollback`   | 回滚（取消/退款时）    | poolNo, orderNo, quantity              | rolledBack        |
| I04 | POST | `/inventory/unit/lock`       | 锁定UNIT资源      | poolNo, unitNo, orderNo                | locked            |
| I05 | POST | `/inventory/unit/release`    | 释放UNIT资源      | poolNo, unitNo, orderNo                | released          |
| I06 | GET  | `/inventory/pool/query`      | 查询可用量         | skuId, dimensionKey                    | availableQuantity |
| I07 | POST | `/inventory/pool/and-check`  | AND组合策略校验（套票） | items[{skuId, dimensionKey, quantity}] | allAvailable      |

#### 2.5 pft-payment · 支付服务

| #     | 方法   | 路径                               | 说明           | 入参关键字段                               | 出参关键字段          |
| ----- | ---- | -------------------------------- | ------------ | ------------------------------------ | --------------- |
| PAY01 | POST | `/payment/pay`                   | 支付（余额/在线/组合） | orderGroupNo, payMethod, amount      | paymentNo       |
| PAY02 | POST | `/payment/refund`                | 退款           | orderGroupNo, refundAmount, refundTo | refundPaymentNo |
| PAY03 | GET  | `/payment/record/{orderGroupNo}` | 查支付记录        | orderGroupNo                         | PaymentRecord[] |

#### 2.6 pft-verification · 核销服务

| #   | 方法   | 路径                                               | 说明           | 入参关键字段                                                  | 出参关键字段                         |
| --- | ---- | ------------------------------------------------ | ------------ | ------------------------------------------------------- | ------------------------------ |
| V01 | POST | `/verification/credential/issue`                 | 发码（出票时从码池分配） | ticketNo, credentialType, codePoolId                    | credentialNo, codeValue        |
| V02 | GET  | `/verification/credential/query-by-code`         | 按码值查凭证       | codeValue                                               | credential→ticketNo            |
| V03 | POST | `/verification/verify`                           | 核销           | ticketNo, verifyPointId, operatorId, credentialCode(可选) | verifyResult, entitlementsUsed |
| V04 | POST | `/verification/verify-batch`                     | 批量核销         | ticketNos[], verifyPointId, operatorId                  | verifyResults[]                |
| V05 | GET  | `/verification/ticket/{ticketNo}/verify-history` | 查核销记录        | ticketNo                                                | VerifyRecord[]                 |

#### 2.7 pft-finance · 财务服务

| #   | 方法   | 路径                             | 说明      | 入参关键字段                             | 出参关键字段                          |
| --- | ---- | ------------------------------ | ------- | ---------------------------------- | ------------------------------- |
| F01 | POST | `/finance/freeze`              | 票级冻结    | accountNo, ticketNo, amount, event | frozenNo                        |
| F02 | POST | `/finance/unfreeze`            | 解冻（核销时） | frozenNo                           | unfrozen                        |
| F03 | POST | `/finance/refund-freeze`       | 退款冻结释放  | ticketNo, amount                   | released                        |
| F04 | GET  | `/finance/account/{subjectId}` | 查账户余额   | subjectId                          | availableBalance, frozenBalance |
| F05 | POST | `/finance/withdraw/apply`      | 提现申请    | subjectId, amount, bankCardId      | withdrawNo                      |

#### 2.8 pft-risk · 风控服务

| #   | 方法   | 路径                      | 说明     | 入参关键字段                                   | 出参关键字段                       |
| --- | ---- | ----------------------- | ------ | ---------------------------------------- | ---------------------------- |
| R01 | POST | `/risk/check`           | 风控校验   | subjectId, actionType, dimensionValues[] | pass/reject, ruleId          |
| R02 | POST | `/risk/report`          | 上报风控事件 | subjectId, eventType, detail, auditLogId | eventId                      |
| R03 | GET  | `/risk/blacklist/check` | 黑名单校验  | dimension, dimensionValue                | isBlacklisted, bannedActions |

#### 2.9 pft-identity · 用户/租户/接入服务

| #    | 方法   | 路径                                       | 说明                        | 入参关键字段                                                                             | 出参关键字段                                    |
| ---- | ---- | ---------------------------------------- | ------------------------- | ---------------------------------------------------------------------------------- | ----------------------------------------- |
| ID01 | POST | `/identity/customer/login-or-register`   | C端首次登录/注册（首次登录才建Customer） | channelId, channelRef, identityType, identityValue, unionid, phone?                | customerId, token                         |
| ID02 | GET  | `/identity/customer/{customerId}`        | 查Customer详情               | customerId                                                                         | Customer完整（含identity/binding）             |
| ID03 | POST | `/identity/customer-credential/register` | 注册C端个人凭证（人脸/证件）           | customerId, credentialType, codeValue                                              | credentialNo                              |
| ID04 | GET  | `/identity/customer-credential/query`    | 查个人凭证                     | credentialType, codeValue                                                          | customerId                                |
| ID05 | POST | `/identity/tenant-staff/login`           | B端员工登录（租户后台/平台后台共用）       | channelId, tenantNo, phone, password                                               | staffId, tenantId, token                  |
| ID06 | POST | `/identity/tenant-staff/create`          | 创建租户员工（含平台员工）             | tenantId, name, phone, staffType, isOwner                                          | staffId                                   |
| ID07 | POST | `/identity/tenant/create`                | 创建租户并初始化默认散客账号            | tenantName, contactPhone, businessTypes, currency                                  | tenantId, defaultCustomerId, ownerStaffId |
| CH01 | POST | `/identity/channel/create`               | 创建接入端（API类按需创建）           | channelCode, channelType, ownerTenantId, appKey, appSecret, defaultOperatorStaffId | channelId                                 |
| CH02 | GET  | `/identity/channel/{channelCode}`        | 查询接入端                     | channelCode                                                                        | Channel完整                                 |
| CH03 | POST | `/identity/tenant-mp-config/register`    | 登记租户小程序appId              | tenantId, mpType, appId, appSecret, mchId                                          | mpConfigId                                |
| CH04 | GET  | `/identity/tenant-mp-config/resolve`     | appId解析租户上下文              | mpType, appId                                                                      | tenantId, mpConfigId                      |

---

### 三、状态机 · 完整变迁定义

> 每个状态变迁都定义：触发条件、前置状态、后置状态、副作用（联动操作）。

#### 3.1 OrderGroup 状态机

```text
UNPAID ──支付成功──→ PAID
  │                     │
  │                     ├──全部子单退款──→ REFUNDED
  │                     ├──部分子单退款──→ PARTIAL_REFUNDED
  │
  └──超时未付──→ CANCELLED
```

| 变迁   | 前置                    | 后置               | 触发条件                                           | 副作用                                    |
| ---- | --------------------- | ---------------- | ---------------------------------------------- | -------------------------------------- |
| 支付成功 | UNPAID                | PAID             | 所有paymentRecords状态=PAID，totalAmount=各payment之和 | 触发`pft.order.order_paid`事件；各子单状态变迁PAID |
| 全部退款 | PAID/PARTIAL_REFUNDED | REFUNDED         | 所有子单orderStatus=REFUNDED                       | 触发`pft.order.order_refunded`事件         |
| 部分退款 | PAID                  | PARTIAL_REFUNDED | 部分子单orderStatus=REFUNDED                       | 无额外副作用                                 |
| 超时取消 | UNPAID                | CANCELLED        | 支付超时（默认30min）                                  | 各子单状态变迁CANCELLED；库存回滚                  |

#### 3.2 Order 状态机

```text
PENDING_PAY ──支付成功──→ PAID
  │                         │
  │                         ├──部分票核销──→ PARTIALLY_VERIFIED
  │                         │                   │
  │                         │                   ├──全部票核销──→ FULLY_VERIFIED
  │                         │                   │
  │                         ├──全部票核销──→ FULLY_VERIFIED
  │                         │
  │                         ├──退款──→ REFUNDED
  │
  └──取消──→ CANCELLED
```

| 变迁   | 前置                      | 后置                 | 触发条件                               | 副作用                                      |
| ---- | ----------------------- | ------------------ | ---------------------------------- | ---------------------------------------- |
| 支付成功 | PENDING_PAY             | PAID               | OrderGroup支付成功，本子单归属               | 库存确认扣减；触发`pft.order.order_paid`（按子单）     |
| 部分核销 | PAID                    | PARTIALLY_VERIFIED | 本子单下≥1张票ticketStatus=USED，且不全为USED | 无额外副作用                                   |
| 全部核销 | PAID/PARTIALLY_VERIFIED | FULLY_VERIFIED     | 本子单下所有票ticketStatus=USED或EXPIRED   | 触发`pft.order.order_verified`；财务解冻        |
| 退款   | PAID/PARTIALLY_VERIFIED | REFUNDED           | 退款单覆盖本子单所有票                        | 库存回滚；财务冻结释放；触发`pft.order.order_refunded` |
| 取消   | PENDING_PAY             | CANCELLED          | OrderGroup取消，本子单归属                 | 库存回滚                                     |

> **套票主单状态聚合规则**：主Order状态不由自身票驱动，而是聚合所有子Order状态计算。例如：所有子Order=FULLY_VERIFIED → 主Order=FULLY_VERIFIED；部分子Order=REFUNDED → 主Order=PARTIALLY_VERIFIED。

#### 3.3 Ticket 状态机

```text
AVAILABLE ──首次核销──→ PARTIALLY_USED ──全部权益核销──→ USED
  │           │                                    │
  │           │──权益过期──→ EXPIRED                 │──有效期到期──→ EXPIRED（自动）
  │           │                                    │
  │──退款──→ REFUNDED    ──退款──→ REFUNDED          │──退款──→ REFUNDED（需退改策略允许）
  │
  │──取消──→ CANCELLED
  │
  │──有效期到期──→ EXPIRED（自动，未核销的票）
```

| 变迁   | 前置                       | 后置             | 触发条件                                | 副作用                                               |
| ---- | ------------------------ | -------------- | ----------------------------------- | ------------------------------------------------- |
| 部分核销 | AVAILABLE                | PARTIALLY_USED | 部分Entitlement status=USED           | 无额外副作用                                            |
| 全部核销 | AVAILABLE/PARTIALLY_USED | USED           | 所有Entitlement status=USED或EXPIRED   | 触发`pft.verify.ticket_verified`；财务解冻对应FrozenRecord |
| 过期   | AVAILABLE/PARTIALLY_USED | EXPIRED        | validPeriod.end到期，且仍有未核销Entitlement | 触发`pft.order.ticket_expired`；定时任务扫描               |
| 退款   | AVAILABLE/PARTIALLY_USED | REFUNDED       | 退款单覆盖本票；票属性退改策略允许                   | 库存回滚；财务冻结释放                                       |
| 取消   | AVAILABLE                | CANCELLED      | Order取消                             | 库存回滚                                              |

#### 3.4 Entitlement 状态机

```text
ACTIVE ──核销──→ USED
  │
  │──过期──→ EXPIRED
  │
  │──退款──→ REFUNDED
```

| 变迁             | 前置          | 后置          | 触发条件                                | 副作用                                                                    |
| -------------- | ----------- | ----------- | ----------------------------------- | ---------------------------------------------------------------------- |
| 核销（FIXED）      | ACTIVE      | USED        | 核销1次                                | usedCount=1                                                            |
| 核销（COUNTED）    | ACTIVE      | ACTIVE/USED | 核销1次，usedCount++                    | usedCount<detail.maxCount→仍ACTIVE；usedCount=detail.maxCount→USED       |
| 核销（SELECTABLE） | ACTIVE      | USED        | 核销≤detail.maxCount项                 | detail.candidateRefs逐项标记                                               |
| 核销（TIMED）      | ACTIVE      | USED        | 首次核销启动计时startedAt                   | 超时→EXPIRED                                                             |
| 核销（UNLIMITED）  | ACTIVE      | ACTIVE      | 有效期内不限次，每次核销仅记录                     | 不改变状态                                                                  |
| 核销（QUOTA）      | ACTIVE      | ACTIVE/USED | 扣减detail.quotaAmount                | quotaUsed<detail.quotaAmount→仍ACTIVE；quotaUsed=detail.quotaAmount→USED |
| 过期             | ACTIVE      | EXPIRED     | entitlement.validPeriod.end到期       | 定时任务扫描                                                                 |
| 退款             | ACTIVE/USED | REFUNDED    | 票退款时联动（USED的Entitlement按退改策略判断是否可退） | 释放冻结                                                                   |

#### 3.5 PaymentRecord 状态机

```text
CREATED ──支付成功──→ PAID ──退款──→ REFUNDED
```

| 变迁   | 前置      | 后置       | 触发条件           | 副作用             |
| ---- | ------- | -------- | -------------- | --------------- |
| 支付成功 | CREATED | PAID     | 第三方渠道回调/余额扣款成功 | OrderGroup→PAID |
| 退款   | PAID    | REFUNDED | 退款审批通过         | 余额加回/原路退回       |

#### 3.6 FrozenRecord 状态机

```text
FROZEN ──核销解冻──→ RELEASED（event=VERIFY）
  │
  └──退款释放──→ RELEASED（event=REFUND）
```

| 变迁   | 前置     | 后置       | 触发条件                   | 副作用                                                                  |
| ---- | ------ | -------- | ---------------------- | -------------------------------------------------------------------- |
| 核销解冻 | FROZEN | RELEASED | Ticket核销（event=VERIFY） | account.available_balance += amount；account.frozen_balance -= amount |
| 退款释放 | FROZEN | RELEASED | Ticket退款（event=REFUND） | account.frozen_balance -= amount；原路退回/余额加回                           |

---

> **以上DDL/API/状态机构成概要设计的直接输入**——建表脚本从DDL直接生成，接口契约从API清单直接定义，状态变迁代码从状态机定义直接实现。编排层Workflow组合调用各服务API，驱动状态变迁和副作用联动。
