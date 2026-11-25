# PFT 2.0 应用架构

> **CHAPTER 03 · APPLICATION ARCHITECTURE**
> 
> 服务怎么划分？怎么通信？本文档定义微服务清单、服务间通信模式、系统分层架构与编排层设计原则。编排引擎技术选型见 §5.1.4（技术架构文档）。

## 21 个服务（20 业务服务 + 1 基础服务） · 边界即数据主权 · 业务层定策略 · 编排层管流程 · 规则归 Nacos

> 把基础设施从"业务微服务清单"中剔除，每个服务独占数据并对外暴露能力，再用业务层（解释权：选择/组合编排）+ 编排层（Workflow）把跨服务流程显式化。编排引擎技术选型见 §5.1.4（技术架构文档）。

---

## § 4.1 微服务清单（21 个服务 = 20 业务服务 + 1 基础服务）

> MVP 标记 = Phase 1-2 必须上线；其余进入 Phase 2/3。
> 价格体系独立为 `pft-pricing` 服务，与商品服务分离——商品管"是什么"，价格管"卖多少钱"。
> 身份与游客服务合并为 `pft-identity`，统一管 C端 Customer + B端 TenantStaff + 租户。Channel-First 接入端(t_channel等)归 `pft-platform`。
> 风控独立为 `pft-risk`，套餐与计费功能并入 `pft-platform`，不单独建 `pft-billing`。
> 文件存储独立为 `pft-filestorage` 基础服务（编号 022），为所有业务服务提供统一的对象存储/文件上传/签名URL能力。

| #   | 服务                    | 归属域         | 核心职责                                                                                                                                                                                                                                                                                               | 阶段      |
| --- | --------------------- |-------------| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| 01  | **pft-product**       | `商品`（郑宇1）   | SKU 管理、票属性元数据、套票编排定义、商品发布                                                                                                                                                                                                                                                                          | **MVP** |
| 02  | **pft-pricing**       | `商品`        | 价格体系全套：L0 默认价 / L1 维度价格点 / L2 定价规则、价格查询、价格快照                                                                                                                                                                                                                                                       | **MVP** |
| 03  | **pft-inventory**     | `商品`（郑宇2）   | 库存池抽象（COUNTING/UNIT）、配额管理、Redis 预扣、对账                                                                                                                                                                                                                                                              | **MVP** |
| 04  | **pft-order**         | `订单`        | OrderGroup → Order → Ticket 三级聚合、状态机                                                                                                                                                                                                                                                               | **MVP** |
| 05  | **pft-business**      | `业务决策`      | **业务解释权**：编排选择（按 productType/channel/tenant 上下文选择 Workflow）、编排组合（多个编排串联）、业务规则配置化驱动、上下文决策引擎。不包含原子能力调用——那是编排层的活                                                                                                                                                                                      | **MVP** |
| 06  | **pft-orchestration** | `跨域编排`      | 跨域流程编排（下单/退款/核销/分销/充值）——原子能力组装、Activity幂等、补偿与重试；不含业务解释逻辑（不包括 OrderRouter，解释权已上移到 pft-business）                                                                                                                                                                                                     | **MVP** |
| 07  | **pft-payment**       | `支付`        | 支付渠道适配、退款、对账文件解析                                                                                                                                                                                                                                                                                   | **MVP** |
| 08  | **pft-verification**  | `核销`        | 核销点管理、在线/离线核销、闸机绑定与冲突仲裁、凭证与码池管理                                                                                                                                                                                                                                                                    | **MVP** |
| 09  | **pft-finance**       | `财务`        | 统一账户模型、票级冻结/解冻、对账、提现、银行卡管理                                                                                                                                                                                                                                                                         | **P2**  |
| 10  | **pft-risk**          | `风控`        | 黑名单校验、风控规则引擎、异常行为检测、账号封禁管理、爽约拉黑、审计日志消费与风控事件生成                                                                                                                                                                                                                                                      | **P2**  |
| 11  | **pft-device**        | `设备`        | 闸机/POS/手持机/自助机/云票务终端注册、分组、状态管理、绑定核销点                                                                                                                                                                                                                                                               | **P2**  |
| 12  | **pft-distribution**  | `分销`        | 4 级采购链、共享库存池、分销结算价计算、授信生命周期、分销双模式（分润/逐级采购）                                                                                                                                                                                                                                                         | **P3**  |
| 13  | **pft-identity**      | `用户与身份`（张峰） | 统一身份服务：**C端 Customer 主账号 + 多渠道身份识别 + 租户绑定 + 人脸/证件凭证**；**B端 TenantStaff（含平台员工）**；Tenant（平台租户约定 `tenant_no='PLATFORM'`，self-tenant 模式无 is_platform 字段）；Org；RBAC + ABAC 融合权限模型（单套体系，平台超管 = tenant_no='PLATFORM' 租户下员工 + RBAC SUPER_ADMIN 角色双因子判定）；多种登录方式（账密/短信/微信/飞书/小程序授权）；MFA；游客实名；第三方企业资质审查（天眼查对接） | **MVP** |
| 14  | **pft-platform**      | `平台运营`      | 平台组织/权限（租户/区域维度）、平台字典、**Channel-First 统一接入端管控（t_channel 服务商级端 + t_tenant_mp_config 小程序 appId 配置 + t_channel_tenant_binding 渠道-租户绑定）**、国际化管理（语言/币种/时区/翻译）、套餐管理/资源额度/功能开关、审批流配置、投诉与工单                                                                                                                | **MVP** |
| 15  | **pft-notification**  | `通知`        | 短信/模板消息/邮件/Webhook 出向、验证码发送与校验                                                                                                                                                                                                                                                                     | **P2**  |
| 16  | **pft-audit**         | `审计`        | 审计日志采集/存储/查询（商户和平台公用）、CDC 输出到 MQ 供 pft-risk 消费                                                                                                                                                                                                                                                     | **P2**  |
| 17  | **pft-application**   | `应用`        | 应用市场、应用定义、套餐-应用绑定、租户应用启用管理                                                                                                                                                                                                                                                                         | **P3**  |
| 18  | **pft-marketing**     | `营销`        | 优惠券、活动、玩法编排                                                                                                                                                                                                                                                                                        | **P3**  |
| 19  | **pft-data-pipeline** | `数据`        | CDC → ES/OLAP，搜索同步、T+1 离线报表、实时报表聚合                                                                                                                                                                                                                                                                 | **P2**  |
| 20  | **pft-open-platform** | `开放`        | OpenAPI、签名鉴权、流控、商户 SDK                                                                                                                                                                                                                                                                             | **P3**  |
| 21  | **pft-filestorage**  | `基础设施`      | 文件存储统一服务：对象存储封装、STS 临时凭证签发、签名 URL 生成、文件上传/下载代理、文件元数据管理。为所有业务服务提供统一文件能力，不承载业务逻辑                                                                                                                                                                                | **MVP** |

### 各微服务 → 归属领域 速查

> 完整领域-微服务映射见 §4.1.2；此处按微服务维度列出归属域，便于快速查阅。

| 微服务               | 归属领域      | 说明                                                   |
| ----------------- | --------- | ---------------------------------------------------- |
| pft-product       | 商品域       | SPU/SKU管理、套票编排定义                                     |
| pft-pricing       | 商品域       | 价格体系（L0/L1/L2）、价格查询                                  |
| pft-inventory     | 商品域       | 库存池、配额、预扣与对账                                         |
| pft-order         | 订单域       | 订单聚合、状态机                                             |
| pft-business      | 无（业务决策服务） | 业务解释权：编排选择/组合、业务规则配置化、上下文决策（不属于具体业务领域，也不属于编排层）       |
| pft-orchestration | 无（跨域编排服务） | 跨域流程编排（下单/退款/核销/分销/充值等），纯粹原子能力组装                     |
| pft-payment       | 支付域       | 支付渠道适配、退款、对账                                         |
| pft-verification  | 核销域       | 核销点管理、在线/离线核销、码池管理                                   |
| pft-finance       | 财务域       | 统一账户、冻结/解冻、提现、对账                                     |
| pft-risk          | 风控域       | 黑名单、风控规则、异常检测、账号封禁                                   |
| pft-device        | 设备域       | 闸机/POS/手持机/自助机注册与状态管理                                |
| pft-distribution  | 分销域       | 4级采购链、共享库存池、分销双模式                                    |
| pft-identity      | 用户身份域     | 统一身份、RBAC+ABAC权限、多种登录方式、MFA                          |
| pft-platform      | 平台运营域     | 平台字典、Channel-First接入端管控(t_channel)、套餐与资源额度、审批流、投诉与工单 |
| pft-notification  | 通知域       | 短信/模板消息/邮件/Webhook出向                                 |
| pft-audit         | 审计日志域     | 审计日志采集/存储/查询、CDC输出                                   |
| pft-application   | 应用域       | 应用市场、应用定义、租户应用启用管理                                   |
| pft-marketing     | 营销域       | 优惠券、活动、玩法编排                                          |
| pft-data-pipeline | 数据域       | CDC同步、搜索同步、T+1离线报表、实时报表                              |
| pft-open-platform | 开放平台域     | OpenAPI、签名鉴权、流控、商户SDK                                |
| pft-filestorage  | 基础设施域     | 文件存储统一服务：对象存储封装、STS凭证、签名URL、文件元数据              |

### 服务边界说明

| 服务                | 不负责                                             | 说明                                     |
| ----------------- | ----------------------------------------------- | -------------------------------------- |
| pft-product       | 不分销结算价计算（交 pft-pricing）                         | 商品管结构，价格管金额                            |
| pft-pricing       | 不管成本价 costPrice（属 t_sku，由商品域维护）                 | 售价体系独立，成本价不在售价体系内                      |
| pft-business      | 不含原子能力调用（交 pft-orchestration），不含 Workflow 定义与执行 | 业务层只做编排的选择与组合，不触碰原子能力的串联细节             |
| pft-orchestration | 不含业务解释逻辑（交 pft-business），不含编排路由                 | 编排层不知道"为什么选这个 Workflow"，只负责按指示执行原子能力组装 |
| pft-platform      | 不含限流/流控（接入层 Gateway 负责）                         | 收束为纯平台配置服务；套餐与计费功能并入本服务，暂不独立           |
| pft-finance       | 不含支付渠道对接（交 pft-payment）                         | 账户与支付分离                                |
| pft-identity      | 不含业务流程（下单/核销等由对应服务负责）                           | 只管身份与权限，不管业务                           |
| pft-risk          | 不含审计日志存储（交 pft-audit）                           | 风控消费审计日志，自身不存储原始操作日志                   |
| pft-device        | 不含核销逻辑（交 pft-verification）                      | 设备管理只管注册/分组/状态，不管核销                    |
| pft-audit         | 不含风控规则判定（交 pft-risk）                            | 审计只管记录，规则判定由风控负责                       |
| pft-application   | 不含套餐计费（交 pft-platform）                          | 应用管理只管应用启用，不管计费                        |
| pft-filestorage  | 不含业务逻辑（只管文件存取，不感知订单/商品/用户等业务实体）            | 纯基础设施服务，被所有业务服务通过 Feign 调用             |

### 领域-微服务映射表

> 基于 §2.2.1 三级拆分表整理。18 个一级领域（核心 12 + 支撑 5 + 通用 1）全部有微服务承载，无空白。`pft-orchestration` 为跨域编排服务，归属将在下方"非领域归属服务"表单独列出。

| #   | 一级领域       | 战略定位 | 对应微服务                                           | 覆盖情况                                             |
| --- | ---------- | ---- | ----------------------------------------------- | ------------------------------------------------ |
| 1   | **商品域**    | 核心   | `pft-product` + `pft-pricing` + `pft-inventory` | ✅ 完整：商品/价格/库存三服务各司其职                             |
| 2   | **订单域**    | 核心   | `pft-order`                                     | ✅ 完整：订单聚合、状态机                                    |
| 3   | **支付域**    | 核心   | `pft-payment`                                   | ✅ 完整                                             |
| 4   | **核销域**    | 核心   | `pft-verification`                              | ✅ 完整                                             |
| 5   | **分销域**    | 核心   | `pft-distribution`                              | ✅ 完整（P2）                                         |
| 6   | **财务域**    | 核心   | `pft-finance`                                   | ✅ 完整                                             |
| 7   | **用户域**    | 核心   | `pft-identity`                                  | ✅ 完整（已合并游客能力）                                    |
| 8   | **风控域**    | 核心   | `pft-risk`                                      | ✅ 完整（P2）：独立服务，跨场景通用                              |
| 9   | **平台运营域**  | 核心   | `pft-platform`                                  | ✅ 完整（MVP）：含套餐与计费功能，暂不独立 pft-billing              |
| 10  | **设备域**    | 核心   | `pft-device`                                    | ✅ 完整（MVP）：闸机/POS/手持机/自助机注册与分组                    |
| 11  | **应用域**    | 核心   | `pft-application`                               | ✅ 完整（P2）：应用市场/套餐应用启用                             |
| 12  | **通知域**    | 支撑   | `pft-notification`                              | ✅ 完整（P2）                                         |
| 13  | **营销域**    | 支撑   | `pft-marketing`                                 | ✅ 完整（P3）                                         |
| 14  | **数据域**    | 支撑   | `pft-data-pipeline`                             | ✅ 完整（P2）                                         |
| 15  | **开放平台域**  | 支撑   | `pft-open-platform`                             | ✅ 完整（P3）                                         |
| 16  | **审计日志域**  | 支撑   | `pft-audit`                                     | ✅ 完整（P2）：商户和平台公用                                 |
| 17  | **套餐与计费域** | 核心   | `pft-platform`（套餐管理/资源额度/订购流程）                  | ✅ 完整：并入 pft-platform，后续扩大后再评估是否拆分为独立 pft-billing |
| 18  | **基础设施域**  | 通用   | `pft-filestorage` + _其他选型即服务_                  | ✅ 完整（MVP）：文件存储独立为 pft-filestorage 服务；Keycloak/Nacos/XXL-JOB 等仍为选型即服务 |

> **结论**：18 个一级领域（核心 12 + 支撑 5 + 通用 1）全部有微服务承载，无空白。编排层（`pft-orchestration`）为跨域编排服务，仅做原子能力组装，不含业务解释。业务层（`pft-business`）持有解释权——根据上下文选择/组合编排。两者都不属于任何业务领域。套餐与计费域功能并入 `pft-platform`，后续扩大后再评估是否拆分为独立 `pft-billing`。基础设施域新增 `pft-filestorage` 文件存储服务（MVP），Keycloak/Nacos/XXL-JOB 等仍为选型即服务。总计 **21 个微服务**（18 个领域服务 + 1 个业务决策服务 + 1 个跨域编排服务 + 1 个基础设施文件存储服务）。

### pft-risk 风控服务

风控是跨业务场景的通用能力，**独立为 `pft-risk` 服务（MVP）**，不仅覆盖下单风控，还包括提现风控、异常操作检测、账号封禁、爽约拉黑等。

#### 调用关系

```
各服务写操作 → pft-audit（写审计日志）
                          ↓ CDC 实时消费
                    pft-risk（检测异常 → 生成 RiskEvent → 命中规则 → 黑名单/预警）
                          ↓ 调用
                    pft-notification（风控预警通知）

下单：pft-order → pft-risk /risk/check（黑名单校验）→ 通过/拒绝/预警
提现：pft-finance → pft-risk /risk/check（大额/频繁提现检测）→ 通过/拒绝
核销：pft-verification → pft-risk /risk/check（高频核销检测）→ 通过/预警
```

#### 核心职责

| 职责     | 说明                           |
| ------ | ---------------------------- |
| 黑名单校验  | 下单/提现/核销前，检查用户/IP/身份证是否在黑名单  |
| 爽约拉黑   | 核销/退票后触发，爽约次数超阈值自动加入黑名单      |
| 提现风控   | 大额提现/频繁提现/非常规时段提现检测          |
| 异常操作检测 | 消费审计日志，检测"凌晨改银行卡""批量上架"等异常行为 |
| 账号封禁管理 | 人工封禁/解封，支持登录级和业务级，可组合动作      |
| 风控事件查询 | 供运营后台查询风控事件记录                |

> **设计关键**：风控强依赖审计日志的完整性。pft-audit 先写日志，pft-risk 通过 CDC 消费审计日志做异步检测；同步校验（下单/提现前黑名单检查）走同步 RPC。

---

## § 4.1.5 权限模型：RBAC + ABAC 融合

> 功能权限用 RBAC（静态角色），数据权限用 ABAC（动态属性），两套菜单分别配置，不过度设计。

### 为什么两个都要

| 场景             | RBAC 能否解决      | ABAC                                     |
| -------------- | -------------- | ---------------------------------------- |
| "能不能点订单查询按钮"   | ✅ 能（菜单/API 权限） | —                                        |
| "能看到哪些订单"      | ❌ 不能           | ✅ `订单.creator_id == 当前用户.id`             |
| "部门领导看本部门订单"   | ❌ 不能           | ✅ `订单.org_path LIKE 当前用户.org_path + '%'` |
| "分销商只看自己分销的订单" | ❌ 不能           | ✅ `订单.distributor_id == 当前用户.id`         |

**结论**：RBAC 管"能不能干"，ABAC 管"能干哪些数据"。两套独立配置，互不影响。

---

### RBAC 部分（功能权限：用户→角色→权限→资源）

**管理菜单**：`系统管理 → 角色管理`

```
角色 = 权限集合，权限 = 资源集合

用户 → 角色 → 权限 → 资源(MENU/BUTTON/API/PAGE)

示例角色：
  ├── 超级管理员（全部权限）
  ├── 老板（订单/商品/财务权限，全部数据）
  ├── 部门经理（本部门数据，可审批）
  ├── 普通员工（自己创建的数据）
  └── 导游（仅下单/游客管理，无价格配置权限）

权限示例（对租户可见）：
  product:manage → 资源: MENU:/product/list, BUTTON:product:create, API:GET /product/list, API:POST /product/create
  order:refund   → 资源: BUTTON:order:refund, API:POST /order/refund
```

**存储**（pft-identity 服务，MySQL）：

```sql
-- 平台级广播表（平台统一维护）
t_sys_permission (id, permission_code, permission_name, module)         -- 权限定义，对租户可见
t_sys_resource (id, resource_code, resource_type, resource_value)       -- 资源定义，type=MENU/BUTTON/API/PAGE
t_sys_permission_resource (permission_id, resource_id)                  -- 权限-资源映射

-- 租户级分片表（按tenant_id分片）
t_sys_role (id, tenant_id, role_code, role_name, status)                -- 角色
t_sys_role_permission (role_id, permission_id, tenant_id)               -- 角色-权限绑定
t_sys_user_role (user_id, role_id, tenant_id)                           -- user_id 语义=t_tenant_staff.id
                                                                        -- 平台员工：tenant_id = 平台租户id，超管由 RBAC SUPER_ADMIN 角色判定
```

**校验链路**：

- 登录时：角色 → 权限 → 资源，展开为 resource_code 列表注入 JWT
- Gateway 层：校验 API 资源权限（请求路径+方法 ∈ Token 中的 API 资源列表）
- 前端：根据 MENU/BUTTON 资源动态渲染菜单和按钮（服务端也校验，不依赖前端）

---

### ABAC 部分（数据权限）

**管理菜单**：`系统管理 → 数据权限规则`（独立菜单，不跟 RBAC 混在一起）

```
数据权限 = 规则引擎，按条件动态过滤数据

规则要素：
  主体属性（User.attr）：角色、部门 org_path、自己创建的 ID
  资源属性（Resource.attr）：订单.creator_id、订单.org_id、订单.distributor_id
  环境属性（Env.attr）：当前时间、请求来源（PC/小程序/OTA）

示例规则：
  规则1（员工）：订单.creator_id == 当前用户.id
  规则2（部门经理）：订单.org_path LIKE 当前用户.org_path + '%'
  规则3（分销商）：订单.distributor_id == 当前用户.distributor_id
  规则4（OTA渠道）：订单.channel == 当前用户.channel_id
```

**存储**（pft-identity 服务，MySQL + Nacos 缓存）：

```sql
-- 数据权限规则表（配置态，由运营配置）
sys_data_permission (
  id, tenant_id, role_id,
  resource_type,        -- 资源类型：ORDER / PRODUCT / TICKET
  attr_field,           -- 属性字段：creator_id / org_id / distributor_id
  attr_value_source,    -- 值来源：SELF（本人）/ DEPT（本部门）/ CUSTOM（自定义）
  custom_values         -- attr_value_source=CUSTOM 时的具体值列表
)

-- 规则缓存到 Nacos，各服务本地内存缓存，登录时注入 Token
```

**校验点**（MyBatis 拦截器，自动注入 WHERE 条件）：

```sql
-- 员工查订单（自动注入）
SELECT * FROM pft_order_2026q3
WHERE tenant_id = 100
  AND creator_id = 10086   -- ← ABAC 自动注入，不需要业务代码写死

-- 部门经理查订单（org_path 前缀匹配）
SELECT * FROM pft_order_2026q3
WHERE tenant_id = 100
  AND org_id IN (SELECT id FROM sys_org WHERE org_path LIKE '0/1/5/%')
```

---

### 性能考虑（重要）

ABAC 条件是 **SQL WHERE 片段**，走数据库的索引，性能可控：

| ABAC 条件类型            | 实现方式                        | 性能                    |
| -------------------- | --------------------------- | --------------------- |
| `creator_id = 当前用户`  | `AND creator_id = ?`，走索引    | ✅ 优秀                  |
| `org_id IN (本部门及下级)` | 登录时预计算部门 ID 列表，注入 IN 条件，走索引 | ✅ 优秀                  |
| `spu_id IN (自定义列表)`  | 登录时缓存 SPU 列表，注入 IN 条件       | ⚠️ 列表大时（>1000）需降级到 ES |
| 复杂多表条件               | 走 ES 查询，不走 MySQL            | ✅ ES filter 效率高       |

> **设计原则**：ABAC 规则尽量用"等于/IN"条件，避免模糊匹配；列表超过 1000 个 ID 时，查询自动路由到 ES（与 §5.3.5 查询分流策略一致）。

---

### RBAC + ABAC 融合流程

```
登录
  → 查 RBAC 角色 → 注入 Token（菜单权限 + API 权限）
  → 查 ABAC 规则 → 注入 Token（数据权限条件模板）
  → 返回 Token 给前端

请求到达 Gateway
  → 校验 Token 有效性
  → 校验 API 权限（RBAC）
  → 转发到业务服务

业务服务执行查询
  → MyBatis 拦截器读取 Token 里的 ABAC 规则
  → 自动注入 WHERE 条件
  → 执行 SQL，返回过滤后数据
```

---

## § 4.2 服务间通信模式

> 同步看一致性、异步看吞吐、Workflow 看可观测的长流程。

| 模式          | 实现                      | 适用场景                           | 幂等保障                |
| ----------- | ----------------------- | ------------------------------ | ------------------- |
| **同步 RPC**  | OpenFeign (HTTP/REST)   | 强一致读写：扣库存、查商品、查价格、下单前置校验       | request_id + 重试退避   |
| **异步消息**    | RocketMQ 5.x (事务消息)     | 状态扩散：订单已支付、票已核销、库存变更、价格快照      | 本地消息表 + 消费幂等键       |
| **编排工作流**   | Workflow引擎（技术选型见§5.1.4） | 跨服务长流程：下单 → 锁库存 → 支付 → 出票 → 通知 | Workflow ID 全局幂等    |
| **事件订阅**    | RocketMQ + 广播订阅         | 领域事件外溢：CDC → 数据管道 / 营销 / 通知    | 消费侧 dedup 表         |
| **OpenAPI** | HTTP / JSON + HMAC 签名   | 外部商户 / 分销商集成                   | X-Idempotency-Key 头 |

---

## § 4.2.1 系统分层架构 · 四层职责分离

> 接入层不能直达核心层，中间需要明确的**业务层**（解释权：选择/组合编排）+ **编排层**（原子能力组装）。核心域只暴露原子能力，不知道上层编排和业务决策。

```
系统分层架构（四层）

┌─────────────────────────────────────────────────────────────┐
│  接入层  │  Gateway + BFF + 防腐层（OTA适配）            │
│         │  Gateway 执行：                                │
│         │  ① 端API权限校验（RBAC，平台运营域管控下发）  │
│         │  ② 限流与流控执行                             │
│         │  ③ locale解析注入（X-PFT-Locale/X-PFT-TimeZone → LocaleContext ThreadLocal）│
│         │  ④ 路由到业务层                                │
├─────────────────────────────────────────────────────────────┤
│  业务层  │  pft-business · 持有业务解释权（Decision）     │
│          │  住在 pft-business 的 app/ 目录                 │
│          │  ① 编排选择：按 productType/channel/tenant      │
│          │     上下文决定要调哪个 Workflow（OrderRouter）   │
│          │  ② 编排组合：多编排串联（如"选座+下单+物流"）   │
│          │  ③ 业务规则配置化驱动（规则引擎按策略表决策）   │
│          │  ④ 选出的编排通过 RPC 下发给编排层执行          │
├─────────────────────────────────────────────────────────────┤
│  编排层  │  Workflow引擎（技术选型见§5.1.4）           │
│          │  住在 pft-orchestration 的 app/ 目录           │
│          │  ① 通用Workflow：下单/退款/核销/分销（业态无关）│
│          │  ② 业态扩展（Activity/Workflow按需组织，       │
│          │     当前示例：库存Adapter/业务Workflow/套票组合）│
│          │  ③ 不知道"为什么选我"——纯能力组装              │
├─────────────────────────────────────────────────────────────┤
│  核心层  │  Product / Pricing / Order / Inventory /       │
│          │  Payment / Finance / Credential / Distribution  │
│          │  各域只暴露原子能力，业态无关，不知道上层编排    │
└─────────────────────────────────────────────────────────────┘
```

### 核心原则

- 核心域只提供原子能力（validate / lock / create / refund / issue / calculatePrice）
- 编排层组合原子能力成为业务流程，不含业务解释逻辑
- **业务层持有解释权**：根据运行时上下文（产品类型/渠道/供应商/租户/实名与否…）决定调哪个编排、串联哪几个编排
- 前端只调一个 `trigger` 接口，不感知后面经过了几个域
- 不同业务场景 = 不同 Workflow 定义，核心域代码不变

### 为什么需要中间两层

- 核心域保持纯净、可独立测试与复用
- 编排逻辑集中在 Workflow，可观测、可版本化
- 业务解释逻辑集中在 pft-business，策略变更只需改配置/规则，不碰编排层和核心层
- 新业态只需在业务层新增策略 + 编排层新增 Activity/Workflow，无需修改核心域代码
- 失败重试 / 补偿 / 超时策略由编排层统一管理

### 业务层-编排层 边界判据（必须钉死）

> 这是两层之间最关键的职责边界。违反以下任何一条，两层会迅速糊到一起。

| #   | 判据                                       | 业务层（pft-business）                                   | 编排层（pft-orchestration）                |
| --- | ---------------------------------------- | --------------------------------------------------- | ------------------------------------- |
| 1   | **知道"为什么"吗？**                            | ✅ 知道——根据 productType/channel/tenant/实名策略等上下文决定选哪个编排 | ❌ 不知道——编排层收到指令直接执行，不关心为什么是这个 Workflow |
| 2   | **可以 if(channel==OTA) 吗？**               | ✅ 可以——这是业务层本职，按渠道选择不同编排组合                           | ❌ 禁止——编排层内部不应该出现渠道/业态等业务判断分支          |
| 3   | **可以组合多个编排吗？**                           | ✅ 可以——如"选座 Workflow + 下单 Workflow + 物流 Workflow"串行  | ❌ 禁止——编排之间不互相调用，组合是业务层的活              |
| 4   | **可以手写 try{ orderService.create() } 吗？** | ❌ 禁止——这是原子能力拼接，是编排层的活                               | ✅ 本职——Activity 内调用核心层原子 API           |
| 5   | **组合粒度是什么？**                             | 编排级（Workflow 为最小组合单元）                               | 原子能力级（核心服务 API 为最小拼接单元）               |
| 6   | **决策由谁驱动？**                              | 规则配置 + 策略表（Nacos 规则中心），避免硬编码 if-else 上帝类            | 不参与决策，被动接收指令                          |

> **一句话总结**：编排层不知道"为什么选我"；业务层不知道"原子能力内部怎么实现"。

### 业务层目录结构规范

> 业务层（`pft-business`）持有解释权——编排的选择与组合。目录聚焦规则配置和决策逻辑。

```
pft-business/src/main/java/.../decision/
├── router/                    # ① 编排路由（决定选哪个Workflow）
│   └── OrderRouter.java                  # 前端统一入口trigger→按productType/channel/tenant路由到编排层Workflow
├── strategy/                  # ② 策略表（规则配置化驱动，避免硬编码if-else）
│   ├── ProductTypeStrategy.java          # 按productType选择Workflow组合
│   ├── ChannelStrategy.java             # 按channel类型选择编排差异
│   └── CompositeStrategy.java           # 编排组合策略（多Workflow串联）
└── config/                    # ③ 规则配置（Nacos规则中心）
    └── BusinessRules.java               # 业务规则加载与决策引擎
```

### 编排层目录结构规范（方案E，调整后）

> 编排层仅负责原子能力组装，不含业务解释（router/ 已上移到 pft-business）。

```
pft-orchestration/src/main/java/.../workflow/
├── common/                    # ① 通用Workflow（业态无关，所有业态必经）
│   ├── PlaceOrderWorkflow.java        # 标准下单
│   ├── OTAPushOrderWorkflow.java      # OTA推单
│   ├── RefundWorkflow.java            # 退款
│   ├── DistributionOrderWorkflow.java # 分销采购
│   └── VerifyWorkflow.java            # 核销后续
├── business/                  # ② 业态业务Workflow（跨域重流程独立编排）
│   ├── hotel/
│   │   ├── HotelCheckInWorkflow.java       # 酒店入住
│   │   └── HotelCheckOutWorkflow.java      # 酒店退房结算
│   ├── logistics/
│   │   └── LogisticsShipWorkflow.java      # 物流发货
│   └── annualpass/
│       └── AnnualPassActivateWorkflow.java # 年卡激活/续费/转赠
├── inventory/                 # ③ 业态库存Adapter（作为Workflow Activity，调用核心层通用池+业态特化逻辑）
│   ├── SeatMapSelectionActivity.java       # 演出选座（调用核心层UNIT池+座位图渲染/锁座）
│   ├── CruiseScheduleActivity.java         # 游船航次（调用核心层UNIT池+航次排班）
│   └── RouteSegmentActivity.java           # 线路行程（调用核心层COUNTING池+多日多段库存联动）
└── composite/                 # ④ 套票组合Workflow（跨业态子票编排与状态聚合）
    └── CompositeTicketWorkflow.java        # 套票主子单拆分/聚合核销/部分退分摊
```

> `router/` 目录已从编排层移除——编排路由（OrderRouter）现在属于 `pft-business` 业务层，负责"解释权"（根据上下文决定调哪个编排）。编排层的责任收缩为：收到业务层下发的 Workflow 类型后，按定义执行 Activity 步骤。

### 编排路由机制（解释权在业务层）

> 前端只调一个 `trigger` 接口，**业务层**根据业态自动路由，编排层按指令执行。前端不感知后面经过了几个域和哪个业态扩展点。

```
前端 trigger(placeOrderRequest)
    ↓
业务层 OrderRouter（按 SPU.productType / channel / tenant 上下文路由）
    → 决定调用哪个 Workflow：
        ├── [标准景区] → PlaceOrderWorkflow
        ├── [OTA推单] → OTAPushOrderWorkflow
        ├── [酒店]     → PlaceOrderWorkflow + HotelCheckInWorkflow（编排组合）
        ├── [演出]     → PlaceOrderWorkflow + SeatMapSelectionActivity
        └── [套票]     → CompositeTicketWorkflow
    ↓
编排层 按指示执行 Workflow → Activity 步骤
    → PlaceOrderWorkflow（通用流程，所有业态必经）
        ├── [酒店] → 业务层已在触发前决定组合 HotelCheckInWorkflow
        ├── [演出] → 业务层已路由到 SeatMapSelectionActivity
        └── [游船] → 业务层已路由到 CruiseScheduleActivity
```

**关键原则**：

- 通用Workflow是所有业态的必经主流程（下单→锁库存→支付→出票）
- 业态扩展点是通用Workflow内的可选Activity，按productType条件触发
- 业态扩展点只调用核心层原子API，不跨Workflow调用
- **业务层决定"选哪个/组合哪几个 Workflow"**，编排层只负责按指令执行
- 新增业态 = 在业务层新增策略 + 在编排层新增Activity/Workflow，不改通用Workflow和核心层

### 典型编排场景示例

> 不同业务场景由不同 Workflow 定义驱动，核心域原子能力保持不变。每个步骤都是独立的幂等 Activity。

| 场景 / Workflow                        | 编排步骤                                                                                                                                                                                                                                                           |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **PlaceOrderWorkflow** (标准C端下单)      | `①ProductService.validateSKU → ②PricingService.calculatePrice → ③InventoryService.lock → ④OrderService.createOrder → ⑤PaymentService.createPayment → ⑥[等待支付Signal] → ⑦OrderService.confirmOrder → ⑧CredentialService.issueCode → ⑨FinanceService.freezeProfit` |
| **OTAPushOrderWorkflow** (OTA推单)     | `①ProductService.validateSKU → ②PricingService.calculatePrice → ③InventoryService.lock → ④OrderService.createOrder(status=PAID) → ⑤CredentialService.issueCode → ⑥FinanceService.freezeProfit`（无支付等待步骤）                                                        |
| **RefundWorkflow** (退款)              | `①OrderService.checkRefundPolicy → ②InventoryService.release → ③PaymentService.refund → ④FinanceService.unfreezeProfit → ⑤CredentialService.revokeCode → ⑥OrderService.updateStatus(REFUNDED)`                                                                 |
| **DistributionOrderWorkflow** (分销采购) | `①DistributionService.checkAuthorization → ②PricingService.calculateSettlement → ③FinanceService.deductBalance → ④InventoryService.lock → ⑤OrderService.createOrder → ⑥CredentialService.issueCode`                                                            |
| **VerifyWorkflow** (核销后续)            | `①CredentialService.validateCode → ②TicketService.markVerified → ③FinanceService.unfreezeToAvailable → ④NotificationService.sendVerifyNotice`                                                                                                                  |

---

## § 4.3 编排层与业务层 设计原则

> 编排层（`pft-orchestration`）负责跨服务长流程的原子能力组装、状态管理与失败重试。业务层（`pft-business`）持有解释权，负责编排的选择与组合。两者职责分离，各司其职。技术选型见 §5.1.4（技术架构文档）。

### 编排层职责边界（pft-orchestration）

- **管流程编排，不管业务逻辑**：所有业务计算委托给核心层服务（Product/Pricing/Inventory/Order/Payment 等）
- **管失败重试与补偿，不管业务规则**：退款规则、库存释放条件等业务逻辑由核心层定义
- **管流程状态持久化，不管数据持久化**：订单状态、库存数据由各核心服务自己的数据库管理
- **不管"为什么选我"**：编排层只按业务层下发的指令执行 Workflow，不关心为什么是这个 Workflow

### 业务层职责边界（pft-business）

- **管编排选择与组合，不管原子能力拼接**：业务层决定"调哪个/组合哪几个 Workflow"，但不手写 Activity 内的原子 API 调用
- **管业务规则解释，不管核心计算**：价格计算、库存扣减等核心逻辑委托给核心层
- **管上下文决策，不管流程执行**：根据 productType/channel/tenant/实名策略等运行时上下文路由，但 Workflow 的实际执行由编排层完成
- **配置化驱动，避免硬编码上帝类**：策略表 + 规则引擎，新增业态/渠道只需加配置而非改代码

### 支持场景

- **交易类**：下单 → 锁库存 → 支付 → 出票 完整链路；退款多分支（未核销/部分核销/全核销）
- **分销类**：分销 4 级采购、库存共享池协商
- **财务类**：充值 → 创建充值订单（财务域） → 调用支付（支付域） → 给账户充虚拟资产（财务域） → 产生交易流水（财务域）
- **核销类**：离线核销冲突仲裁的等待 + 仲裁子流程
- **组合类**：套票主子单的拆分 & 状态聚合
- **OTA类**：OTA推单 → 锁库存 → 创建订单(PAID) → 出票
- **特殊业态**：导游报团（创建草稿 → 现场调整人数 → 确认支付，长时间挂起）；酒店入住/退房结算

### 编排定义版本管理

- 编排定义版本化：老订单跑老版本 Workflow，新订单跑新版本
- Activity 必须幂等：禁止在 Activity 内启子事务
- 业态差异通过规则中心（Nacos）注入，不写死在编排定义里
- 避免 Workflow 内传递大对象（控制 payload 大小）

---

## § 4.4 跨域交互协议 · 领域事件 + Activity 契约

> 核心域之间不直接调用，而是通过两种机制协作：① 编排层 Activity 同步调用核心域API（强一致）；② 领域事件异步扩散状态变更（最终一致）。本节定义完整的领域事件清单和核心 Activity 的接口契约。

---

### 一、领域事件清单

> 事件命名规范：`pft.{domain}.{event}`。所有事件通过 RocketMQ 事务消息发布，消费侧通过 dedup 表保证幂等。

#### 1.1 订单域事件（pft-order 发布）

| 事件                              | Topic                           | 触发时机                      | Payload 结构                                                                                                                                                                                        | 消费方                                                                              |
| ------------------------------- | ------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `pft.order.order_paid`          | `pft-order-order-paid`          | OrderGroup支付成功（PAID）      | `{orderGroupId, sellerTenantId, channelId, channelRef, operatorType, operatorId, buyerType, buyerId, buyerCustomerId, totalAmount, currency, orders[{orderId, skuId, quantity, sellerTenantId}]}` | pft-inventory(确认扣减)、pft-verification(发码)、pft-finance(冻结)、pft-notification(短信通知)  |
| `pft.order.order_cancelled`     | `pft-order-order-cancelled`     | OrderGroup超时取消（CANCELLED） | `{orderGroupId, reason: "PAY_TIMEOUT", orders[{orderId}]}`                                                                                                                                        | pft-inventory(回滚预扣)                                                              |
| `pft.order.order_refunded`      | `pft-order-order-refunded`      | Order全部退款（REFUNDED）       | `{orderGroupId, orderId, refundAmount, refundItems[{ticketId, amount}]}`                                                                                                                          | pft-inventory(回滚)、pft-finance(冻结释放)、pft-verification(撤销码)、pft-notification(退款通知) |
| `pft.order.ticket_verified`     | `pft-order-ticket-verified`     | Ticket核销完成（USED）          | `{ticketId, orderId, verifyPointId, operatorId, entitlementsUsed[{entitlementId, type}]}`                                                                                                         | pft-finance(解冻)、pft-notification(核销通知)                                           |
| `pft.order.ticket_expired`      | `pft-order-ticket-expired`      | Ticket过期（定时任务扫描）          | `{ticketId, orderId, validEnd}`                                                                                                                                                                   | pft-finance(过期释放冻结)、pft-notification(过期提醒)                                       |
| `pft.order.ticket_person_added` | `pft-order-ticket-person-added` | 补录实名（添加Person）            | `{ticketId, personId, name, idType, idNumber, phone}`                                                                                                                                             | pft-identity(关联globalCustomerId，可选)、pft-verification(更新凭证绑定)                     |

#### 1.2 核销域事件（pft-verification 发布）

| 事件                              | Topic                           | 触发时机      | Payload 结构                                            | 消费方                      |
| ------------------------------- | ------------------------------- | --------- | ----------------------------------------------------- | ------------------------ |
| `pft.verify.credential_issued`  | `pft-verify-credential-issued`  | 出票发码完成    | `{ticketId, credentialId, codeValue, credentialType}` | pft-notification(发码短信通知) |
| `pft.verify.credential_revoked` | `pft-verify-credential-revoked` | 凭证撤销（退款时） | `{ticketId, credentialId, reason}`                    | pft-order(联动票状态)         |

#### 1.3 财务域事件（pft-finance 发布）

| 事件                             | Topic                          | 触发时机      | Payload 结构                                                      | 消费方                                     |
| ------------------------------ | ------------------------------ | --------- | --------------------------------------------------------------- | --------------------------------------- |
| `pft.finance.profit_frozen`    | `pft-finance-profit-frozen`    | 票级冻结完成    | `{frozenId, accountId, ticketId, amount, event}`                | pft-audit(审计记录)                         |
| `pft.finance.profit_released`  | `pft-finance-profit-released`  | 解冻/冻结释放完成 | `{frozenId, accountId, amount, releaseType: "VERIFY"/"REFUND"}` | pft-audit(审计记录)、pft-data-pipeline(报表聚合) |
| `pft.finance.withdraw_applied` | `pft-finance-withdraw-applied` | 提现申请提交    | `{withdrawId, subjectId, amount, bankCardId}`                   | pft-risk(提现风控校验)、pft-platform(审批流触发)    |

#### 1.4 风控域事件（pft-risk 发布）

| 事件                           | Topic                        | 触发时机         | Payload 结构                                                                       | 消费方                                       |
| ---------------------------- | ---------------------------- | ------------ | -------------------------------------------------------------------------------- | ----------------------------------------- |
| `pft.risk.rule_hit`          | `pft-risk-rule-hit`          | 风控规则命中       | `{eventId, ruleId, subjectId, dimensionValues, action: "BLOCK"/"WARN"/"FREEZE"}` | pft-notification(预警通知)、pft-identity(账号封禁) |
| `pft.risk.blacklist_updated` | `pft-risk-blacklist-updated` | 黑名单变更（新增/移除） | `{dimension, dimensionValue, action: "ADD"/"REMOVE", bannedActions[]}`           | pft-order(下单校验缓存刷新)、pft-finance(提现校验缓存刷新) |

#### 1.5 库存域事件（pft-inventory 发布）

| 事件                        | Topic                     | 触发时机   | Payload 结构                                      | 消费方                                            |
| ------------------------- | ------------------------- | ------ | ----------------------------------------------- | ---------------------------------------------- |
| `pft.inventory.low_stock` | `pft-inventory-low-stock` | 库存低于阈值 | `{poolId, skuId, availableQuantity, threshold}` | pft-notification(低库存告警通知)                      |
| `pft.inventory.stock_out` | `pft-inventory-stock-out` | 库存售罄   | `{poolId, skuId}`                               | pft-notification(售罄通知)、pft-data-pipeline(售罄聚合) |

#### 1.6 商品域事件（pft-product 发布）

| 事件                            | Topic                         | 触发时机    | Payload 结构                              | 消费方                                                         |
| ----------------------------- | ----------------------------- | ------- | --------------------------------------- | ----------------------------------------------------------- |
| `pft.product.sku_published`   | `pft-product-sku-published`   | SKU上架发布 | `{skuId, spuId, productType, tenantId}` | pft-inventory(建池)、pft-pricing(同步L0默认价)、pft-identity(权限缓存刷新) |
| `pft.product.sku_unpublished` | `pft-product-sku-unpublished` | SKU下架   | `{skuId}`                               | pft-inventory(停售池)                                          |

#### 1.7 用户身份域事件（pft-identity 发布）+ 接入端事件（pft-platform 发布）

> ⚠️ `pft.channel.*` 事件原由 pft-identity 发布，t_channel 等表迁至 pft-platform 后改由 pft-platform 发布。

| 事件                                   | Topic                                | 触发时机                                          | Payload 结构                                                                     | 消费方                                                                    |
| ------------------------------------ | ------------------------------------ | --------------------------------------------- | ------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `pft.identity.customer_registered`   | `pft-identity-customer-registered`   | C端首次登录建 Customer                              | `{customerId, customerKind, registerChannelId, registerTenantId, phone}`       | pft-finance(无账户，仅画像)、pft-notification(欢迎通知)                            |
| `pft.identity.customer_bound_tenant` | `pft-identity-customer-bound-tenant` | C端游客在租户小程序首次绑定                                | `{customerId, tenantId, tenantOpenid, registerSource}`                         | pft-platform(租户画像)、pft-notification                                    |
| `pft.identity.customer_cancelled`    | `pft-identity-customer-cancelled`    | C端注销                                          | `{customerId, cancelReason}`                                                   | pft-finance(清账户)、pft-platform(画像清理)、pft-notification                   |
| `pft.identity.staff_registered`      | `pft-identity-staff-registered`      | B端员工创建                                        | `{staffId, staffType, tenantId, isOwner}`                                      | pft-notification(欢迎)、pft-identity(RBAC角色挂接)                            |
| `pft.identity.tenant_created`        | `pft-identity-tenant-created`        | 商户租户创建（平台租户约定 tenant_no='PLATFORM'，系统启动时自动种子） | `{tenantId, tenantNo, tenantName, ownerStaffId, defaultCustomerId, packageId}` | pft-platform(套餐生效/功能开关)、pft-finance(商户账户+授信)、pft-identity(RBAC角色模板初始化) |
| `pft.channel.channel_created`        | `pft-channel-channel-created`        | 接入端创建（API类按需建）                                | `{channelId, channelCode, channelType, ownerTenantId, defaultOperatorStaffId}` | pft-platform(接入审计)、pft-risk(白名单注册)                                     |
| `pft.channel.mp_config_registered`   | `pft-channel-mp-config-registered`   | 租户小程序 appId 登记                                | `{tenantId, mpType, appId, mpConfigId}`                                        | pft-platform(微信生态联调)、pft-notification                                  |

---

### 二、核心 Activity 接口契约

> 每个 Activity 是编排层 Workflow 内的一个幂等步骤，调用核心域API组合完成。以下定义各核心 Workflow 的 Activity 编排顺序、入参/出参/幂等键。

#### 2.1 PlaceOrderWorkflow · 标准下单编排

```text
前端 trigger(placeOrderRequest)
    ↓
业务层 OrderRouter（在 pft-business，按 SPU.productType 路由）
    → 决定调用 PlaceOrderWorkflow（或组合多个 Workflow）
    ↓
编排层 PlaceOrderWorkflow（在 pft-orchestration，通用流程 + 业态扩展点）

步骤序列（每步=一个幂等Activity）：
```

| #   | Activity                        | 调用API                                | 入参                                                                                                                                                                                                                                | 出参                                    | 幂等键                     | 失败策略              |
| --- | ------------------------------- | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- | ----------------------- | ----------------- |
| A1  | ValidateSKUActivity             | P02 `/product/sku/{skuId}`           | skuId, quantity, date, tenantId                                                                                                                                                                                                   | skuValid, ticketMetas[]               | skuId+date              | 拒绝下单              |
| A2  | CalculatePriceActivity          | PR02 `/pricing/price-point/query`    | skuId, date, channel, extDims                                                                                                                                                                                                     | finalPrice, settlePrice               | skuId+date+channel      | 拒绝下单              |
| A3  | RiskCheckActivity               | R01 `/risk/check`                    | buyerId, actionType=PLACE_ORDER, dimensionValues                                                                                                                                                                                  | pass/reject                           | buyerId+actionType      | 拒绝下单              |
| A4  | InventoryLockActivity           | I01 `/inventory/pool/pre-deduct`     | skuId, dimensionKey, quantity, orderId                                                                                                                                                                                            | poolId, deducted                      | orderId（全局唯一）           | 回滚+拒绝             |
| A4a | ComboInventoryCheckActivity（套票） | I07 `/inventory/pool/and-check`      | items[{skuId, dimKey, qty}]（套票各子项）                                                                                                                                                                                                | allAvailable                          | orderId                 | AND策略：任一子项不足则整体拒绝 |
| A5  | CreateOrderActivity             | T01+T03+T07 创建聚合单+子单+票               | sellerTenantId, channelId, channelRef, operatorType, operatorId, operatorTenantId, buyerType, buyerId, buyerCustomerId, contact, currency, orders[{skuId, qty, sellerTenantId}], tickets[{persons[], entitlements[], bindings[]}] | orderGroupId, orderIds[], ticketIds[] | orderGroupId（全局幂等）      | 回滚库存              |
| A5a | CreateComboOrderActivity（套票）    | T03 创建主Order+子Order                  | parentOrderId=null的主单 + parentOrderId=主单ID的各子Order                                                                                                                                                                                | comboOrderId, subOrderIds[]           | comboOrderId            | 回滚库存              |
| A6  | CreatePaymentActivity           | PAY01 `/payment/pay`                 | orderGroupId, payMethod, amount                                                                                                                                                                                                   | paymentId                             | orderGroupId            | 回滚订单+库存           |
| A7  | IssueCredentialActivity         | V01 `/verification/credential/issue` | ticketId, credentialType, codePoolId                                                                                                                                                                                              | credentialId, codeValue               | ticketId                | 回滚支付+订单+库存        |
| A8  | FreezeProfitActivity            | F01 `/finance/freeze`                | accountId, ticketId, profitShare, event=VERIFY                                                                                                                                                                                    | frozenId                              | ticketId                | 仅记账，不影响主流程        |
| A9  | NotifyActivity                  | (pft-notification内部)                 | templateId, channel, recipient, content                                                                                                                                                                                           | notifyId                              | orderGroupId+templateId | 通知失败不影响主流程        |

> **套票下单特殊步骤**：A4a（AND策略校验）→ A5a（拆主+N子Order）→ 每个子Order独立创建Ticket→ A6-A9按子Order独立执行。

#### 2.2 RefundWorkflow · 退款编排

| #   | Activity                  | 调用API                          | 入参                                     | 出参                                | 幂等键                  | 失败策略 |
| --- | ------------------------- | ------------------------------ | -------------------------------------- | --------------------------------- | -------------------- | ---- |
| R1  | CheckRefundPolicyActivity | T08+T04 查票+子单状态                | ticketIds[], orderId                   | refundableTickets[], refundAmount | orderId+ticketIds    | 拒绝退款 |
| R2  | RiskCheckRefundActivity   | R01 `/risk/check`              | subjectId, actionType=REFUND           | pass/reject                       | subjectId+actionType | 拒绝退款 |
| R3  | InventoryReleaseActivity  | I03 `/inventory/pool/rollback` | poolId, orderId, quantity              | rolledBack                        | orderId              | 补偿重试 |
| R4  | PaymentRefundActivity     | PAY02 `/payment/refund`        | orderGroupId, refundAmount, refundTo   | refundPaymentId                   | orderGroupId         | 补偿重试 |
| R5  | FinanceReleaseActivity    | F03 `/finance/refund-freeze`   | ticketId, amount                       | released                          | ticketId             | 补偿重试 |
| R6  | RevokeCredentialActivity  | (pft-verification内部)           | ticketId, reason=REFUND                | revoked                           | ticketId             | 补偿重试 |
| R7  | UpdateOrderStatusActivity | T06+T12 子单+票状态变迁               | orderId→REFUNDED, ticketIds[]→REFUNDED | updated                           | orderId              | 补偿重试 |

#### 2.3 VerifyWorkflow · 核销编排

| #   | Activity                         | 调用API                                            | 入参                                                    | 出参                                    | 幂等键                             | 失败策略               |
| --- | -------------------------------- | ------------------------------------------------ | ----------------------------------------------------- | ------------------------------------- | ------------------------------- | ------------------ |
| V1  | ValidateCodeActivity             | V02 `/verification/credential/query-by-code`     | codeValue                                             | ticketId, valid                       | codeValue                       | 拒绝核销               |
| V2  | CheckBindingActivity             | T08 查票详情（含personEntitlements）                    | ticketId                                              | persons[], entitlements[], bindings[] | ticketId                        | 拒绝核销（绑定校验不通过）      |
| V2a | CheckPersonIdentityActivity（实名票） | ID04 查个人凭证                                       | globalCustomerId, credentialType, codeValue（刷脸/证件）    | personMatch                           | globalCustomerId+credentialType | EXCLUSIVE校验失败→拒绝核销 |
| V3  | VerifyEntitlementActivity        | V03 `/verification/verify`                       | ticketId, verifyPointId, operatorId, entitlementIds[] | verifyResult, entitlementsUsed[]      | ticketId+verifyPointId          | 拒绝核销               |
| V4  | MarkTicketStatusActivity         | T12 `/order/ticket/{ticketId}/status-transition` | ticketId, targetStatus=USED/PARTIALLY_USED            | newStatus                             | ticketId                        | 补偿重试               |
| V5  | UnfreezeProfitActivity           | F02 `/finance/unfreeze`                          | frozenId                                              | unfrozen                              | frozenId                        | 补偿重试               |
| V6  | NotifyVerifyActivity             | (pft-notification内部)                             | ticketId, verifyResult                                | notifyId                              | ticketId                        | 通知失败不影响核销          |

#### 2.4 CompositeTicketWorkflow · 套票组合编排

| #   | Activity                     | 调用API                        | 入参                                                         | 出参               | 幂等键          | 失败策略      |
| --- | ---------------------------- | ---------------------------- | ---------------------------------------------------------- | ---------------- | ------------ | --------- |
| C1  | CreateComboOrderActivity     | T03 创建主Order(comboFlag=true) | orderGroupId, comboSkuId, totalPrice                       | comboOrderId     | comboOrderId | 回滚        |
| C2  | CreateSubOrdersActivity      | T03 批量创建子Order               | comboOrderId, subItems[{skuId, unitPrice, sellerTenantId}] | subOrderIds[]    | comboOrderId | 回滚主Order  |
| C3  | CreateComboTicketActivity    | T07 创建主票（编排定义+整体有效期）         | comboOrderId, persons[], validPeriod                       | comboTicketId    | comboOrderId | 回滚子Orders |
| C4  | CreateSubTicketsActivity     | T07 批量创建子票（权益下沉）             | subOrderIds[], 各子票persons[]+entitlements[]+bindings[]      | subTicketIds[]   | comboOrderId | 回滚主票      |
| C5  | ComboInventoryCheckActivity  | I07 AND策略校验                  | subItems各子项poolId+dimensionKey+quantity                    | allAvailable     | comboOrderId | 整体拒绝      |
| C6  | ComboStatusAggregateActivity | T06 主Order状态聚合               | comboOrderId, 各子Order status                               | 主Order newStatus | comboOrderId | 补偿重试      |

> **套票退款特殊步骤**：套票退款按子Order独立执行RefundWorkflow，主Order状态由C6聚合计算。部分退只退部分子Order（如只退门票子票），酒店子票不受影响。

---

> **以上领域事件+Activity契约构成概要设计的协作协议输入**——事件Topic和Payload直接定义RocketMQ消费者，Activity入参/出参直接映射编排层Workflow步骤代码，幂等键直接用于防重复执行。

---

## § 4.5 剩余 11 个微服务 · REST API 定义

> §2（API 接口清单，已合入 `pft-arch-02-core-models.md`）覆盖 9 个核心服务（trade/product/pricing/inventory/payment/verification/finance/risk/identity），共 **60 个接口**。本节补充剩余 11 个服务的完整 API 定义，共 **97 个接口**。编排层（`pft-orchestration`）对外仅暴露 `trigger` 入口，内部 Workflow/Activity API 不对外发布。

### 统一约定

> 以下 11 个服务 API 共享的约定：

| 约定项  | 规则                                                 |
| ---- | -------------------------------------------------- |
| 接口风格 | RESTful + 幂等键（xxxNo）                               |
| 路径参数 | 用业务号（uk唯一索引），内部查id再操作                              |
| 认证方式 | Gateway统一JWT校验 → RBAC API权限 → 转发                   |
| 错误码  | 7位数字：`{3位服务编号}{4位错误类型}`（详见HLD §6.2），内部和对外统一返回原始数字码 |
| 幂等保障 | request_id + 重试退避（同步）；dedup表（异步）                   |

**错误码范围分配**（与 HLD §6.2.2 完全对齐）：

**核心服务（9个）**：

| 服务                | 编号  | 错误码范围           | 示例                                                        |
| ----------------- | --- | --------------- | --------------------------------------------------------- |
| pft-product       | 001 | 0010000~0019999 | 0010004=SKUNotFound, 0010005=SKUAlreadyExists             |
| pft-pricing       | 002 | 0020000~0029999 | 0020004=PricePointNotFound, 0020006=PriceConflict         |
| pft-inventory     | 003 | 0030000~0039999 | 0030004=PoolNotFound, 0030006=InsufficientStock           |
| pft-order         | 004 | 0100000~0109999 | 0100004=OrderNotFound, 0100006=OrderStateConflict         |
| pft-orchestration | 005 | 0500000~0509999 | 0500001=WorkflowNotFound, 0500006=WorkflowStateConflict   |
| pft-payment       | 006 | 0300000~0309999 | 0300004=PaymentNotFound, 0300006=PaymentStateConflict     |
| pft-verification  | 007 | 0400000~0409999 | 0400004=CredentialNotFound, 0400006=CredentialAlreadyUsed |
| pft-finance       | 008 | 0200000~0209999 | 0200004=AccountNotFound, 0200006=InsufficientBalance      |
| pft-risk          | 009 | 0700000~0709999 | 0700004=RuleNotFound, 0700005=Blacklisted                 |

**补充服务（11个）**：

| 服务                | 编号  | 错误码范围           | 示例                                                  |
| ----------------- | --- | --------------- | --------------------------------------------------- |
| pft-identity      | 010 | 0600000~0609999 | 0600004=UserNotFound, 0600006=CredentialConflict    |
| pft-device        | 011 | 0800000~0809999 | 0800004=DeviceNotFound, 0800006=DeviceStateConflict |
| pft-business      | 012 | 0510000~0519999 | 0510001=RouteNotFound, 0510006=DecisionRuleConflict |
| pft-distribution  | 013 | 0900000~0909999 | 0900004=RelationNotFound, 0900006=ChainTooDeep      |
| pft-platform      | 014 | 0110000~0119999 | 0110004=DictNotFound, 0110005=DictAlreadyExists     |
| pft-notification  | 015 | 0120000~0129999 | 0120004=TemplateNotFound, 0120006=SendFailed        |
| pft-audit         | 016 | 0130000~0139999 | 0130004=LogNotFound                                 |
| pft-application   | 017 | 0140000~0149999 | 0140004=AppNotFound, 0140005=AppAlreadyExists       |
| pft-marketing     | 018 | 0150000~0159999 | 0150004=CouponNotFound, 0150006=CouponStockOut      |
| pft-data-pipeline | 019 | 0160000~0169999 | 0160004=SyncTaskNotFound, 0160006=TaskStateConflict |
| pft-open-platform | 020 | 0170000~0179999 | 0170004=ApiKeyNotFound, 0170006=PushFailed          |

**通用错误码**（所有服务共享，000开头）：

| 错误码     | 说明               |
| ------- | ---------------- |
| 0000001 | 参数校验失败           |
| 0000002 | 未认证（未登录）         |
| 0000003 | 无权限（RBAC拦截）      |
| 0000004 | 资源不存在            |
| 0000005 | 资源已存在（唯一约束冲突）    |
| 0000006 | 操作冲突（并发修改/状态不允许） |
| 0000007 | 系统内部错误           |
| 0000008 | 限流（Gateway流控拦截）  |

---

### 4.5.0 pft-business · 业务决策服务

> 业务层持有解释权——根据运行时上下文（productType/channel/tenant/实名策略）决定调哪个编排、是否需要组合多个编排。对外仅暴露 `trigger` 入口（前端统一入口），内部 Strategy/Router 不对外发布。

| #   | 方法   | 路径                                  | 说明                | 入参关键字段                                                                                                                                                          | 出参关键字段                                               | 错误码范围                          |
| --- | ---- | ----------------------------------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- | ------------------------------ |
| B01 | POST | `/business/trigger`                 | 统一业务触发入口          | workflowType(PLACE_ORDER/REFUND/VERIFY/DISTRIBUTION_ORDER/OTA_PUSH/COMBO), businessContext(productType/channel/tenant/compositeFlag), payload(JSON,各Workflow不同) | decisionId, workflowTypes[], timestamp               | 0510000~0519999                |
| B02 | GET  | `/business/decision/{decisionId}`   | 查决策结果             | decisionId                                                                                                                                                      | decisionId, selectedWorkflows[], routeReason, status | 0510004=DecisionNotFound       |
| B03 | GET  | `/business/decision/query`          | 查询决策历史（管理后台）      | workflowType, businessContext, dateFrom, dateTo, pageNum, pageSize                                                                                              | decisions[], total                                   | —                              |
| B04 | GET  | `/business/strategy/{strategyCode}` | 查策略配置             | strategyCode                                                                                                                                                    | Strategy完整（productType→workflow映射、composition rules） | 0510004=StrategyNotFound       |
| B05 | PUT  | `/business/strategy/{strategyCode}` | 更新策略配置（热更新到Nacos） | strategyCode, rules[], compositeRules[]                                                                                                                         | updated                                              | 0510006=StrategyUpdateConflict |

**请求/响应结构体示例**：

```json
// B01 POST /business/trigger 请求体（下单场景）
{
  "workflowType": "PLACE_ORDER",
  "businessContext": {
    "productType": "SCENIC_TICKET",
    "channelId": "CH_MINIPROGRAM",
    "tenantId": "TNT001",
    "compositeFlag": false,
    "realNameFlag": true
  },
  "payload": {
    "buyerId": "USR001",
    "orders": [
      {"skuId": "SKU001", "quantity": 2, "sellerTenantId": "TNT001"}
    ],
    "payMethod": "WECHAT"
  },
  "idempotencyKey": "OG20260701001"
}

// B01 响应体
{
  "decisionId": "DEC20260701001",
  "selectedWorkflows": ["PlaceOrderWorkflow"],
  "routeReason": "productType=SCENIC_TICKET, channel=MINIPROGRAM → PlaceOrderWorkflow",
  "composition": null,
  "timestamp": "2026-07-01T10:00:00.000+08:00"
}

// 组合编排场景响应体
{
  "decisionId": "DEC20260701002",
  "selectedWorkflows": ["PlaceOrderWorkflow", "LogisticsShipWorkflow"],
  "routeReason": "productType=LOCAL_PRODUCT, channel=MINIPROGRAM → PlaceOrderWorkflow + LogisticsShipWorkflow (composite)",
  "composition": {"mode": "SEQUENTIAL", "workflowOrder": ["PlaceOrderWorkflow", "LogisticsShipWorkflow"]},
  "timestamp": "2026-07-01T10:05:00.000+08:00"
}
```

---

### 4.5.1 pft-orchestration · 编排服务

> 编排层接收业务层下发的 Workflow 类型指令后执行原子能力组装，内部Workflow/Activity API不对外发布。业务层（pft-business）持有解释权——决定调哪个/组合哪几个 Workflow，编排层只负责按指令执行。

| #   | 方法   | 路径                                            | 说明                 | 入参关键字段                                                                                               | 出参关键字段                                                    | 错误码范围                         |
| --- | ---- | --------------------------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ----------------------------- |
| O01 | POST | `/orchestration/trigger`                      | 统一编排触发入口           | workflowType(PLACE_ORDER/REFUND/VERIFY/DISTRIBUTION_ORDER/OTA_PUSH/COMBO), payload(JSON,各Workflow不同) | workflowId, workflowType, status(STARTED/FAILED)          | 0500000~0509999               |
| O02 | GET  | `/orchestration/workflow/{workflowId}`        | 查Workflow执行状态      | workflowId                                                                                           | workflowId, workflowType, currentActivity, status, result | 0500004=WorkflowNotFound      |
| O03 | POST | `/orchestration/workflow/{workflowId}/signal` | 发送Signal（如支付成功回调）  | workflowId, signalType(PAY_SUCCESS/PAY_TIMEOUT), signalPayload                                       | signalAccepted                                            | 0500006=WorkflowStateConflict |
| O04 | POST | `/orchestration/workflow/{workflowId}/cancel` | 取消Workflow         | workflowId, reason                                                                                   | cancelled                                                 | 0500006=WorkflowStateConflict |
| O05 | GET  | `/orchestration/workflow/query`               | 查询Workflow列表（管理后台） | workflowType, orderGroupNo, status, pageNum, pageSize                                                | workflows[], total                                        | —                             |

**请求/响应结构体示例**：

```json
// O01 POST /orchestration/trigger 请求体（下单场景）
{
  "workflowType": "PLACE_ORDER",
  "payload": {
    "buyerId": "USR001",
    "channel": "MINI_PROGRAM",
    "contact": {"name": "张三", "phone": "13800138000"},
    "orders": [
      {"skuId": "SKU001", "quantity": 2, "sellerTenantId": "TNT001"}
    ],
    "payMethod": "WECHAT"
  },
  "idempotencyKey": "OG20260701001"   // orderGroupNo作为幂等键
}

// O01 响应体
{
  "workflowId": "WF20260701001",
  "workflowType": "PLACE_ORDER",
  "status": "STARTED",
  "orderGroupNo": "OG20260701001"      // 下单场景返回聚合单号
}
```

---

### 4.5.2 pft-device · 设备服务

| #   | 方法   | 路径                                | 说明           | 入参关键字段                                                                                                                        | 出参关键字段                  | 错误码范围                           |
| --- | ---- | --------------------------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------- | ------------------------------- |
| D01 | POST | `/device/register`                | 注册设备         | deviceType(GATE/POS/HANDHELD/Self_Service/KIOSK/FACE_RECOGNITION), deviceName, tenantId, poiId, capabilities[], deviceGroupNo | deviceNo                | 0800005=DeviceAlreadyRegistered |
| D02 | GET  | `/device/{deviceNo}`              | 查设备详情        | deviceNo                                                                                                                      | Device完整                | 0800004=DeviceNotFound          |
| D03 | PUT  | `/device/{deviceNo}/status`       | 更新设备状态       | deviceNo, deviceStatus(ACTIVE/OFFLINE/MAINTENANCE)                                                                            | updated                 | 0800006=DeviceStateConflict     |
| D04 | POST | `/device/heartbeat`               | 设备心跳上报       | deviceNo, timestamp, capabilitiesStatus                                                                                       | heartbeatAccepted       | —                               |
| D05 | POST | `/device/group/create`            | 创建设备分组       | groupNo, groupName, tenantId, poiId, verifyPointId                                                                            | groupNo                 | 0800005=GroupAlreadyExists      |
| D06 | GET  | `/device/group/{groupNo}`         | 查设备分组详情      | groupNo                                                                                                                       | DeviceGroup完整+devices[] | 0800004=GroupNotFound           |
| D07 | PUT  | `/device/{deviceNo}/bind-group`   | 设备绑定分组       | deviceNo, groupNo                                                                                                             | bound                   | 0800004/0800006                 |
| D08 | GET  | `/device/group/{groupNo}/devices` | 查分组下所有设备     | groupNo                                                                                                                       | Device[]                | —                               |
| D09 | GET  | `/device/query`                   | 查询设备列表（管理后台） | tenantId, deviceType, deviceStatus, poiId, pageNum, pageSize                                                                  | devices[], total        | —                               |

**请求/响应结构体**：

```json
// D01 POST /device/register 请求体
{
  "deviceType": "GATE",
  "deviceName": "东门闸机#3",
  "tenantId": "TNT001",
  "poiId": "POI001",
  "capabilities": ["VERIFY", "IDENTIFY"],
  "deviceGroupNo": "DG001"
}

// D01 响应体
{
  "deviceNo": "DEV20260701001",
  "deviceType": "GATE",
  "deviceName": "东门闸机#3",
  "deviceStatus": "ACTIVE",
  "tenantId": "TNT001"
}
```

---

### 4.5.3 pft-distribution · 分销服务

| #    | 方法   | 路径                                               | 说明        | 入参关键字段                                                                                                                                     | 出参关键字段                         | 错误码范围                                                       |
| ---- | ---- | ------------------------------------------------ | --------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------ | ----------------------------------------------------------- |
| DS01 | POST | `/distribution/relation/create`                  | 建立分销关系    | supplierTenantId, distributorTenantId, parentRelationId, distributionMode(PROFIT_SHARE/PURCHASE), paymentMode(CREDIT/BALANCE), creditLimit | relationNo                     | 0900005=RelationAlreadyExists, 0900006=RelationChainTooDeep |
| DS02 | GET  | `/distribution/relation/{relationNo}`            | 查分销关系详情   | relationNo                                                                                                                                 | DistributionRelation完整         | 0900004=RelationNotFound                                    |
| DS03 | GET  | `/distribution/relation/chain`                   | 查分销链（4级）  | skuId, distributorTenantId                                                                                                                 | chain[]（供应商→一级→二级→三级）          | —                                                           |
| DS04 | POST | `/distribution/relation/{relationNo}/suspend`    | 暂停分销关系    | relationNo, reason                                                                                                                         | suspended                      | 0900006=RelationStateConflict                               |
| DS05 | POST | `/distribution/shared-pool/create`               | 创建共享库存池映射 | relationId, sourcePoolNo, quotaType(HARD/SOFT/ROLLING), quotaQuantity                                                                      | sharedPoolNo                   | 0900005=PoolAlreadyExists                                   |
| DS06 | GET  | `/distribution/shared-pool/{sharedPoolNo}`       | 查共享池详情    | sharedPoolNo                                                                                                                               | SharedInventoryPool完整          | 0900004=PoolNotFound                                        |
| DS07 | PUT  | `/distribution/shared-pool/{sharedPoolNo}/quota` | 更新配额      | sharedPoolNo, quotaQuantity                                                                                                                | updated                        | —                                                           |
| DS08 | GET  | `/distribution/settlement-price/query`           | 查分销结算价    | skuId, distributorTenantId                                                                                                                 | settlePrice, calculationMethod | —                                                           |
| DS09 | POST | `/distribution/refund/create`                    | 分销退款      | orderGroupNo, refundItems[], refundMode(逐级退/分润反退)                                                                                          | refundNo                       | —                                                           |

---

### 4.5.4 pft-platform · 平台运营服务

| #    | 方法   | 路径                                          | 说明          | 入参关键字段                                                                                               | 出参关键字段                                                                            | 错误码范围                            |
| ---- | ---- | ------------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | -------------------------------- |
| PL01 | POST | `/platform/dict/create`                     | 创建字典项       | dictType, dictCode, dictName, dictNameEn, scope, tenantId                                            | dictId                                                                            | 0110005=DictAlreadyExists        |
| PL02 | GET  | `/platform/dict/list`                       | 查字典列表       | dictType, scope                                                                                      | DictItem[]                                                                        | —                                |
| PL03 | PUT  | `/platform/dict/{dictType}/{dictCode}`      | 更新字典项       | dictType, dictCode, dictName, dictNameEn                                                             | updated                                                                           | 0110004=DictNotFound             |
| PL04 | POST | `/platform/package/create`                  | 创建套餐包       | packageName, packagePrice, durationDays, featurePermissions[], resourceLimits                        | packageNo                                                                         | —                                |
| PL05 | GET  | `/platform/package/list`                    | 查套餐列表       | —                                                                                                    | Package[]                                                                         | —                                |
| PL06 | POST | `/platform/package/subscribe`               | 订购套餐        | tenantId, packageId, subscriptionType(NEW/RENEW/UPGRADE)                                             | subscriptionNo                                                                    | 0110006=PackageAlreadySubscribed |
| PL07 | GET  | `/platform/package/subscription/{tenantId}` | 查租户当前套餐     | tenantId                                                                                             | Subscription完整                                                                    | —                                |
| PL08 | POST | `/platform/approval-flow/create`            | 创建审批流       | flowName, flowCode, flowDefinition[], scope                                                          | flowNo                                                                            | —                                |
| PL09 | POST | `/platform/approval/submit`                 | 提交审批        | flowCode(或flowId), businessNo, applicantId, businessContext                                          | instanceNo                                                                        | —                                |
| PL10 | POST | `/platform/approval/{instanceNo}/approve`   | 审批通过        | instanceNo, approverId, comment                                                                      | approved                                                                          | 0110006=ApprovalStateConflict    |
| PL11 | POST | `/platform/approval/{instanceNo}/reject`    | 审批拒绝        | instanceNo, approverId, comment                                                                      | rejected                                                                          | 0110006=ApprovalStateConflict    |
| PL12 | POST | `/platform/complaint/create`                | 创建投诉工单      | complainantType, complainantId, complaintType, content, orderGroupNo                                 | complaintNo                                                                       | —                                |
| PL13 | GET  | `/platform/complaint/{complaintNo}`         | 查工单详情       | complaintNo                                                                                          | Complaint完整                                                                       | 0110004=ComplaintNotFound        |
| PL14 | PUT  | `/platform/complaint/{complaintNo}/assign`  | 分派工单        | complaintNo, handlerId, slaDeadline                                                                  | assigned                                                                          | —                                |
| PL15 | POST | `/platform/third-party-channel/create`      | 创建第三方服务渠道配置 | serviceType(PAYMENT/MESSAGE/FILE/INVOICE/VERIFY/MAP/LOGISTICS/OTA), channelCode, configParams, scope | channelNo                                                                         | 0110005=ChannelAlreadyExists     |
| PL16 | GET  | `/platform/third-party-channel/list`        | 查第三方渠道列表    | serviceType, scope                                                                                   | ThirdPartyChannel[]                                                               | —                                |
| PL17 | POST | `/platform/access-endpoint/create`          | 创建接入端配置     | endpointType, endpointName, otaChannel, allowedApiPaths[], rateLimitConfig                           | endpointNo                                                                        | —                                |
| PL18 | GET  | `/platform/access-endpoint/list`            | 查接入端列表      | endpointType                                                                                         | AccessEndpoint[]                                                                  | —                                |
| PL19 | GET  | `/platform/i18n/language/list`              | 查支持语言列表     | —                                                                                                    | Language[]{localeCode, languageName, languageNameEn, status}                      | —                                |
| PL20 | GET  | `/platform/i18n/currency/list`              | 查支持币种列表     | —                                                                                                    | Currency[]{currencyCode, currencyName, currencySymbol, exchangeRateToCNY, status} | —                                |
| PL21 | POST | `/platform/i18n/translation/create`         | 创建翻译记录      | tableName, entityId, fieldName, locale, fieldValue                                                   | translationId                                                                     | 0110005=TranslationAlreadyExists |
| PL22 | GET  | `/platform/i18n/translation/query`          | 查翻译记录       | tableName, entityId, fieldName, locale                                                               | Translation[]{id, tableName, entityId, fieldName, locale, fieldValue}             | —                                |
| PL23 | PUT  | `/platform/i18n/translation/{id}`           | 更新翻译记录      | fieldValue                                                                                           | updated                                                                           | 0110004=TranslationNotFound      |
| PL24 | POST | `/platform/i18n/translation/batch`          | 批量导入翻译      | translations[{tableName, entityId, fieldName, locale, fieldValue}]                                   | count                                                                             | —                                |

---

### 4.5.5 pft-notification · 通知服务

| #   | 方法   | 路径                                    | 说明      | 入参关键字段                                                                                                       | 出参关键字段           | 错误码范围                         |
| --- | ---- | ------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------ | ---------------- | ----------------------------- |
| N01 | POST | `/notification/template/create`       | 创建通知模板  | templateCode, templateName, notifyChannel(SMS/MINI_PROGRAM_MSG/EMAIL/WEBHOOK/IN_APP), templateContent, scope | templateNo       | 0120005=TemplateAlreadyExists |
| N02 | GET  | `/notification/template/list`         | 查模板列表   | notifyChannel, scope, tenantId                                                                               | NotifyTemplate[] | —                             |
| N03 | PUT  | `/notification/template/{templateNo}` | 更新模板    | templateNo, templateContent                                                                                  | updated          | 0120004=TemplateNotFound      |
| N04 | POST | `/notification/send`                  | 发送通知    | templateCode, recipientId, recipientType, params(变量值), relatedBusinessNo                                     | notifyNo         | 0120006=SendFailed            |
| N05 | POST | `/notification/send-batch`            | 批量发送通知  | templateCode, recipients[{recipientId, recipientType, params}], relatedBusinessNo                            | notifyNos[]      | 0120006                       |
| N06 | POST | `/notification/verify-code/send`      | 发送验证码   | phone, verifyCodeType(LOGIN/REGISTER/RESET_PASSWORD), tenantId                                               | sendSuccess      | 0120006=RateLimited           |
| N07 | POST | `/notification/verify-code/check`     | 校验验证码   | phone, code, verifyCodeType                                                                                  | pass/reject      | 0120006=CodeExpired           |
| N08 | GET  | `/notification/record/{notifyNo}`     | 查通知记录   | notifyNo                                                                                                     | NotifyRecord完整   | 0120004=RecordNotFound        |
| N09 | GET  | `/notification/record/query`          | 查通知记录列表 | recipientId, notifyChannel, sendStatus, dateFrom, dateTo                                                     | records[], total | —                             |

---

### 4.5.6 pft-audit · 审计服务

| #    | 方法   | 路径                             | 说明             | 入参关键字段                                                                                            | 出参关键字段        | 错误码范围               |
| ---- | ---- | ------------------------------ | -------------- | ------------------------------------------------------------------------------------------------- | ------------- | ------------------- |
| AU01 | POST | `/audit/log/create`            | 写审计日志          | operatorId, operatorType, action, resourceType, resourceId, detail, ipAddress, tenantId, logScope | logNo         | —                   |
| AU02 | GET  | `/audit/log/{logNo}`           | 查审计日志详情        | logNo                                                                                             | AuditLog完整    | 0130004=LogNotFound |
| AU03 | GET  | `/audit/log/query`             | 查审计日志列表（管理后台）  | operatorId, action, resourceType, dateFrom, dateTo, tenantId, logScope, pageNum, pageSize         | logs[], total | —                   |
| AU04 | GET  | `/audit/log/query-by-resource` | 查资源变更历史        | resourceType, resourceId                                                                          | logs[]        | —                   |
| AU05 | GET  | `/audit/log/stats`             | 审计统计（操作频次/异常率） | tenantId, dateFrom, dateTo, action                                                                | stats[]       | —                   |

---

### 4.5.7 pft-application · 应用服务

| #    | 方法   | 路径                                         | 说明        | 入参关键字段                                                      | 出参关键字段          | 错误码范围                        |
| ---- | ---- | ------------------------------------------ | --------- | ----------------------------------------------------------- | --------------- | ---------------------------- |
| AP01 | POST | `/application/app/create`                  | 创建应用定义    | appName, appCode, appType(BUILTIN/THIRD_PARTY), description | appNo           | 0140005=AppAlreadyExists     |
| AP02 | GET  | `/application/app/list`                    | 查应用列表     | appType                                                     | AppDefinition[] | —                            |
| AP03 | GET  | `/application/app/{appNo}`                 | 查应用详情     | appNo                                                       | AppDefinition完整 | 0140004=AppNotFound          |
| AP04 | POST | `/application/binding/create`              | 创建套餐-应用绑定 | packageId, appId                                            | bindingId       | 0140005=BindingAlreadyExists |
| AP05 | GET  | `/application/binding/package/{packageId}` | 查套餐应用列表   | packageId                                                   | AppDefinition[] | —                            |
| AP06 | POST | `/application/tenant-app/enable`           | 租户启用应用    | tenantId, appId                                             | enabled         | 0140004/0140006              |
| AP07 | GET  | `/application/tenant-app/{tenantId}`       | 查租户已启用应用  | tenantId                                                    | TenantApp[]     | —                            |

---

### 4.5.8 pft-marketing · 营销服务（P3）

| #    | 方法   | 路径                                   | 说明       | 入参关键字段                                                                                                                                             | 出参关键字段       | 错误码范围                                        |
| ---- | ---- | ------------------------------------ | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | -------------------------------------------- |
| MK01 | POST | `/marketing/coupon/create`           | 创建优惠券    | couponName, couponType(FIXED_AMOUNT/PERCENT_DISCOUNT/FREE_VERIFY), couponValue, applicableSkuIds, totalCount, effectiveFrom, effectiveTo, tenantId | couponNo     | 0150005=CouponAlreadyExists                  |
| MK02 | GET  | `/marketing/coupon/{couponNo}`       | 查优惠券详情   | couponNo                                                                                                                                           | Coupon完整     | 0150004=CouponNotFound                       |
| MK03 | GET  | `/marketing/coupon/list`             | 查优惠券列表   | tenantId, couponStatus                                                                                                                             | Coupon[]     | —                                            |
| MK04 | POST | `/marketing/coupon/{couponNo}/claim` | 用户领取优惠券  | couponNo, userId                                                                                                                                   | userCouponId | 0150006=CouponExpired/0150006=CouponStockOut |
| MK05 | GET  | `/marketing/coupon/user/{userId}`    | 查用户优惠券列表 | userId, couponStatus(AVAILABLE/USED/EXPIRED)                                                                                                       | UserCoupon[] | —                                            |
| MK06 | POST | `/marketing/coupon/use`              | 使用优惠券    | userCouponId, orderGroupNo                                                                                                                         | used         | 0150006=CouponStateConflict                  |
| MK07 | POST | `/marketing/activity/create`         | 创建营销活动   | activityName, activityType, startTime, endTime, rules[], tenantId                                                                                  | activityNo   | —                                            |
| MK08 | GET  | `/marketing/activity/list`           | 查活动列表    | tenantId, activityStatus                                                                                                                           | Activity[]   | —                                            |

---

### 4.5.9 pft-data-pipeline · 数据管道服务

| #    | 方法   | 路径                                         | 说明        | 入参关键字段                                                                                          | 出参关键字段                                                           | 错误码范围                     |
| ---- | ---- | ------------------------------------------ | --------- | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------- |
| DP01 | POST | `/data-pipeline/cdc-task/create`           | 创建CDC同步任务 | sourceTable, targetType(ES/STARROCKS/KAFKA), targetName, syncMode(REALTIME/BATCH), fieldMapping | taskNo                                                           | 0160005=TaskAlreadyExists |
| DP02 | GET  | `/data-pipeline/cdc-task/{taskNo}`         | 查CDC任务详情  | taskNo                                                                                          | CdcSyncTask完整                                                    | 0160004=TaskNotFound      |
| DP03 | PUT  | `/data-pipeline/cdc-task/{taskNo}/pause`   | 暂停CDC任务   | taskNo                                                                                          | paused                                                           | 0160006=TaskStateConflict |
| DP04 | PUT  | `/data-pipeline/cdc-task/{taskNo}/resume`  | 恢复CDC任务   | taskNo                                                                                          | resumed                                                          | 0160006                   |
| DP05 | GET  | `/data-pipeline/cdc-task/list`             | 查CDC任务列表  | sourceTable, targetType, taskStatus                                                             | CdcSyncTask[]                                                    | —                         |
| DP06 | GET  | `/data-pipeline/search/product`            | 搜索商品（ES）  | keyword, productType, tenantId, pageNum, pageSize                                               | products[], total                                                | —                         |
| DP07 | GET  | `/data-pipeline/search/order`              | 搜索订单（ES）  | keyword, orderStatus, tenantId, dateFrom, dateTo, pageNum, pageSize                             | orders[], total                                                  | —                         |
| DP08 | GET  | `/data-pipeline/report/realtime/sales`     | 实时销售看板    | tenantId, date(今日)                                                                              | SalesRealtime{totalOrders, totalAmount, totalVerified, avgPrice} | —                         |
| DP09 | GET  | `/data-pipeline/report/realtime/inventory` | 实时库存看板    | tenantId, skuId                                                                                 | InventoryRealtime{totalAvailable, totalFrozen, totalSold}        | —                         |

---

### 4.5.10 pft-open-platform · 开放平台服务（P3）

> Partner 模式统一口径（详见 `pft-arch-02-database.md` §2.9.1）：**所有 OTA/小程序/H5/PC/API 接入方都是渠道（Channel）**，由 `channel_id` 引用 `t_channel.id`。`channel` 字符串枚举（DOUYIN/MEITUAN/CTRIP/FLIGGY）已统一替换为 `channel_id`。

| #    | 方法   | 路径                                      | 说明                 | 入参关键字段                                                                                                                    | 出参关键字段                                       | 错误码范围                       |
| ---- | ---- | --------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | --------------------------- |
| OP01 | POST | `/open-platform/api-key/create`         | 创建API密钥（**一渠道一套**） | **channelId**（必填，FK→t_channel.id）, allowedInterfaces[], rateLimitQps, expiresAt, tenantId(可选，仅channel_scope=TENANT时填)     | keyNo, appKey, appSecret                     | 0170005=ApiKeyAlreadyExists |
| OP02 | GET  | `/open-platform/api-key/{keyNo}`        | 查API密钥详情           | keyNo                                                                                                                     | ApiKey完整（不含appSecret）                        | 0170004=ApiKeyNotFound      |
| OP03 | PUT  | `/open-platform/api-key/{keyNo}/revoke` | 撤销API密钥            | keyNo, reason                                                                                                             | revoked                                      | 0170006=KeyStateConflict    |
| OP04 | POST | `/open-platform/order/push`             | OTA推单（外部合作方调用）     | orderItems[], buyerInfo, **channelId**（必填）, otaMerchantId（对应t_channel_tenant_binding.ota_merchant_id）, contact, persons[] | orderGroupNo, ticketNos[], credentialCodes[] | 0170006=PushFailed          |
| OP05 | POST | `/open-platform/order/refund`           | OTA退款请求            | orderGroupNo, refundItems[], **channelId**（必填）                                                                            | refundNo                                     | 0100004/0100006             |
| OP06 | GET  | `/open-platform/order/{orderGroupNo}`   | OTA查订单状态           | orderGroupNo                                                                                                              | OrderGroup摘要+票状态                             | 0100004                     |
| OP07 | GET  | `/open-platform/product/list`           | OTA查可分销商品          | **channelId**（必填）, **tenantId**（必填，按t_channel_tenant_binding限定）, productType, pageNum                                     | products[]                                   | —                           |

**认证方式**：开放平台所有接口使用HMAC签名鉴权。请求头必须包含：

- `X-PFT-AppKey`: 分配的AppKey（**一渠道（channel_id）一套**，通过 channel_id 关联 t_channel + t_api_key）
- `X-PFT-Timestamp`: 当前时间戳（毫秒）
- `X-PFT-Signature`: HMAC-SHA256(AppKey + Timestamp + Body, AppSecret)
- `X-Idempotency-Key`: 幂等键（推单场景必须）
- 鉴权流程：先按 AppKey 查到 channel_id，再校验 IP 白名单 / 时间窗 / 签名，最后按 channel_tenant_binding 校验调用方是否有权操作该 tenant_id

**不在本节范围**（后续详细设计）：加密算法选择、签名版本号、timestamp 容忍窗口、nonce 去重存储、拉单/核销模式接口（OP08/OP09/OP10）。

---

### 11个服务API统计

| 服务                | 接口数    | 认证方式        | 阶段  |
| ----------------- | ------ | ----------- | --- |
| pft-business      | 5      | Gateway JWT | MVP |
| pft-orchestration | 5      | Gateway JWT | MVP |
| pft-device        | 9      | Gateway JWT | MVP |
| pft-distribution  | 9      | Gateway JWT | P2  |
| pft-platform      | 24     | Gateway JWT | MVP |
| pft-notification  | 9      | Gateway JWT | P2  |
| pft-audit         | 5      | Gateway JWT | P2  |
| pft-application   | 7      | Gateway JWT | P2  |
| pft-marketing     | 8      | Gateway JWT | P3  |
| pft-data-pipeline | 9      | Gateway JWT | P2  |
| pft-open-platform | 7      | HMAC签名      | P3  |
| **11服务合计**        | **97** | —           | —   |

> **9 个核心服务 60 个接口 + 11 个补充服务 97 个接口 = 20 个微服务共 157 个 REST API**。加上 Gateway 限流/鉴权/BFF 适配接口，全系统对外 API 总量约 165。
