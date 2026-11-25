# PFT 2.0 完整数据库设计

> **CHAPTER 02 · DATABASE DESIGN**
>
> PFT 2.0 完整数据库设计，按18个一级领域展开，输出全部69张表DDL。所有DDL遵循O-04k命名规范。

## 设计原则

> 所有DDL遵循以下统一规范（O-04k + i18n规范）：

| 规范项 | 规则 |
|--------|------|
| 主键 | `id BIGINT NOT NULL AUTO_INCREMENT` |
| 业务ID | `xxx_no VARCHAR(32) NOT NULL` + `UNIQUE KEY uk_xxx_no (xxx_no)` |
| 审计字段 | 5个：`create_time/update_time/create_by/update_by/deleted` |
| 金额 | `BIGINT`（分），不使用DECIMAL |
| 状态 | `VARCHAR(20)` 存英文code，前端按locale渲染 |
| 字段约束 | 所有字段 `NOT NULL + DEFAULT`，JSON字段允许NULL |
| 字符集 | utf8mb4，InnoDB引擎 |
| 分库维度 | `tenant_id BIGINT NOT NULL`（对外也用tenant_id传入） |
| 业务引用ID | 统一BIGINT：sku_id/spu_id/pool_id等内部引用字段用BIGINT，对应业务编号用xxx_no |
| 禁止is_前缀 | deleted用TINYINT(0/1)，不使用is_deleted |
| COMMENT | 每个表和字段必须有COMMENT |

---

## 一、领域表清单

### 1. 订单域（pft-order 库）

| 表名 | 说明 |
|------|------|
| t_order_group | 聚合单 |
| t_order | 子单 |
| t_ticket | 票 |
| t_ticket_person | 票上的人 |
| t_entitlement | 权益 |
| t_person_entitlement_binding | 人-权益绑定 |
| t_payment_record | 支付记录 |
| t_refund_order | 退款单 |
| t_refund_detail | 退款明细 |

### 2. 支付域（pft-payment 库）

| 表名 | 说明 |
|------|------|
| t_payment_record | 支付记录（支付域独立副本，结构与交易库相同） |
| t_payment_channel_config | 支付渠道配置 |
| t_merchant_payment_config | 商户收款配置 |

### 3. 核销域（pft-verification 库）

| 表名 | 说明 |
|------|------|
| t_ticket_credential | 票凭证 |
| t_code_pool | 码池 |
| t_verify_point | 核销点 |
| t_verify_record | 核销记录 |

### 4. 财务域（pft-finance 库）

| 表名 | 说明 |
|------|------|
| t_account | 统一账户 |
| t_frozen_record | 冻结记录 |
| t_fund_flow | 资金流水 |
| t_withdraw_order | 提现单 |
| t_bank_card | 银行卡 |
| t_invoice_config | 商户发票配置 |
| t_invoice_order | 发票单 |
| t_resource_batch | 资源批次（短信/积分） |

### 5. 商品域（pft-product 库）

| 表名 | 说明 |
|------|------|
| t_spu | SPU（产品） |
| t_sku | SKU（票型） |
| t_sku_version_snapshot | SKU版本快照（每次属性变更时存旧版本） |
| t_ticket_meta | 票属性元数据 |
| t_sku_meta_value | SKU票属性值 |
| t_sale_rule | 售卖规则 |
| t_sale_rule_item | 售卖条件项 |

### 6. 价格域（pft-pricing 库）

| 表名 | 说明 |
|------|------|
| t_price_point | 价格点 |
| t_pricing_rule | 定价规则 |

### 7. 库存域（pft-inventory 库）

| 表名 | 说明 |
|------|------|
| t_inventory_pool | 库存池 |
| t_inventory_unit | UNIT池具体资源 |
| t_shared_inventory_pool | 共享库存池映射 |

### 8. 风控域（pft-risk 库）

| 表名 | 说明 |
|------|------|
| t_risk_rule | 控规则 |
| t_blacklist | 黑名单 |
| t_risk_event | 风控事件 |
| t_account_ban | 账号封禁 |

### 9. 用户域（pft-identity 库）

> C端游客与B端员工完全分离；平台超管=特殊租户下的员工；Channel-First 接入端(t_channel/t_tenant_mp_config/t_channel_tenant_binding)已迁至平台运营域(pft-platform)。

| 表名 | 说明 |
|------|------|
| t_customer | C端游客/会员主账号（含租户代下单占位买家 TENANT_DEFAULT + 真人注册账号 REAL；**PLATFORM 租户下不设 PLATFORM_DEFAULT 占位**——平台业务强制注册均为 REAL） |
| t_customer_identity | C端多渠道身份识别（微信openid/支付宝uid/OTA uid等） |
| t_customer_credential | C端个人凭证（身份证/护照/驾驶证/人脸等，跨订单复用；id_number从customer表移出至此） |
| t_tenant_staff | B端员工（非分片单表；含内部员工与租户员工；org_id归属主部门、position_id归属主岗位；登录凭证移至t_staff_credential；安全配置移至t_staff_config；is_owner/staff_type已删除，分类走RBAC角色；超管判定 = INTERNAL租户 + SUPER_ADMIN RBAC双因子） |
| t_staff_credential | B端员工登录凭证（非分片单表；PASSWORD/MFA_TOTP/WECHAT_WORK_SCAN等；password_hash从staff表移出；与C端t_customer_credential核验凭证无关，B/C分开） |
| t_staff_config | 员工配置（1:N KV，非分片单表；mfa_enabled/login_2fa_confirm/session_timeout等；模式对称t_tenant_config） |
| t_tenant | 租户（tenant_type区分INTERNAL内部运营主体/EXTERNAL外部业务租户；内部租户可多个平级均对外卖货；default_customer_id已删，占位买家反查t_customer；currency/locale迁t_tenant_config） |
| t_tenant_config | 租户配置(1:N KV，currency/locale等偏好，加载时全量查+缓存) |
| t_org | 租户内部门架构（自引用树，非分片单表；GROUP→外挂t_group+t_group_tenant，MERCHANT=租户本身，本表只管部门/班组） |
| t_tenant_position | 租户岗位定义（非分片单表；岗位≠角色，岗位描述"做什么"，角色描述"能做什么"；员工1:1岗位） |
| t_sys_role | RBAC角色（单套体系；按tenant_id分片） |
| t_sys_permission | 权限定义（**广播表**；平台统一维护功能权限项，对租户可见；如product:manage/order:refund） |
| t_sys_resource | 资源定义（**广播表**；平台统一维护；resource_type区分MENU/BUTTON/API/PAGE等） |
| t_sys_role_permission | 角色-权限绑定（按tenant_id分片；替代原t_sys_role_menu+t_sys_role_api） |
| t_sys_permission_resource | 权限-资源映射（**广播表**；平台维护每个权限包含哪些资源） |
| t_sys_user_role | 员工角色绑定（user_id 实为 tenant_staff_id；按tenant_id分片） |
| t_sys_data_permission | ABAC数据权限规则（按tenant_id分片） |

### 10. 设备域（pft-device 库）

| 表名 | 说明 |
|------|------|
| t_device | 设备 |
| t_device_group | 设备分组 |

### 11. 分销域（pft-distribution 库）

| 表名 | 说明 |
|------|------|
| t_distribution_relation | 分销关系 |
| t_shared_inventory_pool | 共享库存池映射（分销域视角） |

### 12. 平台运营域（pft-platform 库）

| 表名 | 说明 |
|------|------|
| t_sys_dict | 平台字典 |
| t_package | 套餐包 |
| t_package_subscription | 套餐订购记录 |
| t_approval_flow | 审批流定义 |
| t_approval_instance | 审批实例 |
| t_complaint | 投诉工单 |
| t_channel | 接入端定义（预置5个平台端 + 按需API端；服务商级；Channel-First 统一接入模型；**从用户域迁入**） |
| t_channel_tenant_binding | 渠道-租户绑定（一个渠道下挂载1或N个租户；承载OTA侧商户ID映射；**从用户域迁入**） |
| t_tenant_mp_config | 租户小程序 appId 配置（多小程序：微信/支付宝/抖音；**从用户域迁入**） |
| ~~t_access_endpoint~~ | ~~接入端配置~~ **已废弃，功能并入 t_channel** |
| t_i18n_language | 支持语言列表 |
| t_i18n_currency | 支持币种列表 |
| t_i18n_translation | 通用翻译表（多语言字段存储） |
| t_country | 国家字典（广播表，名称走 t_i18n_translation） |
| t_region | 地区字典（自引用树+level，广播表，不固化省市区三级） |
| t_config_meta | 平台配置元数据（统一管理TENANT/STAFF等各KV配置表合法key/类型/校验规则/默认值） |

### 13. 通知域（pft-notification 库）

| 表名 | 说明 |
|------|------|
| t_notify_template | 通知模板 |
| t_notify_record | 通知记录 |

### 14. 审计域（pft-audit 库）

| 表名 | 说明 |
|------|------|
| t_audit_log | 审计日志 |

### 15. 应用域（pft-application 库）

| 表名 | 说明 |
|------|------|
| t_app_definition | 应用定义 |
| t_app_binding | 套餐-应用绑定 |

### 16. 营销域（pft-marketing 库，P3）

| 表名 | 说明 |
|------|------|
| t_coupon | 优惠券 |

### 17. 数据域（pft-data-pipeline 库）

| 表名 | 说明 |
|------|------|
| t_cdc_sync_task | CDC同步任务 |

### 18. 开放平台域（pft-open-platform 库，P3）

| 表名 | 说明 |
|------|------|
| t_api_key | API密钥 |

---

## 二、完整DDL

---

### 2.1 订单域

#### t_order_group（聚合单）

```sql
CREATE TABLE t_order_group (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    order_group_no      VARCHAR(32)     NOT NULL    COMMENT '聚合单号，支付幂等键来源，由流水号生成器生成',
    -- 卖家（商品归属）
    seller_tenant_id    BIGINT          NOT NULL    COMMENT '卖家租户ID（商品归属租户，聚合单层冗余，子单同值）',
    -- 入口（Channel-First）
    channel_id          BIGINT          NOT NULL    COMMENT '入口端ID（指向 t_channel.id：MP_TENANT_HOSTED/MP_PLATFORM/PC_TENANT/PC_PLATFORM/OFFLINE/API_XXX）',
    app_id              VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '对接端标识（指向t_channel.app_id，标识订单组创建来源端；空串=未指定，历史数据兼容）',
    app_ref             VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '对接端自定义子标识（app_id对应）：小程序=tenant_mp_config_id字符串；API=子渠道号；其他=空串',
    -- 操作人（谁点的下单按钮）
    operator_type       VARCHAR(20)     NOT NULL    COMMENT '操作人类型：CUSTOMER(C端会员)/TENANT_STAFF(B端员工含平台员工)',
    operator_id         BIGINT          NOT NULL    COMMENT '操作人ID（多态：customer_id 或 tenant_staff_id）',
    operator_tenant_id  BIGINT          NOT NULL    COMMENT '操作人所属租户ID（=会话tenant_context_id；C端时=渠道端所属租户或=seller_tenant_id）',
    -- 付款方（谁的钱）
    buyer_type          VARCHAR(20)     NOT NULL    COMMENT '付款方类型：CUSTOMER(会员或租户默认散客占位)/ANONYMOUS(线下现金无主体)',
    buyer_id            BIGINT          NOT NULL    DEFAULT 0 COMMENT '付款方ID（多态；ANONYMOUS时=0）',
    buyer_customer_id   BIGINT          NOT NULL    DEFAULT 0 COMMENT 'C端筛选冗余：buyer_type=CUSTOMER时=buyer_id，否则0（带索引报表用）',
    -- 联系人（脱敏保留）
    contact_name        VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '联系人姓名',
    contact_phone       VARCHAR(20)     NOT NULL    DEFAULT '' COMMENT '联系人手机',
    contact_id_type     VARCHAR(16)     NOT NULL    DEFAULT '' COMMENT '联系人证件类型：ID_CARD/PASSPORT等',
    contact_id_number   VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '联系人证件号',
    -- 金额与状态
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

#### t_order（子单）

```sql
CREATE TABLE t_order (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    order_no            VARCHAR(32)     NOT NULL    COMMENT '子单号，由流水号生成器生成',
    order_group_no      VARCHAR(32)     NOT NULL    COMMENT '归属聚合单号',
    parent_order_no     VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '套票子单指向主单号，非套票=空串',
    combo_flag            TINYINT         NOT NULL    DEFAULT 0 COMMENT '是否套票主单：1=套票主单，0=普通子单或套票子项',
    seller_tenant_id    BIGINT          NOT NULL    COMMENT '卖家商户ID',
    sku_id              BIGINT          NOT NULL    COMMENT 'SKU ID',
    sku_name            VARCHAR(200)    NOT NULL    COMMENT 'SKU名称（下单时快照）',
    sku_version         INT             NOT NULL    DEFAULT 0 COMMENT '下单时SKU版本号（查订单商品属性时按sku_id+sku_version还原）',
    quantity            INT             NOT NULL    COMMENT '购买数量',
    unit_price          BIGINT          NOT NULL    COMMENT '单价（分）；套票主单=套餐总价，套票子单=分摊价',
    sale_dims           JSON            NULL        COMMENT '用户选择的售卖维度快照：{date:"2026-07-05", timeSlot:"10:00-11:00", seatZone:"VIP"}',
    order_status        VARCHAR(20)     NOT NULL    DEFAULT 'PENDING_PAY' COMMENT '状态：PENDING_PAY/PAID/PARTIALLY_VERIFIED/FULLY_VERIFIED/REFUNDED/CANCELLED',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_no (order_no),
    KEY idx_group (order_group_no),
    KEY idx_parent (parent_order_no),
    KEY idx_tenant_sku (tenant_id, sku_id),
    KEY idx_tenant_status (tenant_id, order_status, create_time)
) COMMENT='子单：每种SKU一条，套票拆主+N子';
```

#### t_ticket（票）

```sql
CREATE TABLE t_ticket (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '票号，格式TKT+yyyyMMdd+6位随机',
    order_no            VARCHAR(32)     NOT NULL    COMMENT '归属子单号',
    ticket_status       VARCHAR(20)     NOT NULL    DEFAULT 'AVAILABLE' COMMENT '票状态：AVAILABLE/PARTIALLY_USED/USED/EXPIRED/REFUNDED/CANCELLED',
    valid_start         DATETIME(3)     NOT NULL    DEFAULT '1970-01-01 00:00:00.000' COMMENT '有效期起始（出票时确定或首次核销时延迟确定，毫秒精度）',
    valid_end           DATETIME(3)     NOT NULL    DEFAULT '1970-01-01 00:00:00.000' COMMENT '有效期终止（毫秒精度）',
    pass_policy         VARCHAR(16)     NOT NULL    DEFAULT 'SINGLE' COMMENT '放行策略（从SKU继承）：SINGLE/BATCH',
    metadata            JSON            NULL        COMMENT '业态扩展字段（seatInfo/cabinInfo等）',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ticket_no (ticket_no),
    KEY idx_order (order_no),
    KEY idx_tenant_status (tenant_id, ticket_status, create_time)
) COMMENT='票：一等公民，独立生命周期';
```

#### t_ticket_person（票上的人）

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
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ticket_person (ticket_no, person_id),
    KEY idx_global (global_customer_id)
) COMMENT='票上的人：0~N人，实名票必填；global_customer_id 首次登录后回填';
```

#### t_entitlement（权益）

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
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_entitlement_no (entitlement_no),
    KEY idx_ticket (ticket_no),
    KEY idx_tenant_type (tenant_id, entitlement_type)
) COMMENT='权益：核销最小单元，6种类型';
```

#### t_person_entitlement_binding（人-权益绑定）

```sql
CREATE TABLE t_person_entitlement_binding (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '归属票号',
    person_id           VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '人ID（空串=开放争抢，OPEN模式）',
    entitlement_no      VARCHAR(32)     NOT NULL    COMMENT '权益号',
    binding_type        VARCHAR(16)     NOT NULL    COMMENT '绑定类型：EXCLUSIVE/SHARED/OPEN',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_person_ent (ticket_no, person_id, entitlement_no),
    KEY idx_person (person_id),
    KEY idx_entitlement (entitlement_no)
) COMMENT='人-权益绑定：三角关系核心';
```

#### t_payment_record（支付记录）

> **支付中心统一入口**：支持INBOUND（游客收款）和OUTBOUND（采购付款）两种方向。分销采购链场景下，一个batch含1条INBOUND+N条OUTBOUND，原子提交。

```sql
CREATE TABLE t_payment_record (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    payment_no          VARCHAR(32)     NOT NULL    COMMENT '支付流水号，由流水号生成器生成',
    batch_no            VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '批量支付单号(同批共享),单条时空',
    item_no             VARCHAR(16)     NOT NULL    DEFAULT '' COMMENT '批内项号(批内唯一,标识本条在批中的位置)',
    depend_on_item      VARCHAR(16)     NOT NULL    DEFAULT '' COMMENT '依赖项号(必须在依赖项成功后执行,空=无依赖)',
    order_group_no      VARCHAR(32)     NOT NULL    COMMENT '归属聚合单号',
    pay_direction       VARCHAR(16)     NOT NULL    DEFAULT 'INBOUND' COMMENT '资金方向:INBOUND(收款)/OUTBOUND(采购付款)',
    pay_method          VARCHAR(16)     NOT NULL    COMMENT '支付方式：BALANCE/WECHAT/ALIPAY/CREDIT/OFFLINE/ZERO_FEE等',
    receive_channel     VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '收款渠道(INBOUND时填):CASH/WECHAT_QR/ALIPAY_QR/BANK_TRANSFER/OFFLINE_SYSTEM_OUT(系统外已收)',
    amount              BIGINT          NOT NULL    COMMENT '支付金额（分）',
    settle_amount       BIGINT          NOT NULL    DEFAULT 0 COMMENT '结算金额(分,OUTBOUND=向上采购价;INBOUND=售价;利润=amount-settle_amount)',
    transaction_no      VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '渠道流水号（第三方回调返回或内部渠道同步生成）',
    payer_account_no    VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '付款方账户(OUTBOUND=采购方;INBOUND=空)',
    payee_account_no    VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '收款方账户(INBOUND=卖方;OUTBOUND=供应商)',
    ticket_no          VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '关联票号(用于关联冻结记录)',
    freeze_instructions JSON            NULL        COMMENT '冻结指令快照:[{ticketNo,accountNo,amount,freezeType}]',
    external_frozen     TINYINT         NOT NULL    DEFAULT 0 COMMENT '是否外部渠道冻结:1=第三方冻结(如易宝分账),0=平台内部冻结',
    pay_time            DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '支付时间',
    pay_status          VARCHAR(16)     NOT NULL    DEFAULT 'CREATED' COMMENT '支付状态：CREATED/PAID/PARTIAL_REFUNDED/REFUNDED',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_payment_no (payment_no),
    KEY idx_group (order_group_no),
    KEY idx_batch (batch_no),
    KEY idx_ticket (ticket_no)
) COMMENT='支付记录：支持INBOUND收款/OUTBOUND采购付款/批量支付/冻结指令';
```

> **pay_status 状态说明**：
> - `CREATED`：支付单已创建，等待支付
> - `PAID`：单条支付记录支付成功
> - `PARTIAL_REFUNDED`：部分退款（原支付金额部分退回，如一单多票只退部分票）
> - `REFUNDED`：全额退款（原支付金额全部退回）
>
> **组合支付聚合规则**：OrderGroup.payStatus从UNPAID→PARTIAL_PAID→PAID的变迁由多条PaymentRecord聚合触发：任意一条PaymentRecord回调PAID → OrderGroup进入PARTIAL_PAID；所有PaymentRecord均已PAID且金额之和=totalAmount → OrderGroup进入PAID。PARTIAL_PAID是OrderGroup聚合单层的状态，不是单条PaymentRecord的状态。

#### t_refund_order（退款单）

```sql
CREATE TABLE t_refund_order (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    refund_no           VARCHAR(32)     NOT NULL    COMMENT '退款单号，格式REF+yyyyMMdd+6位随机',
    order_group_no      VARCHAR(32)     NOT NULL    COMMENT '归属聚合单号',
    refund_type         VARCHAR(16)     NOT NULL    COMMENT '退款类型：ORDER_REFUND/COMPENSATION/PARTIAL_REFUND',
    refund_reason       VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '退款原因',
    refund_amount       BIGINT          NOT NULL    COMMENT '退款总金额（分）',
    refund_status       VARCHAR(20)     NOT NULL    DEFAULT 'PENDING' COMMENT '状态：PENDING/APPROVED/PROCESSING/COMPLETED/REJECTED',
    refund_items        JSON            NOT NULL    COMMENT '退款明细：[{orderNo, ticketNos[], amount}]',
    initiator_type      VARCHAR(16)     NOT NULL    COMMENT '发起方：VISITOR/MERCHANT/PLATFORM/SYSTEM/OTA',
    initiator_id        BIGINT          NOT NULL    DEFAULT 0 COMMENT '发起方ID',
    approver_id         BIGINT          NOT NULL    DEFAULT 0 COMMENT '审批人ID',
    approve_time        DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '审批时间',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_refund_no (refund_no),
    KEY idx_group (order_group_no),
    KEY idx_tenant_status (tenant_id, refund_status, create_time)
) COMMENT='退款单：未使用票退款/售后补偿/部分退款';
```

#### t_refund_detail（退款明细）

```sql
CREATE TABLE t_refund_detail (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    refund_detail_no    VARCHAR(32)     NOT NULL    COMMENT '退款明细号，由流水号生成器生成',
    refund_no           VARCHAR(32)     NOT NULL    COMMENT '归属退款单号',
    payment_no          VARCHAR(32)     NOT NULL    COMMENT '关联支付记录号（退款来源）',
    refund_amount       BIGINT          NOT NULL    COMMENT '本次退款金额（分，来自该支付记录的退款部分）',
    refund_channel      VARCHAR(16)     NOT NULL    COMMENT '退款渠道：WECHAT/ALIPAY/BALANCE/CREDIT等（与原支付渠道对应）',
    refund_transaction_no VARCHAR(64)   NOT NULL    DEFAULT '' COMMENT '支付中心返回的退款流水号（用于后续跟踪对账）',
    refund_detail_status VARCHAR(16)    NOT NULL    DEFAULT 'PENDING' COMMENT '明细状态：PENDING/PROCESSING/SUCCESS/FAILED',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_refund_detail_no (refund_detail_no),
    KEY idx_refund_no (refund_no),
    KEY idx_payment_no (payment_no),
    KEY idx_tenant_status (tenant_id, refund_detail_status, create_time)
) COMMENT='退款明细：一次退款动作涉及的多笔支付记录退款详情';
```

> **退款明细用途**：
> - 记录每笔退款用了哪些原始支付记录、各退了多少金额
> - 支付中心返回的退款流水号（refund_transaction_no）用于后续跟踪对账
> - 业务层"退款去向"提示：根据 refund_channel + refund_transaction_no 展示
> - 支持场景：1笔完整退款、1笔部分退款、多笔完整+1笔部分等

---

### 2.2 支付域

#### t_payment_channel_config（支付渠道配置）

```sql
CREATE TABLE t_payment_channel_config (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    channel_code        VARCHAR(16)     NOT NULL    COMMENT '渠道代码：WECHAT/ALIPAY/YEEPAY/UNIONPAY/BALANCE/CREDIT',
    channel_name        VARCHAR(64)     NOT NULL    COMMENT '渠道名称',
    merchant_no         VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '商户号/子商户号',
    app_id              VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '应用ID',
    secret_key          VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '密钥（加密存储）',
    cert_path           VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '证书路径',
    callback_url        VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '回调地址',
    scope               VARCHAR(16)     NOT NULL    DEFAULT 'PLATFORM' COMMENT '配置范围：PLATFORM/TENANT',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID（scope=TENANT时必填）',
    channel_status      VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE/PENDING_APPROVAL',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_channel_scope (channel_code, scope, tenant_id),
    KEY idx_scope_tenant (scope, tenant_id)
) COMMENT='支付渠道配置：平台级/租户级渠道参数';
```

#### t_merchant_payment_config（商户收款配置）

```sql
CREATE TABLE t_merchant_payment_config (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（商户）',
    collection_mode     VARCHAR(16)     NOT NULL    COMMENT '收款模式：PLATFORM_COLLECT/INDEPENDENT',
    channel_code        VARCHAR(16)     NOT NULL    DEFAULT '' COMMENT '独立收款渠道代码（collection_mode=INDEPENDENT时必填）',
    merchant_no         VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '独立收款商户号',
    config_status       VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/PENDING_APPROVAL/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_tenant (tenant_id)
) COMMENT='商户收款配置：代收/独立收款模式';
```

---

### 2.3 核销域

#### t_ticket_credential（票凭证）

```sql
CREATE TABLE t_ticket_credential (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    credential_no       VARCHAR(32)     NOT NULL    COMMENT '凭证号，由流水号生成器生成',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '归属票号',
    credential_type     VARCHAR(16)     NOT NULL    COMMENT '凭证类型：QR_CODE/BAR_CODE/ID_CARD/FACE',
    code_value          VARCHAR(128)    NOT NULL    COMMENT '码值（码池分配）',
    code_pool_id        BIGINT          NOT NULL    DEFAULT 0 COMMENT '归属码池ID',
    status              VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/EXPIRED/REVOKED',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_credential_no (credential_no),
    KEY idx_ticket (ticket_no),
    KEY idx_code_value (code_value),
    KEY idx_pool (code_pool_id)
) COMMENT='票凭证：随票生灭的码值';
```

#### t_code_pool（码池）

```sql
CREATE TABLE t_code_pool (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    pool_no             VARCHAR(32)     NOT NULL    COMMENT '码池编号，格式CP+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '归属商户ID',
    pool_type           VARCHAR(16)     NOT NULL    COMMENT '池类型：SINGLE_TICKET/COMBO_TICKET',
    credential_type     VARCHAR(16)     NOT NULL    DEFAULT 'QR_CODE' COMMENT '凭证类型：QR_CODE/BAR_CODE',
    capacity            BIGINT          NOT NULL    COMMENT '池容量（最大并发码数）',
    allocated_count     BIGINT          NOT NULL    DEFAULT 0 COMMENT '已分配码数',
    recycled_count      BIGINT          NOT NULL    DEFAULT 0 COMMENT '已回收复用码数',
    pool_status         VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_pool_no (pool_no),
    KEY idx_tenant_type (tenant_id, pool_type)
) COMMENT='码池：按商户+票类型建池，码值资源管理';
```

#### t_verify_point（核销点）

```sql
CREATE TABLE t_verify_point (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    verify_point_no     VARCHAR(32)     NOT NULL    COMMENT '核销点编号，格式VP+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '归属商户ID',
    poi_id              BIGINT          NOT NULL    DEFAULT 0 COMMENT '关联POI ID',
    point_name          VARCHAR(128)    NOT NULL    COMMENT '核销点名称（如"东门闸机组"）',
    point_type          VARCHAR(16)     NOT NULL    DEFAULT 'GATE' COMMENT '类型：GATE/COUNTER/SELF_SERVICE/HANDHELD',
    point_status        VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    allowed_sku_ids     JSON            NULL        COMMENT '允许核销的SKU列表（null=全部）',
    device_group_id     BIGINT          NOT NULL    DEFAULT 0 COMMENT '绑定设备分组ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_verify_point_no (verify_point_no),
    KEY idx_tenant_poi (tenant_id, poi_id)
) COMMENT='核销点：闸机组/窗口/自助机/手持机';
```

#### t_verify_record（核销记录）

```sql
CREATE TABLE t_verify_record (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    verify_no           VARCHAR(32)     NOT NULL    COMMENT '核销记录号，格式VF+yyyyMMdd+6位随机',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '核销票号',
    entitlement_no      VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '核销权益号',
    verify_point_id     BIGINT          NOT NULL    COMMENT '核销点ID',
    operator_id         BIGINT          NOT NULL    COMMENT '操作人ID',
    device_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '核销设备ID',
    verify_type         VARCHAR(16)     NOT NULL    DEFAULT 'ONLINE' COMMENT '核销类型：ONLINE/OFFLINE',
    offline_timestamp   BIGINT          NOT NULL    DEFAULT 0 COMMENT '离线时序戳（离线核销时设备时间）',
    verify_result       VARCHAR(16)     NOT NULL    DEFAULT 'SUCCESS' COMMENT '结果：SUCCESS/FAILED/DUPLICATE',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间（在线=服务器时间，离线=回连时间）',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_verify_no (verify_no),
    KEY idx_ticket (ticket_no),
    KEY idx_point_time (verify_point_id, create_time),
    KEY idx_tenant_time (tenant_id, create_time)
) COMMENT='核销记录：每次核销事实，含在线/离线';
```

---

### 2.4 财务域

#### t_account（统一账户）

```sql
CREATE TABLE t_account (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    account_no          VARCHAR(32)     NOT NULL    COMMENT '账户编号，由流水号生成器生成',
    subject_id          BIGINT          NOT NULL    COMMENT '主体ID（商户/分销商/平台）',
    account_kind        VARCHAR(16)     NOT NULL    COMMENT '账户类型：MERCHANT/DISTRIBUTOR/PLATFORM',
    available_balance   BIGINT          NOT NULL    DEFAULT 0 COMMENT '可用余额（分）',
    frozen_balance      BIGINT          NOT NULL    DEFAULT 0 COMMENT '冻结余额（分）',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_account_no (account_no),
    UNIQUE KEY uk_subject_kind (subject_id, account_kind)
) COMMENT='统一账户：商户/分销商/平台各一个';
```

#### t_frozen_record（冻结记录）

> **冻结随支付下发**：冻结在支付确认到账瞬间原子完成（非二次动作）。支持平台内部冻结和外部渠道原生冻结（如易宝分账）两种模式。

```sql
CREATE TABLE t_frozen_record (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    frozen_no           VARCHAR(32)     NOT NULL    COMMENT '冻结记录编号，由流水号生成器生成',
    account_no          VARCHAR(32)     NOT NULL    COMMENT '归属账户编号',
    ticket_no           VARCHAR(32)     NOT NULL    COMMENT '关联票号（票级冻结）',
    amount              BIGINT          NOT NULL    COMMENT '冻结金额（分）= 利润/采购款/全款',
    freeze_type         VARCHAR(16)     NOT NULL    DEFAULT 'PROFIT' COMMENT '冻结类型:PROFIT(利润)/SETTLEMENT(采购款)/FULL(全款,供应商直销)',
    frozen_status       VARCHAR(16)     NOT NULL    DEFAULT 'FROZEN' COMMENT '状态：FROZEN/RELEASED',
    frozen_event        VARCHAR(16)     NOT NULL    COMMENT '冻结事件：VERIFY/REFUND',
    external_frozen     TINYINT         NOT NULL    DEFAULT 0 COMMENT '是否外部渠道冻结:1=第三方冻结(解冻调第三方API),0=平台内部冻结',
    external_channel    VARCHAR(16)     NOT NULL    DEFAULT '' COMMENT '外部渠道(external_frozen=1时):YEEPAY/UNIONPAY等',
    external_frozen_no  VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '外部冻结单号(第三方返回的冻结流水号,解冻时用)',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_frozen_no (frozen_no),
    KEY idx_account (account_no),
    KEY idx_ticket (ticket_no)
) COMMENT='冻结记录：按票冻结，核销解冻/退款释放；支持外部渠道原生冻结';
```

#### t_fund_flow（资金流水）

> **flow_type 扩展**：在原有 `RECHARGE/PAYMENT/REFUND/FREEZE/UNFREEZE/WITHDRAW/FEE/RESOURCE` 基础上新增 `TRANSFER_OUT`（采购转出）/ `TRANSFER_IN`（采购转入），区分于 PAYMENT（游客支付进入）和 REFUND（退款退出）。

```sql
CREATE TABLE t_fund_flow (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    flow_no             VARCHAR(32)     NOT NULL    COMMENT '流水号，格式FL+yyyyMMdd+6位随机',
    account_no          VARCHAR(32)     NOT NULL    COMMENT '归属账户编号',
    flow_type           VARCHAR(16)     NOT NULL    COMMENT '流水类型：RECHARGE/PAYMENT/REFUND/FREEZE/UNFREEZE/WITHDRAW/FEE/RESOURCE/TRANSFER_OUT/TRANSFER_IN',
    amount              BIGINT          NOT NULL    COMMENT '变动金额（分，正=入，负=出）',
    balance_before      BIGINT          NOT NULL    COMMENT '变动前余额（分）',
    balance_after       BIGINT          NOT NULL    COMMENT '变动后余额（分）',
    related_no          VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '关联业务号（订单号/退款号/提现号等）',
    payment_batch_no    VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '关联支付批次号(追溯资金动作来源)',
    fee_item            VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '费用项（短信费/提现手续费等）',
    remark              VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '备注',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_flow_no (flow_no),
    KEY idx_account_time (account_no, create_time),
    KEY idx_tenant_type_time (tenant_id, flow_type, create_time),
    KEY idx_batch (payment_batch_no)
) COMMENT='资金流水：所有账户变动统一记录，含采购扣转(TRANSFER_OUT/IN)';
```

#### t_withdraw_order（提现单）

```sql
CREATE TABLE t_withdraw_order (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    withdraw_no         VARCHAR(32)     NOT NULL    COMMENT '提现单号，格式WD+yyyyMMdd+6位随机',
    account_no          VARCHAR(32)     NOT NULL    COMMENT '提现账户编号',
    subject_id          BIGINT          NOT NULL    COMMENT '提现主体ID（商户/分销商）',
    withdraw_amount     BIGINT          NOT NULL    COMMENT '提现金额（分）',
    bank_card_id        BIGINT          NOT NULL    COMMENT '提现银行卡ID',
    withdraw_status     VARCHAR(20)     NOT NULL    DEFAULT 'PENDING' COMMENT '状态：PENDING/APPROVED/PROCESSING/COMPLETED/REJECTED/FAILED',
    approval_no         VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '审批实例号',
    transaction_no      VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '第三方打款流水号',
    fail_reason         VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '失败原因',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_withdraw_no (withdraw_no),
    KEY idx_account (account_no),
    KEY idx_tenant_status (tenant_id, withdraw_status, create_time)
) COMMENT='提现单：available_balance→银行卡';
```

#### t_bank_card（银行卡）

```sql
CREATE TABLE t_bank_card (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    card_no             VARCHAR(32)     NOT NULL    COMMENT '银行卡编号（系统内ID）',
    subject_id          BIGINT          NOT NULL    COMMENT '归属主体ID（商户/分销商）',
    bank_name           VARCHAR(64)     NOT NULL    COMMENT '银行名称',
    bank_code           VARCHAR(16)     NOT NULL    DEFAULT '' COMMENT '银行代码',
    card_number         VARCHAR(256)    NOT NULL    COMMENT '银行卡号（加密存储）',
    card_holder         VARCHAR(64)     NOT NULL    COMMENT '持卡人姓名',
    card_type           VARCHAR(16)     NOT NULL    DEFAULT 'DEBIT' COMMENT '卡类型：DEBIT/CREDIT',
    branch_name         VARCHAR(128)    NOT NULL    DEFAULT '' COMMENT '开户支行',
    card_status         VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_card_no (card_no),
    KEY idx_subject (subject_id)
) COMMENT='银行卡：商户/分销商提现收款账户';
```

#### t_invoice_config（商户发票配置）

```sql
CREATE TABLE t_invoice_config (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    config_no           VARCHAR(32)     NOT NULL    COMMENT '配置编号，格式IC+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '归属商户ID',
    invoice_title       VARCHAR(128)    NOT NULL    COMMENT '发票抬头',
    tax_no              VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '税号',
    address_phone       VARCHAR(128)    NOT NULL    DEFAULT '' COMMENT '地址电话',
    bank_branch         VARCHAR(128)    NOT NULL    DEFAULT '' COMMENT '开户行及账号',
    default_content     VARCHAR(128)    NOT NULL    DEFAULT '' COMMENT '默认开票内容',
    invoice_provider    VARCHAR(16)     NOT NULL    DEFAULT '' COMMENT '开票服务商：BAIWANG/HANGTIAN/PIAOYITONG',
    provider_app_id     VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '服务商AppID',
    provider_secret     VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '服务商密钥（加密存储）',
    provider_terminal   VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '开票终端号',
    config_status       VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_config_no (config_no),
    KEY idx_tenant (tenant_id)
) COMMENT='商户发票配置：开票抬头+开票账户';
```

#### t_invoice_order（发票单）

```sql
CREATE TABLE t_invoice_order (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    invoice_no          VARCHAR(32)     NOT NULL    COMMENT '发票单号，格式INV+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '开票商户ID',
    invoice_type        VARCHAR(16)     NOT NULL    COMMENT '发票类型：E_NORMAL/E_SPECIAL',
    invoice_subject     VARCHAR(16)     NOT NULL    COMMENT '开票主体：MERCHANT_TO_VISITOR/PLATFORM_TO_MERCHANT',
    order_group_no      VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '关联订单号（商户给游客开票）',
    fee_item            VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '费用项（平台给商户开票时）',
    invoice_amount      BIGINT          NOT NULL    COMMENT '开票金额（分）',
    invoice_config_id   BIGINT          NOT NULL    DEFAULT 0 COMMENT '发票配置ID（引用t_invoice_config）',
    invoice_status      VARCHAR(20)     NOT NULL    DEFAULT 'PENDING' COMMENT '状态：PENDING/APPROVED/INVOICED/RED_INVOICED/REJECTED',
    invoice_file_url    VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '发票文件URL（开票成功后存OSS）',
    approval_no         VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '审批实例号',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_invoice_no (invoice_no),
    KEY idx_tenant_status (tenant_id, invoice_status, create_time),
    KEY idx_order (order_group_no)
) COMMENT='发票单：商户给游客开票/平台给商户开票';
```

#### t_resource_batch（资源批次）

```sql
CREATE TABLE t_resource_batch (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    batch_no            VARCHAR(32)     NOT NULL    COMMENT '批次号，格式RB+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '归属商户ID',
    resource_type       VARCHAR(16)     NOT NULL    COMMENT '资源类型：SMS/POINTS/ALARM_QUOTA',
    total_quantity      BIGINT          NOT NULL    COMMENT '总量（短信条数/积分点数/预警额度）',
    remaining_quantity  BIGINT          NOT NULL    COMMENT '剩余量',
    unit                VARCHAR(16)     NOT NULL    DEFAULT 'COUNT' COMMENT '单位：COUNT/POINT/YUAN',
    expire_at           DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT '过期时间',
    batch_status        VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/EXPIRED/CONSUMED',
    purchase_no         VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '购买流水号（引用资金流水）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_batch_no (batch_no),
    KEY idx_tenant_type (tenant_id, resource_type, expire_at)
) COMMENT='资源批次：短信包/积分/预警额度，FIFO消耗';
```

---

### 2.5 商品域

#### t_spu（SPU产品）

```sql
CREATE TABLE t_spu (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    spu_no              VARCHAR(32)     NOT NULL    COMMENT 'SPU编号，格式SPU+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '归属商户ID',
    product_type        VARCHAR(16)     NOT NULL    COMMENT '产品类型（平台字典）：SCENIC/HOTEL/SHOW/Cruise/RESTAURANT/ANNUAL_PASS/SPECIALTY/TIMED/COUPON/LINE',
    spu_name            VARCHAR(128)    NOT NULL    COMMENT '产品名称',
    poi_id              BIGINT          NOT NULL    DEFAULT 0 COMMENT '关联POI ID',
    description         TEXT            NULL        COMMENT '产品富文本描述',
    cover_image         VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '封面图URL',
    spu_status          VARCHAR(16)     NOT NULL    DEFAULT 'DRAFT' COMMENT '状态：DRAFT/PUBLISHED/UNPUBLISHED',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_spu_no (spu_no),
    KEY idx_tenant_type (tenant_id, product_type),
    KEY idx_tenant_status (tenant_id, spu_status)
) COMMENT='SPU：产品（景区/酒店/演出等）';
```

#### t_sku（SKU票型）

```sql
CREATE TABLE t_sku (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    sku_no              VARCHAR(32)     NOT NULL    COMMENT 'SKU编号，格式SKU+yyyyMMdd+6位随机',
    spu_id              BIGINT          NOT NULL    COMMENT '归属SPU ID',
    tenant_id           BIGINT          NOT NULL    COMMENT '归属商户ID',
    sku_name            VARCHAR(200)    NOT NULL    COMMENT 'SKU名称（如"成人票""VIP套票"）',
    cost_price          BIGINT          NOT NULL    DEFAULT 0 COMMENT '成本价（分）——供应商商品属性，不在售价体系内',
    sale_mode           VARCHAR(16)     NOT NULL    DEFAULT 'FIXED_DATE' COMMENT '售卖模式：FIXED_DATE/TIMED_RESERVATION/PRE_SALE',
    version             INT             NOT NULL    DEFAULT 1 COMMENT '版本号，每次属性变更+1（下单时在t_order记录sku_version）',
    sku_status          VARCHAR(16)     NOT NULL    DEFAULT 'DRAFT' COMMENT '状态：DRAFT/PUBLISHED/UNPUBLISHED',
    tags                 JSON            NULL        COMMENT '标签列表（商户自定义）',
    sale_channels        JSON            NOT NULL    COMMENT '销售渠道列表：[MINI_PROGRAM/WECHAT_SHOP/PC/COUNTER/OTA_DOUYIN/OTA_MEITUAN/OTA_CTRIP]',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_sku_no (sku_no),
    KEY idx_tenant_spu (tenant_id, spu_id),
    KEY idx_tenant_status (tenant_id, sku_status)
) COMMENT='SKU：票型（成人票/儿童票/VIP套票等），version版本号每次属性变更+1';
```

#### t_sku_version_snapshot（SKU版本快照）

```sql
CREATE TABLE t_sku_version_snapshot (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    snapshot_no         VARCHAR(32)     NOT NULL    COMMENT '快照编号，格式SKVS+yyyyMMdd+6位随机',
    sku_id              BIGINT          NOT NULL    COMMENT 'SKU ID',
    version             INT             NOT NULL    COMMENT '版本号（变更前的版本号）',
    snapshot_data       JSON            NOT NULL    COMMENT '商品属性快照：{spu:{name,poiId,productType,coverImage,description}, sku:{name,comboFlag,saleChannels,costPrice,saleMode}, attributes:[{code,name,value}], refundPolicy, verifyRules, priceChangeLog:{oldPrice,newPrice,changeReason}}',
    changed_by          VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '变更操作人',
    change_reason       VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '变更原因',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_snapshot_no (snapshot_no),
    UNIQUE KEY uk_sku_version (sku_id, version),
    KEY idx_tenant_sku (tenant_id, sku_id)
) COMMENT='SKU版本快照：每次SKU属性变更时存旧版本完整属性，含价格变更日志，查订单时按sku_id+version还原';
```

#### t_ticket_meta（票属性元数据）

```sql
CREATE TABLE t_ticket_meta (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    attribute_code      VARCHAR(32)     NOT NULL    COMMENT '属性代码（全局唯一Code）',
    attribute_name      VARCHAR(64)     NOT NULL    COMMENT '属性名称',
    value_type          VARCHAR(16)     NOT NULL    COMMENT '值类型：POLICY_CHOICE/TOGGLE/NUMERIC/TEXT/DATE_RANGE',
    default_value       VARCHAR(128)    NOT NULL    DEFAULT '' COMMENT '默认值',
    scope               VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '适用业态（逗号分隔）',
    impacts             JSON            NOT NULL    COMMENT '影响链：[ORDER/INVENTORY/PRICING/VERIFY/REFUND]',
    conflicts           JSON            NULL        COMMENT '互斥属性列表',
    depends_on          JSON            NULL        COMMENT '依赖前置属性列表',
    ui_hint             JSON            NULL        COMMENT '前端联动规则：{group, show_if}',
    enabled_when        VARCHAR(128)    NOT NULL    DEFAULT '' COMMENT '条件可用性：何条件下可用',
    disabled_when       VARCHAR(128)    NOT NULL    DEFAULT '' COMMENT '条件禁用：何条件下被禁用',
    attribute_status    VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_attribute_code (attribute_code)
) COMMENT='票属性元数据：声明式驱动，新属性=新元数据+新规则配置';
```

#### t_sku_meta_value（SKU票属性值）

```sql
CREATE TABLE t_sku_meta_value (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    sku_id              BIGINT          NOT NULL    COMMENT 'SKU ID',
    attribute_code      VARCHAR(32)     NOT NULL    COMMENT '属性代码（引用t_ticket_meta）',
    attribute_value     VARCHAR(128)    NOT NULL    COMMENT '属性值（POLICY_CHOICE=选项code，TOGGLE=0/1，NUMERIC=数字，TEXT=文本）',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_sku_attr (sku_id, attribute_code),
    KEY idx_attribute (attribute_code),
    KEY idx_tenant (tenant_id)
) COMMENT='SKU票属性值：每个SKU的票属性配置';
```

#### t_sale_rule（售卖规则）

```sql
CREATE TABLE t_sale_rule (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    rule_no             VARCHAR(32)     NOT NULL    COMMENT '规则编号，格式SR+yyyyMMdd+6位随机',
    sku_id              BIGINT          NOT NULL    COMMENT '归属SKU ID',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID',
    effective_from      DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '规则生效时间',
    effective_to        DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT '规则失效时间',
    rule_status         VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_rule_no (rule_no),
    KEY idx_sku (sku_id),
    KEY idx_tenant_status (tenant_id, rule_status)
) COMMENT='售卖规则：定义SKU的一组售卖条件（同rule内item为AND，多rule间为OR），条件项见t_sale_rule_item';
```

#### t_sale_rule_item（售卖条件项）

```sql
CREATE TABLE t_sale_rule_item (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    rule_id             BIGINT          NOT NULL    COMMENT '归属售卖规则ID',
    rule_type           VARCHAR(32)     NOT NULL    COMMENT '条件类型：DATE_RANGE/TIME_SLOT/PRE_SALE_DAYS/DAILY_BUY_WINDOW/PURCHASE_DEADLINE/BLACKOUT_DATE/WEEKDAY_MASK/REGION_LIMIT/AGE_RANGE/CERT_TYPE/MEMBER_LEVEL/CUSTOMER_TAG/GEO_FENCE/PURCHASE_POI/MIN_PURCHASE/MAX_PURCHASE/DAILY_LIMIT_PER_USER',
    rule_value          JSON            NOT NULL    COMMENT '条件值（按rule_type结构化，如DATE_RANGE={from,to}，REGION_LIMIT={regions:[MAINLAND]})',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    KEY idx_rule (rule_id),
    KEY idx_tenant (tenant_id)
) COMMENT='售卖条件项：type+value可扩展，同rule_id下item为AND关系，新增规则类型=加rule_type枚举+校验Adapter';
```

---

### 2.6 价格域

#### t_price_point（价格点）

```sql
CREATE TABLE t_price_point (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    price_no            VARCHAR(32)     NOT NULL    COMMENT '价格点编号，由流水号生成器生成',
    sku_id              BIGINT          NOT NULL    COMMENT 'SKU ID',
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
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_price_no (price_no),
    KEY idx_sku_channel_date (sku_id, channel, date_single),
    KEY idx_sku_channel_range (sku_id, channel, date_from, date_to),
    KEY idx_tenant_sku (tenant_id, sku_id)
) COMMENT='价格点：L0默认价 / L1维度价格点（固定维度提取为列，动态维度用ext_dims JSON）';
```

#### t_pricing_rule（定价规则）

```sql
CREATE TABLE t_pricing_rule (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    rule_no             VARCHAR(32)     NOT NULL    COMMENT '规则编号，格式PR+yyyyMMdd+6位随机',
    sku_id              BIGINT          NOT NULL    COMMENT 'SKU ID',
    rule_type           VARCHAR(16)     NOT NULL    COMMENT '规则类型：MARGIN/SURCHARGE/DISCOUNT/MEMBER_DISCOUNT',
    base_price_ref      VARCHAR(16)     NOT NULL    COMMENT '基准价引用：RETAIL/COUNTER/BASE/CURRENT',
    calculator          VARCHAR(16)     NOT NULL    COMMENT '计算方式：PERCENT/FIXED/MATRIX',
    params              JSON            NOT NULL    COMMENT '计算参数（JSON，随ruleType+calculator变化）',
    priority            INT             NOT NULL    DEFAULT 0 COMMENT '优先级',
    effective_from      DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '生效起始',
    effective_to        DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT '生效终止',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_rule_no (rule_no),
    KEY idx_sku_type (sku_id, rule_type),
    KEY idx_tenant_sku (tenant_id, sku_id)
) COMMENT='定价规则：L2可选规则（分销结算/预约加价/折扣）';
```

---

### 2.7 库存域

#### t_inventory_pool（库存池）

```sql
CREATE TABLE t_inventory_pool (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    pool_no             VARCHAR(32)     NOT NULL    COMMENT '库存池编号，由流水号生成器生成',
    sku_id              BIGINT          NOT NULL    COMMENT 'SKU ID',
    pool_type           VARCHAR(16)     NOT NULL    COMMENT '池类型：COUNTING/UNIT',
    dimension_key       JSON            NULL        COMMENT '维度键组合（如date/roomType/showTime等）',
    total_quantity      BIGINT          NOT NULL    COMMENT '总量（COUNTING池）',
    available_quantity  BIGINT          NOT NULL    COMMENT '可用量（实时）',
    frozen_quantity     BIGINT          NOT NULL    DEFAULT 0 COMMENT '预扣冻结量',
    pool_status         VARCHAR(16)     NOT NULL    DEFAULT 'ON_SALE' COMMENT '池状态：ON_SALE/STOP_SALE/EXPIRED',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_pool_no (pool_no),
    KEY idx_sku_dim (sku_id, dimension_key(128)),
    KEY idx_tenant_sku (tenant_id, sku_id, pool_status)
) COMMENT='库存池：L1 COUNTING / L2 UNIT 按维度键建池';
```

#### t_inventory_unit（UNIT池具体资源）

```sql
CREATE TABLE t_inventory_unit (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    unit_no             VARCHAR(32)     NOT NULL    COMMENT '资源个体编号（座位号/房号/舱位号）',
    pool_no             VARCHAR(32)     NOT NULL    COMMENT '归属库存池编号',
    unit_status         VARCHAR(16)     NOT NULL    DEFAULT 'AVAILABLE' COMMENT '状态：AVAILABLE/FROZEN/OCCUPIED',
    order_no            VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '锁定子单号（FROZEN/OCCUPIED时）',
    metadata            JSON            NULL        COMMENT '资源属性（座位等级/房型等）',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（分库维度）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_unit_no (unit_no),
    KEY idx_pool_status (pool_no, unit_status)
) COMMENT='UNIT池具体资源：需锁定个体的座位/房间/舱位';
```

#### t_shared_inventory_pool（共享库存池映射）

```sql
CREATE TABLE t_shared_inventory_pool (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    relation_id         BIGINT          NOT NULL    COMMENT '分销关系ID',
    source_pool_no      VARCHAR(32)     NOT NULL    COMMENT '源库存池编号（供应商池）',
    shared_pool_no      VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '共享池编号（分销商独立池，软配额模式）',
    quota_type          VARCHAR(16)     NOT NULL    DEFAULT 'HARD' COMMENT '配额类型：HARD/SOFT/ROLLING',
    quota_quantity      BIGINT          NOT NULL    DEFAULT 0 COMMENT '配额数量',
    quota_used          BIGINT          NOT NULL    DEFAULT 0 COMMENT '已用配额',
    sharing_status      VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    KEY idx_relation (relation_id),
    KEY idx_source_pool (source_pool_no)
) COMMENT='共享库存池：分销商从供应商池分配额';
```

---

### 2.8 风控域

#### t_risk_rule（风控规则）

```sql
CREATE TABLE t_risk_rule (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    rule_no             VARCHAR(32)     NOT NULL    COMMENT '规则编号，格式RR+yyyyMMdd+6位随机',
    rule_name           VARCHAR(64)     NOT NULL    COMMENT '规则名称（如"凌晨操作检测"）',
    rule_type           VARCHAR(16)     NOT NULL    COMMENT '规则类型：BLACKLIST/PURCHASE_LIMIT/GEO_FENCE/ABNORMAL_OP/DEFAULT_BREAK',
    scope               VARCHAR(16)     NOT NULL    DEFAULT 'GLOBAL' COMMENT '范围：GLOBAL/TENANT',
    dimension           VARCHAR(16)     NOT NULL    COMMENT '维度：USER_ID/ID_CARD/PHONE/IP/DEVICE_ID',
    threshold           VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '阈值（如"1小时内3次"）',
    time_window         INT             NOT NULL    DEFAULT 0 COMMENT '时间窗口（秒）',
    action              VARCHAR(16)     NOT NULL    DEFAULT 'WARN' COMMENT '动作：BLOCK/WARN/FREEZE',
    rule_status         VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    created_by_type     VARCHAR(16)     NOT NULL    DEFAULT 'SYSTEM' COMMENT '创建方：PLATFORM_ADMIN/TENANT_ADMIN/SYSTEM',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID（scope=TENANT时必填）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_rule_no (rule_no),
    KEY idx_type_scope (rule_type, scope),
    KEY idx_tenant_type (tenant_id, rule_type)
) COMMENT='风控规则：黑名单/购买限制/异常操作检测等';
```

#### t_blacklist（黑名单）

```sql
CREATE TABLE t_blacklist (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    blacklist_no        VARCHAR(32)     NOT NULL    COMMENT '黑名单记录编号',
    dimension           VARCHAR(16)     NOT NULL    COMMENT '维度：USER_ID/ID_CARD/PHONE/IP',
    dimension_value     VARCHAR(64)     NOT NULL    COMMENT '维度值（身份证号/IP等）',
    reason              VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '封禁原因',
    scope               VARCHAR(16)     NOT NULL    DEFAULT 'GLOBAL' COMMENT '范围：GLOBAL/TENANT',
    banned_actions      JSON            NOT NULL    COMMENT '封禁动作组合：[PLACE_ORDER/WITHDRAW/VERIFY/PUBLISH/LOGIN]',
    expires_at          DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT '过期时间（null=永久）',
    blacklist_status    VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/EXPIRED/REVOKED',
    created_by_type     VARCHAR(16)     NOT NULL    DEFAULT 'SYSTEM' COMMENT '创建方：RISK_RULE/MANUAL',
    rule_id             BIGINT          NOT NULL    DEFAULT 0 COMMENT '关联规则ID（规则触发时）',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID（scope=TENANT时）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_blacklist_no (blacklist_no),
    KEY idx_dimension (dimension, dimension_value),
    KEY idx_tenant_scope (tenant_id, scope)
) COMMENT='黑名单：按维度封禁，可组合封禁动作';
```

#### t_risk_event（风控事件日志）

```sql
CREATE TABLE t_risk_event (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    event_no            VARCHAR(32)     NOT NULL    COMMENT '事件编号，格式RE+yyyyMMdd+6位随机',
    event_type          VARCHAR(16)     NOT NULL    COMMENT '类型：RULE_HIT/MANUAL_BAN/MANUAL_UNBAN/ABNORMAL_OP_DETECTED',
    subject_id          BIGINT          NOT NULL    COMMENT '主体ID（用户/商户）',
    dimension_values    JSON            NOT NULL    COMMENT '触发维度值集合',
    rule_id             BIGINT          NOT NULL    DEFAULT 0 COMMENT '关联规则ID',
    action              VARCHAR(16)     NOT NULL    COMMENT '执行动作：BLOCK/WARN/FREEZE',
    detail              VARCHAR(512)    NOT NULL    DEFAULT '' COMMENT '详细描述',
    audit_log_id        BIGINT          NOT NULL    DEFAULT 0 COMMENT '关联审计日志ID',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_event_no (event_no),
    KEY idx_subject (subject_id, create_time),
    KEY idx_type_time (event_type, create_time)
) COMMENT='风控事件日志：规则命中/人工封禁/异常检测';
```

#### t_account_ban（账号封禁记录）

```sql
CREATE TABLE t_account_ban (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    ban_no              VARCHAR(32)     NOT NULL    COMMENT '封禁编号',
    subject_id          BIGINT          NOT NULL    COMMENT '被封禁主体（用户/商户）',
    ban_type            VARCHAR(16)     NOT NULL    COMMENT '封禁类型：LOGIN/BUSINESS',
    banned_actions      JSON            NOT NULL    COMMENT '封禁动作组合：[PLACE_ORDER/WITHDRAW/VERIFY/PUBLISH/LOGIN]',
    reason              VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '封禁原因',
    ban_source          VARCHAR(16)     NOT NULL    DEFAULT 'MANUAL' COMMENT '来源：RISK_RULE/MANUAL',
    rule_id             BIGINT          NOT NULL    DEFAULT 0 COMMENT '关联规则ID（规则自动触发时）',
    expires_at          DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT '过期时间',
    ban_status          VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/EXPIRED/REVOKED',
    revoked_by          VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '解封人',
    revoked_at          DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '解封时间',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ban_no (ban_no),
    KEY idx_subject_status (subject_id, ban_status),
    KEY idx_tenant (tenant_id)
) COMMENT='账号封禁：登录级/业务级封禁，可组合动作';
```

---

### 2.9 用户域

> **架构原则**：
> - C端（Customer）与B端（TenantStaff）账号完全分离
> - tenant_type 区分内外部：INTERNAL(内部运营主体,可多个平级)/EXTERNAL(外部业务租户)；原 tenant_no='PLATFORM' 约定废弃
> - 超管判定 = 所属租户 tenant_type=INTERNAL + RBAC SUPER_ADMIN 角色（双因子，全局超管跨所有租户）
> - 内部租户也对外卖货：所有租户(含INTERNAL)统一设 default customer 占位买家
> - Channel-First 接入端(t_channel/t_tenant_mp_config/t_channel_tenant_binding)已迁至平台运营域(pft-platform)，详见 §2.12
> - Person 延迟建 Customer：下单只建 Person，首次登录才建 Customer（核销不建）
> - 代下单：每租户创建时预置 1 条"代下单占位买家"账号（customer_kind=TENANT_DEFAULT）作 buyer 兜底；t_tenant 不再存 default_customer_id，反查 t_customer 获取
> - 租户偏好(currency/locale等)迁至 t_tenant_config（1:N KV），加载租户时全量查+缓存

#### t_customer（C端主账号，广播表）

```sql
CREATE TABLE t_customer (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    customer_no         VARCHAR(32)     NOT NULL    COMMENT '客户编号，格式CUS+yyyyMMdd+6位随机',
    customer_kind       VARCHAR(16)     NOT NULL    DEFAULT 'REAL' COMMENT '账号类型：REAL(真人注册账号)/TENANT_DEFAULT(业务租户代下单占位买家)；PLATFORM 租户下不设占位买家，故无 PLATFORM_DEFAULT 值',
    wechat_unionid      VARCHAR(64)     DEFAULT NULL COMMENT '微信开放平台unionid（本租户内跨小程序/公众号/App识别；跨租户不收敛，由 (unionid, register_tenant_id) 复合唯一键保证）',
    alipay_user_id      VARCHAR(64)     DEFAULT NULL COMMENT '支付宝uid',
    phone               VARCHAR(20)     DEFAULT NULL COMMENT '联系电话+登录句柄（非唯一，可被本租户内多账号共用；手机登录匹配多个时弹身份选择器）',
    name                VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '姓名/昵称',
    email               VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '邮箱',
    gender              VARCHAR(8)      NOT NULL    DEFAULT '' COMMENT '性别：MALE/FEMALE/UNKNOWN',
    birthday            DATE            NOT NULL    DEFAULT '1970-01-01' COMMENT '生日',
    avatar              VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '头像URL',
    auth_status         VARCHAR(20)     NOT NULL    DEFAULT 'UNAUTHENTICATED' COMMENT '认证状态：UNAUTHENTICATED/PHONE_VERIFIED/PERSON_CERTIFIED',
    customer_status     VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/BANNED/CANCELLED',
    register_source     VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '注册来源渠道编码（channel_code）',
    register_tenant_id  BIGINT          NOT NULL    DEFAULT 0 COMMENT '所属租户ID（self-tenant 隔离：该 customer 仅归属此租户，不跨租户复用；unionid/alipay 唯一键均带此列，phone 非唯一；证件号收敛改走 t_customer_credential 唯一键）',
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_customer_no (customer_no),
    UNIQUE KEY uk_wechat_unionid_tenant (wechat_unionid, register_tenant_id),
    UNIQUE KEY uk_alipay_user_id_tenant (alipay_user_id, register_tenant_id),
    KEY idx_phone_tenant (phone, register_tenant_id),
    KEY idx_kind_status (customer_kind, customer_status),
    KEY idx_register_tenant (register_tenant_id, create_time),
    KEY idx_tenant_kind (register_tenant_id, customer_kind)
) COMMENT='C端游客/会员主账号（广播表；kind=TENANT_DEFAULT为租户代下单占位买家,每租户1条;tenant表不再存default_customer_id,反查本表获取）';
```

> **强识别字段用 NULL**：`wechat_unionid`/`alipay_user_id` 可 NULL，MySQL 唯一索引对 NULL 不校验重复，允许多条缺失并存；`phone` 非唯一、可 NULL 可重复。证件号收敛走 `t_customer_credential.uk_type_code_tenant`。
> **身份识别模型（方案Y，不合并）**：`wechat_unionid`/`alipay_user_id` 为唯一收敛键（带 register_tenant_id，本租户内命中即复用）；证件号收敛走 `t_customer_credential.uk_type_code_tenant (credential_type, code_value, register_tenant_id)`，支持 ID_CARD/PASSPORT 等国际证件；`phone` 降级为非唯一"登录句柄+联系电话"，可被多账号共用——手机登录匹配多个时弹身份选择器，用户每次选一个登入。绑手机遇已占用允许共存（不拒绝、不合并），用户可注销其一或解绑以收敛；禁止解绑账号最后一个凭证；注销=停用保留（CANCELLED，数据留存）；永不自动/验证后合并，罕见保留双方历史转人工。详见 详细设计/pft-identity/数据库设计.md。
> **customer_kind=TENANT_DEFAULT（租户代下单占位买家）**：
> - 每租户创建时同步生成 1 条（含内部租户，内部租户也对外卖货）
> - t_tenant 不再存 default_customer_id，反查 `t_customer WHERE register_tenant_id=? AND customer_kind='TENANT_DEFAULT'`（走 idx_tenant_kind 索引）
> - 业务语义：占位买家**不是真用户**，而是订单 buyer_customer_id 字段的占位符（窗口/员工代下单、现金售票时使用）

#### t_customer_identity（多渠道身份识别，广播表）

```sql
CREATE TABLE t_customer_identity (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    customer_id         BIGINT          NOT NULL    COMMENT '归属 Customer ID',
    identity_type       VARCHAR(32)     NOT NULL    COMMENT '标识类型：WECHAT_OPENID/DOUYIN_OPENID/OTA_UID/ALIPAY_OPENID/OTHER',
    identity_value      VARCHAR(128)    NOT NULL    COMMENT '标识值（openid/OTA用户uid等）',
    bind_channel_id     BIGINT          NOT NULL    DEFAULT 0 COMMENT '产生该标识的接入端ID（指向 t_channel）',
    bind_tenant_id      BIGINT          NOT NULL    DEFAULT 0 COMMENT '产生该标识的租户ID（小程序openid必带；平台端=内部租户id,即 tenant_type=INTERNAL 的租户数值 id）',
    extra_data          JSON            NULL        COMMENT '扩展数据（授权scope/首授时间等）',
    identity_status     VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/REVOKED',
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_identity (identity_type, identity_value),
    KEY idx_customer (customer_id),
    KEY idx_bind_tenant (bind_tenant_id, identity_type)
) COMMENT='C端多渠道身份识别：一个 Customer 可有 N 个渠道标识（不做主账号合并）';
```

#### t_customer_credential（C端个人凭证，广播表；原 t_person_credential 改名）

```sql
CREATE TABLE t_customer_credential (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    credential_no       VARCHAR(32)     NOT NULL    COMMENT '凭证编号，格式PC+yyyyMMdd+6位随机',
    customer_id         BIGINT          NOT NULL    COMMENT '归属 Customer ID',
    register_tenant_id  BIGINT          NOT NULL    DEFAULT 0 COMMENT '注册租户ID（冗余自t_customer.register_tenant_id,用于证件号收敛唯一键）',
    credential_type     VARCHAR(32)     NOT NULL    COMMENT '凭证类型: ID_CARD(身份证)/PASSPORT(护照)/DRIVER_LICENSE(驾驶证)/FACE(人脸)/...(支持国际证件扩展)',
    code_value          VARCHAR(128)    NOT NULL    COMMENT '码值（证件号/faceToken等）',
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_credential_no (credential_no),
    UNIQUE KEY uk_type_code_tenant (credential_type, code_value, register_tenant_id),
    KEY idx_customer_type (customer_id, credential_type),
    KEY idx_tenant (register_tenant_id)
) COMMENT='C端个人凭证: 身份证/护照/驾驶证/人脸等,挂在Customer下跨订单复用; id_number从t_customer移出至此; 证件号收敛=uk_type_code_tenant命中即复用customer; 凭证失效直接软删除(deleted=1),无status字段';
```

#### t_tenant_staff（B端员工，非分片单表）

```sql
CREATE TABLE t_tenant_staff (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    staff_no            VARCHAR(32)     NOT NULL    COMMENT '员工编号(工号),格式yyMMdd+4位随机,纯数字短编号,不带前缀;员工日常使用,越短越好',
    tenant_id           BIGINT          NOT NULL    COMMENT '所属租户ID（内部员工=tenant_type=INTERNAL 租户id）',
    org_id              BIGINT          NOT NULL    DEFAULT 0 COMMENT '所属部门ID(0=未分配; FK→t_org.id); 一个员工只属于一个主部门,多部门数据访问走RBAC角色+数据范围',
    position_id         BIGINT          NOT NULL    DEFAULT 0 COMMENT '岗位ID(0=未分配; FK→t_tenant_position.id); 一个员工一个岗位(1:N),兼岗需求走RBAC角色',
    name                VARCHAR(64)     NOT NULL    COMMENT '姓名',
    phone               VARCHAR(20)     NOT NULL    COMMENT '手机号(数据属性,非唯一;若支持手机号登录,录入时同时存一份到t_staff_credential;否则仅展示用)',
    email               VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '邮箱',
    staff_status        VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/DISABLED/RESIGNED',
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_staff_no (staff_no),
    KEY idx_tenant_phone (tenant_id, phone),
    KEY idx_tenant_status (tenant_id, staff_status),
    KEY idx_tenant_org (tenant_id, org_id),
    KEY idx_tenant_position (tenant_id, position_id)
) COMMENT='B端员工(非分片单表): 租户员工/平台(内部)员工同表; 60万租户×2~3员工≈180万,单表+索引足够,无需分片; 一个员工一个主部门(org_id)+一个岗位(position_id); 兼岗需求走RBAC角色; 登录凭证(password/MFA secret等)移至t_staff_credential; 安全行为配置(mfa_enabled等)移至t_staff_config; 员工分类走RBAC角色(sys_user_role); is_owner/staff_type已删除; 超管判定=所属租户tenant_type=INTERNAL+RBAC SUPER_ADMIN双因子';
```

> **设计要点（t_tenant_staff 重构）**：
> - **非分片单表**：60万租户×2~3员工≈120~180万条，单表 + `(tenant_id, phone)` 索引毫秒级检索。分片反而增加跨片查询复杂度（超管跨租户查员工、登录路由分片解析）。
> - **password_hash 已移出**：密码只是登录凭证之一，B端员工还可能通过企业微信扫码/短信验证码等登录。凭证统一管理在 `t_staff_credential`（PASSWORD/MFA_TOTP/WECHAT_WORK_SCAN 等）。
> - **mfa_enabled 已移出**：MFA 开关属安全行为配置，移至 `t_staff_config`（KV）；MFA 密钥（TOTP secret）属凭证，放 `t_staff_credential`。
> - **is_owner 已删除**：无实际业务作用。注册租户时创建一个 staff + 分配 OWNER 角色即可，"每租户唯一 OWNER"由应用层事务保证（K8 原则），不需要表级 boolean。
> - **staff_type 已删除**：固定枚举不够灵活。员工分类走 RBAC 角色体系（`sys_role` + `sys_user_role`），一个员工可持多角色（如 OPERATOR + FINANCE），每个租户可自定义角色组合。
> - **staff_no 去前缀**：工号是员工日常使用的编号，越短越好。去掉 STF 前缀改为纯数字短格式（`yyMMdd+4位随机`）。tenant_no 保留 TNT 前缀（跨系统引用多，前缀助识别）。
> - **phone 非唯一**：与 C 端 `t_customer.phone` 策略一致，`uk_tenant_phone` 改为普通索引 `idx_tenant_phone`。同一租户内多员工可共用手机号（如前台座机），登录匹配多个时弹身份选择器。
> - **org_id 主部门**：一个员工只属于一个主部门（1:N），用于审批链上报和默认通讯录归属。多部门数据访问走 RBAC 角色 + 数据范围授权。
> - **position_id 单岗位**：一个员工只属于一个岗位（1:N），岗位描述"做什么"（运营主管/安全员）。兼岗需求走 RBAC 角色补偿（N:M），角色描述"能做什么"（查看报表/修改订单）。

#### t_staff_credential（B端员工登录凭证，非分片单表）

```sql
CREATE TABLE t_staff_credential (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    credential_no       VARCHAR(32)     NOT NULL    COMMENT '凭证编号,格式SC+yyyyMMdd+6位随机',
    staff_id            BIGINT          NOT NULL    COMMENT '员工ID（FK→t_tenant_staff.id）',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（冗余,便于按租户批量查询/清理）',
    credential_type     VARCHAR(32)     NOT NULL    COMMENT '凭证类型: PASSWORD(密码hash)/MFA_TOTP(TOTP密钥,加密存储)/WECHAT_WORK_SCAN(企业微信扫码绑定)',
    credential_value    VARCHAR(512)    NOT NULL    DEFAULT '' COMMENT '凭证值(密码bcrypt hash/TOTP secret加密密文等;敏感数据加密存储)',
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_credential_no (credential_no),
    UNIQUE KEY uk_staff_type (staff_id, credential_type),
    KEY idx_tenant (tenant_id)
) COMMENT='B端员工登录凭证(非分片单表): 一个员工可有多种凭证(PASSWORD/MFA_TOTP/企微扫码绑定等); password_hash从t_tenant_staff移出至此; 凭证失效直接软删除(deleted=1),无status字段; 与C端核验凭证t_customer_credential(身份证/人脸)无关,也与C端登录凭证(如有)分开(B/C安全域隔离,管理方不同,数据量差异大)';
```

> **B/C端凭证表为何分开**：
> - **安全等级不同**：B端涉及企业资金操作，需强制MFA/密码策略/IP限制；C端个人账号，策略宽松。混表管理互相干扰。
> - **管理方不同**：B端凭证由租户管理员管（重置密码/离职吊销）；C端由游客自助管理。
> - **数据量差异**：B端~180万，C端千万级，混表 B 端数据被淹没。
> - **爆炸半径**：分表后一端出问题不影响另一端登录。
> - **C端登录凭证缺口**：当前 C 端 `t_customer_identity` 承载 openid 收敛，`t_customer_credential` 承载身份证/人脸核验，但**密码登录无落脚点**（`t_customer` 无 password_hash）。若 C 端未来需密码登录（PC/APP），应新建 `t_customer_login_credential`，与 B 端对称。

#### t_staff_config（员工配置，1:N KV，非分片单表）

```sql
CREATE TABLE t_staff_config (
    id              BIGINT      NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    staff_id        BIGINT      NOT NULL    COMMENT '员工ID（FK→t_tenant_staff.id）',
    tenant_id       BIGINT      NOT NULL    COMMENT '租户ID（冗余,便于按租户批量查询）',
    config_key      VARCHAR(64) NOT NULL    COMMENT '配置键(关联 t_config_meta WHERE config_scope=STAFF): mfa_enabled(是否开启MFA)/login_2fa_confirm(登录二次确认)/session_timeout(会话超时秒数)/ip_whitelist(IP白名单)等',
    config_value    JSON        NULL        COMMENT '配置值(JSON承载,如 true / 3600 / ["10.0.0.1"])',
    create_time     DATETIME    NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME    NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by       VARCHAR(64) NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by       VARCHAR(64) NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted         TINYINT     NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_staff_key (staff_id, config_key),
    KEY idx_tenant (tenant_id)
) COMMENT='员工配置(1:N KV,非分片单表): mfa_enabled/login_2fa_confirm/session_timeout等安全行为配置; MFA密钥(TOTP secret)放t_staff_credential不在此; 模式对称t_tenant_config; 取值校验依赖平台域 t_config_meta(WHERE config_scope=STAFF) + 应用层ConfigParser; 加载员工时全量查+缓存兜底';
```

#### t_tenant（租户，广播表）

```sql
CREATE TABLE t_tenant (
    id              BIGINT       NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    tenant_no       VARCHAR(32)  NOT NULL    COMMENT '租户编号,格式TNT+yyyyMMdd+6位随机;内部租户同样走此规则,不再用PLATFORM约定',
    tenant_name     VARCHAR(128) NOT NULL    COMMENT '租户名称',
    tenant_type     VARCHAR(20)  NOT NULL    DEFAULT 'EXTERNAL'
                    COMMENT '租户类型: INTERNAL(内部运营主体,可多个,平级)/EXTERNAL(外部业务租户)',
    contact_phone   VARCHAR(20)  NOT NULL    COMMENT '联系人手机号',
    country_code    VARCHAR(2)   NOT NULL    DEFAULT 'CN'
                    COMMENT '国家码 ISO 3166-1(如 CN/US/JP),关联 t_country.country_code',
    region_id       BIGINT       NOT NULL    DEFAULT 0
                    COMMENT '最末级地区ID,关联 t_region.id;0表示未设置',
    region_path     VARCHAR(256) NOT NULL    DEFAULT ''
                    COMMENT '行政区划完整路径(冗余,取自 t_region.region_path),展示+检索用,如"中国/福建省/厦门市/思明区"',
    business_types  JSON         NOT NULL    COMMENT '业态列表(多选):[SCENIC/HOTEL/SHOW/...]',
    auth_status     VARCHAR(20)  NOT NULL    DEFAULT 'UNAUTHENTICATED'
                    COMMENT '认证状态: UNAUTHENTICATED(未认证)/PENDING_REVIEW(审核中)/CERTIFIED(已认证)/REJECTED(已驳回)',
    register_source VARCHAR(32)  NOT NULL    DEFAULT 'SELF_REGISTER'
                    COMMENT '租户来源: SELF_REGISTER(自行注册)/PLATFORM_CREATED(后台添加)/IMPORT(批量导入)/PARTNER_INVITE(合作伙伴邀请)',
    tenant_status   VARCHAR(20)  NOT NULL    DEFAULT 'ACTIVE'
                    COMMENT '状态: ACTIVE/BANNED/INACTIVE',
    create_time     DATETIME     NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME     NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by       VARCHAR(64)  NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by       VARCHAR(64)  NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted         TINYINT      NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_tenant_no (tenant_no),
    KEY idx_type (tenant_type),
    KEY idx_country (country_code),
    KEY idx_phone (contact_phone),
    KEY idx_status (tenant_status)
) COMMENT='租户(广播表): tenant_type区分内部/外部;内部租户可多个平级,均对外卖货;currency/locale等偏好移至 t_tenant_config;default_customer_id已删除,占位买家反查t_customer';
```

> **设计要点（t_tenant 重构）**：
> - **tenant_type 区分内外部**：`INTERNAL`(内部运营主体,可多个平级)/`EXTERNAL`(外部业务租户)。原 `tenant_no='PLATFORM'` 约定废弃，改用类型字段判定。
> - **内部租户也对外卖货**：所有租户(含INTERNAL)统一设 default customer 占位买家，原"PLATFORM不设占位"逻辑作废。
> - **超管判定**：`所属租户 tenant_type=INTERNAL` + `RBAC SUPER_ADMIN` 双因子，全局超管跨所有租户。
> - **default_customer_id 已删除**：占位买家反查 `t_customer WHERE register_tenant_id=? AND customer_kind='TENANT_DEFAULT'`（走 idx_tenant_kind 索引），消除原"建tenant→建customer→回填tenant"两段式写。
> - **currency/locale 已移出**：迁至 `t_tenant_config`（1:N KV），加载租户时全量查配置 + 缓存兜底性能。
> - **package_id/package_expire_at 已移出**：查当前套餐走 `t_package_subscription WHERE tenant_id=? AND subscription_status='ACTIVE' AND NOW() BETWEEN start_at AND expire_at`。
> - **国际化行政区划**：`country_code` + `region_id`(末级,关联平台域 t_region) + `region_path`(冗余展示)，不再固化省市区三字段；地区字典在平台运营域 t_country/t_region（自引用树+level，不固化层级）。

> **数据初始化**：
> - 系统启动时由 `pft-identity` 自动种子内部运营租户（幂等 INSERT WHERE NOT EXISTS，`tenant_type='INTERNAL'`，可多个平级）
> - 租户创建时同步生成 1 条 `t_customer(customer_kind=TENANT_DEFAULT)` 占位买家（含内部租户，内部租户也对外卖货）；t_tenant 不再存 default_customer_id，反查 t_customer 获取
> - 租户偏好(currency/locale等)写入 `t_tenant_config`；当前套餐由 `t_package_subscription` 当前生效记录体现

#### t_tenant_config（租户配置，1:N KV，广播表）

```sql
CREATE TABLE t_tenant_config (
    id              BIGINT      NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    tenant_id       BIGINT      NOT NULL    COMMENT '租户ID',
    config_key      VARCHAR(64) NOT NULL    COMMENT '配置键(关联 t_config_meta WHERE config_scope=TENANT,如 currency/locale/timezone/supported_pay_methods)',
    config_value    JSON        NULL        COMMENT '配置值(JSON统一承载,如 "CNY" / ["WECHAT","ALIPAY"] / {"decimal":2});由应用层 ConfigParser 按key注册负责录入校验与解释读取',
    create_time     DATETIME    NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME    NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by       VARCHAR(64) NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by       VARCHAR(64) NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted         TINYINT     NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_tenant_key (tenant_id, config_key),
    KEY idx_tenant (tenant_id)
) COMMENT='租户配置(1:N KV,广播表): 加载租户时全量查+缓存兜底性能;底层只管数据合理/扩展,上层管性能;取值校验依赖平台域 t_config_meta(WHERE config_scope=TENANT) + 应用层ConfigParser';
```

#### t_org（租户内部门架构，自引用树，非分片单表）

```sql
CREATE TABLE t_org (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    org_no              VARCHAR(32)     NOT NULL    COMMENT '部门编号,格式DEP+yyyyMMdd+6位随机',
    org_name            VARCHAR(128)    NOT NULL    COMMENT '部门名称',
    parent_org_id       BIGINT          NOT NULL    DEFAULT 0 COMMENT '上级部门ID(0=顶级部门)',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID',
    org_status          VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_org_no (org_no),
    KEY idx_tenant_parent (tenant_id, parent_org_id),
    KEY idx_parent (parent_org_id)
) COMMENT='租户内部门架构(自引用树,非分片单表): GROUP(集团)→未来外挂t_group+t_group_tenant; MERCHANT(商户)=租户本身; 本表只管租户内部部门/班组等组织层级; 60万租户×2~3部门≈180万,单表+索引足够,无需分片';
```

#### t_tenant_position（租户岗位定义，非分片单表）

```sql
CREATE TABLE t_tenant_position (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    position_no         VARCHAR(32)     NOT NULL    COMMENT '岗位编号,格式POS+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID',
    position_name       VARCHAR(64)     NOT NULL    COMMENT '岗位名称（如"运营主管/安全员/财务审核"等）',
    position_code       VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '岗位编码（租户内唯一，如OPS_MANAGER/SAFETY_INSPECTOR，便于代码引用）',
    position_status     VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_position_no (position_no),
    UNIQUE KEY uk_tenant_code (tenant_id, position_code),
    KEY idx_tenant (tenant_id)
) COMMENT='租户岗位定义(非分片单表): 岗位≠角色,岗位描述"做什么",角色描述"能做什么"; 每个租户自定义岗位名称与编码; 员工1:1岗位(通过t_tenant_staff.position_id关联); 60万租户×5岗位≈300万,单表+索引足够,无需分片';
```

> ⚠️ **以下 t_channel / t_tenant_mp_config / §2.9.1 / t_channel_tenant_binding 已归属平台运营域(pft-platform)，DDL 暂存于此（迁移过渡期），正式归属见 §2.12 表清单。**

#### t_channel（接入端定义，广播表，⚠️已迁至平台运营域）

> Channel-First 统一接入模型 + Partner 模式（详见 §2.9.1）：**一渠道 = 一个外部合作方（Partner）= 一套 partner/app 凭证**。所有外部流量入口（OTA/小程序/H5/PC/API/AI Agent/三方小程序）都是一条 t_channel 记录。渠道下挂载 1 个或 N 个租户由 t_channel_tenant_binding 表达；AppKey 凭证由 t_api_key 承载（一渠道一套）。小程序 appId 在 t_tenant_mp_config 仅为反向映射与小程序特殊密钥。

```sql
CREATE TABLE t_channel (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    channel_code        VARCHAR(64)     NOT NULL    COMMENT '渠道唯一编码：MP_TENANT_HOSTED/MP_PLATFORM/PC_TENANT/PC_PLATFORM/OFFLINE/API_XXX',
    channel_name        VARCHAR(128)    NOT NULL    COMMENT '渠道展示名（"租户托管小程序"/"美团接入"）',
    partner_id          VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '合作方ID（Partner 统一抽象：美团partnerId/微信appId/抖音appId/携程agentId/AI Agent ID等）；每个外部合作方一个唯一partner_id',
    partner_name        VARCHAR(128)    NOT NULL    DEFAULT '' COMMENT '合作方名称（冗余展示用：美团/微信/抖音/携程等）',
    channel_type        VARCHAR(16)     NOT NULL    COMMENT '渠道类型：MP/PC/API/OFFLINE/H5',
    channel_scope       VARCHAR(16)     NOT NULL    COMMENT '渠道作用域：PLATFORM(平台运营方持有，全平台共用)/TENANT(具体租户持有)；详见§2.9.1',
    owner_tenant_id     BIGINT          NOT NULL    DEFAULT 0 COMMENT '渠道所有者租户ID（channel_scope=TENANT时必填=持有该渠道的租户；channel_scope=PLATFORM时=内部租户id,即 tenant_type=INTERNAL 的租户数值 id）。注意：与渠道下挂载的租户(channel_tenant_binding.tenant_id)不同，前者表"持有"，后者表"使用"',
    app_key             VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '接入AppKey（API端必填；一渠道一套；与t_api_key共享app_key全局唯一）；PC/MP端由 t_tenant_mp_config 承载小程序密钥',
    app_secret          VARCHAR(255)    NOT NULL    DEFAULT '' COMMENT '接入密钥（加密存储；API端必填；一渠道一套，与t_api_key.app_secret各自独立但语义一致）',
    default_operator_staff_id BIGINT    NOT NULL    DEFAULT 0 COMMENT '默认操作员ID（channel_type=API必填，请求未带staffCode时兜底）',
    ip_whitelist        VARCHAR(512)    NOT NULL    DEFAULT '' COMMENT 'IP白名单（逗号分隔；API端使用）',
    callback_url        VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '回调地址（API端订单/退款通知）',
    extra_config        JSON            NULL        COMMENT '扩展配置：签名算法/协议版本/子渠道枚举/防重放窗口等（详细设计阶段再细化）',
    channel_status      VARCHAR(16)     NOT NULL    DEFAULT 'ENABLED' COMMENT '状态：ENABLED/DISABLED',
    valid_from          DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '生效开始时间',
    valid_to            DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT '生效结束时间',
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_channel_code (channel_code),
    UNIQUE KEY uk_partner_id (partner_id),
    UNIQUE KEY uk_app_key (app_key),
    KEY idx_type_scope (channel_type, channel_scope),
    KEY idx_owner_tenant (owner_tenant_id)
) COMMENT='渠道（Channel）：服务商级Partner统一抽象表，一渠道=一个外部合作方=一套partner/app凭证；渠道下挂载的租户由t_channel_tenant_binding表达';
```

> **预置端**（系统安装时插入，全平台共用）：
> - `MP_TENANT_HOSTED` (MP/PLATFORM)：租户托管小程序端，承载 N 租户 appId（协议转换见 t_tenant_mp_config）
> - `MP_PLATFORM` (MP/PLATFORM)：平台C端小程序
> - `PC_TENANT` (PC/PLATFORM)：租户B端后台（所有租户共用登录入口，登录时根据员工.tenant_id 确定租户上下文）
> - `PC_PLATFORM` (PC/PLATFORM)：平台超管后台
> - `OFFLINE` (OFFLINE/PLATFORM)：线下窗口
>
> **按需端（API 类）**：每个外部对接方一条 t_channel 记录，如 `API_MEITUAN` / `API_CTRIP` / `API_DOUYIN` / `API_WECHAT_MINI_PFT`（channel_scope=PLATFORM，owner_tenant_id=内部租户 id，即 tenant_type=INTERNAL 的租户数值 id；partner_id=各合作方原生 ID）。渠道下挂载的 N 个租户由 t_channel_tenant_binding 表达（OTA 侧商户 scenicId/merchantId 存于 ota_merchant_id）。

#### t_tenant_mp_config（租户小程序配置，广播表）

```sql
CREATE TABLE t_tenant_mp_config (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    tenant_id           BIGINT          NOT NULL    COMMENT '归属租户ID',
    mp_type             VARCHAR(20)     NOT NULL    COMMENT '小程序类型：WECHAT_MP/WECHAT_MINI/WECHAT_WORK/ALIPAY_MINI/DOUYIN_MINI',
    app_id              VARCHAR(64)     NOT NULL    COMMENT '小程序 appId（微信/支付宝/抖音）',
    app_secret          VARCHAR(255)    NOT NULL    COMMENT '小程序 appSecret（加密存储）',
    mch_id              VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '微信支付商户号（可能共用）',
    remark              VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '备注',
    config_status       VARCHAR(16)     NOT NULL    DEFAULT 'ENABLED' COMMENT '状态：ENABLED/DISABLED',
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_mp_appid (mp_type, app_id),
    KEY idx_tenant_type (tenant_id, mp_type)
) COMMENT='租户小程序配置：一租户可有 N 条（微信MP/支付宝/抖音等）；请求进来时 appId → 找到租户与登录上下文。**注意：appId 概念在 Partner 模式下统一上提到 t_channel.partner_id；本表只承担 (appId, mpType)→tenantId 的反向映射 + 小程序特殊密钥（appSecret/mchId 等）的存储**，与 Channel 是协议转换关系（详见§2.9.1）';
```

#### 2.9.1 渠道对接模式说明（Channel-First + Partner 统一口径）

> **核心原则**：所有外部流量入口（OTA 美团/携程、小程序 微信/支付宝/抖音、H5、PC、API 对接方、AI Agent、第三方自研小程序）都是「渠道（Channel）」概念。**一渠道 = 一个外部合作方（Partner）= 一套 partner/app 凭证**。

**Channel-First 统一接入模型**：

```
PFT 平台
└── 渠道（t_channel）：1 条 = 1 个外部合作方（Partner）
    ├── partner_id：合作方 ID（美团 partnerId / 微信 appId / 抖音 appId / 携程 agentId 等统一抽象）
    ├── 端配置：channel_type（MP/PC/API/OFFLINE/H5）+ channel_scope（PLATFORM/TENANT）+ owner_tenant_id
    ├── partner/app 凭证（t_api_key）：1 渠道 = 1 套 app_key + app_secret
    └── 渠道内租户（t_channel_tenant_binding）：1 或 N 个
        ├── 租户 A（单一商户型：渠道下 1 个租户）
        ├── 租户 B
        └── 租户 N（服务商型：渠道下 N 个租户）
```

**关键设计语义**：

1. **Partner 模式统一口径**：不论是 OTA（美团、携程）、小程序平台（微信、支付宝、抖音）、H5、PC 还是 API 对接方，都视为 Partner；partner_id 字段在 t_channel 上统一抽象，承载各合作方原生的"服务商 ID"概念
2. **AppKey 一渠道一套**：t_api_key 与 t_channel 一对一关联（channel_id 必填），一渠道 = 一套 app_key + app_secret。tenant_id 字段在 t_api_key 上 nullable（仅 owner_tenant_id 语义，标识渠道归属）
3. **渠道内租户的两种形态**：
   - **单一商户型**：第三方只对接一个 PFT 租户 → 渠道下 1 条 t_channel_tenant_binding
   - **服务商型**：第三方对接多个 PFT 租户 → 渠道下 N 条 t_channel_tenant_binding，每条携带 ota_merchant_id（OTA 侧 scenicId/merchantId）
4. **Channel Scope 区分**：
   - `PLATFORM`：渠道配置由平台运营方持有（全平台共用，如 MP_PLATFORM、PC_PLATFORM、API_MEITUAN）
   - `TENANT`：渠道配置由具体租户持有（如某景区自研独立小程序）
5. **Owner Tenant vs 渠道下租户**：
   - `t_channel.owner_tenant_id`：表示"这个渠道归谁持有"（channel_scope=TENANT 时必填）
   - `t_channel_tenant_binding.tenant_id`：表示"这个渠道能给哪些租户用"
   - 二者是不同概念，不要混淆

**典型场景举例**：

| 场景 | 渠道记录 | 渠道-租户绑定 | AppKey |
|---|---|---|---|
| 美团对接 100 个景区 | 1 条 t_channel（API_MEITUAN, scope=PLATFORM, partner_id=美团partnerId）| 100 条 t_channel_tenant_binding，每条 ota_merchant_id 不同（美团 scenicId） | 1 套 t_api_key（app_key=美团appId, app_secret=美团appSecret） |
| PFT 自家微信小程序 | 1 条 t_channel（MP_WECHAT_PFT_SELF, scope=PLATFORM, partner_id=微信appId） | 1 条 t_channel_tenant_binding（PFT 平台租户） | 1 套 t_api_key |
| 某景区自研独立小程序 | 1 条 t_channel（MP_WECHAT_TENANT_XXX, scope=TENANT, owner_tenant_id=该景区租户）| 1 条 t_channel_tenant_binding（该景区自己） | 1 套 t_api_key |
| 携程对接 50 个景区 | 1 条 t_channel（API_CTRIP, scope=PLATFORM, partner_id=携程agentId）| 50 条 t_channel_tenant_binding | 1 套 t_api_key |

**与美团 API 三级嵌套的匹配**：

| 美团 API 要求 | PFT 现状 | 匹配位置 |
|---|---|---|
| partnerId | t_channel.partner_id（统一抽象） | t_channel |
| appId + appSecret | t_api_key.app_key + app_secret（一渠道一套） | t_api_key |
| scenicId / merchantId（每景区）| t_channel_tenant_binding.ota_merchant_id | t_channel_tenant_binding |
| 渠道→多商户（一对多）| 1 个 t_channel + N 条 t_channel_tenant_binding | 三表组合 |

**不在本节范围**（后续系统详细设计再完善）：
- 加密算法选择（HMAC-SHA256 / MD5 / RSA）：用 t_channel.extra_config JSON 兜底
- 签名协议（timestamp / nonce / sign_method）：详细设计阶段
- API 版本号（v1/v2/v3）：用 t_channel.extra_config JSON 兜底
- 防重放机制（timestamp 容忍窗口 / nonce 去重表）：详细设计阶段
- 拉单模式 / 核销模式接口（OP08/OP09/OP10）：详细设计阶段
- t_access_endpoint 表去留：详见 §2.10 平台运营域注释（与 t_channel 合并决策待定）

#### t_channel_tenant_binding（渠道-租户绑定表）

> 表达"一个渠道下挂载哪些租户"的多对多关系；同时承载 OTA 侧商户 ID 映射（详见 §2.9.1）。

```sql
CREATE TABLE t_channel_tenant_binding (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    binding_no          VARCHAR(32)     NOT NULL    COMMENT '绑定编号，格式CHB+yyyyMMdd+6位随机',
    channel_id          BIGINT          NOT NULL    COMMENT '渠道ID（FK→t_channel.id）',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID（FK→t_tenant.id；此租户可通过该渠道下单/被下单）',
    partner_id          VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '合作方ID（冗余便于查询，与t_channel.partner_id同步）',
    ota_merchant_id     VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT 'OTA侧商户ID（美团scenicId/抖音shopId/携程shopId/AI Agent 商户id等）；推单/拉单路由时用于按租户维度识别订单归属',
    ota_sub_channel     VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT 'OTA子渠道枚举（可选；用于同渠道内细分场景，如美团"景点门票"vs"玩乐"）',
    binding_status      VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '绑定状态：ACTIVE/INACTIVE/SUSPENDED',
    extra_config        JSON            NULL        COMMENT '渠道×租户特有配置（如分账比例、特价生效、结算账户等）',
    valid_from          DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '生效开始时间',
    valid_to            DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT '生效结束时间',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_binding_no (binding_no),
    UNIQUE KEY uk_channel_tenant_merchant (channel_id, tenant_id, ota_merchant_id),
    KEY idx_channel (channel_id),
    KEY idx_tenant (tenant_id),
    KEY idx_partner_merchant (partner_id, ota_merchant_id)
) COMMENT='渠道-租户绑定：一个渠道(channel)下挂载1或N个租户(tenant)，承载OTA侧商户ID映射；详见§2.9.1';
```

**典型数据示例**：
- 美团渠道（channel_id=10, partner_id=MEITUAN_PARTNER）下挂 100 个景区 → 100 条 t_channel_tenant_binding，每条 ota_merchant_id=不同 scenicId
- PFT 自家微信小程序（channel_id=20, partner_id=WX_APPID_XXX）下挂 1 个平台租户 → 1 条 t_channel_tenant_binding
- 某景区自研独立小程序（channel_id=30, channel_scope=TENANT, owner_tenant_id=该景区）下挂 1 个租户（自己）→ 1 条 t_channel_tenant_binding

#### RBAC + ABAC 7表（用户→角色→权限→资源，用于B端员工权限）

> **模型**：用户(t_tenant_staff) → 角色(t_sys_role) → 权限(t_sys_permission) → 资源(t_sys_resource)
> - **权限**：对租户可见的功能单元（如"商品管理"、"订单退款"），平台统一维护
> - **资源**：权限下的具体资源，resource_type区分MENU(菜单)/BUTTON(按钮)/API(接口)/PAGE(页面)等
> - 租户只配置"角色拥有哪些权限"，权限背后的资源对租户透明
> - 广播表(3张)：t_sys_permission / t_sys_resource / t_sys_permission_resource（平台级，全库同步）
> - 分片表(4张)：t_sys_role / t_sys_role_permission / t_sys_user_role / t_sys_data_permission（按tenant_id分片）

```sql
CREATE TABLE t_sys_role (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    role_code           VARCHAR(32)     NOT NULL    COMMENT '角色代码',
    role_name           VARCHAR(64)     NOT NULL    COMMENT '角色名称',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID',
    role_status         VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_role_code_tenant (role_code, tenant_id)
) COMMENT='RBAC角色：按tenant_id分片；单套体系，平台员工与租户员工共用';

CREATE TABLE t_sys_permission (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    permission_code     VARCHAR(64)     NOT NULL    COMMENT '权限编码：product:manage / order:refund / finance:report',
    permission_name     VARCHAR(64)     NOT NULL    COMMENT '权限名称（对租户可见）：商品管理/订单退款/财务报表',
    permission_desc     VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '权限描述',
    module              VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '所属模块：product/order/finance/verification等',
    permission_status   VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_permission_code (permission_code),
    KEY idx_module (module)
) COMMENT='权限定义（广播表）：平台统一维护的功能权限项，对租户可见；每个权限关联N个资源(t_sys_permission_resource)';

CREATE TABLE t_sys_resource (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    resource_code       VARCHAR(64)     NOT NULL    COMMENT '资源唯一编码：menu:product:list / button:order:refund / api:POST:/order/refund',
    resource_name       VARCHAR(64)     NOT NULL    COMMENT '资源名称（商品列表菜单/退款按钮/退款接口）',
    resource_type       VARCHAR(16)     NOT NULL    COMMENT '资源类型：MENU(菜单)/BUTTON(按钮)/API(接口)/PAGE(页面)/DATA_EXPORT(数据导出)',
    resource_value      VARCHAR(256)    NOT NULL    COMMENT '资源值：MENU=前端路由路径；BUTTON=按钮标识；API=HTTP方法+路径（如 POST /order/refund）',
    parent_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '父资源ID（菜单树层级；0=顶级）',
    sort_order          INT             NOT NULL    DEFAULT 0 COMMENT '排序权重',
    resource_status     VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_resource_code (resource_code),
    KEY idx_type (resource_type),
    KEY idx_parent (parent_id)
) COMMENT='资源定义（广播表）：平台统一维护，resource_type区分菜单/按钮/API/页面等；权限通过t_sys_permission_resource关联资源';

CREATE TABLE t_sys_role_permission (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    role_id             BIGINT          NOT NULL    COMMENT '角色ID',
    permission_id       BIGINT          NOT NULL    COMMENT '权限ID（FK→t_sys_permission.id）',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_role_permission_tenant (role_id, permission_id, tenant_id),
    KEY idx_tenant (tenant_id)
) COMMENT='角色-权限绑定（按tenant_id分片）：租户配置角色拥有哪些权限；替代原t_sys_role_menu+t_sys_role_api';

CREATE TABLE t_sys_permission_resource (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    permission_id       BIGINT          NOT NULL    COMMENT '权限ID（FK→t_sys_permission.id）',
    resource_id         BIGINT          NOT NULL    COMMENT '资源ID（FK→t_sys_resource.id）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_permission_resource (permission_id, resource_id)
) COMMENT='权限-资源映射（广播表）：平台维护每个权限包含哪些资源（菜单/按钮/API等）；一个权限可关联N个资源';

CREATE TABLE t_sys_user_role (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    user_id             BIGINT          NOT NULL    COMMENT '员工ID（语义=t_tenant_staff.id；字段名保留 user_id 避免大范围联动）',
    role_id             BIGINT          NOT NULL    COMMENT '角色ID',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_user_role_tenant (user_id, role_id, tenant_id)
) COMMENT='员工角色绑定（user_id 语义=tenant_staff_id；按tenant_id分片；单套RBAC体系，平台员工 = tenant_no=\'PLATFORM\' 租户下员工 + SUPER_ADMIN 角色判定超管）';

CREATE TABLE t_sys_data_permission (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    role_id             BIGINT          NOT NULL    COMMENT '角色ID',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID',
    resource_type       VARCHAR(16)     NOT NULL    COMMENT '资源类型：ORDER/PRODUCT/TICKET',
    attr_field          VARCHAR(32)     NOT NULL    COMMENT '属性字段：creator_id/org_id/distributor_id',
    attr_value_source   VARCHAR(16)     NOT NULL    COMMENT '值来源：SELF/DEPT/CUSTOM',
    custom_values       JSON            NULL        COMMENT '自定义值列表（attr_value_source=CUSTOM时）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    KEY idx_role_tenant (role_id, tenant_id)
) COMMENT='ABAC数据权限规则（按tenant_id分片）：MyBatis拦截器自动注入WHERE条件';
```

---

### 2.10 设备域

#### t_device（设备）

```sql
CREATE TABLE t_device (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    device_no           VARCHAR(32)     NOT NULL    COMMENT '设备编号，格式DEV+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '归属商户ID',
    device_type         VARCHAR(16)     NOT NULL    COMMENT '设备类型：GATE/POS/HANDHELD/SELF_SERVICE/KIOSK/FACE_RECOGNITION',
    device_name         VARCHAR(128)    NOT NULL    COMMENT '设备名称（如"东门闸机#3"）',
    poi_id              BIGINT          NOT NULL    DEFAULT 0 COMMENT '绑定POI ID',
    device_group_id     BIGINT          NOT NULL    DEFAULT 0 COMMENT '设备分组ID',
    capabilities        JSON            NOT NULL    COMMENT '设备能力：[SELL/PICKUP/Verify/IDENTIFY]',
    device_status       VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/OFFLINE/MAINTENANCE/INACTIVE',
    last_heartbeat      DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '最后心跳时间',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_device_no (device_no),
    KEY idx_tenant_type (tenant_id, device_type),
    KEY idx_group (device_group_id)
) COMMENT='设备：闸机/POS/手持机/自助机/刷脸机';
```

#### t_device_group（设备分组）

```sql
CREATE TABLE t_device_group (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    group_no            VARCHAR(32)     NOT NULL    COMMENT '分组编号，格式DG+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '归属商户ID',
    group_name          VARCHAR(128)    NOT NULL    COMMENT '分组名称（如"东门闸机组"）',
    poi_id              BIGINT          NOT NULL    DEFAULT 0 COMMENT '绑定POI ID',
    verify_point_id     BIGINT          NOT NULL    DEFAULT 0 COMMENT '绑定核销点ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_group_no (group_no),
    KEY idx_tenant_poi (tenant_id, poi_id)
) COMMENT='设备分组：跨设备类型分组，绑定核销点';
```

---

### 2.11 分销域

#### t_distribution_relation（分销关系）

```sql
CREATE TABLE t_distribution_relation (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    relation_no         VARCHAR(32)     NOT NULL    COMMENT '分销关系编号，格式DR+yyyyMMdd+6位随机',
    supplier_tenant_id  BIGINT          NOT NULL    COMMENT '供应商租户ID',
    distributor_tenant_id BIGINT        NOT NULL    COMMENT '分销商租户ID',
    parent_relation_id  BIGINT          NOT NULL    DEFAULT 0 COMMENT '上级分销关系ID（4级采购链）',
    distribution_mode   VARCHAR(16)     NOT NULL    COMMENT '分销模式：PROFIT_SHARE/PURCHASE',
    payment_mode        VARCHAR(16)     NOT NULL    DEFAULT 'CREDIT' COMMENT '支付模式：CREDIT/BALANCE',
    credit_limit        BIGINT          NOT NULL    DEFAULT 0 COMMENT '授信额度（分，payment_mode=CREDIT时）',
    credit_used         BIGINT          NOT NULL    DEFAULT 0 COMMENT '已用授信（分）',
    relation_status     VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/SUSPENDED/TERMINATED',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_relation_no (relation_no),
    KEY idx_supplier (supplier_tenant_id),
    KEY idx_distributor (distributor_tenant_id),
    KEY idx_parent (parent_relation_id)
) COMMENT='分销关系：4级采购链，分润/逐级采购双模式';
```

---

### 2.12 平台运营域

#### t_sys_dict（平台字典）

```sql
CREATE TABLE t_sys_dict (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    dict_type           VARCHAR(32)     NOT NULL    COMMENT '字典类型（如product_type/verify_type/id_type）',
    dict_code           VARCHAR(32)     NOT NULL    COMMENT '字典代码',
    dict_name           VARCHAR(64)     NOT NULL    COMMENT '字典名称',
    dict_name_en        VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '英文名称（i18n）',
    dict_order          INT             NOT NULL    DEFAULT 0 COMMENT '排序',
    dict_status         VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    scope               VARCHAR(16)     NOT NULL    DEFAULT 'PLATFORM' COMMENT '范围：PLATFORM/TENANT',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID（scope=TENANT时）',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_dict_type_code (dict_type, dict_code, scope, tenant_id)
) COMMENT='平台字典：业态/票种/证件类型等全局枚举';
```

#### t_package（套餐包）

```sql
CREATE TABLE t_package (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    package_no          VARCHAR(32)     NOT NULL    COMMENT '套餐编号，格式PKG+yyyyMMdd+6位随机',
    package_name        VARCHAR(128)    NOT NULL    COMMENT '套餐名称（如"基础版""专业版"）',
    package_price       BIGINT          NOT NULL    COMMENT '套餐价格（分/年）',
    duration_days       INT             NOT NULL    DEFAULT 365 COMMENT '有效期（天）',
    feature_permissions JSON            NOT NULL    COMMENT '功能权限项列表：[{featureCode, enabled}]',
    resource_limits     JSON            NOT NULL    COMMENT '资源额度：{smsCount, maxUsers, maxProducts, alarmQuota}',
    package_status      VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_package_no (package_no)
) COMMENT='套餐包：功能权限+资源额度+价格';
```

#### t_package_subscription（套餐订购记录）

```sql
CREATE TABLE t_package_subscription (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    subscription_no     VARCHAR(32)     NOT NULL    COMMENT '订购编号，格式SUB+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '租户ID',
    package_id          BIGINT          NOT NULL    COMMENT '套餐ID',
    subscription_type   VARCHAR(16)     NOT NULL    COMMENT '类型：NEW/RENEW/UPGRADE',
    start_at            DATETIME        NOT NULL    COMMENT '生效时间',
    expire_at           DATETIME        NOT NULL    COMMENT '到期时间',
    subscription_status VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/EXPIRED/CANCELLED',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_subscription_no (subscription_no),
    KEY idx_tenant (tenant_id),
    KEY idx_tenant_active (tenant_id, subscription_status, start_at),
    KEY idx_package (package_id)
) COMMENT='套餐订购记录：新购/续费/升级';
```

#### t_approval_flow（审批流定义）

```sql
CREATE TABLE t_approval_flow (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    flow_no             VARCHAR(32)     NOT NULL    COMMENT '审批流编号，格式AF+yyyyMMdd+8位UUID（自动生成）',
    flow_code           VARCHAR(64)     NOT NULL    COMMENT '审批流唯一标识码（手动输入，如MERCHANT_ONBOARDING），业务方按此启动审批流',
    flow_name           VARCHAR(128)    NOT NULL    COMMENT '审批流名称',
    flow_definition     JSON            NOT NULL    COMMENT '审批节点定义JSON：{"steps":[{stepOrder,stepName,approverType(ROLE/USER/DEPT_LEADER),approverValue,condition(SpEL),timeoutHours,timeoutAction(AUTO_APPROVE/AUTO_REJECT/ESCALATE)}]}',
    scope               VARCHAR(16)     NOT NULL    DEFAULT 'PLATFORM' COMMENT '范围：PLATFORM/TENANT',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID（scope=TENANT时有效）',
    flow_status         VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    version             INT             NOT NULL    DEFAULT 1 COMMENT '版本号，同flowCode+scope+tenantId从1递增',
    version_status      VARCHAR(20)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '版本状态：DRAFT/ACTIVE/HISTORICAL',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_flow_no (flow_no),
    UNIQUE KEY uk_flow_code_scope_version (flow_code, scope, tenant_id, version),
    KEY idx_flow_code_version (flow_code, version_status)
) COMMENT='审批流定义：轻量状态机引擎驱动，不使用Flowable/BPMN';
```

#### t_approval_instance（审批实例）

```sql
CREATE TABLE t_approval_instance (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    instance_no         VARCHAR(32)     NOT NULL    COMMENT '审批实例号，格式AI+yyyyMMdd+6位随机',
    flow_id             BIGINT          NOT NULL    COMMENT '审批流ID（启动时绑定的具体审批流模板ID）',
    flow_code           VARCHAR(64)     NULL        COMMENT '审批流标识码（冗余，便于按code查询）',
    business_no         VARCHAR(32)     NOT NULL    COMMENT '关联业务号（退款单号/提现单号等）',
    applicant_id        BIGINT          NOT NULL    COMMENT '申请人ID',
    applicant_name      VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '申请人姓名（快照，避免跨库查identity）',
    current_node        VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '当前审批节点名称',
    business_context    JSON            NULL        COMMENT '审批内容快照JSON（业务方提供，前端审批工作台据此渲染审批详情：退什么/退多少/谁发起等）',
    timeout_at          DATETIME(3)     NULL        COMMENT '当前节点审批截止时间（XXL-JOB扫描超时处理）',
    instance_status     VARCHAR(16)     NOT NULL    DEFAULT 'PENDING' COMMENT '状态：PENDING/APPROVED/REJECTED/CANCELLED',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_instance_no (instance_no),
    KEY idx_business (business_no),
    KEY idx_tenant_status (tenant_id, instance_status),
    KEY idx_status_timeout (instance_status, timeout_at)
) COMMENT='审批实例：轻量状态机引擎驱动流转';
```

#### t_complaint（投诉工单）

```sql
CREATE TABLE t_complaint (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    complaint_no        VARCHAR(32)     NOT NULL    COMMENT '工单编号，格式CMP+yyyyMMdd+6位随机',
    complainant_type    VARCHAR(16)     NOT NULL    COMMENT '投诉方：VISITOR/MERCHANT',
    complainant_id      BIGINT          NOT NULL    COMMENT '投诉方ID',
    order_group_no      VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '关联订单号（游客投诉时）',
    complaint_type      VARCHAR(16)     NOT NULL    COMMENT '类型：ORDER_ISSUE/SERVICE_ISSUE/BUG/OTHER',
    complaint_content   TEXT            NOT NULL    COMMENT '投诉内容',
    handler_id          BIGINT          NOT NULL    DEFAULT 0 COMMENT '处理人ID',
    sla_deadline        DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT 'SLA截止时间',
    complaint_status    VARCHAR(16)     NOT NULL    DEFAULT 'PENDING' COMMENT '状态：PENDING/ASSIGNED/PROCESSING/RESOLVED/CLOSED',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_complaint_no (complaint_no),
    KEY idx_tenant_status (tenant_id, complaint_status),
    KEY idx_handler (handler_id)
) COMMENT='投诉工单：游客投诉/商户投诉，SLA超时升级';
```

#### t_third_party_channel（已废弃）

> ⚠️ 本表已与 `t_channel` 合并，Channel-First 统一接入模型下不再单独存在。原先的第三方支付/OTA 等接入配置迁移至 `t_channel`（DDL 见 §2.9，归属平台运营域）。此处保留占位以便迁移期检索定位。

> **渠道接入相关表（t_channel / t_channel_tenant_binding / t_tenant_mp_config）已从用户域(pft-identity)迁入本域，DDL 详见 §2.9 用户域（迁移过渡期暂存）。**

#### t_access_endpoint（接入端配置，⚠️已废弃，功能并入 t_channel）

```sql
CREATE TABLE t_access_endpoint (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    endpoint_no         VARCHAR(32)     NOT NULL    COMMENT '接入端编号，格式EP+yyyyMMdd+6位随机',
    endpoint_type       VARCHAR(16)     NOT NULL    COMMENT '端类型：MINI_PROGRAM/WECHAT_SHOP/PC/COUNTER/AI/OTA',
    endpoint_name       VARCHAR(64)     NOT NULL    COMMENT '端名称',
    ota_channel         VARCHAR(16)     NOT NULL    DEFAULT '' COMMENT 'OTA渠道细分（端类型=OTA时）',
    allowed_api_paths   JSON            NOT NULL    COMMENT 'API白名单路径列表',
    blocked_api_paths   JSON            NULL        COMMENT 'API黑名单路径列表',
    rate_limit_config   JSON            NULL        COMMENT '限流配置：{qps, concurrent, circuitBreaker}',
    endpoint_status     VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_endpoint_type_channel (endpoint_type, ota_channel)
) COMMENT='接入端配置：端类型+OTA细分+API权限+限流';
```

#### t_i18n_language（支持语言列表）

```sql
CREATE TABLE t_i18n_language (
    id              BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    locale_code     VARCHAR(8)  NOT NULL COMMENT '语言代码（zh-CN/en-US/ja-JP/ko-KR等）',
    language_name   VARCHAR(64) NOT NULL COMMENT '语言名称（中文）',
    language_name_en VARCHAR(64) NOT NULL COMMENT '语言名称（英文）',
    language_status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    sort_order      INT         NOT NULL DEFAULT 0 COMMENT '排序权重',
    create_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '创建人',
    update_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '更新人',
    deleted         TINYINT     NOT NULL DEFAULT 0 COMMENT '删除标记',
    PRIMARY KEY (id),
    UNIQUE KEY uk_locale_code (locale_code)
) COMMENT='支持语言列表：系统国际化语言定义';
```

#### t_i18n_currency（支持币种列表）

```sql
CREATE TABLE t_i18n_currency (
    id              BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    currency_code   VARCHAR(8)  NOT NULL COMMENT '币种代码（CNY/USD/JPY/KRW等）',
    currency_name   VARCHAR(64) NOT NULL COMMENT '币种名称（中文）',
    currency_name_en VARCHAR(64) NOT NULL COMMENT '币种名称（英文）',
    currency_symbol VARCHAR(8)  NOT NULL COMMENT '币种符号（¥/$/¥/₩等）',
    exchange_rate_to_cny DECIMAL(12,6) NOT NULL DEFAULT 1.000000 COMMENT '对CNY汇率',
    currency_status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    create_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '创建人',
    update_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '更新人',
    deleted         TINYINT     NOT NULL DEFAULT 0 COMMENT '删除标记',
    PRIMARY KEY (id),
    UNIQUE KEY uk_currency_code (currency_code)
) COMMENT='支持币种列表：系统国际化币种定义';
```

#### t_i18n_translation（通用翻译表）

```sql
CREATE TABLE t_i18n_translation (
    id              BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    table_name      VARCHAR(32) NOT NULL COMMENT '源表名（如t_spu/t_sku/t_sys_dict）',
    entity_id       BIGINT      NOT NULL COMMENT '源表实体ID',
    field_name      VARCHAR(32) NOT NULL COMMENT '源表字段名（如spu_name/description）',
    locale          VARCHAR(8)  NOT NULL COMMENT '语言代码（zh-CN/en-US/ja-JP等）',
    field_value     TEXT        NOT NULL COMMENT '翻译值',
    create_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '创建人',
    update_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '更新人',
    deleted         TINYINT     NOT NULL DEFAULT 0 COMMENT '删除标记',
    PRIMARY KEY (id),
    UNIQUE KEY uk_translation (table_name, entity_id, field_name, locale),
    KEY idx_entity (table_name, entity_id),
    KEY idx_locale (locale)
) COMMENT='国际化翻译表：通用多语言字段存储';
```

#### t_country（国家字典，广播表）

```sql
CREATE TABLE t_country (
    id              BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    country_code    VARCHAR(2)  NOT NULL COMMENT '国家码 ISO 3166-1(如 CN/US/JP)',
    iso3_code       VARCHAR(3)  NOT NULL DEFAULT '' COMMENT '国家三字母码 ISO 3166-1(如 CHN/USA)',
    country_status  VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态: ACTIVE/INACTIVE',
    sort_order      INT         NOT NULL DEFAULT 0 COMMENT '排序权重',
    create_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '创建人',
    update_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '更新人',
    deleted         TINYINT     NOT NULL DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_country_code (country_code)
) COMMENT='国家字典(广播表): 名称走 t_i18n_translation(table_name=t_country, field_name=name)';
```

#### t_region（地区字典，自引用树，广播表）

```sql
CREATE TABLE t_region (
    id              BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    region_code     VARCHAR(12) NOT NULL COMMENT '行政区划码(国标,如 350203=思明区)',
    parent_id       BIGINT      NOT NULL DEFAULT 0 COMMENT '上级地区ID,0=顶级',
    country_code    VARCHAR(2)  NOT NULL COMMENT '所属国家码(冗余,便于按国过滤)',
    region_level    INT         NOT NULL DEFAULT 1 COMMENT '层级: 1=一级行政区(省/州/都道府县),2=市/郡,3=区县,4=乡镇,5=街道;不固化层级',
    region_path     VARCHAR(256) NOT NULL DEFAULT '' COMMENT '完整路径含自身,如"中国/福建省/厦门市/思明区"',
    region_status   VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态: ACTIVE/INACTIVE',
    sort_order      INT         NOT NULL DEFAULT 0 COMMENT '排序权重',
    create_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '创建人',
    update_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '更新人',
    deleted         TINYINT     NOT NULL DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_region_code (region_code),
    KEY idx_parent (parent_id),
    KEY idx_country_level (country_code, region_level)
) COMMENT='地区字典(广播表,自引用树): 不固化省市区三级,level标识层级;名称走 t_i18n_translation(table_name=t_region, field_name=name)';
```

#### t_config_meta（平台配置元数据）

```sql
CREATE TABLE t_config_meta (
    id              BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    config_scope    VARCHAR(32) NOT NULL DEFAULT 'TENANT' COMMENT '配置作用域: TENANT(租户配置,t_tenant_config)/STAFF(员工配置,t_staff_config)/...(未来扩展其他配置表时加枚举值)',
    config_key      VARCHAR(64) NOT NULL COMMENT '配置键(TENANT: currency/locale/timezone/supported_pay_methods; STAFF: mfa_enabled/login_2fa_confirm/session_timeout/ip_whitelist)',
    config_group    VARCHAR(32) NOT NULL DEFAULT 'general'
                    COMMENT '配置分组(不同scope下有不同分组): TENANT→general/i18n/payment/notification/business; STAFF→security/session',
    value_type      VARCHAR(16) NOT NULL DEFAULT 'STRING'
                    COMMENT '值类型: STRING/BOOL/INT/DECIMAL/JSON(复杂结构或列表)',
    validation_rule VARCHAR(256) NOT NULL DEFAULT ''
                    COMMENT '校验规则(正则或枚举,如 "^(CNY|USD|JPY)$" 或 json schema 简述);由应用层 ConfigParser 执行',
    default_value   VARCHAR(512) NOT NULL DEFAULT '' COMMENT '默认值(JSON编码)',
    description     VARCHAR(128) NOT NULL DEFAULT '' COMMENT '配置说明',
    meta_status     VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态: ACTIVE/INACTIVE',
    create_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '创建人',
    update_by       VARCHAR(64) NOT NULL DEFAULT 'system' COMMENT '更新人',
    deleted         TINYINT     NOT NULL DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_scope_key (config_scope, config_key)
) COMMENT='平台配置元数据(统一管理各KV配置表合法key): config_scope区分TENANT/STAFF等;一个scope+key一行,定义合法key/类型/校验规则/默认值;应用层按(scope,key)注册ConfigParser负责录入校验与解释读取;避免每种配置表各建一个meta表';
```

> **翻译表使用方式**：
> - 默认语言（zh-CN）：直接查源表字段（如 `t_spu.spu_name`），无需查翻译表
> - 其他语言：查翻译表 `WHERE table_name='t_spu' AND entity_id=? AND field_name='spu_name' AND locale='en-US'`
> - 翻译表不存在对应locale记录时，回退到源表默认字段值
> - t_sys_dict的 `dict_name_en` 字段和 t_notify_template的 `template_content_en` 字段后续迁移到翻译表，当前版本保留原字段

---

### 2.13 通知域

#### t_notify_template（通知模板）

```sql
CREATE TABLE t_notify_template (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    template_no         VARCHAR(32)     NOT NULL    COMMENT '模板编号，格式NT+yyyyMMdd+6位随机',
    template_code       VARCHAR(32)     NOT NULL    COMMENT '模板代码（如ORDER_PAID_SMS/VERIFY_NOTICE_MINI）',
    template_name       VARCHAR(128)    NOT NULL    COMMENT '模板名称',
    notify_channel      VARCHAR(16)     NOT NULL    COMMENT '通知渠道：SMS/MINI_PROGRAM_MSG/EMAIL/WEBHOOK/IN_APP',
    template_content    TEXT            NOT NULL    COMMENT '模板内容（含变量占位符${xxx}）',
    template_content_en TEXT            NOT NULL    DEFAULT '' COMMENT '英文模板内容（i18n）',
    scope               VARCHAR(16)     NOT NULL    DEFAULT 'PLATFORM' COMMENT '范围：PLATFORM/TENANT',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID',
    template_status     VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_template_code_scope (template_code, scope, tenant_id)
) COMMENT='通知模板：短信/模板消息/邮件/Webhook/站内信';
```

#### t_notify_record（通知记录）

```sql
CREATE TABLE t_notify_record (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    notify_no           VARCHAR(32)     NOT NULL    COMMENT '通知记录号，格式NR+yyyyMMdd+6位随机',
    template_id         BIGINT          NOT NULL    COMMENT '模板ID',
    recipient_id        BIGINT          NOT NULL    COMMENT '接收人ID',
    recipient_type      VARCHAR(16)     NOT NULL    COMMENT '接收人类型：CUSTOMER/TENANT_STAFF/SYSTEM',
    notify_channel      VARCHAR(16)     NOT NULL    COMMENT '实际发送渠道',
    notify_content      TEXT            NOT NULL    COMMENT '实际发送内容（变量已替换）',
    related_business_no VARCHAR(32)     NOT NULL    DEFAULT '' COMMENT '关联业务号',
    send_status         VARCHAR(16)     NOT NULL    DEFAULT 'PENDING' COMMENT '状态：PENDING/SUCCESS/FAILED',
    send_time           DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '发送时间',
    fail_reason         VARCHAR(256)    NOT NULL    DEFAULT '' COMMENT '失败原因',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_notify_no (notify_no),
    KEY idx_recipient (recipient_id, create_time),
    KEY idx_tenant_status (tenant_id, send_status, create_time)
) COMMENT='通知记录：每次发送事实';
```

---

### 2.14 审计域

#### t_audit_log（审计日志）

```sql
CREATE TABLE t_audit_log (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    log_no              VARCHAR(32)     NOT NULL    COMMENT '日志编号，格式AL+yyyyMMdd+6位随机',
    operator_id         BIGINT          NOT NULL    COMMENT '操作人ID',
    operator_type       VARCHAR(16)     NOT NULL    COMMENT '操作人类型：CUSTOMER/TENANT_STAFF/SYSTEM/ANONYMOUS',
    action              VARCHAR(32)     NOT NULL    COMMENT '操作动作（如PLACE_ORDER/REFUND/WITHDRAW/MODIFY_BANK_CARD）',
    resource_type       VARCHAR(16)     NOT NULL    COMMENT '资源类型：ORDER/PRODUCT/ACCOUNT/DEVICE',
    resource_id         BIGINT          NOT NULL    DEFAULT 0 COMMENT '资源ID',
    detail              JSON            NOT NULL    COMMENT '操作详情（变更前后对比等）',
    ip_address          VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT 'IP地址',
    tenant_id           BIGINT          NOT NULL    DEFAULT 0 COMMENT '租户ID',
    log_scope           VARCHAR(16)     NOT NULL    DEFAULT 'MERCHANT' COMMENT '日志范围：PLATFORM/MERCHANT',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_log_no (log_no),
    KEY idx_operator (operator_id, create_time),
    KEY idx_action_time (action, create_time),
    KEY idx_tenant_scope (tenant_id, log_scope, create_time),
    KEY idx_resource (resource_type, resource_id)
) COMMENT='审计日志：所有写操作记录，pft-risk通过CDC消费';
```

---

### 2.15 应用域

#### t_app_definition（应用定义）

```sql
CREATE TABLE t_app_definition (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    app_no              VARCHAR(32)     NOT NULL    COMMENT '应用编号，格式APP+yyyyMMdd+6位随机',
    app_name            VARCHAR(128)    NOT NULL    COMMENT '应用名称',
    app_code            VARCHAR(32)     NOT NULL    COMMENT '应用代码（唯一标识）',
    app_type            VARCHAR(16)     NOT NULL    COMMENT '类型：BUILTIN/THIRD_PARTY',
    description         TEXT            NOT NULL    COMMENT '应用描述',
    app_status          VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_app_code (app_code)
) COMMENT='应用定义：应用市场中的应用';
```

#### t_app_binding（套餐-应用绑定）

```sql
CREATE TABLE t_app_binding (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    package_id          BIGINT          NOT NULL    COMMENT '套餐ID',
    app_id              BIGINT          NOT NULL    COMMENT '应用ID',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_package_app (package_id, app_id)
) COMMENT='套餐-应用绑定：哪些应用包含在套餐中';
```

---

### 2.16 营销域（P3）

#### t_coupon（优惠券）

```sql
CREATE TABLE t_coupon (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    coupon_no           VARCHAR(32)     NOT NULL    COMMENT '优惠券编号，格式CPN+yyyyMMdd+6位随机',
    tenant_id           BIGINT          NOT NULL    COMMENT '归属商户ID',
    coupon_name         VARCHAR(128)    NOT NULL    COMMENT '优惠券名称',
    coupon_type         VARCHAR(16)     NOT NULL    COMMENT '类型：FIXED_AMOUNT/PERCENT_DISCOUNT/FREE_VERIFY',
    coupon_value        BIGINT          NOT NULL    DEFAULT 0 COMMENT '优惠值（分或百分比）',
    applicable_sku_ids  JSON            NULL        COMMENT '适用SKU列表（null=全部）',
    total_count         INT             NOT NULL    COMMENT '发行总量',
    used_count          INT             NOT NULL    DEFAULT 0 COMMENT '已使用数量',
    effective_from      DATETIME        NOT NULL    COMMENT '生效起始',
    effective_to        DATETIME        NOT NULL    COMMENT '生效终止',
    coupon_status       VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/INACTIVE/EXPIRED',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_coupon_no (coupon_no),
    KEY idx_tenant_status (tenant_id, coupon_status)
) COMMENT='优惠券：固定金额/百分比折扣/免费核销（P3）';
```

---

### 2.17 数据域

#### t_cdc_sync_task（CDC同步任务）

```sql
CREATE TABLE t_cdc_sync_task (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    task_no             VARCHAR(32)     NOT NULL    COMMENT '任务编号，格式CDC+yyyyMMdd+6位随机',
    source_table        VARCHAR(64)     NOT NULL    COMMENT '源表名（如t_order/t_sku）',
    target_type         VARCHAR(16)     NOT NULL    COMMENT '目标类型：ES/STARROCKS/KAFKA',
    target_name         VARCHAR(64)     NOT NULL    COMMENT '目标名称（ES索引/StarRocks表/Kafka Topic）',
    sync_mode           VARCHAR(16)     NOT NULL    DEFAULT 'REALTIME' COMMENT '模式：REALTIME/BATCH',
    field_mapping       JSON            NOT NULL    COMMENT '字段映射规则',
    task_status         VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/PAUSED/ERROR',
    last_sync_at        DATETIME        NOT NULL    DEFAULT '1970-01-01 00:00:00' COMMENT '最后同步时间',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_task_no (task_no),
    KEY idx_source (source_table),
    KEY idx_target (target_type, target_name)
) COMMENT='CDC同步任务：binlog→ES/StarRocks/Kafka';
```

---

### 2.18 开放平台域（P3）

#### t_api_key（API密钥）

```sql
CREATE TABLE t_api_key (
    id                  BIGINT          NOT NULL    AUTO_INCREMENT COMMENT '主键ID',
    key_no              VARCHAR(32)     NOT NULL    COMMENT '密钥编号，格式AK+yyyyMMdd+6位随机',
    channel_id          BIGINT          NOT NULL    COMMENT '渠道ID（FK→t_channel.id；一渠道=一套AppKey；详见§2.9.1）',
    partner_id          VARCHAR(64)     NOT NULL    DEFAULT '' COMMENT '合作方ID（冗余便于查询，与t_channel.partner_id同步；美团partnerId/微信appId等）',
    tenant_id           BIGINT          NULL        DEFAULT NULL COMMENT '渠道所有者租户ID（nullable；PLATFORM渠道此字段为NULL；TENANT渠道=owner_tenant_id）。注意：与"渠道下挂载的租户"（t_channel_tenant_binding.tenant_id）不同',
    app_key             VARCHAR(64)     NOT NULL    COMMENT 'AppKey（一渠道一套；与t_channel.app_key共享全局唯一索引）',
    app_secret          VARCHAR(128)    NOT NULL    COMMENT 'AppSecret（加密存储；一渠道一套）',
    allowed_interfaces  JSON            NOT NULL    COMMENT '允许调用的接口列表',
    rate_limit_qps      INT             NOT NULL    DEFAULT 100 COMMENT 'QPS限制',
    key_status          VARCHAR(16)     NOT NULL    DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/REVOKED',
    expires_at          DATETIME        NOT NULL    DEFAULT '9999-12-31 23:59:59' COMMENT '过期时间',
    -- 审计字段
    create_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time         DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    create_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '创建人',
    update_by           VARCHAR(64)     NOT NULL    DEFAULT 'system' COMMENT '更新人',
    deleted             TINYINT         NOT NULL    DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    PRIMARY KEY (id),
    UNIQUE KEY uk_key_no (key_no),
    KEY idx_channel (channel_id),
    KEY idx_partner (partner_id),
    KEY idx_tenant (tenant_id)
) COMMENT='API密钥：按渠道签发（一渠道一套 app_key/app_secret），通过 channel_id 关联 t_channel；用于开放平台签名鉴权+流控（P3）；详见§2.9.1';
```

---

## 三、表汇总统计

| 领域 | 表数 |
|------|------|
| 订单域 | 9 |
| 支付域 | 3 |
| 核销域 | 4 |
| 财务域 | 9 |
| 商品域 | 7 |
| 价格域 | 2 |
| 库存域 | 3 |
| 风控域 | 4 |
| 用户域 | 17 |
| 设备域 | 2 |
| 分销域 | 1 |
| 平台运营域 | 15 |
| 通知域 | 2 |
| 审计域 | 1 |
| 应用域 | 2 |
| 营销域 | 1 |
| 数据域 | 1 |
| 开放平台域 | 1 |
| **合计** | **75** |

> 注：
> - 用户域 17 张 = t_customer / t_customer_identity / t_customer_credential(原 t_person_credential 改名, id_number从customer移出至此) / t_tenant_staff / t_staff_credential(登录凭证) / t_staff_config(员工配置KV) / t_tenant / t_tenant_config(租户配置1:N KV) / t_org(部门架构) / t_tenant_position(岗位定义) + RBAC+ABAC 7 张（t_sys_role / t_sys_permission(广播) / t_sys_resource(广播) / t_sys_role_permission / t_sys_permission_resource(广播) / t_sys_user_role / t_sys_data_permission）
> - 平台运营域 15 张：t_channel / t_channel_tenant_binding / t_tenant_mp_config（从用户域迁入，Channel-First 接入端统一管理）/ t_sys_dict / t_package / t_package_subscription / t_approval_flow / t_approval_instance / t_complaint / t_i18n_language / t_i18n_currency / t_i18n_translation / t_country / t_region / t_config_meta（t_access_endpoint 已废弃并入 t_channel，t_third_party_channel 已废弃并入 t_channel）
> - t_payment_record 在订单域和支付域各一份（结构相同），t_shared_inventory_pool 在库存域和分销域各一份（同一张表）
> - 共 75 张独立表，覆盖 18 个一级领域

---

## 四、分库策略

> 按04技术架构文档分库策略，以tenant_id（BIGINT）为分库维度。

| 库名 | 包含表 | 说明 |
|------|--------|------|
| pft-order | t_order_group, t_order, t_ticket, t_ticket_person, t_entitlement, t_person_entitlement_binding, t_payment_record, t_refund_order, t_refund_detail | 交易核心 |
| pft-payment | t_payment_record, t_payment_channel_config, t_merchant_payment_config | 支付域独立 |
| pft-verification | t_ticket_credential, t_code_pool, t_verify_point, t_verify_record | 核销域独立 |
| pft-finance | t_account, t_frozen_record, t_fund_flow, t_withdraw_order, t_bank_card, t_invoice_config, t_invoice_order, t_resource_batch | 财务域独立 |
| pft-product | t_spu, t_sku, t_sku_version_snapshot, t_ticket_meta, t_sku_meta_value, t_sale_rule, t_sale_rule_item | 商品域独立 |
| pft-pricing | t_price_point, t_pricing_rule | 价格域独立 |
| pft-inventory | t_inventory_pool, t_inventory_unit, t_shared_inventory_pool | 库存域独立 |
| pft-risk | t_risk_rule, t_blacklist, t_risk_event, t_account_ban | 风控域独立 |
| pft-identity | **广播**：t_customer, t_customer_identity, t_customer_credential, t_tenant, t_tenant_config, t_sys_permission, t_sys_resource, t_sys_permission_resource；**非分片单表**：t_tenant_staff, t_staff_credential, t_staff_config, t_org, t_tenant_position（60万租户×2~3员工/组织≈180万,单表+索引足够）；**分片**：t_sys_role, t_sys_role_permission, t_sys_user_role, t_sys_data_permission | 用户域（C端广播+B端非分片+RBAC按tenant_id分片+权限资源广播） |
| pft-device | t_device, t_device_group | 设备域独立 |
| pft-distribution | t_distribution_relation, t_shared_inventory_pool | 分销域独立 |
| pft-platform | t_channel(广播), t_channel_tenant_binding, t_tenant_mp_config(广播), t_sys_dict, t_package, t_package_subscription, t_approval_flow, t_approval_instance, t_complaint, t_i18n_language, t_i18n_currency, t_i18n_translation, t_country, t_region, t_config_meta | 平台运营域独立（含Channel-First接入端） |
| pft-application | t_app_definition, t_app_binding | 应用域独立 |
| pft-notification | t_notify_template, t_notify_record | 通知域独立 |
| pft-audit | t_audit_log | 审计域独立 |
| pft-marketing | t_coupon | 营销域独立（P3） |
| pft-data-pipeline | t_cdc_sync_task | 数据域独立 |
| pft-open-platform | t_api_key | 开放平台域独立（P3） |

> **ShardingSphere 规则**：按 tenant_id 分库，每个库独立物理实例。初期可合库（单实例多schema），按租户量增长逐步拆分物理实例。
>
> **全局广播表**（不分库，各库同步一份）：
> - 用户域：t_customer / t_customer_identity / t_customer_credential / t_tenant / t_tenant_config / t_sys_permission / t_sys_resource / t_sys_permission_resource（**8 张，C端租户内识别（self-tenant 隔离）+ 租户偏好KV + 权限资源平台级广播**）
> - 平台运营域：t_channel / t_tenant_mp_config / t_sys_dict / t_approval_flow(PLATFORM scope) / t_i18n_language / t_i18n_currency / t_i18n_translation / t_country / t_region / t_config_meta（t_access_endpoint 已废弃并入 t_channel）
> - 商品域：t_ticket_meta

