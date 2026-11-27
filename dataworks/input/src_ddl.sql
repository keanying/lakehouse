-- 业务库表 DDL（dataworks/ddl_tool 业务库 DDL 补齐工具维护，请勿手工改动 -- @ 开头的标记行）
-- 更新时间：2026-11-27 18:10:27
-- 共 366 张：已录入 DDL 362 张，标记弃用 4 张，未对上业务库表 0 张
-- 格式：每张表前为标记行 -- @table 数据源:表名 / @at 录入时间 / @status 弃用 / @reason 原因 / @note 备注 / @tcmt 表描述 / @cmt 字段名 描述（人工修改的描述），其后为原始 CREATE TABLE 语句（弃用表可以没有）

-- @table BI_RDS_bi_datav:datav_auth
-- @at 2026-11-27 14:48:14
CREATE TABLE `datav_auth` (
  `user_id` int(10) NOT NULL COMMENT '用户id',
  `DataV_token` varchar(16) DEFAULT NULL COMMENT '大屏用户token',
  `account` varchar(32) DEFAULT NULL COMMENT '账号',
  `certificate` varchar(120) DEFAULT NULL COMMENT '密码',
  `capacity` int(10) DEFAULT NULL COMMENT '客容量',
  `land_name` varchar(50) DEFAULT NULL COMMENT '景区大屏标题-商户名称',
  `index` varchar(255) DEFAULT NULL COMMENT '景区大屏-首页url',
  `sale` varchar(255) DEFAULT NULL COMMENT '景区大屏-销售分析url',
  `tourist` varchar(255) DEFAULT NULL COMMENT '景区大屏-游客画像url',
  `analyst` varchar(255) DEFAULT NULL COMMENT '景区大屏-客流分析url',
  `secret_code` varchar(255) DEFAULT NULL COMMENT '12301大数据分析登录用户识别码',
  `land_id` int(20) DEFAULT NULL COMMENT '使用闸机统计出入园的景区',
  `is_use` int(10) NOT NULL COMMENT '是否使用（1：使用，0：禁用）',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `DataV_token` (`DataV_token`),
  KEY `idx_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:datav_preplay_describe_bak
-- @at 2026-11-27 16:15:40
CREATE TABLE `datav_preplay_describe_bak` (
  `id` int unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `member_id` int DEFAULT NULL COMMENT '会员id',
  `member_name` varchar(200) DEFAULT NULL COMMENT '名称',
  `stat_date` date DEFAULT NULL COMMENT '统计日期',
  `stat_slice` time DEFAULT NULL COMMENT '统计时间（切片）',
  `preplay_ticket_num` int DEFAULT NULL COMMENT '预约票数',
  `checked_ticket_num` int DEFAULT NULL COMMENT '检票票数',
  `booking_order_num` int DEFAULT NULL COMMENT '预订订单数',
  `nonchecked_ticket_num` int DEFAULT NULL COMMENT '未检票票数',
  `out_land_num` int DEFAULT NULL COMMENT '出园数',
  `in_land_num` int DEFAULT NULL COMMENT '在园数',
  PRIMARY KEY (`id`),
  KEY `idx_date` (`member_id`,`stat_date`)
) ENGINE=InnoDB AUTO_INCREMENT=5452261 DEFAULT CHARSET=utf8mb3;

-- @table BI_RDS_bi_datav:dim_channel
-- @at 2026-11-27 11:48:52
CREATE TABLE `dim_channel` (
  `order_channel_id` int NOT NULL COMMENT '订单表渠道ID',
  `track_source_id` int DEFAULT NULL COMMENT '轨迹表对应的source_id',
  `is_line_off` int DEFAULT NULL COMMENT '0:线上, 1:线下',
  `is_group` int DEFAULT NULL,
  `channel_name` varchar(50) DEFAULT NULL COMMENT '渠道名称',
  PRIMARY KEY (`order_channel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:dim_city
-- @at 2026-11-27 11:51:11
CREATE TABLE `dim_city` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `city_code` int DEFAULT NULL COMMENT '城市编码',
  `city_name` varchar(255) DEFAULT NULL COMMENT '城市名称',
  `province_code` int DEFAULT NULL COMMENT '省份编码',
  `province_name` varchar(255) DEFAULT NULL COMMENT '省份名称',
  `country_code` int DEFAULT NULL COMMENT '国家编码',
  `country_name` varchar(255) DEFAULT NULL COMMENT '国家名称',
  `area_code` varchar(20) DEFAULT NULL COMMENT '区域编码',
  `zip_code` varchar(6) DEFAULT NULL COMMENT '邮政编码',
  `lng` varchar(30) DEFAULT NULL COMMENT '经度',
  `lat` varchar(30) DEFAULT NULL COMMENT '纬度',
  PRIMARY KEY (`id`),
  KEY `idx_province_code` (`province_code`)
) ENGINE=InnoDB AUTO_INCREMENT=8816207 DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:dim_city_phone
-- @at 2026-11-27 11:54:40
CREATE TABLE `dim_city_phone` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `number` int DEFAULT NULL COMMENT '号码段',
  `type` int DEFAULT NULL COMMENT '1=移动，2=联通，3=电信，4= 电信虚拟运营商，5=联通虚拟运营商，6=移动虚拟运营商',
  `area_code` int DEFAULT NULL COMMENT '区域编码',
  `pft_area_code` varchar(20) DEFAULT NULL COMMENT '票付通区域编码',
  `zip_code` varchar(10) DEFAULT NULL COMMENT '邮政编码',
  `city_code` int DEFAULT NULL COMMENT '城市编码',
  `city_name` varchar(50) DEFAULT NULL COMMENT '城市名称',
  `province_code` int DEFAULT NULL COMMENT '省份编码',
  `province_name` varchar(50) DEFAULT NULL COMMENT '省份名称',
  `country_code` int DEFAULT NULL COMMENT '国家编码',
  `country_name` varchar(50) DEFAULT NULL COMMENT '国家名称',
  `lng` varchar(30) DEFAULT NULL COMMENT '经度',
  `lat` varchar(30) DEFAULT NULL COMMENT '纬度',
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_number` (`number`)
) ENGINE=InnoDB AUTO_INCREMENT=830669 DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:dim_distribute_system_type
-- @at 2026-11-27 11:36:24
CREATE TABLE `dim_distribute_system_type` (
  `user_id` int DEFAULT NULL COMMENT '账户id',
  `account` varchar(100) DEFAULT NULL COMMENT '账号',
  `distribute_system_name` varchar(50) DEFAULT NULL COMMENT '第三方分销系统名称',
  `dcodeurl_like` varchar(255) DEFAULT NULL COMMENT '对接url地址标志',
  `distribute_system_type` varchar(20) DEFAULT NULL COMMENT '第三方分销系统类型'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='对接第三方分销系统商户分类';

-- @table BI_RDS_bi_datav:dim_districts_info
-- @at 2026-11-27 14:21:03
-- @cmt city_adcode 城市编码
-- @cmt city_center 城市中心经纬度
-- @cmt city_lat 城市-纬度
-- @cmt city_lng 城市-经度
-- @cmt city_name 城市名称
-- @cmt district_adcode 区县行政区划码
-- @cmt district_center 区县中心经纬度
-- @cmt district_lat 区/县-纬度
-- @cmt district_lng 区/县-经度
-- @cmt district_name 区县-优先使用字段
-- @cmt id 主键ID
-- @cmt province_adcode 省份编码
-- @cmt province_center 省中心经纬度
-- @cmt province_lat 省份纬度
-- @cmt province_lng 省份经度
-- @cmt province_name 省份名称
CREATE TABLE `dim_districts_info` (
  `id` varchar(255) DEFAULT NULL,
  `province_name` varchar(255) DEFAULT NULL,
  `province_adcode` varchar(255) DEFAULT NULL,
  `province_center` varchar(255) DEFAULT NULL,
  `province_lng` varchar(255) DEFAULT NULL,
  `province_lat` varchar(255) DEFAULT NULL,
  `city_name` varchar(255) DEFAULT NULL,
  `city_adcode` varchar(255) DEFAULT NULL,
  `city_center` varchar(255) DEFAULT NULL,
  `city_lng` varchar(255) DEFAULT NULL,
  `city_lat` varchar(255) DEFAULT NULL,
  `district_name` varchar(255) DEFAULT NULL,
  `district_adcode` varchar(255) DEFAULT NULL,
  `district_center` varchar(255) DEFAULT NULL,
  `district_lng` varchar(255) DEFAULT NULL,
  `district_lat` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:dim_hy_area
-- @at 2026-11-27 14:23:39
-- @cmt city_name 城市名称
-- @cmt country_name 国家名称
-- @cmt merger_name_left 全称
-- @cmt province_name 省份名称
CREATE TABLE `dim_hy_area` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `pid` int DEFAULT NULL COMMENT '父id',
  `shortname` varchar(100) DEFAULT NULL COMMENT '简称',
  `name` varchar(100) DEFAULT NULL COMMENT '名称',
  `merger_name` varchar(255) DEFAULT NULL COMMENT '全称',
  `merger_name_left` varchar(255) DEFAULT NULL,
  `province_name` varchar(50) DEFAULT NULL,
  `city_name` varchar(50) DEFAULT NULL,
  `country_name` varchar(50) DEFAULT NULL,
  `level` tinyint DEFAULT NULL COMMENT '层级 0 1 2 省市区县',
  `pinyin` varchar(100) DEFAULT NULL COMMENT '拼音',
  `code` varchar(100) DEFAULT NULL COMMENT '长途区号',
  `zip_code` varchar(100) DEFAULT NULL COMMENT '邮编',
  `first` varchar(50) DEFAULT NULL COMMENT '首字母',
  `lng` varchar(100) DEFAULT NULL COMMENT '经度',
  `lat` varchar(100) DEFAULT NULL COMMENT '纬度',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3750 DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:dim_idcard_city
-- @at 2026-11-27 14:24:19
-- @cmt city 城市
-- @cmt country 国家
-- @cmt id 主键ID
-- @cmt idcard 身份证号段
-- @cmt province 省份
CREATE TABLE `dim_idcard_city` (
  `id` int NOT NULL AUTO_INCREMENT,
  `idcard` int DEFAULT NULL,
  `province` varchar(50) DEFAULT NULL,
  `city` varchar(50) DEFAULT NULL,
  `country` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=13167 DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:dim_land_topic
-- @at 2026-11-27 14:24:53
-- @cmt land_topic 景区主题
-- @cmt land_topic_name 景区主题名称
CREATE TABLE `dim_land_topic` (
  `land_topic` varchar(20) DEFAULT NULL,
  `land_topic_name` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:dim_order_status
-- @at 2026-11-27 14:25:14
-- @cmt order_status 订单状态
-- @cmt order_status_name 订单状态名称
CREATE TABLE `dim_order_status` (
  `order_status` tinyint(1) DEFAULT NULL,
  `order_status_name` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:dim_province
-- @at 2026-11-27 14:25:29
CREATE TABLE `dim_province` (
  `province_code` int NOT NULL COMMENT '省编码',
  `province_name` varchar(255) DEFAULT NULL COMMENT '省名称',
  `province_adcode` int DEFAULT NULL COMMENT '邮政编码',
  PRIMARY KEY (`province_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- @table BI_RDS_bi_datav:dim_resource_type
-- @at 2026-11-27 14:25:52
-- @cmt resource_type 直签/第三方    1：三方 2:直签
-- @cmt resource_type_name 资源类型名称
CREATE TABLE `dim_resource_type` (
  `resource_type` varchar(1) DEFAULT NULL,
  `resource_type_name` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:dim_staff_group
-- @at 2026-11-27 14:26:10
-- @cmt staff_group_id 员工组ID
-- @cmt staff_group_name 员工组名称
CREATE TABLE `dim_staff_group` (
  `staff_group_id` int DEFAULT NULL,
  `staff_group_name` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:dim_user_short_name
-- @at 2026-11-27 14:26:25
-- @cmt short_name 简名称
-- @cmt user_id 用户id
CREATE TABLE `dim_user_short_name` (
  `user_id` int DEFAULT NULL,
  `short_name` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC;

-- @table BI_RDS_bi_datav:marketing_test
-- @at 2026-11-27 14:29:29
-- @status 弃用
-- @reason 测试 / 临时表

-- @table BI_RDS_bi_datav:marketing_test_score
-- @at 2026-11-27 14:29:35
-- @status 弃用
-- @reason 测试 / 临时表

-- @table ECS_pft_business_case:pft_allinone_card_trades
-- @at 2026-11-27 14:40:50
CREATE TABLE `pft_allinone_card_trades` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `date_time` int(8) NOT NULL DEFAULT '0' COMMENT '日期',
  `ordernum` varchar(30) NOT NULL DEFAULT '' COMMENT '交易流水订单号',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `member_id` int(10) NOT NULL DEFAULT '0' COMMENT '用户ID',
  `operate_id` int(10) NOT NULL DEFAULT '0' COMMENT '操作员ID',
  `mobile` varchar(15) NOT NULL DEFAULT '' COMMENT '手机号',
  `aio_card_id` int(10) NOT NULL DEFAULT '0' COMMENT '开卡记录id',
  `physical_principal` int(10) NOT NULL DEFAULT '0' COMMENT '卡本金消费金额',
  `physical_principal_balance` int(10) NOT NULL DEFAULT '0' COMMENT '卡本金余额',
  `physical_bonus` int(10) NOT NULL DEFAULT '0' COMMENT '卡奖励金消费金额',
  `physical_bonus_balance` int(10) NOT NULL DEFAULT '0' COMMENT '卡奖励金余额',
  `pay_type` tinyint(4) NOT NULL DEFAULT '1' COMMENT '支付方式： 1现金支付, 2支付宝支付, 3微信支付，4卡支付 5:非支付的时候默认值 6：易宝',
  `operation_type` tinyint(4) NOT NULL DEFAULT '8' COMMENT '交易类型：1充值 2工本费 3押金 4激活 5补卡 6退卡 7仅退款 8奖励金 9年卡套餐购买 10年卡套餐续费 11年卡套餐激活 12普通订单消费',
  `create_time` int(11) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `money` int(11) NOT NULL DEFAULT '0' COMMENT '操作金额',
  `site_id` int(10) NOT NULL DEFAULT '0' COMMENT '站点id',
  `channel` tinyint(1) NOT NULL DEFAULT '1' COMMENT '操作渠道  1：云票务 2：微商城 3：闸机 4：手持机',
  `card_no` varchar(50) NOT NULL DEFAULT '' COMMENT '实体卡号',
  `wrist_id` int(10) NOT NULL DEFAULT '0' COMMENT '腕带id',
  `sub_merchant_id` int(10) NOT NULL DEFAULT '0' COMMENT '子商户id',
  PRIMARY KEY (`id`),
  KEY `idx_ordernum` (`ordernum`),
  KEY `idx_date` (`date_time`),
  KEY `idx_oper` (`operate_id`),
  KEY `idx_mobile` (`mobile`),
  KEY `idx_aio_card_id` (`aio_card_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=265583 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='新版园区一卡通消费记录表';

-- @table ECS_pft_business_case:pft_annual_affiliates_card
-- @at 2026-11-27 14:41:06
CREATE TABLE `pft_annual_affiliates_card` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `card_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '年卡id',
  `name` varchar(10) NOT NULL DEFAULT '' COMMENT '姓名',
  `id_card` varchar(36) NOT NULL DEFAULT '' COMMENT '证件号码',
  `voucher_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '证件类型',
  `avatar` varchar(255) NOT NULL DEFAULT '' COMMENT '头像，存url地址',
  `state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态 1：正常 2：已删除',
  `idx` tinyint(1) NOT NULL DEFAULT '1' COMMENT '年卡人脸序号码',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '票id',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_card_id` (`card_id`) USING BTREE,
  KEY `idx_id_card` (`id_card`) USING BTREE,
  KEY `idx_create_time` (`create_time`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=169234 DEFAULT CHARSET=utf8 COMMENT='年卡附属持卡人表';

-- @table ECS_pft_business_case:pft_annual_aliface_map
-- @at 2026-11-27 14:41:17
CREATE TABLE `pft_annual_aliface_map` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'pk',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '商户id',
  `virtual_no` varchar(10) NOT NULL DEFAULT '' COMMENT '虚拟卡号',
  `id_card_no` varchar(20) NOT NULL DEFAULT '' COMMENT '身份证号',
  `face_id` varchar(60) NOT NULL DEFAULT '' COMMENT '人脸id',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态 0-删除 1-正常',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `virtual_no` (`virtual_no`) USING BTREE,
  KEY `sid_id_card` (`sid`,`id_card_no`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=606215 DEFAULT CHARSET=utf8 COMMENT='年卡支付宝人脸id关系表';

-- @table ECS_pft_business_case:pft_annual_async_order
-- @at 2026-11-27 14:41:32
CREATE TABLE `pft_annual_async_order` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `consume_map` varchar(255) NOT NULL DEFAULT '' COMMENT '下单参数',
  `card_mid` int(11) NOT NULL DEFAULT '0' COMMENT '购买者id',
  `sid` int(11) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `terminal` int(11) NOT NULL DEFAULT '0' COMMENT '终端号',
  `operId` int(11) NOT NULL DEFAULT '0' COMMENT '操作员id',
  `err_msg` varchar(255) NOT NULL DEFAULT '' COMMENT '错误信息',
  `number` tinyint(2) NOT NULL DEFAULT '0' COMMENT '重试次数',
  `status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态 ：0 .未成功 1,成功',
  `card_order_id` int(11) NOT NULL COMMENT '关联pft_annual_card_order',
  `options` text NOT NULL COMMENT '年卡特权支付扩展信息（用于过闸记录）',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_create_time` (`create_time`) USING BTREE,
  KEY `idx_sid` (`sid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1353323 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡异步下单重试表';

-- @table ECS_pft_business_case:pft_annual_card
-- @at 2026-11-27 14:41:52
-- @cmt id 主键ID
CREATE TABLE `pft_annual_card` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `memberid` int(10) NOT NULL COMMENT '会员id',
  `sid` int(10) NOT NULL COMMENT '供应商id',
  `pid` int(10) NOT NULL COMMENT '关联的年卡产品id',
  `virtual_no` varchar(8) NOT NULL COMMENT '虚拟卡号',
  `physics_no` varchar(20) NOT NULL COMMENT '物理卡号',
  `card_no` varchar(30) NOT NULL DEFAULT '' COMMENT '卡片上的卡号',
  `password` varchar(32) NOT NULL COMMENT '卡密码',
  `renew_times` tinyint(3) unsigned NOT NULL COMMENT '续费次数',
  `status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态，0未激活，1激活,2禁用,3仓库,4挂失',
  `create_time` int(10) NOT NULL COMMENT '生成时间',
  `active_time` int(10) NOT NULL COMMENT '激活时间',
  `sale_time` int(10) NOT NULL COMMENT '售出时间',
  `update_time` int(10) NOT NULL COMMENT '更新时间',
  `activate_source` tinyint(1) NOT NULL DEFAULT '0' COMMENT '激活渠道，0pc,1终端',
  `avalid_begin` int(10) unsigned NOT NULL COMMENT '有效开始日期',
  `avalid_end` int(10) unsigned NOT NULL COMMENT '有效截止日期',
  `distributor_id` int(10) NOT NULL DEFAULT '0' COMMENT '分销商id',
  `send_num` int(10) NOT NULL DEFAULT '0' COMMENT '过期微信推送次数',
  `dname` varchar(100) NOT NULL COMMENT '用户姓名',
  `mobile` char(11) NOT NULL COMMENT '用户手机号',
  `id_card_no` varchar(36) NOT NULL COMMENT '用户身份证',
  `province` smallint(2) DEFAULT NULL COMMENT '所在地,省份',
  `city` smallint(2) DEFAULT NULL COMMENT '所在地,城市',
  `address` varchar(255) DEFAULT NULL COMMENT '地址',
  `lock_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '年卡是否锁定 0否 1是',
  `annual_status` int(10) unsigned NOT NULL DEFAULT '8' COMMENT '年卡叠加状态',
  `ext_info` json NOT NULL COMMENT '年卡扩展属性',
  `remarks` varchar(150) NOT NULL DEFAULT '' COMMENT '年卡激活备注',
  PRIMARY KEY (`id`,`activate_source`),
  UNIQUE KEY `virtual_index` (`virtual_no`),
  KEY `idx_distributor_id` (`distributor_id`),
  KEY `idx_memberid` (`memberid`),
  KEY `idx_physicsno` (`physics_no`),
  KEY `idx_pid` (`pid`),
  KEY `idx_sid_mobile` (`sid`,`mobile`),
  KEY `idx_card_no` (`card_no`),
  KEY `idx_sid_status` (`sid`,`status`),
  KEY `idx_avalid_end` (`avalid_end`) USING BTREE,
  KEY `idx_idcard_no` (`id_card_no`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=10596238 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table ECS_pft_business_case:pft_annual_card_active_apply
-- @at 2026-11-27 14:42:05
CREATE TABLE `pft_annual_card_active_apply` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '商家id',
  `annual_id` int(10) NOT NULL DEFAULT '0' COMMENT '年卡表id',
  `mobile` varchar(11) NOT NULL DEFAULT '' COMMENT '手机号',
  `id_card` varchar(20) NOT NULL DEFAULT '' COMMENT '身份证号码',
  `name` varchar(20) NOT NULL DEFAULT '' COMMENT '姓名',
  `tid` int(10) NOT NULL DEFAULT '0' COMMENT '票id',
  `audit_materials` varchar(2500) NOT NULL DEFAULT '' COMMENT '审核材料',
  `state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '审核状态 0：审核中 1：审核通过 2：审核不通过',
  `apply_remark` varchar(50) NOT NULL DEFAULT '' COMMENT '申请备注',
  `audit_remark` varchar(50) NOT NULL DEFAULT '' COMMENT '审核备注',
  `op_id` int(10) NOT NULL DEFAULT '0' COMMENT '审核操作人id',
  `active_params` json NOT NULL COMMENT '激活时的参数',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=85110 DEFAULT CHARSET=utf8 COMMENT='年卡激活审核记录表';

-- @table ECS_pft_business_case:pft_annual_card_booking_rule
-- @at 2026-11-27 14:42:17
CREATE TABLE `pft_annual_card_booking_rule` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `title` varchar(200) NOT NULL DEFAULT '' COMMENT '规则名称',
  `card_pid` int(10) NOT NULL DEFAULT '0' COMMENT '年卡产品ID',
  `card_tid` int(10) NOT NULL DEFAULT '0' COMMENT '年卡门票ID',
  `pri_map` json DEFAULT NULL COMMENT '年卡特权开关配置 "{"1012898":1,"1012899":0}',
  `state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态:0=停用，1启用, -1删除',
  `create_time` int(11) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `operator_id` int(10) NOT NULL DEFAULT '0' COMMENT '最新操作员id，关联pft_member.id',
  `type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '年卡预约特权扣减模式 1:核销扣减 2:预约扣减',
  PRIMARY KEY (`id`),
  KEY `idx_sid_card_tid` (`sid`,`card_tid`)
) ENGINE=InnoDB AUTO_INCREMENT=216 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡特权预约规则表';

-- @table ECS_pft_business_case:pft_annual_card_booking_storage
-- @at 2026-11-27 14:46:57
CREATE TABLE `pft_annual_card_booking_storage` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `play_date` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '日期 20171010',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品ID',
  `ticket_id` int(10) NOT NULL DEFAULT '0' COMMENT '门票id',
  `ptype` tinyint(1) NOT NULL DEFAULT '0' COMMENT '类型:0=平时,1=特殊',
  `state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态:0=停用，1启用',
  `storage` int(10) NOT NULL DEFAULT '-1' COMMENT '总库存',
  `ticket_sold_count` int(6) NOT NULL DEFAULT '0' COMMENT '已售票数',
  `create_time` int(11) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `operator_id` int(10) NOT NULL DEFAULT '0' COMMENT '最新操作员id，关联pft_member.id',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_ticket_id_play_date` (`ticket_id`,`play_date`),
  KEY `idx_sid` (`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=14339 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡特权预约日历价格规则细表';

-- @table ECS_pft_business_case:pft_annual_card_conf
-- @at 2026-11-27 16:33:35
-- @cmt id 主键ID
CREATE TABLE `pft_annual_card_conf` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `tid` int(10) unsigned NOT NULL COMMENT '产品id',
  `aid` int(10) NOT NULL COMMENT '供应商id',
  `auto_act_day` smallint(6) NOT NULL DEFAULT '-1' COMMENT '购买后自动激活天数',
  `srch_limit` varchar(20) NOT NULL DEFAULT '1' COMMENT '搜索限制',
  `cert_limit` tinyint(1) NOT NULL DEFAULT '0' COMMENT '身份证认证限制',
  `act_notice` tinyint(1) NOT NULL DEFAULT '0' COMMENT '激活通知',
  PRIMARY KEY (`id`),
  UNIQUE KEY `tid` (`tid`)
) ENGINE=InnoDB AUTO_INCREMENT=1896 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡产品激活配置表';

-- @table ECS_pft_business_case:pft_annual_card_order
-- @at 2026-11-27 14:47:23
CREATE TABLE `pft_annual_card_order` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `tid` int(10) NOT NULL COMMENT '门票id',
  `memberid` int(10) NOT NULL COMMENT '会员id',
  `aid` int(10) NOT NULL COMMENT '供应商id',
  `virtual_no` varchar(8) NOT NULL,
  `ordernum` varchar(30) NOT NULL COMMENT '订单号',
  `num` int(10) NOT NULL COMMENT '购买数量',
  `create_time` int(10) NOT NULL COMMENT '订单生成时间',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '0取消1正常',
  `package_id` int(10) NOT NULL DEFAULT '0' COMMENT '年卡套餐id',
  `order_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '订单状态（uu_ss_order表中的）',
  `verify_time` int(10) NOT NULL DEFAULT '0' COMMENT '订单验证时间',
  PRIMARY KEY (`id`),
  KEY `idx_ordernum` (`ordernum`),
  KEY `idx_virtual_no` (`virtual_no`),
  KEY `idx_package_id` (`package_id`),
  KEY `idx_aid_memberid_status` (`aid`,`memberid`,`status`)
) ENGINE=InnoDB AUTO_INCREMENT=29992243 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡特权过闸表';

-- @table ECS_pft_business_case:pft_annual_card_order_task
-- @at 2026-11-27 14:47:37
CREATE TABLE `pft_annual_card_order_task` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `mid` int(10) NOT NULL DEFAULT '0' COMMENT '下单人ID',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `paymode` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '支付方式',
  `ordermode` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '交易来源 0=平台，10=云票务',
  `pay_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '支付金额',
  `tnum` int(10) unsigned NOT NULL DEFAULT '1' COMMENT '购买数量',
  `tid` int(10) NOT NULL DEFAULT '0' COMMENT '年卡门票ID',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '年卡产品ID',
  `lid` int(10) NOT NULL DEFAULT '0' COMMENT '年卡景区ID',
  `dname` varchar(100) NOT NULL DEFAULT '' COMMENT '下单人姓名',
  `mobile` varchar(20) NOT NULL DEFAULT '' COMMENT '下单人手机号',
  `operator_id` int(10) NOT NULL DEFAULT '0' COMMENT '操作员ID',
  `remark` varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `order_time` int(10) NOT NULL DEFAULT '0' COMMENT '下单时间',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `t_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态 0 下单中 1已完成',
  `task_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '任务类型 0下单 1导入 2延期',
  PRIMARY KEY (`id`),
  KEY `idx_create_time` (`create_time`),
  KEY `idx_dname_mobile` (`dname`,`mobile`),
  KEY `idx_lid_tid` (`lid`,`tid`),
  KEY `idx_sid_opid` (`sid`,`operator_id`)
) ENGINE=InnoDB AUTO_INCREMENT=39586 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡下单异步任务表';

-- @table ECS_pft_business_case:pft_annual_card_photos
-- @at 2026-11-27 14:47:51
CREATE TABLE `pft_annual_card_photos` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `virtual_no` varchar(10) NOT NULL DEFAULT '' COMMENT '虚拟卡号',
  `photos` varchar(1024) NOT NULL DEFAULT '' COMMENT '照片集合,json格式',
  `create_time` int(10) unsigned NOT NULL COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uni_virtual` (`virtual_no`)
) ENGINE=InnoDB AUTO_INCREMENT=2788834 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡用户照片表';

-- @table ECS_pft_business_case:pft_annual_card_privilege
-- @at 2026-11-27 14:48:03
CREATE TABLE `pft_annual_card_privilege` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_tid` int(10) NOT NULL COMMENT '所属票类ID',
  `tid` int(10) NOT NULL COMMENT '包含的门票id',
  `aid` int(10) NOT NULL COMMENT '上级供应商id',
  `use_limit` varchar(50) NOT NULL COMMENT '使用限制',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态',
  PRIMARY KEY (`id`),
  UNIQUE KEY `t_relation` (`parent_tid`,`tid`)
) ENGINE=InnoDB AUTO_INCREMENT=5385 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡套餐特权表';

-- @table ECS_pft_business_case:pft_annual_card_privilege_group
-- @at 2026-11-27 14:48:17
CREATE TABLE `pft_annual_card_privilege_group` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '特权分组id',
  `parent_tid` int(10) NOT NULL DEFAULT '0' COMMENT '所属票类ID',
  `aid` int(10) NOT NULL DEFAULT '0' COMMENT '上级供应商id',
  `use_limit` varchar(50) NOT NULL DEFAULT '-1' COMMENT '使用限制',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '生成时间',
  `group_name` varchar(50) NOT NULL DEFAULT '' COMMENT '组合特权名称',
  `sort` int(10) NOT NULL DEFAULT '0' COMMENT '组合排序',
  `use_time_limit` json DEFAULT NULL COMMENT '可使用时间限制  {"type":1,"begin_time":"9:00","end_time":"23:00"} type 限制类型0：不限 1：限制',
  `holiday_limit` json DEFAULT NULL COMMENT '可使用时间限制  {"type":1,"holiday_limit":["weekend"]} type 限制类型0：不限 1：限制 holiday_limit 见年卡常量枚举值',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=42718 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡特权组合关联及配置表';

-- @table ECS_pft_business_case:pft_annual_card_privilege_relation
-- @at 2026-11-27 14:48:36
CREATE TABLE `pft_annual_card_privilege_relation` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `parent_tid` int(10) NOT NULL DEFAULT '0' COMMENT '所属票类ID',
  `aid` int(10) NOT NULL DEFAULT '0' COMMENT '上级供应商id',
  `tid` int(10) NOT NULL DEFAULT '0' COMMENT '包含的门票id',
  `state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态',
  `group_id` int(10) NOT NULL DEFAULT '0' COMMENT '特权分组id',
  `supplier_aid` int(10) NOT NULL DEFAULT '0' COMMENT '上级供应商id  如果是自供应的 值和aid一致',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=44549 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡套餐特权关系表';

-- @table ECS_pft_business_case:pft_annual_card_renew
-- @at 2026-11-27 14:48:51
CREATE TABLE `pft_annual_card_renew` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `card_id` int(10) unsigned NOT NULL COMMENT '年卡id',
  `memberid` int(10) unsigned NOT NULL COMMENT '会员id',
  `sid` int(10) unsigned NOT NULL COMMENT '供应商id',
  `money` int(10) unsigned NOT NULL COMMENT '续费金额（分）',
  `create_time` int(10) unsigned NOT NULL COMMENT '续费时间',
  `order_id` varchar(20) CHARACTER SET utf8 NOT NULL DEFAULT '' COMMENT '续费订单号',
  `status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '支付状态',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=217532 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='年卡用户续费表';

-- @table ECS_pft_business_case:pft_annual_card_task_detail
-- @at 2026-11-27 14:50:23
CREATE TABLE `pft_annual_card_task_detail` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `track_id` int(10) NOT NULL DEFAULT '0' COMMENT '异步任务ID',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `pay_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '单笔订单金额',
  `ordernum` varchar(64) NOT NULL DEFAULT '' COMMENT '订单号',
  `virtual_no` varchar(8) NOT NULL DEFAULT '' COMMENT '虚拟卡号',
  `physics_no` varchar(20) NOT NULL DEFAULT '0' COMMENT '物理卡号',
  `card_no` varchar(30) NOT NULL DEFAULT '' COMMENT '实体卡号',
  `remark` varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `d_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态 0处理中 1下单成功 2下单失败',
  `dname` varchar(100) NOT NULL DEFAULT '' COMMENT '用户名称',
  `id_card_no` varchar(36) NOT NULL DEFAULT '' COMMENT '身份证号',
  `mobile` varchar(15) NOT NULL DEFAULT '0' COMMENT '手机号',
  `avalid_begin` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '有效期开始时间',
  `avalid_end` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '有效期结束时间',
  `ext` json DEFAULT NULL COMMENT '扩展信息',
  PRIMARY KEY (`id`),
  KEY `idx_track_id` (`track_id`),
  KEY `idx_create_time` (`create_time`),
  KEY `idx_sid` (`sid`,`track_id`,`virtual_no`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=6591378 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡下单异步任务明细表';

-- @table ECS_pft_business_case:pft_annual_card_trade
-- @at 2026-11-27 14:50:37
CREATE TABLE `pft_annual_card_trade` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `card_id` int(10) NOT NULL DEFAULT '0' COMMENT '年卡ID',
  `member_id` int(10) NOT NULL DEFAULT '0' COMMENT '用户ID',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `type` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '交易类型：0=售卡，1=续费，2=补卡，3=被取消,  4=激活，5=验证（特权支付）',
  `payway` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '支付方式',
  `source` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '交易来源 0=平台，10=云票务',
  `pay_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '支付金额',
  `num` int(10) unsigned NOT NULL DEFAULT '1' COMMENT '购买数量',
  `ordernum` varchar(64) NOT NULL DEFAULT '' COMMENT '交易订单号',
  `ticket_id` int(10) NOT NULL DEFAULT '0' COMMENT '年卡门票ID',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `operator_id` int(10) NOT NULL DEFAULT '0' COMMENT '操作员ID',
  `remark` varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `user_name` varchar(100) NOT NULL DEFAULT '' COMMENT '用户姓名',
  `user_mobile` varchar(64) NOT NULL DEFAULT '' COMMENT '用户手机号',
  `user_id_card` varchar(36) NOT NULL DEFAULT '' COMMENT '用户身份证号',
  `virtual_no` varchar(8) NOT NULL DEFAULT '' COMMENT '虚拟卡号',
  `card_no` varchar(16) NOT NULL DEFAULT '' COMMENT '实体卡号',
  `physics_no` varchar(20) NOT NULL DEFAULT '' COMMENT '物理卡号',
  `p_name` varchar(200) NOT NULL DEFAULT '' COMMENT '卡套餐名称',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品id',
  `wrist_id` int(10) NOT NULL DEFAULT '0' COMMENT '腕带id',
  PRIMARY KEY (`id`),
  KEY `idx_add_time` (`add_time`),
  KEY `idx_pid` (`pid`),
  KEY `idx_sid_type_payway` (`sid`,`type`,`payway`),
  KEY `idx_ticket_id` (`ticket_id`),
  KEY `idx_virtural_no` (`virtual_no`),
  KEY `ordernum` (`ordernum`),
  KEY `idx_operatorid_sid_source_addtime` (`operator_id`,`sid`,`source`,`add_time`),
  KEY `idx_sid_card_id` (`card_id`,`sid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=35082695 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table ECS_pft_business_case:pft_annual_cover_rule
-- @at 2026-11-27 14:50:48
CREATE TABLE `pft_annual_cover_rule` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT 'pk',
  `apply_did` bigint(20) NOT NULL DEFAULT '0' COMMENT '商户id',
  `rule_name` varchar(50) NOT NULL DEFAULT '' COMMENT '规则名称',
  `cover_url` varchar(255) NOT NULL DEFAULT '' COMMENT '封面地址',
  `rule_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态 1-使用中 2-停用',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted_at` datetime DEFAULT NULL COMMENT '删除时间',
  `delete_flag` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0-正常 1-删除',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_apply_did` (`apply_did`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8 COMMENT='年卡封面规则配置表';

-- @table ECS_pft_business_case:pft_annual_cover_suit_ticket
-- @at 2026-11-27 14:51:07
CREATE TABLE `pft_annual_cover_suit_ticket` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'pk',
  `rule_id` varchar(50) NOT NULL DEFAULT '' COMMENT 'pft_annual_cover_rule主键',
  `lid` int(10) NOT NULL DEFAULT '0' COMMENT '产品id',
  `tid` int(10) NOT NULL DEFAULT '0' COMMENT '票id',
  `delete_flag` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0-正常 1-删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_tid` (`tid`,`delete_flag`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=167 DEFAULT CHARSET=utf8 COMMENT='年卡封面规则适用票';

-- @table ECS_pft_business_case:pft_annual_desensitization_config
-- @at 2026-11-27 14:51:19
CREATE TABLE `pft_annual_desensitization_config` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `desensitization_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否开启脱敏 0否 1是',
  `desensitization_page` varchar(255) NOT NULL DEFAULT '' COMMENT '{"platform":{"audit_detail":1,"batch_Progress":1,"manage":1,"record":1},"scenic":{"consume":1,"menber_manege":"1"}}',
  `staff_limit_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '脱敏员工配置 1：全部 2：指定员工',
  `staff_id` varchar(1000) NOT NULL DEFAULT '' COMMENT '员工id',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `show_use_limit` tinyint(1) NOT NULL DEFAULT '1' COMMENT '年卡特权次数显示 0: 不展示 1: 展示',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡脱敏信息配置';

-- @table ECS_pft_business_case:pft_annual_manage_record
-- @at 2026-11-27 14:51:31
CREATE TABLE `pft_annual_manage_record` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '操作记录主键',
  `batch_id` int(10) NOT NULL DEFAULT '0' COMMENT '批次号，供应商timestamp',
  `virtual_no` varchar(20) NOT NULL DEFAULT '' COMMENT '虚拟卡号',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `opt_member` int(10) NOT NULL DEFAULT '0' COMMENT '操作人id',
  `opt_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '操作类型：1-编辑 2-挂失 3-补卡 4-禁用 5-恢复 6-删除实体卡 7-补实体卡 8-续费 9-人脸短信 10-批量禁用 11-批量恢复 12-批量人脸短信 13-升级',
  `channel` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1-平台 2-云票务',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '生成时间',
  `before_info` varchar(1000) NOT NULL DEFAULT '' COMMENT '操作前',
  `after_info` varchar(1000) NOT NULL DEFAULT '' COMMENT '操作后',
  `before_avatars` varchar(1000) NOT NULL DEFAULT '' COMMENT '操作前照片',
  `after_avatars` varchar(1000) NOT NULL DEFAULT '' COMMENT '操作后照片',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_virtual_no` (`virtual_no`),
  KEY `idx_create_time` (`create_time`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=542002 DEFAULT CHARSET=utf8 COMMENT='年卡管理操作记录';

-- @table ECS_pft_business_case:pft_annual_ticket_relation
-- @at 2026-11-27 14:51:42
CREATE TABLE `pft_annual_ticket_relation` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '表id',
  `parent_tid` int(10) NOT NULL DEFAULT '0' COMMENT '年卡产品门票id',
  `tid` int(10) NOT NULL DEFAULT '0' COMMENT '门票id',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '套餐创建时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `state` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '关联状态状态 0未生效 1已生效',
  `type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '关联类型：1续费 2升级',
  PRIMARY KEY (`id`),
  KEY `idx_parent_tid_tid` (`parent_tid`,`tid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1916 DEFAULT CHARSET=utf8 COMMENT='年卡关联套餐配置表';

-- @table ECS_pft_business_case:pft_annual_wx_config
-- @at 2026-11-27 14:51:56
CREATE TABLE `pft_annual_wx_config` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `is_open` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0不开启 1 开启是否开启推送',
  `validity` int(11) NOT NULL DEFAULT '0' COMMENT '过期时间',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '用户id',
  `notice_num` int(11) NOT NULL DEFAULT '0' COMMENT '通知次数',
  `space_day` int(11) NOT NULL DEFAULT '0' COMMENT '发送间隔天',
  `begin_time` int(11) NOT NULL DEFAULT '0' COMMENT '开始时间',
  PRIMARY KEY (`id`),
  KEY `idx_member_id` (`member_id`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='年卡过期微信推送配置';

-- @table ECS_pft_business_case:pft_card_order_journal
-- @at 2026-11-27 14:52:08
CREATE TABLE `pft_card_order_journal` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `ordernum` varchar(30) NOT NULL DEFAULT '' COMMENT '交易流水订单号',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `member_id` int(10) NOT NULL DEFAULT '0' COMMENT '用户ID',
  `order_member_id` int(10) NOT NULL DEFAULT '0' COMMENT '转账接收方用户id0',
  `operate_id` int(10) NOT NULL DEFAULT '0' COMMENT '操作员ID',
  `balance_pay_money` int(10) NOT NULL DEFAULT '0' COMMENT '卡本金消费金额',
  `award_pay_money` int(10) NOT NULL DEFAULT '0' COMMENT '卡奖励金消费金额',
  `refund_status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '退款状态 1：未退款 2：部分退款 3：已退款',
  `pay_status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '支付状态 1：未支付 2：已支付 3：支付失败',
  `error_msg` json DEFAULT NULL COMMENT '支付失败原因',
  `money` int(10) NOT NULL DEFAULT '0' COMMENT '操作金额',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_ordernum` (`ordernum`),
  KEY `idx_sid_mid_oper` (`sid`,`member_id`,`operate_id`)
) ENGINE=InnoDB AUTO_INCREMENT=106826 DEFAULT CHARSET=utf8 COMMENT='卡消费记录表';

-- @table ECS_pft_business_case:pft_card_order_refund_journal
-- @at 2026-11-27 14:52:19
CREATE TABLE `pft_card_order_refund_journal` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `pay_journal_id` int(10) NOT NULL DEFAULT '0' COMMENT '支付记录id',
  `ordernum` varchar(30) NOT NULL DEFAULT '' COMMENT '订单支付流水订单号pft_card_order_journal表订单号',
  `refund_order_num` varchar(30) NOT NULL DEFAULT '' COMMENT '退款订单号',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `member_id` int(10) NOT NULL DEFAULT '0' COMMENT '用户ID',
  `operate_id` int(10) NOT NULL DEFAULT '0' COMMENT '操作员ID',
  `balance_refund_money` int(10) NOT NULL DEFAULT '0' COMMENT '余额退款金额',
  `award_refund_money` int(10) NOT NULL DEFAULT '0' COMMENT '奖励金退款金额',
  `refund_money` int(10) NOT NULL DEFAULT '0' COMMENT '退款总金额',
  `refund_status` tinyint(1) NOT NULL DEFAULT '2' COMMENT '退款状态 1：退款失败 2：退款成功',
  `error_msg` json DEFAULT NULL COMMENT '退款失败原因',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_refund_order_num` (`refund_order_num`),
  KEY `idx_pay_journal_id` (`pay_journal_id`),
  KEY `idx_sid_mid_oper` (`sid`,`member_id`,`operate_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1618 DEFAULT CHARSET=utf8 COMMENT='卡消费退款记录表';

-- @table ECS_pft_business_case:pft_external_code_order
-- @at 2026-11-27 15:05:48
CREATE TABLE `pft_external_code_order` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `batch_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '批次id',
  `v_code` varchar(255) NOT NULL DEFAULT '' COMMENT '外部码',
  `ordernum` varchar(20) NOT NULL DEFAULT '' COMMENT '订单号',
  `send_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发送时间',
  `start_dt` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '结束时间,和开始都为0则订单使用游玩日期;有结束则使用批次有效期;都有值则使用固定有效期',
  `end_dt` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '开始时间,和结束都为0则订单使用游玩日期;有结束则使用批次有效期;都有值则使用固定有效期',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `send_type` tinyint(1) NOT NULL DEFAULT '2' COMMENT '发码方式：1一单一码;2一单多码',
  `state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '删除：0删除;1正常',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_ordernum` (`ordernum`),
  KEY `idx_v_code` (`v_code`)
) ENGINE=InnoDB AUTO_INCREMENT=3448738 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='外部码对应订单表';

-- @table ECS_pft_business_case:pft_marketing_sms_task
-- @at 2026-11-27 15:06:15
CREATE TABLE `pft_marketing_sms_task` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `uid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '用户ID',
  `p_type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '推送人员类型 1=用户画像配置 2=导入手机号 3=输入手机号 4=选择用户类型',
  `push_type_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '不同推送类型的业务ID',
  `state` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '发送状态 1=待发送 2=发送中 3=发送完成 4=发送失败',
  `is_send` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '是否可发送 1=准备中 2=可发送',
  `operater_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '操作用户ID',
  `is_timing` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '是否定时发送 1=定时发送 2=非定时发送',
  `send_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '发送时间',
  `finish_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '发送完成时间',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`uid`),
  KEY `idx_create_time` (`create_time`),
  KEY `idx_send_time` (`send_time`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=2630 DEFAULT CHARSET=utf8 COMMENT='营销短信发送任务表';

-- @table ECS_pft_business_case:pft_park_card_order
-- @at 2026-11-27 14:40:18
-- @cmt id 主键ID
CREATE TABLE `pft_park_card_order` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `member_id` int(10) unsigned NOT NULL COMMENT 'IC卡绑定的账号id',
  `sid` int(10) unsigned NOT NULL COMMENT '所属供应商id',
  `ordernum` varchar(20) NOT NULL DEFAULT '0' COMMENT '订单号',
  `tnum` int(10) unsigned NOT NULL COMMENT '购买张数',
  `money` int(10) unsigned NOT NULL COMMENT '订单金额',
  `op_id` int(10) unsigned NOT NULL COMMENT '操作人员id',
  `order_time` int(10) unsigned NOT NULL COMMENT '下单时间',
  `card_id` int(10) unsigned NOT NULL COMMENT 'pft_card 表id',
  PRIMARY KEY (`id`),
  KEY `idx_mid` (`member_id`),
  KEY `idx_opid` (`op_id`),
  KEY `idx_ordernum` (`ordernum`),
  KEY `idx_sid` (`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=417559 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table ECS_summary_eco_mms:pft_distribute_order
-- @at 2026-11-27 16:00:26
CREATE TABLE `pft_distribute_order` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `seller_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '直推分销员用户id',
  `snap_level` int(11) NOT NULL DEFAULT '-1' COMMENT '分销员快照等级',
  `order_num` varchar(50) NOT NULL DEFAULT '' COMMENT '平台订单号',
  `distribute_item_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '分销商品id',
  `sid` int(11) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `land_id` int(11) NOT NULL DEFAULT '0' COMMENT '景区id',
  `ticket_id` int(11) NOT NULL DEFAULT '0' COMMENT '票id',
  `reward_status` varchar(20) NOT NULL DEFAULT '' COMMENT '佣金状态',
  `total_reward` int(11) NOT NULL DEFAULT '0' COMMENT '总佣金，单位分',
  `ticket_num` int(11) NOT NULL DEFAULT '0' COMMENT '票数量',
  `ticket_price` int(11) NOT NULL DEFAULT '0' COMMENT '票售价，单位分',
  `ticket_source_price` int(11) NOT NULL DEFAULT '0' COMMENT '票成本价，单位分',
  `order_time` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '下单时间',
  `settle_time` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '结算时间，状态为结算时才能用',
  `mch_id` bigint(20) NOT NULL DEFAULT '-1' COMMENT '商户ID',
  `created_by` varchar(100) NOT NULL DEFAULT '' COMMENT '创建者',
  `created_date` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
  `last_modified_by` varchar(100) NOT NULL DEFAULT '' COMMENT '最后修改者',
  `last_modified_date` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '最后修改时间',
  `sync` tinyint(4) NOT NULL DEFAULT '1' COMMENT '是否已同步',
  `last_sync_time` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '上次同步时间',
  `is_delete` tinyint(4) NOT NULL DEFAULT '0' COMMENT '逻辑删除,0：否，1:是',
  `order_member_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '下单人memberId',
  `write_off_time` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '核销时间',
  `trade_order_num` varchar(50) DEFAULT '' COMMENT '交易订单号',
  PRIMARY KEY (`id`),
  KEY `idx_order_time` (`order_time`),
  KEY `ux_orderNum` (`order_num`)
) ENGINE=InnoDB AUTO_INCREMENT=1803 DEFAULT CHARSET=utf8mb4 COMMENT='分销订单';

-- @table POLAR_auth_center:identity_info
-- @at 2026-11-27 16:19:14
CREATE TABLE `identity_info` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `tag` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '身份标识',
  `name` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '身份名称',
  `valid_time_config` text CHARACTER SET utf8 COLLATE utf8_general_ci COMMENT '有效期配置',
  `create_by` bigint(20) NOT NULL DEFAULT '0' COMMENT '创建人',
  `update_by` bigint(20) NOT NULL DEFAULT '0' COMMENT '更新人',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `description` varchar(255) NOT NULL DEFAULT '' COMMENT '身份描述',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8 COMMENT='身份表';

-- @table POLAR_auth_center:tourist_auth_info
-- @at 2026-11-27 16:20:08
CREATE TABLE `tourist_auth_info` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `tourist_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '游客id',
  `auth_apply_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '认证申请记录id',
  `identity_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '身份id',
  `end_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '有效期',
  `status` tinyint(2) NOT NULL DEFAULT '0' COMMENT '状态 1启用 0禁用',
  `auth_ext_content` text CHARACTER SET utf8 COLLATE utf8_general_ci COMMENT '认证扩展信息',
  `create_by` bigint(20) NOT NULL DEFAULT '0' COMMENT '创建人',
  `update_by` bigint(20) NOT NULL DEFAULT '0' COMMENT '更新人',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_tourist_end_status` (`tourist_id`,`end_time`,`status`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=272 DEFAULT CHARSET=utf8 COMMENT='游客身份认证表';

-- @table POLAR_auth_center:tourist_info
-- @at 2026-11-27 16:19:30
CREATE TABLE `tourist_info` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `certificate_type` tinyint(4) NOT NULL DEFAULT '0' COMMENT '证件类型 1.大陆身份证,2.港澳台居住证 3.港澳台通行证',
  `certificate_no` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '证件号',
  `real_name` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '真实姓名',
  `sex` tinyint(2) NOT NULL DEFAULT '0' COMMENT '性别 0未知 1男 2女',
  `birthday` date NOT NULL DEFAULT '1970-01-01' COMMENT '生日',
  `end_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '有效期',
  `create_by` bigint(20) NOT NULL DEFAULT '0' COMMENT '创建人',
  `update_by` bigint(20) NOT NULL DEFAULT '0' COMMENT '更新人',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_type_no` (`certificate_type`,`certificate_no`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=88 DEFAULT CHARSET=utf8 COMMENT='游客信息表';

-- @table POLAR_base_server:country_region
-- @at 2026-11-27 14:35:36
CREATE TABLE `country_region` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name_zh` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '中文名称',
  `name_en` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '英文名称',
  `full_name_en` varchar(64) NOT NULL DEFAULT '' COMMENT '英文全称',
  `full_name_zh` varchar(64) NOT NULL DEFAULT '' COMMENT '中文全称',
  `is_country` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否为独立国家： 0.否 1.是',
  `alpha_2_code` char(2) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT 'ISO 3166-1标准中的二位字母代码: 美国.US 中国.CN 香港.HK 台湾.TW',
  `alpha_3_code` char(3) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT 'ISO 3166-1标准中的三位字母代码',
  `numeric_3_code` varchar(10) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT 'ISO 3166-1标准中的三位数字代码',
  `sort` int(4) NOT NULL DEFAULT '0' COMMENT '排序',
  `remark` text CHARACTER SET utf8 COLLATE utf8_general_ci COMMENT '备注',
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=311 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='世界国家及行政区信息表';

-- @table POLAR_base_server:global_phone_area
-- @at 2026-11-27 14:35:55
CREATE TABLE `global_phone_area` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `country_id` int(11) NOT NULL DEFAULT '0' COMMENT '国家ID',
  `phone_area_code` varchar(10) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '手机区号: 中国86',
  `sort` int(4) NOT NULL DEFAULT '0' COMMENT '排序',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=230 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='全球手机区号表';

-- @table POLAR_base_server:identity_area_code
-- @at 2026-11-27 14:36:09
CREATE TABLE `identity_area_code` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id',
  `identity_type` int(11) NOT NULL DEFAULT '0' COMMENT '证件类型',
  `identity_code` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '0' COMMENT '证件编码',
  `country_id` int(11) NOT NULL DEFAULT '0' COMMENT '国家ID',
  `region_id` int(11) NOT NULL DEFAULT '0' COMMENT '区域ID',
  `extra` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '扩展信息JSON：省、市、区',
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_iac_identity_code` (`country_id`,`identity_type`,`identity_code`),
  KEY `idx_iac_region_id` (`region_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6786 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='证件号地区码';

-- @table POLAR_base_server:region_area
-- @at 2026-11-27 14:36:23
CREATE TABLE `region_area` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `country_id` int(11) NOT NULL DEFAULT '0' COMMENT '国家ID',
  `level` tinyint(1) NOT NULL DEFAULT '0' COMMENT '区域级别： 1.省/直辖市/特别行政区/州 2.市 3.区/县',
  `parent_code` varchar(10) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '0' COMMENT '上级编码',
  `area_code` varchar(10) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '行政区代码: 北京.110000',
  `area_name` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '区域名称',
  `short_name` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '简称',
  `join_name` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '级联名称',
  `zip_code` mediumint(6) unsigned zerofill NOT NULL DEFAULT '000000' COMMENT '邮政编码',
  `city_code` char(6) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '区号',
  `lng` decimal(10,6) NOT NULL DEFAULT '0.000000' COMMENT '经度',
  `lat` decimal(10,6) NOT NULL DEFAULT '0.000000' COMMENT '纬度',
  `status` int(11) NOT NULL DEFAULT '1' COMMENT '状态：1.正常 2.撤消 3.合并取消',
  `remark` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '备注',
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `create_by` int(10) NOT NULL DEFAULT '0' COMMENT '创建人',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `update_by` int(10) NOT NULL DEFAULT '0' COMMENT '修改人',
  `name_letters` varchar(64) NOT NULL DEFAULT '' COMMENT '区域名称拼音首字母',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ra_area_code` (`area_code`),
  KEY `idx_ra_country_id` (`country_id`),
  KEY `idx_ra_parent_code` (`parent_code`)
) ENGINE=InnoDB AUTO_INCREMENT=9884 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='国家的地区表';

-- @table POLAR_myuu:deposite_config
-- @at 2026-11-27 15:33:32
CREATE TABLE `deposite_config` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `fid` int(10) unsigned NOT NULL COMMENT '操作人ID',
  `amount` int(10) unsigned NOT NULL COMMENT '预存金额',
  `fee` int(10) unsigned NOT NULL COMMENT '单价',
  `type` tinyint(1) NOT NULL COMMENT '1为电子凭证费, 2为短信费',
  `status` tinyint(1) NOT NULL COMMENT '1为失效,2生效',
  `created_at` int(10) unsigned NOT NULL COMMENT '创建时间',
  `updated_at` int(10) unsigned NOT NULL COMMENT '更新时间',
  `account_type` tinyint(1) NOT NULL COMMENT '1为电子凭证费, 2为短信费',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户专项费用表';

-- @table POLAR_myuu:exclusive_account_code
-- @at 2026-11-27 15:33:40
CREATE TABLE `exclusive_account_code` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `user_id` int(10) unsigned NOT NULL COMMENT '用户ID',
  `config_id` int(10) unsigned NOT NULL COMMENT '配置ID',
  `lmoney` int(10) unsigned NOT NULL COMMENT '本次操作后账户余额',
  `total_use` int(10) unsigned NOT NULL COMMENT '累计使用',
  `begin_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '有效开始时间',
  `end_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '有效结束时间',
  `update_time` int(10) unsigned NOT NULL COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `update_time` (`update_time`)
) ENGINE=InnoDB AUTO_INCREMENT=345 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户预存配置电子凭证费';

-- @table POLAR_myuu:exclusive_account_sms
-- @at 2026-11-27 15:33:50
CREATE TABLE `exclusive_account_sms` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `user_id` int(10) unsigned NOT NULL COMMENT '用户ID',
  `config_id` int(10) unsigned NOT NULL COMMENT '配置ID',
  `lmoney` int(10) unsigned NOT NULL COMMENT '本次操作后账户余额',
  `total_use` int(10) unsigned NOT NULL COMMENT '累计使用',
  `update_time` int(10) unsigned NOT NULL COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `update_time` (`update_time`)
) ENGINE=InnoDB AUTO_INCREMENT=116 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户预存配置短信费';

-- @table POLAR_myuu:order_aids_split
-- @at 2026-11-27 15:35:07
CREATE TABLE `order_aids_split` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `orderid` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '订单号',
  `buyerid` int(10) NOT NULL COMMENT '购买用户ID',
  `sellerid` int(10) NOT NULL COMMENT '供应商ID',
  `level` tinyint(2) NOT NULL DEFAULT '0' COMMENT '所处的级别：1=第一级，0=既是1级也是末级，-1=最末级，2=中间级别',
  `pmode` int(1) DEFAULT '0' COMMENT '该级别的支付方式',
  `cost_money` decimal(12,0) NOT NULL DEFAULT '0' COMMENT '成本价（分为单位）',
  `sale_money` decimal(12,0) NOT NULL DEFAULT '0' COMMENT '销售价（分为单位）',
  `member_relationship` tinyint(1) NOT NULL DEFAULT '0' COMMENT '订单会员关系 0:平台关系,1:资源中心关系',
  `order_time` int(11) NOT NULL DEFAULT '0' COMMENT '逻辑下单时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '订单更新时间',
  `order_month` tinyint(2) NOT NULL DEFAULT '0' COMMENT '逻辑下单月份',
  `apply_did` int(10) NOT NULL DEFAULT '0' COMMENT '原始供应商ID',
  `sync_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否同步标示 1:同步,0:无需同步',
  PRIMARY KEY (`id`),
  UNIQUE KEY `key_id` (`orderid`,`buyerid`,`sellerid`),
  KEY `b_id` (`buyerid`),
  KEY `idx_sellerid_memberrrelationship_ordertime` (`sellerid`,`member_relationship`,`order_time`),
  KEY `idx_sellerid_order_time` (`sellerid`,`order_time`),
  KEY `idx_update_time` (`update_time`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1250264406 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='订单每级买入卖出者';

-- @table POLAR_myuu:order_user_info
-- @at 2026-11-27 18:10:27
CREATE TABLE `order_user_info` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ordernum` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '订单号',
  `ordername` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '取票人姓名',
  `ordertel` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '取票人电话',
  `personid` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '取票人身份信息',
  `voucher_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '身份信息类型:1=身份证, 2=护照, 3=军官证, 4=回乡证, 5=台胞证, 99=其他',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `province_code` varchar(10) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '省份',
  `city_code` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '城市',
  `town_code` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '乡镇',
  `address` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '具体地址',
  `apply_did` int(10) NOT NULL DEFAULT '0' COMMENT '原始供应商ID',
  `sync_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否同步标示 1:同步,0:无需同步',
  `mobile_area` varchar(10) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '手机区号',
  `mobile_region` varchar(10) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '手机区号的区域代码',
  PRIMARY KEY (`id`),
  KEY `idx_create_time` (`create_time`),
  KEY `idx_ordertel` (`ordertel`),
  KEY `idx_ordernum` (`ordernum`),
  KEY `idx_personid` (`personid`)
) ENGINE=InnoDB AUTO_INCREMENT=1035621309 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='订单取票人信息表';

-- @table POLAR_myuu:pft_account_book_platform_in
-- @at 2026-11-27 15:35:29
CREATE TABLE `pft_account_book_platform_in` (
  `id` bigint(14) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `account_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '账户ID',
  `subject_code` mediumint(6) unsigned NOT NULL DEFAULT '0' COMMENT '账本科目编码',
  `subject_type` tinyint(2) NOT NULL DEFAULT '0' COMMENT '账本科目类型',
  `template_code` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '账本模板ID',
  `balance_money` bigint(12) NOT NULL DEFAULT '0' COMMENT '账本余额',
  `frozen_money` bigint(12) NOT NULL DEFAULT '0' COMMENT '冻结金额',
  `settle_mark` mediumint(8) NOT NULL DEFAULT '0' COMMENT '账期标识',
  `settle_id` int(10) NOT NULL DEFAULT '0' COMMENT '账期配置ID',
  `settle_income_money` bigint(12) NOT NULL DEFAULT '0' COMMENT '账期内收入金额',
  `settle_payout_money` bigint(12) NOT NULL DEFAULT '0' COMMENT '账期内支出金额',
  `trade_account_id` int(10) NOT NULL DEFAULT '0' COMMENT '交易方账户ID',
  `trade_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '交易类型：0=普通，1=授信，2=押金 3=积分',
  `trade_limit_money` bigint(12) NOT NULL DEFAULT '0' COMMENT '交易限定金额',
  `trade_limit_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '交易限制金额类型：0=不使用限额，1=按月，2=按日，3=总限制',
  `trade_limit_total` bigint(12) NOT NULL DEFAULT '0' COMMENT '累计使用限额',
  `last_trade_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '上一条交易流水ID',
  `effect_time` datetime NOT NULL DEFAULT '1970-01-01 00:00:00' COMMENT '生效时间',
  `dead_time` datetime NOT NULL DEFAULT '2099-12-31 23:59:59' COMMENT '失效时间',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '账本状态：1=正常，2=禁用，3=销户',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '最后更新时间',
  `total_money` bigint(20) NOT NULL DEFAULT '0' COMMENT '总金额',
  PRIMARY KEY (`id`,`account_id`),
  KEY `idx_account_id_subject_id_template_code_status_trade_account_id` (`account_id`,`subject_code`,`template_code`,`status`,`trade_account_id`),
  KEY `idx_trade_account_id_subject_code` (`trade_account_id`,`subject_code`),
  KEY `idx_subject_code_balance_money` (`subject_code`,`balance_money`)
) ENGINE=InnoDB AUTO_INCREMENT=1830624322304 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='账户账本表-平台内'
/*!50100 PARTITION BY HASH (`account_id`)
PARTITIONS 16 */;

-- @table POLAR_myuu:pft_account_book_subject
-- @at 2026-11-27 15:35:39
CREATE TABLE `pft_account_book_subject` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `subject_code` mediumint(6) unsigned NOT NULL DEFAULT '0' COMMENT '账本科目编码',
  `subject_name` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '账本科目名称',
  `type` tinyint(2) NOT NULL DEFAULT '1' COMMENT '账本科目类型：1=平台余额类，2=授信类，3=现金类，4=第三方支付类，5=押金类，6=积分类，7=充值类，8=专款预存类',
  `unit` varchar(8) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '单位',
  `can_withdraw` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否可提现：0=不行，1=可以',
  `can_invoice` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否可打印发票：0=不行，1=可以',
  `can_integral` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否可计算积分：0=不行，1=可以',
  `is_default` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否默认创建：0=不是，1=是',
  `priority` tinyint(1) NOT NULL DEFAULT '0' COMMENT '优先级：越大优先级越高',
  `repeatable` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否可以多条记录：0=不能 1=可以',
  `refund_expires` int(4) NOT NULL DEFAULT '0' COMMENT '退款期限:小时为单位',
  `refund_limit` int(4) NOT NULL DEFAULT '0' COMMENT '退款上限',
  `remaining_limit` bigint(12) NOT NULL DEFAULT '0' COMMENT '余额上限',
  `third_party` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否为第三方支付',
  `trade_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '交易类型：0=普通，1=授信，2=押金 3=积分',
  `ext` varchar(512) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '扩展规则',
  `remark` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '备注',
  `add_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_code` (`subject_code`)
) ENGINE=InnoDB AUTO_INCREMENT=142 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='账本科目';

-- @table POLAR_myuu:pft_account_exclusive_config
-- @at 2026-11-27 15:35:54
CREATE TABLE `pft_account_exclusive_config` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id',
  `nums` int(10) NOT NULL DEFAULT '0' COMMENT '数量',
  `min_num` int(10) NOT NULL DEFAULT '0' COMMENT '最小数量',
  `max_num` int(10) NOT NULL DEFAULT '0' COMMENT '最大数量',
  `price` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '原价总-分',
  `unit_price` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '单价-分',
  `discount` int(10) NOT NULL DEFAULT '100' COMMENT '折扣  100 是原价',
  `valid_period` int(10) NOT NULL DEFAULT '0' COMMENT '有效期-月',
  `purchase_type` tinyint(2) NOT NULL DEFAULT '0' COMMENT '0 固定 1 阶梯',
  `subject_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '账本科目编码',
  `stat` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态:1=有效,0=无效,2=删除',
  `create_date` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_date` int(10) NOT NULL DEFAULT '0' COMMENT '修改时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=164 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='专项配置表';

-- @table POLAR_myuu:pft_account_exclusive_config_history
-- @at 2026-11-27 15:36:04
CREATE TABLE `pft_account_exclusive_config_history` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id',
  `exclusive_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'id',
  `version_code` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '配置版本号  从0开始',
  `nums` int(10) NOT NULL DEFAULT '0' COMMENT '数量',
  `min_num` int(10) NOT NULL DEFAULT '0' COMMENT '最小数量',
  `max_num` int(10) NOT NULL DEFAULT '0' COMMENT '最大数量',
  `price` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '原价总-分',
  `unit_price` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '单价-分',
  `discount` int(10) NOT NULL DEFAULT '100' COMMENT '折扣  100 是原价',
  `valid_period` int(10) NOT NULL DEFAULT '0' COMMENT '有效期-月',
  `purchase_type` tinyint(2) NOT NULL DEFAULT '0' COMMENT '0 固定 1 阶梯',
  `subject_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '账本科目编码',
  `create_date` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_exclusive_id` (`exclusive_id`)
) ENGINE=InnoDB AUTO_INCREMENT=194 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='专项配置历史表';

-- @table POLAR_myuu:pft_account_exclusive_order_record
-- @at 2026-11-27 15:36:52
CREATE TABLE `pft_account_exclusive_order_record` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id',
  `orderid` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '订单号',
  `trade_no` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '外部交易流水',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '商家ID',
  `account_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '账户ID',
  `subject_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '账本科目编码',
  `memo` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '备注',
  `trade_num` int(11) NOT NULL DEFAULT '0' COMMENT '交易数量',
  `remain_num` int(10) NOT NULL DEFAULT '0' COMMENT '本次结束后剩余总数',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '下单人',
  `trade_time` int(10) NOT NULL DEFAULT '0' COMMENT '交易时间-逻辑',
  `template_item_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '模板费用项编码',
  `channel` tinyint(2) NOT NULL DEFAULT '0' COMMENT '交易请求来源',
  `insert_time` int(10) NOT NULL DEFAULT '0' COMMENT '插入时间-系统时间',
  `recmonth` int(8) NOT NULL DEFAULT '0' COMMENT '交易月份，用来分区',
  `outter_trade_no` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '第三方交易流水',
  `h_config_id` int(10) NOT NULL DEFAULT '0' COMMENT '历史专项费用配置id 关联exclusive_config_history主键',
  PRIMARY KEY (`id`),
  KEY `idx_trade_no` (`trade_no`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_orderid` (`orderid`),
  KEY `idx_trade_time` (`trade_time`),
  KEY `idx_fid_time` (`fid`,`trade_time`)
) ENGINE=InnoDB AUTO_INCREMENT=65037065 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户使用 记录表';

-- @table POLAR_myuu:pft_account_exclusive_purchase_record
-- @at 2026-11-27 15:37:12
CREATE TABLE `pft_account_exclusive_purchase_record` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id',
  `orderid` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '订单号',
  `trade_no` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '外部交易流水',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '商家ID',
  `dprice` int(10) NOT NULL DEFAULT '0' COMMENT '订单价格',
  `exclusive_id` int(10) NOT NULL DEFAULT '0' COMMENT '专款配置ID ',
  `version_code` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '配置版本号  从0开始',
  `remain_num` int(10) NOT NULL DEFAULT '0' COMMENT '本次结束后剩余总数',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '下单人',
  `order_time` int(10) NOT NULL DEFAULT '0' COMMENT '下单时间',
  `purchase_type` tinyint(2) NOT NULL DEFAULT '0' COMMENT '0 固定 1 阶梯',
  `subject_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '账本科目编码',
  PRIMARY KEY (`id`),
  KEY `idx_trade_no` (`trade_no`),
  KEY `idx_fid` (`fid`),
  KEY `idx_orderid` (`orderid`),
  KEY `idx_exclusive_id` (`exclusive_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2134 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='专项购买记录表';

-- @table POLAR_myuu:pft_account_exclusive_remain
-- @at 2026-11-27 15:37:21
CREATE TABLE `pft_account_exclusive_remain` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '账号',
  `remain_num` int(10) NOT NULL DEFAULT '0' COMMENT '剩余数',
  `total_num` int(10) NOT NULL DEFAULT '0' COMMENT '累计数',
  `total_money` int(10) NOT NULL DEFAULT '0' COMMENT '累计预存余额-分',
  `subject_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '账本科目编码',
  `create_date` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_date` int(10) NOT NULL DEFAULT '0' COMMENT '修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_fid` (`fid`)
) ENGINE=InnoDB AUTO_INCREMENT=1134 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='专项用户余额表';

-- @table POLAR_myuu:pft_account_template_item_list
-- @at 2026-11-27 15:37:37
CREATE TABLE `pft_account_template_item_list` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `item_code` mediumint(6) unsigned NOT NULL DEFAULT '0' COMMENT '费用项编码',
  `item_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '费用项类型 ',
  `item_name` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '费用项名称',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_item_code` (`item_code`)
) ENGINE=InnoDB AUTO_INCREMENT=143 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='账本专项模板费用项列表';

-- @table POLAR_myuu:pft_auto_withdraw_setting
-- @at 2026-11-27 15:37:47
CREATE TABLE `pft_auto_withdraw_setting` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `fid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '客户ID',
  `mode` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '自动清分模式，1=日结，2=周结，3=月结',
  `account_info` varchar(5000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '账号的json信息串 {"bank_name":"","bank_ins_code":"","bank_account":"","acc_type":"","account_name":""}',
  `freeze_type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '资金冻结类型，1=冻结未使用的总额，2=按比例冻结',
  `freeze_data` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '资金冻结详情，比例或是具体的金额 - {"type":"1/2","value":"30"}',
  `service_fee` decimal(4,2) NOT NULL DEFAULT '0.00' COMMENT '提现的手续费率 - 5%',
  `cut_way` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '手续费扣除方式：0=提现金额中扣除，1=账户余额扣除',
  `close_date` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '结算日期，日结（几点），月结（几号），周结（周几）',
  `close_time` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '结算时间，0-23点',
  `transfer_date` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '转账日期，日结（几点），月结（几号），周结（周几）',
  `transfer_time` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '转账时间，0-23点',
  `cycle_mark` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '上次更新的周期标识，日（20160612）-月（20160104）-周（20160238）',
  `status` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '配置的状态，0=无效，1=有效',
  `update_uid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '配置修改用户',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '配置更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=276 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='客户账户余额自动清分配置表';

-- @table POLAR_myuu:pft_common_dict
-- @at 2026-11-27 15:37:58
CREATE TABLE `pft_common_dict` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '标签名',
  `code` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '数据值',
  `dict_type` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '类型 city,channel',
  `description` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '描述',
  `parent_id` int(10) NOT NULL DEFAULT '0' COMMENT '父级编号',
  `create_date` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '更新者',
  `update_date` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `del_flag` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态:1=正常,0=删除',
  PRIMARY KEY (`id`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_code` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=69 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='通用字典表';

-- @table POLAR_myuu:pft_customer_certification
-- @at 2026-11-27 15:39:46
CREATE TABLE `pft_customer_certification` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `customer_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '客户ID',
  `bsn_les` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '营业执照',
  `opt_les` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '经营许可证',
  `auth_les` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '资源方授权书',
  `org_les` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '组织机构代码证',
  `tax_les` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '税务登记证',
  `id_card` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '身份证照片',
  `id_card_hand` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '手持身份证正面',
  `id_card_B` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '手持身份证反面',
  `certi_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '会员认证状态:0=未认证,1=审核中,2=—已认证（审核通过）,3=拒绝',
  `ref_reason` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '审核不通过原因',
  `apply_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '申请认证时间',
  `pass_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '审核通过时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_customer_id` (`customer_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1988 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户资质认证数据';

-- @table POLAR_myuu:pft_management_land
-- @at 2026-11-27 15:39:57
CREATE TABLE `pft_management_land` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `title` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '名称',
  `letters` varchar(25) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT 'A' COMMENT '首字母',
  `jtype` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '级别',
  `mtype` char(1) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT 'A' COMMENT '景区类型：A景区C酒店',
  `municipality` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '城市',
  `province` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '省份',
  `address` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '地址',
  `lng_lat_pos` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '经纬度',
  `topic` varchar(500) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '旅游主题',
  `selling_point` varchar(512) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '卖点',
  `state` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '主体关联状态 0：未关联 1：已关联',
  `operator_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '操作人ID',
  `create_time` datetime NOT NULL DEFAULT '1970-01-01 00:00:00' COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT '1970-01-01 00:00:00' COMMENT '更新时间',
  `oversea` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '境内外 0：境内 1：境外',
  `apply_did` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '景区供应商',
  `apply_time` datetime NOT NULL DEFAULT '1970-01-01 00:00:00' COMMENT '景区供应商关联时间',
  `is_del` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否删除 0：否 1：是',
  `tel` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '联系电话',
  `website` varchar(500) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '官网',
  `runtime` varchar(500) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '开放时间',
  `county` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '区/县',
  `is_parent` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否父景区 0否 1是',
  `parent_id` int(11) NOT NULL DEFAULT '0' COMMENT '父景区id',
  `autonavi_id` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '高德id',
  `ctrip_id` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '携程id',
  `poi_type_name` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '景区类型名称',
  `region_province_code` varchar(10) NOT NULL DEFAULT '' COMMENT '新地区省份编码',
  `region_city_code` varchar(10) NOT NULL DEFAULT '' COMMENT '新地区城市编码',
  `region_county_code` varchar(10) NOT NULL DEFAULT '' COMMENT '新地区区县编码',
  PRIMARY KEY (`id`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_apply_did` (`apply_did`)
) ENGINE=InnoDB AUTO_INCREMENT=435996 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='业态景区表';

-- @table POLAR_myuu:pft_management_resource
-- @at 2026-11-27 15:40:07
CREATE TABLE `pft_management_resource` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `mt_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '业态ID',
  `mtype` char(1) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '业态类型',
  `land_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '景区ID',
  `create_time` datetime NOT NULL DEFAULT '1970-01-01 00:00:00' COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT '1970-01-01 00:00:00' COMMENT '更新时间',
  `color` int(10) NOT NULL DEFAULT '0' COMMENT '颜色 0.管理端（绿） 1.商家段（橙色）',
  PRIMARY KEY (`id`),
  KEY `idx_mt_id` (`mt_id`),
  KEY `idx_land_id` (`land_id`)
) ENGINE=InnoDB AUTO_INCREMENT=197440 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='业态资源关联表';

-- @table POLAR_myuu:pft_member
-- @at 2026-11-27 16:16:49
CREATE TABLE `pft_member` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `customer_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '客户id',
  `account_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '用户所使用的支付账户ID',
  `dtype` tinyint(1) NOT NULL COMMENT '会员类型:0=供应商,1=分销商,2=直接供应方,3=合并终端后的资源方,5=普通用户,6=员工,7=集团帐号,9=平台帐号',
  `account` varchar(32) NOT NULL COMMENT '登录帐号供应商:100000~199999=分销商:200000~599999 直接供应方:600000~999999 普通用户:手机号 平台帐号:admin 员工帐号:4位~12位英文或数字 集团帐号1000~9999',
  `dname` varchar(100) NOT NULL COMMENT '用户名称',
  `letters` varchar(32) NOT NULL DEFAULT '' COMMENT '姓名首字母',
  `status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0正常1禁用2删除3未审核',
  `mobile` char(11) NOT NULL DEFAULT '' COMMENT '联系用手机号码',
  `creattime` datetime DEFAULT '0000-00-00 00:00:00' COMMENT '帐号创建时间',
  `lasttime` datetime DEFAULT '0000-00-00 00:00:00' COMMENT '最近登录时间',
  `headphoto` varchar(255) NOT NULL DEFAULT '' COMMENT '头像保存路径',
  `cname` varchar(100) NOT NULL DEFAULT '' COMMENT '联系人姓名',
  `ctel` varchar(50) NOT NULL DEFAULT '' COMMENT '联系人电话',
  `endtime` datetime DEFAULT '0000-00-00 00:00:00' COMMENT '帐号终止时间默认无限',
  `dcode` char(6) NOT NULL DEFAULT '' COMMENT '唯一的接口编码',
  `dcodeURL` varchar(255) NOT NULL DEFAULT '' COMMENT '回调地址',
  `alipay` varchar(120) NOT NULL DEFAULT '' COMMENT '支付宝帐号 供应商、分销商不能为空 必须为E-mail格式',
  `bank_account1` varchar(120) NOT NULL DEFAULT '' COMMENT '预留的银行帐号1',
  `bank_account2` varchar(120) NOT NULL DEFAULT '' COMMENT '预留的银行帐号2',
  `fee_platform` smallint(5) NOT NULL DEFAULT '0' COMMENT '平台使用费 单位分',
  `fee_bank` decimal(5,2) NOT NULL DEFAULT '5.00' COMMENT '第三方支付费用',
  `fee_sms` smallint(5) NOT NULL DEFAULT '10' COMMENT '短信每条收费 单位分',
  `fee_code` smallint(5) NOT NULL DEFAULT '100' COMMENT '凭证费费用',
  `member_auth` varchar(20000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '会员权限',
  `fee_pay_way` tinyint(1) NOT NULL DEFAULT '0' COMMENT '付凭证费人员:0=供应商,1=分销商',
  `group_id` smallint(5) unsigned NOT NULL DEFAULT '1' COMMENT '会员分组,由admin配置;默认为1票付通组;2测试组;3点餐组;4云顶;5鼓浪屿；6签约账户',
  `salesID` int(10) unsigned NOT NULL DEFAULT '0',
  `kefuID` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '客服服务人员ID',
  `reg_source` tinyint(2) NOT NULL DEFAULT '1' COMMENT '注册来源，1=pc端，2=微平台，3=微商城，4=微信小程序，5=支付宝小程序，6=e福州，7=终端，8=招行，9=mini云小程序，10=微平台小程序',
  `grouping_id` smallint(5) unsigned NOT NULL DEFAULT '1' COMMENT '用户分组标签 默认为1 未分组',
  `create_by` varchar(20) NOT NULL DEFAULT '' COMMENT '创建者',
  `update_by` varchar(20) NOT NULL DEFAULT '' COMMENT '修改者',
  `create_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `account` (`account`) USING BTREE,
  KEY `idx_mobile` (`mobile`) USING BTREE,
  KEY `idx_dname` (`dname`) USING BTREE,
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_dtype` (`dtype`),
  FULLTEXT KEY `ft_dname` (`dname`) /*!50100 WITH PARSER `ngram` */ 
) ENGINE=InnoDB AUTO_INCREMENT=10221602 DEFAULT CHARSET=utf8 COMMENT='会员角色表';

-- @table POLAR_myuu:pft_member_extinfo
-- @at 2026-11-27 15:40:43
CREATE TABLE `pft_member_extinfo` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `fid` int(10) NOT NULL,
  `position` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `com_name` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `province` smallint(2) DEFAULT NULL,
  `city` int(10) NOT NULL DEFAULT '0' COMMENT '公司所在地,城市',
  `country` bigint(20) DEFAULT '0' COMMENT '公司所在地,区县',
  `corp_kind` tinyint(1) DEFAULT '2' COMMENT '公司类型0：酒店、1：景区、2：旅行社、3：加盟门店、4：电商、5：淘宝/天猫、6、团购网、7、个人，8、其他',
  `fax` varchar(16) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `website` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `business` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `short_company_name` varchar(30) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `cinfos` varchar(1500) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `coop` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `add_saler_type` tinyint(1) NOT NULL DEFAULT '0',
  `early_warning` decimal(12,0) NOT NULL DEFAULT '0',
  `jiutian_auth` tinyint(1) NOT NULL DEFAULT '0',
  `refund_back` tinyint(1) NOT NULL DEFAULT '0',
  `terminal_type` tinyint(1) NOT NULL DEFAULT '0',
  `other_les` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `birthday` smallint(4) NOT NULL DEFAULT '0' COMMENT ' 生日',
  `protocol_start` date NOT NULL DEFAULT '0000-00-00',
  `protocol_end` date NOT NULL DEFAULT '0000-00-00',
  `protocol_main` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `protocol_meal` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '协议套餐',
  `contract_num` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '合同编号',
  `contract_model` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '合作模式:0=无,1=套餐,2=票务,3=订单',
  `contract_depart` tinyint(3) NOT NULL DEFAULT '0' COMMENT '签约合同所属 1:市场部 2:项目部',
  `is_pay` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否回款:0=否,1=是',
  `finance_name` varchar(60) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '账务账户名称  用于比对财务账户的名称',
  `distribution_check` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '被添加为分销商是否需要审核：0=不要，1=要',
  `hotline` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '热线电话',
  `cooperate_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT ' 凭证费订单模式类型 1:1元 2:预存',
  `format_type` smallint(5) NOT NULL DEFAULT '0' COMMENT '公司业态',
  `types` smallint(5) NOT NULL DEFAULT '0' COMMENT '类型/级别',
  `ext` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '扩展规则{json}',
  `create_by` int(10) NOT NULL DEFAULT '0' COMMENT '创建人ID',
  `update_by` int(10) NOT NULL DEFAULT '0' COMMENT '修改者',
  `create_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `contract_subject` tinyint(4) NOT NULL DEFAULT '1' COMMENT '合作主体：1：票付通，2：票易通',
  `remark` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '备注',
  `region_province_code` varchar(10) NOT NULL DEFAULT '' COMMENT '新地区省份编码',
  `region_city_code` varchar(10) NOT NULL DEFAULT '' COMMENT '新地区城市编码',
  `region_county_code` varchar(10) NOT NULL DEFAULT '' COMMENT '新地区区县编码',
  PRIMARY KEY (`id`),
  KEY `idx_com_name` (`com_name`),
  KEY `pft_member_extinfo_update_at_index` (`update_at`),
  KEY `idx_fid` (`fid`),
  FULLTEXT KEY `ft_com_name` (`com_name`)
) ENGINE=InnoDB AUTO_INCREMENT=38282733 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='会员详细资料表';

-- @table POLAR_myuu:pft_member_relationship
-- @at 2026-11-27 16:16:58
CREATE TABLE `pft_member_relationship` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) NOT NULL COMMENT '父ID',
  `son_id` int(10) NOT NULL COMMENT '子ID',
  `son_id_type` tinyint(1) NOT NULL COMMENT '0分销商1资源方2员工3供应商（父ID为集团帐号情况下）',
  `ship_type` tinyint(1) NOT NULL COMMENT '关系类型:0供销关系1从属关系2平级关系3推荐关系',
  `status` tinyint(1) NOT NULL COMMENT '状态:0=正常,1=断联',
  `rectime` datetime DEFAULT NULL COMMENT '记录生成时间',
  `cuttime` datetime DEFAULT NULL COMMENT '断联时间',
  `restoretime` datetime DEFAULT NULL COMMENT '断联恢复时间',
  `price_group_id` int(10) NOT NULL DEFAULT '0' COMMENT '分组ID',
  `remark` varchar(255) NOT NULL DEFAULT '' COMMENT '备注信息',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_sonid` (`son_id`) USING BTREE,
  KEY `uniq_parent_id_son_id_ship_type` (`parent_id`,`son_id`,`ship_type`),
  KEY `idx_group_id` (`price_group_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1596042 DEFAULT CHARSET=utf8 COMMENT='会员关系表';

-- @table POLAR_myuu:pft_order_tourist_track
-- @at 2026-11-27 15:41:03
CREATE TABLE `pft_order_tourist_track` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `ordernum` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '0' COMMENT '订单号',
  `idx` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '订单游客表序号',
  `track_action` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '变更状态:1=入园,2=取消,3=过期,4=验证',
  `tid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '票类ID',
  `tnum` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '变更次数',
  `left_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '剩余可用次数',
  `source` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '操作来源:0=终端机,1=软终端,2=自助机,3=外部通知更新,4=云票务,5=云闸机,6=PC-支付宝,7=手机支付宝,8=支付宝刷卡,9=支付宝扫码,10=微信支付,11=微信刷卡,12=微信扫码,13=PC-银联,14=手机-银联,15=PC-环迅,16=内部接口,17=外部接口,18=undefined,19=自运行服务,20=安卓智能终端机,21=验证服务器,22=微信商城,23=二级店铺,24=OTA,25=会员购票,26=年卡特权,27=平安银行,28=内部接口,29=民生乐收银,30=一卡通',
  `terminal` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '终端号',
  `branch_terminal` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '分终端号',
  `saler_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '现在存储站点ID',
  `insert_time` int(11) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `oper_member` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '操作用户',
  `msg` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '备注信息',
  `ext_content` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '{}' COMMENT '验证或是取消过程中的一些数据',
  `order_time` int(11) NOT NULL DEFAULT '0' COMMENT '逻辑下单时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '订单更新时间',
  `order_month` tinyint(2) NOT NULL DEFAULT '0' COMMENT '逻辑下单月份',
  `apply_did` int(10) NOT NULL DEFAULT '0' COMMENT '原始供应商ID',
  `sync_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否同步标示 1:同步,0:无需同步',
  PRIMARY KEY (`id`),
  KEY `idx_salerid` (`saler_id`),
  KEY `idx_oper_member` (`oper_member`),
  KEY `insert_time_apply_did_idx` (`insert_time`,`apply_did`),
  KEY `idx_ordernum` (`ordernum`)
) ENGINE=InnoDB AUTO_INCREMENT=3542880737 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='门票订单变更追踪表';

-- @table POLAR_myuu:pft_order_track
-- @at 2026-11-27 16:17:10
CREATE TABLE `pft_order_track` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `ordernum` varchar(20) NOT NULL COMMENT '订单号',
  `action` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '变更状态:1=0=下单,1=修改,2=取消,3=出票,4=支付,验证,撤销,7=撤改,8=重打印,9=离线订单下载,10=处理退票申请,11=提交退票申请,12=过期,13=同意退票申请,14=拒绝退票申请,15=核销,16=订单加票,17=完结',
  `tid` int(10) unsigned NOT NULL COMMENT '票类ID',
  `tnum` int(10) unsigned NOT NULL COMMENT '变更票数',
  `left_num` int(10) unsigned NOT NULL COMMENT '剩余票数',
  `source` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '操作来源:0=终端机,1=软终端,2=自助机,3=外部通知更新,4=云票务,5=云闸机,6=PC-支付宝,7=手机支付宝,8=支付宝刷卡,9=支付宝扫码,10=微信支付,11=微信刷卡,12=微信扫码,13=PC-银联,14=手机-银联,15=PC-环迅,16=内部接口,17=外部接口,18=undefined,19=自运行服务,20=安卓智能终端机,21=验证服务器,22=微信商城,23=二级店铺,24=OTA,25=会员购票,26=年卡特权,27=平安银行,28=内部接口,29=民生乐收银,30=一卡通',
  `terminal` int(11) unsigned NOT NULL COMMENT '共享终端号',
  `branchTerminal` int(11) unsigned NOT NULL COMMENT '分终端号',
  `SalerID` int(11) unsigned NOT NULL COMMENT '现在存储站点ID',
  `id_card` varchar(20) NOT NULL COMMENT '身份证',
  `insertTime` datetime NOT NULL COMMENT '添加时间',
  `oper_member` int(10) unsigned NOT NULL COMMENT '操作用户',
  `msg` varchar(255) NOT NULL COMMENT '备注信息',
  `ext_content` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '{}' COMMENT '验证或是取消过程中的一些数据',
  `order_time` int(11) NOT NULL DEFAULT '0' COMMENT '逻辑下单时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '订单更新时间',
  `order_month` tinyint(2) NOT NULL DEFAULT '0' COMMENT '逻辑下单月份',
  `apply_did` int(10) NOT NULL DEFAULT '0' COMMENT '原始供应商ID',
  `sync_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否同步标示 1:同步,0:无需同步',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_ordernum` (`ordernum`) USING BTREE,
  KEY `idx_salerid` (`SalerID`) USING BTREE,
  KEY `idx_insertTime` (`insertTime`) USING BTREE,
  KEY `idx_oper_member` (`oper_member`),
  KEY `idx_pot_time_tid` (`insertTime`,`tid`,`action`),
  KEY `idx_inserttime_oper_member` (`insertTime`,`id`,`oper_member`,`action`,`source`),
  KEY `idx_member_time_id` (`oper_member`,`insertTime` DESC,`id` DESC),
  KEY `idx_tid_time_id` (`tid`,`insertTime` DESC,`id` DESC)
) ENGINE=InnoDB AUTO_INCREMENT=67039984 DEFAULT CHARSET=utf8 COMMENT='订单变更追踪表';

-- @table POLAR_myuu:pft_package_tickets
-- @at 2026-11-27 15:41:52
CREATE TABLE `pft_package_tickets` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_tid` int(10) NOT NULL COMMENT '所属票类ID',
  `lid` int(10) NOT NULL COMMENT '套票包含的景区id',
  `tid` int(10) NOT NULL COMMENT '套票包含的门票id',
  `pid` int(10) NOT NULL COMMENT '套票包含的产品id',
  `aid` int(10) NOT NULL COMMENT '套票子票所属的上级供应商id',
  `num` tinyint(1) unsigned NOT NULL COMMENT '套票子票限定的购买数量',
  `cost_price` int(10) NOT NULL DEFAULT '0' COMMENT '打包成本价',
  `property_type` tinyint(3) NOT NULL DEFAULT '0' COMMENT '属性类型：1往返票',
  `property_value` tinyint(3) NOT NULL DEFAULT '0' COMMENT 'property_type=1时：0非往返票，1去程票，2返程票；',
  `payload` json DEFAULT NULL COMMENT '扩展信息，包含往返码头start_pier_id、end_pier_id等',
  PRIMARY KEY (`id`),
  KEY `idx_parent_tid` (`parent_tid`),
  KEY `idx_tid` (`tid`),
  KEY `idx_property_type` (`property_type`),
  KEY `idx_lid` (`lid`)
) ENGINE=InnoDB AUTO_INCREMENT=338191 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='套票包含的子票数据';

-- @table POLAR_myuu:pft_sms_journal
-- @at 2026-11-27 15:42:02
CREATE TABLE `pft_sms_journal` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `aid` int(10) NOT NULL COMMENT '平台供应商ID',
  `ordernum` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '订单号',
  `mobile` char(11) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '电话号码',
  `wordscnt` tinyint(1) unsigned NOT NULL COMMENT '字数统计',
  `msgcnt` tinyint(1) unsigned NOT NULL COMMENT '条数统计',
  `smstxt` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '短信内容',
  `tob` enum('N','Y') CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '是否为供应商短信Y:供应商，N:分销商',
  `platformid` tinyint(1) NOT NULL COMMENT '短信发送平台ID',
  `send_time` int(10) NOT NULL DEFAULT '0' COMMENT '最后发送时间',
  `platform_sid` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '短信服务商返回的短信唯一标识符',
  `api_code` smallint(4) NOT NULL COMMENT 'API接口调用发送状态',
  `api_errmsg` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT 'API错误信息',
  `report_time` int(10) NOT NULL DEFAULT '0' COMMENT '通知时间',
  `report_code` smallint(4) NOT NULL COMMENT '客户接收状态',
  `report_errmsg` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '客户接收错误信息',
  `is_resend` tinyint(4) NOT NULL DEFAULT '0' COMMENT '是否为重发短信 0否 1是',
  `channel` tinyint(3) unsigned NOT NULL DEFAULT '1' COMMENT '发送渠道 1=平台 2=消息中心',
  PRIMARY KEY (`id`),
  KEY `idx_aid` (`aid`),
  KEY `idx_api_code` (`api_code`),
  KEY `idx_api_resend` (`is_resend`),
  KEY `idx_mobile` (`mobile`),
  KEY `idx_send_time` (`send_time`),
  KEY `idx_ordernum` (`ordernum`),
  KEY `idx_platform_sid` (`platform_sid`),
  KEY `idx_aid_sendtime` (`aid`,`send_time`)
) ENGINE=InnoDB AUTO_INCREMENT=164914302 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='订单短信发送记录';

-- @table POLAR_myuu:pft_special_ticket
-- @at 2026-11-27 15:43:18
CREATE TABLE `pft_special_ticket` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `ticket_id` int(6) NOT NULL COMMENT '门票id',
  `special_config` text CHARACTER SET utf8 COLLATE utf8_general_ci COMMENT '特殊配置信息',
  PRIMARY KEY (`id`),
  KEY `idx_ticket_id` (`ticket_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5376067 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='特殊票属性信息存表';

-- @table POLAR_myuu:pft_special_user_config
-- @at 2026-11-27 15:43:27
CREATE TABLE `pft_special_user_config` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `tag` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '特殊人群标签',
  `tag_desc` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '特殊人群标签说明',
  `type` tinyint(4) NOT NULL DEFAULT '0' COMMENT '特殊人群分类 1年龄 2身份 3地域',
  `rule_content` varchar(2000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '规则内容',
  `valid_time` varchar(3000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '有效期(json格式)',
  `data_source_desc` varchar(2000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '数据源说明',
  `status` tinyint(4) NOT NULL DEFAULT '1' COMMENT '状态 1有效 0无效',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  `create_by` bigint(20) NOT NULL DEFAULT '0' COMMENT '创建人',
  `update_by` bigint(20) NOT NULL DEFAULT '0' COMMENT '更新人',
  `data_scope` varchar(1024) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '数据范围',
  `business_type` tinyint(2) NOT NULL DEFAULT '0' COMMENT '业务类型 1实名  2特殊身份',
  `certificate_type` tinyint(4) NOT NULL DEFAULT '0' COMMENT '证件类型',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='特殊人群配置表';

-- @table POLAR_myuu:pft_supplier_extinfo
-- @at 2026-11-27 15:44:29
CREATE TABLE `pft_supplier_extinfo` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `fid` int(10) unsigned NOT NULL COMMENT '会员id',
  `transfer_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '转供应商时间',
  `enable_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '启用订单数 0 未启用 大于50 记录 启用日期',
  `enable_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '启用日期',
  `push_money_check_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '给提成状态审核时间',
  `push_money_checkt_status` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '给提成的审核状态 1：已经审核 2：还未审核',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3267 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='供应商会员拓展信息表';

-- @table POLAR_myuu:pft_trade_journal
-- @at 2026-11-27 15:44:42
CREATE TABLE `pft_trade_journal` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `customer_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '客户ID',
  `account_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '账户ID',
  `trade_account_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '交易目标账户',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '会员ID',
  `aid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '本次有关的会员ID',
  `dmoney` decimal(14,0) unsigned NOT NULL DEFAULT '0' COMMENT '本次记录金额',
  `lmoney` decimal(14,0) NOT NULL DEFAULT '0' COMMENT '本次结束后剩余金额',
  `frozen_money` decimal(14,0) unsigned NOT NULL DEFAULT '0' COMMENT '本次记录冻结金额',
  `frozen_remain_money` decimal(14,0) NOT NULL DEFAULT '0' COMMENT '冻结余额',
  `trade_limit_money` bigint(12) NOT NULL DEFAULT '0' COMMENT '交易限定金额',
  `trade_limit_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '交易限定金额类型',
  `trade_limit_total` bigint(12) NOT NULL DEFAULT '0' COMMENT '累计交易限定金额',
  `orderid` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '订单号',
  `trade_no` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '外部交易流水',
  `account_book_id` bigint(14) NOT NULL DEFAULT '0' COMMENT '当前账户账本ID',
  `subject_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '账本科目编码',
  `trade_subject_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '交易对方账本科目编码',
  `subject_type` tinyint(2) NOT NULL DEFAULT '0' COMMENT '账本科目类型',
  `template_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '专项模板编码',
  `template_item_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '模板费用项编码',
  `function_code` int(8) NOT NULL DEFAULT '0' COMMENT '系统功能编码',
  `settle_mark` mediumint(8) NOT NULL DEFAULT '0' COMMENT '所属账期',
  `daction` tinyint(1) NOT NULL COMMENT '0增加 1减少',
  `rectime` datetime NOT NULL COMMENT '插入时间',
  `trade_time` datetime NOT NULL COMMENT '交易时间',
  `recmonth` int(8) NOT NULL DEFAULT '0' COMMENT '交易月份，用来分区',
  `dtype` tinyint(1) NOT NULL COMMENT '0下单 1取消 3账户资金变化[充值/扣款] 4供应商处可用资金变化 5利润6提现或转账的资金冻结 7凭证码 8短信息费 9银行交易手续费 10平台使用费 11供应商信用额度变化 12取消提现 13拒绝提现 14退款手续费 15联盟押金 16充值返现 17撤改撤销 18转账 19佣金发放 20佣金提 21获得佣金 22平台费 23出售产品 24线下充值 25银行卡验证费，26平台套餐续费 27预存还款 28 一卡通充值 29 一卡通提现交易手续费 10平台使用费',
  `ptype` tinyint(1) NOT NULL COMMENT '金额类型 0帐号资金 1支付宝 2供应商处可用资金,3供应商信用额度设置,4财付通,5银联,6环迅,9现金,10会员卡,11拉卡拉(商户),12拉卡拉(平台),13民生乐收银-微信,14平安银行15优惠券，16民生乐收银-支付宝',
  `account_type` tinyint(1) NOT NULL DEFAULT '-1' COMMENT '资金流向类型 : 0帐号资金 1支付宝 2供应商处可用资金 3供应商信用额度设置 4财付通 5银联 6环迅 9现金 11商户拉卡拉 12平台拉卡拉,13民生乐收银-微信,14平安银行，15优惠券，16民生乐收银-支付宝',
  `reversal_trade_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '被冲正交易流水ID',
  `last_trade_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '上一条交易流水ID',
  `channel` tinyint(2) NOT NULL DEFAULT '0' COMMENT '交易请求来源',
  `account_adjust` tinyint(1) NOT NULL DEFAULT '0' COMMENT '调账标识：0=正常， 1=被调账',
  `opid` int(10) NOT NULL COMMENT '操作人员ID',
  `memo` varchar(2556) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '备注',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '流水状态 1=正常，2=冲正',
  `sequence` int(10) NOT NULL DEFAULT '0' COMMENT '交易序列（确保同rectime下的顺序）',
  `total_trade` tinyint(1) NOT NULL DEFAULT '1' COMMENT '总金额交易;总金额变更;0:未变更，1：变更',
  `available_trade` tinyint(1) NOT NULL DEFAULT '0' COMMENT '可用金额交易;可用金额变更;0:未变更，1：变更',
  `available_money` bigint(20) NOT NULL DEFAULT '0' COMMENT '可用交易金额',
  `available_remain_money` bigint(20) NOT NULL DEFAULT '0' COMMENT '可用金额余额',
  `available_trade_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '可用金额交易类型;1:支出,0:收入',
  `frozen_trade` tinyint(1) NOT NULL DEFAULT '0' COMMENT '冻结金额交易;冻结金额变更;0:未变更，1：变更',
  `frozen_trade_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '冻结金额交易类型;1:解冻,0:冻结',
  `product_order_id` varchar(64) NOT NULL DEFAULT '' COMMENT '商品订单号',
  PRIMARY KEY (`id`,`recmonth`),
  KEY `idx_aid` (`aid`),
  KEY `idx_account_id_rectime_id` (`account_id`,`rectime`,`id`),
  KEY `idx_recmonth_fid_rectime_subCode_id` (`recmonth`,`fid`,`rectime`,`subject_code`,`id`),
  KEY `idx_account_rec` (`account_type`,`rectime`),
  KEY `idx_template_item_code_rectime` (`template_item_code`,`rectime`),
  KEY `idx_trade_no` (`trade_no`),
  KEY `idx_fid` (`fid`),
  KEY `idx_orderid` (`orderid`),
  KEY `idx_tradeId_accountId_tmplCode_rectime` (`trade_account_id`,`account_id`,`rectime`),
  KEY `idx_time` (`rectime`),
  KEY `idx_insert_time` (`trade_time`) USING BTREE,
  KEY `idx_product_order_id` (`product_order_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2136741751 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='平台交易流水表'
/*!50100 PARTITION BY LIST (`recmonth`)
(PARTITION p0 VALUES IN (1) ENGINE = InnoDB,
 PARTITION p1 VALUES IN (2) ENGINE = InnoDB,
 PARTITION p2 VALUES IN (3) ENGINE = InnoDB,
 PARTITION p3 VALUES IN (4) ENGINE = InnoDB,
 PARTITION p4 VALUES IN (5) ENGINE = InnoDB,
 PARTITION p5 VALUES IN (6) ENGINE = InnoDB,
 PARTITION p6 VALUES IN (7) ENGINE = InnoDB,
 PARTITION p7 VALUES IN (8) ENGINE = InnoDB,
 PARTITION p8 VALUES IN (9) ENGINE = InnoDB,
 PARTITION p9 VALUES IN (10) ENGINE = InnoDB,
 PARTITION p10 VALUES IN (11) ENGINE = InnoDB,
 PARTITION p11 VALUES IN (12) ENGINE = InnoDB) */;

-- @table POLAR_myuu:pft_wd_cash
-- @at 2026-11-27 15:44:58
CREATE TABLE `pft_wd_cash` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `fid` int(10) unsigned NOT NULL,
  `wd_money` decimal(12,0) unsigned NOT NULL,
  `apply_time` datetime NOT NULL,
  `wd_time` datetime NOT NULL,
  `wd_status` tinyint(1) NOT NULL COMMENT '提现状态：0=未处理，1=已同意，2=处理成功，3=处理失败，4=被取消，5=自动转账中',
  `bank_name` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '类型 - 1=银行，2=支付宝',
  `push_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '自动提现推送状态：0=不需要推送，1=等待推送，2=已经接受，3=处理完成',
  `credit_balance_present` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户提现申请的时候的可提现金额 - 单位分',
  `bank_ins_code` varchar(15) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '支行行号 - 现代化支付系统行号',
  `bank_accuont` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `wd_name` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `wd_operator` varchar(30) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `batchno` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `serial_num` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '支付系统流水号',
  `memo` varchar(300) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `fee_bank_once` smallint(5) NOT NULL DEFAULT '5',
  `cut_fee_way` tinyint(1) NOT NULL,
  `accType` tinyint(1) NOT NULL DEFAULT '0',
  `service_charge` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '提现手续费',
  `ifprint` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '打印状态 0未打印 1已打印',
  `contract_subject` tinyint(4) NOT NULL DEFAULT '1' COMMENT '合作主体：1：票付通，2：票易通',
  PRIMARY KEY (`id`),
  KEY `idx_fid` (`fid`)
) ENGINE=InnoDB AUTO_INCREMENT=286124 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='现金提现表';

-- @table POLAR_myuu:user_auth_info
-- @at 2026-11-27 15:45:08
CREATE TABLE `user_auth_info` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '用户id',
  `identity_type` int(11) NOT NULL DEFAULT '0' COMMENT '认证类型',
  `end_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '有效期',
  `status` tinyint(4) NOT NULL DEFAULT '1' COMMENT '状态 1有效 0无效',
  `card_ext_content` text CHARACTER SET utf8 COLLATE utf8_general_ci COMMENT '证件扩展信息',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  `identity_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '实名身份id',
  PRIMARY KEY (`id`),
  KEY `idx_user_identity_type` (`user_id`,`identity_type`)
) ENGINE=InnoDB AUTO_INCREMENT=1263335 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='认证中心-用户认证信息表';

-- @table POLAR_myuu:user_info
-- @at 2026-11-27 15:45:21
CREATE TABLE `user_info` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `identity_type` tinyint(4) NOT NULL DEFAULT '1' COMMENT '身份类型 1 身份证（中国大陆居民身份）',
  `id_no` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '证件号',
  `real_name` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '真实姓名',
  `sex` tinyint(4) NOT NULL DEFAULT '0' COMMENT '性别 0未知 1男 2女',
  `birthday` date NOT NULL DEFAULT '1970-01-01' COMMENT '生日',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `pk_no_type` (`id_no`,`identity_type`)
) ENGINE=InnoDB AUTO_INCREMENT=997895 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='认证中心-用户表';

-- @table POLAR_myuu:uu_jq_ticket
-- @at 2026-11-27 16:36:53
CREATE TABLE `uu_jq_ticket` (
  `id` int(6) NOT NULL AUTO_INCREMENT COMMENT '表id',
  `landid` int(6) NOT NULL COMMENT '景区id',
  `gid` int(10) NOT NULL DEFAULT '0' COMMENT '商品id',
  `version` int(6) NOT NULL DEFAULT '0' COMMENT '票属性版本号',
  `title` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '门票名称',
  `tprice` decimal(12,2) unsigned NOT NULL COMMENT '市场价',
  `uprice` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '出售价(弃用)',
  `gprice` decimal(12,2) unsigned DEFAULT '0.00' COMMENT '团购价(弃用)',
  `wprice` char(13) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT '' COMMENT '周价格按时间分类 1,3,5,6|2,4,7(弃用)',
  `fprice` decimal(10,0) NOT NULL DEFAULT '0' COMMENT '当日供应价(弃用)',
  `reb` decimal(6,0) unsigned NOT NULL DEFAULT '0' COMMENT '退款数值',
  `rebp` decimal(2,1) unsigned DEFAULT '0.0' COMMENT '评论返还(百分比)',
  `discount` decimal(6,0) unsigned DEFAULT NULL COMMENT '折扣',
  `delaydays` decimal(6,0) unsigned NOT NULL DEFAULT '0' COMMENT '允许推迟游玩的天数',
  `use_early_days` tinyint(1) NOT NULL DEFAULT '0' COMMENT '提前使用天数',
  `print_ticket_limit` tinyint(4) NOT NULL DEFAULT '0' COMMENT '是否当日可取票',
  `mobre` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '二维码',
  `px` int(6) NOT NULL DEFAULT '0' COMMENT '排序',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态: 1=上架, 2=下架, 6=删除',
  `pay` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '支付方式 1：在线支付，2：一卡通支付，3：现金支付',
  `notes` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '购票须知',
  `ifs` enum('0','1') CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '0' COMMENT '是否有特价票',
  `storage` int(10) NOT NULL DEFAULT '-1' COMMENT '总库存：-1=不限，>0=总库',
  `storage_open` date DEFAULT NULL COMMENT '开启总库存的日期',
  `ddays` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '提前下单间隔时间',
  `getaddr` varchar(300) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '取票信息',
  `smslimit` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `s_limit_up` int(10) NOT NULL DEFAULT '0' COMMENT '库存上限',
  `s_limit_low` int(10) NOT NULL DEFAULT '0' COMMENT '库存下限',
  `buy_limit_up` int(10) NOT NULL DEFAULT '0' COMMENT '购买上限,0表示不限',
  `buy_limit_low` int(10) NOT NULL DEFAULT '1' COMMENT '购买下限，必须大于0',
  `open_time` datetime DEFAULT NULL COMMENT '启用日期',
  `end_time` datetime DEFAULT NULL COMMENT '结束日期',
  `apply_did` int(10) unsigned NOT NULL COMMENT '供应商ID',
  `modify_op` varchar(30) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '更改用户ID',
  `uuid` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品ID',
  `pft_rflex_id` int(10) NOT NULL DEFAULT '0' COMMENT '弃用',
  `cancel_auto_onMin` int(10) unsigned NOT NULL DEFAULT '120' COMMENT '未支付多少分钟内自动取消',
  `delaytype` tinyint(1) NOT NULL DEFAULT '0' COMMENT '允许推迟的天数使用0游玩时间/1下单时间/2期票模式',
  `order_limit` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '订单验证限制日期 默认全部',
  `order_end` datetime DEFAULT NULL COMMENT '截止订单有效期日期 到当天的23：59：59',
  `sync_id` int(10) NOT NULL DEFAULT '0' COMMENT '先行平台关联id',
  `sync_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '第三方平台产品同步ID',
  `cancel_cost` varchar(2000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '取消费用二维数组 [[\\''c_type\\''=>类型 0 固定金额 1 百分比,\\''c_days\\''=>游玩前天数,\\''c_cost\\''=>\\''\\'']',
  `re_integral` int(10) NOT NULL DEFAULT '0' COMMENT '点评返现积分',
  `reb_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '取消费用类型 0 百分比，1 实际指定具体值',
  `order_start` datetime DEFAULT NULL COMMENT '订单有效期开始日期 00:00:00',
  `max_order_days` smallint(5) NOT NULL DEFAULT '-1' COMMENT '提前下单最多间隔天数',
  `Mdetails` tinyint(1) NOT NULL DEFAULT '0',
  `Mpath` varchar(500) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '',
  `sourceT` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '对接类型：0=票付通，1=九天闸机权限，2=第三方, 3=开放接口',
  `overdue_refund` tinyint(1) NOT NULL DEFAULT '0' COMMENT '过期退款 大于0 可退 小于 0 不可退',
  `batch_check` tinyint(1) NOT NULL DEFAULT '0' COMMENT '分批验证 0 不支持 1 支持，2：一票一码，3：一票一证',
  `batch_day_check` tinyint(10) NOT NULL DEFAULT '0' COMMENT '分批验证 每天可验证张数',
  `batch_diff_identities` tinyint(1) NOT NULL DEFAULT '0' COMMENT '限不同身份证验证 0 不限  1 限制',
  `chk_terminal_info` varchar(4000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '启用每个终端都可以验证一次功能,0不启用ALL全部可验证,指定分终端使用逗号分隔',
  `refund_audit` tinyint(1) NOT NULL DEFAULT '0' COMMENT '退票审核：0 不审核 1 需审核',
  `delaytime` char(5) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '0|0' COMMENT '延迟验证时间',
  `refund_rule` tinyint(1) NOT NULL DEFAULT '0' COMMENT '退票规则：0=有效期内可退 ： 未使用订单末级分销商可退；过期订单供应商可退，1=游玩日期内可退，阶梯退：未使用订单末级分销商可退；过期订单供应商可退 2=不可退：分销商供应商都不可退 3=随时退：未使用订单末级分销商可退；过期订单分销商可退，供应商可退。-1=不可退且是可提现',
  `refund_early_time` int(10) NOT NULL DEFAULT '0' COMMENT '退票提前多少分钟',
  `cancel_notify_supplier` tinyint(1) NOT NULL DEFAULT '0' COMMENT '取消订单时短信通知供应商',
  `revoke_audit` tinyint(1) NOT NULL DEFAULT '1' COMMENT '撤改是否需要人工审核 1=需要（允许撤改），0=不需要（允许撤改） 2不可撤改',
  `delay_refund_time` int(10) NOT NULL DEFAULT '0' COMMENT '延迟退款时间',
  `num_modify` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0只可减少，大于0为增减或减少的上限比例',
  `expire_action` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '订单过期后处理方式 - 1=不做处理，2=自动完结，3=自动验证，4=自动取消',
  `expire_action_days` smallint(3) unsigned NOT NULL DEFAULT '1' COMMENT '多少天后自动处理 - 结合expire_action使用',
  `expire_action_fee` decimal(6,2) unsigned NOT NULL DEFAULT '0.00' COMMENT '自动取消的手续费',
  `update_time` int(11) DEFAULT '0' COMMENT '创建时间/更新时间',
  `shop` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL,
  `if_verify` tinyint(1) NOT NULL DEFAULT '0' COMMENT '游玩日期不可验证 1=不可验证，0=可以验证',
  `discount_scale` tinyint(3) NOT NULL DEFAULT '0' COMMENT '折扣比例 0 不折扣 最多99',
  `modify_limit_time` int(10) NOT NULL DEFAULT '0' COMMENT '修改门票限制时间-相对于游玩时间而言',
  `ticket_changing_range` int(3) NOT NULL DEFAULT '0' COMMENT '允许改签至游玩日期前后天数,0:不可改签',
  `ticket_changing_audit` tinyint(1) NOT NULL DEFAULT '0' COMMENT '改签是否需要审核,0:不需要审核,1:需要审核',
  `ticket_changing_weekend` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否允许平时改签至周末,0:不允许,1:允许',
  `max_expiration_date` date DEFAULT '1970-01-01' COMMENT '门票过期最大日期',
  `dhour` varchar(8) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '23:59' COMMENT '提前下单截止日具体时间 (时:分:秒)12:12:12（线路）',
  `pre_sale` tinyint(1) NOT NULL DEFAULT '0' COMMENT '期票标识：是否预售 0:否 1:是',
  `order_flag` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否支持抱团',
  PRIMARY KEY (`id`),
  KEY `idx_lid_pid_status_expiration` (`landid`,`pid`,`status`,`max_expiration_date`),
  KEY `idx_gid` (`gid`),
  KEY `idx_pid_status_max_expiration_date` (`pid`,`status`,`max_expiration_date`),
  KEY `a_status_did` (`apply_did`,`status`),
  KEY `idx_max_date_status` (`max_expiration_date`,`status`),
  KEY `idx_update_time` (`update_time`)
) ENGINE=InnoDB AUTO_INCREMENT=5593939 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='门票表';

-- @table POLAR_myuu:uu_land
-- @at 2026-11-27 16:18:09
CREATE TABLE `uu_land` (
  `id` int(6) NOT NULL AUTO_INCREMENT COMMENT '表id',
  `title` varchar(255) NOT NULL COMMENT '景区名称',
  `letters` varchar(32) NOT NULL DEFAULT '' COMMENT 'title字段的拼音首字母',
  `tel` varchar(50) NOT NULL DEFAULT '' COMMENT '联系电话',
  `fax` varchar(50) NOT NULL DEFAULT '' COMMENT '传真',
  `jtype` varchar(20) NOT NULL DEFAULT '0' COMMENT '景区级别',
  `opentime` date DEFAULT '0000-00-00' COMMENT '开业时间',
  `runtime` varchar(1000) NOT NULL DEFAULT '' COMMENT '营业时间',
  `area` varchar(32) NOT NULL DEFAULT '' COMMENT '省份|城市|区县',
  `address` varchar(255) NOT NULL DEFAULT '' COMMENT '详细地址',
  `jtzn` text NOT NULL COMMENT '交通指南',
  `jdjj` mediumtext NOT NULL COMMENT '景点简介',
  `bhjq` mediumtext NOT NULL COMMENT '包含的景点和项目',
  `jqts` varchar(2000) NOT NULL COMMENT '景区相关提示',
  `qt` varchar(2000) NOT NULL DEFAULT '' COMMENT '其他信息',
  `imgpath` varchar(200) NOT NULL COMMENT '缩略图',
  `status` tinyint(1) NOT NULL COMMENT '状态：1=上架，2=下架',
  `verify_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0未审核1审核通过2关闭3删除',
  `px` int(6) NOT NULL DEFAULT '0' COMMENT '推荐值，数字越大排越前',
  `addtime` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '添加时间',
  `passtime` datetime DEFAULT '0000-00-00 00:00:00' COMMENT '审核通过时间',
  `salerid` decimal(10,0) NOT NULL DEFAULT '0' COMMENT '商家ID',
  `apply_did` int(10) unsigned NOT NULL COMMENT '景区供应商',
  `topic` varchar(600) NOT NULL DEFAULT '' COMMENT '主题',
  `uptime` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `p_type` char(1) NOT NULL COMMENT '景区类型：A景区B线路C酒店F套票',
  `taobao_support` tinyint(1) DEFAULT '0' COMMENT '绑定淘宝：1=应许绑定，0=禁止绑定',
  `attribute` varchar(2000) NOT NULL DEFAULT '',
  `terminal` int(10) NOT NULL COMMENT '终端号',
  `pft_rflex_id` int(10) NOT NULL DEFAULT '0' COMMENT '同步产品ID',
  `delaytime` char(5) NOT NULL DEFAULT '' COMMENT '延迟验证时间',
  `sync_id` int(10) NOT NULL DEFAULT '0' COMMENT '先行平台关联id',
  `sync_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0没同步 1同步、2被同步,3取消同步，4被取消同步，5取消同步（不可再同步）',
  `areacode` smallint(4) unsigned NOT NULL DEFAULT '0' COMMENT '地区编码4位数',
  `custom_made` enum('0','1','2','3','4') NOT NULL DEFAULT '0' COMMENT '私人定制：清新之旅，住宿主题，精彩云秀，娱乐美食，游客服务',
  `imgpathGrp` varchar(2000) NOT NULL DEFAULT '',
  `scenicid_list` varchar(200) NOT NULL DEFAULT '' COMMENT '已关联子景点信息',
  `lng_lat_pos` varchar(50) NOT NULL DEFAULT '' COMMENT '经纬度',
  `terminal_type` tinyint(1) NOT NULL DEFAULT '2' COMMENT '验证类型 1:新服务器 2:旧服务器',
  `venus_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '场馆ID',
  `mVerification` tinyint(1) unsigned DEFAULT '0' COMMENT '分批验证',
  `resourceID` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '资源库ID',
  `operater_id` int(10) DEFAULT '0' COMMENT '最新操作员id，关联pft_member.id',
  `reception_ability` int(10) NOT NULL DEFAULT '0' COMMENT '园区接待能力值',
  `warn_percent` tinyint(3) NOT NULL DEFAULT '0' COMMENT '园区日接待能力预警百分比',
  `order_flag` tinyint(1) NOT NULL DEFAULT '0' COMMENT '产品订单类型标识:0=通用,1=团队订单',
  `oversea` int(1) NOT NULL DEFAULT '0' COMMENT '境外境内:0=境内,1=境外',
  `group_number_limit` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否勾选报团人数限制: 0=否，1=是',
  `group_ticket_limit` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否勾选报团门票限制: 0=否，1=是',
  `group_limit` varchar(1000) NOT NULL DEFAULT '' COMMENT '报团限制json',
  `relation_land_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '关联业态景区状态 0=未关联 1=已关联',
  `video_url` varchar(255) NOT NULL DEFAULT '' COMMENT '视频url',
  `sub_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1:游船计时 2:滑雪场计时',
  `sub_sid` int(11) NOT NULL DEFAULT '0' COMMENT '子商户id',
  `land_version` int(11) NOT NULL DEFAULT '0' COMMENT '产品快照版本号',
  `region_area` varchar(64) NOT NULL DEFAULT '' COMMENT '新地区编码',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `salerid` (`salerid`) USING BTREE,
  KEY `px` (`px`) USING BTREE,
  KEY `idx_terminal` (`terminal`) USING BTREE,
  KEY `idx_resourceID` (`resourceID`) USING BTREE,
  KEY `idx_apply_did` (`apply_did`) USING BTREE,
  KEY `idx_addtime` (`addtime`)
) ENGINE=InnoDB AUTO_INCREMENT=348009 DEFAULT CHARSET=utf8 COMMENT='景区表';

-- @table POLAR_myuu:uu_order_addon
-- @at 2026-11-27 16:18:18
CREATE TABLE `uu_order_addon` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `orderid` varchar(20) NOT NULL COMMENT '订单号',
  `dstatus` tinyint(1) NOT NULL COMMENT '确认订单状态0无需确认 1待确认 2已确认未验证 3已确认已验证 4确认后取消 5确认后修改,6演出套票的订单',
  `confirm_time` datetime DEFAULT NULL COMMENT '确认时间',
  `confirm_op` int(10) NOT NULL COMMENT '分销商ID',
  `ifpack` int(10) NOT NULL COMMENT '0非套票订单1套票主订单 >100000套票从订单（2票付通从订单）',
  `sysorder` tinyint(1) NOT NULL COMMENT '子票是否已经处理完成:100=处理完,0=没有',
  `pack_order` varchar(20) NOT NULL COMMENT '套票主票订单号',
  `pack_process` varchar(2000) NOT NULL COMMENT '线下自填的流水号json数据',
  `ifprint` tinyint(1) NOT NULL COMMENT '是否被打印 1代表被打印',
  `vcode` varchar(255) NOT NULL DEFAULT '' COMMENT '对接第三方系统的凭证码',
  `tordernum` varchar(64) NOT NULL COMMENT '对接第三方系统的对方订单',
  `partner_mark` smallint(4) NOT NULL DEFAULT '0' COMMENT '是否对接三方系统标识',
  `link_ordernum` varchar(20) NOT NULL DEFAULT '' COMMENT '原来uu_order_fx_details->concat_id',
  `order_time` int(11) NOT NULL DEFAULT '0' COMMENT '逻辑下单时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '订单更新时间',
  `order_month` tinyint(2) NOT NULL DEFAULT '0' COMMENT '逻辑下单月份',
  `apply_did` int(10) NOT NULL DEFAULT '0' COMMENT '原始供应商ID',
  `sync_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否同步标示 1:同步,0:无需同步',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `orderid` (`orderid`) USING BTREE,
  KEY `packorder` (`pack_order`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=24650943 DEFAULT CHARSET=utf8 COMMENT='订单扩展表';

-- @table POLAR_myuu:uu_order_apply_info
-- @at 2026-11-27 16:18:29
CREATE TABLE `uu_order_apply_info` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `orderid` varchar(20) NOT NULL COMMENT '订单号',
  `apply_id` int(10) NOT NULL COMMENT '顶级供应商ID',
  `aprice` decimal(12,0) NOT NULL COMMENT '供应价',
  `lprice` decimal(12,0) NOT NULL COMMENT '零售价表',
  `counter_price` decimal(12,0) NOT NULL DEFAULT '0' COMMENT '下单时的门市价',
  `sale_price` int(10) NOT NULL DEFAULT '0' COMMENT '实际售价',
  `pid` int(10) NOT NULL COMMENT '产品ID',
  `refund_num` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '退票数',
  `verified_num` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '已验证票数',
  `origin_num` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '原始票数',
  `can_refund` smallint(5) NOT NULL DEFAULT '-1' COMMENT '可退票数',
  `playtime` date NOT NULL COMMENT '游玩时间（弃用）',
  `addtime` datetime NOT NULL COMMENT '添加时间',
  `flag` tinyint(1) NOT NULL COMMENT '处理标识：1=已经处理，0=没有',
  `current_num` smallint(5) NOT NULL DEFAULT '0' COMMENT '记录当前总的票数',
  `order_time` int(11) NOT NULL DEFAULT '0' COMMENT '逻辑下单时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '订单更新时间',
  `order_month` tinyint(2) NOT NULL DEFAULT '0' COMMENT '逻辑下单月份',
  `sync_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否同步标示 1:同步,0:无需同步',
  `can_take` smallint(5) NOT NULL DEFAULT '-1' COMMENT '可取票数',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `orderid` (`orderid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=24653830 DEFAULT CHARSET=utf8 COMMENT='订单原始数据表';

-- @table POLAR_myuu:uu_order_fx_details
-- @at 2026-11-27 15:56:02
CREATE TABLE `uu_order_fx_details` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `orderid` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '订单号',
  `series` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '演出类座位等信息或是团号',
  `assembly` tinyint(3) unsigned NOT NULL COMMENT '0不用处理|其他数字到线路表取相应的值',
  `memo` varchar(2000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '备注',
  `origin` varchar(300) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '客源地',
  `concat_id` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '关联的订单号',
  `pay_status` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '支付状态:0=现场支付,1=已支付,2=未支付(弃用)',
  `aids_money` varchar(3000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '供应商进化线付款详情',
  `aids` varchar(300) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '转分销各级分销链',
  `aids_price` varchar(300) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '转分销各级分销链购买价格',
  `ext_content` varchar(3000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '扩展属性',
  `product_ext` varchar(5000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '{}' COMMENT '产品扩展json数据，演出、线路等产品的一些定制数据 - {"show":{},"line":{}}',
  `partner_ext` varchar(1000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '{}' COMMENT '合作方的一些数据，三方系统订单号，凭证码等数据',
  `offline_ext` varchar(1000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '{}' COMMENT '线下售票系统的一些数据，线下自填的流水号等一些数据',
  `notice_ext` varchar(1000) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '{}' COMMENT '通知类数据，是否需要回调，通知邮件，remsg短信通知次数等',
  `order_time` int(11) NOT NULL DEFAULT '0' COMMENT '逻辑下单时间',
  `order_month` tinyint(2) NOT NULL DEFAULT '0' COMMENT '逻辑下单月份',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '订单更新时间',
  `apply_did` int(10) NOT NULL DEFAULT '0' COMMENT '原始供应商ID',
  `sync_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否同步标示 1:同步,0:无需同步',
  PRIMARY KEY (`id`),
  UNIQUE KEY `orderid` (`orderid`),
  KEY `concatID` (`concat_id`),
  KEY `idx_order_time` (`order_time`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1109856423 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='订单详情表';

-- @table POLAR_myuu:uu_order_tourist_info
-- @at 2026-11-27 15:57:53
CREATE TABLE `uu_order_tourist_info` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `orderid` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `tourist` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '游客姓名',
  `idcard` varchar(18) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `voucher_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '身份信息类型:1=身份证, 2=护照, 3=军官证, 4=回乡证, 5=台胞证, 99=其他',
  `mobile` varchar(11) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '0',
  `check_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0未验证1已验证2已取消',
  `idx` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '订单序号',
  `print_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '打印状态0未打印1已打印',
  `check_time` int(10) NOT NULL DEFAULT '0' COMMENT '验证时间',
  `lid` int(10) NOT NULL DEFAULT '0' COMMENT '景点ID',
  `chk_code` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '升级过的凭证号',
  `member_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '游客ID',
  `is_checked` tinyint(1) NOT NULL DEFAULT '0' COMMENT '这个门票码是否全部验证',
  `order_time` int(11) NOT NULL DEFAULT '0' COMMENT '逻辑下单时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '订单更新时间',
  `order_month` tinyint(2) NOT NULL DEFAULT '0' COMMENT '逻辑下单月份',
  `apply_did` int(10) NOT NULL DEFAULT '0' COMMENT '原始供应商ID',
  `sync_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否同步标示 1:同步,0:无需同步',
  `mobile_area` varchar(10) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '手机区号',
  `mobile_region` varchar(10) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '手机区号的区域代码',
  PRIMARY KEY (`id`),
  KEY `orderid` (`orderid`),
  KEY `idx_chk_code` (`chk_code`),
  KEY `idx_idcard` (`idcard`),
  KEY `idx_orderid_idx` (`orderid`,`idx`),
  KEY `idx_order_time` (`order_time`) USING BTREE,
  KEY `idx_update_time` (`update_time`)
) ENGINE=InnoDB AUTO_INCREMENT=1677223439 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='游客身份证等信息表';

-- @table POLAR_myuu:uu_order_tourist_info_extend
-- @at 2026-11-27 15:58:28
CREATE TABLE `uu_order_tourist_info_extend` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `orderid` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '订单号ID',
  `idx` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '订单游客序号',
  `end_time` datetime NOT NULL DEFAULT '1000-01-01 00:00:00' COMMENT '门票订单有效截止时间',
  `valid_num` int(10) NOT NULL DEFAULT '0' COMMENT '剩余可入园次数',
  `take_way` int(10) NOT NULL DEFAULT '0' COMMENT '取票方式:1=凭证号取票,2=手机号取票,3=身份证取票,4=订单号取票,5=团单号取票',
  `apply_did` int(10) NOT NULL DEFAULT '0' COMMENT '原始供应商ID',
  `ext_info` varchar(1500) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '{}' COMMENT '拓展信息字段 ',
  `order_time` int(11) NOT NULL DEFAULT '0' COMMENT '逻辑下单时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '订单更新时间',
  `order_month` tinyint(2) NOT NULL DEFAULT '0' COMMENT '逻辑下单月份',
  `sync_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否同步标示 1:同步,0:无需同步',
  PRIMARY KEY (`id`),
  KEY `idx_orderid` (`orderid`),
  KEY `idx_end_time_id` (`end_time`,`id`),
  KEY `idx_order_time` (`order_time`) USING BTREE,
  KEY `idx_update_time` (`update_time`)
) ENGINE=InnoDB AUTO_INCREMENT=1562098053 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='游客身份证等信息表';

-- @table POLAR_myuu:uu_product_price
-- @at 2026-11-27 16:18:42
CREATE TABLE `uu_product_price` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `pid` int(10) NOT NULL COMMENT '产品ID',
  `ticket_id` int(10) NOT NULL DEFAULT '0' COMMENT '门票id',
  `ptype` tinyint(1) NOT NULL COMMENT '类型:0=平时,1=特殊',
  `n_price` decimal(8,0) unsigned NOT NULL COMMENT '平日价格',
  `m_price` decimal(8,0) unsigned NOT NULL DEFAULT '0' COMMENT '周末价格',
  `s_price` decimal(8,0) unsigned NOT NULL COMMENT '特殊价格',
  `l_price` decimal(8,0) unsigned NOT NULL COMMENT '零售价',
  `window_price` int(10) NOT NULL DEFAULT '0' COMMENT '窗口价',
  `start_date` date DEFAULT NULL COMMENT '开始日期',
  `end_date` date DEFAULT NULL COMMENT '结束日期',
  `memo` varchar(200) NOT NULL DEFAULT '' COMMENT '价格说明',
  `status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态:0=未审核,1=被拒绝,2=已通过',
  `weekdays` varchar(16) NOT NULL COMMENT '适用日期[例如：0,1,2,3,4,5,6]',
  `storage` int(10) NOT NULL DEFAULT '-1' COMMENT '库存',
  `rid` int(10) NOT NULL DEFAULT '0',
  `update_time` int(11) DEFAULT '0' COMMENT '创建时间/更新时间',
  `operater_id` int(10) DEFAULT '0' COMMENT '最新操作员id，关联pft_member.id',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uniq_ticketptypedatestatusweekdays_unique` (`ticket_id`,`ptype`,`start_date`,`end_date`,`status`,`weekdays`) USING BTREE,
  KEY `pid` (`pid`) USING BTREE,
  KEY `ticketid_index` (`ticket_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=2147483713 DEFAULT CHARSET=utf8 COMMENT='产品价格规则细表';

-- @table POLAR_myuu:uu_ss_order
-- @at 2026-11-27 16:18:54
CREATE TABLE `uu_ss_order` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '表id',
  `member` int(10) unsigned NOT NULL COMMENT '购买者ID',
  `ordernum` varchar(20) NOT NULL COMMENT '订单号',
  `certnum` decimal(6,0) unsigned zerofill NOT NULL COMMENT '资源ID',
  `remotenum` varchar(36) NOT NULL COMMENT '远端订单号',
  `lid` int(6) NOT NULL COMMENT '景区id',
  `tid` int(6) NOT NULL COMMENT '门票id',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品id',
  `aid` int(10) NOT NULL COMMENT '供应商ID',
  `tnum` int(10) unsigned NOT NULL COMMENT '门票数量',
  `tprice` int(10) NOT NULL COMMENT '单价',
  `ordername` varchar(50) NOT NULL COMMENT '取票人姓名',
  `ordertel` varchar(20) NOT NULL COMMENT '取票人电话',
  `contacttel` varchar(20) NOT NULL COMMENT '取票人电话',
  `ordertime` datetime DEFAULT NULL COMMENT '下单时间',
  `playtime` date NOT NULL DEFAULT '0000-00-00' COMMENT '预计游玩时间',
  `begintime` date NOT NULL COMMENT '开始时间',
  `endtime` date NOT NULL COMMENT '结束时间',
  `ctime` datetime NOT NULL COMMENT '取消时间',
  `dtime` datetime NOT NULL COMMENT '验证时间',
  `status` tinyint(1) NOT NULL COMMENT '订单状态：0=未使用,1=已使用,2=已过期,3=被取消,4=待确认(酒店)，待收货(特产),5=被终端修改,6=被终端撤销,7=部分使用,8=订单完结,9=被删除',
  `pay_status` tinyint(1) unsigned NOT NULL DEFAULT '2' COMMENT '支付方式:0=现场支付,1=已支付,2=未支付',
  `salerid` int(6) unsigned zerofill NOT NULL COMMENT '商家ID',
  `remsg` tinyint(1) unsigned NOT NULL COMMENT '短信重发限制次数',
  `smserror` smallint(3) NOT NULL COMMENT '短信错误信息',
  `paymode` tinyint(1) unsigned NOT NULL DEFAULT '255' COMMENT '支付方式：0 = 余额支付,1 = 支付宝,2 = 授信支付,3 = 产品自销,4 = 现场支付,5 = 微信支付,6 = 会员卡支付,7 = 银联支付,8 = 环迅支付,9 = 现金支付,10 = 会员卡,11 = 拉卡拉（商户）,12 = 拉卡拉（平台）,13 = 特权支付（年卡）,14 = 微信（聚合）,15 = 平安银行,16 = 支付宝（聚合）,17 = 会员卡支付,18 = 计时卡支付,25 = 招行一网通支付,26 = 银联商务支付,27 = 银联商务POS支付,28 = 威富通支付,29 = 易宝云企付,33 = 博思支付,35 = 积分支付,36 = POS支',
  `totalmoney` int(10) NOT NULL COMMENT '总的支付金额',
  `ordermode` tinyint(1) NOT NULL DEFAULT '0' COMMENT '下单方式:0=正常分销商下单,1=普通用户支付,2=用户手机支付,3=会员卡购票,10=云票务,11=微信商城,12=自助机,13=二级店铺,14=闸机购票,15=智能终端,16=计调下单,17=淘宝码商,18=年卡,19=微信端,20=外部接口OTA下单,22=一卡通,23=套票子票',
  `onsale` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0正常1使用优惠价支付2修改过的订单',
  `personid` varchar(64) NOT NULL DEFAULT '' COMMENT '取票人身份信息',
  `callback` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否需要回调0无需1必需',
  `code` int(6) unsigned zerofill NOT NULL COMMENT '凭证码',
  `unionCheck` tinyint(1) NOT NULL DEFAULT '0' COMMENT '提现类型：0=正常订单，1=不可退而且可提现的订单，2=独立收款',
  `visitors` tinyint(1) NOT NULL DEFAULT '2' COMMENT '订单客户类型：1=游客,2=分销商',
  `pay_time` int(11) NOT NULL DEFAULT '0' COMMENT '订单支付时间',
  `order_time` int(11) NOT NULL DEFAULT '0' COMMENT '逻辑下单时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '订单更新时间',
  `order_month` tinyint(2) NOT NULL DEFAULT '0' COMMENT '逻辑下单月份',
  `product_type` char(1) NOT NULL DEFAULT '' COMMENT '商品类型',
  `apply_did` int(10) NOT NULL DEFAULT '0' COMMENT '原始供应商ID',
  `sync_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否同步标示 1:同步,0:无需同步',
  `trade_order_id` varchar(32) NOT NULL DEFAULT '' COMMENT '交易订单号',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_ordernum` (`ordernum`) USING BTREE,
  KEY `idx_lid` (`lid`) USING BTREE,
  KEY `idx_tid` (`tid`) USING BTREE,
  KEY `idx_mid` (`member`) USING BTREE,
  KEY `idx_aid` (`aid`) USING BTREE,
  KEY `idx_code` (`code`) USING BTREE,
  KEY `idx_ordertime` (`ordertime`) USING BTREE,
  KEY `idx_dtime` (`dtime`) USING BTREE,
  KEY `idx_remotenum` (`remotenum`) USING BTREE,
  KEY `idx_ordertel` (`ordertel`) USING BTREE,
  KEY `idx_salerid` (`salerid`) USING BTREE,
  KEY `idx_endtime` (`endtime`) USING BTREE,
  KEY `idx_trade_order_id` (`trade_order_id`),
  KEY `idx_personid` (`personid`)
) ENGINE=InnoDB AUTO_INCREMENT=303071582 DEFAULT CHARSET=utf8 COMMENT='平台订单记录主表';

-- @table POLAR_myuu:uu_ss_order_team
-- @at 2026-11-27 15:58:56
CREATE TABLE `uu_ss_order_team` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0 未确认 1 已确认 2 已验证 3 已取消',
  `contacttel` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '0' COMMENT '手机号',
  `ordername` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '姓名',
  `pay_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0 未支付 1 已支付 2 部分支付',
  `ordernum` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '0' COMMENT '团队订单号',
  `playtime` date NOT NULL COMMENT '游玩时间',
  `tnum` int(11) DEFAULT '0' COMMENT '团队人数',
  `province` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '客源地省份',
  `province_code` varchar(10) DEFAULT '' COMMENT '新省份区域编码(region_area.area_code)',
  `city` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '客源地城市',
  `city_code` varchar(10) DEFAULT '' COMMENT '新城市区域编码(region_area.area_code)',
  `county` int(11) unsigned NOT NULL COMMENT '客源地县城',
  `county_code` varchar(10) DEFAULT '' COMMENT '新区县区域编码(region_area.area_code)',
  `aid` int(11) NOT NULL COMMENT '供应商',
  `fid` int(11) NOT NULL COMMENT '分销商',
  `ordertime` datetime NOT NULL COMMENT '下单时间',
  `updatetime` int(11) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `guide` int(11) NOT NULL DEFAULT '0' COMMENT '导游id',
  `combine_pay_id` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '合并付款的ID',
  `ordertype` tinyint(1) NOT NULL DEFAULT '0' COMMENT '报团下单方式：1=云票务 ；2=微平台；3=分销商报团预定；4=报团计调',
  `is_lodging` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否住宿 0 否 1 是',
  `hotel` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '入住酒店名称',
  `team_type_id` int(10) NOT NULL DEFAULT '0' COMMENT '团单类（对应pft_team_rules表中limit_type等于2的id）',
  `ext_content` json DEFAULT NULL COMMENT '团单扩展信息',
  `active_code` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '团单激活码,码规则与团单号一样',
  `active_status` tinyint(1) DEFAULT '0' COMMENT '激活状态:0无需激活,1未激活,2已激活',
  `active_time` int(10) NOT NULL DEFAULT '0' COMMENT '激活时间',
  `group_id` int(10) NOT NULL DEFAULT '0' COMMENT '分销商分组id',
  `sync` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已同步 0：否 1：是',
  `first_check_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '团单首次验证时间',
  PRIMARY KEY (`id`),
  KEY `idx_aid` (`aid`),
  KEY `idx_active_code` (`active_code`),
  KEY `idx_fid` (`fid`),
  KEY `idx_combine_id` (`combine_pay_id`),
  KEY `idx_ordernum` (`ordernum`),
  KEY `idx_playtime` (`playtime`) USING BTREE,
  KEY `idx_province_code` (`province_code`),
  KEY `idx_city_code` (`city_code`),
  KEY `idx_county_code` (`county_code`)
) ENGINE=InnoDB AUTO_INCREMENT=742007 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table POLAR_myuu:uu_ss_order_team_link
-- @at 2026-11-27 15:59:12
CREATE TABLE `uu_ss_order_team_link` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `main_ordernum` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '团队订单号',
  `son_ordernum` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '子订单号',
  `lid` int(11) NOT NULL COMMENT '景区id',
  `tid` int(11) NOT NULL COMMENT '票类id',
  `is_expired` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否过期',
  `order_time` int(10) NOT NULL DEFAULT '0' COMMENT '下单时间',
  `active_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '激活状态 0：无需激活 1：未激活  2：已激活',
  `status` tinyint(1) NOT NULL DEFAULT '-1' COMMENT '订单状态：0=未使用,1=已使用,2=已过期,3=被取消,4=待确认(酒店)，待收货(特产),5=被终端修改,6=被终端撤销,7=部分使用,8=订单完结,9=被删除,10=待预约,11=待出票,80=待发货,81=已发货',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `playtime` date NOT NULL DEFAULT '0000-00-00' COMMENT '游玩时间（同uu_ss_oerder表）',
  PRIMARY KEY (`id`),
  KEY `idx_main` (`main_ordernum`),
  KEY `idx_tid` (`tid`),
  KEY `idx_son` (`son_ordernum`),
  KEY `idx_lid` (`lid`),
  KEY `idx_playtime` (`playtime`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1223556 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table POLAR_platform:uu_order_terminal_change
-- @at 2026-11-27 15:34:16
-- @cmt dstatus 状态
-- @cmt dtime 结束时间
-- @cmt id 主键ID
-- @cmt lid 产品ID
-- @cmt ordernum 订单号
-- @cmt reason 变动原因
-- @cmt salerid 商家ID
-- @cmt stime 开始时间
-- @cmt terminal 终端号
-- @cmt tid 门票ID
-- @cmt tnum 票数
CREATE TABLE `uu_order_terminal_change` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `ordernum` char(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `terminal` int(6) unsigned NOT NULL,
  `salerid` char(6) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `lid` int(6) unsigned NOT NULL,
  `tid` int(6) unsigned NOT NULL,
  `stype` tinyint(1) unsigned NOT NULL,
  `tnum` int(10) NOT NULL,
  `dstatus` tinyint(1) unsigned NOT NULL,
  `reason` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `dadmin` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `stime` datetime DEFAULT NULL,
  `dtime` datetime DEFAULT NULL,
  `fxid` int(10) NOT NULL,
  `remote_sn` varchar(48) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '第三方流水号',
  `system_sn` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '平台流水号',
  `modify_tnum` smallint(4) NOT NULL DEFAULT '0' COMMENT '本次修改的票数',
  `aids` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '转分销各级分销链',
  `ltitle` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '景区名',
  `ttitle` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '票名',
  `concat_id` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '联票的主订单',
  `ifpack` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0非套票订单1套票主订单 （2票付通从订单）',
  `apply_did` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `sub_merchant_id` int(11) NOT NULL DEFAULT '-1' COMMENT '子商户id',
  `sourceT` tinyint(1) NOT NULL DEFAULT '0' COMMENT '对接类型：0=票付通，1=九天闸机权限，2=第三方, 3=开放接口',
  `dcodeURL` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '回调地址',
  `pack_order` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '套票主票订单',
  `system_auto_check` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否需要系统自动处理',
  `p_type` varchar(1) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '冗余票类型',
  `audit_data` varchar(5100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '{}' COMMENT 'json串',
  `approval_code` int(10) NOT NULL DEFAULT '0' COMMENT '审核流程编号',
  PRIMARY KEY (`id`),
  KEY `idx_ordernum_dstatus_ptype` (`ordernum`,`dstatus`,`p_type`),
  KEY `idx_approval_code` (`approval_code`),
  KEY `idx_ordernum` (`ordernum`),
  KEY `idx_system_sn` (`system_sn`),
  KEY `idx_dstatus_time` (`dstatus`,`stime`),
  KEY `idx_sub_merchant_id` (`sub_merchant_id`),
  KEY `idx_concat_id` (`concat_id`),
  KEY `idx_apply_did` (`apply_did`)
) ENGINE=InnoDB AUTO_INCREMENT=46363853 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='终端订单变动记录表';

-- @table POLAR_rcenter:pft_resource_amount_operation_track
-- @at 2026-11-27 15:07:38
CREATE TABLE `pft_resource_amount_operation_track` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `member_id` int(10) NOT NULL DEFAULT '0' COMMENT '用户id',
  `trad_member_id` int(10) NOT NULL DEFAULT '0' COMMENT '交易对方用户id',
  `ordernum` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '订单号',
  `serial_num` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '流水号',
  `money` int(10) NOT NULL DEFAULT '0' COMMENT '操作金额',
  `balance` int(10) NOT NULL DEFAULT '0' COMMENT '余额',
  `op_type` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '操作类型:0=下单,1=充值,2=扣款,3=退保审核,4=退款,5=拒绝退款',
  `track_type` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '追踪记录类型: 0=保证金追踪记录类型',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `opid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '操作用户',
  `msg` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '备注信息',
  `img_path` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '图片地址',
  PRIMARY KEY (`id`),
  KEY `idx_member_id` (`member_id`),
  KEY `idx_ordernum` (`ordernum`)
) ENGINE=InnoDB AUTO_INCREMENT=11777 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心用户金额操作追踪记录';

-- @table POLAR_rcenter:pft_resource_land
-- @at 2026-11-27 15:07:51
CREATE TABLE `pft_resource_land` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `lid` int(10) NOT NULL DEFAULT '0' COMMENT '景区id',
  `land_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '景区名称',
  `land_level` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '0' COMMENT '景区级别',
  `city_code` int(10) NOT NULL DEFAULT '0' COMMENT '城市编码',
  `province_code` int(10) NOT NULL DEFAULT '0' COMMENT '省份编码',
  `p_type` char(1) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '景区类型:A景区B线路C酒店F套票',
  `topic` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '0' COMMENT '产品主题',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `relation_land_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '关联业态景区状态 0=未关联 1=已关联',
  `platform_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '平台状态:1=有效,0=无效',
  `resource_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '资源中心状态:1=有效,0=无效',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  `px` int(10) NOT NULL DEFAULT '0' COMMENT '排序',
  `salesman_id` int(10) NOT NULL DEFAULT '0' COMMENT '业务员id',
  `source_sid` int(10) NOT NULL DEFAULT '0' COMMENT '最初供应商id',
  `oversea` int(1) NOT NULL DEFAULT '0' COMMENT '境外境内:0=境内,1=境外',
  `address` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '详细地址',
  `resource_id` int(10) NOT NULL DEFAULT '0' COMMENT '资源库ID',
  `land_account` decimal(10,0) NOT NULL DEFAULT '0' COMMENT '平台创建景区生成的账号',
  `imgpath` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '缩略图',
  `jtype` varchar(20) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '景区级别',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_lid_sid` (`lid`,`sid`),
  KEY `idx_sid` (`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=286314 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心景区产品表';

-- @table POLAR_rcenter:pft_resource_land_attr
-- @at 2026-11-27 15:08:05
CREATE TABLE `pft_resource_land_attr` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `lid` int(10) NOT NULL DEFAULT '0' COMMENT '景区id',
  `sales` int(10) NOT NULL DEFAULT '0' COMMENT '累计销量',
  `profit` int(10) NOT NULL DEFAULT '0' COMMENT '利润',
  `cron_time` int(10) NOT NULL DEFAULT '0' COMMENT '任务时间',
  `attr_expand` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '{}' COMMENT '产品拓展属性',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `attr_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态: 0:无效,1:有效',
  `ticket_listing_time` int(10) NOT NULL DEFAULT '0' COMMENT '景区下门票最新上架时间-用于景区列表排序使用',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  `views` int(10) NOT NULL DEFAULT '0' COMMENT '浏览数',
  `purchase_num` int(10) NOT NULL DEFAULT '0' COMMENT '景区被采购数',
  `thirty_days_sales` int(10) NOT NULL DEFAULT '0' COMMENT '近30天票销量',
  `resource_type` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '资源选项 0：未知  1：第三方 2：直签',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_lid_sid` (`lid`,`sid`),
  KEY `idx_profit` (`profit`),
  KEY `idx_sales` (`sales`),
  KEY `idx_ticket_listing_time` (`ticket_listing_time`)
) ENGINE=InnoDB AUTO_INCREMENT=317236 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心景区拓展表';

-- @table POLAR_rcenter:pft_resource_ota_prohibit_confing
-- @at 2026-11-27 15:08:16
CREATE TABLE `pft_resource_ota_prohibit_confing` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT 'ota用户id',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品id',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `confing_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态: 0:无效,1:有效',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_sid_fid_pid` (`sid`,`fid`,`pid`),
  KEY `idx_pid` (`pid`)
) ENGINE=InnoDB AUTO_INCREMENT=319449 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心供应商禁售OTA用户配置';

-- @table POLAR_rcenter:pft_resource_product
-- @at 2026-11-27 15:08:52
-- @cmt id 主键ID
-- @cmt pay 支付方式 1：在线支付，2：一卡通支付，3：现金支付
CREATE TABLE `pft_resource_product` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品pid',
  `ticket_id` int(10) NOT NULL DEFAULT '0' COMMENT '票id',
  `lid` int(10) NOT NULL DEFAULT '0' COMMENT '景区id',
  `price_spread` int(10) NOT NULL DEFAULT '0' COMMENT '分销差价',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否还分销在资源中心:1=是,0=不是',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  `max_expiration_date` date NOT NULL DEFAULT '1970-01-01' COMMENT '门票过期最大日期',
  `shop` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '销售渠道',
  `platform_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '平台状态:1=有效,0=无效',
  `ddays` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '提前下单间隔时间',
  `dhour` varchar(8) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '23:59' COMMENT '提前下单截止日具体时间 (时:分:秒)12:12:12（线路）',
  `refund_rule` tinyint(1) NOT NULL DEFAULT '0' COMMENT '退票规则：0=有效期内可退 ： 未使用订单末级分销商可退；过期订单供应商可退，1=游玩日期内可退，阶梯退：未使用订单末级分销商可退；过期订单供应商可退 2=不可退：分销商供应商都不可退 3=随时退：未使用订单末级分销商可退；过期订单分销商可退，供应商可退。-1=不可退且是可提现',
  `ticket_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '门票名称',
  `px` int(10) NOT NULL DEFAULT '0' COMMENT '排序',
  `billing_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '开票状态 0:无,1:可开发票,2:不可开票,3景区对客户开票',
  `pre_sale` tinyint(1) NOT NULL DEFAULT '0' COMMENT '期票标识：是否预售 0:否 1:是',
  `order_flag` tinyint(1) NOT NULL DEFAULT '0' COMMENT '产品订单类型标识:0=通用,1=团队订单',
  `pay` tinyint(1) NOT NULL DEFAULT '0' COMMENT '支付方式 1：在线支付，2：一卡通支付，3：现金支付 ',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_sid_pid` (`sid`,`pid`),
  KEY `idx_pid` (`pid`),
  KEY `idx_ticket_id` (`ticket_id`),
  KEY `idx_lid_sid` (`lid`,`sid`),
  KEY `idx_status_platform_expire_sid_lid` (`status`,`platform_status`,`max_expiration_date`,`sid`,`lid`)
) ENGINE=InnoDB AUTO_INCREMENT=3320489 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心产品表';

-- @table POLAR_rcenter:pft_resource_product_record
-- @at 2026-11-27 15:08:44
-- @cmt id 主键ID
CREATE TABLE `pft_resource_product_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `operator_id` int(10) NOT NULL COMMENT '操作者id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品pid',
  `operate_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0=下架,1=上架,2=修改',
  `daction` text CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '操作内容 json格式 ,[{"field":"fieldName","newValue":"","origValue":""}]',
  `record_time` datetime NOT NULL COMMENT '记录时间',
  PRIMARY KEY (`id`),
  KEY `idx_sid_pid` (`sid`,`pid`),
  KEY `idx_record_time` (`record_time`)
) ENGINE=InnoDB AUTO_INCREMENT=39468263 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心资源变更操作日志';

-- @table POLAR_rcenter:pft_resource_purchase
-- @at 2026-11-27 15:09:14
-- @cmt id 主键ID
CREATE TABLE `pft_resource_purchase` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '采购分销商id',
  `ticket_id` int(10) NOT NULL DEFAULT '0' COMMENT '票id',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品pid',
  `insert_time` int(10) NOT NULL DEFAULT '0' COMMENT '采购时间',
  `status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已采购:1=是,0=不是',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  `price_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '采购价格是否相同：1=相同,0=不同',
  `source` int(10) NOT NULL DEFAULT '0' COMMENT '采购来源：0=其他，1=资源包采购',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_sid_fid_pid` (`sid`,`fid`,`pid`),
  KEY `idx_pid` (`pid`),
  KEY `idx_fid` (`fid`),
  KEY `idx_ticket_id` (`ticket_id`),
  KEY `idx_fid_status_sid_pid` (`fid`,`status`,`sid`,`pid`)
) ENGINE=InnoDB AUTO_INCREMENT=26083629 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心产品采购表';

-- @table POLAR_rcenter:pft_resource_purchase_recode_list
-- @at 2026-11-27 15:09:32
-- @cmt id 主键ID
CREATE TABLE `pft_resource_purchase_recode_list` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '用户id',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品pid',
  `ticket_id` int(10) NOT NULL DEFAULT '0' COMMENT '票id',
  `price_spread` int(10) NOT NULL DEFAULT '0' COMMENT '分销差价',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除成功:2=待采购,1=成功,0=不成功',
  `reason` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '采购失败原因',
  `group_ids` varchar(512) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '自动给分销商分销的分组列表:格式1,2',
  `all_distributor` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否默认分销给所有分销商 0=否 1=是',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  `operation_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0:根据采购规则自动采购,1:根据采购规则手动采购',
  `rule_id` int(10) NOT NULL DEFAULT '0' COMMENT '采购规则id',
  PRIMARY KEY (`id`),
  KEY `idx_fid_sid_pid` (`fid`,`sid`,`pid`),
  KEY `idx_pid` (`pid`),
  KEY `idx_ticket_id` (`ticket_id`)
) ENGINE=InnoDB AUTO_INCREMENT=139264334 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心产品表采购记录-历史记录';

-- @table POLAR_rcenter:pft_resource_recommend_config
-- @at 2026-11-27 15:09:44
CREATE TABLE `pft_resource_recommend_config` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `title` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '推荐名称',
  `url_path` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '网址路径',
  `subheading` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '副标题',
  `min_img` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '小图路径',
  `max_img` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '大图路径',
  `title_img` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '标题图片路径',
  `place` tinyint(1) NOT NULL DEFAULT '0' COMMENT '位置:0=top,1=right,2=left,3=bottom',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `recommend_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '推荐状态:1=推荐首页,0=其他',
  `index_num` int(2) NOT NULL DEFAULT '0' COMMENT '首页推荐数量',
  `enabled_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态:0=失效专题,1=普通专题,2=地区推荐专题',
  `delete_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '删除状态:1=是,0=不是',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  `channel` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '推荐渠道:1=旅游小店,2=资源包',
  `recommend_describe` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '专题描述',
  `price` int(10) NOT NULL DEFAULT '0' COMMENT '售价',
  `expiry` int(10) NOT NULL DEFAULT '0' COMMENT '有效期（年）',
  `province_code` bigint(12) NOT NULL DEFAULT '0' COMMENT '专题地区编码（大于0时，表示地区推荐专题）',
  PRIMARY KEY (`id`),
  KEY `idx_place` (`place`)
) ENGINE=InnoDB AUTO_INCREMENT=237 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心推荐产品配置';

-- @table POLAR_rcenter:pft_resource_recommend_land
-- @at 2026-11-27 15:10:00
CREATE TABLE `pft_resource_recommend_land` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(11) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `lid` int(11) NOT NULL DEFAULT '0' COMMENT '景区id',
  `recommend_id` int(11) NOT NULL DEFAULT '0' COMMENT '资源中心推荐产品配置表id',
  `px` int(4) NOT NULL DEFAULT '0' COMMENT '排序',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `enabled_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '启用状态:1=是,0=不是',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  PRIMARY KEY (`id`),
  KEY `idx_recommend_id` (`recommend_id`),
  KEY `idx_lid_sid` (`lid`,`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=40690 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心推荐景区表';

-- @table POLAR_rcenter:pft_resource_recommend_product
-- @at 2026-11-27 15:10:15
CREATE TABLE `pft_resource_recommend_product` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `rp_id` int(11) NOT NULL DEFAULT '0' COMMENT '资源中心产品表id',
  `recommend_id` int(11) NOT NULL DEFAULT '0' COMMENT '资源中心推荐产品配置表id',
  `px` int(4) NOT NULL DEFAULT '0' COMMENT '排序',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `enabled_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '启用状态:1=是,0=不是',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  PRIMARY KEY (`id`),
  KEY `idx_rp_id` (`rp_id`),
  KEY `idx_recommend_id` (`recommend_id`)
) ENGINE=InnoDB AUTO_INCREMENT=861 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心推荐产品表';

-- @table POLAR_rcenter:pft_resource_salesman_log
-- @at 2026-11-27 15:10:27
CREATE TABLE `pft_resource_salesman_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `lid` int(10) NOT NULL DEFAULT '0' COMMENT '景区id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `salesman_id` int(10) NOT NULL DEFAULT '0' COMMENT '业务员',
  `resource_type` int(10) NOT NULL DEFAULT '0' COMMENT '资源选项',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11362 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='产品管理业务员资源历史表';

-- @table POLAR_rcenter:pft_resource_search_history
-- @at 2026-11-27 15:10:39
CREATE TABLE `pft_resource_search_history` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `member_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '用户id',
  `shop` tinyint(1) NOT NULL DEFAULT '0' COMMENT '渠道',
  `key_word` varchar(512) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '搜索关键字',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `search_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '搜索类型 1:景区 2:门票',
  PRIMARY KEY (`id`),
  KEY `idx_member_id` (`member_id`)
) ENGINE=InnoDB AUTO_INCREMENT=902539 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心搜索历史表';

-- @table POLAR_rcenter:pft_resource_supplier_attr
-- @at 2026-11-27 15:10:54
CREATE TABLE `pft_resource_supplier_attr` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `sales` int(10) NOT NULL DEFAULT '0' COMMENT '累计销量',
  `cron_time` int(10) NOT NULL DEFAULT '0' COMMENT '任务时间',
  `attr_expand` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '{}' COMMENT '拓展属性',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `attr_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态: 0:无效,1:有效',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  `settled_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT '入驻状态 0:未入驻,1:已入驻',
  `settled_time` int(10) NOT NULL DEFAULT '0' COMMENT '供货商入驻时间 等于0时未入驻',
  `purchase_settled_time` int(10) NOT NULL DEFAULT '0' COMMENT '采购商入驻时间 等于0时未入驻',
  `index_push_time` int(10) NOT NULL DEFAULT '0' COMMENT '首页推荐时间',
  `last_province` int(10) NOT NULL DEFAULT '0' COMMENT '最后选择的省份',
  `certi_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '资源中心资质认证状态0:未认证,1:已认证',
  `supplier_num` int(10) NOT NULL DEFAULT '0' COMMENT '累计供应数',
  `purchase_num` int(10) NOT NULL DEFAULT '0' COMMENT '累计被采购数',
  `enjoyAlone_product_push` tinyint(1) NOT NULL DEFAULT '0' COMMENT '资源中心专享产品推送状态 0未推送,1:已推送',
  `open_time` int(10) NOT NULL DEFAULT '0' COMMENT '开通时间',
  `end_time` int(10) NOT NULL DEFAULT '0' COMMENT '结束时间',
  `bond_sate` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '保证金状态 0:未缴纳,1:已缴纳,2:部分缴纳',
  `supply_guide_state` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '供应引导状态: 0=未引导,1=已引导',
  `index_function_guide_state` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '首页功能引导状态: 0=未引导,1=已引导',
  `sup_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '会员类型:0=供应商,1=分销商,2=直接供应方,3=合并终端后的资源方,5=普通用户,6=员工,7=集团帐号,9=平台帐号',
  `sup_name` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '用户名称',
  `cname` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '联系人姓名',
  `head_photo` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '用户头像',
  `member_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态：0正常1禁用2删除3未审核',
  `account` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '登录帐号供应商:100000~199999=分销商:200000~599999 直接供应方:600000~999999 普通用户:手机号 平台帐号:admin 员工帐号:4位~12位英文或数字 集团帐号1000~9999',
  `account_id` int(10) NOT NULL DEFAULT '0' COMMENT '用户所使用的支付账户ID',
  `mobile` varchar(11) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '手机号码',
  `group_id` smallint(5) NOT NULL DEFAULT '0' COMMENT '会员分组,由admin配置;默认为1票付通组;2测试组;3点餐组;4云顶;5鼓浪屿；6签约账户',
  `city_code` bigint(12) NOT NULL DEFAULT '0' COMMENT '公司所在地城市编号',
  `province_code` bigint(12) NOT NULL DEFAULT '0' COMMENT '公司所在地省份编号',
  `hotline` varchar(32) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '热线电话',
  `com_name` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' COMMENT '公司名称',
  `customer_id` int(10) NOT NULL DEFAULT '0' COMMENT '客户id',
  `ota_state` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'OTA账号状态:0=不是,1=是',
  `copartner_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '合伙人状态:0=不是,1=是',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=15165 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心供应商拓展表';

-- @table POLAR_rcenter:pft_resource_user_function
-- @at 2026-11-27 15:11:07
CREATE TABLE `pft_resource_user_function` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `function_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '资源中心功能类型,0=无,1=专享功能,2=旅游小店,3=供应商,4=采购商,5=资源包',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `product_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '状态:1=有效,0=无效',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  `user_function_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '资源中心功能类型,0=管理后台配置类型,1=套餐类型',
  `start_time` int(10) NOT NULL DEFAULT '0' COMMENT '开始时间',
  `end_time` int(10) NOT NULL DEFAULT '0' COMMENT '结束时间',
  `copartner_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '合伙人状态:0=不是,1=是',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=7746 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='资源中心用户功能表';

-- @table RDS_BI_Business:company_report_date
-- @at 2026-11-27 16:04:14
-- @cmt end_date 预计结束时间
-- @cmt start_date 预计开始时间
-- @cmt stat_month 统计月份
CREATE TABLE `company_report_date` (
  `stat_month` varchar(7) DEFAULT NULL,
  `start_date` datetime DEFAULT NULL,
  `end_date` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table RDS_BI_Business:culture_tourism_business_opportunity_input
-- @at 2026-11-27 16:04:25
CREATE TABLE `culture_tourism_business_opportunity_input` (
  `user_id` varchar(255) DEFAULT NULL COMMENT '商户ID',
  `belong_area` varchar(20) DEFAULT NULL COMMENT '所属大区',
  `customer_manage` varchar(20) DEFAULT NULL COMMENT '客户经理',
  `value_add_service` varchar(255) DEFAULT NULL COMMENT '增值业务',
  `scenic_name` varchar(255) DEFAULT NULL COMMENT '景区名称',
  `scenic_company_name` varchar(255) DEFAULT NULL COMMENT '景区公司名称',
  `contract_party_a_name` varchar(255) DEFAULT NULL COMMENT '合同甲方名称',
  `subject_name` varchar(255) DEFAULT NULL COMMENT '项目名称',
  `province` varchar(255) DEFAULT NULL COMMENT '省份',
  `city` varchar(255) DEFAULT NULL COMMENT '地市',
  `cooperation_business_pwxt` int(2) DEFAULT NULL COMMENT '合作业务内容-票务系统（有合作意向填1）',
  `cooperation_business_cylsxt` int(2) DEFAULT NULL COMMENT '合作业务内容-餐饮零售系统（有合作意向填1）',
  `cooperation_business_qtjc` int(2) DEFAULT NULL COMMENT '合作业务内容-其它集成（有合作意向填1）',
  `cooperation_business_zzcp` int(2) DEFAULT NULL COMMENT '合作业务内容-增值产品（有合作意向填1）',
  `cooperation_business_zhdl` int(2) DEFAULT NULL COMMENT '合作业务内容-智慧导览（有合作意向填1）',
  `cooperation_business_wb` int(2) DEFAULT NULL COMMENT '合作业务内容-维保（有合作意向填1）',
  `forcast_money` varchar(255) DEFAULT NULL COMMENT '预计金额(元)',
  `business_type` varchar(255) DEFAULT NULL COMMENT '业务类型',
  `third_party_contribution` varchar(255) DEFAULT NULL COMMENT '第三方出资',
  `meituan` varchar(255) DEFAULT NULL COMMENT '美团',
  `business_level` varchar(255) DEFAULT NULL COMMENT '商机阶段',
  `forcast_sign_month` varchar(20) DEFAULT NULL COMMENT '预计签单月',
  `contacts_name` varchar(255) DEFAULT NULL COMMENT '联系人姓名',
  `contacts_job` varchar(255) DEFAULT NULL COMMENT '联系人职务',
  `contacts_mobile` varchar(255) DEFAULT NULL COMMENT '联系方式'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='文旅部商机信息看板';

-- @table RDS_BI_Business:culture_tourism_task_input
-- @at 2026-11-27 16:04:35
CREATE TABLE `culture_tourism_task_input` (
  `oper_year` varchar(20) DEFAULT NULL COMMENT '年',
  `team` varchar(20) DEFAULT NULL COMMENT '大区',
  `user_name` varchar(20) DEFAULT NULL COMMENT '人员',
  `task_type` varchar(255) NOT NULL COMMENT '任务类型',
  `january` decimal(16,3) DEFAULT NULL COMMENT '一月',
  `february` decimal(16,3) DEFAULT NULL COMMENT '二月',
  `march` decimal(16,3) DEFAULT NULL COMMENT '三月',
  `April` decimal(16,3) DEFAULT NULL COMMENT '四月',
  `May` decimal(16,3) DEFAULT NULL COMMENT '五月',
  `June` decimal(16,3) DEFAULT NULL COMMENT '六月',
  `July` decimal(16,3) DEFAULT NULL COMMENT '7月',
  `August` decimal(16,3) DEFAULT NULL COMMENT '8月',
  `September` decimal(16,3) DEFAULT NULL COMMENT '9月',
  `October` decimal(16,3) DEFAULT NULL COMMENT '10月',
  `November` decimal(16,3) DEFAULT NULL COMMENT '11月',
  `December` decimal(16,3) DEFAULT NULL COMMENT '12月'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='文旅部任务情况填报表';

-- @table RDS_BI_Business:dim_user_layering
-- @at 2026-11-27 16:04:47
CREATE TABLE `dim_user_layering` (
  `userid` int(10) NOT NULL COMMENT '商户id',
  `layering` varchar(255) NOT NULL COMMENT '商户价值',
  `oper_date` varchar(40) NOT NULL COMMENT '统计月（自然季度开始月）',
  `use_12301page_num` int(4) NOT NULL DEFAULT '0' COMMENT '自然季度使用12301页面数'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table RDS_BI_Business:package_history
-- @at 2026-11-27 16:05:09
-- @cmt add_time 供应商+产品最早上架资源中心票的时间
-- @cmt cooper_month 合作月份
-- @cmt cooper_price 合作价格
-- @cmt cooper_year 合作年份
-- @cmt cooperation 合作
-- @cmt end_time 结束时间
-- @cmt id 主键ID
-- @cmt remark 备注
-- @cmt start_time 开始服务日期
-- @cmt user_id 用户id
CREATE TABLE `package_history` (
  `user_id` int(10) DEFAULT NULL,
  `cooperation` varchar(20) DEFAULT NULL,
  `cooper_price` int(10) DEFAULT NULL,
  `cooper_year` int(4) DEFAULT NULL,
  `cooper_month` int(10) DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `add_time` datetime DEFAULT NULL,
  `remark` varchar(255) DEFAULT NULL,
  `id` int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2705 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table RDS_BI_Business:package_open_type
-- @at 2026-11-27 16:05:21
CREATE TABLE `package_open_type` (
  `package_open_type_id` int(11) NOT NULL COMMENT '套餐开通类型',
  `type_name` varchar(255) DEFAULT NULL COMMENT '类型名称',
  `catalogue` varchar(255) DEFAULT NULL COMMENT '分类',
  PRIMARY KEY (`package_open_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table RDS_BI_Business:quarter_first_date
-- @at 2026-11-27 16:05:34
CREATE TABLE `quarter_first_date` (
  `quarter` varchar(255) DEFAULT NULL COMMENT '季度',
  `quarter_first_date` date DEFAULT NULL COMMENT '季度首日'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table RDS_BI_Business:resource_center_auto_get_user
-- @at 2026-11-27 16:05:46
CREATE TABLE `resource_center_auto_get_user` (
  `user_id` int(11) NOT NULL COMMENT '资源中心自动拉取商户ID',
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table RDS_BI_Business:resource_center_district
-- @at 2026-11-27 16:05:58
CREATE TABLE `resource_center_district` (
  `district` varchar(50) DEFAULT NULL COMMENT '区域',
  `province` varchar(50) DEFAULT NULL COMMENT '省',
  `authority_code` varchar(50) DEFAULT NULL COMMENT '权限控制编码',
  `import_province` int(2) DEFAULT NULL COMMENT '1-重点关注省'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table RDS_BI_Business:third_purchase_system
-- @at 2026-11-27 16:06:11
CREATE TABLE `third_purchase_system` (
  `coopB` int(4) NOT NULL COMMENT '第三方采购系统ID',
  `system_name` varchar(50) DEFAULT NULL COMMENT '系统名称，不同版本系统名称会相同',
  PRIMARY KEY (`coopB`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table RDS_crm_erp:achievement_detail_pub
-- @at 2026-11-27 11:34:28
CREATE TABLE `achievement_detail_pub` (
  `dept_name` varchar(255) DEFAULT NULL COMMENT '一级部门名称',
  `dept_name_level2` varchar(255) DEFAULT NULL COMMENT '二级部门名称',
  `owner__r` varchar(255) DEFAULT NULL COMMENT '负责人',
  `account_id__r` varchar(255) DEFAULT NULL COMMENT '客户名称',
  `order_amount` varchar(255) DEFAULT NULL COMMENT '销售金额',
  `payment_amount` varchar(255) DEFAULT NULL COMMENT '已回款金额',
  `order_time` varchar(255) DEFAULT NULL COMMENT '签约时间',
  `srlx` varchar(255) DEFAULT NULL COMMENT '收入类型',
  `lxmx` varchar(255) DEFAULT NULL COMMENT '类型明细',
  `htbh` varchar(255) DEFAULT NULL COMMENT '合同编号',
  `receipt_amount` varchar(255) DEFAULT NULL COMMENT '已开票金额',
  `no_receipt_amount` varchar(255) DEFAULT NULL COMMENT '待开票金额',
  `receipt_status` varchar(255) DEFAULT NULL COMMENT '开票完成状态',
  `returned_goods_amount` varchar(255) DEFAULT NULL COMMENT '退货单金额',
  `refund_amount` varchar(255) DEFAULT NULL COMMENT '已退货金额',
  `product_amount` varchar(255) DEFAULT NULL COMMENT '产品合计',
  `yfk` varchar(255) DEFAULT NULL COMMENT '预付款',
  `arrival_amount` varchar(255) DEFAULT NULL COMMENT '到货款',
  `contract_property` varchar(255) DEFAULT NULL COMMENT '合同属性',
  `field_m9n8u__c` varchar(255) DEFAULT NULL COMMENT '纯软件/软件+硬件',
  `field_2uy29__c` varchar(255) DEFAULT NULL COMMENT '客户类型',
  `province` varchar(255) DEFAULT NULL COMMENT '省份',
  `city` varchar(255) DEFAULT NULL COMMENT '城市',
  `address` varchar(255) DEFAULT NULL COMMENT '地址',
  `data_own_department` varchar(255) DEFAULT NULL COMMENT '归属部门',
  `new_opportunity_id` varchar(255) DEFAULT NULL COMMENT '商机ID',
  `new_opportunity_name` varchar(255) DEFAULT NULL COMMENT '商机名称',
  `owner_department` varchar(255) DEFAULT NULL COMMENT '负责人归属部门',
  `owner_department_id` varchar(255) DEFAULT NULL COMMENT '负责人归属部门-id',
  `land_type` varchar(255) DEFAULT NULL COMMENT '景区类型',
  `dept_name_id` varchar(255) DEFAULT NULL COMMENT '负责人归属一级部门ID',
  `dept_name_id_level2` varchar(255) DEFAULT NULL COMMENT '负责人归属二级部门ID',
  `sfgb` varchar(255) DEFAULT NULL COMMENT '是否共背',
  `gbr` varchar(255) DEFAULT NULL COMMENT '共背人',
  `last_modified_time` varchar(255) DEFAULT NULL COMMENT '最后修改时间',
  `create_time` varchar(255) DEFAULT NULL COMMENT '创建时间',
  `life_status` varchar(255) DEFAULT NULL COMMENT '生命状态',
  `created` varchar(255) DEFAULT NULL COMMENT '创建人',
  `relevant_team__r` varchar(255) DEFAULT NULL COMMENT '相关团队',
  `htztai__c` varchar(255) DEFAULT NULL COMMENT '合同状态',
  `is_deleted` varchar(255) DEFAULT NULL COMMENT '是否删除',
  `kccov__c` varchar(255) DEFAULT NULL COMMENT '平台账号',
  `field_xtkpe__c` varchar(255) DEFAULT NULL COMMENT '合同开始时间',
  `field_pgsdj__c` varchar(255) DEFAULT NULL COMMENT '合同结束时间',
  `order_status` varchar(255) DEFAULT NULL COMMENT '订单状态',
  `gbr_name` varchar(255) DEFAULT NULL COMMENT '共背人姓名',
  `gbr_dept_name` varchar(255) DEFAULT NULL COMMENT '共背人一级部门名称',
  `gbr_dept_name_level2` varchar(255) DEFAULT NULL COMMENT '共背人二级部门名称',
  `account_type` varchar(255) DEFAULT NULL COMMENT '客户分类',
  `land_level` varchar(255) DEFAULT NULL COMMENT '景区等级',
  `account_level` varchar(255) DEFAULT NULL COMMENT '客户类型',
  `platform_id` varchar(255) DEFAULT NULL COMMENT '平台ID',
  `account_id` varchar(255) DEFAULT NULL COMMENT '客户ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='签约业绩-明细表';

-- @table RDS_crm_erp:dim_new_opportunity_mapping
-- @at 2026-11-27 11:37:23
-- @cmt data_own_department__r 部门
-- @cmt mark 映射部门
CREATE TABLE `dim_new_opportunity_mapping` (
  `data_own_department__r` varchar(255) DEFAULT NULL COMMENT '部门',
  `mark` varchar(255) DEFAULT NULL COMMENT '映射部门'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- @table RDS_crm_erp:erp_ys
-- @at 2026-11-27 11:38:01
CREATE TABLE `erp_YS` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `vbillcode` varchar(30) DEFAULT '' COMMENT '单据号',
  `customer` varchar(30) DEFAULT '' COMMENT '客商',
  `department` varchar(30) DEFAULT '' COMMENT '部门',
  `amt` varchar(30) DEFAULT '' COMMENT '原币金额',
  `notes` varchar(30) DEFAULT '' COMMENT '备注',
  `documentdate` varchar(30) DEFAULT '' COMMENT '单据日期',
  `productid` varchar(30) DEFAULT '' COMMENT '产品id',
  `op1` varchar(100) DEFAULT '' COMMENT 'op1',
  `op2` varchar(100) DEFAULT '' COMMENT 'op2',
  `op3` varchar(100) DEFAULT '' COMMENT 'op3',
  `op4` varchar(100) DEFAULT '' COMMENT 'op4',
  `taxSum` varchar(30) DEFAULT NULL COMMENT '税额',
  `stage_money` varchar(30) DEFAULT NULL COMMENT '分期金额',
  `history` tinyint(1) NOT NULL DEFAULT '0' COMMENT '历史',
  `hc` tinyint(1) NOT NULL DEFAULT '0' COMMENT '红冲',
  `create_date` varchar(30) DEFAULT '' COMMENT '创建日期',
  `is_last` tinyint(1) DEFAULT NULL COMMENT '是否最后一期',
  PRIMARY KEY (`id`),
  KEY `idx_vbillcode` (`vbillcode`),
  KEY `idx_documentdate` (`documentdate`)
) ENGINE=InnoDB AUTO_INCREMENT=125424 DEFAULT CHARSET=utf8mb4 COMMENT='erp应收单据管理-crm分期';

-- @table RDS_crm_erp:pft_crm_account
-- @at 2026-11-27 11:38:35
CREATE TABLE `pft_crm_account` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '客户名称',
  `field_41liw__c` varchar(10) NOT NULL DEFAULT '' COMMENT '客户属性',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `account_type` varchar(10) NOT NULL DEFAULT '' COMMENT '客户分类',
  `phone_number_attribution_city` varchar(20) NOT NULL DEFAULT '' COMMENT '电话归属市编码',
  `phone_number_attribution_city__r` varchar(20) NOT NULL DEFAULT '' COMMENT '电话归属市名称',
  `province` varchar(10) NOT NULL DEFAULT '' COMMENT '省份编号',
  `province__r` varchar(10) NOT NULL DEFAULT '' COMMENT '省份名称',
  `tel` varchar(50) NOT NULL DEFAULT '' COMMENT '电话',
  `field_f2192__c` varchar(100) NOT NULL DEFAULT '' COMMENT '与竞品合作原因',
  `biz_status` varchar(20) NOT NULL DEFAULT '' COMMENT '分配状态',
  `key_world` varchar(100) NOT NULL DEFAULT '' COMMENT '景区关键词',
  `back_reason` varchar(30) NOT NULL DEFAULT '' COMMENT '销售人员退回原因',
  `field_0w21l__c` varchar(100) NOT NULL DEFAULT '' COMMENT '平台账号/ID/手机',
  `field_3o2h7__c` varchar(30) NOT NULL DEFAULT '' COMMENT '线下合作竞品(禁用)',
  `field_tdfig__c` varchar(1000) NOT NULL DEFAULT '' COMMENT '最近跟进内容',
  `field_nz4yo__c` varchar(50) NOT NULL DEFAULT '' COMMENT '主营类目',
  `city` varchar(20) NOT NULL DEFAULT '' COMMENT '市编码',
  `city__r` varchar(20) NOT NULL DEFAULT '' COMMENT '市名称',
  `field_5q3iq__c` varchar(20) NOT NULL DEFAULT '' COMMENT '旅行社类型',
  `phone_number_attribution_country` varchar(20) NOT NULL DEFAULT '' COMMENT '电话归属国家编码',
  `phone_number_attribution_country__r` varchar(20) NOT NULL DEFAULT '' COMMENT '电话归属国家名称',
  `last_follower` varchar(20) NOT NULL DEFAULT '' COMMENT '最后跟进人',
  `field_pqss9__c` varchar(20) NOT NULL DEFAULT '' COMMENT '旅行社客群',
  `is_er_enterprise` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否关联对接企业',
  `field_r1qr3__c__r` varchar(30) NOT NULL DEFAULT '' COMMENT '客户转移人',
  `field_k678b__c` tinyint(1) NOT NULL DEFAULT '0' COMMENT '景区是否收费',
  `deal_status` varchar(30) NOT NULL DEFAULT '' COMMENT '成交状态',
  `address` varchar(100) NOT NULL DEFAULT '' COMMENT '详细地址',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `field_4h84y__c` varchar(20) NOT NULL DEFAULT '' COMMENT '景区类型',
  `transfer_count` varchar(20) NOT NULL DEFAULT '' COMMENT '转手次数',
  `country` varchar(20) NOT NULL DEFAULT '' COMMENT '国家编号',
  `country__r` varchar(20) NOT NULL DEFAULT '' COMMENT '国家名称',
  `biz_reg_name` varchar(20) NOT NULL DEFAULT '' COMMENT '工商注册',
  `account_status` varchar(20) NOT NULL DEFAULT '' COMMENT '状态（原）',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除',
  `last_deal_closed_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后一次成交时间',
  `completed_field_quantity` varchar(20) NOT NULL DEFAULT '' COMMENT '完成字段总数',
  `phone_number_attribution_province` varchar(20) NOT NULL DEFAULT '' COMMENT '电话归属省份',
  `phone_number_attribution_province__r` varchar(20) NOT NULL DEFAULT '' COMMENT '电话归属省份名称',
  `owner_department` varchar(20) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `high_seas_id__r` varchar(30) NOT NULL DEFAULT '' COMMENT '所属公海',
  `last_followed_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后跟进时间',
  `created_by__l` varchar(10) NOT NULL DEFAULT '' COMMENT '创建人',
  `relevant_team__r` varchar(150) NOT NULL DEFAULT '' COMMENT '相关团队',
  `data_own_department` varchar(100) DEFAULT '' COMMENT '归属部门',
  `field_Z4La2__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '客户转移时间',
  `district` varchar(30) NOT NULL DEFAULT '' COMMENT '区编码',
  `district__r` varchar(30) NOT NULL DEFAULT '' COMMENT '区名称',
  `field_t72i6__c` varchar(300) NOT NULL DEFAULT '' COMMENT '线上合作竞品',
  `field_tkx02__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '首签成单日期',
  `account_level` varchar(30) NOT NULL DEFAULT '' COMMENT '客户类型',
  `remark` varchar(500) NOT NULL DEFAULT '' COMMENT '备注',
  `leads_id` varchar(30) NOT NULL DEFAULT '' COMMENT '源线索id',
  `leads_id__r` varchar(30) NOT NULL DEFAULT '' COMMENT '源线索',
  `owner__r` varchar(100) DEFAULT '' COMMENT '负责人',
  `recycled_reason` varchar(100) NOT NULL DEFAULT '' COMMENT '退回/收回原因',
  `last_modified_by__r` varchar(100) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `record_type` varchar(100) NOT NULL DEFAULT '' COMMENT '业务类型',
  `field_r13cs__c` varchar(100) NOT NULL DEFAULT '' COMMENT '历史负责人',
  `owner_modified_time` varchar(100) NOT NULL DEFAULT '' COMMENT '负责人变更时间',
  `location` varchar(200) NOT NULL DEFAULT '' COMMENT '定位',
  `returned_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '退回/收回时间',
  `account_source` varchar(200) NOT NULL DEFAULT '' COMMENT '客户来源',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `account_no` varchar(100) NOT NULL DEFAULT '' COMMENT '客户编号',
  `field_jgcP2__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '历史创建时间',
  `field_1oLsM__c` varchar(100) NOT NULL DEFAULT '' COMMENT '历史创建人',
  `remind_days` varchar(30) NOT NULL DEFAULT '' COMMENT '回收提前提醒天数',
  `fax` varchar(100) NOT NULL DEFAULT '' COMMENT '传真',
  `field_2F24z__c` varchar(50) NOT NULL DEFAULT '' COMMENT '单日最高客流',
  `field_X3542__c` varchar(50) NOT NULL DEFAULT '' COMMENT '客情关系',
  `extend_days` varchar(30) NOT NULL DEFAULT '' COMMENT '申请延期天数',
  `phone_number_attribution_address` varchar(100) NOT NULL DEFAULT '' COMMENT '电话归属详细地址',
  `field_57egr__c` varchar(50) NOT NULL DEFAULT '' COMMENT '清洗频次',
  `field_mvq72__c` varchar(50) NOT NULL DEFAULT '' COMMENT '合作属性',
  `completion_rate` varchar(30) NOT NULL DEFAULT '' COMMENT '客户资料完善度',
  `field_eejK4__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '有效日期',
  `next_followed_remark` varchar(100) NOT NULL DEFAULT '' COMMENT '下次跟进要点',
  `field_SOJx2__c` varchar(50) NOT NULL DEFAULT '' COMMENT '合作伙伴类型',
  `field_0ut89__c` varchar(50) NOT NULL DEFAULT '' COMMENT '景区等级',
  `filling_checker_id` varchar(100) NOT NULL DEFAULT '' COMMENT '报备审核人',
  `field_R6i8i__c` varchar(100) NOT NULL DEFAULT '' COMMENT '历史负责人',
  `phone_number_attribution_district` varchar(20) NOT NULL DEFAULT '' COMMENT '电话归属区',
  `email` varchar(20) NOT NULL DEFAULT '' COMMENT '邮件',
  `uniform_social_credit_code` varchar(20) NOT NULL DEFAULT '' COMMENT '统一社会信用代码',
  `out_tenant_id` varchar(30) NOT NULL DEFAULT '' COMMENT '外部企业',
  `field_5EhT1__c` varchar(50) NOT NULL DEFAULT '' COMMENT '合作伙伴名称',
  `url` varchar(50) NOT NULL DEFAULT '' COMMENT '网址',
  `claimed_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '领取/分配时间',
  `enterprise_wechat_user_id` varchar(50) NOT NULL DEFAULT '' COMMENT '企业微信UserId',
  `field_vJj2v__c` varchar(50) NOT NULL DEFAULT '' COMMENT '市场活动名称',
  `field_dNomd__c` varchar(50) NOT NULL DEFAULT '' COMMENT '最新商机阶段',
  `total_refund_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '退款总额',
  `high_seas_name` varchar(30) NOT NULL DEFAULT '' COMMENT '所属公海（名称）',
  `next_followed_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '下次跟进时间',
  `field_uVa0R__c` varchar(50) NOT NULL DEFAULT '' COMMENT '年总客流',
  `pin_yin` varchar(400) NOT NULL DEFAULT '' COMMENT '名字拼写',
  `poi_information` varchar(100) NOT NULL DEFAULT '' COMMENT 'POI信息',
  `field_aotKy__c` varchar(30) NOT NULL DEFAULT '' COMMENT '介绍方客户',
  `area_location` varchar(100) NOT NULL DEFAULT '' COMMENT '地区定位',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `last_deal_closed_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '最后一次成交金额',
  `expire_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '预计收回时间',
  `phone_number_attribution` varchar(100) NOT NULL DEFAULT '' COMMENT '电话归属地',
  `industry_ext` varchar(100) NOT NULL DEFAULT '' COMMENT '工商扩展',
  `remaining_time` varchar(20) NOT NULL DEFAULT '' COMMENT '剩余保有时间',
  `parent_account_id` varchar(50) NOT NULL DEFAULT '' COMMENT '上级客户',
  `industry_level2` varchar(30) NOT NULL DEFAULT '' COMMENT '2级',
  `industry_level1` varchar(30) NOT NULL DEFAULT '' COMMENT '1级',
  `is_remind_recycling` varchar(30) NOT NULL DEFAULT '' COMMENT '是否待回收提醒',
  `lock_user` varchar(50) NOT NULL DEFAULT '' COMMENT '加锁人',
  `field_dEOev__c` varchar(50) NOT NULL DEFAULT '' COMMENT '联系状态',
  `object_describe_api_name` varchar(100) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `out_owner` varchar(100) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `phone_number_attribution_location` varchar(100) NOT NULL DEFAULT '' COMMENT '电话归属定位',
  `field_HmG2a__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '预计联系日',
  `field_vre3G__c` varchar(100) NOT NULL DEFAULT '' COMMENT '来源明细',
  `field_3l2ev__c` varchar(30) NOT NULL DEFAULT '' COMMENT '是否进行协作操作',
  `field_RmCg5__c` varchar(100) NOT NULL DEFAULT '' COMMENT 'SDR协作人员',
  `field_Gr773__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '协作操作时间',
  `account_path` varchar(100) NOT NULL DEFAULT '' COMMENT '客户层级',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '新增时间',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '修改时间',
  `field_6hP1c__c` varchar(100) NOT NULL DEFAULT '' COMMENT '是否KP',
  `field_S2uaA__c` varchar(100) NOT NULL DEFAULT '' COMMENT '调研痛点',
  `field_IHtfw__c` varchar(100) NOT NULL DEFAULT '' COMMENT '客户身份',
  `field_nd204__c` varchar(100) NOT NULL DEFAULT '' COMMENT '推荐官姓名',
  `field_9KYpD__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '变更推荐官时间',
  `field_e63kf__c` varchar(100) NOT NULL DEFAULT '' COMMENT '推荐官公司',
  `field_7nAj1__c` varchar(50) NOT NULL DEFAULT '' COMMENT '推荐官联系电话',
  `option1` varchar(50) DEFAULT NULL COMMENT '自定义111',
  `option2` varchar(50) DEFAULT '' COMMENT '自定义2',
  `option3` varchar(50) DEFAULT '' COMMENT '自定义3',
  `option4` varchar(50) DEFAULT '' COMMENT '自定义4',
  `option5` varchar(50) DEFAULT '' COMMENT '自定义5',
  `option6` varchar(50) DEFAULT '' COMMENT '自定义6',
  `option7` varchar(50) DEFAULT '' COMMENT '自定义7',
  `option8` varchar(50) DEFAULT '' COMMENT '自定义8',
  `option9` varchar(50) DEFAULT '' COMMENT '自定义9',
  `option10` varchar(50) DEFAULT '' COMMENT '自定义10',
  `option11` varchar(50) DEFAULT '' COMMENT '自定义11',
  `option12` varchar(50) DEFAULT '' COMMENT '自定义12',
  `option13` varchar(50) DEFAULT '' COMMENT '自定义13',
  `option14` varchar(50) DEFAULT '' COMMENT '自定义14',
  `option15` varchar(50) DEFAULT '' COMMENT '自定义15',
  `field_cvdoc__c` varchar(30) DEFAULT '' COMMENT '客户分层评分',
  `field_7CZ5p__c` varchar(30) DEFAULT '' COMMENT '客户分层等级',
  `field_eqvsh__c` varchar(30) DEFAULT '' COMMENT '合作景区产品数量',
  `field_2F7CY__c` varchar(30) DEFAULT '' COMMENT '年订单量(万)',
  `field_fA2Xe__c` varchar(30) DEFAULT '' COMMENT '年客流量(万)',
  `field_9E59E__c` varchar(100) DEFAULT NULL COMMENT '线下合作竞品',
  `deptId` varchar(40) NOT NULL DEFAULT '' COMMENT 'crm部门id',
  `field_w5GSd__c` varchar(30) DEFAULT NULL COMMENT '景区客户分层数据',
  `field_8isa7__c` tinyint(1) DEFAULT NULL COMMENT '六大业态',
  `field_1P0nK__c` tinyint(1) DEFAULT NULL COMMENT '十大业态',
  `field_i4oZj__c` varchar(32) DEFAULT NULL COMMENT '合作客户分层数据',
  `field_5xc2Z__c` varchar(30) DEFAULT '' COMMENT '合同总计金额',
  `field_ylN5I__c` varchar(600) NOT NULL DEFAULT '' COMMENT '文心一言回答',
  `account_level__o` varchar(100) NOT NULL DEFAULT '' COMMENT 'account_level__o',
  `field_32fi4__c` varchar(50) DEFAULT NULL COMMENT '主数据标签',
  `customer_identity__c` varchar(50) DEFAULT NULL COMMENT '客户身份',
  `field_nCR7F__c` date DEFAULT NULL COMMENT '平台转项目时间',
  `field_t3g1q__c` date DEFAULT NULL COMMENT '第一份项目合同创建时间',
  `field_6b320__c` varchar(50) DEFAULT NULL COMMENT '来源同事',
  `field_quNoM__c` varchar(50) DEFAULT NULL COMMENT '来源业务',
  `field_Zq433__c` varchar(64) DEFAULT NULL COMMENT '最新区域CSR',
  `field_lsd32__c` varchar(32) DEFAULT NULL COMMENT '新客户分层等级',
  `initial_layer_level__c` varchar(16) DEFAULT NULL COMMENT '初次分层等级',
  PRIMARY KEY (`id`),
  KEY `idx_field_0w21l__c` (`field_0w21l__c`)
) ENGINE=InnoDB AUTO_INCREMENT=97355 DEFAULT CHARSET=utf8mb4 COMMENT='客户表';

-- @table RDS_crm_erp:pft_crm_active_record_obj
-- @at 2026-11-27 16:14:46
-- @cmt crm_id CRM ID
-- @cmt id 主键ID
-- @cmt name 名称
CREATE TABLE `pft_crm_active_record_obj` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `crm_id` varchar(64) DEFAULT NULL,
  `name` varchar(32) DEFAULT NULL,
  `active_record_type` varchar(64) DEFAULT NULL COMMENT '跟进方式',
  `field_hROh0__c` varchar(16) DEFAULT NULL COMMENT '通话状态',
  `field_7oqB8__c` varchar(16) DEFAULT NULL COMMENT '跟进类型',
  `active_record_content` text CHARACTER SET utf8mb4 COMMENT '跟进内容',
  `field_n44Do__c` text COMMENT '跟进原因',
  `field_2SqQI__c` text COMMENT '跟进结果',
  `field_fixSF__c` datetime DEFAULT NULL COMMENT '下次跟进时间',
  `field_ngo1V__c` varchar(64) DEFAULT NULL COMMENT '关联客户',
  `field_ngo1V__c__r` varchar(64) DEFAULT NULL COMMENT '关联客户名称',
  `field_2dHgQ__c` varchar(32) DEFAULT NULL COMMENT '客户属性',
  `field_3M7Yl__c` varchar(64) DEFAULT NULL COMMENT '关联销售线索',
  `field_3M7Yl__c__r` varchar(64) DEFAULT NULL COMMENT '关联销售线索名称',
  `owner` varchar(64) DEFAULT NULL COMMENT '负责人',
  `owner__r` varchar(32) DEFAULT NULL COMMENT '负责人名称',
  `owner_department` varchar(64) DEFAULT NULL COMMENT '负责人主属部门',
  `field_ag2O8__c` varchar(32) DEFAULT NULL COMMENT '职位',
  `created_by` varchar(64) DEFAULT NULL COMMENT '创建人',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `last_modified_by` varchar(64) DEFAULT NULL COMMENT '最后修改人',
  `last_modified_time` datetime DEFAULT NULL COMMENT '最后修改时间',
  `life_status` varchar(16) DEFAULT NULL COMMENT '生命状态',
  `related_object` text COMMENT '关联业务模块',
  `related_sales_opportunity__c` varchar(64) DEFAULT NULL COMMENT '关联商机',
  `related_sales_opportunity__c__r` varchar(64) DEFAULT NULL COMMENT '关联商机名称',
  PRIMARY KEY (`id`),
  KEY `idx_crm_id` (`crm_id`),
  KEY `idx_account` (`field_ngo1V__c`),
  KEY `idx_leads` (`field_3M7Yl__c`)
) ENGINE=InnoDB AUTO_INCREMENT=471696 DEFAULT CHARSET=utf8 COMMENT='crm销售记录';

-- @table RDS_crm_erp:pft_crm_cases
-- @at 2026-11-27 16:15:00
-- @cmt id 主键ID
CREATE TABLE `pft_crm_cases` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `_id` varchar(60) NOT NULL COMMENT 'crmId',
  `name` varchar(60) DEFAULT NULL COMMENT '工单编码',
  `field_y101p_c` varchar(100) DEFAULT NULL COMMENT '合同创建人',
  `field_2hO9e_c` decimal(18,2) DEFAULT NULL COMMENT '合同金额',
  `field_tNu3z_c` varchar(60) DEFAULT NULL COMMENT '市级',
  `catalog` varchar(60) DEFAULT NULL COMMENT '分类',
  `satification_comment` varchar(500) DEFAULT NULL COMMENT '用户评语',
  `field_Uvax6_c` varchar(255) DEFAULT NULL COMMENT '故障视频',
  `field_country_c` varchar(60) DEFAULT NULL COMMENT '国家',
  `reasons_for_transfer_c` varchar(500) DEFAULT NULL COMMENT '转派理由',
  `field_5Pwx6_c` varchar(255) DEFAULT NULL COMMENT '故障描述',
  `cases_state_log` varchar(255) DEFAULT NULL COMMENT '工单状态流转',
  `tel` varchar(50) DEFAULT NULL COMMENT '电话',
  `field_P6wiW_c` varchar(50) DEFAULT NULL COMMENT '是否需要备件',
  `field_hpX17_c` datetime DEFAULT NULL COMMENT '工单实际完成时间',
  `field_29P4e_c` varchar(100) DEFAULT NULL COMMENT '合同编号',
  `field_29P4e_c__r` varchar(100) DEFAULT NULL COMMENT '合同编号',
  `field_JM4uq_c` varchar(60) DEFAULT NULL COMMENT '任务类型',
  `field_2566s_c` varchar(60) DEFAULT NULL COMMENT '省份',
  `field_1b4yk_c` varchar(500) DEFAULT NULL COMMENT '工单任务描述',
  `field_e134u_c` varchar(60) DEFAULT NULL COMMENT '工单结果确认',
  `field_TMae1_c` varchar(60) DEFAULT NULL COMMENT '客户分层等级',
  `field_district_c` varchar(60) DEFAULT NULL COMMENT '区',
  `field_nt141_c` datetime DEFAULT NULL COMMENT '维保结束日期',
  `assign_way_c` varchar(60) DEFAULT NULL COMMENT '派单方式',
  `priority` varchar(50) DEFAULT NULL COMMENT '优先级',
  `field_9xxw4_c` varchar(500) DEFAULT NULL COMMENT '任务描述',
  `field_province_c` varchar(60) DEFAULT NULL COMMENT '省',
  `field_4EQwm_c` varchar(60) DEFAULT NULL COMMENT '联系人姓名',
  `field_83gg2_c` varchar(255) DEFAULT NULL COMMENT '转交处理工程师',
  `field_xcpz_c` varchar(255) DEFAULT NULL COMMENT '服务现场拍照',
  `field_b68d1_c` varchar(50) DEFAULT NULL COMMENT '是否完成交付物提交',
  `field_bT1aB_c` varchar(50) DEFAULT NULL COMMENT '是/否包含巡检保障内容',
  `field_location_c` varchar(255) DEFAULT NULL COMMENT '地址',
  `field_oZKo2_c` datetime DEFAULT NULL COMMENT '客户期望入场时间',
  `actual_time_range_c` varchar(60) DEFAULT NULL COMMENT '实际服务时间',
  `field_wy91x_c` varchar(60) DEFAULT NULL COMMENT '所属项目',
  `field_workflowStatus_c` varchar(60) DEFAULT NULL COMMENT '工单流程状态',
  `field_xcfwry_c` varchar(255) DEFAULT NULL COMMENT '支撑人',
  `field_gcjl_c` varchar(255) DEFAULT NULL COMMENT '服务过程记录',
  `field_2l54n_c` varchar(500) DEFAULT NULL COMMENT '项目详细地址（禁用）',
  `origin_source` varchar(60) DEFAULT NULL COMMENT '数据来源',
  `field_laborHour_c` decimal(10,2) DEFAULT NULL COMMENT '工时统计',
  `field_QEtgx_c` datetime DEFAULT NULL COMMENT '计划结束时间',
  `field_wa4wv_c` varchar(50) DEFAULT NULL COMMENT '是否维保内',
  `actual_end_time_c` datetime DEFAULT NULL COMMENT '实际服务结束时间',
  `field_68ys4_c` varchar(50) DEFAULT NULL COMMENT '是否涉及配件发货',
  `field_KeW2z_c` varchar(50) DEFAULT NULL COMMENT '是否接受外协',
  `field_SjG45_c` varchar(255) DEFAULT NULL COMMENT '上传客户确认单',
  `field_situation_after_service_c` varchar(500) DEFAULT NULL COMMENT '服务后情况',
  `last_modified_time` datetime DEFAULT NULL COMMENT '最后修改时间',
  `due_to_time` datetime DEFAULT NULL COMMENT '到期时间',
  `field_iO8Y2_c` decimal(10,2) DEFAULT NULL COMMENT '预计投入人天',
  `field_bY384_c` datetime DEFAULT NULL COMMENT '计划开始时间',
  `life_status` varchar(50) DEFAULT NULL COMMENT '生命状态',
  `field_awk81_c` varchar(500) DEFAULT NULL COMMENT '具体故障',
  `field_tw2m3_c` varchar(60) DEFAULT NULL COMMENT '所属阶段',
  `field_68jyi_c` varchar(50) DEFAULT NULL COMMENT '是否采购维保服务',
  `field_ioqkH_c` varchar(60) DEFAULT NULL COMMENT '工作类型',
  `field_8rESn_c` varchar(60) DEFAULT NULL COMMENT '区域',
  `field_assignStatus_c` varchar(60) DEFAULT NULL COMMENT '指派状态',
  `account_id` varchar(100) DEFAULT NULL COMMENT '客户',
  `account_id__r` varchar(100) DEFAULT NULL COMMENT '客户',
  `field_l8zA2_c` varchar(50) DEFAULT NULL COMMENT '是否区域指派',
  `field_wxAppName_c` varchar(60) DEFAULT NULL COMMENT '微信服务号',
  `satification_scores` varchar(50) DEFAULT NULL COMMENT '用户打分',
  `field_photos_after_service_c` varchar(255) DEFAULT NULL COMMENT '服务后照片',
  `cases_state` varchar(60) DEFAULT NULL COMMENT '工单状态',
  `field_8cBc4_c` datetime DEFAULT NULL COMMENT '期望解决时间',
  `field_hEG7c_c` varchar(255) DEFAULT NULL COMMENT '交付负责人',
  `field_1rv1l_c` varchar(500) DEFAULT NULL COMMENT '上传巡检/保服务单',
  `booking_time_range_c` varchar(60) DEFAULT NULL COMMENT '预约服务时间',
  `field_detail_address_c` varchar(60) DEFAULT NULL COMMENT '详细地址',
  `field_b52q8_c` varchar(50) DEFAULT NULL COMMENT '联系电话',
  `field_5ng1J_c` decimal(10,2) DEFAULT NULL COMMENT '实际花费工时',
  `subject` varchar(60) DEFAULT NULL COMMENT '主题',
  `booking_end_time_c` datetime DEFAULT NULL COMMENT '预约结束服务',
  `field_C6oi3_c` varchar(50) DEFAULT NULL COMMENT '是否包含在合同内',
  `field_city_c` varchar(60) DEFAULT NULL COMMENT '市',
  `field_8d1sn_c` varchar(500) DEFAULT NULL COMMENT '客户需求描述',
  `field_ea70i_c` varchar(255) DEFAULT NULL COMMENT '故障设备照片',
  `field_Bhk9h_c` varchar(60) DEFAULT NULL COMMENT '需求类型',
  `owner_department` varchar(60) DEFAULT NULL COMMENT '负责人所在部门',
  `assign_user` varchar(255) DEFAULT NULL COMMENT '派单员',
  `lock_status` varchar(50) DEFAULT NULL COMMENT '锁定状态',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `field_9yhtU_c` varchar(60) DEFAULT NULL COMMENT '故障设备型号',
  `plan_time_range_c` varchar(60) DEFAULT NULL COMMENT '计划服务时间',
  `field_currentTaskStartTime_c` datetime DEFAULT NULL COMMENT '当前节点启动时间',
  `field_workflowProgressName_c` varchar(60) DEFAULT NULL COMMENT '工单流程进度',
  `created_by` varchar(255) DEFAULT NULL COMMENT '创建人',
  `field_xrzoE_c` varchar(60) DEFAULT NULL COMMENT '客户地址',
  `field_zpfwsj_c` datetime DEFAULT NULL COMMENT '计划开始服务',
  `field_7vXkh_c` varchar(60) DEFAULT NULL COMMENT '关联服务类采购申请单',
  `data_own_department` varchar(255) DEFAULT NULL COMMENT '归属部门',
  `field_fwrq_c` datetime DEFAULT NULL COMMENT '预约开始服务',
  `field_serviceAddress_c` varchar(60) DEFAULT NULL COMMENT '服务地址',
  `reasons_for_rejection_c` varchar(500) DEFAULT NULL COMMENT '拒单理由',
  `field_vv1u8_c` varchar(50) DEFAULT NULL COMMENT '是否外采',
  `actual_start_time_c` datetime DEFAULT NULL COMMENT '实际服务开始时间',
  `field_lgv0m_c` datetime DEFAULT NULL COMMENT '实际开始时间',
  `description` varchar(255) DEFAULT NULL COMMENT '问题描述',
  `field_4M913_c` varchar(255) DEFAULT NULL COMMENT '产品类型',
  `field_glcp_c` varchar(60) DEFAULT NULL COMMENT '关联产品',
  `contact_id` varchar(60) DEFAULT NULL COMMENT '联系人',
  `field_4d1vk_c` datetime DEFAULT NULL COMMENT '工单关单时间',
  `field_h2etA_c` varchar(500) DEFAULT NULL COMMENT '解决方案',
  `field_1m26K_c` decimal(10,2) DEFAULT NULL COMMENT '基准工时',
  `cases_status` varchar(60) DEFAULT NULL COMMENT '状态',
  `field_assignType_c` varchar(60) DEFAULT NULL COMMENT '指派类型',
  `field_hb3q1_c` varchar(60) DEFAULT NULL COMMENT '任务名称',
  `field_w62Ri_c` datetime DEFAULT NULL COMMENT '实际结束时间',
  `field_913Da_c` varchar(50) DEFAULT NULL COMMENT '是否需要原厂工程师',
  `field_wxAppId_c` varchar(60) DEFAULT NULL COMMENT '微信服务号ID',
  `out_owner` varchar(255) DEFAULT NULL COMMENT '外部负责人',
  `field_o81Td_c` datetime DEFAULT NULL COMMENT '工单实际开始时间',
  `field_gmxCa_c` varchar(500) DEFAULT NULL COMMENT '配件告知客户寄回',
  `field_7Zd8V_c` varchar(500) DEFAULT NULL COMMENT '项目详细地址',
  `owner` varchar(255) DEFAULT NULL COMMENT '负责人',
  `field_Wl7tg_c` varchar(60) DEFAULT NULL COMMENT '发货单',
  `field_hg26p_c` varchar(60) DEFAULT NULL COMMENT '客户ID',
  `last_modified_by` varchar(255) DEFAULT NULL COMMENT '最后修改人',
  `field_assign_endtime_c` datetime DEFAULT NULL COMMENT '计划结束服务',
  `record_type` varchar(60) DEFAULT NULL COMMENT '业务类型',
  `field_barcode_c` varchar(60) DEFAULT NULL COMMENT '设备条码',
  `assign_time_c` datetime DEFAULT NULL COMMENT '派单时间',
  `field_OW4IR_c` varchar(255) DEFAULT NULL COMMENT '区域负责人',
  `field_a8oUH_c` varchar(50) DEFAULT NULL COMMENT '工单工时区分',
  `field_w01PJ_c` varchar(50) DEFAULT NULL COMMENT '是否外包',
  `field_O68w2_c` datetime DEFAULT NULL COMMENT '预计入场时间',
  `field_c2com_c` varchar(50) DEFAULT NULL COMMENT '是否转交处理',
  PRIMARY KEY (`id`),
  UNIQUE KEY `pft_crm_cases_UN` (`_id`)
) ENGINE=InnoDB AUTO_INCREMENT=78862 DEFAULT CHARSET=utf8 COMMENT='crm工单';

-- @table RDS_crm_erp:pft_crm_category_product
-- @at 2026-11-27 11:39:53
CREATE TABLE `pft_crm_category_product` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '产品分类名称',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `code` varchar(30) NOT NULL DEFAULT '' COMMENT 'code',
  `categoryCode` varchar(30) NOT NULL DEFAULT '' COMMENT 'categoryCode',
  `orderField` varchar(30) NOT NULL DEFAULT '' COMMENT 'orderField',
  `pid` varchar(30) NOT NULL DEFAULT '' COMMENT '父纷享平台id',
  `op1` varchar(30) NOT NULL DEFAULT '' COMMENT '自定义1',
  `op2` varchar(30) NOT NULL DEFAULT '' COMMENT '自定义2',
  `op3` varchar(30) NOT NULL DEFAULT '' COMMENT '自定义3',
  PRIMARY KEY (`id`),
  KEY `idx_platform_id` (`platform_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6598 DEFAULT CHARSET=utf8mb4 COMMENT='crm产品分类表';

-- @table RDS_crm_erp:pft_crm_corporation
-- @at 2026-11-27 11:40:15
CREATE TABLE `pft_crm_corporation` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '甲方名称',
  `crm_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `field_S7bv6__c` varchar(20) NOT NULL DEFAULT '' COMMENT '手机号',
  `lock_user` varchar(50) NOT NULL DEFAULT '' COMMENT '加锁人',
  `field_Ez806__c__r` varchar(20) NOT NULL DEFAULT '' COMMENT '国家',
  `field_4TTv8__c__r` varchar(20) NOT NULL DEFAULT '' COMMENT '市',
  `field_L12pi__c__r` varchar(20) NOT NULL DEFAULT '' COMMENT '省',
  `field_1Fla5__c__r` varchar(20) NOT NULL DEFAULT '' COMMENT '区',
  `owner_department_id` varchar(40) NOT NULL DEFAULT '' COMMENT '负责人主属部门id',
  `owner_department` varchar(40) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `out_owner` varchar(40) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `owner` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人',
  `owner__r` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人名称',
  `field_50Oo3__c` varchar(30) NOT NULL DEFAULT '' COMMENT '开户行',
  `field_N9t1t__c` varchar(200) NOT NULL DEFAULT '' COMMENT '详细地址',
  `field_ceUjO__c` varchar(200) NOT NULL DEFAULT '' COMMENT '地区定位',
  `field_GB1v2__c` varchar(30) NOT NULL DEFAULT '' COMMENT '银行类别',
  `field_2p5fO__c` varchar(200) NOT NULL DEFAULT '' COMMENT '定位',
  `field_ywM40__c` varchar(200) NOT NULL DEFAULT '' COMMENT '纳税识别号',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `last_modified_by` varchar(100) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `last_modified_by__r` varchar(100) NOT NULL DEFAULT '' COMMENT '最后修改人名称',
  `out_tenant_id` varchar(30) NOT NULL DEFAULT '' COMMENT '外部企业',
  `field_bsbcO__c` varchar(100) NOT NULL DEFAULT '' COMMENT '银行账号',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `created_by` varchar(50) NOT NULL DEFAULT '' COMMENT '创建人',
  `created_by__l` varchar(20) NOT NULL DEFAULT '' COMMENT '创建人名称',
  `relevant_team__r` varchar(300) NOT NULL DEFAULT '' COMMENT '相关团队',
  `record_type` varchar(100) NOT NULL DEFAULT '' COMMENT '业务类型',
  `data_own_department` varchar(30) NOT NULL DEFAULT '' COMMENT '归属部门id',
  `data_own_department__r` varchar(30) NOT NULL DEFAULT '' COMMENT '归属部门',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '新增时间',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '修改时间',
  `djbh` varchar(30) NOT NULL DEFAULT '' COMMENT '单据号',
  `erp_id` varchar(30) NOT NULL DEFAULT '' COMMENT 'erp的主键id',
  `field_vSFOo__c` varchar(100) NOT NULL DEFAULT '' COMMENT '银行账号 最新',
  `field_A2Es0__c` varchar(32) NOT NULL DEFAULT '' COMMENT '电话',
  `party_a_type__c` varchar(16) NOT NULL DEFAULT '' COMMENT '甲方类型',
  PRIMARY KEY (`id`),
  KEY `idx_crm_id` (`crm_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6225 DEFAULT CHARSET=utf8mb4 COMMENT='甲方公司名称信息表';

-- @table RDS_crm_erp:pft_crm_customer_detail
-- @at 2026-11-27 11:40:45
CREATE TABLE `pft_crm_customer_detail` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `name` varchar(32) DEFAULT NULL COMMENT '12301平台ID',
  `crm_id` varchar(64) DEFAULT NULL COMMENT 'crmId',
  `field_jMbd6__c` varchar(255) DEFAULT NULL COMMENT '备注',
  `field_2smdj__c` varchar(64) DEFAULT NULL COMMENT '合同编号',
  `field_2smdj__c__r` varchar(32) DEFAULT NULL COMMENT '合同编号',
  `field_66mVu__c` datetime DEFAULT NULL COMMENT '套餐开始时间',
  `owner_department` varchar(64) DEFAULT NULL COMMENT '负责人主属部门',
  `owner_department_id` varchar(64) DEFAULT NULL COMMENT '负责人主属部门ID',
  `out_owner` varchar(64) DEFAULT NULL COMMENT '外部负责人',
  `owner` varchar(64) DEFAULT NULL COMMENT '负责人',
  `lock_status` varchar(32) DEFAULT NULL COMMENT '锁定状态',
  `last_modified_time` datetime DEFAULT NULL COMMENT '最后修改时间',
  `field_k8i81__c` varchar(32) DEFAULT NULL COMMENT '续费标记',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `life_status` varchar(32) DEFAULT NULL COMMENT '生命状态',
  `last_modified_by` varchar(64) DEFAULT NULL COMMENT '最后修改人',
  `out_tenant_id` varchar(32) DEFAULT NULL COMMENT '外部企业',
  `created_by` varchar(64) DEFAULT NULL COMMENT '创建人',
  `data_own_department` varchar(64) DEFAULT NULL COMMENT '归属部门',
  `field_51934__c` datetime DEFAULT NULL COMMENT '套餐结束时间',
  `field_fxzcN__c` varchar(64) DEFAULT NULL COMMENT '客户ID',
  `field_fxzcN__c__r` varchar(64) DEFAULT NULL COMMENT '客户名称',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=821506 DEFAULT CHARSET=utf8 COMMENT='12301平台ID明细表';

-- @table RDS_crm_erp:pft_crm_delivery_note
-- @at 2026-11-27 11:41:10
CREATE TABLE `pft_crm_delivery_note` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(50) NOT NULL DEFAULT '' COMMENT '发货单编号',
  `crm_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `lock_status` varchar(30) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `receive_remark` varchar(500) NOT NULL DEFAULT '' COMMENT '收货备注',
  `attachments` varchar(300) NOT NULL DEFAULT '' COMMENT '收获附件',
  `remark` varchar(500) NOT NULL DEFAULT '' COMMENT '备注',
  `lock_user` varchar(50) NOT NULL DEFAULT '' COMMENT '加锁人',
  `ship_to_add` varchar(100) NOT NULL DEFAULT '' COMMENT '收获地址',
  `express_order_id` varchar(50) NOT NULL DEFAULT '' COMMENT '物流单号',
  `sales_order_id` varchar(50) NOT NULL DEFAULT '' COMMENT '销售订单编号',
  `object_describe_api_name` varchar(50) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `owner_department` varchar(20) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `out_owner` varchar(100) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `owner` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人',
  `images` varchar(50) NOT NULL DEFAULT '' COMMENT '收货图片',
  `consignee` varchar(50) NOT NULL DEFAULT '' COMMENT '收货人',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `express_org` varchar(50) NOT NULL DEFAULT '' COMMENT '物流公司',
  `total_delivery_money` varchar(30) NOT NULL DEFAULT '' COMMENT '发货总金额',
  `last_modified_by` varchar(50) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `out_tenant_id` varchar(30) NOT NULL DEFAULT '' COMMENT '外部企业',
  `created_by` varchar(50) NOT NULL DEFAULT '' COMMENT '创建人',
  `relevant_team` varchar(100) NOT NULL DEFAULT '' COMMENT '相关团队',
  `record_type` varchar(100) NOT NULL DEFAULT '' COMMENT '业务类型',
  `receive_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '收货日期',
  `consignee_phone_number` varchar(30) NOT NULL DEFAULT '' COMMENT '收货人电话',
  `delivery_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '发货日期',
  `account_id` varchar(50) NOT NULL DEFAULT '' COMMENT '客户名称',
  `data_own_department` varchar(30) NOT NULL DEFAULT '' COMMENT '归属部门',
  `status` varchar(20) NOT NULL DEFAULT '' COMMENT '状态',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '新增时间',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '修改时间',
  `field_2D5Y5__c` date DEFAULT NULL COMMENT '实际发货日期',
  `sales_order_id__r` varchar(64) DEFAULT NULL COMMENT '合同编号',
  `account_id__r` varchar(64) DEFAULT NULL COMMENT '客户名称',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2996 DEFAULT CHARSET=utf8mb4 COMMENT='发货单';

-- @table RDS_crm_erp:pft_crm_delivery_note_product
-- @at 2026-11-27 11:41:34
CREATE TABLE `pft_crm_delivery_note_product` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `delivery_note_id` varchar(50) NOT NULL DEFAULT '' COMMENT '发货单编号',
  `receive_remark` varchar(200) NOT NULL DEFAULT '' COMMENT '收货备注',
  `product_image` varchar(50) NOT NULL DEFAULT '' COMMENT '产品图片',
  `avg_price` varchar(50) NOT NULL DEFAULT '' COMMENT '平均单价',
  `remark` varchar(200) NOT NULL DEFAULT '' COMMENT '备注',
  `lock_user` varchar(20) NOT NULL DEFAULT '' COMMENT '加锁人',
  `specs` varchar(1000) NOT NULL DEFAULT '' COMMENT '产品规格',
  `delivery_num` varchar(20) NOT NULL DEFAULT '' COMMENT '本次发货数',
  `has_delivered_num` varchar(20) NOT NULL DEFAULT '' COMMENT '已发货数',
  `object_describe_api_name` varchar(20) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `sales_order_product_id` varchar(50) NOT NULL DEFAULT '' COMMENT '产品订单编号',
  `sales_order_id` varchar(50) NOT NULL DEFAULT '' COMMENT '销售订单编号',
  `product_id` varchar(50) NOT NULL DEFAULT '' COMMENT '产品名称',
  `field_o1wn8__c` varchar(50) NOT NULL DEFAULT '' COMMENT '产品类型',
  `out_owner` varchar(50) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `owner_department` varchar(50) NOT NULL DEFAULT '' COMMENT '负责人所在部门',
  `field_8Qt0e__c` varchar(50) NOT NULL DEFAULT '' COMMENT '产品编码',
  `order_product_amount` varchar(50) NOT NULL DEFAULT '' COMMENT '订单产品数量',
  `delivery_money` varchar(50) NOT NULL DEFAULT '' COMMENT '本次发货金额',
  `owner` varchar(50) NOT NULL DEFAULT '' COMMENT '负责人',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `lock_status` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `life_status` varchar(50) NOT NULL DEFAULT '' COMMENT '生命状态',
  `last_modified_by` varchar(50) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `out_tenant_id` varchar(50) NOT NULL DEFAULT '' COMMENT '外部企业',
  `created_by` varchar(50) NOT NULL DEFAULT '' COMMENT '创建人',
  `record_type` varchar(50) NOT NULL DEFAULT '' COMMENT '业务类型',
  `real_receive_num` varchar(50) NOT NULL DEFAULT '' COMMENT '本次收货数',
  `relevant_team` varchar(50) NOT NULL DEFAULT '' COMMENT '相关团队',
  `unit` varchar(50) NOT NULL DEFAULT '' COMMENT '单位',
  `data_own_department` varchar(50) NOT NULL DEFAULT '' COMMENT '归属部门',
  `sales_price` varchar(50) NOT NULL DEFAULT '' COMMENT '销售单价',
  `name` varchar(50) NOT NULL DEFAULT '' COMMENT '发货单产品id',
  `crm_id` varchar(50) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10957 DEFAULT CHARSET=utf8mb4 COMMENT='发货单产品';

-- @table RDS_crm_erp:pft_crm_department
-- @at 2026-11-27 16:15:11
-- @cmt add_time 供应商+产品最早上架资源中心票的时间
-- @cmt update_time 更新时间
CREATE TABLE `pft_crm_department` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `NAME` varchar(50) NOT NULL DEFAULT '' COMMENT '部门名称',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `offset` int(10) NOT NULL DEFAULT '0' COMMENT '序号',
  `manager_id__l` varchar(30) NOT NULL DEFAULT '' COMMENT '部门负责人',
  `manager_id` varchar(50) DEFAULT '' COMMENT '负责人id',
  `parent_id` varchar(50) NOT NULL DEFAULT '' COMMENT '上级部门',
  `assistant_id` varchar(200) NOT NULL DEFAULT '' COMMENT '助理',
  `STATUS` varchar(20) NOT NULL DEFAULT '' COMMENT '部门状态',
  `dept_id` varchar(50) NOT NULL DEFAULT '' COMMENT '部门id',
  `owner_department` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `dept_code` varchar(50) NOT NULL DEFAULT '' COMMENT '部门编码',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `dept_children` varchar(200) NOT NULL DEFAULT '' COMMENT '部门子部门序列',
  `dept_parent_path` varchar(200) NOT NULL DEFAULT '' COMMENT '部门祖先路径',
  `owner__r` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人',
  `lock_user` varchar(50) NOT NULL DEFAULT '' COMMENT '加锁人',
  `relevant_team__r` varchar(100) NOT NULL DEFAULT '' COMMENT '相关团队',
  `record_type` varchar(20) NOT NULL DEFAULT '' COMMENT '业务类型',
  `object_describe_api_name` varchar(100) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `last_modified_by__r` varchar(30) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `created_by__r` varchar(50) NOT NULL DEFAULT '' COMMENT '创建人',
  `out_tenant_id` varchar(100) NOT NULL DEFAULT '' COMMENT '外部企业',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `data_own_department__r` varchar(50) NOT NULL DEFAULT '' COMMENT '归属部门',
  `data_own_department` varchar(50) NOT NULL DEFAULT '' COMMENT '归属部门',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `out_owner` varchar(50) NOT NULL DEFAULT '' COMMENT '外部负责人',
  PRIMARY KEY (`id`),
  KEY `idx_platform_id` (`platform_id`)
) ENGINE=InnoDB AUTO_INCREMENT=540 DEFAULT CHARSET=utf8mb4 COMMENT='部门表';

-- @table RDS_crm_erp:pft_crm_invoice_application
-- @at 2026-11-27 11:42:05
CREATE TABLE `pft_crm_invoice_application` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `field_04yCt__c` varchar(100) NOT NULL DEFAULT '' COMMENT '开票事由',
  `field_itPsc__c` varchar(100) NOT NULL DEFAULT '' COMMENT '是否与合同寄出',
  `contact_tel` varchar(100) NOT NULL DEFAULT '' COMMENT '联系方式',
  `account_bank` varchar(100) NOT NULL DEFAULT '' COMMENT '开户行',
  `field_3yw6g__c` varchar(500) NOT NULL DEFAULT '' COMMENT '开票内容',
  `title_type` varchar(100) NOT NULL DEFAULT '' COMMENT '抬头类型',
  `field_1Jnr6__c` varchar(100) NOT NULL DEFAULT '' COMMENT '甲方名称',
  `owner_department` varchar(100) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `field_xAs8O__c` varchar(100) NOT NULL DEFAULT '' COMMENT '测试',
  `field_Xe3g4__c` varchar(100) NOT NULL DEFAULT '' COMMENT '关联回款信息',
  `field_Lz4fg__c` varchar(100) NOT NULL DEFAULT '' COMMENT '客户ID',
  `finance_confirm_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '财务确认时间',
  `biz_status` varchar(100) NOT NULL DEFAULT '' COMMENT '状态',
  `lock_status` varchar(100) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `field_1wv2x__c` varchar(100) NOT NULL DEFAULT '' COMMENT '付款阶段',
  `field_XlozQ__c` varchar(100) NOT NULL DEFAULT '' COMMENT '产品类型',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `submit_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '提交时间',
  `tax_amount_sum` varchar(100) NOT NULL DEFAULT '' COMMENT '税金',
  `invoice_tel` varchar(100) NOT NULL DEFAULT '' COMMENT '电话',
  `invoice_add` varchar(100) NOT NULL DEFAULT '' COMMENT '开票地址',
  `field_8tuFr__c` varchar(100) NOT NULL DEFAULT '' COMMENT '关联合同信息',
  `created_by` varchar(100) NOT NULL DEFAULT '' COMMENT '创建人',
  `relevant_team` varchar(300) NOT NULL DEFAULT '' COMMENT '相关团队',
  `tax_id` varchar(100) NOT NULL DEFAULT '' COMMENT '纳税识别号',
  `data_own_department` varchar(100) NOT NULL DEFAULT '' COMMENT '归属部门',
  `field_x61k2__c` varchar(300) NOT NULL DEFAULT '' COMMENT '关联回款信息(多选)',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '开票申请编号',
  `account_bank_no` varchar(100) NOT NULL DEFAULT '' COMMENT '开户账号',
  `platform_id` varchar(100) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `order_id` varchar(100) NOT NULL DEFAULT '' COMMENT '销售订单编号',
  `status` varchar(100) NOT NULL DEFAULT '' COMMENT '状态（原）',
  `field_y4uPg__c` varchar(100) NOT NULL DEFAULT '' COMMENT '业务分类',
  `finance_employee_id` varchar(100) NOT NULL DEFAULT '' COMMENT '财务确认人姓名',
  `invoice_title` varchar(100) NOT NULL DEFAULT '' COMMENT '开票抬头',
  `remark` varchar(1000) NOT NULL DEFAULT '' COMMENT '备注',
  `lock_user` varchar(100) NOT NULL DEFAULT '' COMMENT '加锁人',
  `invoice_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '开票日期',
  `field_8jf2L__c` varchar(100) NOT NULL DEFAULT '' COMMENT '关联发货单',
  `object_describe_api_name` varchar(100) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `field_S29nZ__c` varchar(100) NOT NULL DEFAULT '' COMMENT '款项是否收到',
  `invoice_type` varchar(100) NOT NULL DEFAULT '' COMMENT '开票类型',
  `out_owner` varchar(100) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `attach` varchar(500) NOT NULL DEFAULT '' COMMENT '附件',
  `owner` varchar(100) NOT NULL DEFAULT '' COMMENT '负责人',
  `is_fixed_flow` varchar(100) NOT NULL DEFAULT '' COMMENT '是否混合审批流',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `life_status` varchar(100) NOT NULL DEFAULT '' COMMENT '生命状态',
  `invoice_no` varchar(100) NOT NULL DEFAULT '' COMMENT '发票号码',
  `field_vx7zS__c` varchar(100) NOT NULL DEFAULT '' COMMENT '快递单号',
  `field_d8IT2__c` varchar(100) NOT NULL DEFAULT '' COMMENT '邮箱',
  `last_modified_by` varchar(100) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `out_tenant_id` varchar(100) NOT NULL DEFAULT '' COMMENT '外部企业',
  `field_s1AJn__c` varchar(100) NOT NULL DEFAULT '' COMMENT '发票签收回执单',
  `record_type` varchar(100) NOT NULL DEFAULT '' COMMENT '业务类型',
  `account_id` varchar(100) NOT NULL DEFAULT '' COMMENT '客户名称',
  `invoice_applied_amount` varchar(100) NOT NULL DEFAULT '' COMMENT '开票金额（元）',
  `contact_add` varchar(100) NOT NULL DEFAULT '' COMMENT '寄送地址',
  `recipient` varchar(100) NOT NULL DEFAULT '' COMMENT '收件人',
  `field_G2kq0__c` varchar(100) NOT NULL DEFAULT '' COMMENT '合同金额',
  PRIMARY KEY (`id`),
  KEY `idx_platform_id` (`platform_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7647 DEFAULT CHARSET=utf8mb4 COMMENT='开票申请';

-- @table RDS_crm_erp:pft_crm_journal
-- @at 2026-11-27 16:15:18
-- @cmt crm_id CRM ID
-- @cmt id 主键ID
-- @cmt name 名称
CREATE TABLE `pft_crm_Journal` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `crm_id` varchar(64) DEFAULT NULL,
  `name` varchar(32) DEFAULT NULL,
  `owner` varchar(64) DEFAULT NULL COMMENT '负责人',
  `owner__r` varchar(32) DEFAULT NULL COMMENT '负责人',
  `owner_department` varchar(64) DEFAULT NULL COMMENT '负责人主属部门',
  `period_type` varchar(16) DEFAULT NULL COMMENT '汇报周期',
  `work_summary` text CHARACTER SET utf8mb4 COMMENT '本期工作总结',
  `work_plan` text CHARACTER SET utf8mb4 COMMENT '下期工作计划',
  `work_experience` text CHARACTER SET utf8mb4 COMMENT '心得体会',
  `comment_by` varchar(64) DEFAULT NULL COMMENT '点评人',
  `comment_time` datetime DEFAULT NULL COMMENT '点评时间',
  `comment_status` varchar(16) DEFAULT NULL COMMENT '点评状态',
  `comment_score` int(11) DEFAULT NULL COMMENT '点评评分',
  `comment_content` text CHARACTER SET utf8mb4 COMMENT '点评内容',
  `is_delayed` tinyint(1) DEFAULT NULL COMMENT '是否补交',
  `related_object_data` text COMMENT '关联业务对象',
  `journal_time` varchar(64) DEFAULT NULL COMMENT '时间',
  `created_by` varchar(64) DEFAULT NULL COMMENT '创建人',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `last_modified_by` varchar(64) DEFAULT NULL COMMENT '最后修改人',
  `last_modified_time` datetime DEFAULT NULL COMMENT '最后修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_crm_id_name` (`crm_id`,`name`),
  KEY `idx_period_type_journal_time` (`period_type`,`journal_time`)
) ENGINE=InnoDB AUTO_INCREMENT=5334 DEFAULT CHARSET=utf8 COMMENT='crm日志';

-- @table RDS_crm_erp:pft_crm_leads
-- @at 2026-11-27 11:43:01
CREATE TABLE `pft_crm_leads` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(50) NOT NULL DEFAULT '' COMMENT '联系人姓名',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `offset` int(10) NOT NULL DEFAULT '0' COMMENT '序号',
  `leads_pool_id` varchar(30) NOT NULL DEFAULT '' COMMENT '线索池',
  `tel` varchar(150) NOT NULL DEFAULT '' COMMENT '电话',
  `biz_status` varchar(50) NOT NULL DEFAULT '' COMMENT '状态',
  `field_1W1xh__c` varchar(30) NOT NULL DEFAULT '' COMMENT '省id',
  `field_1W1xh__c__r` varchar(30) NOT NULL DEFAULT '' COMMENT '省名称',
  `leads_stage` varchar(30) NOT NULL DEFAULT '' COMMENT '线索阶段',
  `is_duplicated` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否存在重复数据',
  `next_followed_remark` varchar(100) NOT NULL DEFAULT '' COMMENT '下次跟进要点',
  `last_follower` varchar(50) NOT NULL DEFAULT '' COMMENT '最后跟进人id',
  `last_follower__r` varchar(50) NOT NULL DEFAULT '' COMMENT '最后跟进人',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `is_collected` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否归集',
  `field_iDtZf__c` varchar(30) NOT NULL DEFAULT '' COMMENT '市id',
  `field_iDtZf__c__r` varchar(30) NOT NULL DEFAULT '' COMMENT '市名称',
  `biz_reg_name` tinyint(1) NOT NULL DEFAULT '0' COMMENT '工商是否有注册',
  `field_kmlM1__c` varchar(700) NOT NULL DEFAULT '' COMMENT '新负责人id',
  `field_kmlM1__c__r` varchar(200) NOT NULL DEFAULT '' COMMENT '新负责人',
  `created_by` varchar(700) NOT NULL DEFAULT '' COMMENT '创建人id',
  `created_by__r` varchar(200) NOT NULL DEFAULT '' COMMENT '创建人',
  `remaining_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '剩余保有时间',
  `last_follow_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后跟进时间',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除',
  `field_Qja0Q__c` varchar(100) NOT NULL DEFAULT '' COMMENT '呼叫电话',
  `leads_status` varchar(20) NOT NULL DEFAULT '' COMMENT '状态（原）',
  `country` varchar(30) NOT NULL DEFAULT '' COMMENT '国',
  `company` varchar(100) NOT NULL DEFAULT '' COMMENT '公司名称',
  `department` varchar(30) NOT NULL DEFAULT '' COMMENT '部门',
  `is_outstrip_time` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否超时',
  `mobile` varchar(100) NOT NULL DEFAULT '' COMMENT '手机号',
  `last_modified_by_id` varchar(700) NOT NULL DEFAULT '' COMMENT '最后修改人id',
  `last_modified_by__r` varchar(30) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `record_type` varchar(30) NOT NULL DEFAULT '' COMMENT '业务类型',
  `returned_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '退回/收回时间',
  `refresh_duplicated_version` varchar(30) NOT NULL DEFAULT '' COMMENT '重复数据刷库版本号',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `phone_number_attribution_city` varchar(20) NOT NULL DEFAULT '' COMMENT '手机归属市',
  `field_jg172__c` tinyint(1) NOT NULL DEFAULT '0' COMMENT '手机是否新建',
  `field_HyYWt__c` varchar(50) NOT NULL DEFAULT '' COMMENT '合作伙伴名称',
  `field_AbkEf__c` varchar(30) NOT NULL DEFAULT '' COMMENT '景区类型',
  `remind_days` varchar(30) NOT NULL DEFAULT '' COMMENT '回收提前提醒天数',
  `field_wm1l5__c` varchar(50) NOT NULL DEFAULT '' COMMENT '线下合作竞品',
  `assigned_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '领取/分配时间',
  `extend_days` varchar(30) NOT NULL DEFAULT '' COMMENT '申请延期天数',
  `field_AlsrU__c` varchar(100) NOT NULL DEFAULT '' COMMENT '意向合作类容',
  `field_0ke13__c` varchar(30) NOT NULL DEFAULT '' COMMENT '区',
  `utm_medium__c` varchar(50) NOT NULL DEFAULT '' COMMENT 'utm_medium',
  `phone_number_attribution_address` varchar(200) NOT NULL DEFAULT '' COMMENT '手机归属详细地址',
  `field_xw1F9__c` varchar(50) NOT NULL DEFAULT '' COMMENT '景区等级',
  `marketing_source_name__c` varchar(50) NOT NULL DEFAULT '' COMMENT '官网访问来源',
  `keyword_id` varchar(50) NOT NULL DEFAULT '' COMMENT '关键词',
  `back_reason` varchar(200) NOT NULL DEFAULT '' COMMENT '销售人员退回原因',
  `field_8r89N__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '线索转移时间',
  `field_1ogYf__c` varchar(30) NOT NULL DEFAULT '' COMMENT '客户类型',
  `close_reason` varchar(200) NOT NULL DEFAULT '' COMMENT '线索无效原因',
  `resale_count` varchar(30) NOT NULL DEFAULT '' COMMENT '线索数量',
  `field_seb90__c` varchar(50) NOT NULL DEFAULT '' COMMENT '免费时间段',
  `marketing_activity_id__c` varchar(100) NOT NULL DEFAULT '' COMMENT '营销活动',
  `phone_number_attribution_country` varchar(20) NOT NULL DEFAULT '' COMMENT '手机归属国家',
  `ggdyu__c` varchar(30) NOT NULL DEFAULT '' COMMENT '广告地域',
  `phone_number_attribution_district` varchar(20) NOT NULL DEFAULT '' COMMENT '手机归属区',
  `email` varchar(200) NOT NULL DEFAULT '' COMMENT '邮件',
  `field_zXBWq__c` varchar(30) NOT NULL DEFAULT '' COMMENT '旅行社类型',
  `address` varchar(200) NOT NULL DEFAULT '' COMMENT '地址',
  `field_vio0u__c` varchar(30) NOT NULL DEFAULT '' COMMENT '联系状态',
  `out_tenant_id` varchar(30) NOT NULL DEFAULT '' COMMENT '外部企业',
  `field_Im8AL__c` varchar(30) NOT NULL DEFAULT '' COMMENT '合作伙伴类型',
  `field_xG80r__c` varchar(50) NOT NULL DEFAULT '' COMMENT '来源搜索关键词',
  `url` varchar(100) NOT NULL DEFAULT '' COMMENT '网址',
  `enterprise_wechat_user_id` varchar(50) NOT NULL DEFAULT '' COMMENT '企业微信UserId',
  `collected_to` varchar(100) NOT NULL DEFAULT '' COMMENT '归集到的线索',
  `field_8b1gc__c` varchar(100) NOT NULL DEFAULT '' COMMENT '呼叫内容',
  `assigner_id` varchar(50) NOT NULL DEFAULT '' COMMENT '分配管理员',
  `transform_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '转换时间',
  `source` varchar(50) NOT NULL DEFAULT '' COMMENT '线索来源',
  `phone_number_attribution_province` varchar(20) NOT NULL DEFAULT '' COMMENT '手机归属省份名称',
  `next_followed_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '下次跟进时间',
  `owner_change_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '负责变更时间',
  `field_1R6zU__c` varchar(100) NOT NULL DEFAULT '' COMMENT '来源明细',
  `utm_content__c` varchar(100) NOT NULL DEFAULT '' COMMENT 'utm_content__c',
  `owner_department` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `landing_page_url` varchar(1000) NOT NULL DEFAULT '' COMMENT '落地页url',
  `job_title` varchar(30) NOT NULL DEFAULT '' COMMENT '职务',
  `lock_status` varchar(30) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `utm_term__c` varchar(100) NOT NULL DEFAULT '' COMMENT 'utm_term__c',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT 'crm创建时间',
  `expire_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '预计收回时间',
  `promotion_channel` varchar(100) NOT NULL DEFAULT '' COMMENT '推广渠道',
  `field_8k5FS__c` varchar(50) NOT NULL DEFAULT '' COMMENT '景区关键词',
  `changed_to_mql_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '转MQL时间',
  `phone_number_attribution` varchar(100) NOT NULL DEFAULT '' COMMENT '手机归属地',
  `relevant_team__r` varchar(100) NOT NULL DEFAULT '' COMMENT '相关团队',
  `field_2cyq4__c` varchar(50) NOT NULL DEFAULT '' COMMENT '微信号',
  `industry_ext` varchar(50) NOT NULL DEFAULT '' COMMENT '工商扩展',
  `field_n8xp1__c` varchar(1000) NOT NULL DEFAULT '' COMMENT '最后跟进内容',
  `data_own_department` varchar(50) NOT NULL DEFAULT '' COMMENT '归属部门',
  `field_17efn__c` varchar(30) NOT NULL DEFAULT '' COMMENT '关键人岗位角色',
  `conversion_probability` varchar(20) NOT NULL DEFAULT '' COMMENT '转换概率',
  `is_remind_recycling` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否待回收提醒',
  `field_s1aO7__c` varchar(50) NOT NULL DEFAULT '' COMMENT '线索转移人',
  `remark` varchar(500) NOT NULL DEFAULT '' COMMENT '备注',
  `field_1jYz5__c` varchar(30) NOT NULL DEFAULT '' COMMENT '地区',
  `field_c2FZc__c` varchar(100) NOT NULL DEFAULT '' COMMENT '线上合作竞品',
  `field_0Q1qI__c` varchar(50) NOT NULL DEFAULT '' COMMENT '景区是否免费',
  `lock_user` varchar(50) NOT NULL DEFAULT '' COMMENT '加锁人',
  `keyword_serving_plan_id` varchar(50) NOT NULL DEFAULT '' COMMENT '关键词投放计划',
  `field_0pplv__c` varchar(20) NOT NULL DEFAULT '' COMMENT '国家',
  `utm_campaign__c` varchar(100) NOT NULL DEFAULT '' COMMENT 'utm_campaign__c',
  `marketing_spread_user__c` varchar(50) NOT NULL DEFAULT '' COMMENT '推广人',
  `object_describe_api_name` varchar(100) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `out_owner` varchar(50) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `leads_stage_changed_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '线索阶段变更时间',
  `field_R2UsB__c` varchar(50) NOT NULL DEFAULT '' COMMENT '旅行社客群',
  `phone_number_attribution_location` varchar(100) NOT NULL DEFAULT '' COMMENT '手机归属定位',
  `owner` varchar(50) NOT NULL DEFAULT '' COMMENT '负责人',
  `picture_path` varchar(50) NOT NULL DEFAULT '' COMMENT '名片',
  `completed_result` varchar(300) NOT NULL DEFAULT '' COMMENT '处理结果',
  `field_pbwx8__c` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否KP关键人',
  `utm_source__c` varchar(100) NOT NULL DEFAULT '' COMMENT 'utm_source__c',
  `field_SoRo8__c` varchar(100) NOT NULL DEFAULT '' COMMENT '客户需求',
  `field_Szi2p__c` varchar(100) NOT NULL DEFAULT '' COMMENT '线索转移原因',
  `field_car2R__c` varchar(50) NOT NULL DEFAULT '' COMMENT '二次跟进周期',
  `field_R6Yx3__c` varchar(100) NOT NULL DEFAULT '' COMMENT '定位',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '修改时间',
  `field_1QUj6__c` varchar(100) NOT NULL DEFAULT '' COMMENT '大区归属',
  `ownerid` varchar(100) NOT NULL DEFAULT '' COMMENT '负责人id',
  `field_s1X8v__c` varchar(50) DEFAULT NULL COMMENT '行业认知',
  `field_0p29I__c` varchar(50) DEFAULT NULL COMMENT '银行名称',
  `life_status_before_invalid` varchar(50) DEFAULT NULL COMMENT '作废前生命状态',
  `field_6J89w__c` varchar(50) DEFAULT NULL COMMENT '政府名称',
  `field_G5Fvc__c` varchar(50) DEFAULT NULL COMMENT '平台和设备使用情况',
  `new_opportunity_id` varchar(50) DEFAULT NULL COMMENT '原转换商机2.0名称',
  `field_jc1vC__c` varchar(50) DEFAULT NULL COMMENT '详细地址',
  `field_VKxD7__c` varchar(50) DEFAULT NULL COMMENT '线下合作竞品',
  `field_F5Adj__c` varchar(50) DEFAULT NULL COMMENT '预计营业时间',
  `version` varchar(50) DEFAULT NULL COMMENT 'version',
  `field_2iPGw__c` datetime DEFAULT NULL COMMENT '线索提交时间',
  `relevance_wechat_date` datetime DEFAULT NULL COMMENT '关联企微日期',
  `field_298k0__c` varchar(50) DEFAULT NULL COMMENT '来源业务',
  `field_z0cA6__c` varchar(50) DEFAULT NULL COMMENT '景区现状',
  `tenant_id` varchar(50) DEFAULT NULL COMMENT 'tenant_id',
  `field_y14on__c` varchar(50) DEFAULT NULL COMMENT '客户性格',
  `wechat_fan_id` varchar(50) DEFAULT NULL COMMENT '微信用户',
  `visitor_id` varchar(50) DEFAULT NULL COMMENT '访客id',
  `marketing_partner_promoter` varchar(50) DEFAULT NULL COMMENT '伙伴推广人',
  `origin_source` varchar(50) DEFAULT NULL COMMENT '数据来源',
  `field_Y1W82__c` datetime DEFAULT NULL COMMENT '第一次转移时间(SDR专用)',
  `field_1B2hd__c` varchar(50) DEFAULT NULL COMMENT '移交面销',
  `field_SB322__c` varchar(50) DEFAULT NULL COMMENT '沟通配合度',
  `field_zW2Di__c` varchar(50) DEFAULT NULL COMMENT '年游客体量',
  `field_r25t1__c` varchar(50) DEFAULT NULL COMMENT '散团比例',
  `wechat_id` varchar(50) DEFAULT NULL COMMENT '微信号',
  `field_w6Z27__c` varchar(50) DEFAULT NULL COMMENT '竞品使用情况',
  `field_2wC5d__c` varchar(50) DEFAULT NULL COMMENT '第一次转移人员(SDR专用)',
  `field_62jl1__c` varchar(50) DEFAULT NULL COMMENT 'bumen',
  `marketing_event_id` varchar(50) DEFAULT NULL COMMENT '市场活动名称',
  `account_id` varchar(50) DEFAULT NULL COMMENT '原转换客户名称',
  `landing_page_id` varchar(50) DEFAULT NULL COMMENT '落地页名称',
  `order_by` varchar(50) DEFAULT NULL COMMENT 'order_by',
  `field_5z6h1__c` double DEFAULT NULL COMMENT '年客流量（万）',
  `field_2si6E__c` double DEFAULT NULL COMMENT '年度GMV（万）',
  `field_rv87J__c` varchar(50) DEFAULT NULL COMMENT '推荐官联系电话',
  `field_1e9Xz__c` varchar(50) DEFAULT NULL COMMENT '产品痛点',
  `field_5M4Iw__c` varchar(50) DEFAULT NULL COMMENT '线索是否由SDR交付',
  `wechat_nickname` varchar(50) DEFAULT NULL COMMENT '企微昵称',
  `field_vFVuj__c` varchar(50) DEFAULT NULL COMMENT '游客年龄段',
  `field_1eXxx__c` varchar(50) DEFAULT NULL COMMENT '内部推荐人姓名',
  `extend_obj_data_id` varchar(50) DEFAULT NULL COMMENT 'extend_obj_data_id',
  `is_relevance_wechat` tinyint(1) DEFAULT NULL COMMENT '是否关联企微',
  `package` varchar(50) DEFAULT NULL COMMENT 'package',
  `extend_reason` varchar(50) DEFAULT NULL COMMENT '延期原因',
  `field_4SjUd__c` varchar(50) DEFAULT NULL COMMENT '推荐官公司',
  `relevant_team` varchar(50) DEFAULT NULL COMMENT '相关团队',
  `field_xG4rR__c` varchar(50) DEFAULT NULL COMMENT '主营时段和接待力',
  `field_xvoSK__c` varchar(50) DEFAULT NULL COMMENT '集团名称',
  `field_A1gZn__c` varchar(50) DEFAULT NULL COMMENT '客户潜力',
  `field_1gZq6__c` varchar(50) DEFAULT NULL COMMENT '线索是否超时过',
  `field_Cj5m3__c` varchar(50) DEFAULT NULL COMMENT '运营商名称',
  `contact_id` varchar(50) DEFAULT NULL COMMENT '原转换联系人名称',
  `marketing_promotion_source_id` varchar(50) DEFAULT NULL COMMENT '营销推广来源',
  `marketing_partner` varchar(50) DEFAULT NULL COMMENT '伙伴企业',
  `field_1FEfn__c` varchar(50) DEFAULT NULL COMMENT '需求转化周期',
  `field_ikqmn__c` varchar(50) DEFAULT NULL COMMENT '来源渠道',
  `field_h1aCg__c` varchar(50) DEFAULT NULL COMMENT '是否已营业',
  `is_overtime` tinyint(1) DEFAULT NULL COMMENT '是否超时',
  `field_cNf4g__c` varchar(50) DEFAULT NULL COMMENT '推荐官姓名',
  `last_modified_by` varchar(50) DEFAULT NULL COMMENT '最后修改人',
  `field_e0K8F__c` varchar(50) DEFAULT NULL COMMENT '第三方类型',
  `field_HnEhG__c` varchar(50) DEFAULT NULL COMMENT '集成商名称',
  `field_sZtKv__c` varchar(50) DEFAULT NULL COMMENT '外部推荐公司名称',
  `field_xy7Gx__c` varchar(50) DEFAULT NULL COMMENT '智慧化意识',
  `field_6d00Y__c` varchar(100) DEFAULT NULL COMMENT '来源同事',
  PRIMARY KEY (`id`),
  KEY `idx_platform_id` (`platform_id`)
) ENGINE=InnoDB AUTO_INCREMENT=211902 DEFAULT CHARSET=utf8mb4 COMMENT='销售线索表';

-- @table RDS_crm_erp:pft_crm_new_opportunity
-- @at 2026-11-27 16:15:24
-- @cmt ownerid 负责人ID
-- @cmt update_time 更新时间
CREATE TABLE `pft_crm_new_opportunity` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '商机名称',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `offset` int(10) NOT NULL DEFAULT '0' COMMENT '序号',
  `discount` decimal(5,2) NOT NULL DEFAULT '0.00' COMMENT '折扣',
  `created_by__r` varchar(50) NOT NULL DEFAULT '' COMMENT '创建人',
  `price` varchar(30) NOT NULL DEFAULT '' COMMENT '价格',
  `owner_department` varchar(50) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `new_opporutnity_lines_specs` varchar(100) NOT NULL DEFAULT '' COMMENT '新的机会线规格（字段API中没有）',
  `new_opporutnity_lines_unit` varchar(30) NOT NULL DEFAULT '' COMMENT '新的机会线单位（字段API中没有）',
  `data_own_department__r` varchar(50) NOT NULL DEFAULT '' COMMENT '归属部门',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除',
  `owner__r` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `last_modified_by__r` varchar(100) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `created_by__l` varchar(30) NOT NULL DEFAULT '' COMMENT '创建人',
  `record_type` varchar(30) NOT NULL DEFAULT '' COMMENT '业务类型',
  `field_vV16L__c` varchar(1000) NOT NULL DEFAULT '' COMMENT '商机附件',
  `field_dw0m6__c` varchar(50) NOT NULL DEFAULT '' COMMENT '介绍客户名称',
  `close_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '预计签单日期',
  `field_P427h__c` varchar(30) NOT NULL DEFAULT '' COMMENT '接收部门',
  `field_f4VSj__c` varchar(50) NOT NULL DEFAULT '' COMMENT '景区名称',
  `cost_time` varchar(30) NOT NULL DEFAULT '' COMMENT '结单周期',
  `field_T4dCx__c` varchar(100) NOT NULL DEFAULT '' COMMENT '输单原因',
  `field_12GLt__c` varchar(20) NOT NULL DEFAULT '' COMMENT '客户类型',
  `field_Mb5oG__c` varchar(50) NOT NULL DEFAULT '' COMMENT '输单明细',
  `field_SbhwS__c` varchar(30) NOT NULL DEFAULT '' COMMENT '联系人姓名',
  `opp_lines_sum` varchar(30) NOT NULL DEFAULT '' COMMENT '产品合计',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `probability` int(10) NOT NULL DEFAULT '0' COMMENT '赢率',
  `field_WxqwU__c` varchar(30) NOT NULL DEFAULT '' COMMENT '合同签约金额',
  `last_followed_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后跟进时间',
  `relevant_team` varchar(3000) NOT NULL DEFAULT '' COMMENT '相关团队',
  `new_opportunity_path` varchar(50) NOT NULL DEFAULT '' COMMENT '商机2.0层级',
  `field_8h1yU__c` varchar(30) NOT NULL DEFAULT '' COMMENT '当前阶段',
  `field_3tn0c__c` varchar(30) NOT NULL DEFAULT '' COMMENT '是否为老带新',
  `opp_discount` decimal(7,2) NOT NULL DEFAULT '0.00' COMMENT '整单折扣',
  `parent_id` varchar(50) NOT NULL DEFAULT '' COMMENT '上级商机2.0',
  `price_book_id` varchar(100) NOT NULL DEFAULT '' COMMENT '价目表',
  `sales_process_id` varchar(30) NOT NULL DEFAULT '' COMMENT '销售模式',
  `field_ghmt1__c` varchar(50) NOT NULL DEFAULT '' COMMENT '客户来源',
  `field_fz10n__c` varchar(50) NOT NULL DEFAULT '' COMMENT '内部来源',
  `field_Ol34C__c` varchar(30) NOT NULL DEFAULT '' COMMENT '伙伴名称',
  `promised_probability` varchar(20) NOT NULL DEFAULT '' COMMENT '员工承诺赢率',
  `lock_user` varchar(50) NOT NULL DEFAULT '' COMMENT '加锁人',
  `sales_status` varchar(20) NOT NULL DEFAULT '' COMMENT '阶段状态',
  `leads_id` varchar(50) NOT NULL DEFAULT '' COMMENT '主线索',
  `sales_stage` varchar(30) NOT NULL DEFAULT '' COMMENT '商机阶段',
  `partner_id` varchar(30) NOT NULL DEFAULT '' COMMENT 'par',
  `object_describe_api_name` varchar(50) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `stg_changed_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '阶段变更时间',
  `field_k4iF2__c` varchar(30) NOT NULL DEFAULT '' COMMENT '合作类型',
  `field_0ikb1__c` varchar(500) NOT NULL DEFAULT '' COMMENT '输单说明',
  `out_owner` varchar(50) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `probability_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '预测金额',
  `out_resources` varchar(50) NOT NULL DEFAULT '' COMMENT '外部来源',
  `field_WRuta__c` varchar(50) NOT NULL DEFAULT '' COMMENT '是否区总支撑',
  `amount` varchar(20) NOT NULL DEFAULT '' COMMENT '预计销售金额',
  `field_4F61d__c` varchar(50) NOT NULL DEFAULT '' COMMENT '接收部门负责人',
  `field_Zj1hj__c` varchar(500) NOT NULL DEFAULT '' COMMENT '备注',
  `out_tenant_id` varchar(30) NOT NULL DEFAULT '' COMMENT '外部企业',
  `field_3xpp2__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '历史创建时间',
  `field_jxucK__c` varchar(30) NOT NULL DEFAULT '' COMMENT '合作伙伴类型',
  `lost_reason` varchar(30) NOT NULL DEFAULT '' COMMENT 'lost',
  `field_jrC5v__c` varchar(30) NOT NULL DEFAULT '' COMMENT '历史创建人',
  `marketing_event_id` varchar(50) NOT NULL DEFAULT '' COMMENT '主市场活动',
  `account_id` varchar(50) NOT NULL DEFAULT '' COMMENT '客户名称',
  `field_b4RzK__c` varchar(50) NOT NULL DEFAULT '' COMMENT '商机编号',
  `field_e7o5s__c` varchar(1000) NOT NULL DEFAULT '' COMMENT '最近跟进内容',
  `field_d0cX7__c` varchar(30) NOT NULL DEFAULT '' COMMENT '集成商|资方名称',
  `field_Lv321__c` varchar(50) NOT NULL DEFAULT '' COMMENT '商机项目号',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '修改时间',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `field_x86d7__c` varchar(100) NOT NULL DEFAULT '' COMMENT '输单原因-新',
  `field_94sRs__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '一阶段变更时间',
  `field_ITxfk__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '二阶段变更时间',
  `field_le0Bg__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '三阶段变更时间',
  `ownerid` varchar(100) DEFAULT NULL,
  `account_id__r` varchar(100) NOT NULL DEFAULT '' COMMENT '客户名称',
  `departmentId` varchar(100) NOT NULL DEFAULT '' COMMENT '部门id',
  `field_3Qs1j__c` varchar(50) DEFAULT NULL COMMENT '是否需SR介入',
  `field_yeJ8o__c` varchar(50) DEFAULT NULL COMMENT '是否需FR介入踏勘',
  `field_Q2L8w__c` varchar(50) DEFAULT NULL COMMENT '当前处理角色',
  `field_POxaz__c` varchar(50) DEFAULT NULL COMMENT '领导拜访次数',
  `field_Oad4W__c` varchar(50) DEFAULT NULL COMMENT '是否外采(是否需外采设备或系统)',
  `life_status_before_invalid` varchar(50) DEFAULT NULL COMMENT '作废前生命状态',
  `field_XUAtn__c` varchar(50) DEFAULT NULL COMMENT '景区客户分层数据',
  `field_blxpO__c` varchar(50) DEFAULT NULL COMMENT '竞争对手',
  `field_81E5a__c` varchar(50) DEFAULT NULL COMMENT '旅行社类型',
  `field_0IxkG__c` varchar(50) DEFAULT NULL COMMENT '关联报价单',
  `field_b8dY9__c` varchar(50) DEFAULT NULL COMMENT '输单原因',
  `field_83QGd__c` varchar(255) DEFAULT NULL COMMENT '上传《需求调研表（AR）》',
  `field_3mh20__c` varchar(50) DEFAULT NULL COMMENT '维保报价折扣',
  `field_1d8sn__c` varchar(100) DEFAULT NULL COMMENT '上传《项目跟踪文档》或《解决方案》',
  `version` varchar(50) DEFAULT NULL COMMENT 'version',
  `field_AJmAY__c` varchar(50) DEFAULT NULL COMMENT '拜访次数',
  `field_imqW2__c` varchar(50) DEFAULT NULL COMMENT '踏勘报告',
  `field_7ev17__c` varchar(50) DEFAULT NULL COMMENT '竞品对比',
  `tenant_id` varchar(50) DEFAULT NULL COMMENT 'tenant_id',
  `field_so8f2__c` varchar(50) DEFAULT NULL COMMENT '是否完成踏勘（勿删）',
  `field_6Z41x__c` datetime DEFAULT NULL COMMENT '初步接洽阶段变更时间',
  `field_o54m9__c` varchar(50) DEFAULT NULL COMMENT '指定归属部门',
  `field_JIV22__c` varchar(50) DEFAULT NULL COMMENT '上传《终版需求清单》',
  `origin_source` varchar(50) DEFAULT NULL COMMENT '数据来源',
  `field_sv42w__c` varchar(50) DEFAULT NULL COMMENT '判定销售模式',
  `field_pCx4U__c` varchar(50) DEFAULT NULL COMMENT '上传《维保报价单》附件',
  `field_6teIr__c` varchar(50) DEFAULT NULL COMMENT '报价单审核状态',
  `field_QE4hi__c` varchar(50) DEFAULT NULL COMMENT '是否使用竞品策略',
  `email` varchar(50) DEFAULT NULL COMMENT '邮件',
  `field_02q17__c` datetime DEFAULT NULL COMMENT '日期',
  `field_ov1m1__c` varchar(50) DEFAULT NULL COMMENT '市区',
  `field_0uyXs__c` varchar(50) DEFAULT NULL COMMENT '折扣比例',
  `field_z27EP__c` varchar(50) DEFAULT NULL COMMENT '商机类型',
  `field_0O3w1__c` varchar(50) DEFAULT NULL COMMENT '招投标类型',
  `field_yL225__c` datetime DEFAULT NULL COMMENT '输单阶段变更日期',
  `field_Cct5j__c` double DEFAULT NULL COMMENT '明细总价',
  `field_2ha97__c` datetime DEFAULT NULL COMMENT '赢单阶段变更日期',
  `field_1bgFc__c` datetime DEFAULT NULL COMMENT '谈判签约阶段变更时间',
  `owner` varchar(50) DEFAULT NULL COMMENT '负责人',
  `field_qEw4b__c` varchar(50) DEFAULT NULL COMMENT '是否推荐官',
  `field_04w3j__c` varchar(50) DEFAULT NULL COMMENT '联系人职务',
  `field_nxYCu__c` varchar(50) DEFAULT NULL COMMENT '输单前客户阶段',
  `field_urofz__c` varchar(50) DEFAULT NULL COMMENT '上传《调研记录》',
  `field_B6OkU__c` varchar(50) DEFAULT NULL COMMENT '上传《售后服务回访表》',
  `field_eCDjL__c` varchar(50) DEFAULT NULL COMMENT '线下遇到竞品',
  `field_byhvk__c` varchar(50) DEFAULT NULL COMMENT '合作伙伴名称',
  `field_Vx6f4__c` datetime DEFAULT NULL COMMENT '需求确认阶段变更时间',
  `field_R7gcC__c` varchar(50) DEFAULT NULL COMMENT '合作需求',
  `field_A6LzS__c` varchar(50) DEFAULT NULL COMMENT '区总拜访次数',
  `field_qL7A1__c` varchar(100) DEFAULT NULL COMMENT '上传《需求调研表（SR）》',
  `field_jza12__c` varchar(50) DEFAULT NULL COMMENT 'SR',
  `field_0L271__c` varchar(50) DEFAULT NULL COMMENT '是否招投标',
  `field_vB7jy__c` varchar(50) DEFAULT NULL COMMENT '报价清单',
  `field_23wLl__c` varchar(50) DEFAULT NULL COMMENT '景区类型',
  `order_by` varchar(50) DEFAULT NULL COMMENT 'order_by',
  `field_7w49u__c` varchar(50) DEFAULT NULL COMMENT '客户需求',
  `field_2g0cn__c` varchar(50) DEFAULT NULL COMMENT '线下遇到竞品',
  `field_4nplS__c` varchar(50) DEFAULT NULL COMMENT '省份',
  `extend_obj_data_id` varchar(50) DEFAULT NULL COMMENT 'extend_obj_data_id',
  `field_wC4oz__c` varchar(50) DEFAULT NULL COMMENT '是否定制(产品是否涉及定制)',
  `field_05RV4__c` varchar(50) DEFAULT NULL COMMENT '指定CSR人员',
  `field_42uG9__c` varchar(50) DEFAULT NULL COMMENT '是否有创建项目交接单',
  `package` varchar(50) DEFAULT NULL COMMENT 'package',
  `field_6MT2N__c` varchar(50) DEFAULT NULL COMMENT '相关团队人员部门',
  `field_18jj7__c` varchar(50) DEFAULT NULL COMMENT '成交条件',
  `field_ngNlf__c` varchar(50) DEFAULT NULL COMMENT '现场踏勘人员',
  `field_K3g0q__c` varchar(50) DEFAULT NULL COMMENT '指派阶段',
  `field_mpD2y__c` datetime DEFAULT NULL COMMENT '挂起阶段变更日期',
  `field_6woz2__c` varchar(50) DEFAULT NULL COMMENT 'CSR是否前置介入',
  `field_Y8un0__c` varchar(50) DEFAULT NULL COMMENT '与竞品合作原因',
  `field_37j3a__c` datetime DEFAULT NULL COMMENT '方案确认阶段变更时间',
  `field_9wq8e__c` varchar(50) DEFAULT NULL COMMENT '联系方式',
  `field_t18aj__c__r` varchar(50) DEFAULT NULL COMMENT 'CSR负责人',
  PRIMARY KEY (`id`),
  KEY `idx_platform_id` (`platform_id`)
) ENGINE=InnoDB AUTO_INCREMENT=31593 DEFAULT CHARSET=utf8mb4 COMMENT='商机管理表';

-- @table RDS_crm_erp:pft_crm_order_payment
-- @at 2026-11-27 16:15:28
-- @cmt add_time 供应商+产品最早上架资源中心票的时间
-- @cmt update_time 更新时间
CREATE TABLE `pft_crm_order_payment` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(50) NOT NULL DEFAULT '' COMMENT '回款明细编号',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `offset` int(10) NOT NULL DEFAULT '0' COMMENT '序号',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `approve_employee_id` varchar(50) NOT NULL DEFAULT '' COMMENT '当前审批人',
  `finance_employee_id` varchar(50) NOT NULL DEFAULT '' COMMENT '财务确认人',
  `payment_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '回款日期',
  `field_83G4A__c` varchar(50) NOT NULL DEFAULT '' COMMENT '付款方式',
  `remark` varchar(500) NOT NULL DEFAULT '' COMMENT '备注',
  `lock_user` varchar(100) NOT NULL DEFAULT '' COMMENT '加锁人',
  `attachment` varchar(500) NOT NULL DEFAULT '' COMMENT '附件',
  `payment_id` varchar(50) NOT NULL DEFAULT '' COMMENT '回款记录编号',
  `object_describe_api_name` varchar(100) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `out_owner` varchar(200) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `owner_department` varchar(50) NOT NULL DEFAULT '' COMMENT '负责人所在部门',
  `owner__r` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人',
  `finance_confirm_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '财务确认时间',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `payment_term` varchar(50) NOT NULL DEFAULT '' COMMENT 'pay',
  `submit_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '审批提交时间',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `payment_amount` varchar(50) NOT NULL DEFAULT '' COMMENT '本次回款金额',
  `last_modified_by__r` varchar(30) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `out_tenant_id` varchar(70) NOT NULL DEFAULT '' COMMENT '外部企业',
  `created_by__r` varchar(50) NOT NULL DEFAULT '' COMMENT '创建人',
  `record_type` varchar(20) NOT NULL DEFAULT '' COMMENT '业务类型',
  `relevant_team__r` varchar(30) NOT NULL DEFAULT '' COMMENT '相关团队',
  `notification_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '提醒日期',
  `data_own_department` varchar(30) NOT NULL DEFAULT '' COMMENT '归属部门',
  `account_id` varchar(50) NOT NULL DEFAULT '' COMMENT '客户名称',
  `payment_plan_id` varchar(50) NOT NULL DEFAULT '' COMMENT '回款计划编号',
  `order_id` varchar(50) NOT NULL DEFAULT '' COMMENT '合同编号',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `field_1594d__c` varchar(50) NOT NULL DEFAULT '' COMMENT '合作类型',
  `field_huGh5__c` varchar(80) DEFAULT NULL COMMENT '归属人id',
  `field_huGh5__c__r` varchar(30) DEFAULT NULL COMMENT '归属人name',
  `field_g8Dix__c` varchar(20) DEFAULT NULL COMMENT '回款类型',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16429 DEFAULT CHARSET=utf8mb4 COMMENT='回款明细表';

-- @table RDS_crm_erp:pft_crm_out_side_attendance
-- @at 2026-11-27 16:15:34
-- @cmt check_key 核验键
-- @cmt id 主键ID
CREATE TABLE `pft_crm_out_side_attendance` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `check_key` varchar(256) DEFAULT NULL,
  `open_user_id` varchar(64) DEFAULT NULL COMMENT '用户开平账号',
  `user_name` varchar(64) DEFAULT NULL COMMENT '用户昵称',
  `checkins_time_stamp` datetime DEFAULT NULL COMMENT '签到时间',
  `checkins_address_desc` varchar(256) DEFAULT NULL COMMENT '外勤签到地址',
  `customer_id` varchar(64) DEFAULT NULL COMMENT '关联客户Id',
  `device_risk` tinyint(1) DEFAULT NULL COMMENT '设备异常: true-异常、false-正常',
  `content_text` varchar(128) DEFAULT NULL COMMENT '文字描述',
  `checkins_distnace` varchar(32) DEFAULT NULL COMMENT '签到距离',
  `cheat_risk` varchar(16) DEFAULT NULL COMMENT '系统风险: 0- 正常、1- IOS越狱、2- Android 作弊软件、3- Android 伪造地址、4 模拟器、5 root',
  `checkins_lon` decimal(10,0) DEFAULT NULL COMMENT '签到经度',
  `checkins_lat` decimal(10,0) DEFAULT NULL COMMENT '签到纬度',
  `checkout_time_stamp` datetime DEFAULT NULL COMMENT '签退时间',
  `checkout_address_desc` varchar(256) DEFAULT NULL COMMENT '外勤签退地址',
  `checkout_lon` decimal(10,0) DEFAULT NULL COMMENT '签退经度',
  `checkout_lat` decimal(10,0) DEFAULT NULL COMMENT '签退纬度',
  `check_type` int(11) DEFAULT NULL COMMENT '类型 1：签到，2：签退',
  PRIMARY KEY (`id`),
  KEY `idx_check_key` (`check_key`),
  KEY `idx_user` (`open_user_id`,`user_name`),
  KEY `idx_check_time` (`checkins_time_stamp`,`checkout_time_stamp`)
) ENGINE=InnoDB AUTO_INCREMENT=4632 DEFAULT CHARSET=utf8 COMMENT='crm外勤表';

-- @table RDS_crm_erp:pft_crm_payment
-- @at 2026-11-27 16:15:42
-- @cmt add_time 供应商+产品最早上架资源中心票的时间
-- @cmt update_time 更新时间
CREATE TABLE `pft_crm_payment` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `NAME` varchar(50) NOT NULL DEFAULT '' COMMENT '回款编号',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `OFFSET` int(10) NOT NULL DEFAULT '0' COMMENT '序号',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `approve_employee_id` varchar(100) NOT NULL DEFAULT '' COMMENT '当前审批人',
  `purpose` varchar(50) NOT NULL DEFAULT '' COMMENT '回款用途',
  `finance_employee_id` varchar(100) NOT NULL DEFAULT '' COMMENT '财务确认人',
  `payment_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '回款时间',
  `field_PIj68__c` varchar(50) NOT NULL DEFAULT '' COMMENT '回款类型',
  `approved_employee_id` varchar(100) NOT NULL DEFAULT '' COMMENT '已审批人',
  `remark` varchar(500) NOT NULL DEFAULT '' COMMENT '备注',
  `available_amount` varchar(50) NOT NULL DEFAULT '' COMMENT '可用金额',
  `lock_user` varchar(50) NOT NULL DEFAULT '' COMMENT '加锁人',
  `attachment` varchar(1000) NOT NULL DEFAULT '' COMMENT '附件',
  `object_describe_api_name` varchar(100) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `owner_department` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `out_owner` varchar(50) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `owner__r` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人',
  `field_owSmU__c` varchar(50) NOT NULL DEFAULT '' COMMENT '付款方式',
  `amount` varchar(50) NOT NULL DEFAULT '' COMMENT '回款金额',
  `finance_confirm_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '财务确认时间',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `payment_term` varchar(50) NOT NULL DEFAULT '' COMMENT '回款方式',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `submit_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '回款提交时间',
  `payment_amount` varchar(50) NOT NULL DEFAULT '' COMMENT '已用金额',
  `last_modified_by` varchar(30) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `out_tenant_id` varchar(100) NOT NULL DEFAULT '' COMMENT '外部企业',
  `created_by` varchar(50) NOT NULL DEFAULT '' COMMENT '创建人',
  `relevant_team` varchar(100) NOT NULL DEFAULT '' COMMENT '相关团队',
  `record_type` varchar(20) NOT NULL DEFAULT '' COMMENT '业务类型',
  `notification_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '提醒日期',
  `account_id` varchar(50) NOT NULL DEFAULT '' COMMENT '客户名称',
  `data_own_department` varchar(50) NOT NULL DEFAULT '' COMMENT '归属部门',
  `order_id` varchar(500) NOT NULL DEFAULT '' COMMENT '合同编号',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `erp_id` varchar(20) DEFAULT '',
  `field_cxNon__c` varchar(100) NOT NULL DEFAULT '' COMMENT '打款名称',
  PRIMARY KEY (`id`),
  KEY `idx_platform_id` (`platform_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15481 DEFAULT CHARSET=utf8mb4 COMMENT='回款记录表';

-- @table RDS_crm_erp:pft_crm_personnel
-- @at 2026-11-27 11:45:17
CREATE TABLE `pft_crm_personnel` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '系统名（昵称）',
  `crm_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `leader` varchar(50) NOT NULL DEFAULT '' COMMENT '汇报对象',
  `lock_rule` varchar(30) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `user_id` varchar(40) NOT NULL DEFAULT '' COMMENT 'userid',
  `userid__c` varchar(30) NOT NULL DEFAULT '' COMMENT 'OA-Userid',
  `work_phone` varchar(30) NOT NULL DEFAULT '' COMMENT '办公电话',
  `msn` varchar(30) NOT NULL DEFAULT '' COMMENT 'msn ',
  `language` varchar(20) NOT NULL DEFAULT '' COMMENT '语言',
  `qq_account` varchar(20) NOT NULL DEFAULT '' COMMENT 'qq号码',
  `password` varchar(20) NOT NULL DEFAULT '' COMMENT '密码',
  `profile_image` varchar(300) NOT NULL DEFAULT '' COMMENT '头像',
  `weixin_account` varchar(20) NOT NULL DEFAULT '' COMMENT '微信号码',
  `date_of_first_ployment` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '就业日期',
  `employee_create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '员工创建时间',
  `owner_department` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人所在部门',
  `vice_departments` varchar(30) NOT NULL DEFAULT '' COMMENT '附属部门',
  `name_spell` varchar(100) NOT NULL DEFAULT '' COMMENT '拼音',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `data_own_department` varchar(30) NOT NULL DEFAULT '' COMMENT '归属部门id',
  `data_own_department__r` varchar(30) NOT NULL DEFAULT '' COMMENT '归属部门',
  `full_name` varchar(30) NOT NULL DEFAULT '' COMMENT '姓名',
  `phone` varchar(30) NOT NULL DEFAULT '' COMMENT '手机',
  `employee_number` varchar(30) NOT NULL DEFAULT '' COMMENT '办公电话扩展分机号',
  `extension_number` varchar(30) NOT NULL DEFAULT '' COMMENT '员工编号',
  `date_of_joining` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '入职日期',
  `position` varchar(30) NOT NULL DEFAULT '' COMMENT '职位',
  `status` varchar(20) NOT NULL DEFAULT '' COMMENT '员工状态',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `last_modified_by` varchar(100) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '新增时间',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '修改时间',
  `OAUserid__c` varchar(50) NOT NULL DEFAULT '' COMMENT 'OA-Userid',
  PRIMARY KEY (`id`),
  KEY `idx_crm_id` (`crm_id`)
) ENGINE=InnoDB AUTO_INCREMENT=662 DEFAULT CHARSET=utf8mb4 COMMENT='人员信息表';

-- @table RDS_crm_erp:pft_crm_product
-- @at 2026-11-27 16:15:52
-- @cmt add_time 供应商+产品最早上架资源中心票的时间
-- @cmt update_time 更新时间
CREATE TABLE `pft_crm_product` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '产品名称',
  `field_QMJ84__c` varchar(100) NOT NULL DEFAULT '' COMMENT '产品型号/版本',
  `product_code` varchar(100) NOT NULL DEFAULT '' COMMENT '产品编码',
  `offset` int(10) NOT NULL DEFAULT '0' COMMENT '序号',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `is_saleable` tinyint(1) NOT NULL DEFAULT '0' COMMENT '可独立销售',
  `field_277XC__c` varchar(30) NOT NULL DEFAULT '' COMMENT '税率',
  `field_Z2Lsz__c` varchar(30) NOT NULL DEFAULT '' COMMENT '业务结算价（含内部结算价）',
  `off_shelves_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '下架时间',
  `price` varchar(30) NOT NULL DEFAULT '' COMMENT '标准价格',
  `field_jc99S__c` varchar(50) NOT NULL DEFAULT '' COMMENT '开票名称',
  `owner_department` varchar(50) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `data_own_department__r` varchar(100) NOT NULL DEFAULT '' COMMENT '归属部门',
  `data_own_department` varchar(50) NOT NULL DEFAULT '' COMMENT '归属部门',
  `model` varchar(50) NOT NULL DEFAULT '' COMMENT '型号',
  `field_EmoN9__c` varchar(50) NOT NULL DEFAULT '' COMMENT '厂家',
  `barcode` varchar(100) NOT NULL DEFAULT '' COMMENT '条形码',
  `maintenance_period` varchar(30) NOT NULL DEFAULT '' COMMENT '保养周期',
  `field_thjdm__c` varchar(50) NOT NULL DEFAULT '' COMMENT '对应比例2',
  `field_51rfV__c` varchar(50) NOT NULL DEFAULT '' COMMENT '渠道代理价',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `is_giveaway` varchar(5) NOT NULL DEFAULT '' COMMENT '是否赠品',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `field_2Vauf__c` varchar(50) NOT NULL DEFAULT '' COMMENT '最低限价',
  `order_field` varchar(100) NOT NULL DEFAULT '' COMMENT '排序',
  `created_by__l` varchar(30) NOT NULL DEFAULT '' COMMENT '创建人',
  `created_by__r` varchar(50) NOT NULL DEFAULT '' COMMENT '创建人',
  `relevant_team` varchar(500) NOT NULL DEFAULT '' COMMENT '相关团队',
  `field_Rdpcz__c` varchar(100) NOT NULL DEFAULT '' COMMENT '合同产品名',
  `field_9k065__c` varchar(50) NOT NULL DEFAULT '' COMMENT '所属产品线2',
  `product_line` varchar(50) NOT NULL DEFAULT '' COMMENT '产品线',
  `field_Olx95__c` varchar(1000) NOT NULL DEFAULT '' COMMENT '销售配置',
  `unit` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `field_fdm25__c` varchar(20) NOT NULL DEFAULT '' COMMENT '是否共背',
  `unitR` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `field_IP6hS__c` varchar(50) NOT NULL DEFAULT '' COMMENT '软件著作权',
  `field_wLj8x__c` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `description` varchar(50) NOT NULL DEFAULT '' COMMENT '图文描述',
  `product_status` varchar(5) NOT NULL DEFAULT '' COMMENT '上下架',
  `field_Zj1hj__c` varchar(500) NOT NULL DEFAULT '' COMMENT '备注',
  `replacement_period` varchar(20) NOT NULL DEFAULT '' COMMENT '更换周期（天）',
  `field_9191l__c` varchar(100) NOT NULL DEFAULT '' COMMENT '所属产品线1',
  `lock_user` varchar(100) NOT NULL DEFAULT '' COMMENT '加锁人',
  `on_shelves_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '上架时间',
  `safety_stock` varchar(30) NOT NULL DEFAULT '' COMMENT '安全库存',
  `field_zOOlv__c` varchar(30) NOT NULL DEFAULT '' COMMENT '采购价',
  `field_4Tu86__c` varchar(30) NOT NULL DEFAULT '' COMMENT '对应比例1',
  `object_describe_api_name` varchar(50) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `out_owner` varchar(50) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `owner__r` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人',
  `picture_path` varchar(50) NOT NULL DEFAULT '' COMMENT '产品图片',
  `is_package` varchar(100) NOT NULL DEFAULT '' COMMENT '产品组合',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `last_modified_by__r` varchar(100) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `technical_parameter` varchar(100) NOT NULL DEFAULT '' COMMENT '技术参数',
  `out_tenant_id` varchar(50) NOT NULL DEFAULT '' COMMENT '外部企业',
  `record_type` varchar(50) NOT NULL DEFAULT '' COMMENT '业务类型',
  `product_spec` varchar(1000) NOT NULL DEFAULT '' COMMENT '规格属性',
  `category` varchar(50) NOT NULL DEFAULT '' COMMENT '分类',
  `erp_state` tinyint(2) DEFAULT '0',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `field_x4hKs__c` varchar(20) DEFAULT NULL COMMENT '软硬件判断（隐藏）',
  `option1` varchar(50) DEFAULT NULL COMMENT '自定义',
  `option2` varchar(50) DEFAULT '' COMMENT '自定义2',
  `option3` varchar(50) DEFAULT '' COMMENT '自定义3',
  `option4` varchar(50) DEFAULT '' COMMENT '自定义4',
  `option5` varchar(50) DEFAULT '' COMMENT '自定义5',
  `option6` varchar(50) DEFAULT '' COMMENT '自定义6',
  `option7` varchar(50) DEFAULT '' COMMENT '自定义7',
  `option8` varchar(50) DEFAULT '' COMMENT '自定义8',
  `option9` varchar(50) DEFAULT '' COMMENT '自定义9',
  `option10` varchar(50) DEFAULT '' COMMENT '自定义10',
  `option11` varchar(50) DEFAULT '' COMMENT '自定义11',
  `option12` varchar(50) DEFAULT '' COMMENT '自定义12',
  `option13` varchar(50) DEFAULT '' COMMENT '自定义13',
  `option14` varchar(50) DEFAULT '' COMMENT '自定义14',
  `option15` varchar(50) DEFAULT '' COMMENT '自定义15',
  `field_1VOgx__c` varchar(20) DEFAULT NULL COMMENT '外采判定',
  `hardware_accompanying_soft__c` varchar(20) DEFAULT NULL COMMENT '硬件配套软件',
  PRIMARY KEY (`id`),
  KEY `idx_platform_id` (`platform_id`),
  KEY `idx_product_code` (`product_code`)
) ENGINE=InnoDB AUTO_INCREMENT=4648 DEFAULT CHARSET=utf8mb4 COMMENT='产品表';

-- @table RDS_crm_erp:pft_crm_project
-- @at 2026-11-27 16:15:57
-- @cmt _id ID
-- @cmt id 主键ID
CREATE TABLE `pft_crm_project` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL COMMENT '项目名称',
  `_id` varchar(50) DEFAULT NULL,
  `field_1Sm9f__c` varchar(30) DEFAULT NULL COMMENT '项目编号',
  `field_zQMau__c` varchar(50) DEFAULT NULL COMMENT '关联合同订单',
  `field_zQMau__c__r` varchar(30) DEFAULT NULL COMMENT '关联合同订单编号',
  `new_opportunity_id` varchar(50) DEFAULT NULL COMMENT '关联商机',
  `new_opportunity_id__r` varchar(50) DEFAULT NULL COMMENT '关联商机名称',
  `account_id` varchar(50) DEFAULT NULL COMMENT '客户名称id',
  `account_id__r` varchar(50) DEFAULT NULL COMMENT '客户名称',
  `field_4wf2F__c` varchar(20) DEFAULT NULL COMMENT '项目类型',
  `field_gMzy7__c` varchar(50) DEFAULT NULL COMMENT '区域负责人',
  `field_idoJp__c` varchar(50) DEFAULT NULL COMMENT '方案经理',
  `field_7g272__c` varchar(50) DEFAULT NULL COMMENT '项目经理',
  `field_Dff3M__c` varchar(50) DEFAULT NULL COMMENT '实施工程师',
  `field_0bQ0W__c` varchar(50) DEFAULT NULL COMMENT '客户成功经理',
  `field_10H51__c` varchar(50) DEFAULT NULL COMMENT '采购物控',
  `field_8mHhN__c` varchar(50) DEFAULT NULL COMMENT '产品经理',
  `field_cZh1u__c` varchar(50) DEFAULT NULL COMMENT '销售经理',
  `field_Ex4jG__c` varchar(50) DEFAULT NULL COMMENT '甲方名称',
  `field_5k8fW__c` varchar(50) DEFAULT NULL COMMENT '票付通平台账号ID',
  `project_no` varchar(30) DEFAULT NULL COMMENT '项目编号（系统）',
  `owner` varchar(50) DEFAULT NULL COMMENT '负责人',
  `data_own_department` varchar(50) DEFAULT NULL COMMENT '归属部门',
  `field_dVv1l__c` varchar(20) DEFAULT NULL COMMENT '项目复杂程度',
  `field_H1U7i__c` varchar(20) DEFAULT NULL COMMENT '验收状态',
  `life_status` varchar(20) DEFAULT NULL COMMENT '生命状态',
  `create_time` timestamp NULL DEFAULT NULL COMMENT '创建时间',
  `last_modified_time` timestamp NULL DEFAULT NULL COMMENT '最后修改时间',
  `field_188l2__c` timestamp NULL DEFAULT NULL COMMENT '交接时间',
  `field_CBx20__c` varchar(50) DEFAULT NULL COMMENT '合同类型',
  `field_6J29p__c` timestamp NULL DEFAULT NULL COMMENT '项目验收日期',
  `field_2Hci0__c` timestamp NULL DEFAULT NULL COMMENT '确认收入日期',
  `field_1bOO5__c` varchar(30) DEFAULT NULL COMMENT '项目阶段',
  `field_21UYP__c` varchar(100) DEFAULT NULL COMMENT '阻塞类型',
  `field_0SI5q__c` datetime DEFAULT NULL COMMENT '核定验收时间',
  `field_0280W__c` varchar(50) DEFAULT NULL COMMENT '项目类型',
  `field_G21zC__c` varchar(50) DEFAULT NULL COMMENT '复杂度值',
  `field_J5Gel__c` date DEFAULT NULL COMMENT '项目计划完工日期',
  `field_6s65o__c` varchar(32) DEFAULT NULL COMMENT '合同归属部门',
  `field_M7L5u__c` double DEFAULT NULL COMMENT '确认收入金额',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12899 DEFAULT CHARSET=utf8 COMMENT='CRM项目表';

-- @table RDS_crm_erp:pft_crm_project_connect
-- @at 2026-11-27 11:46:06
CREATE TABLE `pft_crm_project_connect` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `field_kWMp2__c` varchar(100) NOT NULL DEFAULT '' COMMENT '甲方名称',
  `field_239C0__c` varchar(100) NOT NULL DEFAULT '' COMMENT '项目名称',
  `field_c2Me6__c` varchar(50) NOT NULL DEFAULT '' COMMENT '第三方出资',
  `field_15GhW__c` varchar(90) NOT NULL DEFAULT '' COMMENT '收货人',
  `field_jZwgP__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '部份上线时间',
  `field_e9MP2__c` varchar(30) NOT NULL DEFAULT '' COMMENT '费率',
  `field_HDvu8__c` varchar(50) NOT NULL DEFAULT '' COMMENT '合同类型',
  `field_vq9sF__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '合同结束时间',
  `field_422xj__c` varchar(100) NOT NULL DEFAULT '' COMMENT '微商城',
  `field_1g4h7__c` varchar(30) NOT NULL DEFAULT '' COMMENT '12',
  `field_1GZYf__c` varchar(50) NOT NULL DEFAULT '' COMMENT '客户类型',
  `field_z7rBS__c` varchar(200) NOT NULL DEFAULT '' COMMENT '收款方式',
  `owner_department` varchar(20) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `field_6G8M0__c` varchar(30) NOT NULL DEFAULT '' COMMENT '是否国营',
  `field_50r24__c` varchar(30) NOT NULL DEFAULT '' COMMENT '业务类型选项',
  `field_GDxk8__c` varchar(100) NOT NULL DEFAULT '' COMMENT '关联客户信息',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `field_HrG1q__c` varchar(200) NOT NULL DEFAULT '' COMMENT '收货地址',
  `field_mvJbO__c` varchar(50) NOT NULL DEFAULT '' COMMENT '指派项目经理',
  `created_by` varchar(50) NOT NULL DEFAULT '' COMMENT '创建人',
  `relevant_team` varchar(100) NOT NULL DEFAULT '' COMMENT '相关团队',
  `field_pKpac__c` varchar(200) NOT NULL DEFAULT '' COMMENT '其他',
  `field_zg3Y3__c` varchar(200) NOT NULL DEFAULT '' COMMENT '云票务',
  `data_own_department` varchar(50) NOT NULL DEFAULT '' COMMENT '归属部门',
  `field_3suG8__c` varchar(100) NOT NULL DEFAULT '' COMMENT '12301平台',
  `field_Kf9GR__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '合同开始时间',
  `field_orrv5__c` varchar(30) NOT NULL DEFAULT '' COMMENT '景区类型',
  `field_6C2eI__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '预计上线时间',
  `name` varchar(50) NOT NULL DEFAULT '' COMMENT '主属性',
  `crm_id` varchar(50) NOT NULL DEFAULT '' COMMENT '项目id',
  `field_gqSrh__c` varchar(50) NOT NULL DEFAULT '' COMMENT '关联合同订单',
  `field_0djNe__c` varchar(50) NOT NULL DEFAULT '' COMMENT '景区等级',
  `field_72k1S__c` varchar(50) NOT NULL DEFAULT '' COMMENT '指派实施工程师',
  `field_5Ly2X__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '独立收款上线时间',
  `field_1Sbsc__c` varchar(50) NOT NULL DEFAULT '' COMMENT '预投项目',
  `field_uawxi__c` varchar(50) NOT NULL DEFAULT '' COMMENT '电话',
  `field_3ubCn__c` varchar(500) NOT NULL DEFAULT '' COMMENT '销售口头承诺',
  `field_ksK0Y__c` varchar(300) NOT NULL DEFAULT '' COMMENT '项目背景',
  `field_d018y__c` varchar(100) NOT NULL DEFAULT '' COMMENT '其他集成综合布线',
  `lock_user` varchar(50) NOT NULL DEFAULT '' COMMENT '加锁人',
  `field_jBxO5__c` varchar(50) NOT NULL DEFAULT '' COMMENT '项目类型',
  `field_cufm6__c` varchar(20) NOT NULL DEFAULT '' COMMENT '合同是否关联',
  `field_ae2tA__c` varchar(600) NOT NULL DEFAULT '' COMMENT '备注',
  `field_GMl61__c` varchar(50) NOT NULL DEFAULT '' COMMENT '景区名称',
  `object_describe_api_name` varchar(200) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `out_owner` varchar(50) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `field_6726e__c` varchar(500) NOT NULL DEFAULT '' COMMENT '附件',
  `field_rt6U4__c` varchar(50) NOT NULL DEFAULT '' COMMENT '票付通平台账号ID',
  `field_6x8Bd__c` varchar(50) NOT NULL DEFAULT '' COMMENT '指派客服人员',
  `field_Lp5yW__c` varchar(100) NOT NULL DEFAULT '' COMMENT '票务系统综合布线',
  `field_Dsmn2__c` varchar(50) NOT NULL DEFAULT '' COMMENT '合同金额',
  `owner` varchar(50) NOT NULL DEFAULT '' COMMENT '负责人',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `last_modified_by` varchar(150) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `out_tenant_id` varchar(30) NOT NULL DEFAULT '' COMMENT '外部企业',
  `field_4wdjE__c` varchar(30) NOT NULL DEFAULT '' COMMENT '未开通独立收款原因',
  `field_Xml71__c` varchar(30) NOT NULL DEFAULT '' COMMENT '供应商权限',
  `field_5G6ym__c` varchar(30) NOT NULL DEFAULT '' COMMENT '是否标准化项目',
  `record_type` varchar(100) NOT NULL DEFAULT '' COMMENT '业务类型',
  `field_121O4__c` varchar(30) NOT NULL DEFAULT '' COMMENT '是否需要项目主管',
  `field_L2Rp8__c` varchar(200) NOT NULL DEFAULT '' COMMENT '景区地址',
  `field_0Y11G__c` varchar(10) NOT NULL DEFAULT '' COMMENT '是否新增平台账户',
  `csr` varchar(100) DEFAULT NULL COMMENT 'CSR',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1628 DEFAULT CHARSET=utf8mb4 COMMENT='项目交接单';

-- @table RDS_crm_erp:pft_crm_sales_order
-- @at 2026-11-27 11:47:46
CREATE TABLE `pft_crm_sales_order` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(50) NOT NULL DEFAULT '' COMMENT '订单名称',
  `field_jFo4a__c` varchar(50) NOT NULL DEFAULT '' COMMENT '城市',
  `offset` int(10) NOT NULL DEFAULT '0' COMMENT '序号',
  `discount` varchar(30) NOT NULL DEFAULT '' COMMENT '折扣',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `account_id` varchar(50) NOT NULL DEFAULT '' COMMENT '客户名称',
  `account_id__r` varchar(100) NOT NULL DEFAULT '' COMMENT '客户名称',
  `order_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '订单时间',
  `field_fN4cl__c` varchar(200) NOT NULL DEFAULT '' COMMENT '通讯地址',
  `field_5x6zE__c` varchar(30) NOT NULL DEFAULT '' COMMENT '到货款（计算）',
  `data_own_department__r` varchar(50) NOT NULL DEFAULT '' COMMENT '归属部门',
  `new_opportunity_id` varchar(50) NOT NULL DEFAULT '' COMMENT '商机id',
  `new_opportunity_id__r` varchar(100) NOT NULL DEFAULT '' COMMENT '商机名称',
  `payment_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '已回款金额(元)',
  `field_2uY29__c` varchar(30) NOT NULL DEFAULT '' COMMENT '客户类型',
  `field_L068S__c` varchar(30) NOT NULL DEFAULT '' COMMENT '年总客流',
  `field_a4xaC__c` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否标准合同',
  `field_ariL1__c` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否分期付',
  `field_8Ys5r__c` varchar(30) NOT NULL DEFAULT '' COMMENT '景区类型',
  `receipt_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '已开票金额(元)',
  `no_receipt_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '待开票金额(元)',
  `receipt_status` varchar(30) NOT NULL DEFAULT '' COMMENT '开票完成状态',
  `returned_goods_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '退货单金额',
  `refund_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '已退款金额',
  `product_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '产品合计',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `field_fuz3J__c` varchar(30) NOT NULL DEFAULT '' COMMENT '预付款（计算）',
  `field_Xjw8n__c` varchar(20) NOT NULL DEFAULT '' COMMENT '省',
  `current_level` varchar(20) NOT NULL DEFAULT '' COMMENT '已审批节点数量',
  `field_Nc472__c` varchar(30) NOT NULL DEFAULT '' COMMENT '单日最高客流',
  `logistics_status` varchar(20) NOT NULL DEFAULT '' COMMENT '发货状态',
  `created_by__r` varchar(30) NOT NULL DEFAULT '' COMMENT '创建人',
  `order_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '销售金额',
  `owner_department` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `owner_department_id` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人主属部门id',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `submit_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '提交时间',
  `resource` varchar(20) NOT NULL DEFAULT '' COMMENT '来源',
  `relevant_team__r` varchar(100) NOT NULL DEFAULT '' COMMENT '相关团队',
  `field_Yp7i2__c` varchar(30) NOT NULL DEFAULT '' COMMENT '协议状态',
  `field_d0en6__c` varchar(30) NOT NULL DEFAULT '' COMMENT '验收款（计算）',
  `field_tajfO__c` varchar(30) NOT NULL DEFAULT '' COMMENT '质保金（计算）',
  `htztai__c` varchar(30) NOT NULL DEFAULT '' COMMENT '合同状态 1待提交2审批中3审批通过4审批未通过5已签约6部门审批通过other其他',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除',
  `owner__r` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人',
  `field_zl1Df__c` tinyint(1) NOT NULL DEFAULT '0' COMMENT '合同合规性',
  `field_lF70b__c` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否以票抵款',
  `field_pgsdj__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '合同结束日期',
  `last_modified_by__r` varchar(60) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `field_8yeP2__c` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否借用合同',
  `record_type` varchar(30) NOT NULL DEFAULT '' COMMENT '业务类型',
  `lock_rule` varchar(40) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `settle_type` varchar(50) NOT NULL DEFAULT '' COMMENT '结算方式',
  `field_eAynp__c` varchar(100) NOT NULL DEFAULT '' COMMENT '历史签约产品',
  `order_title` varchar(100) NOT NULL DEFAULT '' COMMENT '合同标题',
  `wait_returned_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '待回款金额（元）',
  `ship_to_id` varchar(40) NOT NULL DEFAULT '' COMMENT '联系人',
  `field_05tG4__c` varchar(40) NOT NULL DEFAULT '' COMMENT '部门名称',
  `contract_property` varchar(50) NOT NULL DEFAULT '' COMMENT '合同属性',
  `field_xtkpe__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '合同开始日期',
  `before_content` varchar(2000) NOT NULL DEFAULT '' COMMENT '其他模板条款修改内容修动前',
  `day_pay` varchar(30) NOT NULL DEFAULT '' COMMENT '合同生效后多少工作日付款',
  `quote_id` varchar(50) NOT NULL DEFAULT '' COMMENT '关联报价单',
  `DHWWb__c` varchar(50) NOT NULL DEFAULT '' COMMENT '甲方名称',
  `contract_type` varchar(50) NOT NULL DEFAULT '' COMMENT '合同类型',
  `shipments_comment` varchar(50) NOT NULL DEFAULT '' COMMENT '发货备注',
  `field_8I2qf__c` varchar(50) NOT NULL DEFAULT '' COMMENT '有无纸质合同',
  `price_book_id` varchar(100) NOT NULL DEFAULT '' COMMENT '价目表',
  `shipments_amount_sum` varchar(30) NOT NULL DEFAULT '' COMMENT '已发货金额',
  `field_9r24B__c` varchar(50) NOT NULL DEFAULT '' COMMENT '合同是否有修改',
  `field_120t5__c` varchar(100) NOT NULL DEFAULT '' COMMENT '质保期起计方式',
  `field_2b87n__c` varchar(50) NOT NULL DEFAULT '' COMMENT '运输费、保价',
  `field_WKWwP__c` varchar(50) NOT NULL DEFAULT '' COMMENT '电子邮箱',
  `field_zJo57__c` varchar(100) NOT NULL DEFAULT '' COMMENT '签约周期',
  `field_yy3gf__c` varchar(100) NOT NULL DEFAULT '' COMMENT 'OA审批节点',
  `field_c385T__c` varchar(30) NOT NULL DEFAULT '' COMMENT '票抵款金额',
  `field_u1st5__c` varchar(50) NOT NULL DEFAULT '' COMMENT '安装、调适、系统培训费',
  `ship_to_tel` varchar(30) NOT NULL DEFAULT '' COMMENT '电话',
  `work_flow_id` varchar(100) NOT NULL DEFAULT '' COMMENT '自由流程',
  `field_A1tTl__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '审批提交日期',
  `field_75caR__c` varchar(50) NOT NULL DEFAULT '' COMMENT 'oa流程id',
  `out_tenant_id` varchar(70) NOT NULL DEFAULT '' COMMENT '外部企业',
  `field_g8YyP__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '历史创建时间',
  `field_m9n8u__c` varchar(10) NOT NULL DEFAULT '' COMMENT '纯软件/软件+硬件',
  `field_f2xA2__c` varchar(30) NOT NULL DEFAULT '' COMMENT '是否推送oa',
  `marketing_name` varchar(50) NOT NULL DEFAULT '' COMMENT '市场活动名称',
  `dynamic_amount` varchar(50) NOT NULL DEFAULT '' COMMENT '额外调整',
  `commision_info` varchar(50) NOT NULL DEFAULT '' COMMENT '提成信息',
  `cooperation_type` varchar(50) NOT NULL DEFAULT '' COMMENT '合作类型',
  `field_D1P4N__c` varchar(30) NOT NULL DEFAULT '' COMMENT '验收款比例',
  `field_qkbYX__c` varchar(50) NOT NULL DEFAULT '' COMMENT '软件金额',
  `field_pN2n7__c` varchar(30) NOT NULL DEFAULT '' COMMENT '历史创建人',
  `ship_to_add` varchar(200) NOT NULL DEFAULT '' COMMENT '收货地址',
  `field_Wa2q9__c` varchar(50) NOT NULL DEFAULT '' COMMENT '收费方式',
  `field_g0OKr__c` varchar(50) NOT NULL DEFAULT '' COMMENT '原版合同盖章扫描件或者流程',
  `field_4F24n__c` varchar(30) NOT NULL DEFAULT '' COMMENT '质保期（年）',
  `field_xb96r__c` varchar(30) NOT NULL DEFAULT '' COMMENT '质保金比例',
  `field_7656t__c` varchar(30) NOT NULL DEFAULT '' COMMENT '保期（年）',
  `plan_payment_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '已计划回款金额',
  `sponsor` varchar(50) NOT NULL DEFAULT '' COMMENT '出资方',
  `field_5qm01__c` varchar(500) NOT NULL DEFAULT '' COMMENT '推送OA结果',
  `prepay_comment` varchar(30) NOT NULL DEFAULT '' COMMENT '预付款比例',
  `receipt_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '收货时间',
  `hand_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '交货时间',
  `bill_money_to_confirm` varchar(30) NOT NULL DEFAULT '' COMMENT '待确认的开票金额',
  `payment_money_to_confirm` varchar(30) NOT NULL DEFAULT '' COMMENT '待确认的回款金额',
  `field_x84sD__c` varchar(30) NOT NULL DEFAULT '' COMMENT '硬件金额',
  `field_pX7wp__c` varchar(30) NOT NULL DEFAULT '' COMMENT '景区是否收费',
  `promotion_id` varchar(200) NOT NULL DEFAULT '' COMMENT '促销活动',
  `remark` varchar(1000) NOT NULL DEFAULT '' COMMENT '备注',
  `field_yTzfR__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '安装、调适、培训服务、现场服务时间',
  `lock_user` varchar(30) NOT NULL DEFAULT '' COMMENT '加锁人',
  `field_x11af__c` varchar(30) NOT NULL DEFAULT '' COMMENT '业务类别',
  `field_zt92n__c` varchar(200) NOT NULL DEFAULT '' COMMENT '合同名称',
  `order_status` varchar(30) NOT NULL DEFAULT '' COMMENT '合同状态',
  `shipping_depot_id` varchar(50) NOT NULL DEFAULT '' COMMENT '订货仓库',
  `field_1DBOl__c` varchar(30) NOT NULL DEFAULT '' COMMENT '签约周期（天）',
  `receipt_type` varchar(30) NOT NULL DEFAULT '' COMMENT '收款类型',
  `field_GqBaM__c` varchar(30) NOT NULL DEFAULT '' COMMENT '到货款比例',
  `object_describe_api_name` varchar(30) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `out_owner` varchar(200) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `field_IaOmE__c` varchar(2000) NOT NULL DEFAULT '' COMMENT '其他模板条款修改内容修动后',
  `field_wFC12__c` varchar(30) NOT NULL DEFAULT '' COMMENT '合作版本',
  `field_342ly__c` varchar(30) NOT NULL DEFAULT '' COMMENT '项目周期（年）',
  `field_R40au__c` varchar(30) NOT NULL DEFAULT '' COMMENT '工作日天数',
  `field_192ml__c` varchar(30) NOT NULL DEFAULT '' COMMENT '是否电子签约',
  `field_oAzE9__c` varchar(100) NOT NULL DEFAULT '' COMMENT '类型明细',
  `shipments_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '发货时间',
  `kccOv__c` varchar(50) NOT NULL DEFAULT '' COMMENT '平台账号/ID/手机',
  `field_mrALl__c` varchar(10) NOT NULL DEFAULT '' COMMENT '是否共背',
  `field_rTV74__c` varchar(50) NOT NULL DEFAULT '' COMMENT '共背人员',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '新增时间',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '修改时间',
  `field_kccOv__c` varchar(50) NOT NULL DEFAULT '' COMMENT '平台ID',
  `field_n4omq__c` varchar(30) NOT NULL DEFAULT '' COMMENT '甲方名称crmId',
  `field_ir2P0__c` varchar(50) DEFAULT '' COMMENT '合同归属部门',
  `owner_id` varchar(20) NOT NULL DEFAULT '' COMMENT '负责人id',
  `field_rTV74__c__id` varchar(20) NOT NULL DEFAULT '' COMMENT '共背人id',
  `field_aK06g__c` varchar(30) NOT NULL DEFAULT '' COMMENT '项目合作归属',
  `field_Qc9ei__c` int(10) NOT NULL DEFAULT '0' COMMENT '折扣金额',
  `field_zU8sQ__c` varchar(30) NOT NULL DEFAULT '' COMMENT '折扣选项',
  `field_RiboM__c` varchar(30) DEFAULT NULL COMMENT '其他费用',
  `field_6gMu1__c` varchar(30) DEFAULT NULL COMMENT '是否需要交接验收',
  `field_f7R4o__c` varchar(100) NOT NULL DEFAULT '' COMMENT '共签团队',
  `field_HZtVl__c` varchar(80) NOT NULL DEFAULT '' COMMENT '战略生态组人员',
  `field_Mz9On__c` varchar(20) NOT NULL DEFAULT '' COMMENT '是否算业绩',
  `field_s2w67__c` timestamp NULL DEFAULT NULL COMMENT '第一次到货日期',
  `field_4q225__c` timestamp NULL DEFAULT NULL COMMENT '最后到货日期',
  `is_crm_done` varchar(100) NOT NULL DEFAULT '0' COMMENT 'crm是否完成归档0:未完成 1：已完成',
  `field_d11co__c` varchar(200) NOT NULL DEFAULT '' COMMENT '到货款约定付款条件',
  `field_A8Ky0__c` varchar(200) NOT NULL DEFAULT '' COMMENT '验收款约定付款条件',
  `field_JaF8w__c` varchar(200) NOT NULL DEFAULT '' COMMENT '质保金约定付款条件',
  `field_btzUf__c` varchar(200) NOT NULL DEFAULT '' COMMENT '预付款约定付款条件',
  `field_OS5XC__c` varchar(30) NOT NULL DEFAULT '' COMMENT '验收款',
  `field_U1W0I__c` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '预付款约定到账日期',
  `field_m5dOo__c` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '验收款约定到账日期',
  `field_q3bQ4__c` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '到货款约定到账日期',
  `field_nm02i__c` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '质保金约定到账日期',
  `field_her82__c` varchar(30) NOT NULL DEFAULT '' COMMENT '其他阶段款',
  `field_GLr9q__c` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '其他阶段约定到账日期',
  `field_4fjkx__c` varchar(200) NOT NULL DEFAULT '' COMMENT '其他阶段约定付款条件',
  `field_Pkfg4__c` varchar(30) NOT NULL DEFAULT '' COMMENT '未发货硬件数',
  `field_01wfr__c` varchar(30) NOT NULL DEFAULT '' COMMENT '预付款',
  `field_LD81A__c` varchar(30) NOT NULL DEFAULT '' COMMENT '质保金',
  `field_LivhZ__c` varchar(30) NOT NULL DEFAULT '' COMMENT '到货款',
  `field_kUZN2__c` varchar(500) NOT NULL DEFAULT '' COMMENT '质保金约定付款条件',
  `field_4c3mN__c` varchar(500) NOT NULL DEFAULT '' COMMENT '其他阶段款约定付款条件',
  `field_ryVXm__c` varchar(100) NOT NULL DEFAULT '' COMMENT '其他阶段款实际到账日期',
  `field_mhE25__c` varchar(30) NOT NULL DEFAULT '' COMMENT '总预付款回款金额',
  `field_Z0yd5__c` varchar(30) NOT NULL DEFAULT '' COMMENT '剩余预付款',
  `field_JUXnN__c` varchar(30) NOT NULL DEFAULT '' COMMENT '总验收款回款金额',
  `field_4TB2l__c` varchar(30) NOT NULL DEFAULT '' COMMENT '剩余验收款',
  `field_eh62J__c` varchar(30) NOT NULL DEFAULT '' COMMENT '总到货款回款金额',
  `field_pR41M__c` varchar(30) NOT NULL DEFAULT '' COMMENT '剩余到货款',
  `field_iu018__c` varchar(30) NOT NULL DEFAULT '' COMMENT '总质保金回款金额',
  `field_6hdbj__c` varchar(30) NOT NULL DEFAULT '' COMMENT '剩余质保金',
  `field_JfV7W__c` varchar(30) NOT NULL DEFAULT '' COMMENT '总其他阶段款回款金额',
  `field_g71iR__c` varchar(30) NOT NULL DEFAULT '' COMMENT '剩余其他阶段款',
  `field_fthCP__c` varchar(500) NOT NULL DEFAULT '' COMMENT '预付款约定付款条件',
  `field_Zh8v3__c` varchar(500) NOT NULL DEFAULT '' COMMENT '到货款约定付款条件',
  `field_fyk8q__c` varchar(500) NOT NULL DEFAULT '' COMMENT '验收款约定付款条件',
  `field_6GFbd__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '验收款实际到账日期',
  `field_xPwsz__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '预付款实际到账日期',
  `field_TSS1j__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '质保金实际到账日期',
  `receivable_amount` double DEFAULT '0' COMMENT '待回款金额（元）',
  `field_SwG1l__c` varchar(30) NOT NULL DEFAULT '' COMMENT '毛利率',
  `field_b4d1m__c` varchar(20) NOT NULL DEFAULT '' COMMENT '是否归档异常',
  `field_98Fop__c` varchar(10) NOT NULL DEFAULT '' COMMENT '是否归档',
  `field_zoqyn__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '归档时间',
  `field_17x1q__c` varchar(10) DEFAULT '' COMMENT '是否盖章',
  `field_wo165__c` int(11) DEFAULT NULL COMMENT '盖章份数',
  `field_1C4OX__c` varchar(10) DEFAULT '' COMMENT '是否重新盖章',
  `field_Q1cll__c` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '盖章日期',
  `field_4y04a__c` varchar(30) NOT NULL DEFAULT '' COMMENT '签约渠道:服务商1 渠道直签2 其他other',
  `field_LS4n3__c` varchar(30) NOT NULL DEFAULT '' COMMENT '旅行社类型',
  `field_O2vm2__c` varchar(50) NOT NULL DEFAULT '' COMMENT 'TAPD名称',
  `field_1UpWd__c` varchar(200) NOT NULL DEFAULT '' COMMENT 'TPAD链接',
  `field_Kodh7__c` double DEFAULT NULL COMMENT '实际研发总工时',
  `field_dkJ95__c` datetime DEFAULT NULL COMMENT '套餐开始时间',
  `field_xdS65__c` datetime DEFAULT NULL COMMENT '套餐结束时间',
  `field_1Oypp__c` varchar(100) DEFAULT NULL COMMENT '服务商人员',
  `field_8nDkS__c` varchar(30) DEFAULT NULL COMMENT '服务商名称',
  `is_participated_in_activit__c` varchar(30) DEFAULT NULL COMMENT '是否有参加活动',
  `field_3f8du__c` varchar(20) DEFAULT NULL COMMENT '是否定制化',
  `field_4L5hl__c` double DEFAULT NULL COMMENT '预估研发总工时',
  `field_zb0D4__c` varchar(64) DEFAULT NULL COMMENT '最新合同编号',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_platform_id` (`platform_id`),
  KEY `idx_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=24031 DEFAULT CHARSET=utf8mb4 COMMENT=' 合同订单表 ';

-- @table RDS_crm_erp:pft_crm_sales_order_change
-- @at 2026-11-27 16:16:04
-- @cmt crm_id CRM ID
-- @cmt id 主键ID
-- @cmt name 名称
CREATE TABLE `pft_crm_sales_order_change` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `crm_id` varchar(64) DEFAULT NULL,
  `name` varchar(32) DEFAULT NULL,
  `field_HRu7y__c` varchar(64) DEFAULT NULL COMMENT '关联原合同订单ID',
  `field_HRu7y__c__r` varchar(32) DEFAULT NULL COMMENT '关联原合同订单',
  `field_Ru5uW__c` varchar(32) DEFAULT NULL COMMENT '新合同编号',
  `field_EcqUD__c` varchar(100) DEFAULT NULL COMMENT '合同变更类型（多选）',
  `field_4a5bY__c` tinyint(1) DEFAULT NULL COMMENT '是否标准合同（true/false）',
  `is_archived__c` varchar(16) DEFAULT NULL COMMENT '是否归档状态',
  `life_status` varchar(16) DEFAULT NULL COMMENT '合同生命周期状态',
  `field_g3pOR__c` varchar(16) DEFAULT NULL COMMENT '盖章确认状态',
  `field_Bgay2__c` varchar(64) DEFAULT NULL COMMENT '客户名称',
  `field_Bgay2__c__r` varchar(64) DEFAULT NULL COMMENT '客户名称',
  `field_h7g37__c` varchar(64) DEFAULT NULL COMMENT '变更前甲方名称',
  `field_h7g37__c__r` varchar(64) DEFAULT NULL COMMENT '变更前甲方名称',
  `field_q56x1__c` varchar(64) DEFAULT NULL COMMENT '变更后甲方名称',
  `field_q56x1__c__r` varchar(64) DEFAULT NULL COMMENT '变更后甲方名称',
  `field_33LV1__c` decimal(10,0) DEFAULT NULL COMMENT '变更前销售金额',
  `field_qZMwZ__c` decimal(10,0) DEFAULT NULL COMMENT '变更前产品总金额',
  `field_P4dD2__c` decimal(10,0) DEFAULT NULL COMMENT '变更前预付款金额',
  `field_cqxc7__c` decimal(10,0) DEFAULT NULL COMMENT '变更前到货款金额',
  `field_2s2v2__c` decimal(10,0) DEFAULT NULL COMMENT '变更前验收款金额',
  `field_n9Q2N__c` decimal(10,0) DEFAULT NULL COMMENT '变更前其他阶段款金额',
  `field_1v795__c` decimal(10,0) DEFAULT NULL COMMENT '变更前质保金金额',
  `field_0T7z8__c` decimal(10,0) DEFAULT NULL COMMENT '变更前其他费用金额',
  `field_uly0n__c` decimal(10,0) DEFAULT NULL COMMENT '变更后销售金额',
  `field_qreo0__c` decimal(10,0) DEFAULT NULL COMMENT '销售金额差值计算结果',
  `field_154Yd__c` decimal(10,0) DEFAULT NULL COMMENT '变更后产品总金额',
  `field_E72zp__c` decimal(10,0) DEFAULT NULL COMMENT '变更后预付款金额',
  `field_49Lr5__c` decimal(10,0) DEFAULT NULL COMMENT '变更后到货款金额',
  `field_1TBf2__c` decimal(10,0) DEFAULT NULL COMMENT '变更后验收款金额',
  `field_58GbI__c` decimal(10,0) DEFAULT NULL COMMENT '变更后其他阶段款金额',
  `field_f3wU1__c` decimal(10,0) DEFAULT NULL COMMENT '变更后质保金金额',
  `field_JYo2u__c` decimal(10,0) DEFAULT NULL COMMENT '变更后其他费用金额',
  `created_by` varchar(64) DEFAULT NULL COMMENT '创建人',
  `last_modified_by` varchar(64) DEFAULT NULL COMMENT '最后修改人',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `last_modified_time` datetime DEFAULT NULL COMMENT '最后修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_crm_id_name` (`crm_id`,`name`),
  KEY `idx_field_HRu7y__c` (`field_HRu7y__c`)
) ENGINE=InnoDB AUTO_INCREMENT=1936 DEFAULT CHARSET=utf8 COMMENT='crm合同变更单';

-- @table RDS_crm_erp:pft_crm_sales_order_change_detail
-- @at 2026-11-27 16:16:10
-- @cmt crm_id CRM ID
-- @cmt id 主键ID
-- @cmt name 名称
CREATE TABLE `pft_crm_sales_order_change_detail` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `crm_id` varchar(64) DEFAULT NULL,
  `name` varchar(32) DEFAULT NULL,
  `field_66q9G__c` varchar(64) DEFAULT NULL COMMENT '合同变更单',
  `field_66q9G__c__r` varchar(64) DEFAULT NULL COMMENT '合同变更单',
  `field_d2Ney__c` varchar(64) DEFAULT NULL COMMENT '关联订单产品',
  `field_Kvk1r__c` varchar(64) DEFAULT NULL COMMENT '产品名称',
  `field_Kvk1r__c__r` varchar(128) DEFAULT NULL COMMENT '产品名称',
  `field_4bKr3__c` varchar(16) DEFAULT NULL COMMENT '产品类型',
  `field_S6GW5__c` varchar(64) DEFAULT NULL COMMENT '合同产品名称',
  `field_unq05__c` decimal(10,0) DEFAULT NULL COMMENT '变更前数量',
  `field_QAxsq__c` decimal(10,0) DEFAULT NULL COMMENT '变更后数量',
  `field_67d51__c` decimal(10,0) DEFAULT NULL COMMENT '变更前单价',
  `field_qa4c6__c` decimal(10,0) DEFAULT NULL COMMENT '变更后单价',
  `field_CCDT7__c` decimal(10,0) DEFAULT NULL COMMENT '对外建议售价',
  `field_I52gB__c` decimal(10,0) DEFAULT NULL COMMENT '变更前折扣',
  `field_4kRv2__c` decimal(10,0) DEFAULT NULL COMMENT '变更后折扣',
  `field_QAF2Z__c` decimal(10,0) DEFAULT NULL COMMENT '变更前小计',
  `field_32nZZ__c` decimal(10,0) DEFAULT NULL COMMENT '变更后小计',
  `field_akIed__c` decimal(10,0) DEFAULT NULL COMMENT '变更前整单折扣金额',
  `field_OwIvc__c` decimal(10,0) DEFAULT NULL COMMENT '变更后整单折扣金额',
  `field_1ntCt__c` decimal(10,0) DEFAULT NULL COMMENT '变更后整单折扣金额2',
  `business_scene__c` varchar(16) DEFAULT NULL COMMENT '变更后业务场景',
  `field_RY7OB__c` varchar(16) DEFAULT NULL COMMENT '单位',
  `field_Fe54S__c` decimal(10,0) DEFAULT NULL COMMENT '已发货数量',
  `field_E2IJ2__c` decimal(10,0) DEFAULT NULL COMMENT '未审批通过的发货数量',
  `field_K64t9__c` varchar(16) DEFAULT NULL COMMENT '是否需要交接验收',
  `created_by` varchar(64) DEFAULT NULL COMMENT '创建人',
  `last_modified_by` varchar(64) DEFAULT NULL COMMENT '最后修改人',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `last_modified_time` datetime DEFAULT NULL COMMENT '最后修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_crm_id_name` (`crm_id`,`name`),
  KEY `idx_field_66q9G_d2Ney__c` (`field_66q9G__c`,`field_d2Ney__c`)
) ENGINE=InnoDB AUTO_INCREMENT=17369 DEFAULT CHARSET=utf8 COMMENT='合同变更明细';

-- @table RDS_crm_erp:pft_crm_sales_order_product
-- @at 2026-11-27 11:48:15
CREATE TABLE `pft_crm_sales_order_product` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `NAME` varchar(50) NOT NULL DEFAULT '' COMMENT '订单产品编号',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `OFFSET` int(10) NOT NULL DEFAULT '0' COMMENT '序号',
  `product_image` varchar(200) NOT NULL DEFAULT '' COMMENT '产品图片',
  `discount` varchar(50) NOT NULL DEFAULT '' COMMENT '折扣',
  `promotion_id` varchar(100) NOT NULL DEFAULT '' COMMENT '促销活动',
  `product_price` varchar(30) NOT NULL DEFAULT '' COMMENT '价格',
  `delivery_amount` varchar(30) NOT NULL DEFAULT '' COMMENT '已发货金额小计',
  `owner_department` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人主属部门',
  `lock_rule` varchar(50) NOT NULL DEFAULT '' COMMENT '锁定规则',
  `lock_user` varchar(50) NOT NULL DEFAULT '' COMMENT '加锁人',
  `remark` varchar(500) NOT NULL DEFAULT '' COMMENT '备注',
  `object_describe_api_name` varchar(100) NOT NULL DEFAULT '' COMMENT 'object_describe_api_name',
  `out_owner` varchar(50) NOT NULL DEFAULT '' COMMENT '外部负责人',
  `order_product_amount` varchar(50) NOT NULL DEFAULT '' COMMENT '折扣金额',
  `OWNER` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人',
  `quantity` varchar(50) NOT NULL DEFAULT '' COMMENT '数量',
  `lock_status` varchar(20) NOT NULL DEFAULT '' COMMENT '锁定状态',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `last_modified_by__r` varchar(30) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `is_giveaway` varchar(30) NOT NULL DEFAULT '' COMMENT '是否赠品',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `out_tenant_id` varchar(100) NOT NULL DEFAULT '' COMMENT '外部企业',
  `created_by` varchar(50) NOT NULL DEFAULT '' COMMENT '创建人',
  `relevant_team` varchar(300) NOT NULL DEFAULT '' COMMENT '相关团队',
  `record_type` varchar(50) NOT NULL DEFAULT '' COMMENT '业务类型',
  `unit` varchar(50) NOT NULL DEFAULT '' COMMENT '单位',
  `data_own_department` varchar(50) NOT NULL DEFAULT '' COMMENT '归属部门',
  `subtotal` varchar(50) NOT NULL DEFAULT '' COMMENT '小计',
  `sales_price` varchar(50) NOT NULL DEFAULT '' COMMENT '销售单价',
  `dynamic_amount` varchar(50) NOT NULL DEFAULT '' COMMENT '额外调整',
  `order_id` varchar(50) NOT NULL DEFAULT '' COMMENT '合同订单',
  `product_id` varchar(50) NOT NULL DEFAULT '' COMMENT '产品id',
  `add_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '添加时间',
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '修改时间',
  `field_gMk7b__c` varchar(30) NOT NULL DEFAULT '' COMMENT '产品类型',
  `field_r3Hi0__c` varchar(50) NOT NULL DEFAULT '' COMMENT '整单折扣后金额',
  `field_RY7OB__c` varchar(100) NOT NULL DEFAULT '' COMMENT '单位-新',
  `field_12v0S__c` varchar(20) NOT NULL DEFAULT '' COMMENT '二手程度',
  `field_p9g8l__c` varchar(30) NOT NULL DEFAULT '' COMMENT '是否二手',
  `field_2mlqK__c` varchar(20) NOT NULL DEFAULT '' COMMENT '业务场景',
  `field_6CWlu_c` varchar(30) DEFAULT NULL COMMENT '是否定制化',
  `field_gpl1K__c` datetime DEFAULT NULL COMMENT '开始时间',
  `field_i555g__c` datetime DEFAULT NULL COMMENT '结束时间',
  `field_single_line_text__c` varchar(30) DEFAULT NULL COMMENT '单位(导入)',
  `field_YMzjR__c` double DEFAULT NULL COMMENT '建议售价',
  `field_kIhsg__c` varchar(100) DEFAULT NULL COMMENT '合同产品名称',
  `field_1zz86__c` varchar(30) DEFAULT NULL COMMENT '结算价',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=43407 DEFAULT CHARSET=utf8mb4 COMMENT='订单产品表';

-- @table RDS_crm_erp:pft_crm_time_sheet
-- @at 2026-11-27 16:16:16
-- @cmt crm_id CRM ID
-- @cmt id 主键ID
CREATE TABLE `pft_crm_time_sheet` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `crm_id` varchar(50) DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL COMMENT '工时记录编号',
  `field_14W02__c` varchar(50) DEFAULT NULL COMMENT '批量新建工时记录明细',
  `owner` varchar(50) DEFAULT NULL COMMENT '负责人',
  `owner_department` varchar(30) DEFAULT NULL COMMENT '负责人主属部门',
  `owner_department_id` varchar(50) DEFAULT NULL COMMENT '负责人主属部门id',
  `data_own_department` varchar(50) DEFAULT NULL COMMENT '归属部门',
  `out_owner` varchar(50) DEFAULT NULL COMMENT '外部负责人',
  `project_id` varchar(50) DEFAULT NULL COMMENT '所属项目名称',
  `start_date` date DEFAULT NULL COMMENT '工作开始日期',
  `end_date` date DEFAULT NULL COMMENT '工作结束日期',
  `field_w535B__c` int(11) DEFAULT NULL COMMENT '工作时长（天）',
  `field_663L3__c__r` varchar(30) DEFAULT NULL COMMENT '国家',
  `field_113uF__c__r` varchar(30) DEFAULT NULL COMMENT '省',
  `field_086e6__c__r` varchar(30) DEFAULT NULL COMMENT '市',
  `field_S7VbM__c__r` varchar(30) DEFAULT NULL COMMENT '区',
  `billing_type` varchar(30) DEFAULT NULL COMMENT '计费类型',
  `field_b6V80__c` date DEFAULT NULL COMMENT '填报日期',
  `field_O2T9T__c` varchar(30) DEFAULT NULL COMMENT '地区定位',
  `job_describe` text COMMENT '工作内容',
  `field_fFn66__c` varchar(100) DEFAULT NULL COMMENT '详细地址',
  `field_918rS__c` varchar(50) DEFAULT NULL COMMENT '工单编码',
  `field_v1lJr__c` varchar(100) DEFAULT NULL COMMENT '定位',
  `time_period` decimal(10,1) DEFAULT NULL COMMENT '工时数',
  `field_lt5Hy__c` varchar(30) DEFAULT NULL COMMENT '工时类型',
  `created_by` varchar(50) DEFAULT NULL COMMENT '创建人',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `last_modified_by` varchar(50) DEFAULT NULL COMMENT '最后修改人',
  `last_modified_time` datetime DEFAULT NULL COMMENT '最后修改时间',
  `life_status` varchar(30) DEFAULT NULL COMMENT '生命状态',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2694 DEFAULT CHARSET=utf8 COMMENT='工时记录';

-- @table RDS_crm_erp:pft_crm_user
-- @at 2026-11-27 11:48:58
CREATE TABLE `pft_crm_user` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '流程编号',
  `platform_id` varchar(30) NOT NULL DEFAULT '' COMMENT '纷享平台id',
  `custom_name` varchar(100) NOT NULL DEFAULT '' COMMENT '客户名称',
  `record_type` varchar(30) NOT NULL DEFAULT '' COMMENT '业务类型',
  `owner__r` varchar(30) NOT NULL DEFAULT '' COMMENT '负责人',
  `data_own_department` varchar(30) NOT NULL DEFAULT '' COMMENT '归属部门',
  `province__r` varchar(10) NOT NULL DEFAULT '' COMMENT '省份名称',
  `city__r` varchar(20) NOT NULL DEFAULT '' COMMENT '市名称',
  `plate_id` varchar(20) NOT NULL DEFAULT '' COMMENT '平台id',
  `account_level` varchar(30) NOT NULL DEFAULT '' COMMENT '客户类型',
  `custom_value` varchar(30) NOT NULL DEFAULT '' COMMENT '客户价值',
  `field_QoQCJ__c` varchar(30) NOT NULL DEFAULT '' COMMENT '旅行社类型',
  `field_9hz29__c` varchar(30) NOT NULL DEFAULT '' COMMENT '景区类型',
  `field_5adjS__c` varchar(30) NOT NULL DEFAULT '' COMMENT '联系人',
  `field_spwgd__c` varchar(30) NOT NULL DEFAULT '' COMMENT '职务',
  `field_BiK6s__c` varchar(30) NOT NULL DEFAULT '' COMMENT '手机号码',
  `field_6x092__c` varchar(30) NOT NULL DEFAULT '' COMMENT '联系人微信',
  `field_lU72u__c` varchar(30) NOT NULL DEFAULT '' COMMENT '客户性格',
  `field_o90c8__c` varchar(30) NOT NULL DEFAULT '' COMMENT '合作类型',
  `field_9kQ2J__c` varchar(150) NOT NULL DEFAULT '' COMMENT '合作明细',
  `field_n4vg0__c` varchar(100) NOT NULL DEFAULT '' COMMENT '平台合作核心需求',
  `field_qez7v__c` decimal(38,2) DEFAULT '0.00' COMMENT '实收金额',
  `field_L44Bz__c` varchar(30) NOT NULL DEFAULT '' COMMENT '合作线上平台',
  `field_oV1Jc__c` varchar(30) NOT NULL DEFAULT '' COMMENT '合作线下系统',
  `field_5i38I__c` varchar(150) NOT NULL DEFAULT '' COMMENT '套餐内容',
  `field_vFWwf__c` varchar(30) NOT NULL DEFAULT '' COMMENT '接收区域',
  `field_Xc4V1__c` varchar(150) NOT NULL DEFAULT '' COMMENT '接收人员',
  `created_by__l` varchar(10) NOT NULL DEFAULT '' COMMENT '创建人',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `last_modified_by__r` varchar(100) NOT NULL DEFAULT '' COMMENT '最后修改人',
  `last_modified_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '最后修改时间',
  `life_status` varchar(20) NOT NULL DEFAULT '' COMMENT '生命状态',
  `accountobjcrmid` varchar(30) DEFAULT NULL COMMENT '客户crmid',
  `receivename` varchar(30) DEFAULT NULL COMMENT '接收人员姓名',
  `field_6K19R__c` varchar(30) NOT NULL DEFAULT '' COMMENT '年客流量(万)',
  `field_M1lft__c` varchar(30) NOT NULL DEFAULT '' COMMENT '年订单量(万)',
  `field_odxkk__c` varchar(30) NOT NULL DEFAULT '' COMMENT '合作景区产品数量',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=300 DEFAULT CHARSET=utf8mb4 COMMENT='用户交接表';

-- @table RDS_crm_erp:pft_stage_filter
-- @at 2026-11-27 11:49:18
CREATE TABLE `pft_stage_filter` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `contract_no` varchar(30) DEFAULT NULL COMMENT '合同号',
  `op1` varchar(30) DEFAULT NULL COMMENT '自定义1',
  `op2` varchar(30) DEFAULT NULL COMMENT '自定义2',
  `op3` varchar(30) DEFAULT NULL COMMENT '自定义3',
  `op4` varchar(30) DEFAULT NULL COMMENT '自定义4',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=22104 DEFAULT CHARSET=utf8mb4 COMMENT='crm分期过滤表';

-- @table RDS_crm_erp:pft_trade_journal_summary
-- @at 2026-11-27 16:16:33
-- @cmt id 主键ID
CREATE TABLE `pft_trade_journal_summary` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `trade_date` varchar(32) NOT NULL DEFAULT '' COMMENT '交易日期yyyy-MM-dd',
  `subject_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '账本科目编码',
  `trade_subject_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '交易对方账本科目编码',
  `trade_account_pft` int(11) NOT NULL DEFAULT '0' COMMENT '对方商户 1：pft，-2：非票付通',
  `template_item_code` mediumint(6) NOT NULL DEFAULT '0' COMMENT '模板费用项编码',
  `first_sale_channel` int(10) NOT NULL DEFAULT '0' COMMENT '第一销售渠道',
  `sale_channel` int(10) NOT NULL DEFAULT '0' COMMENT '销售渠道',
  `account_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '账户ID',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '会员ID',
  `account_group` int(10) NOT NULL DEFAULT '1' COMMENT '账号分组',
  `contract_subject` int(11) NOT NULL DEFAULT '1' COMMENT '商户主体 1：票付通，2：票易通',
  `income` bigint(20) NOT NULL DEFAULT '0' COMMENT '收入',
  `expense` bigint(20) NOT NULL DEFAULT '0' COMMENT '支出',
  `total` int(11) NOT NULL DEFAULT '0' COMMENT '条数',
  `test` tinyint(1) NOT NULL DEFAULT '0' COMMENT '测试',
  PRIMARY KEY (`id`),
  KEY `idx_tradeDate_subjectCode_contractSubject` (`trade_date`,`subject_code`,`contract_subject`),
  KEY `idx_tradeDate_fid` (`trade_date`,`fid`),
  KEY `idx_tradeDate_accountId` (`trade_date`,`account_id`),
  KEY `idx_trade_date_trade` (`trade_date`,`trade_subject_code`,`trade_account_pft`)
) ENGINE=InnoDB AUTO_INCREMENT=12496742 DEFAULT CHARSET=utf8 COMMENT='交易流水汇总表';

-- @table RDS_crm_erp:tmp_sales_order_change
-- @at 2026-11-27 16:16:38
-- @cmt create_time 创建时间
-- @cmt htbh 合同编号
-- @cmt order_amount 合作总额
-- @cmt owner_departmentname 负责人部门名称
-- @cmt owner_lv1_team 负责人一级团队
-- @cmt owner_lv2_team 负责人二级团队
-- @cmt owner_lv3_team 负责人三级团队
-- @cmt owner_name 车主姓名
-- @cmt platform_id 纷享平台id
-- @cmt user_is_new_2024 用户是否新2024
CREATE TABLE `tmp_sales_order_change` (
  `platform_id` varchar(100) DEFAULT NULL,
  `htbh` varchar(100) DEFAULT NULL,
  `order_amount` decimal(18,2) DEFAULT NULL,
  `owner_name` varchar(100) DEFAULT NULL,
  `owner_departmentname` varchar(100) DEFAULT NULL,
  `owner_lv1_team` varchar(100) DEFAULT NULL,
  `owner_lv2_team` varchar(100) DEFAULT NULL,
  `owner_lv3_team` varchar(100) DEFAULT NULL,
  `user_is_new_2024` varchar(10) DEFAULT NULL,
  `create_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- @table RDS_data_center:c_member_authorize
-- @at 2026-11-27 11:31:16
CREATE TABLE `c_member_authorize` (
  `authorize_id` int NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `member_id` int NOT NULL DEFAULT '0' COMMENT '用户ID',
  `application_key` varchar(64) COLLATE utf8mb4_general_ci NOT NULL DEFAULT '' COMMENT '应用',
  `payload` json DEFAULT NULL COMMENT '负载数据',
  `begin_time` datetime NOT NULL DEFAULT '1970-01-01 00:00:00' COMMENT '开始时间',
  `expire_time` datetime NOT NULL DEFAULT '1970-01-01 00:00:00' COMMENT '到期时间',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`authorize_id`),
  UNIQUE KEY `unq_member_id_application_key` (`member_id`,`application_key`)
) ENGINE=InnoDB AUTO_INCREMENT=4112 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='用户应用授权表';

-- @table RDS_it_project:dim_crm_home_area
-- @at 2026-11-27 16:17:02
-- @cmt amb_level1_dep 阿米巴一级部门
-- @cmt amb_level2_dep 阿米巴二级部门
-- @cmt amb_level3_dep 阿米巴三级部门
-- @cmt department 部门
-- @cmt home_area_desc 归属区域描述
-- @cmt home_area_group 归属区域组
-- @cmt lv1_team 一级团队
-- @cmt lv2_team 二级团队
-- @cmt lv3_team 三级团队
CREATE TABLE `dim_crm_home_area` (
  `home_area_group` varchar(255) DEFAULT NULL,
  `home_area_desc` varchar(255) NOT NULL,
  `department` varchar(255) DEFAULT NULL,
  `depid` varchar(100) DEFAULT NULL COMMENT 'erp对应部门id',
  `lv1_team` varchar(255) DEFAULT NULL,
  `lv2_team` varchar(255) DEFAULT NULL,
  `lv3_team` varchar(255) DEFAULT NULL,
  `amb_level1_dep` varchar(255) DEFAULT NULL,
  `amb_level2_dep` varchar(255) DEFAULT NULL,
  `amb_level3_dep` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`home_area_desc`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- @table RDS_it_project:dim_resource_center_district
-- @at 2026-11-27 16:17:07
-- @cmt authority_code 权限编码
-- @cmt district 区县
-- @cmt import_province 1--重要省
-- @cmt province 省
CREATE TABLE `dim_resource_center_district_2022` (
  `district` varchar(255) DEFAULT NULL,
  `province` varchar(255) DEFAULT NULL,
  `authority_code` varchar(255) DEFAULT NULL,
  `import_province` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table RDS_it_project:ods_amb_project_check_tmp_o_f
-- @at 2026-11-27 16:17:14
-- @cmt htbh 合同编号
-- @cmt htlx 合同类型
-- @cmt id 主键ID
-- @cmt jfmc 甲方名称
-- @cmt jqmc 景区名称
-- @cmt month 月份
-- @cmt remark 备注
-- @cmt sl 数量
-- @cmt tx 交易
-- @cmt xmmc 项目名称
CREATE TABLE `ods_amb_project_check_tmp_o_f` (
  `id` int(255) DEFAULT NULL,
  `month` varchar(255) DEFAULT NULL,
  `htbh` varchar(255) DEFAULT NULL,
  `jfmc` varchar(255) DEFAULT NULL,
  `xmmc` varchar(255) DEFAULT NULL,
  `jqmc` varchar(255) DEFAULT NULL,
  `sfsjyj` varchar(255) DEFAULT NULL,
  `equip_oa_require` varchar(255) DEFAULT NULL,
  `tx` varchar(255) DEFAULT NULL,
  `qy` varchar(255) DEFAULT NULL COMMENT '部门',
  `fzyw` varchar(255) DEFAULT NULL COMMENT '业务负责人',
  `contract_amount` varchar(255) DEFAULT NULL COMMENT '合同金额',
  `yssj` varchar(255) DEFAULT NULL COMMENT '验收时间',
  `device_cost` varchar(255) DEFAULT NULL COMMENT '设备成本',
  `sl` varchar(255) DEFAULT NULL,
  `remark` varchar(255) DEFAULT NULL,
  `gxygf` varchar(255) DEFAULT NULL,
  `dq` varchar(255) DEFAULT NULL,
  `zb` varchar(255) DEFAULT NULL,
  `htlx` varchar(255) DEFAULT NULL,
  `soft_amount` varchar(255) DEFAULT NULL COMMENT '软件收入',
  `equip_amount` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL COMMENT '设备收入',
  `service_amount` varchar(255) DEFAULT NULL COMMENT '技术服务收入',
  `install_amount` varchar(255) DEFAULT NULL COMMENT '安装调试收入',
  `zulin_amount` varchar(255) DEFAULT NULL COMMENT '租赁收入',
  `gbr_name` varchar(255) DEFAULT NULL,
  `xmss_amount` varchar(255) DEFAULT NULL COMMENT '项目实施成本',
  `income_type` varchar(30) DEFAULT NULL COMMENT '收入类型'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table RDS_oa_ecology:cus_fielddata
-- @at 2026-11-27 16:21:26
-- @cmt ID 主键ID
-- @cmt SCOPE 范围
-- @cmt SCOPEID 范围ID
-- @cmt field0 字段0
-- @cmt field1 字段1
-- @cmt field10 字段10
-- @cmt field11 字段11
-- @cmt field12 字段12
-- @cmt field13 字段13
-- @cmt field14 字段14
-- @cmt field15 字段15
-- @cmt field16 字段16
-- @cmt field17 字段17
-- @cmt field18 字段18
-- @cmt field19 字段19
-- @cmt field2 字段2
-- @cmt field20 字段20
-- @cmt field22 字段22
-- @cmt field23 字段23
-- @cmt field24 字段24
-- @cmt field25 字段25
-- @cmt field3 字段3
-- @cmt field4 字段4
-- @cmt field5 字段5
-- @cmt field6 字段6
-- @cmt field7 字段7
-- @cmt field8 字段8
-- @cmt field9 字段9
CREATE TABLE `cus_fielddata` (
  `SEQORDER` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `SCOPE` varchar(400) DEFAULT NULL,
  `SCOPEID` int(11) NOT NULL,
  `ID` int(11) NOT NULL,
  `field0` varchar(999) DEFAULT NULL,
  `field1` char(10) DEFAULT NULL,
  `field2` varchar(100) DEFAULT NULL,
  `field3` varchar(100) DEFAULT NULL,
  `field4` char(10) DEFAULT NULL,
  `field5` varchar(999) DEFAULT NULL,
  `field6` varchar(999) DEFAULT NULL,
  `field7` char(10) DEFAULT NULL,
  `field8` varchar(999) DEFAULT NULL,
  `field9` varchar(999) DEFAULT NULL,
  `field10` varchar(999) DEFAULT NULL,
  `field11` varchar(100) DEFAULT NULL,
  `field12` varchar(100) DEFAULT NULL,
  `field13` varchar(100) DEFAULT NULL,
  `field14` char(10) DEFAULT NULL,
  `field15` varchar(99) DEFAULT NULL,
  `field16` varchar(99) DEFAULT NULL,
  `field17` int(11) DEFAULT NULL,
  `field18` int(11) DEFAULT NULL,
  `field19` varchar(400) DEFAULT NULL,
  `field20` decimal(15,2) DEFAULT NULL,
  `field22` varchar(100) DEFAULT NULL,
  `field23` int(11) DEFAULT NULL,
  `field24` int(11) DEFAULT NULL,
  `field25` int(11) DEFAULT NULL,
  PRIMARY KEY (`SEQORDER`),
  KEY `IX_CUSFIELDDATA_SI` (`SCOPE`,`SCOPEID`),
  KEY `fielddata_idx_id` (`ID`)
) ENGINE=InnoDB AUTO_INCREMENT=3869 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_100
-- @at 2026-11-27 16:21:30
-- @cmt bz 备注
-- @cmt bz1 备注1
-- @cmt cwqrskje 财务确认收款金额
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt jqmc 景区名称
-- @cmt jsr 经手人
-- @cmt khmc 客户名称
-- @cmt lcbh 流程编号
-- @cmt lxdh 联系电话
-- @cmt lysqrq 来源申请日期
-- @cmt ptid 平台ID
-- @cmt ptid1 平台ID1
-- @cmt requestId 流程请求ID
-- @cmt sjdz 时间地址
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqrq 申请日期
-- @cmt wlbm 物流部门
-- @cmt wldh 物流单号
-- @cmt wldh1 物流单号1
-- @cmt wlmc 物流名称
CREATE TABLE `formtable_main_100` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `ssbmlyr` int(11) DEFAULT NULL,
  `wlbm` varchar(999) DEFAULT NULL,
  `wlmc` varchar(999) DEFAULT NULL,
  `glywry` int(11) DEFAULT NULL,
  `khwdmc` varchar(999) DEFAULT NULL,
  `gzbxxx` varchar(999) DEFAULT NULL,
  `lysqrq` char(10) DEFAULT NULL,
  `sfkxbhg` int(11) DEFAULT NULL,
  `sfqkjl` varchar(999) DEFAULT NULL,
  `cgwlbm` varchar(999) DEFAULT NULL,
  `cgwlmc` varchar(999) DEFAULT NULL,
  `lydhgwltm` varchar(999) DEFAULT NULL,
  `lydhgyjbb` varchar(999) DEFAULT NULL,
  `lydhgrjbb` varchar(999) DEFAULT NULL,
  `hgwlfjjl` varchar(999) DEFAULT NULL,
  `iqcjyymz` int(11) DEFAULT NULL,
  `fh` varchar(999) DEFAULT NULL,
  `xglc` text,
  `xgfj` text,
  `bz` text,
  `sfsjpjgh` text,
  `sfhtxg` int(11) DEFAULT NULL,
  `htbh` text,
  `wldh` varchar(999) DEFAULT NULL,
  `pjxx` varchar(999) DEFAULT NULL,
  `wlxxhpjxx` text,
  `wtsfyjj` int(11) DEFAULT NULL,
  `jyqksm` text,
  `khmc` varchar(999) DEFAULT NULL,
  `ptid` varchar(999) DEFAULT NULL,
  `pjsfgh` int(11) DEFAULT NULL,
  `fhmxfj` text,
  `pjycsm` varchar(999) DEFAULT NULL,
  `sfzbqn` int(11) DEFAULT NULL,
  `sjr` varchar(999) DEFAULT NULL,
  `sjdz` varchar(999) DEFAULT NULL,
  `sfsk` int(11) DEFAULT NULL,
  `skje` decimal(38,2) DEFAULT NULL,
  `rjnr` text,
  `sfghmfgh` int(11) DEFAULT NULL,
  `sfsjpjgh1` int(11) DEFAULT NULL,
  `ptid1` varchar(999) DEFAULT NULL,
  `erpcrkdh` text,
  `jqmc` text,
  `jylx` int(11) DEFAULT NULL,
  `ghsbslhj` text,
  `xssbslhj` text,
  `dssbslhj` text,
  `fkpzfjsc` text,
  `zrsbslhj` text,
  `jyzgh` text,
  `jyzxs` text,
  `jyzds` text,
  `jyzr` text,
  `slsfyz` int(11) DEFAULT NULL,
  `sjdhsl` text,
  `ycwlztsm` text,
  `erpdh` text,
  `gzsbbh` text,
  `gzsbfhsj` char(10) DEFAULT NULL,
  `lxdh` text,
  `zrerpcrkdh` text,
  `ycbm` int(11) DEFAULT NULL,
  `jsr` int(11) DEFAULT NULL,
  `gllc` text,
  `sfxyyjzjr` int(11) DEFAULT NULL,
  `zpfxr` int(11) DEFAULT NULL,
  `gzyyfx` text,
  `gjfa` text,
  `fjscjybgd` text,
  `wldh1` text,
  `rjbbh` text,
  `sqshwlyy` text,
  `cwqrskje` decimal(38,2) DEFAULT NULL,
  `bz1` text,
  `lc` text,
  `sfys` int(11) DEFAULT NULL,
  `gllxsqdtz` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3251 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_100_dt1
-- @at 2026-11-27 16:21:34
-- @cmt cpxh 产品型号
-- @cmt cwqrskje 财务确认收款金额
-- @cmt dj 单价
-- @cmt dssj 天时间
-- @cmt ghsj 工号时间
-- @cmt id 主键ID
-- @cmt je 金额
-- @cmt jsr 经手人
-- @cmt mainid 主表记录ID
-- @cmt wlbm 物流部门
-- @cmt wldh 物流单号
-- @cmt wlfs 物流方式
-- @cmt wlmc 物流名称
-- @cmt wlsl 物流数量
-- @cmt wlzt 物流状态
-- @cmt zjsj 增加时间
CREATE TABLE `formtable_main_100_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `wlbm` varchar(999) DEFAULT NULL,
  `wlmc` varchar(999) DEFAULT NULL,
  `hgwlfhsj` char(10) DEFAULT NULL,
  `wlfs` varchar(999) DEFAULT NULL,
  `wldh` varchar(999) DEFAULT NULL,
  `fjptdtsqkbz` varchar(999) DEFAULT NULL,
  `wlsl` int(11) DEFAULT NULL,
  `wlmc1` text,
  `lllb` int(11) DEFAULT NULL,
  `cpxh` varchar(999) DEFAULT NULL,
  `ghsj` char(10) DEFAULT NULL,
  `wlzt` int(11) DEFAULT NULL,
  `gzmx` varchar(999) DEFAULT NULL,
  `ghxs` int(11) DEFAULT NULL,
  `kddh` varchar(999) DEFAULT NULL,
  `xssj` char(10) DEFAULT NULL,
  `sfzysljqxssy` int(11) DEFAULT NULL,
  `sjsyjq` varchar(999) DEFAULT NULL,
  `glhtlc` text,
  `sfsjsk` int(11) DEFAULT NULL,
  `sqrtxfkrmc` varchar(999) DEFAULT NULL,
  `sqrtxfkje` varchar(999) DEFAULT NULL,
  `cwqrskje` varchar(999) DEFAULT NULL,
  `dssj` char(10) DEFAULT NULL,
  `cgtxsbje` varchar(999) DEFAULT NULL,
  `sqrtxfksj` char(10) DEFAULT NULL,
  `zjsj` char(10) DEFAULT NULL,
  `jsr` int(11) DEFAULT NULL,
  `jsrtxjssj` char(10) DEFAULT NULL,
  `jssbmcsfyz` int(11) DEFAULT NULL,
  `sjjssbmc` varchar(999) DEFAULT NULL,
  `jssbslsfyz` int(11) DEFAULT NULL,
  `sjjssbsl` varchar(999) DEFAULT NULL,
  `sbzh` varchar(999) DEFAULT NULL,
  `zh` int(11) DEFAULT NULL,
  `dj` decimal(38,2) DEFAULT NULL,
  `je` decimal(38,2) DEFAULT NULL,
  `sjyjcbje` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5661 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_111
-- @at 2026-11-27 16:17:43
-- @cmt bz 备注
-- @cmt cplx 产品类型
-- @cmt fph 发票号
-- @cmt fplx 发票类型
-- @cmt htbh 合同编号
-- @cmt htzje 合同总金额
-- @cmt id 主键ID
-- @cmt kddz 快递地址
-- @cmt kdrq 快递日期
-- @cmt kpje 开票金额
-- @cmt kprq 开票日期
-- @cmt lcbh 流程编号
-- @cmt lxdh 联系电话
-- @cmt requestId 流程请求ID
-- @cmt sl 数量
-- @cmt sqr 申请人
-- @cmt sqrbm 申请人部门
-- @cmt sqrq 申请日期
-- @cmt ykpje 已开票金额
CREATE TABLE `formtable_main_111` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqrbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `cplx` int(11) DEFAULT NULL,
  `sfyhtyqjc` int(11) DEFAULT NULL,
  `fplx` int(11) DEFAULT NULL,
  `gsmc` varchar(999) DEFAULT NULL,
  `sh` varchar(999) DEFAULT NULL,
  `kpdzjdh` text,
  `khhjzh` text,
  `sl` decimal(38,2) DEFAULT NULL,
  `kpje` decimal(38,2) DEFAULT NULL,
  `kxsfsd` int(11) DEFAULT NULL,
  `kprq` char(10) DEFAULT NULL,
  `kpsy` text,
  `bz` text,
  `htbh` text,
  `sjr` varchar(999) DEFAULT NULL,
  `lxdh` varchar(999) DEFAULT NULL,
  `xghtsplc` int(11) DEFAULT NULL,
  `fph` varchar(999) DEFAULT NULL,
  `htzje` decimal(38,2) DEFAULT NULL,
  `ykpje` decimal(38,2) DEFAULT NULL,
  `kddh` varchar(999) DEFAULT NULL,
  `jjrswclr` varchar(999) DEFAULT NULL,
  `kpnr` varchar(999) DEFAULT NULL,
  `yskxjt` text,
  `kdrq` varchar(100) DEFAULT NULL,
  `kddz` text,
  `yjsksj` varchar(100) DEFAULT NULL,
  `fpqshzd` text,
  `fpqshzdmb` text,
  `wkpje` decimal(38,2) DEFAULT NULL,
  `kpxx` int(11) DEFAULT NULL,
  `sfysqsblc` int(11) DEFAULT NULL,
  `sblcgl` text,
  `glhtsplc` text,
  `sfmt` int(11) DEFAULT NULL,
  `fkjd` int(11) DEFAULT NULL,
  `sfwlbhtkpsq` int(11) DEFAULT NULL,
  `khid` varchar(999) DEFAULT NULL,
  `yhgz` int(11) DEFAULT NULL,
  `fpqs` int(11) DEFAULT NULL,
  `bjpt` decimal(38,2) DEFAULT NULL,
  `bjyj` decimal(38,2) DEFAULT NULL,
  `bjrj` decimal(38,2) DEFAULT NULL,
  `bjazdsf` decimal(38,2) DEFAULT NULL,
  `bjwbf` decimal(38,2) DEFAULT NULL,
  `bjqsl` decimal(38,2) DEFAULT NULL,
  `qrpt` decimal(38,2) DEFAULT NULL,
  `qryj` decimal(38,2) DEFAULT NULL,
  `qrrj` decimal(38,2) DEFAULT NULL,
  `qrazdsf` decimal(38,2) DEFAULT NULL,
  `qrwbf` decimal(38,2) DEFAULT NULL,
  `qrqsl` decimal(38,2) DEFAULT NULL,
  `yhpt` decimal(38,2) DEFAULT NULL,
  `yhyj` decimal(38,2) DEFAULT NULL,
  `yhrj` decimal(38,2) DEFAULT NULL,
  `yhazdsf` decimal(38,2) DEFAULT NULL,
  `yhwbf` decimal(38,2) DEFAULT NULL,
  `yhqsl` decimal(38,2) DEFAULT NULL,
  `slpt` decimal(38,2) DEFAULT NULL,
  `slyj` decimal(38,2) DEFAULT NULL,
  `slrj` decimal(38,2) DEFAULT NULL,
  `slazdsf` decimal(38,2) DEFAULT NULL,
  `slwbf` decimal(38,2) DEFAULT NULL,
  `hjje` decimal(38,2) DEFAULT NULL,
  `slqsl` varchar(999) DEFAULT NULL,
  `bjhjje` decimal(38,2) DEFAULT NULL,
  `yhhjje` decimal(38,2) DEFAULT NULL,
  `tbdzpt` decimal(38,2) DEFAULT NULL,
  `tbdzyj` decimal(38,2) DEFAULT NULL,
  `tbdzrj` decimal(38,2) DEFAULT NULL,
  `tbdzazdsf` decimal(38,2) DEFAULT NULL,
  `tbdzwbf` decimal(38,2) DEFAULT NULL,
  `tbdzqsl` decimal(38,2) DEFAULT NULL,
  `ywht` int(11) DEFAULT NULL,
  `zkl` int(11) DEFAULT NULL,
  `tbzkl` int(11) DEFAULT NULL,
  `bjzjeyhq` int(11) DEFAULT NULL,
  `bjzjeyhh` int(11) DEFAULT NULL,
  `khidxz` int(11) DEFAULT NULL,
  `jqmc` varchar(100) DEFAULT NULL,
  `sjdzyxdz` varchar(100) DEFAULT NULL,
  `fqekp` int(11) DEFAULT NULL,
  `sywkpje` decimal(38,2) DEFAULT NULL,
  `kptj` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4195 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_111_dt1
-- @at 2026-11-27 16:17:48
-- @cmt dhkje 待回款金额
-- @cmt fph 发票号
-- @cmt id 主键ID
-- @cmt kprq 开票日期
-- @cmt mainid 主表记录ID
-- @cmt yfkje 预付款金额
-- @cmt yj 业绩
-- @cmt yskje 已收款金额
CREATE TABLE `formtable_main_111_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `djcsq` int(11) DEFAULT NULL,
  `kprq` char(10) DEFAULT NULL,
  `bcsqje` decimal(38,2) DEFAULT NULL,
  `yfkje` decimal(38,2) DEFAULT NULL,
  `dhkje` decimal(38,2) DEFAULT NULL,
  `yskje` decimal(38,2) DEFAULT NULL,
  `zbje` decimal(38,2) DEFAULT NULL,
  `wbf1` decimal(38,2) DEFAULT NULL,
  `pt` decimal(38,2) DEFAULT NULL,
  `yj` decimal(38,2) DEFAULT NULL,
  `rj` decimal(38,2) DEFAULT NULL,
  `azdsf` decimal(38,2) DEFAULT NULL,
  `wbf2` decimal(38,2) DEFAULT NULL,
  `qsl` decimal(38,2) DEFAULT NULL,
  `fph` decimal(38,2) DEFAULT NULL,
  `kpsy` varchar(999) DEFAULT NULL,
  `sqkpje` decimal(38,2) DEFAULT NULL,
  `kpje` decimal(38,2) DEFAULT NULL,
  `sywkpje` decimal(38,2) DEFAULT NULL,
  `fphm` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `formtable_main_111_dt1_mId` (`mainid`)
) ENGINE=InnoDB AUTO_INCREMENT=539 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_115
-- @at 2026-11-27 16:17:53
-- @cmt bz 备注
-- @cmt gw 岗位
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt jsrq 结束日期
-- @cmt ksrq 开始日期
-- @cmt lcbh 流程编号
-- @cmt requestId 流程请求ID
-- @cmt sjbm 时间部门
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqrq 申请日期
-- @cmt zt 状态
CREATE TABLE `formtable_main_115` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `thr` text,
  `bz` varchar(999) DEFAULT NULL,
  `qfj` text,
  `cclx` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `htbh` text,
  `jpxxcpxxjt` text,
  `sfczfj` int(11) DEFAULT NULL,
  `ksrq` char(10) DEFAULT NULL,
  `kssj` char(5) DEFAULT NULL,
  `jsrq` char(10) DEFAULT NULL,
  `jssj` char(5) DEFAULT NULL,
  `ccsct` decimal(38,2) DEFAULT NULL,
  `ccsy` varchar(999) DEFAULT NULL,
  `ccfyy` decimal(15,2) DEFAULT NULL,
  `cfd` int(11) DEFAULT NULL,
  `mdd` int(11) DEFAULT NULL,
  `jpzk` text,
  `jpjydcpjbjsm` varchar(999) DEFAULT NULL,
  `sjbm` int(11) DEFAULT NULL,
  `sfxgb` int(11) DEFAULT NULL,
  `glgdslspd` int(11) DEFAULT NULL,
  `ccdfyyq` int(11) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `zt` varchar(100) DEFAULT NULL,
  `jtgjdx` text,
  `sfys` int(11) DEFAULT NULL,
  `dcgthcsfcg6xs` int(11) DEFAULT NULL,
  `xzfjyy` int(11) DEFAULT NULL,
  `bmsfyz` int(11) DEFAULT NULL,
  `sqrbmtj` int(11) DEFAULT NULL,
  `tcxz` varchar(100) DEFAULT NULL,
  `sfscdd` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否上传滴滴商旅',
  `zxd` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=15748 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_115_dt1
-- @at 2026-11-27 16:21:39
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt jsrq 结束日期
-- @cmt khmc 客户名称
-- @cmt ksrq 开始日期
-- @cmt mainid 主表记录ID
-- @cmt sjmc 时间名称
CREATE TABLE `formtable_main_115_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `cfd` int(11) DEFAULT NULL,
  `mdd` int(11) DEFAULT NULL,
  `ccsy` varchar(999) DEFAULT NULL,
  `cclx` int(11) DEFAULT NULL,
  `khmc` text,
  `sjmc` text,
  `htbh` text,
  `gwtj` int(11) DEFAULT NULL,
  `sjmctj` varchar(999) DEFAULT NULL,
  `sjbttj` int(11) DEFAULT NULL,
  `sfys` int(11) DEFAULT NULL,
  `frcclx` int(11) DEFAULT NULL,
  `tcxz` varchar(100) DEFAULT NULL,
  `htkhbttj` int(11) DEFAULT NULL,
  `ksrq` char(10) DEFAULT NULL,
  `jsrq` char(10) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `formtable_main_115_dt1_mId` (`mainid`)
) ENGINE=InnoDB AUTO_INCREMENT=15076 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_134
-- @at 2026-11-27 16:21:43
-- @cmt bylx 人类型
-- @cmt csrq 出生日期
-- @cmt csyj 城市业绩
-- @cmt fjsc 附件上传
-- @cmt gj 国家
-- @cmt gj2 国家2
-- @cmt gw 岗位
-- @cmt id 主键ID
-- @cmt jsr 经手人
-- @cmt lcbh 流程编号
-- @cmt requestId 流程请求ID
-- @cmt sfjsoffer 是否接受 offer
-- @cmt sfktcrmzh 是否开通 CRM 账号
-- @cmt sqr 申请人
-- @cmt wjsofferyy 未接受 offer 原因
-- @cmt xb 性别
-- @cmt zjsj 增加时间
CREATE TABLE `formtable_main_134` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `xm` varchar(999) DEFAULT NULL,
  `xb` int(11) DEFAULT NULL,
  `csrq` char(10) DEFAULT NULL,
  `ypbm` int(11) DEFAULT NULL,
  `ypzw` varchar(999) DEFAULT NULL,
  `yprq` char(10) DEFAULT NULL,
  `csyj` text,
  `cspf` decimal(38,1) DEFAULT NULL,
  `csjg` int(11) DEFAULT NULL,
  `yrbmcsyj` text,
  `yrbmcspf` decimal(38,1) DEFAULT NULL,
  `yrbmcsjg` int(11) DEFAULT NULL,
  `rlzyzjyj` text,
  `zjlyj` text,
  `jysqsygz` decimal(38,1) DEFAULT NULL,
  `jysqzzgz` decimal(38,1) DEFAULT NULL,
  `gj` int(11) DEFAULT NULL,
  `jyksgzr` char(10) DEFAULT NULL,
  `yrbmzsr` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqsygz` decimal(38,1) DEFAULT NULL,
  `sqzzgz` decimal(38,1) DEFAULT NULL,
  `gj2` int(11) DEFAULT NULL,
  `yglx` int(11) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `bgdd` int(11) DEFAULT NULL,
  `ygzt` int(11) DEFAULT NULL,
  `zjsj` int(11) DEFAULT NULL,
  `sfjsoffer` int(11) DEFAULT NULL,
  `wjsofferyy` varchar(999) DEFAULT NULL,
  `jsr` int(11) DEFAULT NULL,
  `bylx` int(11) DEFAULT NULL,
  `rlbmtj` int(11) DEFAULT NULL,
  `sfktcrmzh` int(11) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `gwzj` varchar(100) DEFAULT NULL,
  `jygj` varchar(100) DEFAULT NULL,
  `jlxx` varchar(999) DEFAULT NULL,
  `fjsc` text,
  `cbgfzrpj` text,
  `sflr` int(11) DEFAULT NULL,
  `bdxx` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=912 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_136
-- @at 2026-11-27 16:18:06
-- @cmt departmentid 部门ID
-- @cmt id 主键ID
-- @cmt infoman 信息维护人
-- @cmt ischangesalary 是否调薪
-- @cmt lcbh 流程编号
-- @cmt newjob 新岗位
-- @cmt oldjob 原岗位
-- @cmt pmanager 项目经理
-- @cmt redeploydate 调岗日期
-- @cmt redeployreason 调岗原因
-- @cmt requestid 流程请求ID
-- @cmt resource_n 资源数
-- @cmt rzrq 入职日期
-- @cmt scfj 上传附件
-- @cmt sqrq 申请日期
CREATE TABLE `formtable_main_136` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestid` int(11) DEFAULT NULL,
  `redeploydate` char(10) DEFAULT NULL,
  `redeployreason` text,
  `oldjob` int(11) DEFAULT NULL,
  `departmentid` bigint(20) DEFAULT NULL,
  `newjob` int(11) DEFAULT NULL,
  `pmanager` int(11) DEFAULT NULL,
  `ischangesalary` int(11) DEFAULT NULL,
  `infoman` bigint(20) DEFAULT NULL,
  `resource_n` int(11) DEFAULT NULL,
  `ybm` int(11) DEFAULT NULL,
  `ygj` varchar(999) DEFAULT NULL,
  `xgj` varchar(999) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `scfj` text,
  `rzrq` char(10) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `xgwgznr` text,
  `hxjxzbkm` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=131 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_140
-- @at 2026-11-27 16:21:47
-- @cmt bylx 人类型
-- @cmt fphbm 发票号部门
-- @cmt fphsj 发票号时间
-- @cmt fpjsrq 发票结束日期
-- @cmt fpksrq 发票开始日期
-- @cmt fpyy 发票原因
-- @cmt gj 国家
-- @cmt gw 岗位
-- @cmt id 主键ID
-- @cmt lcbh 流程编号
-- @cmt requestId 流程请求ID
-- @cmt sfjsoffer 是否接受 offer
-- @cmt sqbm 申请部门
-- @cmt zjsj 增加时间
CREATE TABLE `formtable_main_140` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `bfpr` int(11) DEFAULT NULL,
  `fphsj` int(11) DEFAULT NULL,
  `fphbm` int(11) DEFAULT NULL,
  `fpxgw` int(11) DEFAULT NULL,
  `fpksrq` char(10) DEFAULT NULL,
  `fpjsrq` char(10) DEFAULT NULL,
  `fpyy` text,
  `lcbh` varchar(999) DEFAULT NULL,
  `rzfpyj` text,
  `rzfppf` decimal(38,1) DEFAULT NULL,
  `rzfpjg` int(11) DEFAULT NULL,
  `yrbmfpyj` text,
  `yrbmfppf` decimal(38,1) DEFAULT NULL,
  `yrbmfpjg` int(11) DEFAULT NULL,
  `jysqsygz` decimal(38,1) DEFAULT NULL,
  `jysqzzgz` decimal(38,1) DEFAULT NULL,
  `jygj` int(11) DEFAULT NULL,
  `jyksgzr` char(10) DEFAULT NULL,
  `sqsygz` decimal(38,1) DEFAULT NULL,
  `sqzzgz` decimal(38,1) DEFAULT NULL,
  `gj` int(11) DEFAULT NULL,
  `sfjsoffer` int(11) DEFAULT NULL,
  `wjsofferdyy` varchar(999) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `bgdd` int(11) DEFAULT NULL,
  `ygzt` int(11) DEFAULT NULL,
  `zjsj` int(11) DEFAULT NULL,
  `bylx` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_148
-- @at 2026-11-27 16:21:51
-- @cmt bm 部门
-- @cmt csrq 出生日期
-- @cmt dzyj 地址业绩
-- @cmt gh 工号
-- @cmt gj 国家
-- @cmt gw 岗位
-- @cmt htlx 合同类型
-- @cmt hyzt 行业状态
-- @cmt id 主键ID
-- @cmt lcbh 流程编号
-- @cmt requestId 流程请求ID
-- @cmt rzrq 入职日期
-- @cmt xb 性别
-- @cmt zjsj 增加时间
CREATE TABLE `formtable_main_148` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `xm` int(11) DEFAULT NULL,
  `bm` int(11) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `bgdd` int(11) DEFAULT NULL,
  `rzrq` char(10) DEFAULT NULL,
  `xb` int(11) DEFAULT NULL,
  `zjsj` int(11) DEFAULT NULL,
  `zply` int(11) DEFAULT NULL,
  `zhlx` int(11) DEFAULT NULL,
  `dzyj` varchar(999) DEFAULT NULL,
  `csrq` char(10) DEFAULT NULL,
  `jg` varchar(999) DEFAULT NULL,
  `hjszd` varchar(999) DEFAULT NULL,
  `sfzhm` varchar(18) DEFAULT NULL,
  `sfzyxq` char(10) DEFAULT NULL,
  `sfzdz` varchar(999) DEFAULT NULL,
  `xjzd` varchar(999) DEFAULT NULL,
  `hjlx` varchar(999) DEFAULT NULL,
  `zgxl` int(11) DEFAULT NULL,
  `mz` varchar(999) DEFAULT NULL,
  `hyzt` int(11) DEFAULT NULL,
  `grtx` text,
  `sccjgzrq` char(10) DEFAULT NULL,
  `zzmm` varchar(999) DEFAULT NULL,
  `xw` varchar(999) DEFAULT NULL,
  `gzkkhh` varchar(400) DEFAULT NULL,
  `gzkh` varchar(999) DEFAULT NULL,
  `jjlxrxm` varchar(999) DEFAULT NULL,
  `lxrdh` varchar(999) DEFAULT NULL,
  `lxrgx` varchar(999) DEFAULT NULL,
  `sfzrxm` text,
  `sfzghm` text,
  `byzs` text,
  `xwzs` text,
  `qgslzzm` text,
  `gzk` text,
  `syq` varchar(999) DEFAULT NULL,
  `syqjsrq` char(10) DEFAULT NULL,
  `ygxz` int(11) DEFAULT NULL,
  `htgs` varchar(999) DEFAULT NULL,
  `htlx` varchar(999) DEFAULT NULL,
  `schtqsr` char(10) DEFAULT NULL,
  `schtdqr` char(10) DEFAULT NULL,
  `xhtksrq` char(10) DEFAULT NULL,
  `xhtjsrq` char(10) DEFAULT NULL,
  `htqx` varchar(999) DEFAULT NULL,
  `xqcs` int(11) DEFAULT NULL,
  `ygzt` int(11) DEFAULT NULL,
  `gh` varchar(999) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `gj` varchar(999) DEFAULT NULL,
  `yddh` varchar(999) DEFAULT NULL,
  `ldhtzt` int(11) DEFAULT NULL,
  `gjxx` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=829 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_149
-- @at 2026-11-27 16:21:56
-- @cmt id 主键ID
-- @cmt requestId 流程请求ID
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqrq 申请日期
-- @cmt yjje 业绩金额
CREATE TABLE `formtable_main_149` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `zdrq` char(10) DEFAULT NULL,
  `zddw` varchar(999) DEFAULT NULL,
  `zdrs` int(11) DEFAULT NULL,
  `yjje` decimal(15,2) DEFAULT NULL,
  `zdsy` text,
  `xgry` text,
  `xgkh` text,
  `xgxm` int(11) DEFAULT NULL,
  `ydzesfcx` int(11) DEFAULT NULL,
  `wscjrs` int(11) DEFAULT NULL,
  `zdlx` text,
  `sqrbmtj` int(11) DEFAULT NULL,
  `bmsfyz` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5192 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_170
-- @at 2026-11-27 16:18:10
-- @cmt bm 部门
-- @cmt fj 附件
-- @cmt id 主键ID
-- @cmt lcbm 流程编码
-- @cmt requestId 流程请求ID
-- @cmt sqr 申请人
-- @cmt sqrq 申请日期
-- @cmt sqsj 申请时间
CREATE TABLE `formtable_main_170` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbm` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `bm` int(11) DEFAULT NULL,
  `gzfj` text,
  `clr` int(11) DEFAULT NULL,
  `gzlx` int(11) DEFAULT NULL,
  `fj` text,
  `yij` varchar(999) DEFAULT NULL,
  `pf` decimal(38,1) DEFAULT NULL,
  `gzsj` text,
  `clnr` text,
  `xysx` decimal(38,1) DEFAULT NULL,
  `wcsx` decimal(38,1) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `sqsj` char(5) DEFAULT NULL,
  `xyrq` char(10) DEFAULT NULL,
  `xysj` char(5) DEFAULT NULL,
  `wcrq` char(10) DEFAULT NULL,
  `wcsj` char(5) DEFAULT NULL,
  `xyts` decimal(38,4) DEFAULT NULL,
  `wcts` decimal(38,4) DEFAULT NULL,
  `gzqingk` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=533 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_176
-- @at 2026-11-27 16:18:15
-- @cmt cwqrskje 财务确认收款金额
-- @cmt dhkje 待回款金额
-- @cmt dsfcz 第三方厂商
-- @cmt fjsc 附件上传
-- @cmt fjsc1 附件上传1
-- @cmt fpmc 发票名称
-- @cmt htbh 合同编号
-- @cmt htlx 合同类型
-- @cmt htzje 合同总金额
-- @cmt hzje 合作金额
-- @cmt id 主键ID
-- @cmt jfmc 甲方名称
-- @cmt jqmc 景区名称
-- @cmt jsr 经手人
-- @cmt khmc1 客户名称1
-- @cmt khmc2 客户名称2
-- @cmt lcbh 流程编号
-- @cmt lcmb 流程模板
-- @cmt lxdh 联系电话
-- @cmt mt 美团
-- @cmt mx5 明细5
-- @cmt ptid 平台ID
-- @cmt ptzh 平台账号
-- @cmt ptzh1 平台账号1
-- @cmt requestId 流程请求ID
-- @cmt rjxq 软件需求
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqsj 申请时间
-- @cmt wldh 物流单号
-- @cmt wlfs 物流方式
-- @cmt yfkje 预付款金额
-- @cmt yskje 已收款金额
-- @cmt ywlxxx 业务联系信息
CREATE TABLE `formtable_main_176` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqsj` char(10) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `lyfs` text,
  `xmsxsj` char(10) DEFAULT NULL,
  `rjnr` text,
  `fkrmc` varchar(999) DEFAULT NULL,
  `fpmc` varchar(999) DEFAULT NULL,
  `skqr` varchar(999) DEFAULT NULL,
  `yjxq` varchar(999) DEFAULT NULL,
  `rjxq` varchar(999) DEFAULT NULL,
  `yjdzmzjdh` varchar(999) DEFAULT NULL,
  `tp` text,
  `qsx` varchar(999) DEFAULT NULL,
  `sfdtfh` int(11) DEFAULT NULL,
  `htbh` varchar(1000) DEFAULT NULL,
  `ptzh` varchar(1000) DEFAULT NULL,
  `ptzh1` varchar(999) DEFAULT NULL,
  `zlksrq` char(10) DEFAULT NULL,
  `zljsrq` char(10) DEFAULT NULL,
  `hzje` decimal(15,2) DEFAULT NULL,
  `sfzbqn` text,
  `sfxysk` text,
  `wldh` varchar(999) DEFAULT NULL,
  `wlfs` varchar(999) DEFAULT NULL,
  `fjsc` text,
  `sqxz` int(11) DEFAULT NULL,
  `yfkje` decimal(38,2) DEFAULT NULL,
  `dhkje` decimal(38,2) DEFAULT NULL,
  `yskje` decimal(38,2) DEFAULT NULL,
  `cwqrskje` decimal(38,2) DEFAULT NULL,
  `fhbhqk` int(11) DEFAULT NULL,
  `ce` decimal(38,2) DEFAULT NULL,
  `htlx` int(11) DEFAULT NULL,
  `khmc1` varchar(999) DEFAULT NULL,
  `khmc2` text,
  `erpcrkdh` int(11) DEFAULT NULL,
  `ptid` varchar(999) DEFAULT NULL,
  `ertdh` varchar(999) DEFAULT NULL,
  `xqdzmqknczxfwbgxzbhxqmqbczbgxz` varchar(999) DEFAULT NULL,
  `xsjysfgh` int(11) DEFAULT NULL,
  `jqmc` varchar(999) DEFAULT NULL,
  `kk` int(11) DEFAULT NULL,
  `jylx` int(11) DEFAULT NULL,
  `zbq` int(11) DEFAULT NULL,
  `ghsbslhj1` text,
  `jyzshsbslhj` text,
  `xssbslhj2` text,
  `dssbslhj` text,
  `dssbfjsc` text,
  `zrsbslhj` text,
  `slsfyz` int(11) DEFAULT NULL,
  `sjdhsl` text,
  `ycwlztsm` text,
  `jyzyerpdh` varchar(999) DEFAULT NULL,
  `dsshyy` text,
  `gzsbbh` varchar(999) DEFAULT NULL,
  `gzsbfhsj` char(10) DEFAULT NULL,
  `lxdh` varchar(999) DEFAULT NULL,
  `zrerpcrkdh` text,
  `ztrerpcrkdh` text,
  `fjsc1` text,
  `ycbm` int(11) DEFAULT NULL,
  `jsr` int(11) DEFAULT NULL,
  `bcfhsfbhzjzzj` int(11) DEFAULT NULL,
  `bcfhyqbwc` int(11) DEFAULT NULL,
  `bczjfhsl` int(11) DEFAULT NULL,
  `bczzjfhsl` int(11) DEFAULT NULL,
  `zjzdh` text,
  `zzjzdh` text,
  `gllc` text,
  `ywlxxx` int(11) DEFAULT NULL,
  `sfswlsyb` int(11) DEFAULT NULL,
  `yjdhsj` char(10) DEFAULT NULL,
  `htzje` decimal(38,2) DEFAULT NULL,
  `sfhyjfbxq` int(11) DEFAULT NULL,
  `fbxqmx` text,
  `dsfcz` int(11) DEFAULT NULL,
  `mt` int(11) DEFAULT NULL,
  `yjxqdh` text,
  `rjxqdh` text,
  `xmht` int(11) DEFAULT NULL,
  `zlcb` decimal(38,2) DEFAULT NULL,
  `jfmc` text,
  `mx5` text,
  `ywyqrdkjejdksj` text,
  `lcmb` int(11) DEFAULT NULL,
  `qhtj` int(11) DEFAULT NULL,
  `glbjsplc` text,
  `lyfsdx` int(11) DEFAULT NULL,
  `gllxsqdtz` text,
  `sfbhdz` int(11) DEFAULT NULL,
  `htfkzt` int(11) DEFAULT NULL,
  `xlk` int(11) DEFAULT NULL,
  `sfxm` int(11) DEFAULT NULL,
  `yjghsj` char(10) DEFAULT NULL,
  `sfxmtsdz` int(11) DEFAULT NULL,
  `erp_state` int(1) NOT NULL DEFAULT '0' COMMENT 'erp状态',
  `xmgzbm` int(11) DEFAULT NULL,
  `ygje` decimal(38,2) DEFAULT NULL,
  `cglb` int(11) DEFAULT NULL,
  `xmzt` int(11) DEFAULT NULL,
  `ywry` int(11) DEFAULT NULL,
  `sjcgje` decimal(38,2) DEFAULT NULL,
  `gyslxfs` varchar(100) DEFAULT NULL,
  `cgfj` text,
  `gw` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5035 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_176_dt2
-- @at 2026-11-27 16:18:20
-- @cmt fjsc 附件上传
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
-- @cmt wldh 物流单号
-- @cmt wlfs 物流方式
CREATE TABLE `formtable_main_176_dt2` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `sbsl` decimal(38,2) DEFAULT NULL,
  `fhsj` char(10) DEFAULT NULL,
  `wldh` varchar(999) DEFAULT NULL,
  `wlfs` varchar(999) DEFAULT NULL,
  `fjsc` text,
  `wlfy` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4092 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_194
-- @at 2026-11-27 16:18:24
-- @cmt bz 备注
-- @cmt dsfcz 第三方厂商
-- @cmt fj 附件
-- @cmt htbh 合同编号
-- @cmt htje 合同金额
-- @cmt id 主键ID
-- @cmt jfmc 甲方名称
-- @cmt jqlx 景区类型
-- @cmt jqlx2 景区类型2
-- @cmt jqmc 景区名称
-- @cmt khlx 客户类型
-- @cmt khlx2 客户类型2
-- @cmt lcbh 流程编号
-- @cmt mt 美团
-- @cmt ptidsj 平台ID时间
-- @cmt q 季度
-- @cmt requestId 流程请求ID
-- @cmt rjxq 软件需求
-- @cmt s 类型
-- @cmt sfbzhxm 是否标准化项目
-- @cmt sfcs 省份城市
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqrq 申请日期
-- @cmt xmgzbm 项目跟踪编码
-- @cmt xmlx 项目类型
-- @cmt xmmc 项目名称
-- @cmt xxdz 信息地址
-- @cmt yjlx 业绩类型
-- @cmt ywlx 业务类型
-- @cmt ywlxxx 业务联系信息
CREATE TABLE `formtable_main_194` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `jjdbh` varchar(999) DEFAULT NULL,
  `htsfgl` int(11) DEFAULT NULL,
  `sfbzhxm` int(11) DEFAULT NULL,
  `jfmc` varchar(999) DEFAULT NULL,
  `xmmc` varchar(999) DEFAULT NULL,
  `jqmc` varchar(999) DEFAULT NULL,
  `xmbj` text,
  `xmlx` int(11) DEFAULT NULL,
  `htje` varchar(999) DEFAULT NULL,
  `khlx` text,
  `jqlx` text,
  `jqaj` int(11) DEFAULT NULL,
  `jqdz` varchar(999) DEFAULT NULL,
  `rjxq` text,
  `scfs` text,
  `pwxtzhbx` int(11) DEFAULT NULL,
  `yjsxsj` char(10) DEFAULT NULL,
  `qjczhbx` int(11) DEFAULT NULL,
  `bmsxsj` char(10) DEFAULT NULL,
  `fj` text,
  `zpxmjl` int(11) DEFAULT NULL,
  `xmgzbm` int(11) DEFAULT NULL,
  `xsktc` text,
  `htbh` text,
  `khlxq` varchar(999) DEFAULT NULL,
  `jqlxq` varchar(999) DEFAULT NULL,
  `jqjbq` varchar(999) DEFAULT NULL,
  `tsdz` varchar(999) DEFAULT NULL,
  `tswc` varchar(999) DEFAULT NULL,
  `rjxqq` varchar(999) DEFAULT NULL,
  `skfsq` varchar(999) DEFAULT NULL,
  `bz` text,
  `glhtspdj` text,
  `htqysj` char(10) DEFAULT NULL,
  `glsbsplcbd` text,
  `sfcs` int(11) DEFAULT NULL,
  `xxdz` varchar(999) DEFAULT NULL,
  `s` int(11) DEFAULT NULL,
  `ytxm` int(11) DEFAULT NULL,
  `xnhtbh` text,
  `zpxmkf` int(11) DEFAULT NULL,
  `ywlxxx` int(11) DEFAULT NULL,
  `pt` text,
  `ypw` text,
  `wsc` text,
  `q` text,
  `yjlx` text,
  `yjxh` varchar(999) DEFAULT NULL,
  `pftzh` varchar(999) DEFAULT NULL,
  `gysqx` int(11) DEFAULT NULL,
  `dlskxxsfysj` int(11) DEFAULT NULL,
  `sfxzptzh` int(11) DEFAULT NULL,
  `zpxmjl1` int(11) DEFAULT NULL,
  `ptidsj` varchar(999) DEFAULT NULL,
  `htsj` char(10) DEFAULT NULL,
  `htjssj` char(10) DEFAULT NULL,
  `khlx2` int(11) DEFAULT NULL,
  `sfgy` int(11) DEFAULT NULL,
  `jqlx2` int(11) DEFAULT NULL,
  `ywlx` int(11) DEFAULT NULL,
  `dsfcz` int(11) DEFAULT NULL,
  `mt` int(11) DEFAULT NULL,
  `bm` int(11) DEFAULT NULL,
  `lcmb` int(11) DEFAULT NULL,
  `sftjsbsqd` int(11) DEFAULT NULL,
  `sf` int(11) DEFAULT NULL,
  `sfxyxmjl` int(11) DEFAULT NULL,
  `glwllxtz` text,
  `khlx3` int(11) DEFAULT NULL,
  `fl` varchar(100) DEFAULT NULL,
  `wktdlskyy` varchar(999) DEFAULT NULL,
  `dlsksxsj` varchar(100) DEFAULT NULL,
  `xmfl` int(11) DEFAULT NULL,
  `sfgb` int(11) DEFAULT NULL,
  `gbbm` text,
  `zpsszc` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=783 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_211
-- @at 2026-11-27 16:18:28
-- @cmt bh 编号
-- @cmt cplx 产品类型
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt jqmc 景区名称
-- @cmt khlxr 客户联系人
-- @cmt lxdh 联系电话
-- @cmt requestId 流程请求ID
-- @cmt scfj 上传附件
-- @cmt sqr 申请人
CREATE TABLE `formtable_main_211` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `tjsj` char(10) DEFAULT NULL,
  `bh` varchar(999) DEFAULT NULL,
  `jqmc` varchar(999) DEFAULT NULL,
  `fksj` char(10) DEFAULT NULL,
  `htbh` text,
  `slqd` int(11) DEFAULT NULL,
  `sfjj` int(11) DEFAULT NULL,
  `khlxr` varchar(999) DEFAULT NULL,
  `lxdh` varchar(999) DEFAULT NULL,
  `cplx` int(11) DEFAULT NULL,
  `yhzxlx` int(11) DEFAULT NULL,
  `cpwt` int(11) DEFAULT NULL,
  `ryjlx` int(11) DEFAULT NULL,
  `wtms` text,
  `xzfqr` int(11) DEFAULT NULL,
  `slsx` decimal(38,2) DEFAULT NULL,
  `scfj` text,
  `qcplx` varchar(999) DEFAULT NULL,
  `qcpwt` varchar(999) DEFAULT NULL,
  `qxzlx` varchar(999) DEFAULT NULL,
  `slqd1` int(11) DEFAULT NULL,
  `clfs` int(11) DEFAULT NULL,
  `wtfklx` int(11) DEFAULT NULL,
  `cljg` text,
  `wtdl` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=409 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_212
-- @at 2026-11-27 16:18:32
-- @cmt bh 编号
-- @cmt bz 备注
-- @cmt bz1 备注1
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt jqmc 景区名称
-- @cmt lxdh 联系电话
-- @cmt requestId 流程请求ID
-- @cmt sqr 申请人
-- @cmt sqsj 申请时间
-- @cmt tcsj 提成时间
CREATE TABLE `formtable_main_212` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `bh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqsj` char(10) DEFAULT NULL,
  `jqmc` varchar(999) DEFAULT NULL,
  `htbh` text,
  `hflx` int(11) DEFAULT NULL,
  `sfysgwc` int(11) DEFAULT NULL,
  `jqlxr` varchar(999) DEFAULT NULL,
  `lxdh` varchar(999) DEFAULT NULL,
  `lxrjs` varchar(999) DEFAULT NULL,
  `dqqkms` text,
  `zphfkf` int(11) DEFAULT NULL,
  `njqdsbazhlm` int(11) DEFAULT NULL,
  `qwnxzsfyjkssywsdsbln` int(11) DEFAULT NULL,
  `qwssmyydznwkssyn` text,
  `ndwsdrjcpsfmy` int(11) DEFAULT NULL,
  `ndwsdyjsbsfmy` int(11) DEFAULT NULL,
  `ndwsdssgcsdfwsfmy` int(11) DEFAULT NULL,
  `bz` text,
  `nfkdwtsfddjj` int(11) DEFAULT NULL,
  `ndwsdssgcsdfws1fmy` int(11) DEFAULT NULL,
  `ndwtdclsdsfgdmy` int(11) DEFAULT NULL,
  `bz1` text,
  `xzhfnr` varchar(999) DEFAULT NULL,
  `smshhfnr` varchar(999) DEFAULT NULL,
  `rjbmyyy` varchar(999) DEFAULT NULL,
  `yjbmyyy` varchar(999) DEFAULT NULL,
  `ssgcsbmyyy` varchar(999) DEFAULT NULL,
  `ssgcsbmyyy1` varchar(999) DEFAULT NULL,
  `bmyhs` int(11) DEFAULT NULL,
  `sfys` int(11) DEFAULT NULL,
  `tcsj` char(10) DEFAULT NULL,
  `glxslxtz` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1185 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_213
-- @at 2026-11-27 16:18:36
-- @cmt bh 编号
-- @cmt bhgyyms 不合格原因描述
-- @cmt fjsc 附件上传
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt jqmc 景区名称
-- @cmt requestId 流程请求ID
-- @cmt sfhg 是否合格
-- @cmt wldh 物流单号
-- @cmt xsry 销售人员
CREATE TABLE `formtable_main_213` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `jqmc` varchar(999) DEFAULT NULL,
  `kxlx` int(11) DEFAULT NULL,
  `htbh` text,
  `kxsj` char(10) DEFAULT NULL,
  `sfhg` int(11) DEFAULT NULL,
  `bhgcpmc` varchar(999) DEFAULT NULL,
  `bhgyyms` text,
  `fjsc` text,
  `sfsjzd` int(11) DEFAULT NULL,
  `bh` varchar(999) DEFAULT NULL,
  `bckxcpmc` varchar(999) DEFAULT NULL,
  `bhgyyfx` text,
  `sfxyjhbhgwl` int(11) DEFAULT NULL,
  `gzfxr` int(11) DEFAULT NULL,
  `jhfs` int(11) DEFAULT NULL,
  `xsry` int(11) DEFAULT NULL,
  `wldh` varchar(999) DEFAULT NULL,
  `gzfxj` text,
  `gzbgsc` text,
  `bhgyygz` int(11) DEFAULT NULL,
  `bhgqsm` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=571 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_213_dt1
-- @at 2026-11-27 16:18:43
-- @cmt bhgyyms 不合格原因描述
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
-- @cmt sfhg 是否合格
CREATE TABLE `formtable_main_213_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `kxcplx` int(11) DEFAULT NULL,
  `kxsl` varchar(999) DEFAULT NULL,
  `xxdwlpj` varchar(999) DEFAULT NULL,
  `kxcpmc` varchar(999) DEFAULT NULL,
  `sfhg` int(11) DEFAULT NULL,
  `bhgyyms` varchar(999) DEFAULT NULL,
  `bhgtpfjsc` text,
  `sfzsdh` int(11) DEFAULT NULL,
  `tzdhsj` char(10) DEFAULT NULL,
  `sjdhsj` char(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1986 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_233
-- @at 2026-11-27 16:18:47
-- @cmt id 主键ID
-- @cmt khjl 客户经理
-- @cmt khmc 客户名称
-- @cmt lcbm 流程编码
-- @cmt requestId 流程请求ID
-- @cmt sj 时间
-- @cmt sm 说明
-- @cmt sprq 审批日期
-- @cmt xmmc 项目名称
-- @cmt yj 业绩
-- @cmt yjsj 业绩时间
-- @cmt zbj 质保金
CREATE TABLE `formtable_main_233` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `xmmc` varchar(999) DEFAULT NULL,
  `khmc` varchar(999) DEFAULT NULL,
  `khjl` int(11) DEFAULT NULL,
  `sprq` char(10) DEFAULT NULL,
  `dzrs` int(11) DEFAULT NULL,
  `dzts` int(11) DEFAULT NULL,
  `sm` text,
  `xmxx` varchar(999) DEFAULT NULL,
  `yj` varchar(999) DEFAULT NULL,
  `wcrj` varchar(999) DEFAULT NULL,
  `dzrj` varchar(999) DEFAULT NULL,
  `wbsf` varchar(999) DEFAULT NULL,
  `wbcb` varchar(999) DEFAULT NULL,
  `sfzbj10` varchar(999) DEFAULT NULL,
  `qcbje` varchar(999) DEFAULT NULL,
  `xmzcb` varchar(999) DEFAULT NULL,
  `zbj` varchar(999) DEFAULT NULL,
  `ztmll` varchar(999) DEFAULT NULL,
  `xmbjsm` text,
  `x` int(11) DEFAULT NULL,
  `lcbm` varchar(999) DEFAULT NULL,
  `tj` decimal(38,2) DEFAULT NULL,
  `dzrt` varchar(999) DEFAULT NULL,
  `zcyjzk` varchar(999) DEFAULT NULL,
  `zcrjzk` varchar(999) DEFAULT NULL,
  `tj2` decimal(38,2) DEFAULT NULL,
  `yjcb` decimal(38,2) DEFAULT NULL,
  `yjsj` decimal(38,2) DEFAULT NULL,
  `rjcb` decimal(38,2) DEFAULT NULL,
  `rjsj` decimal(38,2) DEFAULT NULL,
  `sj` decimal(15,4) DEFAULT NULL,
  `wbcb1` decimal(15,4) DEFAULT NULL,
  `wbsj` decimal(38,2) DEFAULT NULL,
  `yscb` decimal(38,2) DEFAULT NULL,
  `yssj` decimal(38,2) DEFAULT NULL,
  `yhje` decimal(38,2) DEFAULT NULL,
  `dzrjzkj` decimal(38,2) DEFAULT NULL,
  `wbzkj` decimal(38,2) DEFAULT NULL,
  `yszkj` decimal(38,2) DEFAULT NULL,
  `sbyjzkj` decimal(38,2) DEFAULT NULL,
  `sbrjzkj` decimal(38,2) DEFAULT NULL,
  `sbyjsl` decimal(38,2) DEFAULT NULL,
  `sbrjsl` decimal(38,2) DEFAULT NULL,
  `rjzkj` decimal(38,2) DEFAULT NULL,
  `sbrjcb` decimal(38,2) DEFAULT NULL,
  `sbrjsj` decimal(38,2) DEFAULT NULL,
  `sbrjzb` decimal(38,2) DEFAULT NULL,
  `zkjrj` decimal(38,2) DEFAULT NULL,
  `zkbl` decimal(38,2) DEFAULT NULL,
  `dzrjsd` int(11) DEFAULT NULL,
  `zhfycb` decimal(38,2) DEFAULT NULL,
  `zhfysj` decimal(38,2) DEFAULT NULL,
  `zhfyzkj` decimal(38,2) DEFAULT NULL,
  `zhfycb9` decimal(38,2) DEFAULT NULL,
  `zhfysj9` decimal(38,2) DEFAULT NULL,
  `zhfyzkj9` decimal(38,2) DEFAULT NULL,
  `fbsbcb` decimal(38,2) DEFAULT NULL,
  `fbsbsj` decimal(38,2) DEFAULT NULL,
  `fbsbsl` decimal(38,2) DEFAULT NULL,
  `fbsbzkj` decimal(38,2) DEFAULT NULL,
  `fbsbzb` decimal(38,2) DEFAULT NULL,
  `cgrjsj` decimal(38,2) DEFAULT NULL,
  `cgrjzb` decimal(38,2) DEFAULT NULL,
  `cgrjzkj` decimal(38,2) DEFAULT NULL,
  `cgrjcb` decimal(38,2) DEFAULT NULL,
  `dzrjcb` decimal(38,2) DEFAULT NULL,
  `dzrjsj` decimal(38,2) DEFAULT NULL,
  `dzrjzb` decimal(38,2) DEFAULT NULL,
  `dzrjzkj2` decimal(38,2) DEFAULT NULL,
  `sfxydz` int(11) DEFAULT NULL,
  `zhbxcb` decimal(38,2) DEFAULT NULL,
  `zhbxsj` decimal(38,2) DEFAULT NULL,
  `zhbxzkj` decimal(38,2) DEFAULT NULL,
  `zhbxcb1` decimal(38,2) DEFAULT NULL,
  `zhbxsj1` decimal(38,2) DEFAULT NULL,
  `zhbxzkj1` decimal(38,2) DEFAULT NULL,
  `yyx` decimal(15,4) DEFAULT NULL,
  `zkbl4` decimal(38,6) DEFAULT NULL,
  `lxrxm` varchar(100) DEFAULT NULL,
  `sjmc` varchar(100) DEFAULT NULL,
  `zdzk` decimal(38,2) DEFAULT NULL,
  `crmbh` varchar(999) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1833 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_236
-- @at 2026-11-27 16:19:03
-- @cmt bh 编号
-- @cmt csrq 出生日期
-- @cmt gh 工号
-- @cmt id 主键ID
-- @cmt requestId 流程请求ID
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqsj 申请时间
-- @cmt xb 性别
-- @cmt zjsj 增加时间
CREATE TABLE `formtable_main_236` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `bh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `sqsj` char(10) DEFAULT NULL,
  `gh` varchar(999) DEFAULT NULL,
  `xb` int(11) DEFAULT NULL,
  `csrq` char(10) DEFAULT NULL,
  `zgxl` int(11) DEFAULT NULL,
  `zj` varchar(999) DEFAULT NULL,
  `zgrq` char(10) DEFAULT NULL,
  `zjsj` int(11) DEFAULT NULL,
  `grzpzj` text,
  `zgsyqjxkhpjf` decimal(38,2) DEFAULT NULL,
  `zgsyqpxkhf` decimal(38,2) DEFAULT NULL,
  `zzyj` int(11) DEFAULT NULL,
  `zzzj` varchar(999) DEFAULT NULL,
  `zzsxrq` char(10) DEFAULT NULL,
  `xzsfyd` int(11) DEFAULT NULL,
  `dzhxz` decimal(38,2) DEFAULT NULL,
  `xzydsxrq` char(10) DEFAULT NULL,
  `zgkcqtgrq` char(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_240
-- @at 2026-11-27 16:22:00
-- @cmt bz 备注
-- @cmt fjsc 附件上传
-- @cmt fkfs 付款方式
-- @cmt fpbh 发票编号
-- @cmt fpje 发票金额
-- @cmt fplx 发票类型
-- @cmt fpmc 发票名称
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt khh 开户行
-- @cmt lcbm 流程编码
-- @cmt lcmb 流程模板
-- @cmt requestid 流程请求ID
-- @cmt sjbm 时间部门
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqrq 申请日期
-- @cmt tcje 提成金额
-- @cmt yyje 原因金额
CREATE TABLE `formtable_main_240` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestid` int(11) DEFAULT NULL,
  `lcbm` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `fkfs` int(11) DEFAULT NULL,
  `ywfp` int(11) DEFAULT NULL,
  `zfdxhm` varchar(999) DEFAULT NULL,
  `khh` varchar(999) DEFAULT NULL,
  `yhzh` varchar(999) DEFAULT NULL,
  `bz` varchar(999) DEFAULT NULL,
  `fjsc` text,
  `fkjey` decimal(15,2) DEFAULT NULL,
  `fklx` int(11) DEFAULT NULL,
  `htbh` varchar(1000) DEFAULT NULL,
  `cwqrfp` int(11) DEFAULT NULL,
  `fplx` int(11) DEFAULT NULL,
  `fpmc` varchar(999) DEFAULT NULL,
  `fpbh` varchar(999) DEFAULT NULL,
  `fpje` decimal(38,2) DEFAULT NULL,
  `xglc` int(11) DEFAULT NULL,
  `xgdlc` text,
  `sfzxfy` int(11) DEFAULT NULL,
  `zxmc` text,
  `qrfk` int(11) DEFAULT NULL,
  `qrfksj` char(10) DEFAULT NULL,
  `tcxg` int(11) DEFAULT NULL,
  `tcje` varchar(999) DEFAULT NULL,
  `fylxtj` text,
  `tj` text,
  `lcmb` int(11) DEFAULT NULL,
  `sfts` int(11) DEFAULT NULL,
  `sfyft` int(11) DEFAULT NULL,
  `sfyjtk` int(11) DEFAULT NULL,
  `fysfkn` int(11) DEFAULT NULL,
  `ptywlx` int(11) DEFAULT NULL,
  `gllxsqdtz` text,
  `sfydzfp` int(11) DEFAULT NULL,
  `sfxjjl` int(11) DEFAULT NULL,
  `sfsddj` int(11) DEFAULT NULL,
  `sjbm` int(11) DEFAULT NULL,
  `nf` int(11) DEFAULT NULL,
  `syje` decimal(38,2) DEFAULT NULL,
  `yyje` decimal(38,2) DEFAULT NULL,
  `gxyyje` decimal(38,2) DEFAULT NULL,
  `zjxje` decimal(38,2) DEFAULT NULL,
  `gxsyje` decimal(38,2) DEFAULT NULL,
  `zfdx` text,
  `yhzhylk` text,
  `erp_state` int(11) DEFAULT NULL COMMENT '成功状态0:失败，1:成功',
  `lcly` int(11) DEFAULT NULL,
  `dzfpzl` int(11) DEFAULT NULL,
  `lsfzt` varchar(100) DEFAULT NULL,
  `yjfyj` int(11) DEFAULT NULL,
  `xfylxbdtj` varchar(100) DEFAULT NULL,
  `httktj` int(11) DEFAULT NULL,
  `sfpbg` int(11) DEFAULT NULL,
  `pbglb` int(11) DEFAULT NULL,
  `bmtj` int(11) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `jxdtz` text,
  `ghdtz` text,
  `sybq` varchar(100) DEFAULT NULL,
  `sfxgcxzx` int(11) DEFAULT NULL,
  `hjspbq` varchar(10) DEFAULT NULL,
  `hkbl` varchar(100) DEFAULT NULL,
  `bm` int(11) DEFAULT NULL,
  `gzzt` int(11) DEFAULT NULL,
  `pdsfwsaar` int(11) DEFAULT NULL,
  `sffy` int(11) DEFAULT NULL,
  `ysydj` int(11) DEFAULT NULL,
  `glsydj` int(11) DEFAULT NULL,
  `kslx` int(11) DEFAULT NULL,
  `yfkje` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10441 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_240_dt1
-- @at 2026-11-27 16:22:04
-- @cmt bhsj 编号时间
-- @cmt id 主键ID
-- @cmt je 金额
-- @cmt mainid 主表记录ID
-- @cmt sl 数量
CREATE TABLE `formtable_main_240_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `fygzbm` int(11) DEFAULT NULL,
  `fylx` text,
  `yjkm` text,
  `ejkm` text,
  `sjkm` text,
  `fyyt` varchar(999) DEFAULT NULL,
  `je` decimal(38,2) DEFAULT NULL,
  `sjkmsjid` varchar(999) DEFAULT NULL,
  `zpje` decimal(38,2) DEFAULT NULL,
  `se` decimal(38,2) DEFAULT NULL,
  `bhsj` decimal(38,2) DEFAULT NULL,
  `sl` int(11) DEFAULT NULL,
  `slwbk` varchar(999) DEFAULT NULL,
  `fygzbmdbm` text,
  `cgddh` varchar(100) DEFAULT NULL,
  `xfylx` text,
  `sfhtxg` int(11) DEFAULT NULL,
  `khmc` text,
  `sjmc` text,
  `htbh` text,
  `gwtj` int(11) DEFAULT NULL,
  `glhkjh` text,
  `hktj` int(11) DEFAULT NULL,
  `sjmctj` varchar(999) DEFAULT NULL,
  `sjbttj` int(11) DEFAULT NULL,
  `htmctj` varchar(999) DEFAULT NULL,
  `sfxgcxzx` int(11) DEFAULT NULL,
  `crmsfyrk` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `formtable_main_240_dt1_mId` (`mainid`)
) ENGINE=InnoDB AUTO_INCREMENT=21492 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_243
-- @at 2026-11-27 16:22:08
-- @cmt cwqrskje 财务确认收款金额
-- @cmt hsje H金额
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt lcbh 流程编号
-- @cmt lcmb 流程模板
-- @cmt requestid 流程请求ID
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqrq 申请日期
CREATE TABLE `formtable_main_243` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestid` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `jehjdx` decimal(15,2) DEFAULT NULL,
  `hsje` decimal(38,2) DEFAULT NULL,
  `djzs` decimal(38,2) DEFAULT NULL,
  `djsc` text,
  `djkje` decimal(38,2) DEFAULT NULL,
  `bxlx` int(11) DEFAULT NULL,
  `htbh` varchar(1000) DEFAULT NULL,
  `bxzx` int(11) DEFAULT NULL,
  `sfdjk` int(11) DEFAULT NULL,
  `sbjey1` decimal(15,2) DEFAULT NULL,
  `xglc2` text,
  `sfydzfp` int(11) DEFAULT NULL,
  `sfzxfy` int(11) DEFAULT NULL,
  `zxmc` text,
  `qrbx` int(11) DEFAULT NULL,
  `qrbxsj` char(10) DEFAULT NULL,
  `sfyft` int(11) DEFAULT NULL,
  `ywfp` int(11) DEFAULT NULL,
  `lcmb` int(11) DEFAULT NULL,
  `fysfkn` int(11) DEFAULT NULL,
  `ptywlx` int(11) DEFAULT NULL,
  `zhxx` varchar(999) DEFAULT NULL,
  `yhzh` varchar(999) DEFAULT NULL,
  `gllxsqdtz` text,
  `sfxjjl` int(11) DEFAULT NULL,
  `sfsddj` int(11) DEFAULT NULL,
  `cwqrskje` decimal(15,2) DEFAULT NULL,
  `ptyfbbxgllc` varchar(1) DEFAULT NULL,
  `xmsfys` int(11) DEFAULT NULL,
  `sfxgb` int(11) DEFAULT NULL,
  `yhzhylk` text,
  `dzfpzl` int(11) DEFAULT NULL,
  `sqrbmtj` int(11) DEFAULT NULL,
  `bmsfyz` int(11) DEFAULT NULL,
  `fyfzbm` int(11) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `khmc` text,
  `gwbttj` int(11) DEFAULT NULL,
  `sjmin` text,
  `bm` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=9350 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_243_dt1
-- @at 2026-11-27 16:22:11
-- @cmt bhsj 编号时间
-- @cmt bz 备注
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt je 金额
-- @cmt mainid 主表记录ID
-- @cmt sl 数量
-- @cmt xmmc 项目名称
-- @cmt ywy 业务员
CREATE TABLE `formtable_main_243_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `fyyt` varchar(999) DEFAULT NULL,
  `je` decimal(38,2) DEFAULT NULL,
  `fylx` varchar(1000) DEFAULT NULL,
  `xmmc` varchar(999) DEFAULT NULL,
  `bz` varchar(999) DEFAULT NULL,
  `fygzbm` int(11) DEFAULT NULL,
  `yjkm` text,
  `ejkm` text,
  `sjkm` text,
  `zpje` decimal(38,2) DEFAULT NULL,
  `sl` int(11) DEFAULT NULL,
  `se` decimal(38,2) DEFAULT NULL,
  `bhsj` decimal(38,2) DEFAULT NULL,
  `sjkmsjid` varchar(999) DEFAULT NULL,
  `slwbk` varchar(999) DEFAULT NULL,
  `ywy` int(11) DEFAULT NULL,
  `ywryxstj` int(11) DEFAULT NULL,
  `xfylx` text,
  `kkje` decimal(38,2) DEFAULT NULL,
  `three_je` decimal(38,2) DEFAULT NULL,
  `three_se` decimal(38,2) DEFAULT NULL,
  `three_zs` int(11) DEFAULT NULL,
  `nine_je` decimal(38,2) DEFAULT NULL,
  `nine_se` decimal(38,2) DEFAULT NULL,
  `nine_zs` int(11) DEFAULT NULL,
  `one` decimal(38,2) DEFAULT NULL,
  `three` decimal(38,2) DEFAULT NULL,
  `six` decimal(38,2) DEFAULT NULL,
  `xglc` text,
  `htbh` text,
  `thirteen` decimal(38,2) DEFAULT NULL,
  `zpse` decimal(38,2) DEFAULT NULL,
  `hsjehj` decimal(38,2) DEFAULT NULL,
  `khmc` text,
  `sjmignc` text,
  `gwtj` int(11) DEFAULT NULL,
  `bxxg` int(11) DEFAULT NULL,
  `sjmctj` varchar(999) DEFAULT NULL,
  `sjbttj` int(11) DEFAULT NULL,
  `fylxpandua` int(11) DEFAULT NULL,
  `htkhbtxz` int(11) DEFAULT NULL,
  `frbxlx` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16452 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_244
-- @at 2026-11-27 16:22:16
-- @cmt bz 备注
-- @cmt fjsc 附件上传
-- @cmt id 主键ID
-- @cmt jqmc 景区名称
-- @cmt lcbm 流程编码
-- @cmt lcmb 流程模板
-- @cmt requestid 流程请求ID
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqrq 申请日期
-- @cmt xmlx 项目类型
-- @cmt ywy 业务员
CREATE TABLE `formtable_main_244` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestid` int(11) DEFAULT NULL,
  `lcbm` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `clbxsy` varchar(999) DEFAULT NULL,
  `fyhjy` decimal(15,2) DEFAULT NULL,
  `sfdjk` int(11) DEFAULT NULL,
  `sfzjc` int(11) DEFAULT NULL,
  `bz` varchar(999) DEFAULT NULL,
  `fjsc` text,
  `sbjey` decimal(15,2) DEFAULT NULL,
  `sglx` int(11) DEFAULT NULL,
  `thr` text,
  `bxzx01` int(11) DEFAULT NULL,
  `glycsqlc` text,
  `djkje` decimal(38,2) DEFAULT NULL,
  `sbjey1` decimal(15,2) DEFAULT NULL,
  `xmfzd` int(11) DEFAULT NULL,
  `snsw` int(11) DEFAULT NULL,
  `sfkls` int(11) DEFAULT NULL,
  `sslx` int(11) DEFAULT NULL,
  `ywy` int(11) DEFAULT NULL,
  `sfydzfp` int(11) DEFAULT NULL,
  `jqmc` varchar(999) DEFAULT NULL,
  `glmyddcb` text,
  `glyjkxspd` text,
  `sfzx` int(11) DEFAULT NULL,
  `zxmc` text,
  `ds3` decimal(38,2) DEFAULT NULL,
  `zs` int(11) DEFAULT NULL,
  `ds9` decimal(38,2) DEFAULT NULL,
  `zs2` int(11) DEFAULT NULL,
  `bxzx` int(11) DEFAULT NULL,
  `qrbx` int(11) DEFAULT NULL,
  `qrbxsj` char(10) DEFAULT NULL,
  `lcmb` int(11) DEFAULT NULL,
  `smshwtdl` int(11) DEFAULT NULL,
  `smshwtxl` int(11) DEFAULT NULL,
  `fysfkn` int(11) DEFAULT NULL,
  `ptywlx` int(11) DEFAULT NULL,
  `bmtj` varchar(999) DEFAULT NULL,
  `zhxx` varchar(999) DEFAULT NULL,
  `yhzh` varchar(999) DEFAULT NULL,
  `gllxsqdtz` text,
  `gcwdsc` text,
  `sfxjjl` int(11) DEFAULT NULL,
  `sfsddj` int(11) DEFAULT NULL,
  `xmlx` int(11) DEFAULT NULL,
  `ssjdhf` text,
  `smshwtdldx` text,
  `smshwtxldx` text,
  `sfxgb` int(11) DEFAULT NULL,
  `xmsfys` int(11) DEFAULT NULL,
  `yhzhylk` text,
  `dzfpzl` int(11) DEFAULT NULL,
  `sqrbmtj` int(11) DEFAULT NULL,
  `bmsfyz` int(11) DEFAULT NULL,
  `fyfzbm` int(11) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `khmc` text,
  `khbttj` int(11) DEFAULT NULL,
  `frbttj` int(11) DEFAULT NULL,
  `FRbaoio` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16232 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_244_dt1
-- @at 2026-11-27 16:22:21
-- @cmt bz 备注
-- @cmt fj 附件
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
-- @cmt rq 日期
-- @cmt xmmc 项目名称
CREATE TABLE `formtable_main_244_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `rq` char(10) DEFAULT NULL,
  `fjy` decimal(38,2) DEFAULT NULL,
  `hcy` decimal(38,2) DEFAULT NULL,
  `smkccy` decimal(38,2) DEFAULT NULL,
  `qfsmy` decimal(38,2) DEFAULT NULL,
  `snjtfy` decimal(38,2) DEFAULT NULL,
  `zsfy` decimal(38,2) DEFAULT NULL,
  `zfy` decimal(38,2) DEFAULT NULL,
  `bty` decimal(38,2) DEFAULT NULL,
  `xjy` decimal(38,2) DEFAULT NULL,
  `pjzs` decimal(38,2) DEFAULT NULL,
  `bz` varchar(999) DEFAULT NULL,
  `fj` text,
  `bxlx` int(11) DEFAULT NULL,
  `htbh` varchar(1000) DEFAULT NULL,
  `cclc` int(11) DEFAULT NULL,
  `cfd` int(11) DEFAULT NULL,
  `mdd` int(11) DEFAULT NULL,
  `xmmc` varchar(999) DEFAULT NULL,
  `fygzbm` int(11) DEFAULT NULL,
  `je_one` decimal(38,2) DEFAULT NULL,
  `zs_one` int(11) DEFAULT NULL,
  `je_two` decimal(38,2) DEFAULT NULL,
  `zs_two` int(11) DEFAULT NULL,
  `je_three` decimal(38,2) DEFAULT NULL,
  `je_four` decimal(38,2) DEFAULT NULL,
  `je_five` decimal(38,2) DEFAULT NULL,
  `se` decimal(38,2) DEFAULT NULL,
  `bhsje` decimal(38,2) DEFAULT NULL,
  `yjkm` text,
  `ejkm` text,
  `sjkm` text,
  `sjkmsjid` varchar(999) DEFAULT NULL,
  `se1` decimal(38,2) DEFAULT NULL,
  `se2` decimal(38,2) DEFAULT NULL,
  `se3` decimal(38,2) DEFAULT NULL,
  `kkje` decimal(38,2) DEFAULT NULL,
  `sfyc` int(11) DEFAULT NULL,
  `fylx` text,
  `cbje` decimal(38,2) DEFAULT NULL,
  `khmc` text,
  `sjmc` text,
  `gwtj` int(11) DEFAULT NULL,
  `sjmctj` varchar(999) DEFAULT NULL,
  `sjbttj` int(11) DEFAULT NULL,
  `httiaojian` varchar(999) DEFAULT NULL,
  `frbxlx` int(11) DEFAULT NULL,
  `htkhbttj` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=76560 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_256
-- @at 2026-11-27 16:22:25
-- @cmt bz 备注
-- @cmt fjsc 附件上传
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt khh 开户行
-- @cmt lcbm 流程编码
-- @cmt requestId 流程请求ID
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
CREATE TABLE `formtable_main_256` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbm` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `shenqriq` char(10) DEFAULT NULL,
  `sfyykhdcxy` int(11) DEFAULT NULL,
  `sfhxg` int(11) DEFAULT NULL,
  `htbh` varchar(1000) DEFAULT NULL,
  `pflxkdx` text,
  `pfsy` text,
  `pfnr` text,
  `pfjehjy` decimal(15,2) DEFAULT NULL,
  `zfdxhm` varchar(999) DEFAULT NULL,
  `khh` varchar(999) DEFAULT NULL,
  `yhzh` varchar(999) DEFAULT NULL,
  `dkje` decimal(15,2) DEFAULT NULL,
  `bz` varchar(999) DEFAULT NULL,
  `fjsc` text,
  `xgywy` int(11) DEFAULT NULL,
  `xgywbm` int(11) DEFAULT NULL,
  `sfxypf` int(11) DEFAULT NULL,
  `sfxyzqh` int(11) DEFAULT NULL,
  `sgsmcpyy` longtext,
  `sgsmjsyy` longtext,
  `sczqh` text,
  `sjpfqk` text,
  `zrbm` text,
  `scclpz` text,
  `sgsmxmglb` longtext,
  `sgsmlyzyb` longtext,
  `sgsmfwzxz` longtext,
  `sgsmptsyb` longtext,
  `sgsmyyb` longtext,
  `sgsmwlsyb` longtext,
  `dykg` int(11) DEFAULT NULL,
  `ywdykg` int(11) DEFAULT NULL,
  `hqkgbm` int(11) DEFAULT NULL,
  `khmc` text,
  PRIMARY KEY (`id`),
  KEY `ft_main_256_req_index` (`requestId`)
) ENGINE=InnoDB AUTO_INCREMENT=94 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_258
-- @at 2026-11-27 16:22:30
-- @cmt fjsc 附件上传
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt khmc 客户名称
-- @cmt lcbh 流程编号
-- @cmt lxdz 类型地址
-- @cmt requestId 流程请求ID
-- @cmt sjje 时间金额
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqsj 申请时间
-- @cmt xmgzbm 项目跟踪编码
-- @cmt xmmc 项目名称
CREATE TABLE `formtable_main_258` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqsj` char(10) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `xmmc` varchar(999) DEFAULT NULL,
  `gllc` text,
  `khmc` varchar(999) DEFAULT NULL,
  `qwdsj` char(10) DEFAULT NULL,
  `glsbsqd` text,
  `glht` text,
  `xmgzbm` int(11) DEFAULT NULL,
  `ygje` decimal(38,2) DEFAULT NULL,
  `cglb` int(11) DEFAULT NULL,
  `sqxz` int(11) DEFAULT NULL,
  `cgxq` varchar(999) DEFAULT NULL,
  `qwsxxg` varchar(999) DEFAULT NULL,
  `fjsc` text,
  `djrlxfs` varchar(999) DEFAULT NULL,
  `lxdz` varchar(999) DEFAULT NULL,
  `qsx` varchar(999) DEFAULT NULL,
  `erpckdh` varchar(999) DEFAULT NULL,
  `sjje` decimal(38,2) DEFAULT NULL,
  `sbsqdzsftx` int(11) DEFAULT NULL,
  `gllxsqdtz` text,
  `gyslxfs` varchar(300) DEFAULT NULL,
  `cgfj` text,
  `zpcgry` int(11) DEFAULT NULL,
  `ftg` varchar(100) DEFAULT NULL,
  `xmzt` int(11) DEFAULT NULL,
  `cght` text,
  `sjwcsj` char(10) DEFAULT NULL,
  `zpz` int(11) DEFAULT NULL,
  `ywry` int(11) DEFAULT NULL,
  `xcglb` text,
  `cgxm` varchar(100) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `csrfrtj` int(11) DEFAULT NULL,
  `khmcylk` text,
  `htbh` text,
  PRIMARY KEY (`id`),
  KEY `ft_main_258_req_index` (`requestId`)
) ENGINE=InnoDB AUTO_INCREMENT=1575 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_258_dt1
-- @at 2026-11-27 16:19:08
-- @cmt bz 备注
-- @cmt dw 数仓
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
-- @cmt sjje 时间金额
-- @cmt xmmc 项目名称
CREATE TABLE `formtable_main_258_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `xqmx` varchar(999) DEFAULT NULL,
  `sqsl` int(11) DEFAULT NULL,
  `bz` varchar(999) DEFAULT NULL,
  `dw` varchar(999) DEFAULT NULL,
  `cglb` text,
  `sjje` decimal(38,2) DEFAULT NULL,
  `cgxq` varchar(999) DEFAULT NULL,
  `xmmc` varchar(100) DEFAULT NULL,
  `gzbm` int(11) DEFAULT NULL,
  `ygje` decimal(38,2) DEFAULT NULL,
  `sfysk` int(11) DEFAULT NULL,
  `cglbpd` int(11) DEFAULT NULL,
  `frsfzc` int(11) DEFAULT NULL,
  `frsfzcbtzx` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `formtable_main_258_dt1_mId` (`mainid`)
) ENGINE=InnoDB AUTO_INCREMENT=1601 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_265
-- @at 2026-11-27 16:19:12
-- @cmt bz 备注
-- @cmt hkje 回款金额
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt jfmc 甲方名称
-- @cmt lcbh 流程编号
-- @cmt ptzhid 平台账号ID
-- @cmt requestId 流程请求ID
CREATE TABLE `formtable_main_265` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `hkrq` char(10) DEFAULT NULL,
  `hklx` int(11) DEFAULT NULL,
  `hkje` decimal(15,2) DEFAULT NULL,
  `fkfjfmc` varchar(999) DEFAULT NULL,
  `fkzhlx` int(11) DEFAULT NULL,
  `htbh` text,
  `ptzhid` varchar(999) DEFAULT NULL,
  `bz` text,
  `jfmc` text,
  `xmjd` int(11) DEFAULT NULL,
  `hkjtzd` text,
  `sfhk` int(11) DEFAULT NULL,
  `xmjdfx` text,
  `xsry` int(11) DEFAULT NULL,
  `hktj` decimal(38,2) DEFAULT NULL,
  `bt` text,
  `cjrbm` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ft_main_265_req_index` (`requestId`)
) ENGINE=InnoDB AUTO_INCREMENT=655 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_268
-- @at 2026-11-27 16:22:33
-- @cmt dsfcz 第三方厂商
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt jfmc 甲方名称
-- @cmt jqmc 景区名称
-- @cmt khjl 客户经理
-- @cmt mt 美团
-- @cmt mx5 明细5
-- @cmt requestId 流程请求ID
-- @cmt scfj 上传附件
-- @cmt sfbzhxm 是否标准化项目
-- @cmt sqr 申请人
-- @cmt sqsj 申请时间
-- @cmt xmgzbm 项目跟踪编码
-- @cmt xmlx 项目类型
-- @cmt xmmc 项目名称
CREATE TABLE `formtable_main_268` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `ysbh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqsj` char(10) DEFAULT NULL,
  `glxslxjjd` int(11) DEFAULT NULL,
  `xmmc` varchar(999) DEFAULT NULL,
  `htbh` text,
  `jqmc` varchar(999) DEFAULT NULL,
  `sfbzhxm` int(11) DEFAULT NULL,
  `khjl` int(11) DEFAULT NULL,
  `ywlxxz` int(11) DEFAULT NULL,
  `xmgzbm` int(11) DEFAULT NULL,
  `dqxmqs` int(11) DEFAULT NULL,
  `xmbh` varchar(999) DEFAULT NULL,
  `scfj` text,
  `cyyssj` char(10) DEFAULT NULL,
  `zyyssj` char(10) DEFAULT NULL,
  `cyqzjsc` text,
  `zyqzjsc` text,
  `glxslxjjd1` text,
  `dsfcz` int(11) DEFAULT NULL,
  `mt` int(11) DEFAULT NULL,
  `mblx` int(11) DEFAULT NULL,
  `jfmc` varchar(999) DEFAULT NULL,
  `xmlx` int(11) DEFAULT NULL,
  `sbsqlc` text,
  `bjsplc` text,
  `ysbgfj` text,
  `mx1` varchar(999) DEFAULT NULL,
  `mx2` varchar(999) DEFAULT NULL,
  `mx3` varchar(999) DEFAULT NULL,
  `mx4` varchar(999) DEFAULT NULL,
  `zbysbggzj` text,
  `lxxz` int(11) DEFAULT NULL,
  `xmlxpt` int(11) DEFAULT NULL,
  `mx5` varchar(999) DEFAULT NULL,
  `mx6` varchar(999) DEFAULT NULL,
  `mx7` varchar(999) DEFAULT NULL,
  `ftg` varchar(999) DEFAULT NULL,
  `htje` decimal(38,2) DEFAULT NULL,
  `dzrt` decimal(38,2) DEFAULT NULL,
  `sj` decimal(38,2) DEFAULT NULL,
  `zkj` decimal(38,2) DEFAULT NULL,
  `sm` text,
  `wbcb` decimal(38,2) DEFAULT NULL,
  `wbsj` decimal(38,2) DEFAULT NULL,
  `wbzkj` decimal(38,2) DEFAULT NULL,
  `yscb` decimal(38,2) DEFAULT NULL,
  `yssj` decimal(38,2) DEFAULT NULL,
  `yszkj` decimal(38,2) DEFAULT NULL,
  `mxb8` varchar(999) DEFAULT NULL,
  `dzrj` varchar(999) DEFAULT NULL,
  `zhfy` varchar(999) DEFAULT NULL,
  `sbsqdlcbh` varchar(999) DEFAULT NULL,
  `zhbxcb` decimal(38,2) DEFAULT NULL,
  `zhbxsj` decimal(38,2) DEFAULT NULL,
  `zhbxzkj` decimal(38,2) DEFAULT NULL,
  `sfhk` int(11) DEFAULT NULL,
  `hkje` decimal(38,2) DEFAULT NULL,
  `whkyy` text,
  `hjjssj` char(10) DEFAULT NULL,
  `kddh` varchar(999) DEFAULT NULL,
  `ckhsfqs` int(11) DEFAULT NULL,
  `ckhsfyqs10ggzr` int(11) DEFAULT NULL,
  `sfhkcw` int(11) DEFAULT NULL,
  `hkjecw` decimal(38,2) DEFAULT NULL,
  `cwbz` text,
  PRIMARY KEY (`id`),
  KEY `ft_main_268_req_index` (`requestId`)
) ENGINE=InnoDB AUTO_INCREMENT=460 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_268_dt2
-- @at 2026-11-27 16:19:17
-- @cmt cpmc 产品名称
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
CREATE TABLE `formtable_main_268_dt2` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `cpmc` varchar(999) DEFAULT NULL,
  `cbj` varchar(999) DEFAULT NULL,
  `cgnx` varchar(999) DEFAULT NULL,
  `xsj` decimal(38,2) DEFAULT NULL,
  `zkj` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `formtable_main_268_dt2_mId` (`mainid`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_268_dt3
-- @at 2026-11-27 16:19:20
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
-- @cmt mc 名称
-- @cmt sl 数量
CREATE TABLE `formtable_main_268_dt3` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `mc` varchar(999) DEFAULT NULL,
  `gg` varchar(999) DEFAULT NULL,
  `sl` int(11) DEFAULT NULL,
  `cbj` varchar(999) DEFAULT NULL,
  `xsj` decimal(38,2) DEFAULT NULL,
  `zkj` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `formtable_main_268_dt3_mId` (`mainid`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_268_dt4
-- @at 2026-11-27 16:19:24
-- @cmt cpfl 产品分类
-- @cmt cpmc 产品名称
-- @cmt cpxh 产品型号
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
-- @cmt sj 时间
-- @cmt sl 数量
CREATE TABLE `formtable_main_268_dt4` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `cpmc` int(11) DEFAULT NULL,
  `cpxh` varchar(999) DEFAULT NULL,
  `sl` int(11) DEFAULT NULL,
  `sj` decimal(38,2) DEFAULT NULL,
  `cpfl` text,
  `zkj` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `formtable_main_268_dt4_mId` (`mainid`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_268_dt5
-- @at 2026-11-27 16:19:27
-- @cmt cpfl 产品分类
-- @cmt cpmc 产品名称
-- @cmt cpxh 产品型号
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
-- @cmt sj 时间
-- @cmt sl 数量
CREATE TABLE `formtable_main_268_dt5` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `cpxh` varchar(999) DEFAULT NULL,
  `cpfl` varchar(999) DEFAULT NULL,
  `sl` int(11) DEFAULT NULL,
  `jg` decimal(38,2) DEFAULT NULL,
  `sj` decimal(38,2) DEFAULT NULL,
  `cpmc` text,
  PRIMARY KEY (`id`),
  KEY `formtable_main_268_dt5_mId` (`mainid`)
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_274
-- @at 2026-11-27 16:19:33
-- @cmt ddyc 订单异常
-- @cmt hzlx 合作类型
-- @cmt id 主键ID
-- @cmt je 金额
-- @cmt khmc 客户名称
-- @cmt lcbh 流程编号
-- @cmt ptid 平台ID
-- @cmt requestId 流程请求ID
-- @cmt s 类型
-- @cmt tc 提成
CREATE TABLE `formtable_main_274` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `khmc` varchar(999) DEFAULT NULL,
  `ptid` varchar(999) DEFAULT NULL,
  `gslx` int(11) DEFAULT NULL,
  `jq` int(11) DEFAULT NULL,
  `lhs` varchar(999) DEFAULT NULL,
  `jcrczrxm` varchar(999) DEFAULT NULL,
  `khxgtd` int(11) DEFAULT NULL,
  `hzptgnxq` text,
  `hzxspt` varchar(999) DEFAULT NULL,
  `hzxxxt` varchar(999) DEFAULT NULL,
  `sfgmyjsb` varchar(999) DEFAULT NULL,
  `hzlx` int(11) DEFAULT NULL,
  `tc` int(11) DEFAULT NULL,
  `ddyc` int(11) DEFAULT NULL,
  `ssje` decimal(38,2) DEFAULT NULL,
  `zgdmc` varchar(999) DEFAULT NULL,
  `je` decimal(38,2) DEFAULT NULL,
  `lwf` decimal(38,2) DEFAULT NULL,
  `yhjz` int(11) DEFAULT NULL,
  `zc` varchar(999) DEFAULT NULL,
  `sjh` varchar(999) DEFAULT NULL,
  `s` int(11) DEFAULT NULL,
  `s1` int(11) DEFAULT NULL,
  `khcgjl` int(11) DEFAULT NULL,
  `sfqrjs` int(11) DEFAULT NULL,
  `zc1` int(11) DEFAULT NULL,
  `hznr` text,
  `bm` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ft_main_274_req_index` (`requestId`)
) ENGINE=InnoDB AUTO_INCREMENT=532 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_277
-- @at 2026-11-27 16:19:38
-- @cmt dsfcz 第三方厂商
-- @cmt fjsc 附件上传
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt jqmc 景区名称
-- @cmt khjl 客户经理
-- @cmt lcbh 流程编号
-- @cmt mt 美团
-- @cmt qslx 季度类型
-- @cmt qssj 季度时间
-- @cmt requestId 流程请求ID
-- @cmt scfj 上传附件
-- @cmt sfbzhxm 是否标准化项目
-- @cmt sqr 申请人
-- @cmt sqsj 申请时间
-- @cmt xmmc 项目名称
CREATE TABLE `formtable_main_277` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqsj` char(10) DEFAULT NULL,
  `glxslxjjd` text,
  `xmmc` varchar(999) DEFAULT NULL,
  `htbh` text,
  `jqmc` varchar(999) DEFAULT NULL,
  `sfbzhxm` int(11) DEFAULT NULL,
  `khjl` int(11) DEFAULT NULL,
  `ywlxxz` int(11) DEFAULT NULL,
  `qssj` char(10) DEFAULT NULL,
  `scfj` text,
  `qslx` text,
  `dsfcz` int(11) DEFAULT NULL,
  `mt` int(11) DEFAULT NULL,
  `syhbgqssj` char(10) DEFAULT NULL,
  `syhbgqzjsc` text,
  `fjsc` text,
  PRIMARY KEY (`id`),
  KEY `ft_main_277_req_index` (`requestId`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_287
-- @at 2026-11-27 16:22:37
-- @cmt bz 备注
-- @cmt fj 附件
-- @cmt htbh 合同编号
-- @cmt htlx 合同类型
-- @cmt htmc 合同名称
-- @cmt id 主键ID
-- @cmt lcbh 流程编号
-- @cmt lxr 联系人
-- @cmt qsqr 季度二维码
-- @cmt qyrq 区域日期
-- @cmt requestId 流程请求ID
-- @cmt sjhm 手机号码
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
CREATE TABLE `formtable_main_287` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `htmc` varchar(999) DEFAULT NULL,
  `htbh` varchar(999) DEFAULT NULL,
  `htlx` int(11) DEFAULT NULL,
  `dfmc` varchar(999) DEFAULT NULL,
  `htbdje` decimal(38,2) DEFAULT NULL,
  `lxr` varchar(999) DEFAULT NULL,
  `sjhm` varchar(999) DEFAULT NULL,
  `fwsfxg` int(11) DEFAULT NULL,
  `xgyjjs` varchar(999) DEFAULT NULL,
  `sfxyceosh` int(11) DEFAULT NULL,
  `fj` text,
  `sfxyceosh2` int(11) DEFAULT NULL,
  `sfxyceosh3` int(11) DEFAULT NULL,
  `gzqr` int(11) DEFAULT NULL,
  `qsqr` int(11) DEFAULT NULL,
  `bz` text,
  `glqsplc` int(11) DEFAULT NULL,
  `fwfjsc` text,
  `gldlc` text,
  `sfdzqy` int(11) DEFAULT NULL,
  `sqbmxlk` int(11) DEFAULT NULL,
  `sfshyj` int(11) DEFAULT NULL,
  `sfycgd` int(11) DEFAULT NULL,
  `ycgdyy` int(11) DEFAULT NULL,
  `qycgdyysm` text,
  `sfshgzj` int(11) DEFAULT NULL,
  `zdxs` int(11) DEFAULT NULL,
  `xmxx` varchar(266) DEFAULT NULL,
  `gzfs` int(11) DEFAULT NULL,
  `htgztz` int(11) DEFAULT NULL,
  `qyrq` char(10) DEFAULT NULL,
  `gltsgdlc` text,
  `sfxygz` int(11) DEFAULT NULL,
  `yygs` int(11) DEFAULT NULL,
  `qzcyf` int(11) DEFAULT NULL,
  `ygzhtfj` text,
  `sfzbht` int(11) DEFAULT NULL,
  `qfzwz` int(11) DEFAULT NULL,
  `sfsdxzgzq` int(11) DEFAULT NULL,
  `sdgzymlj` varchar(999) DEFAULT NULL,
  `bmtj` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ft_main_287_req_index` (`requestId`)
) ENGINE=InnoDB AUTO_INCREMENT=3416 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_362
-- @at 2026-11-27 16:22:41
-- @cmt fj 附件
-- @cmt id 主键ID
-- @cmt lcbh 流程编号
-- @cmt requestId 流程请求ID
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqsj 申请时间
-- @cmt yjsj 业绩时间
CREATE TABLE `formtable_main_362` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(100) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqsj` char(10) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `yywjlx` int(11) DEFAULT NULL,
  `ckjey` decimal(38,2) DEFAULT NULL,
  `xmhtbhlcgl` text,
  `xmhtmc` varchar(100) DEFAULT NULL,
  `jyhzyz` int(11) DEFAULT NULL,
  `sfdzqy` int(11) DEFAULT NULL,
  `yysy` text,
  `fj` text,
  `gzqr` int(11) DEFAULT NULL,
  `yjsj` char(10) DEFAULT NULL,
  `kddh` varchar(100) DEFAULT NULL,
  `hjsmj` text,
  `qspz` text,
  `jyhzyzfx` text,
  `ckzje` decimal(38,2) DEFAULT NULL,
  `shenqr` int(11) DEFAULT NULL,
  `ygzhtfj` text,
  `qyrbm` int(11) DEFAULT NULL,
  `sfjfyj` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ft_main_362_req_index` (`requestId`)
) ENGINE=InnoDB AUTO_INCREMENT=531 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_362_dt1
-- @at 2026-11-27 16:22:45
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
CREATE TABLE `formtable_main_362_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `ckjd` int(11) DEFAULT NULL,
  `yywjlx` int(11) DEFAULT NULL,
  `ckje` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `formtable_main_362_dt1_mId` (`mainid`)
) ENGINE=InnoDB AUTO_INCREMENT=594 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_37
-- @at 2026-11-27 16:19:42
-- @cmt bz 备注
-- @cmt fj 附件
-- @cmt htje 合同金额
-- @cmt id 主键ID
-- @cmt lcbh 流程编号
-- @cmt requestId 流程请求ID
-- @cmt sqrq 申请日期
CREATE TABLE `formtable_main_37` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `jbr` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `jbrbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `yywjmc` varchar(999) DEFAULT NULL,
  `wjfs` int(11) DEFAULT NULL,
  `htlb` int(11) DEFAULT NULL,
  `jyhzyz` int(11) DEFAULT NULL,
  `bz` varchar(999) DEFAULT NULL,
  `fj` text,
  `lcgl` text,
  `sfygz` int(11) DEFAULT NULL,
  `sfwcgyy` int(11) DEFAULT NULL,
  `htje` decimal(15,2) DEFAULT NULL,
  `cglx` int(11) DEFAULT NULL,
  `sfhxjbqd` int(11) DEFAULT NULL,
  `mybjqddyysm` varchar(999) DEFAULT NULL,
  `dhzd` text,
  `sfdzqy` int(11) DEFAULT NULL,
  `jyhzyzdx` text,
  `sfdwhj` int(11) DEFAULT NULL,
  `yygs` int(11) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `htbh` text,
  `hkbl` varchar(100) DEFAULT NULL,
  `cgbttj` int(11) DEFAULT NULL,
  `bm` int(11) DEFAULT NULL,
  `lxr` varchar(100) DEFAULT NULL,
  `dfmc` varchar(100) DEFAULT NULL,
  `qzcyf` int(11) DEFAULT NULL,
  `sjh` varchar(20) DEFAULT NULL,
  `ygzfj` text,
  `qfzwz` int(11) DEFAULT NULL,
  `sfsdxzgzq` int(11) DEFAULT NULL,
  `sdgzymlj` varchar(999) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7295 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_379
-- @at 2026-11-27 16:22:48
-- @cmt fjsc 附件上传
-- @cmt gw 岗位
-- @cmt id 主键ID
-- @cmt jblx 级别类型
-- @cmt jsrq 结束日期
-- @cmt ksrq 开始日期
-- @cmt lcbh 流程编号
-- @cmt q 季度
-- @cmt requestId 流程请求ID
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqrq 申请日期
CREATE TABLE `formtable_main_379` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `sffdjjr` int(11) DEFAULT NULL,
  `ksrq` char(10) DEFAULT NULL,
  `kssj` char(5) DEFAULT NULL,
  `jsrq` char(10) DEFAULT NULL,
  `jssj` char(5) DEFAULT NULL,
  `jbsc` decimal(38,1) DEFAULT NULL,
  `jbts` decimal(38,4) DEFAULT NULL,
  `ycjxxsc` decimal(38,1) DEFAULT NULL,
  `sjjbsc` decimal(38,1) DEFAULT NULL,
  `jbsy` varchar(999) DEFAULT NULL,
  `fjsc` text,
  `q` text,
  `gw` int(11) DEFAULT NULL,
  `jblx` int(11) DEFAULT NULL,
  `dkxbsj` char(5) DEFAULT NULL,
  `sjcz` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ft_main_379_req_index` (`requestId`)
) ENGINE=InnoDB AUTO_INCREMENT=8002 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_38
-- @at 2026-11-27 16:22:53
-- @cmt htbh 合同编号
-- @cmt id 主键ID
-- @cmt jqmc 景区名称
-- @cmt jsrq 结束日期
-- @cmt khmc 客户名称
-- @cmt lcbh 流程编号
-- @cmt lcmb 流程模板
-- @cmt requestId 流程请求ID
-- @cmt scfj 上传附件
-- @cmt sjbm 时间部门
-- @cmt sjmc 时间名称
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt xmlx 项目类型
CREATE TABLE `formtable_main_38` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `wcrq` char(10) DEFAULT NULL,
  `kssj` char(5) DEFAULT NULL,
  `jsrq` char(10) DEFAULT NULL,
  `jssj` char(5) DEFAULT NULL,
  `wcsy` varchar(999) DEFAULT NULL,
  `scfj` text,
  `wcsc` decimal(38,2) DEFAULT NULL,
  `wcts` decimal(38,4) DEFAULT NULL,
  `htbh` text,
  `xmfzd` int(11) DEFAULT NULL,
  `sslx` int(11) DEFAULT NULL,
  `jqmc` varchar(999) DEFAULT NULL,
  `lcmb` int(11) DEFAULT NULL,
  `xmlx` int(11) DEFAULT NULL,
  `sglx` int(11) DEFAULT NULL,
  `ssjdhf` text,
  `smshwtdl` text,
  `smshwtxl` text,
  `sfxgb` int(11) DEFAULT NULL,
  `sjbm` int(11) DEFAULT NULL,
  `glgdslspd` int(11) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `wclx` int(11) DEFAULT NULL,
  `sjmc` text,
  `khmc` text,
  `tsjxz` int(11) DEFAULT NULL,
  `thr` int(11) DEFAULT NULL,
  `zt` varchar(100) DEFAULT '',
  `cfd` int(11) DEFAULT NULL,
  `mdd` int(11) DEFAULT NULL,
  `frwclx` int(11) DEFAULT NULL,
  `sfys` int(11) DEFAULT NULL,
  `khbtxz` int(11) DEFAULT NULL,
  `sftc` int(11) DEFAULT NULL,
  `htbtxz` int(11) DEFAULT NULL,
  `sfscdd` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否上传滴滴商旅',
  `sfcstczsfy` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5798 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_387
-- @at 2026-11-27 16:22:57
-- @cmt changetype 变更类型
-- @cmt id 主键ID
-- @cmt lcbh 流程编号
-- @cmt requestId 流程请求ID
-- @cmt resourceId 资源ID
CREATE TABLE `formtable_main_387` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `resourceId` int(11) DEFAULT NULL,
  `changerequestid` int(11) DEFAULT NULL,
  `changetype` int(11) DEFAULT NULL,
  `lcbh` varchar(100) DEFAULT NULL,
  `bgxztj` decimal(38,2) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_formtable_main_387` (`resourceId`)
) ENGINE=InnoDB AUTO_INCREMENT=435 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_387_dt1
-- @at 2026-11-27 16:23:01
-- @cmt detail_changeduration 明细变更时长
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
CREATE TABLE `formtable_main_387_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `detail_attendancefromDate` char(10) DEFAULT NULL,
  `detail_attendancefromTime` char(8) DEFAULT NULL,
  `detail_attendancetoDate` char(10) DEFAULT NULL,
  `detail_attendancetoTime` char(8) DEFAULT NULL,
  `detail_attendanceduration` decimal(15,2) DEFAULT NULL,
  `detail_changefromDate` char(10) DEFAULT NULL,
  `detail_changefromTime` char(8) DEFAULT NULL,
  `detail_changetoDate` char(10) DEFAULT NULL,
  `detail_changetoTime` char(8) DEFAULT NULL,
  `detail_changeduration` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=450 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_42
-- @at 2026-11-27 16:23:05
-- @cmt fjsc 附件上传
-- @cmt id 主键ID
-- @cmt jsrq 结束日期
-- @cmt ksrq 开始日期
-- @cmt lcbh 流程编号
-- @cmt lcmb 流程模板
-- @cmt q 季度
-- @cmt requestId 流程请求ID
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt sqrq 申请日期
CREATE TABLE `formtable_main_42` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `sffdjjr` int(11) DEFAULT NULL,
  `ksrq` char(10) DEFAULT NULL,
  `kssj` char(5) DEFAULT NULL,
  `jsrq` char(10) DEFAULT NULL,
  `jssj` char(5) DEFAULT NULL,
  `jbsc` decimal(38,1) DEFAULT NULL,
  `jbts` decimal(38,4) DEFAULT NULL,
  `ycjxxsc` decimal(38,1) DEFAULT NULL,
  `sjjbsc` decimal(38,1) DEFAULT NULL,
  `jbsy` varchar(999) DEFAULT NULL,
  `fjsc` text,
  `zsfs` int(11) DEFAULT NULL,
  `q` text,
  `lcmb` int(11) DEFAULT NULL,
  `zcbm` varchar(100) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `dkxbsj` char(5) DEFAULT NULL,
  `sjcz` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=30354 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_48
-- @at 2026-11-27 16:19:46
-- @cmt csrq 出生日期
-- @cmt gh 工号
-- @cmt id 主键ID
-- @cmt lcbh 流程编号
-- @cmt requestId 流程请求ID
-- @cmt sqr 申请人
-- @cmt sqrbm 申请人部门
-- @cmt sqrq 申请日期
-- @cmt xb 性别
-- @cmt zjsj 增加时间
CREATE TABLE `formtable_main_48` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `sqrbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `gh` int(11) DEFAULT NULL,
  `rzsj` char(10) DEFAULT NULL,
  `syqjzrq` char(10) DEFAULT NULL,
  `zw` int(11) DEFAULT NULL,
  `zj` varchar(999) DEFAULT NULL,
  `csrq` char(10) DEFAULT NULL,
  `grzpzj` text,
  `zphwdf` int(11) DEFAULT NULL,
  `zpcqdf` int(11) DEFAULT NULL,
  `zpyjdf` int(11) DEFAULT NULL,
  `zjsj` int(11) DEFAULT NULL,
  `zgxl` int(11) DEFAULT NULL,
  `xb` int(11) DEFAULT NULL,
  `zzpjyj` text,
  `zzjy` text,
  `pjhwdfmf35` int(11) DEFAULT NULL,
  `pjcqdfmf15` int(11) DEFAULT NULL,
  `pjyjdfmf50` int(11) DEFAULT NULL,
  `sftqzz` int(11) DEFAULT NULL,
  `zzrq` char(10) DEFAULT NULL,
  `rlzybyj` text,
  `hwdfmf35` int(11) DEFAULT NULL,
  `cqdfmf15` int(11) DEFAULT NULL,
  `yjdf` int(11) DEFAULT NULL,
  `sftqzz1` int(11) DEFAULT NULL,
  `zzsj` char(10) DEFAULT NULL,
  `syqnjxpjf` decimal(38,2) DEFAULT NULL,
  `syqncqf` decimal(38,2) DEFAULT NULL,
  `xygpxkhpjf` decimal(38,2) DEFAULT NULL,
  `zzpj` text,
  `xs` int(11) DEFAULT NULL,
  `zz` char(10) DEFAULT NULL,
  `syqzygzjwcqk` text,
  `grgzsxtshgszc` text,
  `gzxtsxgsxdzc` text,
  `dgszdgfgzlcdyhjy` text,
  `pj` int(11) DEFAULT NULL,
  `zwpjnr` text,
  `gzyyjnl` varchar(999) DEFAULT NULL,
  `tsfx` varchar(999) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=615 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_53
-- @at 2026-11-27 16:23:10
-- @cmt fj 附件
-- @cmt gj 国家
-- @cmt gw 岗位
-- @cmt id 主键ID
-- @cmt lcbm 流程编码
-- @cmt lcmb 流程模板
-- @cmt lzrq 离职日期
-- @cmt requestId 流程请求ID
-- @cmt rzrq 入职日期
-- @cmt sqr 申请人
-- @cmt sqrbm 申请人部门
-- @cmt sqrq 申请日期
CREATE TABLE `formtable_main_53` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbm` varchar(999) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqrbm` int(11) DEFAULT NULL,
  `sqrq` char(10) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  `gj` varchar(999) DEFAULT NULL,
  `rzrq` char(10) DEFAULT NULL,
  `nlzrq` char(10) DEFAULT NULL,
  `lzlx` int(11) DEFAULT NULL,
  `lzyy` text,
  `lzhlxdh` varchar(999) DEFAULT NULL,
  `lzhlldz` varchar(999) DEFAULT NULL,
  `lzhxxldz` varchar(999) DEFAULT NULL,
  `fj` text,
  `lzrq` char(10) DEFAULT NULL,
  `qrlzlx` int(11) DEFAULT NULL,
  `lcmb` int(11) DEFAULT NULL,
  `fwzhcrmzh` int(11) DEFAULT NULL,
  `wtzsy` varchar(999) DEFAULT NULL,
  `qsrqrfwzh` int(11) DEFAULT NULL,
  `gr12301ccqyyx` int(11) DEFAULT NULL,
  `sfycz` int(11) DEFAULT NULL,
  `zh` int(11) DEFAULT NULL,
  `gz` char(10) DEFAULT NULL,
  `dndgdzc` text,
  `qgdzc` text,
  `yxqr1` int(11) DEFAULT NULL,
  `yxqr2` int(11) DEFAULT NULL,
  `zhqr` int(11) DEFAULT NULL,
  `gzqr` int(11) DEFAULT NULL,
  `dnqr` int(11) DEFAULT NULL,
  `qgdzcqr` int(11) DEFAULT NULL,
  `bgypqr` int(11) DEFAULT NULL,
  `bgypbgyc` varchar(99) DEFAULT NULL,
  `sbybywxgjj` varchar(999) DEFAULT NULL,
  `gsoaddzhwxqqqmjzwznmp` text,
  `gsoazhqr` int(11) DEFAULT NULL,
  `sfjysbsfgh` text,
  `jysbqr` int(11) DEFAULT NULL,
  `jqcwkx` varchar(999) DEFAULT NULL,
  `jqcwkxqr` int(11) DEFAULT NULL,
  `oaspqx` int(11) DEFAULT NULL,
  `oaspqxqr` int(11) DEFAULT NULL,
  `xxqx` varchar(999) DEFAULT NULL,
  `lxyjqr` int(11) DEFAULT NULL,
  `zhxx` varchar(999) DEFAULT NULL,
  `erpzh` int(11) DEFAULT NULL,
  `erpqxqr` int(11) DEFAULT NULL,
  `crmkhjj` varchar(100) DEFAULT NULL,
  `crmsjjj` varchar(100) DEFAULT NULL,
  `crmpdzd` int(11) DEFAULT NULL,
  `khjjqr` int(11) DEFAULT NULL,
  `sjjjqr` int(11) DEFAULT NULL,
  `khjjfj` text,
  `sjjjfj` text,
  `erpzhwtzyy` varchar(999) DEFAULT NULL,
  `wtzyy` varchar(999) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=907 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_93
-- @at 2026-11-27 16:19:50
-- @cmt fromDate 开始日期
-- @cmt id 主键ID
-- @cmt lcbm 流程编码
-- @cmt requestId 流程请求ID
-- @cmt resourceId 资源ID
-- @cmt sqbm 申请部门
-- @cmt toDate 结束日期
CREATE TABLE `formtable_main_93` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `resourceId` int(11) DEFAULT NULL,
  `fromDate` char(10) DEFAULT NULL,
  `toDate` char(10) DEFAULT NULL,
  `lcbm` varchar(999) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `gw` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_formtable_main_93` (`resourceId`)
) ENGINE=InnoDB AUTO_INCREMENT=20285 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_93_dt1
-- @at 2026-11-27 16:19:54
-- @cmt detail_atteStatus 明细考勤状态
-- @cmt detail_scheduletime 明细排班时间
-- @cmt detail_signdate 明细签到日期
-- @cmt detail_signtime 明细签到时间
-- @cmt detail_signtype 明细签到类型
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
CREATE TABLE `formtable_main_93_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `detail_signdate` char(10) DEFAULT NULL,
  `detail_scheduletime` char(100) DEFAULT NULL,
  `detail_atteStatus` char(100) DEFAULT NULL,
  `detail_signtype` char(10) DEFAULT NULL,
  `detail_signtime` char(8) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_formtable_main_93_dt1` (`detail_signdate`)
) ENGINE=InnoDB AUTO_INCREMENT=24275 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_94
-- @at 2026-11-27 16:23:12
-- @cmt id 主键ID
-- @cmt lcbm 流程编码
-- @cmt requestId 流程请求ID
-- @cmt resourceId 资源ID
-- @cmt sqbm 申请部门
CREATE TABLE `formtable_main_94` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `resourceId` int(11) DEFAULT NULL,
  `leaverequestid` int(11) DEFAULT NULL,
  `lcbm` varchar(999) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_formtable_main_94` (`resourceId`)
) ENGINE=InnoDB AUTO_INCREMENT=171 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:formtable_main_94_dt1
-- @at 2026-11-27 16:23:16
-- @cmt detail_duration 明细时长
-- @cmt detail_fromDate 明细来源日期
-- @cmt detail_fromTime 明细来源时间
-- @cmt detail_newLeaveType 明细请假类型
-- @cmt detail_toDate 明细目标日期
-- @cmt detail_toTime 明细目标时间
-- @cmt id 主键ID
-- @cmt mainid 主表记录ID
CREATE TABLE `formtable_main_94_dt1` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mainid` int(11) DEFAULT NULL,
  `detail_leavefromDate` char(10) DEFAULT NULL,
  `detail_leavefromTime` char(8) DEFAULT NULL,
  `detail_leavetoDate` char(10) DEFAULT NULL,
  `detail_leavetoTime` char(8) DEFAULT NULL,
  `detail_newLeaveType` int(11) DEFAULT NULL,
  `detail_leaveduration` decimal(15,2) DEFAULT NULL,
  `detail_fromDate` char(10) DEFAULT NULL,
  `detail_fromTime` char(8) DEFAULT NULL,
  `detail_toDate` char(10) DEFAULT NULL,
  `detail_toTime` char(8) DEFAULT NULL,
  `detail_duration` decimal(15,2) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=170 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:hrmcity
-- @at 2026-11-27 16:19:58
-- @cmt CANCELED 是否作废
-- @cmt CITYLATITUDE 城市纬度
-- @cmt CITYLONGITUDE 城市经度
-- @cmt CITYNAME 城市名称
-- @cmt COUNTRYID 国家ID
-- @cmt PROVINCEID 省份ID
-- @cmt uuid UUID
CREATE TABLE `hrmcity` (
  `ID` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `CITYNAME` varchar(480) DEFAULT NULL,
  `CITYLONGITUDE` decimal(8,3) DEFAULT NULL,
  `CITYLATITUDE` decimal(8,3) DEFAULT NULL,
  `PROVINCEID` int(11) DEFAULT NULL,
  `COUNTRYID` int(11) DEFAULT NULL,
  `CANCELED` char(1) DEFAULT NULL,
  `uuid` varchar(50) DEFAULT '0',
  `quicksearch` varchar(1000) DEFAULT NULL,
  `city_name2` varchar(100) DEFAULT NULL,
  `hotel_city` varchar(32) DEFAULT NULL COMMENT '携程酒店城市码',
  `train_city` varchar(32) DEFAULT NULL COMMENT '携程火车城市码',
  `flight_city` varchar(32) DEFAULT NULL COMMENT '携程飞机城市码',
  `hotel_city2` varchar(32) DEFAULT NULL COMMENT '滴滴酒店城市id',
  `train_city2` varchar(32) DEFAULT NULL COMMENT '滴滴火车城市id',
  `flight_city2` varchar(32) DEFAULT NULL COMMENT '滴滴飞机城市id',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB AUTO_INCREMENT=464 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:hrmdepartment
-- @at 2026-11-27 16:20:02
-- @cmt ALLSUPDEPID 全部上级部门ID
-- @cmt BMFGLD 部门分管领导
-- @cmt BMFZR 部门负责人
-- @cmt BUDGETATUOMOVEORDER 预算自动排序
-- @cmt CANCELED 是否作废
-- @cmt COADJUTANT 协办人
-- @cmt DEPARTMENTCODE 部门编码
-- @cmt DEPARTMENTMARK 部门简称
-- @cmt DEPARTMENTNAME 部门名称
-- @cmt ECOLOGY_PINYIN_SEARCH 拼音检索码
-- @cmt JZGLBMFGLD 兼职管理部门分管领导
-- @cmt JZGLBMFZR 兼职管理部门负责人
-- @cmt OUTKEY 外部系统主键
-- @cmt SUBCOMPANYID1 所属分部ID
-- @cmt SUPDEPID 上级部门ID
-- @cmt TLEVEL 层级
-- @cmt ZZJGBMFGLD 组织架构部门分管领导
-- @cmt ZZJGBMFZR 组织架构部门负责人
-- @cmt created 创建时间
-- @cmt creater 创建人
-- @cmt modified 修改时间
-- @cmt modifier 修改人
-- @cmt showOrderOfTree 树形显示顺序
-- @cmt showorder 显示顺序
-- @cmt uuid UUID
CREATE TABLE `hrmdepartment` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `DEPARTMENTMARK` varchar(480) DEFAULT NULL,
  `DEPARTMENTNAME` varchar(1000) DEFAULT NULL,
  `SUBCOMPANYID1` int(11) DEFAULT NULL,
  `SUPDEPID` int(11) DEFAULT NULL,
  `ALLSUPDEPID` text,
  `CANCELED` char(1) DEFAULT NULL,
  `DEPARTMENTCODE` varchar(800) DEFAULT NULL,
  `COADJUTANT` int(11) DEFAULT NULL,
  `ZZJGBMFZR` text,
  `ZZJGBMFGLD` text,
  `JZGLBMFZR` text,
  `JZGLBMFGLD` text,
  `BMFZR` text,
  `BMFGLD` text,
  `OUTKEY` varchar(800) DEFAULT NULL,
  `BUDGETATUOMOVEORDER` int(11) DEFAULT NULL,
  `ECOLOGY_PINYIN_SEARCH` varchar(1000) DEFAULT NULL,
  `TLEVEL` int(11) DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `creater` int(11) DEFAULT NULL,
  `modified` datetime DEFAULT NULL,
  `modifier` int(11) DEFAULT NULL,
  `uuid` varchar(50) DEFAULT '0',
  `showorder` double DEFAULT NULL,
  `showOrderOfTree` int(11) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `HRMDEPARTMENT_SUB_IN` (`SUBCOMPANYID1`),
  KEY `IX_HRMDEPARTMENT_SID` (`SUPDEPID`),
  KEY `idx_hrmdepartment_cd` (`OUTKEY`),
  KEY `idx_hrmdepartment_uuid` (`uuid`)
) ENGINE=InnoDB AUTO_INCREMENT=339 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:hrmdepartmentdefined
-- @at 2026-11-27 16:20:06
-- @cmt BMFGLD 部门分管领导
-- @cmt BMFZR 部门负责人
-- @cmt DEPTID crm部门id
-- @cmt JZGLBMFGLD 兼职管理部门分管领导
-- @cmt JZGLBMFZR 兼职管理部门负责人
-- @cmt ZZJGBMFGLD 组织架构部门分管领导
-- @cmt ZZJGBMFZR 组织架构部门负责人
-- @cmt ejbq 二级标签
-- @cmt sjbq 三级标签
-- @cmt yjbq 一级标签
CREATE TABLE `hrmdepartmentdefined` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `DEPTID` int(11) NOT NULL,
  `BMFZR` text,
  `BMFGLD` text,
  `ZZJGBMFZR` text,
  `ZZJGBMFGLD` text,
  `JZGLBMFZR` text,
  `JZGLBMFGLD` text,
  `yjbq` int(11) DEFAULT NULL,
  `ejbq` int(11) DEFAULT NULL,
  `sjbq` int(11) DEFAULT NULL,
  `bmzx` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=616 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:hrmeducationlevel
-- @at 2026-11-27 16:20:11
-- @cmt DESCRIPTION 描述
-- @cmt NAME 名称
-- @cmt uuid UUID
CREATE TABLE `hrmeducationlevel` (
  `ID` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `NAME` varchar(480) DEFAULT NULL,
  `DESCRIPTION` varchar(1000) DEFAULT NULL,
  `uuid` varchar(50) DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:hrmjobtitles
-- @at 2026-11-27 16:20:15
-- @cmt ECOLOGY_PINYIN_SEARCH 拼音检索码
-- @cmt JOBTITLEMARK 岗位简称
-- @cmt JOBTITLENAME 岗位名称
-- @cmt OUTKEY 外部系统主键
-- @cmt canceled 是否作废
-- @cmt created 创建时间
-- @cmt creater 创建人
-- @cmt modified 修改时间
-- @cmt modifier 修改人
-- @cmt uuid UUID
CREATE TABLE `hrmjobtitles` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `JOBTITLEMARK` varchar(480) DEFAULT NULL,
  `JOBTITLENAME` varchar(1000) DEFAULT NULL,
  `JOBTITLEREMARK` text,
  `JOBACTIVITYID` int(11) DEFAULT NULL,
  `JOBDEPARTMENTID` int(11) DEFAULT NULL,
  `JOBRESPONSIBILITY` varchar(1000) DEFAULT NULL,
  `JOBCOMPETENCY` varchar(1000) DEFAULT NULL,
  `JOBDOC` int(11) DEFAULT NULL,
  `JOBTITLECODE` varchar(480) DEFAULT NULL,
  `OUTKEY` varchar(800) DEFAULT NULL,
  `ECOLOGY_PINYIN_SEARCH` varchar(1000) DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `creater` int(11) DEFAULT NULL,
  `modified` datetime DEFAULT NULL,
  `modifier` int(11) DEFAULT NULL,
  `uuid` varchar(50) DEFAULT '0',
  `canceled` char(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_hrmjobtitles_cd` (`OUTKEY`)
) ENGINE=InnoDB AUTO_INCREMENT=459 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:hrmprovince
-- @at 2026-11-27 16:20:19
-- @cmt CANCELED 是否作废
-- @cmt COUNTRYID 国家ID
-- @cmt PROVINCEDESC 省份描述
-- @cmt PROVINCENAME 省份名称
-- @cmt uuid UUID
CREATE TABLE `hrmprovince` (
  `ID` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `PROVINCENAME` varchar(1000) DEFAULT NULL,
  `PROVINCEDESC` varchar(1000) DEFAULT NULL,
  `COUNTRYID` int(11) DEFAULT NULL,
  `CANCELED` char(1) DEFAULT NULL,
  `uuid` varchar(50) DEFAULT '0',
  `quicksearch` varchar(1000) DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB AUTO_INCREMENT=71 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:hrmresource
-- @at 2026-11-27 16:20:23
-- @cmt ACCOUNT 账户
-- @cmt ACCOUNTID1 银行账号
-- @cmt ACCOUNTNAME 账号名
-- @cmt ACCOUNTTYPE 账号类型
-- @cmt ACCUMFUNDACCOUNT 公积金账号
-- @cmt ADBM AD 部门
-- @cmt ADGS AD 公司
-- @cmt ADSJGS AD 上级公司
-- @cmt ASSISTANTDACTYLOGRAM 辅助指纹
-- @cmt ASSISTANTID 助理ID
-- @cmt BANKID1 开户银行ID
-- @cmt BELONGTO 所属主账号
-- @cmt BEMEMBERDATE 入团日期
-- @cmt BEPARTYDATE 入党日期
-- @cmt BIRTHDAY 生日
-- @cmt BIRTHPLACE 出生地
-- @cmt CERTIFICATENUM 身份证号
-- @cmt CLASSIFICATION 密级
-- @cmt COSTCENTERID 成本中心ID
-- @cmt COUNTRYID 国家ID
-- @cmt CREATEDATE 创建日期
-- @cmt CREATERID 创建人ID
-- @cmt DACTYLOGRAM 指纹
-- @cmt DATEFIELD1 自定义日期字段1
-- @cmt DATEFIELD2 自定义日期字段2
-- @cmt DATEFIELD3 自定义日期字段3
-- @cmt DATEFIELD4 自定义日期字段4
-- @cmt DATEFIELD5 自定义日期字段5
-- @cmt DEGREE 学位
-- @cmt DEPARTMENTID 部门ID
-- @cmt DISMISSDATE 离职日期
-- @cmt DSPORDER 显示顺序
-- @cmt ECOLOGY_PINYIN_SEARCH 拼音检索码
-- @cmt EDUCATIONLEVEL 学历
-- @cmt EMAIL 邮箱
-- @cmt ENDDATE 结束日期
-- @cmt EXTPHONE 扩展手机号
-- @cmt FAX 传真
-- @cmt FOLK 民族
-- @cmt HEALTHINFO 健康状况
-- @cmt HEIGHT 高度
-- @cmt HOMEADDRESS 归属地址
-- @cmt ID 主键ID
-- @cmt ISADACCOUNT 是否 AD 账号
-- @cmt ISLABOUUNION 是否工会会员
-- @cmt JOBACTIVITYDESC 职务描述
-- @cmt JOBCALL 职称
-- @cmt JOBLEVEL 职级
-- @cmt JOBTITLE 岗位ID
-- @cmt LASTLOGINDATE 最后登录日期
-- @cmt LASTMODDATE 最后修改日期
-- @cmt LASTMODID 最后修改人ID
-- @cmt LASTNAME 姓名
-- @cmt LLOGINID 登录名
-- @cmt LOCATIONID 办公地点ID
-- @cmt MANAGERID 直属上级ID
-- @cmt MANAGERSTR 上级链路
-- @cmt MARITALSTATUS 婚姻状况
-- @cmt MESSAGERURL 头像地址
-- @cmt MOBILE 手机号
-- @cmt MOBILECALL 手机号
-- @cmt MOBILESHOWTYPE 手机号显示方式
-- @cmt MSGSTYLE 消息样式
-- @cmt NATIONALITY 国籍
-- @cmt NATIVEPLACE 籍贯
-- @cmt NEEDDYNAPASS 是否动态密码
-- @cmt NEEDUSB 是否需要 USB Key
-- @cmt NUMBERFIELD1 自定义数值字段1
-- @cmt NUMBERFIELD2 自定义数值字段2
-- @cmt NUMBERFIELD3 自定义数值字段3
-- @cmt NUMBERFIELD4 自定义数值字段4
-- @cmt NUMBERFIELD5 自定义数值字段5
-- @cmt OCCUPYSPACE 已用空间
-- @cmt OUTKEY 外部系统主键
-- @cmt PASSWDCHGDATE 密码修改日期
-- @cmt PASSWORD 密码
-- @cmt PASSWORDLOCK 密码锁定
-- @cmt PASSWORDSTATE 密码状态
-- @cmt POLICY 政治面貌
-- @cmt PROBATIONENDDATE 试用期结束日期
-- @cmt REGRESIDENTPLACE 户口所在地
-- @cmt RESIDENTPLACE 现居住地
-- @cmt RESIDENTPOSTCODE 居住地邮编
-- @cmt RESOURCEIMAGEID 照片ID
-- @cmt RESOURCETYPE 人员类型
-- @cmt SECLEVEL 安全级别
-- @cmt SERIAL 流水
-- @cmt SEX 性别
-- @cmt STARTDATE 开始日期
-- @cmt STATUS 状态
-- @cmt SUBCOMPANYID1 所属分部ID
-- @cmt SYSTEMLANGUAGE 系统语言
-- @cmt TEMPRESIDENTNUMBER 暂住证号
-- @cmt TEXTFIELD1 自定义文本字段1
-- @cmt TEXTFIELD2 自定义文本字段2
-- @cmt TEXTFIELD3 自定义文本字段3
-- @cmt TEXTFIELD4 自定义文本字段4
-- @cmt TEXTFIELD5 自定义文本字段5
-- @cmt TINYINTFIELD1 自定义选项字段1
-- @cmt TINYINTFIELD2 自定义选项字段2
-- @cmt TINYINTFIELD3 自定义选项字段3
-- @cmt TINYINTFIELD4 自定义选项字段4
-- @cmt TINYINTFIELD5 自定义选项字段5
-- @cmt TOKENKEY 令牌
-- @cmt TOTALSPACE 总空间
-- @cmt USBSTATE USB Key 状态
-- @cmt USEKIND 用工性质
-- @cmt USERUSBTYPE USB Key 类型
-- @cmt WEIGHT 重量
-- @cmt WORKCODE 工号
-- @cmt WORKROOM 办公室
-- @cmt companystartdate 入职日期
-- @cmt companyworkyear 司龄
-- @cmt created 创建时间
-- @cmt creater 创建人
-- @cmt mobilecaflag 手机 CA 标志
-- @cmt modified 修改时间
-- @cmt modifier 修改人
-- @cmt pinyinlastname 姓名拼音
-- @cmt salt 盐值
-- @cmt uuid UUID
-- @cmt workstartdate 参加工作日期
-- @cmt workyear 工龄
CREATE TABLE `hrmresource` (
  `ID` int(11) NOT NULL,
  `LOGINID` varchar(60) DEFAULT NULL COMMENT '系统登陆帐号',
  `PASSWORD` varchar(100) DEFAULT NULL,
  `LASTNAME` varchar(60) DEFAULT NULL,
  `SEX` char(1) DEFAULT NULL,
  `BIRTHDAY` char(10) DEFAULT NULL,
  `NATIONALITY` int(11) DEFAULT NULL,
  `SYSTEMLANGUAGE` int(11) DEFAULT NULL,
  `MARITALSTATUS` char(1) DEFAULT NULL,
  `TELEPHONE` varchar(60) DEFAULT NULL,
  `MOBILE` varchar(60) DEFAULT NULL,
  `MOBILECALL` varchar(60) DEFAULT NULL,
  `EMAIL` varchar(60) DEFAULT NULL,
  `LOCATIONID` int(11) DEFAULT NULL,
  `WORKROOM` varchar(60) DEFAULT NULL,
  `HOMEADDRESS` varchar(100) DEFAULT NULL,
  `RESOURCETYPE` char(1) DEFAULT NULL,
  `STARTDATE` char(10) DEFAULT NULL,
  `ENDDATE` char(10) DEFAULT NULL,
  `JOBTITLE` int(11) DEFAULT NULL,
  `JOBACTIVITYDESC` varchar(200) DEFAULT NULL,
  `JOBLEVEL` int(11) DEFAULT NULL,
  `SECLEVEL` int(11) DEFAULT NULL,
  `DEPARTMENTID` int(11) DEFAULT NULL,
  `SUBCOMPANYID1` int(11) DEFAULT NULL,
  `COSTCENTERID` int(11) DEFAULT NULL,
  `MANAGERID` int(11) DEFAULT NULL,
  `ASSISTANTID` int(11) DEFAULT NULL,
  `BANKID1` int(11) DEFAULT NULL,
  `ACCOUNTID1` varchar(100) DEFAULT NULL,
  `RESOURCEIMAGEID` int(11) DEFAULT NULL,
  `CREATERID` int(11) DEFAULT NULL,
  `CREATEDATE` char(10) DEFAULT NULL,
  `LASTMODID` int(11) DEFAULT NULL,
  `LASTMODDATE` char(10) DEFAULT NULL,
  `LASTLOGINDATE` char(10) DEFAULT NULL,
  `DATEFIELD1` varchar(10) DEFAULT NULL,
  `DATEFIELD2` varchar(10) DEFAULT NULL,
  `DATEFIELD3` varchar(10) DEFAULT NULL,
  `DATEFIELD4` varchar(10) DEFAULT NULL,
  `DATEFIELD5` varchar(10) DEFAULT NULL,
  `NUMBERFIELD1` double DEFAULT NULL,
  `NUMBERFIELD2` double DEFAULT NULL,
  `NUMBERFIELD3` double DEFAULT NULL,
  `NUMBERFIELD4` double DEFAULT NULL,
  `NUMBERFIELD5` double DEFAULT NULL,
  `TEXTFIELD1` varchar(100) DEFAULT NULL,
  `TEXTFIELD2` varchar(100) DEFAULT NULL,
  `TEXTFIELD3` varchar(100) DEFAULT NULL,
  `TEXTFIELD4` varchar(100) DEFAULT NULL,
  `TEXTFIELD5` varchar(100) DEFAULT NULL,
  `TINYINTFIELD1` int(11) DEFAULT NULL,
  `TINYINTFIELD2` int(11) DEFAULT NULL,
  `TINYINTFIELD3` int(11) DEFAULT NULL,
  `TINYINTFIELD4` int(11) DEFAULT NULL,
  `TINYINTFIELD5` int(11) DEFAULT NULL,
  `CERTIFICATENUM` varchar(60) DEFAULT NULL,
  `NATIVEPLACE` varchar(100) DEFAULT NULL,
  `EDUCATIONLEVEL` int(11) DEFAULT NULL,
  `BEMEMBERDATE` char(10) DEFAULT NULL,
  `BEPARTYDATE` char(10) DEFAULT NULL,
  `WORKCODE` varchar(60) DEFAULT NULL,
  `REGRESIDENTPLACE` varchar(200) DEFAULT NULL,
  `HEALTHINFO` char(1) DEFAULT NULL,
  `RESIDENTPLACE` varchar(200) DEFAULT NULL,
  `POLICY` varchar(30) DEFAULT NULL,
  `DEGREE` varchar(30) DEFAULT NULL,
  `HEIGHT` varchar(10) DEFAULT NULL,
  `USEKIND` int(11) DEFAULT NULL,
  `JOBCALL` int(11) DEFAULT NULL,
  `ACCUMFUNDACCOUNT` varchar(30) DEFAULT NULL,
  `BIRTHPLACE` varchar(60) DEFAULT NULL,
  `FOLK` varchar(30) DEFAULT NULL,
  `RESIDENTPHONE` varchar(60) DEFAULT NULL,
  `RESIDENTPOSTCODE` varchar(60) DEFAULT NULL,
  `EXTPHONE` varchar(50) DEFAULT NULL,
  `MANAGERSTR` varchar(500) DEFAULT NULL,
  `STATUS` int(11) DEFAULT NULL,
  `FAX` varchar(60) DEFAULT NULL,
  `ISLABOUUNION` char(1) DEFAULT NULL,
  `WEIGHT` int(11) DEFAULT NULL,
  `TEMPRESIDENTNUMBER` varchar(60) DEFAULT NULL,
  `PROBATIONENDDATE` char(10) DEFAULT NULL,
  `COUNTRYID` int(11) DEFAULT '1',
  `PASSWDCHGDATE` char(10) DEFAULT NULL,
  `NEEDUSB` int(11) DEFAULT NULL,
  `SERIAL` varchar(32) DEFAULT NULL,
  `ACCOUNT` varchar(60) DEFAULT NULL,
  `LLOGINID` varchar(60) DEFAULT NULL,
  `NEEDDYNAPASS` int(11) DEFAULT NULL,
  `DSPORDER` double DEFAULT NULL,
  `PASSWORDSTATE` int(11) DEFAULT NULL,
  `ACCOUNTTYPE` int(11) DEFAULT NULL,
  `BELONGTO` int(11) DEFAULT NULL,
  `DACTYLOGRAM` text,
  `ASSISTANTDACTYLOGRAM` text,
  `PASSWORDLOCK` int(11) DEFAULT NULL,
  `SUMPASSWORDWRONG` int(11) DEFAULT NULL,
  `OLDPASSWORD1` varchar(100) DEFAULT NULL,
  `OLDPASSWORD2` varchar(100) DEFAULT NULL,
  `MSGSTYLE` varchar(20) DEFAULT NULL,
  `MESSAGERURL` varchar(100) DEFAULT NULL,
  `pinyinlastname` varchar(1000) DEFAULT NULL,
  `TOKENKEY` varchar(100) DEFAULT NULL,
  `USERUSBTYPE` varchar(10) DEFAULT NULL,
  `OUTKEY` varchar(100) DEFAULT NULL,
  `ADSJGS` varchar(500) DEFAULT NULL,
  `ADGS` varchar(500) DEFAULT NULL,
  `ADBM` varchar(500) DEFAULT NULL,
  `MOBILESHOWTYPE` int(11) DEFAULT NULL,
  `USBSTATE` int(11) DEFAULT NULL,
  `TOTALSPACE` double DEFAULT '100',
  `OCCUPYSPACE` double DEFAULT '0',
  `ECOLOGY_PINYIN_SEARCH` varchar(1000) DEFAULT NULL,
  `ISADACCOUNT` char(1) DEFAULT NULL,
  `ACCOUNTNAME` varchar(200) DEFAULT NULL,
  `haschangepwd` varchar(10) DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `creater` int(11) DEFAULT NULL,
  `modified` datetime DEFAULT NULL,
  `modifier` int(11) DEFAULT NULL,
  `passwordlocktime` datetime DEFAULT NULL,
  `mobilecaflag` varchar(10) DEFAULT NULL,
  `salt` varchar(100) DEFAULT NULL,
  `companystartdate` varchar(10) DEFAULT NULL,
  `workstartdate` varchar(10) DEFAULT NULL,
  `secondaryPwd` varchar(1000) DEFAULT NULL,
  `useSecondaryPwd` int(11) DEFAULT NULL,
  `CLASSIFICATION` char(1) DEFAULT NULL,
  `uuid` varchar(50) DEFAULT '0',
  `passwordLockReason` varchar(10) DEFAULT NULL,
  `companyworkyear` decimal(10,2) DEFAULT NULL,
  `workyear` decimal(10,2) DEFAULT NULL,
  `DISMISSDATE` varchar(10) DEFAULT NULL,
  `encKey` varchar(200) DEFAULT NULL,
  `crc` varchar(200) DEFAULT NULL,
  `fs_status` int(11) DEFAULT NULL COMMENT '飞书员工状态',
  `whitestate` varchar(10) NOT NULL DEFAULT '0' COMMENT 'M级白名单 ，0 无，1 有',
  PRIMARY KEY (`ID`),
  KEY `HRMRESOURCE_ID` (`ID`,`DEPARTMENTID`),
  KEY `IX_HRMRESCE_TD` (`DEPARTMENTID`,`LASTNAME`),
  KEY `IX_HRMRESOURCE_DEPT` (`DEPARTMENTID`),
  KEY `IX_HRMRESOURCE_LA` (`LOGINID`,`ACCOUNT`),
  KEY `IX_HRMRESOURCE_MANAGER` (`MANAGERID`),
  KEY `IX_HRMRESOURCE_SIDST` (`SUBCOMPANYID1`,`STATUS`),
  KEY `IX_HRMRSC_CNN` (`STATUS`,`ID`,`DSPORDER`),
  KEY `IX_HRMRSC_LID` (`LOGINID`,`ID`),
  KEY `IX_HRMRSUC_STTS` (`LOGINID`,`STATUS`),
  KEY `idx_hrmresource_cd` (`OUTKEY`),
  KEY `IX_HRMRSC_LP` (`STATUS`,`LASTNAME`,`LOGINID`),
  KEY `IX_HRMRSC_PY` (`pinyinlastname`),
  KEY `idx_hrmresource_uuid` (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:hrmresource_fs
-- @at 2026-11-27 16:23:19
-- @cmt ID 主键ID
-- @cmt LASTNAME 姓名
-- @cmt MOBILE 手机号
-- @cmt user_id 用户id
CREATE TABLE `hrmresource_fs` (
  `ID` int(11) NOT NULL,
  `LASTNAME` varchar(60) DEFAULT NULL,
  `MOBILE` varchar(60) DEFAULT NULL,
  `user_id` varchar(60) DEFAULT NULL,
  `fs_union_id` varchar(60) DEFAULT NULL,
  `crm_open_id` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `hrmresource_fs_un` (`MOBILE`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='飞书账号映射表';

-- @table RDS_oa_ecology:hrmschedulesign
-- @at 2026-11-27 16:23:23
-- @cmt ADDR 地址
-- @cmt LATITUDE 纬度
-- @cmt LONGITUDE 经度
-- @cmt SIGNDATE 签到日期
-- @cmt SIGNFROM 签约来源
-- @cmt SIGNTIME 签到时间
-- @cmt SIGNTYPE 签到类型
-- @cmt USERID 用户ID
-- @cmt USERTYPE 用户类型
-- @cmt belongdate 归属日期
-- @cmt deviceInfo 设备信息
-- @cmt memo 备注
CREATE TABLE `hrmschedulesign` (
  `ID` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `USERID` int(11) DEFAULT NULL,
  `USERTYPE` char(1) DEFAULT NULL,
  `SIGNTYPE` char(1) DEFAULT NULL,
  `SIGNDATE` char(10) DEFAULT NULL,
  `SIGNTIME` char(8) DEFAULT NULL,
  `clientAddress` varchar(256) DEFAULT NULL,
  `ISINCOM` char(1) DEFAULT NULL,
  `SIGNFROM` varchar(400) DEFAULT NULL,
  `LONGITUDE` varchar(400) DEFAULT NULL,
  `LATITUDE` varchar(400) DEFAULT NULL,
  `ADDR` varchar(1000) DEFAULT NULL,
  `ISIMPORT` int(11) DEFAULT NULL,
  `SUUID` varchar(1000) DEFAULT NULL,
  `timeZone` varchar(400) DEFAULT NULL,
  `belongdate` char(10) DEFAULT NULL,
  `memo` varchar(4000) DEFAULT NULL,
  `deviceInfo` varchar(1000) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `HRMSCHEDULESIGN_SIGNDATE_IN` (`SIGNDATE`),
  KEY `HRMSCHEDULESIGN_SIGNTYPE_IN` (`SIGNTYPE`),
  KEY `HRMSCHEDULESIGN_USERID_IN` (`USERID`)
) ENGINE=InnoDB AUTO_INCREMENT=788318 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:kq_flow_overtime
-- @at 2026-11-27 16:20:27
-- @cmt belongdate 归属日期
-- @cmt card_mins 卡分钟
-- @cmt changetype 变更类型
-- @cmt computingMode 计算方式
-- @cmt duration_min 时长最小
-- @cmt durationrule 时长计算规则
-- @cmt expiringdate 到期日期
-- @cmt fromdate 开始日期
-- @cmt fromdatedb 开始日期（库存值）
-- @cmt fromtime 开始时间
-- @cmt fromtimedb 开始时间（库存值）
-- @cmt id 主键ID
-- @cmt ori_belongdate 原始所属日期
-- @cmt paidLeaveEnable 是否带薪假
-- @cmt requestid 流程请求ID
-- @cmt resourceid 资源ID
-- @cmt todate 结束日期
-- @cmt todatedb 结束日期（库存值）
-- @cmt totime 结束时间
-- @cmt totimedb 结束时间（库存值）
-- @cmt uuid UUID
-- @cmt workMins 工作时长（分钟）
CREATE TABLE `kq_flow_overtime` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestid` varchar(100) DEFAULT NULL,
  `resourceid` varchar(100) DEFAULT NULL,
  `fromdate` varchar(100) DEFAULT NULL,
  `fromtime` varchar(100) DEFAULT NULL,
  `todate` varchar(100) DEFAULT NULL,
  `totime` varchar(100) DEFAULT NULL,
  `fromdatedb` varchar(100) DEFAULT NULL,
  `fromtimedb` varchar(100) DEFAULT NULL,
  `todatedb` varchar(100) DEFAULT NULL,
  `totimedb` varchar(100) DEFAULT NULL,
  `duration_min` varchar(100) DEFAULT NULL,
  `belongdate` varchar(100) DEFAULT NULL,
  `workMins` varchar(100) DEFAULT NULL,
  `durationrule` varchar(100) DEFAULT NULL,
  `changetype` varchar(100) DEFAULT NULL,
  `paidLeaveEnable` varchar(100) DEFAULT NULL,
  `computingMode` varchar(100) DEFAULT NULL,
  `expiringdate` varchar(100) DEFAULT NULL,
  `tiaoxiuid` varchar(1000) DEFAULT NULL,
  `uuid` varchar(1000) DEFAULT NULL,
  `flow_mins` float DEFAULT '0',
  `card_mins` float DEFAULT '0',
  `ori_belongdate` varchar(100) DEFAULT NULL,
  `flow_dataid` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=43140 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:kq_flow_split_leave
-- @at 2026-11-27 16:20:31
-- @cmt D_Mins 天分钟
-- @cmt belongDate 归属日期
-- @cmt changeType 变更类型
-- @cmt dataid 数据ID
-- @cmt departmentid 部门ID
-- @cmt detailid 明细ID
-- @cmt duration 时长
-- @cmt durationdb 时长
-- @cmt durationrule 时长计算规则
-- @cmt fromdate 开始日期
-- @cmt fromdatedb 开始日期（库存值）
-- @cmt fromtime 开始时间
-- @cmt fromtimedb 开始时间（库存值）
-- @cmt id 主键ID
-- @cmt jobtitle 岗位ID
-- @cmt newleavetype 请假类型
-- @cmt requestid 流程请求ID
-- @cmt resourceid 资源ID
-- @cmt serialid 流水号
-- @cmt status 状态
-- @cmt subcompanyid 分部ID
-- @cmt tablenamedb 来源表名
-- @cmt todate 结束日期
-- @cmt todatedb 结束日期（库存值）
-- @cmt totime 结束时间
-- @cmt totimedb 结束时间（库存值）
-- @cmt usedetail 使用明细
-- @cmt workflowid 流程ID
CREATE TABLE `kq_flow_split_leave` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestid` varchar(100) DEFAULT NULL,
  `workflowid` varchar(100) DEFAULT NULL,
  `dataid` varchar(100) DEFAULT NULL,
  `detailid` varchar(100) DEFAULT NULL,
  `resourceid` varchar(100) DEFAULT NULL,
  `fromdate` varchar(100) DEFAULT NULL,
  `fromtime` varchar(100) DEFAULT NULL,
  `todate` varchar(100) DEFAULT NULL,
  `totime` varchar(100) DEFAULT NULL,
  `newleavetype` varchar(100) DEFAULT NULL,
  `duration` float DEFAULT NULL,
  `usedetail` varchar(10) DEFAULT NULL,
  `durationrule` varchar(10) DEFAULT NULL,
  `tablenamedb` varchar(100) DEFAULT NULL,
  `fromdatedb` varchar(100) DEFAULT NULL,
  `fromtimedb` varchar(100) DEFAULT NULL,
  `todatedb` varchar(100) DEFAULT NULL,
  `totimedb` varchar(100) DEFAULT NULL,
  `durationdb` varchar(100) DEFAULT NULL,
  `status` varchar(100) DEFAULT NULL,
  `belongDate` varchar(50) DEFAULT NULL,
  `D_Mins` varchar(50) DEFAULT NULL,
  `serialid` varchar(50) DEFAULT NULL,
  `subcompanyid` int(11) DEFAULT NULL,
  `departmentid` int(11) DEFAULT NULL,
  `jobtitle` int(11) DEFAULT NULL,
  `leavebackrequestid` varchar(100) DEFAULT NULL,
  `companion` text,
  `iscompanion` varchar(10) DEFAULT NULL,
  `changeType` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_kq_flow_split_leave` (`resourceid`,`fromdate`,`todate`)
) ENGINE=InnoDB AUTO_INCREMENT=46910 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:kq_flow_split_leaveback
-- @at 2026-11-27 16:23:27
-- @cmt D_Mins 天分钟
-- @cmt belongDate 归属日期
-- @cmt changeType 变更类型
-- @cmt dataid 数据ID
-- @cmt departmentid 部门ID
-- @cmt detailid 明细ID
-- @cmt duration 时长
-- @cmt durationdb 时长
-- @cmt durationrule 时长计算规则
-- @cmt fromdate 开始日期
-- @cmt fromdatedb 开始日期（库存值）
-- @cmt fromtime 开始时间
-- @cmt fromtimedb 开始时间（库存值）
-- @cmt id 主键ID
-- @cmt jobtitle 岗位ID
-- @cmt newleavetype 请假类型
-- @cmt requestid 流程请求ID
-- @cmt resourceid 资源ID
-- @cmt serialid 流水号
-- @cmt status 状态
-- @cmt subcompanyid 分部ID
-- @cmt tablenamedb 来源表名
-- @cmt todate 结束日期
-- @cmt todatedb 结束日期（库存值）
-- @cmt totime 结束时间
-- @cmt totimedb 结束时间（库存值）
-- @cmt usedetail 使用明细
-- @cmt workflowid 流程ID
CREATE TABLE `kq_flow_split_leaveback` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestid` varchar(100) DEFAULT NULL,
  `workflowid` varchar(100) DEFAULT NULL,
  `dataid` varchar(100) DEFAULT NULL,
  `detailid` varchar(100) DEFAULT NULL,
  `resourceid` varchar(100) DEFAULT NULL,
  `fromdate` varchar(100) DEFAULT NULL,
  `fromtime` varchar(100) DEFAULT NULL,
  `todate` varchar(100) DEFAULT NULL,
  `totime` varchar(100) DEFAULT NULL,
  `newleavetype` varchar(100) DEFAULT NULL,
  `duration` float DEFAULT NULL,
  `usedetail` varchar(10) DEFAULT NULL,
  `durationrule` varchar(10) DEFAULT NULL,
  `tablenamedb` varchar(100) DEFAULT NULL,
  `fromdatedb` varchar(100) DEFAULT NULL,
  `fromtimedb` varchar(100) DEFAULT NULL,
  `todatedb` varchar(100) DEFAULT NULL,
  `totimedb` varchar(100) DEFAULT NULL,
  `durationdb` varchar(100) DEFAULT NULL,
  `status` varchar(100) DEFAULT NULL,
  `belongDate` varchar(50) DEFAULT NULL,
  `D_Mins` varchar(50) DEFAULT NULL,
  `serialid` varchar(50) DEFAULT NULL,
  `changeType` varchar(50) DEFAULT NULL,
  `subcompanyid` int(11) DEFAULT NULL,
  `departmentid` int(11) DEFAULT NULL,
  `jobtitle` int(11) DEFAULT NULL,
  `leavebackrequestid` varchar(100) DEFAULT NULL,
  `companion` text,
  `iscompanion` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_kq_flow_split_leaveback` (`resourceid`,`fromdate`,`todate`)
) ENGINE=InnoDB AUTO_INCREMENT=296 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:kq_format_detail
-- @at 2026-11-27 16:20:35
-- @cmt absenteeismmins 旷工分钟
-- @cmt attendanceMins 出勤分钟
-- @cmt belatemins 迟到分钟
-- @cmt evectionMins 出差分钟
-- @cmt forgotBeginWorkCheckMins 上班漏签分钟
-- @cmt forgotcheckMins 漏签分钟
-- @cmt graveBeLateMins 严重迟到分钟
-- @cmt graveLeaveEarlyMins 严重早退分钟
-- @cmt groupid 考勤组ID
-- @cmt kqdate 考勤日期
-- @cmt leaveInfo 请假信息
-- @cmt leaveMins 请假分钟
-- @cmt leaveearlymins 早退分钟
-- @cmt outMins 外出分钟
-- @cmt resourceid 资源ID
-- @cmt serialid 流水号
-- @cmt serialnumber 流水号
-- @cmt signMins 签卡分钟
-- @cmt signindate 签到日期
-- @cmt signinid 签到记录ID
-- @cmt signintime 签到时间
-- @cmt signoutdate 签退日期
-- @cmt signoutid 签退记录ID
-- @cmt signouttime 签退时间
-- @cmt workbegindate 上班日期
-- @cmt workbegintime 上班时间
-- @cmt workenddate 下班日期
-- @cmt workendtime 下班时间
-- @cmt workmins 工作时长（分钟）
CREATE TABLE `kq_format_detail` (
  `resourceid` int(11) NOT NULL,
  `kqdate` char(10) NOT NULL,
  `groupid` int(11) DEFAULT NULL,
  `serialid` int(11) DEFAULT NULL,
  `serialnumber` int(11) NOT NULL,
  `workbegindate` char(10) DEFAULT NULL,
  `workbegintime` char(8) DEFAULT NULL,
  `workenddate` char(10) DEFAULT NULL,
  `workendtime` char(8) DEFAULT NULL,
  `workmins` int(11) DEFAULT NULL,
  `signindate` char(10) DEFAULT NULL,
  `signintime` char(8) DEFAULT NULL,
  `signinid` int(11) DEFAULT NULL,
  `signoutdate` char(10) DEFAULT NULL,
  `signouttime` char(8) DEFAULT NULL,
  `signoutid` int(11) DEFAULT NULL,
  `attendanceMins` int(11) DEFAULT NULL,
  `belatemins` int(11) DEFAULT NULL,
  `graveBeLateMins` int(11) DEFAULT NULL,
  `leaveearlymins` int(11) DEFAULT NULL,
  `graveLeaveEarlyMins` int(11) DEFAULT NULL,
  `absenteeismmins` int(11) DEFAULT NULL,
  `leaveMins` int(11) DEFAULT NULL,
  `evectionMins` int(11) DEFAULT NULL,
  `outMins` int(11) DEFAULT NULL,
  `forgotcheckMins` int(11) DEFAULT NULL,
  `signMins` int(11) DEFAULT NULL,
  `leaveInfo` varchar(1000) DEFAULT NULL,
  `forgotBeginWorkCheckMins` int(11) DEFAULT NULL,
  `otherinfo` text,
  PRIMARY KEY (`resourceid`,`kqdate`,`serialnumber`),
  KEY `idx_kq_format_detail_kqdate` (`kqdate`),
  KEY `idx_kq_format_detail_rsid` (`resourceid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:kq_group
-- @at 2026-11-27 16:20:41
-- @cmt auto_checkin 自动签到
-- @cmt auto_checkin_after 自动签到后
-- @cmt auto_checkin_before 自动签到前
-- @cmt auto_checkout 自动核验出
-- @cmt auto_checkout_after 自动核验出后
-- @cmt auto_checkout_before 自动核验出前
-- @cmt groupname 考勤组名称
-- @cmt id 主键ID
-- @cmt ipscope IP范围
-- @cmt isdelete 是否删除
-- @cmt locationcheck 位置核验
-- @cmt serialids 流水ID
-- @cmt signintype 签到类型
-- @cmt signstart 签约开始
-- @cmt subcompanyid 分部ID
-- @cmt validity 有效期
-- @cmt validityenddate 有效结束日期
-- @cmt validityfromdate 有效开始日期
-- @cmt weekday 周天
-- @cmt workhour 工作小时
CREATE TABLE `kq_group` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `groupname` varchar(500) NOT NULL,
  `subcompanyid` int(11) DEFAULT NULL,
  `kqtype` int(11) NOT NULL,
  `excludeid` varchar(4000) DEFAULT NULL,
  `signintype` int(11) DEFAULT NULL,
  `ipscope` varchar(500) DEFAULT NULL,
  `locationcheck` int(11) DEFAULT NULL,
  `locationcheckscope` int(11) DEFAULT NULL,
  `wificheck` int(11) DEFAULT NULL,
  `weekday` varchar(100) DEFAULT NULL,
  `shiftcyclename` varchar(500) DEFAULT NULL,
  `shiftcycleday` int(11) DEFAULT NULL,
  `shiftcycleserialids` varchar(500) DEFAULT NULL,
  `serialids` varchar(1000) DEFAULT NULL,
  `signstart` varchar(5) DEFAULT NULL,
  `workhour` decimal(10,2) DEFAULT NULL,
  `outsidesign` int(11) DEFAULT NULL,
  `validity` int(11) DEFAULT NULL,
  `validityfromdate` varchar(10) DEFAULT NULL,
  `validityenddate` varchar(10) DEFAULT NULL,
  `isdelete` int(11) DEFAULT NULL,
  `excludecount` int(11) DEFAULT NULL,
  `locationfacecheck` int(11) DEFAULT NULL,
  `locationshowaddress` int(11) DEFAULT NULL,
  `wififacecheck` int(11) DEFAULT NULL,
  `ipscope_v4_pc` varchar(500) DEFAULT NULL,
  `ipscope_v4_em` varchar(500) DEFAULT NULL,
  `ipscope_v6_pc` varchar(500) DEFAULT NULL,
  `ipscope_v6_em` varchar(500) DEFAULT NULL,
  `auto_checkin` int(11) DEFAULT '0',
  `auto_checkin_before` int(11) DEFAULT '30',
  `auto_checkin_after` int(11) DEFAULT '30',
  `auto_checkout` int(11) DEFAULT '0',
  `auto_checkout_before` int(11) DEFAULT '5',
  `auto_checkout_after` int(11) DEFAULT '60',
  `calmethod` int(11) DEFAULT '2',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=123 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:kq_holidayset
-- @at 2026-11-27 16:20:45
-- @cmt ID 主键ID
-- @cmt changeType 变更类型
-- @cmt groupId 考勤组ID
-- @cmt holidayDate 节假日日期
-- @cmt holidayDesc 节假日说明
-- @cmt relatedDay 关联日期
CREATE TABLE `kq_holidayset` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `groupId` varchar(100) NOT NULL,
  `holidayDate` char(10) NOT NULL,
  `holidayDesc` varchar(200) DEFAULT NULL,
  `changeType` int(11) NOT NULL,
  `relatedDay` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB AUTO_INCREMENT=26495 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:kq_leaverules
-- @at 2026-11-27 16:20:50
-- @cmt ID 主键ID
-- @cmt balanceEnable 余额启用
-- @cmt computingMode 计算方式
-- @cmt hoursToDay 小时今日
-- @cmt isDelete 是否删除
-- @cmt isEnable 是否启用
-- @cmt leaveName 假期名称
-- @cmt proportion 占比
-- @cmt scopeType 范围类型
-- @cmt scopeValue 范围值
-- @cmt showOrder 显示顺序
CREATE TABLE `kq_leaverules` (
  `ID` int(11) NOT NULL,
  `leaveName` varchar(200) NOT NULL,
  `scopeType` int(11) DEFAULT NULL,
  `scopeValue` varchar(200) DEFAULT NULL,
  `minimumUnit` int(11) NOT NULL,
  `proportion` decimal(10,2) DEFAULT NULL,
  `computingMode` int(11) DEFAULT NULL,
  `hoursToDay` decimal(10,2) DEFAULT NULL,
  `balanceEnable` int(11) DEFAULT '0',
  `isEnable` int(11) DEFAULT NULL,
  `leaveCode` varchar(200) DEFAULT NULL,
  `isDelete` int(11) DEFAULT '0',
  `showOrder` decimal(15,5) DEFAULT NULL,
  `timeselection` int(11) DEFAULT '1',
  `filterHolidays` varchar(100) DEFAULT '0',
  `conversion` int(11) DEFAULT '1',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:kq_shiftonoffworksections
-- @at 2026-11-27 16:23:31
-- @cmt across 是否跨天
-- @cmt beginmin 开始最小
-- @cmt endmin 结束最小
-- @cmt id 主键ID
-- @cmt isdelete 是否删除
-- @cmt mins 分钟
-- @cmt mins_next 分钟下次
-- @cmt record 记录
-- @cmt serialid 流水号
-- @cmt times 时间
CREATE TABLE `kq_shiftonoffworksections` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `serialid` int(11) DEFAULT NULL,
  `across` char(1) DEFAULT NULL,
  `beginmin` varchar(50) DEFAULT NULL,
  `endmin` varchar(50) DEFAULT NULL,
  `times` varchar(100) DEFAULT NULL,
  `onoffworktype` varchar(100) DEFAULT NULL,
  `isdelete` char(1) DEFAULT NULL,
  `mins` varchar(50) DEFAULT NULL,
  `record` varchar(10) DEFAULT NULL,
  `mins_next` char(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=383 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:kq_shiftresttimesections
-- @at 2026-11-27 16:20:54
-- @cmt across 是否跨天
-- @cmt id 主键ID
-- @cmt isdelete 是否删除
-- @cmt resttype 休息类型
-- @cmt serialid 流水号
-- @cmt time 时间
CREATE TABLE `kq_shiftresttimesections` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `serialid` int(11) DEFAULT NULL,
  `resttype` varchar(100) DEFAULT NULL,
  `across` char(1) DEFAULT NULL,
  `time` varchar(100) DEFAULT NULL,
  `isdelete` char(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=363 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:kq_shiftschedule
-- @at 2026-11-27 16:23:33
-- @cmt groupid 考勤组ID
-- @cmt id 主键ID
-- @cmt isdelete 是否删除
-- @cmt kqdate 考勤日期
-- @cmt resourceid 资源ID
-- @cmt serialid 流水号
CREATE TABLE `kq_shiftschedule` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `kqdate` varchar(10) DEFAULT NULL,
  `serialid` int(11) DEFAULT NULL,
  `resourceid` int(11) DEFAULT NULL,
  `groupid` int(11) DEFAULT NULL,
  `isdelete` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_kq_shiftsch_kd` (`kqdate`),
  KEY `idx_kq_shiftsche_rsid` (`resourceid`),
  KEY `idx_kq_shiftsche_gid` (`groupid`)
) ENGINE=InnoDB AUTO_INCREMENT=34953 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:mobile_sign
-- @at 2026-11-27 16:23:37
-- @cmt ADDRESS 地址
-- @cmt LATITUDE 纬度
-- @cmt LONGITUDE 经度
-- @cmt OPERATER 操作人
-- @cmt OPERATE_DATE 操作日期
-- @cmt OPERATE_TIME 数据插入时间
-- @cmt OPERATE_TYPE 操作类型
-- @cmt REMARK 备注
-- @cmt crm CRM
CREATE TABLE `mobile_sign` (
  `ID` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `OPERATER` int(11) NOT NULL,
  `OPERATE_TYPE` varchar(400) DEFAULT NULL,
  `OPERATE_DATE` char(50) NOT NULL,
  `OPERATE_TIME` char(8) NOT NULL,
  `LONGITUDE` varchar(400) DEFAULT NULL,
  `LATITUDE` varchar(400) DEFAULT NULL,
  `ADDRESS` varchar(1000) DEFAULT NULL,
  `REMARK` text,
  `ATTACHMENT` varchar(1000) DEFAULT NULL,
  `crm` varchar(200) DEFAULT NULL,
  `timezone` varchar(1000) DEFAULT NULL,
  `isImport` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB AUTO_INCREMENT=20095 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:project_contract
-- @at 2026-11-27 16:27:57
-- @status 弃用
-- @reason 表已删除 / 迁移

-- @table RDS_oa_ecology:uf_bxlxkmtz
-- @at 2026-11-27 16:23:42
-- @cmt formmodeid 建模表单ID
-- @cmt id 主键ID
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt modeuuid 建模数据UUID
-- @cmt requestId 流程请求ID
CREATE TABLE `uf_bxlxkmtz` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modeuuid` varchar(100) DEFAULT NULL,
  `kmmc` varchar(999) DEFAULT NULL,
  `kmbh` varchar(999) DEFAULT NULL,
  `kmsm` varchar(999) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1555989255721` (`modeuuid`)
) ENGINE=InnoDB AUTO_INCREMENT=206060114 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_cpxxbd
-- @at 2026-11-27 16:20:58
-- @cmt bz 备注
-- @cmt cpfl 产品分类
-- @cmt cpxh 产品型号
-- @cmt formmodeid 建模表单ID
-- @cmt gysmc 供应商名称
-- @cmt id 主键ID
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt modeuuid 建模数据UUID
-- @cmt requestId 流程请求ID
-- @cmt sfhz 省份合作
CREATE TABLE `uf_cpxxbd` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `cplh` varchar(999) DEFAULT NULL,
  `gysmc` varchar(999) DEFAULT NULL,
  `cppp` varchar(999) DEFAULT NULL,
  `cpmcsbmc` varchar(999) DEFAULT NULL,
  `cpxh` varchar(999) DEFAULT NULL,
  `cpgg` varchar(999) DEFAULT NULL,
  `cpjj` varchar(999) DEFAULT NULL,
  `bjzx` int(11) DEFAULT NULL,
  `cpcghsdj` decimal(38,2) DEFAULT NULL,
  `bxq` varchar(999) DEFAULT NULL,
  `cpyf` decimal(38,2) DEFAULT NULL,
  `cpjgcb` decimal(38,2) DEFAULT NULL,
  `gsgtcb` decimal(38,2) DEFAULT NULL,
  `cpzcb` decimal(38,2) DEFAULT NULL,
  `zxwlqdsm` varchar(999) DEFAULT NULL,
  `ggsfj` text,
  `ghjq` varchar(999) DEFAULT NULL,
  `fkf` varchar(999) DEFAULT NULL,
  `csbgfj` text,
  `jszj` varchar(999) DEFAULT NULL,
  `sfhz` int(11) DEFAULT NULL,
  `bz` varchar(999) DEFAULT NULL,
  `cpfl` int(11) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modeuuid` varchar(100) DEFAULT NULL,
  `sfkxs` int(11) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  `xcpmcsbmc` varchar(999) DEFAULT NULL,
  `ycbq` varchar(999) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1559723786821` (`modeuuid`)
) ENGINE=InnoDB AUTO_INCREMENT=11200020408 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_crmsjsjtz
-- @at 2026-11-27 16:23:46
-- @cmt MODEUUID 建模数据UUID
-- @cmt crmbh CRM编号
-- @cmt formmodeid 建模表单ID
-- @cmt hzlx 合作类型
-- @cmt id 主键ID
-- @cmt khmc 客户名称
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt requestId 流程请求ID
-- @cmt sf 省份
-- @cmt sjlx 时间类型
-- @cmt sjmc 时间名称
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt yjqdrq 业绩签订日期
CREATE TABLE `uf_crmsjsjtz` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `crmbh` varchar(100) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `lxrxm` varchar(100) DEFAULT NULL,
  `sjlx` varchar(100) DEFAULT NULL,
  `yjxsje` decimal(38,2) DEFAULT NULL,
  `yjqdrq` char(10) DEFAULT NULL,
  `xsms` varchar(100) DEFAULT NULL,
  `hzlx` varchar(100) DEFAULT NULL,
  `sf` varchar(100) DEFAULT NULL,
  `sq` varchar(100) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  `MODEUUID` varchar(100) DEFAULT NULL,
  `khmc` text,
  `sjmc` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1716263423219` (`MODEUUID`)
) ENGINE=InnoDB AUTO_INCREMENT=752618 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_customer_account
-- @at 2026-11-27 16:23:51
-- @cmt approvestatus 审批状态
-- @cmt bz 备注
-- @cmt category 类目
-- @cmt crmbh CRM编号
-- @cmt formmodeid 建模表单ID
-- @cmt id 主键ID
-- @cmt jqlx 景区类型
-- @cmt khid 客户ID
-- @cmt khjd 客户进度
-- @cmt khlx 客户类型
-- @cmt khly 客户来源
-- @cmt khmc 客户名称
-- @cmt lxr 联系人
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt modeuuid 建模数据UUID
-- @cmt name 名称
-- @cmt requestId 流程请求ID
-- @cmt s 类型
-- @cmt ywlx 业务类型
CREATE TABLE `uf_customer_account` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `yhid` int(11) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modeuuid` varchar(100) DEFAULT NULL,
  `yhmc` varchar(50) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `statusmapped` varchar(50) DEFAULT NULL,
  `category` int(11) DEFAULT NULL,
  `categorymapped` varchar(100) DEFAULT NULL,
  `needhiddendispose` varchar(50) DEFAULT NULL,
  `updatedat` varchar(50) DEFAULT NULL,
  `createdat` varchar(50) DEFAULT NULL,
  `approvestatus` varchar(50) DEFAULT NULL,
  `approvestatusi18n` varchar(100) DEFAULT NULL,
  `customfieldtemplateid` int(11) DEFAULT NULL,
  `khmc` varchar(999) DEFAULT NULL,
  `gsmc` varchar(999) DEFAULT NULL,
  `cjrq` char(10) DEFAULT NULL,
  `fzrcjr` varchar(999) DEFAULT NULL,
  `zxfs` varchar(999) DEFAULT NULL,
  `khly` varchar(999) DEFAULT NULL,
  `khfl` varchar(999) DEFAULT NULL,
  `dq` varchar(999) DEFAULT NULL,
  `lxr` varchar(999) DEFAULT NULL,
  `khjd` varchar(999) DEFAULT NULL,
  `jqlx` varchar(999) DEFAULT NULL,
  `jqdj` varchar(999) DEFAULT NULL,
  `szbm` varchar(999) DEFAULT NULL,
  `ywlx` varchar(999) DEFAULT NULL,
  `hzxxxt` varchar(999) DEFAULT NULL,
  `hzxspt` varchar(999) DEFAULT NULL,
  `bz` varchar(999) DEFAULT NULL,
  `khid` int(11) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  `gzbm` int(11) DEFAULT NULL,
  `jqlxylk` text,
  `jqdjylk` text,
  `khflylk` text,
  `khlyylk` text,
  `khlxylk` text,
  `crmbh` varchar(100) DEFAULT NULL,
  `s` varchar(100) DEFAULT NULL,
  `shi` varchar(100) DEFAULT NULL,
  `lymx` varchar(100) DEFAULT NULL,
  `lyqd` varchar(100) DEFAULT NULL,
  `khlx` varchar(100) DEFAULT NULL,
  `jqyt` varchar(100) DEFAULT NULL,
  `jqaj` varchar(100) DEFAULT NULL,
  `sjh` varchar(100) DEFAULT NULL,
  `sjgl` text,
  `htg` text,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1558002248009` (`modeuuid`)
) ENGINE=InnoDB AUTO_INCREMENT=261338 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_httzbd
-- @at 2026-11-27 16:23:56
-- @cmt bz 备注
-- @cmt cs 城市
-- @cmt ddyc 订单异常
-- @cmt ds 天
-- @cmt dsfcz 第三方厂商
-- @cmt dzyx 地址邮箱
-- @cmt formmodeid 建模表单ID
-- @cmt htbh 合同编号
-- @cmt htlx 合同类型
-- @cmt htmc 合同名称
-- @cmt hzbh 合作编号
-- @cmt hzksrq 合作开始日期
-- @cmt hzlx 合作类型
-- @cmt hzlx1 合作类型1
-- @cmt id 主键ID
-- @cmt jfmc 甲方名称
-- @cmt jqlx 景区类型
-- @cmt jqmc 景区名称
-- @cmt khlx 客户类型
-- @cmt khmc 客户名称
-- @cmt lcbh 流程编号
-- @cmt lxdh 联系电话
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt modeuuid 建模数据UUID
-- @cmt mt 美团
-- @cmt ptzh 平台账号
-- @cmt qyrq 区域日期
-- @cmt requestId 流程请求ID
-- @cmt s 类型
-- @cmt sf 省份
-- @cmt sqbm 申请部门
-- @cmt sqr 申请人
-- @cmt tc 提成
-- @cmt xmmc 项目名称
-- @cmt xsry 销售人员
-- @cmt yfkje 预付款金额
-- @cmt yjje 业绩金额
-- @cmt ykpje 已开票金额
-- @cmt ywlx 业务类型
-- @cmt zbj 质保金
CREATE TABLE `uf_httzbd` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `xmmc` varchar(999) DEFAULT NULL,
  `htbh` varchar(999) DEFAULT NULL,
  `jfmc` varchar(999) DEFAULT NULL,
  `tognxundizhi` varchar(999) DEFAULT NULL,
  `lianxir` varchar(999) DEFAULT NULL,
  `lxdh` varchar(999) DEFAULT NULL,
  `gddh` varchar(999) DEFAULT NULL,
  `dzyx` varchar(999) DEFAULT NULL,
  `qyrq` char(10) DEFAULT NULL,
  `htbddsbzj` decimal(38,2) DEFAULT NULL,
  `yfk` decimal(38,2) DEFAULT NULL,
  `ysk` decimal(38,2) DEFAULT NULL,
  `zbj` decimal(38,2) DEFAULT NULL,
  `wbf` decimal(38,2) DEFAULT NULL,
  `bxq` varchar(999) DEFAULT NULL,
  `azdspxfwxcfwsj` varchar(999) DEFAULT NULL,
  `xmzq` varchar(999) DEFAULT NULL,
  `ysfbj` varchar(999) DEFAULT NULL,
  `azdsxtpxf` varchar(999) DEFAULT NULL,
  `qmbtkxgnrxgq` varchar(999) DEFAULT NULL,
  `qmbtkxgnrxgh` varchar(999) DEFAULT NULL,
  `zhtsfyzbht` int(11) DEFAULT NULL,
  `zbhtbh` varchar(999) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modeuuid` varchar(100) DEFAULT NULL,
  `sfbzht` int(11) DEFAULT NULL,
  `htlx` int(11) DEFAULT NULL,
  `khlx` int(11) DEFAULT NULL,
  `hzlx` int(11) DEFAULT NULL,
  `crjrjyj` int(11) DEFAULT NULL,
  `xqxf` int(11) DEFAULT NULL,
  `khzy` text,
  `yjje` decimal(38,2) DEFAULT NULL,
  `rjje` decimal(38,2) DEFAULT NULL,
  `yjhf` int(11) DEFAULT NULL,
  `yfkbl` decimal(38,4) DEFAULT NULL,
  `dhkbl` decimal(38,4) DEFAULT NULL,
  `yskbl` decimal(38,4) DEFAULT NULL,
  `zbjbl` decimal(38,4) DEFAULT NULL,
  `wbfbl` decimal(38,4) DEFAULT NULL,
  `ptzh` varchar(999) DEFAULT NULL,
  `zbhtfj` text,
  `zzhtfj` text,
  `htmc` varchar(999) DEFAULT NULL,
  `dhk` decimal(38,2) DEFAULT NULL,
  `ywzzht` int(11) DEFAULT NULL,
  `hzbh` varchar(999) DEFAULT NULL,
  `xsry` int(11) DEFAULT NULL,
  `hzjzrq` char(10) DEFAULT NULL,
  `hzksrq` char(10) DEFAULT NULL,
  `jfgsmc` text,
  `yfkje` decimal(38,2) DEFAULT NULL,
  `ykpje` decimal(38,2) DEFAULT NULL,
  `syfkje` decimal(38,2) DEFAULT NULL,
  `sykpje` decimal(38,2) DEFAULT NULL,
  `sf` int(11) DEFAULT NULL,
  `cs` int(11) DEFAULT NULL,
  `sqr` int(11) DEFAULT NULL,
  `sqbm` int(11) DEFAULT NULL,
  `jqmc` varchar(999) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  `ywlx` int(11) DEFAULT NULL,
  `dsfcz` int(11) DEFAULT NULL,
  `mt` int(11) DEFAULT NULL,
  `glbjsp` text,
  `s` int(11) DEFAULT NULL,
  `ds` int(11) DEFAULT NULL,
  `glzhtsplc` int(11) DEFAULT NULL,
  `zbsj` char(10) DEFAULT NULL,
  `xmzqn` int(11) DEFAULT NULL,
  `zbqn` int(11) DEFAULT NULL,
  `dhdstfk` int(11) DEFAULT NULL,
  `ysdstfk` int(11) DEFAULT NULL,
  `wbqn` int(11) DEFAULT NULL,
  `htsxhdstfk` int(11) DEFAULT NULL,
  `zbqqjfs` int(11) DEFAULT NULL,
  `htzt` int(11) DEFAULT NULL,
  `yfkyfsj` char(10) DEFAULT NULL,
  `yskyfsj` char(10) DEFAULT NULL,
  `zbjyfsj` char(10) DEFAULT NULL,
  `zbqssj` char(10) DEFAULT NULL,
  `zbdqsj` char(10) DEFAULT NULL,
  `hthwb` int(11) DEFAULT NULL,
  `wbfyfsj` char(10) DEFAULT NULL,
  `wbdqsj` char(10) DEFAULT NULL,
  `sfypdk` int(11) DEFAULT NULL,
  `pdkje` decimal(38,2) DEFAULT NULL,
  `bz` varchar(999) DEFAULT NULL,
  `dhkyfsj` char(10) DEFAULT NULL,
  `tc` int(11) DEFAULT NULL,
  `ddyc` int(11) DEFAULT NULL,
  `fgzy` int(11) DEFAULT NULL,
  `jqlx` int(11) DEFAULT NULL,
  `jqdj` int(11) DEFAULT NULL,
  `htsxsj` char(10) DEFAULT NULL,
  `khmc` varchar(100) DEFAULT NULL,
  `lxmx` text,
  `lcbh` varchar(100) DEFAULT NULL,
  `htmcxzk` int(11) DEFAULT NULL,
  `hzlx1` text,
  `sfcrmsj` int(11) DEFAULT NULL,
  `crmbh` varchar(100) DEFAULT NULL,
  `htzx` text,
  `xmjd` text,
  `hkbl` text,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1556176906143` (`modeuuid`)
) ENGINE=InnoDB AUTO_INCREMENT=162675 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_jxkhd
-- @at 2026-11-27 16:21:02
-- @cmt bm 部门
-- @cmt bz 备注
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modeuuid 建模数据UUID
-- @cmt scfj 上传附件
CREATE TABLE `uf_jxkhd` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modeuuid` varchar(100) DEFAULT NULL,
  `bm` int(11) DEFAULT NULL,
  `bkhz` int(11) DEFAULT NULL,
  `khz` int(11) DEFAULT NULL,
  `khksrq` char(10) DEFAULT NULL,
  `khjsrq` char(10) DEFAULT NULL,
  `jxkhfs` decimal(38,2) DEFAULT NULL,
  `jxkhnf` int(11) DEFAULT NULL,
  `jxkhyf` varchar(999) DEFAULT NULL,
  `jxkhdengji` varchar(999) DEFAULT NULL,
  `jxkhpy` text,
  `scfj` text,
  `bz` varchar(999) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  `khrq` char(10) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1556605583047` (`modeuuid`)
) ENGINE=InnoDB AUTO_INCREMENT=12406 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_xctzbd
-- @at 2026-11-27 16:21:06
-- @cmt MODEUUID 建模数据UUID
-- @cmt formmodeid 建模表单ID
-- @cmt id 主键ID
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt q 季度
-- @cmt requestId 流程请求ID
-- @cmt tc 提成
CREATE TABLE `uf_xctzbd` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `fxnf` int(11) DEFAULT NULL,
  `fxyf` varchar(999) DEFAULT NULL,
  `yijibu` varchar(999) DEFAULT NULL,
  `ejbm` varchar(999) DEFAULT NULL,
  `jxrs` int(11) DEFAULT NULL,
  `jbgzyxbz` decimal(38,2) DEFAULT NULL,
  `jxjj` decimal(38,2) DEFAULT NULL,
  `tc` decimal(38,2) DEFAULT NULL,
  `glgz` decimal(38,2) DEFAULT NULL,
  `zwjt` decimal(38,2) DEFAULT NULL,
  `jbbt` decimal(38,2) DEFAULT NULL,
  `mqj` decimal(38,2) DEFAULT NULL,
  `wcbt` decimal(38,2) DEFAULT NULL,
  `wancbt` decimal(38,2) DEFAULT NULL,
  `hfgwbt` decimal(38,2) DEFAULT NULL,
  `gsce` decimal(38,2) DEFAULT NULL,
  `kqyckk` decimal(38,2) DEFAULT NULL,
  `gjjcekk` decimal(38,2) DEFAULT NULL,
  `qjqq` decimal(38,2) DEFAULT NULL,
  `q` decimal(38,2) DEFAULT NULL,
  `yfgzhj` decimal(38,2) DEFAULT NULL,
  `sbgrbf` decimal(38,2) DEFAULT NULL,
  `ybgrbf` decimal(38,2) DEFAULT NULL,
  `gjjgrbf` decimal(38,2) DEFAULT NULL,
  `sqgz` decimal(38,2) DEFAULT NULL,
  `zxkc` decimal(38,2) DEFAULT NULL,
  `grsds` decimal(38,2) DEFAULT NULL,
  `sfgzhj` decimal(38,2) DEFAULT NULL,
  `sbgsbf` decimal(38,2) DEFAULT NULL,
  `ybgsbf` decimal(38,2) DEFAULT NULL,
  `gjjgsbf` decimal(38,2) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  `MODEUUID` varchar(100) DEFAULT NULL,
  `modelableid` varchar(200) DEFAULT NULL,
  `nzj` decimal(38,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1606895977760` (`MODEUUID`)
) ENGINE=InnoDB AUTO_INCREMENT=5153 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_xfylx
-- @at 2026-11-27 16:24:00
-- @cmt MODEUUID 建模数据UUID
-- @cmt formmodeid 建模表单ID
-- @cmt id 主键ID
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt requestId 流程请求ID
CREATE TABLE `uf_xfylx` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  `MODEUUID` varchar(100) DEFAULT NULL,
  `fymc` varchar(100) DEFAULT NULL,
  `glszlx` text,
  `sfgycxzx` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1661333202864` (`MODEUUID`)
) ENGINE=InnoDB AUTO_INCREMENT=109 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_xkhjjdtz
-- @at 2026-11-27 16:21:11
-- @cmt MODEUUID 建模数据UUID
-- @cmt ddyc 订单异常
-- @cmt formmodeid 建模表单ID
-- @cmt hzlx 合作类型
-- @cmt id 主键ID
-- @cmt je 金额
-- @cmt khmc 客户名称
-- @cmt lcbh 流程编号
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt ptid 平台ID
-- @cmt requestId 流程请求ID
-- @cmt s 类型
-- @cmt tc 提成
CREATE TABLE `uf_xkhjjdtz` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `lcbh` varchar(999) DEFAULT NULL,
  `khmc` varchar(999) DEFAULT NULL,
  `ptid` varchar(999) DEFAULT NULL,
  `gslx` int(11) DEFAULT NULL,
  `jq` int(11) DEFAULT NULL,
  `lhs` varchar(999) DEFAULT NULL,
  `jcrczrxm` varchar(999) DEFAULT NULL,
  `khxgtd` int(11) DEFAULT NULL,
  `hzptgnxq` text,
  `hzxspt` varchar(999) DEFAULT NULL,
  `hzxxxt` varchar(999) DEFAULT NULL,
  `sfgmyjsb` varchar(999) DEFAULT NULL,
  `hzlx` int(11) DEFAULT NULL,
  `tc` int(11) DEFAULT NULL,
  `ddyc` int(11) DEFAULT NULL,
  `ssje` decimal(38,2) DEFAULT NULL,
  `zgdmc` varchar(999) DEFAULT NULL,
  `je` decimal(38,2) DEFAULT NULL,
  `lwf` decimal(38,2) DEFAULT NULL,
  `yhjz` int(11) DEFAULT NULL,
  `zc` varchar(999) DEFAULT NULL,
  `sjh` varchar(999) DEFAULT NULL,
  `s` int(11) DEFAULT NULL,
  `s1` int(11) DEFAULT NULL,
  `khcgjl` int(11) DEFAULT NULL,
  `sfqrjs` int(11) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  `MODEUUID` varchar(100) DEFAULT NULL,
  `zc1` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1612341145854` (`MODEUUID`)
) ENGINE=InnoDB AUTO_INCREMENT=3479 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_yskmtzbd
-- @at 2026-11-27 16:24:05
-- @cmt MODEUUID 建模数据UUID
-- @cmt formmodeid 建模表单ID
-- @cmt id 主键ID
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt requestId 流程请求ID
CREATE TABLE `uf_yskmtzbd` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `MODEUUID` varchar(100) DEFAULT NULL,
  `fykm` varchar(999) DEFAULT NULL,
  `fykmbm` varchar(999) DEFAULT NULL,
  `sjkmbm` varchar(999) DEFAULT NULL,
  `sjkm` text,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1597107991865` (`MODEUUID`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_yskmtzbd2
-- @at 2026-11-27 16:24:13
-- @cmt MODEUUID 建模数据UUID
-- @cmt formmodeid 建模表单ID
-- @cmt id 主键ID
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt requestId 流程请求ID
CREATE TABLE `uf_yskmtzbd2` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `fykm` varchar(999) DEFAULT NULL,
  `fykmbm` varchar(999) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `MODEUUID` varchar(100) DEFAULT NULL,
  `sjkmbm` text,
  `sjkmbianm` varchar(999) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1597197430694` (`MODEUUID`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_yskmtzbd3
-- @at 2026-11-27 16:24:25
-- @cmt MODEUUID 建模数据UUID
-- @cmt formmodeid 建模表单ID
-- @cmt id 主键ID
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt requestId 流程请求ID
CREATE TABLE `uf_yskmtzbd3` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `fykm` varchar(999) DEFAULT NULL,
  `fykmbm` varchar(999) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `MODEUUID` varchar(100) DEFAULT NULL,
  `sjkmbm` text,
  `sjkmbm2` varchar(999) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1597197963389` (`MODEUUID`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_yybht
-- @at 2026-11-27 16:21:15
-- @cmt MODEUUID 建模数据UUID
-- @cmt bz 备注
-- @cmt formmodeid 建模表单ID
-- @cmt htbh 合同编号
-- @cmt hzbh 合作编号
-- @cmt id 主键ID
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt qyje 区域金额
-- @cmt qyrq 区域日期
-- @cmt requestId 流程请求ID
-- @cmt xmmc 项目名称
CREATE TABLE `uf_yybht` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `hzbh` varchar(999) DEFAULT NULL,
  `htbh` varchar(999) DEFAULT NULL,
  `xmmc` varchar(999) DEFAULT NULL,
  `hzfmc` varchar(999) DEFAULT NULL,
  `wfqyr` varchar(999) DEFAULT NULL,
  `qyje` decimal(38,2) DEFAULT NULL,
  `qyrq` char(10) DEFAULT NULL,
  `lxfs` varchar(999) DEFAULT NULL,
  `qynr` text,
  `bz` varchar(999) DEFAULT NULL,
  `htsmj` text,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  `MODEUUID` varchar(100) DEFAULT NULL,
  `wfqyr1` int(11) DEFAULT NULL,
  `dsf` int(11) DEFAULT NULL,
  `khlx` int(11) DEFAULT NULL,
  `khmc` varchar(999) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1627978771547` (`MODEUUID`)
) ENGINE=InnoDB AUTO_INCREMENT=2062 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:uf_zwht
-- @at 2026-11-27 16:21:21
-- @cmt MODEUUID 建模数据UUID
-- @cmt bh 编号
-- @cmt formmodeid 建模表单ID
-- @cmt htbh 合同编号
-- @cmt htmc 合同名称
-- @cmt id 主键ID
-- @cmt modedatacreatedate 数据创建日期
-- @cmt modedatacreater 数据创建人
-- @cmt modedatacreatertype 数据创建人类型
-- @cmt modedatacreatetime 数据创建时间
-- @cmt modedatamodifier 数据修改人
-- @cmt modedatamodifydatetime 数据修改时间
-- @cmt requestId 流程请求ID
CREATE TABLE `uf_zwht` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requestId` int(11) DEFAULT NULL,
  `htbh` varchar(100) DEFAULT NULL,
  `htmc` varchar(100) DEFAULT NULL,
  `fwfyfmc` varchar(100) DEFAULT NULL,
  `htey` decimal(38,2) DEFAULT NULL,
  `bh` varchar(100) DEFAULT NULL,
  `formmodeid` int(11) DEFAULT NULL,
  `modedatacreater` int(11) DEFAULT NULL,
  `modedatacreatertype` int(11) DEFAULT NULL,
  `modedatacreatedate` varchar(10) DEFAULT NULL,
  `modedatacreatetime` varchar(8) DEFAULT NULL,
  `modedatamodifier` int(11) DEFAULT NULL,
  `modedatamodifydatetime` varchar(100) DEFAULT NULL,
  `MODEUUID` varchar(100) DEFAULT NULL,
  `qdsj` char(10) DEFAULT NULL,
  `htsc` text,
  `khmc` varchar(999) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uf_ind_1639721345730` (`MODEUUID`)
) ENGINE=InnoDB AUTO_INCREMENT=156 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:workflow_currentoperator
-- @at 2026-11-27 16:24:28
-- @cmt AGENTTYPE 代理类型
-- @cmt GROUPDETAILID 组明细ID
-- @cmt GROUPID 考勤组ID
-- @cmt ISCOMPLETE 是否完成
-- @cmt OPERATEDATE 操作日期
-- @cmt OPERATETIME 操作时间
-- @cmt RECEIVEDATE 接收日期
-- @cmt RECEIVETIME 接收时间
-- @cmt REQUESTID 流程请求ID
-- @cmt SHOWORDER 显示顺序
-- @cmt USERID 用户ID
-- @cmt USERTYPE 用户类型
-- @cmt VIEWTYPE 浏览类型
-- @cmt WORKFLOWID 流程ID
-- @cmt isremark 是否备注
-- @cmt opdatetime 操作时间
-- @cmt overtime 超时间
-- @cmt viewdate 浏览日期
-- @cmt viewtime 浏览时间
CREATE TABLE `workflow_currentoperator` (
  `REQUESTID` int(11) NOT NULL,
  `USERID` int(11) DEFAULT NULL,
  `GROUPID` int(11) DEFAULT NULL,
  `WORKFLOWID` int(11) DEFAULT NULL,
  `WORKFLOWTYPE` int(11) DEFAULT NULL,
  `USERTYPE` int(11) DEFAULT NULL,
  `NODEID` int(11) DEFAULT NULL,
  `AGENTORBYAGENTID` int(11) DEFAULT NULL,
  `AGENTTYPE` char(1) DEFAULT NULL,
  `SHOWORDER` int(11) DEFAULT NULL,
  `RECEIVEDATE` char(10) DEFAULT NULL,
  `RECEIVETIME` char(8) DEFAULT NULL,
  `VIEWTYPE` int(11) DEFAULT NULL,
  `ISCOMPLETE` int(11) DEFAULT NULL,
  `ISLASTTIMES` int(11) DEFAULT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `OPERATEDATE` char(10) DEFAULT NULL,
  `OPERATETIME` char(8) DEFAULT NULL,
  `GROUPDETAILID` int(11) DEFAULT NULL,
  `ISREMINDED` char(1) DEFAULT NULL,
  `ISPROCESSED` char(1) DEFAULT NULL,
  `WFREMINDUSER` varchar(1000) DEFAULT NULL,
  `WFUSERTYPES` varchar(800) DEFAULT NULL,
  `ISREJECT` char(1) DEFAULT NULL,
  `NEEDWFBACK` char(1) DEFAULT NULL,
  `LASTISREMARK` char(1) DEFAULT NULL,
  `ISREMINDED_CSH` char(1) DEFAULT NULL,
  `WFREMINDUSER_CSH` text,
  `WFUSERTYPES_CSH` text,
  `HANDLEFORWARDID` int(11) DEFAULT NULL,
  `TAKISREMARK` int(11) DEFAULT NULL,
  `LASTREMINDDATETIME` text,
  `isprocessing` char(1) DEFAULT NULL,
  `processUser` int(11) DEFAULT NULL,
  `isbereject` char(1) DEFAULT NULL,
  `isremark` int(11) DEFAULT NULL,
  `preisremark` int(11) DEFAULT NULL,
  `opdatetime` varchar(20) DEFAULT NULL,
  `overtime` varchar(100) DEFAULT NULL,
  `overworktime` varchar(100) DEFAULT NULL,
  `takid` int(11) DEFAULT NULL,
  `multitaklevel` int(11) DEFAULT NULL,
  `istakout` char(1) DEFAULT NULL,
  `viewdate` char(10) DEFAULT NULL,
  `viewtime` char(8) DEFAULT NULL,
  `isInMultiTak` int(11) DEFAULT NULL,
  `firstviewdate` char(10) DEFAULT NULL,
  `firstviewtime` char(8) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `IX_CURR_RID_NID` (`REQUESTID`,`NODEID`),
  KEY `USERANDREQUESTID` (`USERID`,`REQUESTID`),
  KEY `WORKFLOWUSERANDID` (`REQUESTID`,`USERID`,`WORKFLOWID`),
  KEY `WRKCUOPER_REQUESTID_IN` (`REQUESTID`,`USERID`,`USERTYPE`),
  KEY `wrkcuoper_user_in2` (`isremark`,`USERID`,`USERTYPE`)
) ENGINE=InnoDB AUTO_INCREMENT=2585041 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:workflow_nodebase
-- @at 2026-11-27 16:24:32
-- @cmt ECOLOGY_PINYIN_SEARCH 拼音检索码
-- @cmt ISEND 是否结束
-- @cmt ISSTART 是否开始
-- @cmt OPERATORS 操作人
-- @cmt OPERATORS_1 操作人1
-- @cmt REQUESTID 流程请求ID
-- @cmt SIGNTYPE 签到类型
-- @cmt TOTALGROUPS 总组
-- @cmt uuid UUID
CREATE TABLE `workflow_nodebase` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `NODENAME` varchar(480) DEFAULT NULL,
  `ISSTART` char(1) DEFAULT NULL,
  `ISREJECT` char(1) DEFAULT NULL,
  `ISREOPEN` char(1) DEFAULT NULL,
  `ISEND` char(1) DEFAULT NULL,
  `DRAWXPOS` int(11) DEFAULT NULL,
  `DRAWYPOS` int(11) DEFAULT NULL,
  `TOTALGROUPS` int(11) DEFAULT NULL,
  `NODEATTRIBUTE` char(1) DEFAULT NULL,
  `PASSNUM` int(11) DEFAULT NULL,
  `ISFREENODE` char(1) DEFAULT NULL,
  `FLOWORDER` int(11) DEFAULT NULL,
  `SIGNTYPE` char(1) DEFAULT NULL,
  `OPERATORS_1` varchar(1000) DEFAULT NULL,
  `REQUESTID` int(11) DEFAULT NULL,
  `STARTNODEID` int(11) DEFAULT NULL,
  `OPERATORS` longtext,
  `ECOLOGY_PINYIN_SEARCH` varchar(1000) DEFAULT NULL,
  `drawstyle` varchar(1000) DEFAULT NULL,
  `uuid` varchar(50) DEFAULT '0',
  KEY `IX_WORKFLOW_NDBS_IR` (`ISFREENODE`,`REQUESTID`,`STARTNODEID`,`id`),
  KEY `IX_WORKFLOW_NODEBASE_IDIS` (`id`,`ISFREENODE`)
) ENGINE=InnoDB AUTO_INCREMENT=5370 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:workflow_nownode
-- @at 2026-11-27 16:24:35
-- @cmt REQUESTID 流程请求ID
CREATE TABLE `workflow_nownode` (
  `REQUESTID` int(11) DEFAULT NULL,
  `NOWNODEID` int(11) DEFAULT NULL,
  `NOWNODETYPE` int(11) DEFAULT NULL,
  `NOWNODEATTRIBUTE` int(11) DEFAULT NULL,
  KEY `WORKFLOW_NOWNODE_IN` (`REQUESTID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:workflow_requestbase
-- @at 2026-11-27 16:24:40
-- @cmt CREATEDATE 创建日期
-- @cmt CREATER 创建人
-- @cmt CREATETIME 开始时间
-- @cmt CRMIDS CRMID
-- @cmt CURRENTSTATUS 当前状态
-- @cmt DELETED 删除
-- @cmt ECOLOGY_PINYIN_SEARCH 拼音检索码
-- @cmt LASTOPERATOR 最近操作人
-- @cmt LASTSTATUS 最近状态
-- @cmt MESSAGETYPE 消息类型
-- @cmt REQUESTID 流程请求ID
-- @cmt REQUESTLEVEL 请求级别
-- @cmt REQUESTMARK 请求标记
-- @cmt REQUESTNAME 请求名称
-- @cmt STATUS 状态
-- @cmt TOTALGROUPS 总组
-- @cmt WORKFLOWID 流程ID
-- @cmt remindTypes 提醒类型
-- @cmt secLevel 安全级别
CREATE TABLE `workflow_requestbase` (
  `REQUESTID` int(11) NOT NULL,
  `WORKFLOWID` int(11) DEFAULT NULL,
  `LASTNODEID` int(11) DEFAULT NULL,
  `LASTNODETYPE` char(1) DEFAULT NULL,
  `CURRENTNODEID` int(11) DEFAULT NULL,
  `CURRENTNODETYPE` char(1) DEFAULT NULL,
  `STATUS` varchar(1000) DEFAULT NULL,
  `PASSEDGROUPS` int(11) DEFAULT NULL,
  `TOTALGROUPS` int(11) DEFAULT NULL,
  `REQUESTNAME` varchar(1000) DEFAULT NULL,
  `CREATER` int(11) DEFAULT NULL,
  `CREATEDATE` char(10) DEFAULT NULL,
  `CREATETIME` char(8) DEFAULT NULL,
  `LASTOPERATOR` int(11) DEFAULT NULL,
  `LASTOPERATEDATE` char(10) DEFAULT NULL,
  `LASTOPERATETIME` char(8) DEFAULT NULL,
  `DELETED` int(11) DEFAULT '0',
  `CREATERTYPE` int(11) DEFAULT '0',
  `LASTOPERATORTYPE` int(11) DEFAULT '0',
  `NODEPASSTIME` double DEFAULT '-1',
  `NODELEFTTIME` double DEFAULT '-1',
  `DOCIDS` text,
  `CRMIDS` text,
  `HRMIDS_TEMP` text,
  `PRJIDS` text,
  `CPTIDS` text,
  `REQUESTLEVEL` int(11) DEFAULT '0',
  `REQUESTMARK` varchar(800) DEFAULT NULL,
  `MESSAGETYPE` int(11) DEFAULT NULL,
  `MAINREQUESTID` int(11) DEFAULT NULL,
  `CURRENTSTATUS` int(11) DEFAULT NULL,
  `LASTSTATUS` varchar(480) DEFAULT NULL,
  `ISMULTIPRINT` int(11) DEFAULT '0',
  `CHATSTYPE` int(11) DEFAULT NULL,
  `ECOLOGY_PINYIN_SEARCH` varchar(1000) DEFAULT NULL,
  `HRMIDS` longtext,
  `REQUESTNAMENEW` text,
  `FORMSIGNATUREMD5` text,
  `DATAAGGREGATED` char(1) DEFAULT NULL,
  `secLevel` char(1) DEFAULT NULL,
  `secdocid` varchar(500) DEFAULT NULL,
  `remindTypes` varchar(40) DEFAULT NULL,
  `lastFeedBackDate` char(10) DEFAULT NULL,
  `lastFeedBackTime` char(8) DEFAULT NULL,
  `lastfeedbackoperator` int(11) DEFAULT NULL,
  `requestnamehtmlnew` varchar(4000) DEFAULT NULL,
  `secvalidity` varchar(50) DEFAULT NULL,
  `secencKey` varchar(200) DEFAULT NULL,
  `seccrc` varchar(100) DEFAULT NULL,
  UNIQUE KEY `WORKFLOW_REQUESTID` (`REQUESTID`),
  KEY `WRKREQBASE_REQUEST_IN` (`WORKFLOWID`,`REQUESTID`),
  KEY `WRKREQBASE_REQUEST_IN2` (`CREATER`,`CREATERTYPE`),
  KEY `IDANDSTATUS` (`REQUESTID`,`STATUS`),
  KEY `idx_wfrequestbase_requestlevel` (`REQUESTLEVEL`),
  KEY `WORKFLOW_REQUEST_MAINREQID` (`MAINREQUESTID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:workflow_requestlog
-- @at 2026-11-27 16:24:53
-- @cmt AGENTTYPE 代理类型
-- @cmt ISMOBILE 是否手机号
-- @cmt LOGTYPE 日志类型
-- @cmt OPERATEDATE 操作日期
-- @cmt OPERATETIME 操作时间
-- @cmt OPERATOR 操作人
-- @cmt OPERATORDEPT 操作人部门
-- @cmt OPERATORTYPE 操作人类型
-- @cmt REMARK 备注
-- @cmt REMARKLOCATION 备注位置
-- @cmt REQUESTID 流程请求ID
-- @cmt SHOWORDER 显示顺序
-- @cmt SIGNWORKFLOWIDS 签约流程ID
-- @cmt WORKFLOWID 流程ID
-- @cmt operatorJob 操作人作业
-- @cmt operatorSub 操作人子
-- @cmt seclevel 安全级别
-- @cmt uuid UUID
CREATE TABLE `workflow_requestlog` (
  `REQUESTID` int(11) DEFAULT NULL,
  `WORKFLOWID` int(11) DEFAULT NULL,
  `NODEID` int(11) DEFAULT NULL,
  `LOGTYPE` char(1) DEFAULT NULL,
  `OPERATEDATE` char(10) DEFAULT NULL,
  `OPERATETIME` char(8) DEFAULT NULL,
  `OPERATOR` int(11) DEFAULT NULL,
  `REMARK1` text,
  `clientip` varchar(1000) DEFAULT NULL,
  `OPERATORTYPE` int(11) DEFAULT '0',
  `DESTNODEID` int(11) DEFAULT '0',
  `RECEIVEDPERSONS_1` text,
  `SHOWORDER` int(11) DEFAULT NULL,
  `AGENTORBYAGENTID` int(11) DEFAULT NULL,
  `AGENTTYPE` char(1) DEFAULT NULL,
  `LOGID` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `REMARK` longtext,
  `ANNEXDOCIDS` text,
  `REQUESTLOGID` int(11) NOT NULL DEFAULT '0',
  `OPERATORDEPT` int(11) DEFAULT NULL,
  `SIGNDOCIDS` varchar(1000) DEFAULT NULL,
  `SIGNWORKFLOWIDS` varchar(1000) DEFAULT NULL,
  `RECEIVEDPERSONS` longtext,
  `ISMOBILE` char(1) DEFAULT NULL,
  `HandWrittenSign` varchar(300) DEFAULT NULL,
  `SPEECHATTACHMENT` int(11) DEFAULT NULL,
  `RECEIVEDPERSONIDS` longtext,
  `REMARKLOCATION` text,
  `isSubmitDirect` char(1) DEFAULT NULL,
  `remarkquote` text,
  `fulltextannotation` varchar(1000) DEFAULT NULL,
  `speechattachmente9` varchar(1000) DEFAULT NULL,
  `uuid` varchar(100) DEFAULT NULL,
  `operatorSub` int(11) DEFAULT NULL,
  `operatorJob` int(11) DEFAULT NULL,
  `isRobotNode` char(1) DEFAULT NULL,
  `seclevel` varchar(10) DEFAULT NULL,
  KEY `IX_WORKFLOW_REQUESTLOG_LID` (`LOGID`),
  KEY `WORKFLOW_REQUESTLOG_ODX` (`OPERATOR`,`OPERATORTYPE`),
  KEY `WRKREQLOG_REQUEST_IN` (`REQUESTID`,`LOGTYPE`),
  KEY `idx_wf_req_group` (`NODEID`,`REQUESTID`,`LOGTYPE`)
) ENGINE=InnoDB AUTO_INCREMENT=1403834 DEFAULT CHARSET=utf8;

-- @table RDS_oa_ecology:workflow_requestoperatelog
-- @at 2026-11-27 16:24:57
-- @cmt INVALIDDATE 失效日期
-- @cmt INVALIDID 失效ID
-- @cmt INVALIDTIME 失效时间
-- @cmt ISINVALID 是否失效
-- @cmt ISREMARK 是否备注
-- @cmt OPERATECODE 操作编码
-- @cmt OPERATEDATE 操作日期
-- @cmt OPERATENAME 操作名称
-- @cmt OPERATETIME 操作时间
-- @cmt OPERATETYPE 操作类型
-- @cmt OPERATORID 操作人ID
-- @cmt OPERATORTYPE 操作人类型
-- @cmt REQUESTID 流程请求ID
-- @cmt RETYPE 重新类型
-- @cmt Withdraw 提现
CREATE TABLE `workflow_requestoperatelog` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `REQUESTID` int(11) DEFAULT NULL,
  `NODEID` int(11) DEFAULT NULL,
  `ISREMARK` int(11) DEFAULT NULL,
  `OPERATORID` int(11) DEFAULT NULL,
  `OPERATORTYPE` int(11) DEFAULT NULL,
  `OPERATEDATE` varchar(80) DEFAULT NULL,
  `OPERATETIME` varchar(64) DEFAULT NULL,
  `OPERATETYPE` varchar(200) DEFAULT NULL,
  `OPERATENAME` varchar(800) DEFAULT NULL,
  `OPERATECODE` int(11) DEFAULT NULL,
  `ISINVALID` char(1) DEFAULT NULL,
  `INVALIDID` int(11) DEFAULT NULL,
  `INVALIDDATE` varchar(80) DEFAULT NULL,
  `INVALIDTIME` varchar(64) DEFAULT NULL,
  `detailInfo` longtext,
  `RETYPE` char(1) DEFAULT NULL,
  `REOPERATORID` varchar(20) DEFAULT NULL,
  `Withdraw` char(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `WORKFLOW_REQUESTOPERATELOG_IX` (`REQUESTID`,`ISINVALID`),
  KEY `operatorid_index` (`OPERATORID`)
) ENGINE=InnoDB AUTO_INCREMENT=1055856 DEFAULT CHARSET=utf8;

-- @table RDS_open_data_api:scenic_inout_hour_summary
-- @at 2026-11-27 15:14:20
-- @cmt employee 员工卡
-- @cmt in 入园人数
-- @cmt out 出园人数
CREATE TABLE `scenic_inout_hour_summary` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `gid` int NOT NULL DEFAULT '0' COMMENT '统计组id',
  `date` int NOT NULL DEFAULT '0' COMMENT '统计日期，年月日-20230529',
  `week` int NOT NULL DEFAULT '0' COMMENT '统计年周，例如202352',
  `i0` int NOT NULL DEFAULT '0' COMMENT '入园人数 00:00~00:59',
  `o0` int NOT NULL DEFAULT '0' COMMENT '出园人数 00:00~00:59',
  `e0` int NOT NULL DEFAULT '0' COMMENT '员工卡 00:00~00:59',
  `i1` int NOT NULL DEFAULT '0' COMMENT '入园人数 01:00~01:59',
  `o1` int NOT NULL DEFAULT '0' COMMENT '出园人数 01:00~01:59',
  `e1` int NOT NULL DEFAULT '0' COMMENT '员工卡 01:00~01:59',
  `i2` int NOT NULL DEFAULT '0' COMMENT '入园人数 02:00~02:59',
  `o2` int NOT NULL DEFAULT '0' COMMENT '出园人数 02:00~02:59',
  `e2` int NOT NULL DEFAULT '0' COMMENT '员工卡 02:00~02:59',
  `i3` int NOT NULL DEFAULT '0' COMMENT '入园人数 03:00~03:59',
  `o3` int NOT NULL DEFAULT '0' COMMENT '出园人数 03:00~03:59',
  `e3` int NOT NULL DEFAULT '0' COMMENT '员工卡 03:00~03:59',
  `i4` int NOT NULL DEFAULT '0' COMMENT '入园人数 04:00~04:59',
  `o4` int NOT NULL DEFAULT '0' COMMENT '出园人数 04:00~04:59',
  `e4` int NOT NULL DEFAULT '0' COMMENT '员工卡 04:00~04:59',
  `i5` int NOT NULL DEFAULT '0' COMMENT '入园人数 05:00~05:59',
  `o5` int NOT NULL DEFAULT '0' COMMENT '出园人数 05:00~05:59',
  `e5` int NOT NULL DEFAULT '0' COMMENT '员工卡 05:00~05:59',
  `i6` int NOT NULL DEFAULT '0' COMMENT '入园人数 06:00~06:59',
  `o6` int NOT NULL DEFAULT '0' COMMENT '出园人数 06:00~06:59',
  `e6` int NOT NULL DEFAULT '0' COMMENT '员工卡 06:00~06:59',
  `i7` int NOT NULL DEFAULT '0' COMMENT '入园人数 07:00~07:59',
  `o7` int NOT NULL DEFAULT '0' COMMENT '出园人数 07:00~07:59',
  `e7` int NOT NULL DEFAULT '0' COMMENT '员工卡 07:00~07:59',
  `i8` int NOT NULL DEFAULT '0' COMMENT '入园人数 08:00~08:59',
  `o8` int NOT NULL DEFAULT '0' COMMENT '出园人数 08:00~08:59',
  `e8` int NOT NULL DEFAULT '0' COMMENT '员工卡 08:00~08:59',
  `i9` int NOT NULL DEFAULT '0' COMMENT '入园人数 09:00~09:59',
  `o9` int NOT NULL DEFAULT '0' COMMENT '出园人数 09:00~09:59',
  `e9` int NOT NULL DEFAULT '0' COMMENT '员工卡 09:00~09:59',
  `i10` int NOT NULL DEFAULT '0' COMMENT '入园人数 10:00~10:59',
  `o10` int NOT NULL DEFAULT '0' COMMENT '出园人数 10:00~10:59',
  `e10` int NOT NULL DEFAULT '0' COMMENT '员工卡 10:00~10:59',
  `i11` int NOT NULL DEFAULT '0' COMMENT '入园人数 11:00~11:59',
  `o11` int NOT NULL DEFAULT '0' COMMENT '出园人数 11:00~11:59',
  `e11` int NOT NULL DEFAULT '0' COMMENT '员工卡 11:00~11:59',
  `i12` int NOT NULL DEFAULT '0' COMMENT '入园人数 12:00~12:59',
  `o12` int NOT NULL DEFAULT '0' COMMENT '出园人数 12:00~12:59',
  `e12` int NOT NULL DEFAULT '0' COMMENT '员工卡 12:00~12:59',
  `i13` int NOT NULL DEFAULT '0' COMMENT '入园人数 13:00~13:59',
  `o13` int NOT NULL DEFAULT '0' COMMENT '出园人数 13:00~13:59',
  `e13` int NOT NULL DEFAULT '0' COMMENT '员工卡 13:00~13:59',
  `i14` int NOT NULL DEFAULT '0' COMMENT '入园人数 14:00~14:59',
  `o14` int NOT NULL DEFAULT '0' COMMENT '出园人数 14:00~14:59',
  `e14` int NOT NULL DEFAULT '0' COMMENT '员工卡 14:00~14:59',
  `i15` int NOT NULL DEFAULT '0' COMMENT '入园人数 15:00~15:59',
  `o15` int NOT NULL DEFAULT '0' COMMENT '出园人数 15:00~15:59',
  `e15` int NOT NULL DEFAULT '0' COMMENT '员工卡 15:00~15:59',
  `i16` int NOT NULL DEFAULT '0' COMMENT '入园人数 16:00~16:59',
  `o16` int NOT NULL DEFAULT '0' COMMENT '出园人数 16:00~16:59',
  `e16` int NOT NULL DEFAULT '0' COMMENT '员工卡 16:00~16:59',
  `i17` int NOT NULL DEFAULT '0' COMMENT '入园人数 17:00~17:59',
  `o17` int NOT NULL DEFAULT '0' COMMENT '出园人数 17:00~17:59',
  `e17` int NOT NULL DEFAULT '0' COMMENT '员工卡 17:00~17:59',
  `i18` int NOT NULL DEFAULT '0' COMMENT '入园人数 18:00~18:59',
  `o18` int NOT NULL DEFAULT '0' COMMENT '出园人数 18:00~18:59',
  `e18` int NOT NULL DEFAULT '0' COMMENT '员工卡 18:00~18:59',
  `i19` int NOT NULL DEFAULT '0' COMMENT '入园人数 19:00~19:59',
  `o19` int NOT NULL DEFAULT '0' COMMENT '出园人数 19:00~19:59',
  `e19` int NOT NULL DEFAULT '0' COMMENT '员工卡 19:00~19:59',
  `i20` int NOT NULL DEFAULT '0' COMMENT '入园人数 20:00~20:59',
  `o20` int NOT NULL DEFAULT '0' COMMENT '出园人数 20:00~20:59',
  `e20` int NOT NULL DEFAULT '0' COMMENT '员工卡 20:00~20:59',
  `i21` int NOT NULL DEFAULT '0' COMMENT '入园人数 21:00~21:59',
  `o21` int NOT NULL DEFAULT '0' COMMENT '出园人数 21:00~21:59',
  `e21` int NOT NULL DEFAULT '0' COMMENT '员工卡 21:00~21:59',
  `i22` int NOT NULL DEFAULT '0' COMMENT '入园人数 22:00~22:59',
  `o22` int NOT NULL DEFAULT '0' COMMENT '出园人数 22:00~22:59',
  `e22` int NOT NULL DEFAULT '0' COMMENT '员工卡 22:00~22:59',
  `i23` int NOT NULL DEFAULT '0' COMMENT '入园人数 23:00~23:59',
  `o23` int NOT NULL DEFAULT '0' COMMENT '出园人数 23:00~23:59',
  `e23` int NOT NULL DEFAULT '0' COMMENT '员工卡 23:00~23:59',
  `in` int NOT NULL DEFAULT '0' COMMENT '入园人数 全天合计',
  `out` int NOT NULL DEFAULT '0' COMMENT '出园人数 全天合计',
  `employee` int NOT NULL DEFAULT '0' COMMENT '员工卡 全天合计',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_gid_date` (`gid`,`date`)
) ENGINE=InnoDB AUTO_INCREMENT=143768 DEFAULT CHARSET=utf8mb3 COMMENT='景区出入园小时统计表';

-- @table RDS_open_data_api:scenic_inout_summary_group
-- @at 2026-11-27 15:14:34
CREATE TABLE `scenic_inout_summary_group` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `sid` int NOT NULL DEFAULT '0' COMMENT '景区id',
  `serial_no` varchar(32) NOT NULL DEFAULT '' COMMENT '随机生成的统计组序列号',
  `name` varchar(64) NOT NULL DEFAULT '' COMMENT '统计组名称',
  `gates` json DEFAULT NULL COMMENT '闸机key数值， 例如["a","b"]',
  `delete_at` datetime DEFAULT NULL COMMENT '软删除标记',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `capacity` int NOT NULL DEFAULT '0' COMMENT '瞬时承载量',
  `upper_limit` int NOT NULL DEFAULT '0' COMMENT '上限',
  `config` json DEFAULT NULL COMMENT '客流配置,格式:[{"label":"舒适","min":0,"max":100,"color":"#fff"}]',
  `sid_gates_hash` varchar(32) NOT NULL DEFAULT '' COMMENT 'sid和gates的哈希值，用作检测供应商统计组唯一字段',
  `ext` json NOT NULL COMMENT '扩展配置',
  `source` tinyint NOT NULL DEFAULT '1' COMMENT '来源，1=手动创建，2=终端节点同步',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uni_serial_no` (`serial_no`),
  KEY `sid_index` (`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=564 DEFAULT CHARSET=utf8mb3 COMMENT='景区出入园统计组表';

-- @table RDS_oracle:dim_ogn_oa_staff_info_d
-- @at 2026-11-27 16:17:24
-- @cmt age 年龄
-- @cmt belong_group 所属组
-- @cmt belong_group_id 所属组ID
-- @cmt birthday 生日
-- @cmt birthday_month 生日月份
-- @cmt certificatenum 身份证号
-- @cmt companystartdate 入职日期
-- @cmt companyworkyear 司龄
-- @cmt csrq 出生日期
-- @cmt degree 学位
-- @cmt departmentid 部门ID
-- @cmt departmentname 部门名称
-- @cmt educationlevel 学历
-- @cmt educationlevel_name 学历名称
-- @cmt email 邮箱
-- @cmt enddate 结束日期
-- @cmt folk 民族
-- @cmt homeaddress 归属地址
-- @cmt htlx 合同类型
-- @cmt hyzt 行业状态
-- @cmt id 主键ID
-- @cmt id_card_address ID卡地址
-- @cmt id_card_valid_date ID卡有效日期
-- @cmt job_level 作业级别
-- @cmt job_name 作业名称
-- @cmt jobtitle 岗位ID
-- @cmt join_date 参与日期
-- @cmt jsrq 结束日期
-- @cmt ksrq 开始日期
-- @cmt lastname 姓名
-- @cmt left_date 剩余日期
-- @cmt left_type 剩余类型
-- @cmt location_desc 位置描述
-- @cmt locationid 办公地点ID
-- @cmt loginid 登录账号
-- @cmt lv1_team 一级团队
-- @cmt lv1_team_id 一级团队ID
-- @cmt lv2_team 二级团队
-- @cmt lv2_team_id 二级团队ID
-- @cmt lv3_team 三级团队
-- @cmt lv3_team_id 三级团队ID
-- @cmt managerid 直属上级ID
-- @cmt managerstr 上级链路
-- @cmt mobile 手机号
-- @cmt modified 修改时间
-- @cmt policy 政治面貌
-- @cmt probationenddate 试用期结束日期
-- @cmt residentplace 现居住地
-- @cmt sex 性别
-- @cmt sqrq 申请日期
-- @cmt startdate 开始日期
-- @cmt status 状态
-- @cmt status_desc 状态描述
-- @cmt workcode 工号
-- @cmt workroom 办公室
-- @cmt workstartdate 参加工作日期
-- @cmt workyear 工龄
-- @cmt xxmc 信息名称
create table DIM_OGN_OA_STAFF_INFO_D
(
  id                     NUMBER,
  loginid                VARCHAR2(50),
  lastname               VARCHAR2(100),
  sex                    VARCHAR2(50),
  birthday               VARCHAR2(50),
  mobile                 VARCHAR2(50),
  locationid             NUMBER,
  workroom               VARCHAR2(300),
  jobtitle               NUMBER,
  job_name               VARCHAR2(100),
  job_level              VARCHAR2(100),
  departmentid           NUMBER,
  departmentname         VARCHAR2(100),
  lv1_team_id            NUMBER,
  lv1_team               VARCHAR2(100),
  lv2_team_id            NUMBER,
  lv2_team               VARCHAR2(100),
  lv3_team_id            NUMBER,
  lv3_team               VARCHAR2(100),
  full_dep_name          VARCHAR2(200),
  belong_group_id        NUMBER,
  belong_group           VARCHAR2(100),
  managerid              NUMBER,
  manager_name           VARCHAR2(100),
  managerstr             VARCHAR2(100),
  educationlevel         NUMBER,
  educationlevel_name    VARCHAR2(100),
  workcode               NUMBER,
  degree                 VARCHAR2(100),
  status                 NUMBER,
  status_desc            VARCHAR2(100),
  startdate              VARCHAR2(50),
  enddate                VARCHAR2(50),
  join_date              VARCHAR2(50),
  probationenddate       VARCHAR2(50),
  is_left_format         VARCHAR2(50),
  sqrq                   VARCHAR2(50),
  nlzrq                  VARCHAR2(50),
  left_date              VARCHAR2(50),
  lzlx                   VARCHAR2(50),
  left_type              VARCHAR2(50),
  lzyy                   VARCHAR2(1000),
  companystartdate       VARCHAR2(50),
  companyworkyear        VARCHAR2(50),
  workstartdate          VARCHAR2(50),
  workyear               VARCHAR2(50),
  ishas_other_id         VARCHAR2(50),
  certificatenum         VARCHAR2(50),
  gz                     VARCHAR2(50),
  is_guidan_leftworkflow VARCHAR2(50),
  zzrq                   VARCHAR2(50),
  homeaddress            VARCHAR2(1000),
  residentplace          VARCHAR2(1000),
  xxmc                   VARCHAR2(500),
  zy                     VARCHAR2(500),
  ksrq                   VARCHAR2(50),
  jsrq                   VARCHAR2(50),
  email                  VARCHAR2(50),
  location_desc          VARCHAR2(500),
  syq                    VARCHAR2(50),
  zply                   VARCHAR2(50),
  id_card_address        VARCHAR2(500),
  id_card_valid_date     VARCHAR2(50),
  id_card_register       VARCHAR2(500),
  id_card_register_type  VARCHAR2(50),
  csrq                   VARCHAR2(50),
  folk                   VARCHAR2(50),
  hyzt                   VARCHAR2(50),
  policy                 VARCHAR2(50),
  birthday_month         VARCHAR2(50),
  age                    VARCHAR2(50),
  gzkh                   VARCHAR2(500),
  gzkkhh                 VARCHAR2(500),
  htgs                   VARCHAR2(500),
  htlx                   VARCHAR2(50),
  schtqsr                VARCHAR2(50),
  schtdqr                VARCHAR2(50),
  xhtksrq                VARCHAR2(50),
  xhtjsrq                VARCHAR2(50),
  htqx                   VARCHAR2(50),
  xqcs                   VARCHAR2(50),
  emergency_name         VARCHAR2(500),
  emergency_relation     VARCHAR2(500),
  emergency_phone        VARCHAR2(50),
  other_id               VARCHAR2(50),
  fs_status              NUMBER,
  modified               DATE,
  whitestate             VARCHAR2(50),
  sum_date               VARCHAR2(30),
  is_four_role           NUMBER,
  ldhtzt                 NUMBER,
  m_job_level            VARCHAR2(10)
)
tablespace USERS
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

-- @table RDS_pft_ai:ads_scenic_customer_insight_basic_profile_mo
-- @at 2026-11-27 11:15:13
CREATE TABLE `ads_scenic_customer_insight_basic_profile_mo` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `scenic_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区ID',
  `scenic_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区名称',
  `period_granularity` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N' COMMENT '周期粒度: N=常规单期快照, 其他如 2025H1/2026H1 表示对比周期标识',
  `metric_level` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '维度类型: 性别 / 年龄 / 学历 / 人生阶段 / 有孩一族',
  `tag_value` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '标签值, 如: 男/女, 18-24, 本科, 上班族, 是/否',
  `proportion` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '占比 (%)',
  `tgi` int NOT NULL DEFAULT '0' COMMENT 'TGI值',
  `national_baseline` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '全国对照值 (%)',
  `ranking` int NOT NULL DEFAULT '0' COMMENT '排序 (维度内顺序)',
  `etl_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ETL更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_scenic_id` (`scenic_id`),
  KEY `idx_metric_level` (`metric_level`)
) ENGINE=InnoDB AUTO_INCREMENT=660 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ADS-景区客群洞察-基础人群画像 (性别/年龄/学历/人生阶段/有孩一族)';

-- @table RDS_pft_ai:ads_scenic_customer_insight_hot_poi_mo
-- @at 2026-11-27 11:16:04
CREATE TABLE `ads_scenic_customer_insight_hot_poi_mo` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `scenic_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区ID',
  `scenic_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区名称',
  `period_granularity` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N' COMMENT '周期粒度: N=常规单期快照, 其他如 2025H1/2026H1 表示对比周期标识',
  `metric_level` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'POI类别: 美食/购物/旅游景点/酒店宾馆/文化场馆/教育学校/娱乐休闲/基础设施/生活服务/生活服务:旅行社',
  `ranking` int NOT NULL COMMENT '类别内排名',
  `poi_name` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'POI名称',
  `city` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '所属城市',
  `address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '详细地址',
  `category_detail` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '类别明细, 如: 基础设施:交通设施:火车站',
  `popularity` int NOT NULL DEFAULT '0' COMMENT '热度值',
  `ext_info` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '扩展信息, 如: 景区级别5A',
  `longitude` decimal(10,6) DEFAULT NULL COMMENT '经度',
  `latitude` decimal(10,6) DEFAULT NULL COMMENT '纬度',
  `etl_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ETL更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_scenic_id` (`scenic_id`),
  KEY `idx_metric_level` (`metric_level`),
  KEY `idx_city` (`city`)
) ENGINE=InnoDB AUTO_INCREMENT=4730 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ADS-景区客群洞察-热门到访地明细';

-- @table RDS_pft_ai:ads_scenic_customer_insight_hot_visits_mo
-- @at 2026-11-27 11:16:28
CREATE TABLE `ads_scenic_customer_insight_hot_visits_mo` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `scenic_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区ID',
  `scenic_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区名称',
  `period_granularity` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N' COMMENT '周期粒度: N=常规单期快照, 其他如 2025H1/2026H1 表示对比周期标识',
  `metric_level` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'POI类别: 美食/购物/旅游景点/酒店宾馆/文化场馆/教育学校/娱乐休闲/基础设施/生活服务/生活服务:旅行社',
  `ranking` int NOT NULL COMMENT '类别内排名',
  `poi_name` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'POI名称',
  `city` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '所属城市',
  `popularity` int NOT NULL DEFAULT '0' COMMENT '热度值',
  `address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '详细地址',
  `etl_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ETL更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_scenic_id` (`scenic_id`),
  KEY `idx_metric_level` (`metric_level`)
) ENGINE=InnoDB AUTO_INCREMENT=2810 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ADS-景区客群洞察-热门到访地';

-- @table RDS_pft_ai:ads_scenic_customer_insight_kpi_mo
-- @at 2026-11-27 11:16:44
CREATE TABLE `ads_scenic_customer_insight_kpi_mo` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `scenic_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区ID',
  `scenic_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区名称',
  `period_granularity` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N' COMMENT '周期粒度: N=常规单期快照, 其他如 2025H1/2026H1 表示对比周期标识',
  `metric_level` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '指标级别: 核心 / 次级',
  `metric_category` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '指标分类: 客源构成 / 人群属性 / 学历构成 / 消费水平 / 景区粘性 / 年龄构成 / 性别构成 / 出行方式 / 餐饮消费 / 酒店消费 / 设备消费 / 出游季节 / 购物偏好 / 人生阶段',
  `metric_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '指标名称',
  `metric_value` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '指标数值',
  `metric_unit` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '%' COMMENT '单位: % / 人 / 元 等',
  `tgi` int NOT NULL DEFAULT '0' COMMENT 'TGI值, 0 表示无对照数据',
  `insight_interpretation` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '指标解读',
  `mom_growth_rate` decimal(18,6) NOT NULL DEFAULT '0.000000' COMMENT '环比增长率(%): 较新周期相对较早周期的增长率, 无可比数据时为0',
  `etl_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ETL更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_scenic_id` (`scenic_id`),
  KEY `idx_metric_level` (`metric_level`),
  KEY `idx_metric_category` (`metric_category`)
) ENGINE=InnoDB AUTO_INCREMENT=1071 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ADS-景区客群洞察-核心KPI指标';

-- @table RDS_pft_ai:ads_scenic_customer_insight_source_distribution_mo
-- @at 2026-11-27 11:17:00
CREATE TABLE `ads_scenic_customer_insight_source_distribution_mo` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `scenic_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区ID',
  `scenic_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区名称',
  `period_granularity` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N' COMMENT '周期粒度: N=常规单期快照, 其他如 2025H1/2026H1 表示对比周期标识',
  `metric_level` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '来源类型: 常驻城市 / 活跃商圈',
  `ranking` int NOT NULL COMMENT '排名 (类型内)',
  `name` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '城市/商圈名称, 如: 江苏省-扬州市, 上海市-上海市-外滩商圈',
  `proportion` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '占比 (%)',
  `etl_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ETL更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_scenic_id` (`scenic_id`),
  KEY `idx_metric_level` (`metric_level`),
  KEY `idx_name` (`name`(64))
) ENGINE=InnoDB AUTO_INCREMENT=1754 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ADS-景区客群洞察-客源分布 (常驻城市/活跃商圈)';

-- @table RDS_pft_ai:ads_scenic_customer_insight_source_ranking_mo
-- @at 2026-11-27 11:17:56
CREATE TABLE `ads_scenic_customer_insight_source_ranking_mo` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `scenic_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区ID',
  `scenic_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区名称',
  `period_granularity` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N' COMMENT '周期粒度: N=常规单期快照, 其他如 2025H1/2026H1 表示对比周期标识',
  `metric_level` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '统计类型: 客源省份 / 客源城市',
  `ranking` int NOT NULL COMMENT '类型内排名',
  `name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '省/市名称',
  `proportion` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '占游客总数比例 (%)',
  `remark` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注说明',
  `yoy_growth_rate` decimal(18,6) NOT NULL DEFAULT '0.000000' COMMENT '同比增长率(%): 较新周期相对较早周期的增长率, 无可比数据时为0',
  `etl_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ETL更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_scenic_id` (`scenic_id`),
  KEY `idx_metric_level` (`metric_level`),
  KEY `idx_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=14897 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ADS-景区客群洞察-客源地 (省/市切换)';

-- @table RDS_pft_ai:ads_scenic_customer_insight_travel_behavior_mo
-- @at 2026-11-27 11:18:21
CREATE TABLE `ads_scenic_customer_insight_travel_behavior_mo` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `scenic_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区ID',
  `scenic_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区名称',
  `period_granularity` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N' COMMENT '周期粒度: N=常规单期快照, 其他如 2025H1/2026H1 表示对比周期标识',
  `metric_level` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '旅行维度: 旅游距离 / 出游月份',
  `tag_value` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '标签值, 如: 长途/中途/近途/无出游, 01月-12月',
  `proportion` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '占比 (%)',
  `tgi` int NOT NULL DEFAULT '0' COMMENT 'TGI值',
  `national_baseline` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '全国对照值 (%)',
  `ranking` int NOT NULL DEFAULT '0' COMMENT '排序 (维度内顺序)',
  `etl_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ETL更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_scenic_id` (`scenic_id`),
  KEY `idx_metric_level` (`metric_level`)
) ENGINE=InnoDB AUTO_INCREMENT=494 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ADS-景区客群洞察-旅行行为 (距离/月份)';

-- @table RDS_pft_ai:ads_scenic_customer_insight_visit_preference_mo
-- @at 2026-11-27 11:18:35
CREATE TABLE `ads_scenic_customer_insight_visit_preference_mo` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `scenic_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区ID',
  `scenic_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区名称',
  `period_granularity` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N' COMMENT '周期粒度: N=常规单期快照, 其他如 2025H1/2026H1 表示对比周期标识',
  `metric_level` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '偏好类型: 美食偏好/购物偏好/酒店偏好/景点偏好',
  `preference_object` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '偏好对象, 如: 小吃快餐/综合商场/星级酒店/国家级景点',
  `proportion` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '偏好占比 (%)',
  `tgi` int NOT NULL DEFAULT '0' COMMENT 'TGI值',
  `national_baseline` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '全国对照值 (%)',
  `ranking` int NOT NULL DEFAULT '0' COMMENT '在该偏好类型内的排名',
  `yoy_growth_rate` decimal(16,6) NOT NULL DEFAULT '0.000000' COMMENT '同比增长率(%): 较新周期相对较早周期的增长率, 无可比数据时为0',
  `etl_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ETL更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_scenic_id` (`scenic_id`),
  KEY `idx_metric_level` (`metric_level`)
) ENGINE=InnoDB AUTO_INCREMENT=1299 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ADS-景区客群洞察-到访偏好 (美食/购物/酒店/景点)';

-- @table RDS_pft_ai:ads_scenic_customer_insight_wealth_consume_mo
-- @at 2026-11-27 11:18:48
CREATE TABLE `ads_scenic_customer_insight_wealth_consume_mo` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `scenic_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区ID',
  `scenic_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区名称',
  `period_granularity` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N' COMMENT '周期粒度: N=常规单期快照, 其他如 2025H1/2026H1 表示对比周期标识',
  `metric_level` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '消费维度: 全国消费水平/收入水平/餐饮消费水平/酒店消费水平/手机价格/通勤方式/是否有车',
  `tag_value` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '标签值, 如: 低/中/高, 51-100元, 4001-5000, 公交, 是/否',
  `proportion` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '占比 (%)',
  `tgi` int NOT NULL DEFAULT '0' COMMENT 'TGI值',
  `national_baseline` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '全国对照值 (%)',
  `ranking` int NOT NULL DEFAULT '0' COMMENT '排序 (维度内顺序)',
  `etl_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ETL更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_scenic_id` (`scenic_id`),
  KEY `idx_metric_level` (`metric_level`)
) ENGINE=InnoDB AUTO_INCREMENT=1220 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ADS-景区客群洞察-财富与消费画像';

-- @table RDS_pft_ai:ads_scenic_customer_insight_work_live_mo
-- @at 2026-11-27 11:19:02
CREATE TABLE `ads_scenic_customer_insight_work_live_mo` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `scenic_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区ID',
  `scenic_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区名称',
  `period_granularity` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N' COMMENT '周期粒度: N=常规单期快照, 其他如 2025H1/2026H1 表示对比周期标识',
  `metric_level` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '地点类型: 工作地 / 居住地',
  `ranking` int NOT NULL COMMENT '排名 (类型内)',
  `name` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '地点名称, 如: 扬州大学(扬子津西校区), 蜀冈瘦西湖风景名胜区',
  `proportion` decimal(10,4) NOT NULL DEFAULT '0.0000' COMMENT '占比 (%)',
  `longitude` decimal(10,6) DEFAULT NULL COMMENT '经度',
  `latitude` decimal(10,6) DEFAULT NULL COMMENT '纬度',
  `etl_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ETL更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_scenic_id` (`scenic_id`),
  KEY `idx_metric_level` (`metric_level`),
  KEY `idx_geo` (`longitude`,`latitude`)
) ENGINE=InnoDB AUTO_INCREMENT=1634 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ADS-景区客群洞察-职住地';

-- @table RDS_pft_ai:ads_sup_ota_ctrip_score_di
-- @at 2026-11-27 11:19:16
CREATE TABLE `ads_sup_ota_ctrip_score_di` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `account_id` varchar(50) NOT NULL COMMENT '账号标识（多账号隔离键）',
  `scenic_id` varchar(50) DEFAULT NULL COMMENT '景区ID（如 PFTSCA01018088，账号级绑定）',
  `evaluation_month` varchar(7) NOT NULL COMMENT '月份（YYYY-MM）',
  `region_id` varchar(20) NOT NULL COMMENT '目的地ID',
  `region_name` varchar(50) NOT NULL DEFAULT '' COMMENT '目的地名称',
  `region_type` varchar(10) DEFAULT NULL COMMENT '目的地类型',
  `overall_service_score` decimal(8,2) DEFAULT NULL COMMENT '综合服务分',
  `ocr_score` decimal(8,2) DEFAULT NULL COMMENT '订单确认率评分',
  `fdr_score` decimal(8,2) DEFAULT NULL COMMENT '履约缺陷率评分',
  `manual_intervention_rate_score` decimal(8,2) DEFAULT NULL COMMENT '客服人工介入率评分',
  `timely_response_20s_score` decimal(8,2) DEFAULT NULL COMMENT '20秒回复及时率评分',
  `im_neg_rate_score` decimal(8,2) DEFAULT NULL COMMENT 'IM差评率评分',
  `collect_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '采集时间',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ads_sup_ota_ctrip_score_di` (`account_id`,`evaluation_month`,`region_id`),
  KEY `idx_score_month` (`evaluation_month`),
  KEY `idx_score_region` (`region_id`),
  KEY `idx_score_scenic` (`scenic_id`,`evaluation_month`)
) ENGINE=InnoDB AUTO_INCREMENT=735 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='携程供应商评级雷达图数据';

-- @table RDS_pft_ai:ads_sup_ota_ctrip_trade_di
-- @at 2026-11-27 11:19:28
CREATE TABLE `ads_sup_ota_ctrip_trade_di` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `account_id` varchar(50) NOT NULL COMMENT '账号标识（多账号隔离键）',
  `scenic_id` varchar(50) DEFAULT NULL COMMENT '景区ID（如 PFTSCA01018088，账号级绑定）',
  `transaction_date` date NOT NULL COMMENT '交易日期',
  `signing_code` varchar(20) NOT NULL COMMENT '签约类型编码',
  `signing_type` varchar(50) NOT NULL DEFAULT '' COMMENT '签约类型名称',
  `biz_type` varchar(50) NOT NULL DEFAULT '' COMMENT '业务类型',
  `date_type` varchar(20) NOT NULL COMMENT '日期类型（使用日期/预订日期）',
  `turnover` decimal(18,2) DEFAULT NULL COMMENT '成交销售额（元）',
  `turnover_mom` decimal(12,6) DEFAULT NULL COMMENT '成交销售额环比',
  `order_count` bigint DEFAULT NULL COMMENT '订单数（笔）',
  `order_count_mom` decimal(12,6) DEFAULT NULL COMMENT '订单数环比',
  `sold_ticket_cnt` bigint DEFAULT NULL COMMENT '成交票量（张）',
  `sold_ticket_mom` decimal(12,6) DEFAULT NULL COMMENT '成交票量环比',
  `validated_ticket_volume` bigint DEFAULT NULL COMMENT '核验票量（张）',
  `validated_ticket_mom` decimal(12,6) DEFAULT NULL COMMENT '核验票量环比',
  `refund_rate` decimal(12,6) DEFAULT NULL COMMENT '退订率',
  `refund_rate_mom` decimal(12,6) DEFAULT NULL COMMENT '退订率环比',
  `collect_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '采集时间',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deal_resource_count` decimal(10,2) DEFAULT NULL COMMENT '成交资源数',
  `deal_resource_count_mom` decimal(10,4) DEFAULT NULL COMMENT '成交资源数环比',
  `period_type` varchar(10) DEFAULT NULL COMMENT '周期类型 1d:昨日 7d:近7日 30d:近30日',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ads_sup_ota_ctrip_trade_di` (`account_id`,`transaction_date`,`signing_code`,`biz_type`,`date_type`),
  KEY `idx_kylin_date` (`transaction_date`),
  KEY `idx_kylin_account_date` (`account_id`,`transaction_date`),
  KEY `idx_kylin_scenic_date` (`scenic_id`,`transaction_date`)
) ENGINE=InnoDB AUTO_INCREMENT=2865 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='携程交易卡片每日数据';

-- @table RDS_pft_ai:dim_prd_scenic_supplier_relation
-- @at 2026-11-27 11:24:00
CREATE TABLE `dim_prd_scenic_supplier_relation` (
  `scenic_id` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '景区编码',
  `scenic_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '景区名称',
  `suppliers` longtext COLLATE utf8mb4_unicode_ci COMMENT '供应商列表',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`scenic_id`),
  KEY `idx_scenic_name` (`scenic_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='景区供应商关系维表';

-- @table RDS_pft_ai:pft_dc_daycount_info
-- @at 2026-11-27 16:07:55
-- @status 弃用
-- @reason 测试 / 临时表

-- @table RDS_pft_open_cooperate:hotel_lvyun_hotel_master
-- @at 2026-11-27 15:17:16
CREATE TABLE `hotel_lvyun_hotel_master` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT 'base_con_sys_bind表ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `sync_update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '修改时间',
  `hotel_code` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '酒店代码',
  `hotel_name` varchar(300) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '酒店名称',
  `accnt` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '账号',
  `sta` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '状态',
  `rsv_id` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '预订账号',
  `master_id` int(11) DEFAULT NULL COMMENT '同住账号',
  `grp_accnt` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '团队账号',
  `rsv_man` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '预订人',
  `rsv_no` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '预订号',
  `ota_rsv_no` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT 'OTA订单号',
  `compan_id` int(11) DEFAULT NULL COMMENT '协议单位',
  `company_name` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '协议单位名称',
  `source_id` int(11) DEFAULT NULL COMMENT '订房中心',
  `source_name` varchar(300) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '订房中心名称',
  `agent_id` int(11) DEFAULT NULL COMMENT '旅行社',
  `agent_name` varchar(300) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '旅行社名称',
  `card_no` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '会员卡',
  `sales_man` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '销售员',
  `mobile` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '预订人电话',
  `market` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '市场码',
  `market_des` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '市场码描述',
  `src` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '来源码',
  `src_des` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '来源码描述',
  `rate_code` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '房价码',
  `ratecode_des` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '房价码描述',
  `channel` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '渠道代码',
  `channel_des` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '渠道描述',
  `rsv_type` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '预订类型',
  `rsv_type_des` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '预订类型描述',
  `rmtype` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '房型',
  `rmtype_des` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '房型描述',
  `rmnum` int(11) DEFAULT NULL COMMENT '房数',
  `real_rate` decimal(8,2) DEFAULT NULL COMMENT '房价',
  `rmno` varchar(200) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '房号',
  `charge` decimal(8,2) DEFAULT NULL COMMENT '消费合计',
  `pay` decimal(8,2) DEFAULT NULL COMMENT '付款合计',
  `deposit` decimal(8,2) DEFAULT NULL COMMENT '预付款',
  `arr` datetime DEFAULT NULL COMMENT '到日',
  `dep` datetime DEFAULT NULL COMMENT '离日',
  `adult` int(11) DEFAULT NULL COMMENT '人数',
  `children` int(11) DEFAULT NULL COMMENT '小孩',
  `rsv_date` datetime DEFAULT NULL COMMENT '预订时间',
  `remark` varchar(1000) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL COMMENT '备注',
  `create_date` datetime DEFAULT NULL COMMENT '创建时间',
  `modify_date` datetime DEFAULT NULL COMMENT '修改时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12170 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='绿云 酒店 订单表';

-- @table RDS_pft_open_cooperate:parking_daoer5_entry_record
-- @at 2026-11-27 15:15:05
CREATE TABLE `parking_daoer5_entry_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `object_id` varchar(32) NOT NULL DEFAULT '' COMMENT '对象ID',
  `car_in_id` varchar(32) NOT NULL DEFAULT '' COMMENT '入场表ID',
  `entrance_id` varchar(32) NOT NULL DEFAULT '' COMMENT '控制器编号',
  `entrance_name` varchar(32) NOT NULL DEFAULT '' COMMENT '入场控制器名称',
  `card_id` varchar(32) NOT NULL DEFAULT '' COMMENT '卡ID',
  `car_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车牌号',
  `next_car_no` varchar(32) NOT NULL DEFAULT '' COMMENT '从车牌',
  `correct_car_no` varchar(32) NOT NULL DEFAULT '' COMMENT '矫正车牌',
  `card_no` varchar(32) NOT NULL DEFAULT '' COMMENT '卡号',
  `contact_name` varchar(32) NOT NULL DEFAULT '' COMMENT '车主名称',
  `card_type_name` varchar(32) NOT NULL DEFAULT '' COMMENT '卡类名称',
  `car_no_type` varchar(32) NOT NULL DEFAULT '' COMMENT '车牌类型',
  `card_type_id` int(11) NOT NULL DEFAULT '0' COMMENT '停车类型',
  `in_time` datetime NOT NULL COMMENT '入场时间',
  `entrance_user_name` varchar(32) NOT NULL DEFAULT '' COMMENT '入场操作员',
  `in_pic` varchar(256) NOT NULL DEFAULT '' COMMENT '入场图片路径',
  `in_way` varchar(32) NOT NULL DEFAULT '' COMMENT '入场方式 0正常入场，1校正入场 ，2手工入场 3,扫码入场,4手持机入场',
  `in_way_name` varchar(32) NOT NULL DEFAULT '' COMMENT '入场方式名称',
  `small` varchar(32) NOT NULL DEFAULT '' COMMENT '小车场内0 否 1是',
  `controlIp` varchar(32) NOT NULL DEFAULT '' COMMENT '入场IP',
  `description` varchar(128) NOT NULL DEFAULT '' COMMENT '描述',
  `parking_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车场编号',
  `parking_name` varchar(32) NOT NULL DEFAULT '' COMMENT '车场名称',
  `box_id` varchar(32) NOT NULL DEFAULT '' COMMENT '岗亭ID',
  `box_name` varchar(32) NOT NULL DEFAULT '' COMMENT '岗亭名称',
  `operator_name` varchar(32) NOT NULL DEFAULT '' COMMENT '操作人',
  `park_owner` varchar(32) NOT NULL DEFAULT '' COMMENT '车场负责人',
  `phone` varchar(32) NOT NULL DEFAULT '' COMMENT '电话号码',
  `data_origin` varchar(32) NOT NULL DEFAULT '' COMMENT '线下或线上',
  `sync_status` int(11) NOT NULL DEFAULT '0' COMMENT '同步状态1待同步 2 已同步 3同步失败',
  `delete_code` varchar(32) NOT NULL DEFAULT '' COMMENT '是否已经删除：0正常 1 已删除',
  `is_load` int(11) NOT NULL DEFAULT '0' COMMENT '1待同步 2 已同步 3同步失败 ,线下上传传2',
  `save_time` varchar(32) NOT NULL DEFAULT '' COMMENT '保存时间',
  `create_time` datetime NOT NULL COMMENT '创建时间',
  `cflag` varchar(32) NOT NULL DEFAULT '' COMMENT '线下或线上',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE COMMENT '供应商，绑定',
  KEY `idx_car_no` (`car_no`) USING BTREE COMMENT '车牌号',
  KEY `idx_in_time` (`in_time`) USING BTREE COMMENT '入场时间'
) ENGINE=InnoDB AUTO_INCREMENT=207671 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='道尔5.0停车车辆入场记录（车牌入场时间合并）';

-- @table RDS_pft_open_cooperate:parking_daoer5_exit_record
-- @at 2026-11-27 15:15:17
CREATE TABLE `parking_daoer5_exit_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `car_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车牌号',
  `card_type_id` int(11) NOT NULL DEFAULT '0' COMMENT '车类型ID',
  `card_type_name` varchar(32) NOT NULL DEFAULT '' COMMENT '车类型名称',
  `in_time` datetime NOT NULL COMMENT '入场时间',
  `in_pic` varchar(256) NOT NULL DEFAULT '' COMMENT '入场图片路径',
  `out_time` datetime NOT NULL COMMENT '出场时间',
  `out_pic` varchar(256) NOT NULL DEFAULT '' COMMENT '出场图片路径',
  `in_way_name` varchar(32) NOT NULL DEFAULT '' COMMENT '入场方式，手工入场、校正入场',
  `out_way_name` varchar(32) NOT NULL DEFAULT '' COMMENT '出场方式，手工入场、校正入场',
  `entrance_name` varchar(32) NOT NULL DEFAULT '' COMMENT '入场通道名称',
  `entrance_user_name` varchar(32) NOT NULL DEFAULT '' COMMENT '入场操作员',
  `appearances_name` varchar(32) NOT NULL DEFAULT '' COMMENT '出场通道名称',
  `appearances_user_name` varchar(32) NOT NULL DEFAULT '' COMMENT '出场操作员',
  `payment_info` text NOT NULL COMMENT '支付信息，JSON数组保存',
  `pay_charge` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '实收金额，单位：元（支付信息汇总）',
  `account_charge` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '应收金额，单位：元（支付信息汇总）',
  `dis_amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '优惠金额，单位：元（支付信息汇总）',
  `in_id` varchar(32) NOT NULL DEFAULT '' COMMENT '入场编号',
  `contact_name` varchar(32) NOT NULL DEFAULT '' COMMENT '联系人姓名',
  `small` int(11) NOT NULL DEFAULT '0' COMMENT '是否小车场 0 否 1是',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE COMMENT '供应商，绑定',
  KEY `idx_car_no` (`car_no`) USING BTREE COMMENT '车牌号',
  KEY `idx_entry_time` (`in_time`) USING BTREE COMMENT '入场时间',
  KEY `idx_exit_time` (`out_time`) USING BTREE COMMENT '出场时间'
) ENGINE=InnoDB AUTO_INCREMENT=236974 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='道尔5.0停车车辆出场记录（车牌，出场时间合并）';

-- @table RDS_pft_open_cooperate:parking_daoer_entry_record
-- @at 2026-11-27 15:15:30
CREATE TABLE `parking_daoer_entry_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `car_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车牌号',
  `card_no` varchar(32) NOT NULL DEFAULT '' COMMENT '卡编号',
  `card_id` varchar(32) NOT NULL DEFAULT '' COMMENT '卡号',
  `owner_name` varchar(32) NOT NULL DEFAULT '' COMMENT '车主姓名',
  `card_type_name` varchar(32) NOT NULL DEFAULT '' COMMENT '卡类型',
  `entry_name` varchar(128) NOT NULL DEFAULT '' COMMENT '入口名称',
  `entry_time` datetime NOT NULL COMMENT '入场时间',
  `entry_opt_name` varchar(32) NOT NULL DEFAULT '' COMMENT '入口操作员',
  `payment_info` text NOT NULL COMMENT '费用信息，JSON数组保存',
  `account_charge` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '应收金额，单位：元（支付信息汇总）',
  `pay_charge` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '实收金额，单位：元（支付信息汇总）',
  `dis_amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '这块金额，单位：元（支付信息汇总）',
  `payment_type` varchar(128) NOT NULL DEFAULT '' COMMENT '支付类型，单位：元（支付信息汇总）',
  `payment_type_name` varchar(128) NOT NULL DEFAULT '' COMMENT '支付类型名称',
  `payment_tnx` varchar(128) NOT NULL DEFAULT '' COMMENT '交易编号，唯一值',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE COMMENT '供应商，绑定',
  KEY `idx_car_no` (`car_no`) USING BTREE COMMENT '车牌号',
  KEY `idx_entry_time` (`entry_time`) USING BTREE COMMENT '入场时间'
) ENGINE=InnoDB AUTO_INCREMENT=47795 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='道尔停车车辆入场记录（车牌入场时间合并）';

-- @table RDS_pft_open_cooperate:parking_daoer_exit_record
-- @at 2026-11-27 15:15:40
CREATE TABLE `parking_daoer_exit_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `car_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车牌号',
  `card_no` varchar(32) NOT NULL DEFAULT '' COMMENT '卡编号',
  `card_id` varchar(32) NOT NULL DEFAULT '' COMMENT '卡号',
  `owner_name` varchar(32) NOT NULL DEFAULT '' COMMENT '车主姓名',
  `card_type_name` varchar(32) NOT NULL DEFAULT '' COMMENT '卡类型',
  `entry_name` varchar(32) NOT NULL DEFAULT '' COMMENT '入口名称',
  `entry_time` datetime NOT NULL COMMENT '入场时间',
  `entry_opt_name` varchar(32) NOT NULL DEFAULT '' COMMENT '入口操作员',
  `exit_name` varchar(32) NOT NULL DEFAULT '' COMMENT '出口名称',
  `exit_time` datetime NOT NULL COMMENT '出场时间',
  `exit_opt_name` varchar(32) NOT NULL DEFAULT '' COMMENT '出口操作员',
  `payment_info` text NOT NULL COMMENT '费用信息，JSON数组保存',
  `account_charge` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '应收金额，单位：元（支付信息汇总）',
  `pay_charge` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '实收金额，单位：元（支付信息汇总）',
  `dis_amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '折扣金额，单位：元（支付信息汇总）',
  `payment_type` varchar(128) NOT NULL DEFAULT '' COMMENT '支付类型，（支付信息汇总）',
  `payment_type_name` varchar(128) NOT NULL DEFAULT '' COMMENT '支付类型名称',
  `payment_tnx` varchar(128) NOT NULL DEFAULT '' COMMENT '交易编号，唯一值，（支付信息汇总）',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE COMMENT '供应商，绑定',
  KEY `idx_car_no` (`car_no`) USING BTREE COMMENT '车牌号',
  KEY `idx_entry_time` (`entry_time`) USING BTREE COMMENT '入场时间',
  KEY `idx_exit_time` (`exit_time`) USING BTREE COMMENT '出场时间'
) ENGINE=InnoDB AUTO_INCREMENT=399604 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='道尔停车车辆出场记录（车牌，出场时间合并）';

-- @table RDS_pft_open_cooperate:parking_ketuo_entry_record
-- @at 2026-11-27 15:15:53
CREATE TABLE `parking_ketuo_entry_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `traffic_id` varchar(32) NOT NULL DEFAULT '' COMMENT '入场唯一记录ID',
  `plate_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车牌号',
  `cap_time` datetime NOT NULL COMMENT '入场时间',
  `img_name` varchar(128) NOT NULL DEFAULT '' COMMENT '车辆进出场图片名称',
  `img_type` int(11) NOT NULL DEFAULT '-1' COMMENT '图片信息类型：1：base64位图片信息；2=图片URL',
  `img_info` varchar(255) NOT NULL DEFAULT '' COMMENT '图片信息',
  `cap_place` varchar(32) NOT NULL DEFAULT '' COMMENT '车辆进出场地点',
  `car_type_code` int(11) NOT NULL DEFAULT '-1' COMMENT '固定车类型编码',
  `car_type_name` varchar(32) NOT NULL DEFAULT '' COMMENT '固定车类型名称',
  `car_color` varchar(16) NOT NULL DEFAULT '' COMMENT '车身颜色黑、白、蓝、红等',
  `car_style_code` varchar(16) NOT NULL DEFAULT '' COMMENT '车辆类型编码',
  `car_style_name` varchar(32) NOT NULL DEFAULT '' COMMENT '车辆类型名称',
  `card_no` varchar(32) NOT NULL DEFAULT '' COMMENT '入场取票号/无牌车入场的卡号',
  `pass_type_code` int(11) NOT NULL DEFAULT '-1' COMMENT '放行类型编码',
  `pass_type_name` varchar(32) NOT NULL DEFAULT '' COMMENT '放行类型名称',
  `pass_remark` varchar(255) NOT NULL DEFAULT '' COMMENT '放行说明',
  `car_serial` varchar(32) NOT NULL DEFAULT '' COMMENT '流水号',
  `node_id` int(11) NOT NULL DEFAULT '0' COMMENT '通道id',
  `car_owner_name` varchar(32) NOT NULL DEFAULT '' COMMENT '车主名称',
  `operator` varchar(32) NOT NULL DEFAULT '' COMMENT '放行渠道',
  `oper_name` varchar(32) NOT NULL DEFAULT '' COMMENT '操作人员',
  `serial_type` varchar(16) NOT NULL DEFAULT '' COMMENT '凭据类型',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE COMMENT '供应商，绑定',
  KEY `idx_traffic_id` (`traffic_id`) USING BTREE COMMENT '入场唯一记录ID',
  KEY `idx_plate_no` (`plate_no`) USING BTREE COMMENT '车牌号',
  KEY `idx_cap_time` (`cap_time`) USING BTREE COMMENT '入场时间'
) ENGINE=InnoDB AUTO_INCREMENT=78024 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='科拓停车车辆入场记录';

-- @table RDS_pft_open_cooperate:parking_ketuo_exit_record
-- @at 2026-11-27 15:16:04
CREATE TABLE `parking_ketuo_exit_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `traffic_id` varchar(32) NOT NULL DEFAULT '' COMMENT '出场唯一记录ID',
  `plate_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车牌号',
  `cap_time` datetime NOT NULL COMMENT '出场时间',
  `img_name` varchar(128) NOT NULL DEFAULT '' COMMENT '车辆进出场图片名称',
  `img_type` int(11) NOT NULL DEFAULT '-1' COMMENT '图片信息类型：1：base64位图片信息；2=图片URL',
  `img_info` varchar(255) NOT NULL DEFAULT '' COMMENT '图片信息',
  `cap_place` varchar(32) NOT NULL DEFAULT '' COMMENT '车辆进出场地点',
  `car_type_code` int(11) NOT NULL DEFAULT '-1' COMMENT '固定车类型编码',
  `car_type_name` varchar(32) NOT NULL DEFAULT '' COMMENT '固定车类型名称',
  `car_color` varchar(16) NOT NULL DEFAULT '' COMMENT '车身颜色黑、白、蓝、红等',
  `car_style_code` varchar(16) NOT NULL DEFAULT '' COMMENT '车辆类型编码',
  `car_style_name` varchar(16) NOT NULL DEFAULT '' COMMENT '车辆类型名称',
  `card_no` varchar(32) NOT NULL DEFAULT '' COMMENT '入场取票号/无牌车入场的卡号',
  `pass_type_code` int(11) NOT NULL DEFAULT '-1' COMMENT '放行类型编码',
  `pass_type_name` varchar(32) NOT NULL DEFAULT '' COMMENT '放行类型名称',
  `pass_remark` varchar(255) NOT NULL DEFAULT '' COMMENT '放行说明',
  `car_serial` varchar(32) NOT NULL DEFAULT '' COMMENT '流水号',
  `node_id` int(11) NOT NULL DEFAULT '0' COMMENT '通道id',
  `car_owner_name` varchar(32) NOT NULL DEFAULT '' COMMENT '车主名称',
  `operator` varchar(32) NOT NULL DEFAULT '' COMMENT '放行渠道',
  `oper_name` varchar(32) NOT NULL DEFAULT '' COMMENT '操作人员',
  `serial_type` varchar(16) NOT NULL DEFAULT '' COMMENT '凭据类型',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE COMMENT '供应商，绑定',
  KEY `idx_traffic_id` (`traffic_id`) USING BTREE COMMENT '出场唯一记录ID',
  KEY `idx_plate_no` (`plate_no`) USING BTREE COMMENT '车牌号',
  KEY `idx_cap_time` (`cap_time`) USING BTREE COMMENT '出场时间'
) ENGINE=InnoDB AUTO_INCREMENT=72693 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='科拓停车车辆出场记录';

-- @table RDS_pft_open_cooperate:parking_shuaichen_entry_record
-- @at 2026-11-27 15:17:30
CREATE TABLE `parking_shuaichen_entry_record` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `car_type` varchar(32) NOT NULL DEFAULT '' COMMENT '车型',
  `channel_name` varchar(100) NOT NULL DEFAULT '' COMMENT '入口名称',
  `enter_time` datetime DEFAULT NULL COMMENT '入场时间',
  `order_num` varchar(100) NOT NULL DEFAULT '' COMMENT '订单号',
  `park_code` varchar(20) NOT NULL DEFAULT '' COMMENT '停车场编号',
  `park_name` varchar(100) NOT NULL DEFAULT '' COMMENT '停车场名称',
  `plate_num` varchar(20) NOT NULL DEFAULT '' COMMENT '车牌号',
  `type` varchar(20) NOT NULL DEFAULT '' COMMENT '车辆类型',
  `enter_way` varchar(20) NOT NULL DEFAULT '' COMMENT '入场方式',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=63901 DEFAULT CHARSET=utf8 COMMENT='帅臣停车车辆入场记录';

-- @table RDS_pft_open_cooperate:parking_shuaichen_exit_record
-- @at 2026-11-27 15:17:41
CREATE TABLE `parking_shuaichen_exit_record` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `park_code` varchar(20) NOT NULL DEFAULT '' COMMENT '停车场编号',
  `park_name` varchar(100) NOT NULL DEFAULT '' COMMENT '停车场名称',
  `order_num` varchar(100) NOT NULL DEFAULT '' COMMENT '订单号',
  `plate_num` varchar(20) NOT NULL DEFAULT '' COMMENT '车牌号',
  `channel_name` varchar(100) NOT NULL DEFAULT '' COMMENT '入口名称',
  `exit_time` datetime DEFAULT NULL COMMENT '出场时间',
  `park_time` int(11) NOT NULL DEFAULT '0' COMMENT '停车时长（秒）',
  `type` varchar(20) NOT NULL DEFAULT '' COMMENT '车辆类型',
  `car_type` varchar(32) NOT NULL DEFAULT '' COMMENT '车型',
  `total_amount` int(11) NOT NULL DEFAULT '0' COMMENT '应收总金额 (分)',
  `paid_amount` int(11) NOT NULL DEFAULT '0' COMMENT '实收总金额 (分)',
  `discount_amount` int(11) NOT NULL DEFAULT '0' COMMENT '优惠总金额 (分)',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=60355 DEFAULT CHARSET=utf8 COMMENT='帅臣停车车辆出场记录';

-- @table RDS_pft_open_cooperate:parking_zhihui_entry_record
-- @at 2026-11-27 15:16:15
CREATE TABLE `parking_zhihui_entry_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `index_id` varchar(32) NOT NULL DEFAULT '' COMMENT '唯一索引',
  `park_key` varchar(32) NOT NULL DEFAULT '' COMMENT '停车场唯一编号',
  `car_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车牌号',
  `order_no` varchar(128) NOT NULL DEFAULT '' COMMENT '订单号',
  `car_type_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车辆类型编号',
  `car_type_name` varchar(32) NOT NULL DEFAULT '' COMMENT '车辆类型名称',
  `enter_time` datetime NOT NULL COMMENT '入场时间',
  `enter_gate_name` varchar(128) NOT NULL DEFAULT '' COMMENT '入口名称',
  `enter_operator_name` varchar(32) NOT NULL DEFAULT '' COMMENT '入口操作员',
  `lock_car` varchar(16) NOT NULL DEFAULT '' COMMENT '车辆状态，0-未锁，1-锁定',
  `lock_car_name` varchar(16) NOT NULL DEFAULT '' COMMENT '车辆状态名称',
  `enter_img_path` varchar(1024) NOT NULL DEFAULT '' COMMENT '入口照片',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE COMMENT '供应商，绑定',
  KEY `idx_car_no` (`index_id`) USING BTREE COMMENT '车牌号',
  KEY `idx_entry_time` (`enter_time`) USING BTREE COMMENT '入场时间'
) ENGINE=InnoDB AUTO_INCREMENT=757153 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='智慧停车车辆入场记录（车牌入场时间合并）';

-- @table RDS_pft_open_cooperate:parking_zhihui_exit_record
-- @at 2026-11-27 15:16:28
CREATE TABLE `parking_zhihui_exit_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `index_id` varchar(32) NOT NULL DEFAULT '' COMMENT '唯一索引',
  `park_key` varchar(32) NOT NULL DEFAULT '' COMMENT '停车场唯一编号',
  `car_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车牌号',
  `order_no` varchar(128) NOT NULL DEFAULT '' COMMENT '订单号',
  `car_type_no` varchar(32) NOT NULL DEFAULT '' COMMENT '车辆类型编号',
  `car_type_name` varchar(32) NOT NULL DEFAULT '' COMMENT '车辆类型名称',
  `enter_time` datetime NOT NULL COMMENT '入场时间',
  `enter_gate_name` varchar(128) NOT NULL DEFAULT '' COMMENT '入口名称',
  `out_operator_name` varchar(32) NOT NULL DEFAULT '' COMMENT '出口操作员',
  `out_time` datetime NOT NULL COMMENT '出场时间',
  `out_gate_name` varchar(128) NOT NULL DEFAULT '' COMMENT '出口名称',
  `lock_car` varchar(16) NOT NULL DEFAULT '' COMMENT '车辆状态，0-未锁，1-锁定',
  `lock_car_name` varchar(16) NOT NULL DEFAULT '' COMMENT '车辆状态名称',
  `out_img_path` varchar(1024) NOT NULL DEFAULT '' COMMENT '出场图片',
  `total_amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '订单总金额',
  `free_reason` varchar(128) NOT NULL DEFAULT '' COMMENT '免费放行原因',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE COMMENT '供应商，绑定',
  KEY `idx_car_no` (`index_id`) USING BTREE COMMENT '车牌号',
  KEY `idx_entry_time` (`enter_time`) USING BTREE COMMENT '入场时间',
  KEY `idx_out_time` (`out_time`) USING BTREE COMMENT '出场时间'
) ENGINE=InnoDB AUTO_INCREMENT=736871 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='智慧停车车辆入场记录（车牌入场时间合并）';

-- @table RDS_pft_open_cooperate:retail_sixun_order
-- @at 2026-11-27 15:16:43
CREATE TABLE `retail_sixun_order` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '创建时间',
  `sync_update_time` datetime NOT NULL COMMENT '更新时间',
  `shop_code` varchar(64) NOT NULL DEFAULT '' COMMENT '销售门店号',
  `order_no` varchar(64) NOT NULL DEFAULT '' COMMENT '销售订单号',
  `status` varchar(16) NOT NULL DEFAULT '' COMMENT '是否有效',
  `sale_money` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '销售金额',
  `payment_money` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '支付金额',
  `settlement_money` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '实收金额',
  `table_number` varchar(64) NOT NULL DEFAULT '' COMMENT '座号',
  `number_of_people` int(11) NOT NULL DEFAULT '0' COMMENT '人数',
  `pos_name` varchar(64) NOT NULL DEFAULT '' COMMENT 'POS机名称',
  `operator` varchar(64) NOT NULL DEFAULT '' COMMENT '操作人员',
  `create_time` datetime NOT NULL COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`con_sys_bind`,`member_id`) USING BTREE COMMENT '绑定，供应商',
  KEY `idx_order_shop` (`order_no`,`shop_code`) USING BTREE COMMENT '订单，店铺',
  KEY `idx_create_time` (`create_time`) USING BTREE COMMENT '创单时间'
) ENGINE=InnoDB AUTO_INCREMENT=213 DEFAULT CHARSET=utf8 COMMENT='思迅订单表';

-- @table RDS_pft_open_cooperate:retail_sixun_order_sale_detail
-- @at 2026-11-27 15:16:54
CREATE TABLE `retail_sixun_order_sale_detail` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '创建时间',
  `sync_update_time` datetime NOT NULL COMMENT '更新时间',
  `shop_code` varchar(64) NOT NULL DEFAULT '' COMMENT '店铺编码',
  `order_no` varchar(64) NOT NULL DEFAULT '' COMMENT '销售单据号',
  `seq_no` varchar(64) NOT NULL DEFAULT '' COMMENT '销售单据序号',
  `product_name` varchar(64) NOT NULL DEFAULT '' COMMENT '销售商品名称',
  `sale_num` int(11) NOT NULL DEFAULT '0' COMMENT '销售数量',
  `sale_money` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '销售金额',
  `operator` varchar(64) NOT NULL DEFAULT '' COMMENT '操作人员',
  `sale_time` datetime NOT NULL COMMENT '销售时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_bind_member` (`con_sys_bind`,`member_id`) USING BTREE COMMENT '绑定，供应商',
  KEY `idx_seq_order_shop` (`shop_code`,`order_no`,`seq_no`) USING BTREE COMMENT '序号，订单，店铺'
) ENGINE=InnoDB AUTO_INCREMENT=796 DEFAULT CHARSET=utf8 COMMENT='思迅销售明细表';

-- @table RDS_pft_open_cooperate:retail_sixun_shop
-- @at 2026-11-27 15:17:05
CREATE TABLE `retail_sixun_shop` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '创建时间',
  `sync_update_time` datetime NOT NULL COMMENT '更新时间',
  `shop_code` varchar(64) NOT NULL DEFAULT '' COMMENT '店铺编码',
  `shop_name` varchar(64) NOT NULL DEFAULT '' COMMENT '店铺名称',
  `shop_category` varchar(64) NOT NULL DEFAULT '' COMMENT '店铺分类',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_bind_member` (`con_sys_bind`,`member_id`) USING BTREE COMMENT '绑定，供应商',
  KEY `idx_code` (`shop_code`) USING BTREE COMMENT '店铺'
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8 COMMENT='思迅店铺表';

-- @table RDS_pft_open_cooperate:retail_xisland_order
-- @at 2026-11-27 15:17:53
CREATE TABLE `retail_xisland_order` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `order_code` varchar(64) NOT NULL DEFAULT '' COMMENT '订单号（三方唯一）',
  `store_name` varchar(128) NOT NULL DEFAULT '' COMMENT '门店名称',
  `business_type` varchar(16) NOT NULL DEFAULT '' COMMENT '业务类型：餐饮/零售',
  `pay_type` int(11) NOT NULL DEFAULT '0' COMMENT '支付方式码（三方原值，餐饮单返回，零售单为null时落0）',
  `pay_type_name` varchar(64) NOT NULL DEFAULT '' COMMENT '支付方式名称',
  `order_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '订单金额（元）',
  `pay_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '实付金额（元）',
  `discount_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '优惠金额（元）',
  `return_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '退款金额（元）',
  `pay_status` int(11) NOT NULL DEFAULT '0' COMMENT '支付状态码（三方原值）',
  `pay_status_name` varchar(32) NOT NULL DEFAULT '' COMMENT '支付状态名称',
  `order_create_time` datetime NOT NULL COMMENT '订单创建时间（三方createTime，零售单缺失时兜底取支付时间/同步时间）',
  `pay_time` datetime NOT NULL COMMENT '支付时间（三方payTime，缺失时兜底取订单创建时间）',
  `create_name` varchar(64) NOT NULL DEFAULT '' COMMENT '操作人',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_bind_order_code` (`con_sys_bind`,`order_code`),
  KEY `idx_member_order_time` (`member_id`,`order_create_time`),
  KEY `idx_order_create_time` (`order_create_time`)
) ENGINE=InnoDB AUTO_INCREMENT=1662 DEFAULT CHARSET=utf8 COMMENT='小岛餐饮零售订单表';

-- @table RDS_pft_open_cooperate:retail_xisland_order_item
-- @at 2026-11-27 15:18:04
CREATE TABLE `retail_xisland_order_item` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `order_code` varchar(64) NOT NULL DEFAULT '' COMMENT '订单号（关联主表 retail_xisland_order）',
  `product_name` varchar(128) NOT NULL DEFAULT '' COMMENT '商品/菜品名称',
  `class_name` varchar(64) NOT NULL DEFAULT '' COMMENT '分类名称',
  `unit_price` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '单价（元）',
  `quantity` int(11) NOT NULL DEFAULT '0' COMMENT '数量',
  `amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '小计金额（元）',
  `order_create_time` datetime NOT NULL COMMENT '订单创建时间（三方createTime，零售单缺失时兜底取支付时间/同步时间）',
  `pay_time` datetime NOT NULL COMMENT '支付时间（三方payTime，缺失时兜底取订单创建时间）',
  `row_no` int(11) NOT NULL DEFAULT '0' COMMENT '行号（三方items数组下标，从1开始，用于明细行身份识别与upsert）',
  `discount_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '优惠金额（元）',
  `pay_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '实付金额（元）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_bind_order_row` (`con_sys_bind`,`order_code`,`row_no`),
  KEY `idx_order_code` (`order_code`),
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`),
  KEY `idx_order_create_time` (`order_create_time`)
) ENGINE=InnoDB AUTO_INCREMENT=2131 DEFAULT CHARSET=utf8 COMMENT='小岛餐饮零售订单商品明细表';

-- @table RDS_pft_open_cooperate:retail_xisland_refund_order
-- @at 2026-11-27 15:18:16
CREATE TABLE `retail_xisland_refund_order` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `refund_code` varchar(64) NOT NULL DEFAULT '' COMMENT '退款单号（三方唯一）',
  `order_code` varchar(64) NOT NULL DEFAULT '' COMMENT '原订单号（关联 retail_xisland_order）',
  `store_name` varchar(128) NOT NULL DEFAULT '' COMMENT '门店名称',
  `business_type` varchar(16) NOT NULL DEFAULT '' COMMENT '业务类型：餐饮/零售',
  `refund_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '退款金额（元）',
  `refund_status` int(11) NOT NULL DEFAULT '0' COMMENT '退款状态码（2:失败,6:部分退款,7:退款成功，实测存在文档未说明的2=失败）',
  `refund_status_name` varchar(32) NOT NULL DEFAULT '' COMMENT '退款状态名称',
  `refund_create_time` datetime NOT NULL COMMENT '退款时间（三方createTime，零售退款单无三方时间，兜底取同步时间）',
  `create_name` varchar(64) NOT NULL DEFAULT '' COMMENT '操作人/退款方式',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_bind_refund_code` (`con_sys_bind`,`refund_code`),
  KEY `idx_member_refund_time` (`member_id`,`refund_create_time`),
  KEY `idx_refund_create_time` (`refund_create_time`),
  KEY `idx_order_code` (`order_code`)
) ENGINE=InnoDB AUTO_INCREMENT=59 DEFAULT CHARSET=utf8 COMMENT='小岛餐饮零售退款单表';

-- @table RDS_pft_open_cooperate:retail_xisland_refund_order_item
-- @at 2026-11-27 15:18:29
CREATE TABLE `retail_xisland_refund_order_item` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `refund_code` varchar(64) NOT NULL DEFAULT '' COMMENT '退款单号（关联主表 retail_xisland_refund_order）',
  `order_code` varchar(64) NOT NULL DEFAULT '' COMMENT '原订单号',
  `product_name` varchar(128) NOT NULL DEFAULT '' COMMENT '商品名称（按金额退款时为空串）',
  `class_name` varchar(64) NOT NULL DEFAULT '' COMMENT '分类名称（按金额退款时为空串）',
  `unit_price` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '单价（元，按金额退款时为0）',
  `quantity` int(11) NOT NULL DEFAULT '0' COMMENT '退款数量（按金额退款时为0）',
  `refund_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '该明细退款金额（元）',
  `refund_create_time` datetime NOT NULL COMMENT '退款时间（三方createTime，零售退款单无三方时间，兜底取同步时间）',
  `row_no` int(11) NOT NULL DEFAULT '0' COMMENT '行号（三方items数组下标，从1开始，用于明细行身份识别与upsert）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_bind_refund_row` (`con_sys_bind`,`refund_code`,`row_no`),
  KEY `idx_refund_code` (`refund_code`),
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`),
  KEY `idx_refund_create_time` (`refund_create_time`)
) ENGINE=InnoDB AUTO_INCREMENT=59 DEFAULT CHARSET=utf8 COMMENT='小岛餐饮零售退款单商品明细表';

-- @table RDS_pft_open_cooperate:retail_yinbao_ticket
-- @at 2026-11-27 15:18:41
CREATE TABLE `retail_yinbao_ticket` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `app_id` varchar(100) NOT NULL DEFAULT '' COMMENT 'AppId',
  `sn` varchar(32) NOT NULL DEFAULT '' COMMENT '单据序列号',
  `uid` bigint(20) NOT NULL DEFAULT '0' COMMENT '单据唯一标识',
  `ticket_type` varchar(32) NOT NULL DEFAULT '' COMMENT '单据类型：SELL(销售)/SELL_RETURN(退货)',
  `cashier_uid` bigint(20) NOT NULL DEFAULT '0' COMMENT '收银员唯一标识',
  `cashier` json DEFAULT NULL COMMENT '充值门店的账号',
  `customer_uid` bigint(20) NOT NULL DEFAULT '0' COMMENT '会员在银豹系统的唯一标识',
  `date_time` varchar(32) NOT NULL DEFAULT '' COMMENT '单据产生时间',
  `sys_update_time` varchar(32) NOT NULL DEFAULT '' COMMENT '单据更新时间',
  `total_amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '单据实收总额',
  `total_profit` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '单据总利润',
  `discount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '整单折扣比例',
  `external_order_no` varchar(64) NOT NULL DEFAULT '' COMMENT '第三方平台支付单号',
  `remark` varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `service_fee` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '服务费',
  `gratuity` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '小费',
  `cover_charge` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '餐位费/茶位费',
  `box_fee` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '包厢费',
  `rounding` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '抹零数额',
  `sell_ticket_uid` bigint(20) NOT NULL DEFAULT '0' COMMENT '关联的原销售单据UID（退货单时有效）',
  `invalid` int(11) NOT NULL DEFAULT '0' COMMENT '单据作废标志（1=已作废）',
  `web_order_no` varchar(64) NOT NULL DEFAULT '' COMMENT '网单号（外卖/小程序订单）',
  `payments` json DEFAULT NULL COMMENT '支付方式列表',
  `ticket_spend_detail` json DEFAULT NULL COMMENT '就餐人数信息',
  `ticket_on_table` json DEFAULT NULL COMMENT '桌号信息',
  `point_usage` json DEFAULT NULL COMMENT '积分使用明细',
  `ticket_store_appid_or_account` varchar(32) NOT NULL DEFAULT '' COMMENT '会员所在门店标识',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE COMMENT '供应商，绑定',
  KEY `idx_date_time` (`date_time`) USING BTREE COMMENT '单据产生时间',
  KEY `idx_uid` (`uid`) USING BTREE COMMENT '单据唯一标识',
  KEY `idx_sn_ticket_type_invalid` (`sn`,`ticket_type`,`invalid`) USING BTREE COMMENT '单据号，类型，作废'
) ENGINE=InnoDB AUTO_INCREMENT=114039 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='银豹单据';

-- @table RDS_pft_open_cooperate:retail_yinbao_ticket_item
-- @at 2026-11-27 15:18:53
CREATE TABLE `retail_yinbao_ticket_item` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `con_sys_bind` int(11) NOT NULL DEFAULT '0' COMMENT '绑定ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `sync_create_time` datetime NOT NULL COMMENT '首次同步时间',
  `sync_update_time` datetime NOT NULL COMMENT '最后同步时间',
  `sn` varchar(32) NOT NULL DEFAULT '' COMMENT '单据序列号',
  `uid` bigint(20) NOT NULL DEFAULT '0' COMMENT '单据唯一标识',
  `product_uid` bigint(20) NOT NULL DEFAULT '0' COMMENT '商品唯一标识',
  `name` varchar(64) NOT NULL DEFAULT '' COMMENT '商品名称',
  `buy_price` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '商品进货价',
  `sell_price` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '商品销售价',
  `customer_price` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '商品会员价',
  `quantity` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '销售数量',
  `discount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '折扣比例',
  `customer_discount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '会员折扣比例',
  `total_amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '条目总价',
  `total_profit` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '条目总利润',
  `is_customer_discount` int(11) NOT NULL DEFAULT '0' COMMENT '是否会员折扣（1=是）',
  `product_barcode` varchar(32) NOT NULL DEFAULT '' COMMENT '商品条码',
  `ticket_item_attributes` json DEFAULT NULL COMMENT '商品属性/备注',
  `discount_details` json DEFAULT NULL COMMENT '折扣明细',
  `sale_guider_list` json DEFAULT NULL COMMENT '导购员列表',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_bind` (`member_id`,`con_sys_bind`) USING BTREE COMMENT '供应商，绑定',
  KEY `idx_sn` (`sn`) USING BTREE COMMENT '单据序列号',
  KEY `idx_uid` (`uid`) USING BTREE COMMENT '单据唯一标识'
) ENGINE=InnoDB AUTO_INCREMENT=298555 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='银豹单据商品条目';

-- @table RDS_selectdb_report:r_report_dwm_common
-- @at 2026-11-27 16:12:08
CREATE TABLE `r_report_dwm_common` (
  `operated_at` datetime NULL COMMENT '操作时间',
  `merchant_id` bigint NULL COMMENT '商户ID',
  `business_no` bigint NULL COMMENT '业务单号',
  `sort_key` largeint NULL COMMENT '排序key，时间+业务单号',
  `order_no` text NULL COMMENT '订单号',
  `trade_no` text NULL COMMENT '交易单号',
  `external_operate_no` text NULL COMMENT '外部操作单号',
  `parent_order_no` text NULL COMMENT '主订单号',
  `product_type` text NULL COMMENT '产品类型',
  `sub_type` int NULL COMMENT '子类型',
  `parent_merchant_id` bigint NULL COMMENT '上级商户ID',
  `distributor_id` bigint NULL COMMENT '下级商户ID',
  `operate_type` int NULL COMMENT '操作类型：1支付&加票 2核销&完结 3取消 4撤销 5售后',
  `poi_id` bigint NULL COMMENT 'PoiID',
  `spu_id` bigint NULL COMMENT 'SpuID',
  `sku_id` bigint NULL COMMENT 'SkuID',
  `sale_channel` int NULL COMMENT '销售渠道',
  `operate_channel` int NULL COMMENT '操作渠道',
  `cost_pay_mode` int NULL COMMENT '采购支付方式',
  `sale_pay_mode` int NULL COMMENT '销售支付方式',
  `sell_operator_id` bigint NULL COMMENT '售票员ID',
  `operator_id` bigint NULL COMMENT '操作人ID',
  `operate_site_id` int NULL COMMENT '操作站点ID',
  `sell_site_id` int NULL COMMENT '售票站点ID',
  `cost_unit_price` int NULL COMMENT '采购单价',
  `sale_unit_price` int NULL COMMENT '销售单价',
  `pack_type` int NULL COMMENT '套票规则，0默认 1是主票 2是子票',
  `show_bind_type` int NULL COMMENT '捆绑票规则，0默认 1是主票 2是子票',
  `annual_card_type` int NULL COMMENT '年卡规则，0默认 1是年卡 2是特权',
  `exchange_coupon_type` int NULL COMMENT '预售券规则，0默认 1是预售券 2是权益兑换订单',
  `target_audience` varchar(255) NULL DEFAULT "" COMMENT '适用人群',
  `report_tag` varchar(255) NULL DEFAULT "" COMMENT '报表标签(门票sku的标签)',
  `pay_count` int NULL COMMENT '预订数量',
  `pay_cost_price` bigint NULL COMMENT '预订采购金额',
  `pay_cost_discount_price` bigint NULL COMMENT '预订采购优惠金额',
  `pay_sale_price` bigint NULL COMMENT '预订销售金额',
  `pay_sale_discount_price` bigint NULL COMMENT '预订销售优惠金额',
  `verify_count` int NULL COMMENT '核销数量',
  `verify_cost_price` bigint NULL COMMENT '核销采购金额',
  `verify_cost_discount_price` bigint NULL COMMENT '核销采购优惠金额',
  `verify_sale_price` bigint NULL COMMENT '核销销售金额',
  `verify_sale_discount_price` bigint NULL COMMENT '核销销售优惠金额',
  `cancel_count` int NULL COMMENT '取消数量',
  `cancel_cost_price` bigint NULL COMMENT '取消采购金额',
  `cancel_cost_discount_price` bigint NULL COMMENT '取消采购优惠金额',
  `cancel_cost_fee` bigint NULL COMMENT '取消采购手续费',
  `cancel_sale_price` bigint NULL COMMENT '取消销售金额',
  `cancel_sale_discount_price` bigint NULL COMMENT '取消销售优惠金额',
  `cancel_sale_fee` bigint NULL COMMENT '取消采购手续费',
  `revoke_count` int NULL COMMENT '撤销数量',
  `revoke_cost_price` bigint NULL COMMENT '撤销采购金额',
  `revoke_cost_discount_price` bigint NULL COMMENT '撤销采购优惠金额',
  `revoke_cost_fee` bigint NULL COMMENT '撤销销售金额',
  `revoke_sale_price` bigint NULL COMMENT '撤销销售优惠金额',
  `revoke_sale_discount_price` bigint NULL COMMENT '售后采购金额',
  `revoke_sale_fee` bigint NULL COMMENT '售后销售金额',
  `after_sale_count` int NULL COMMENT '售后数量',
  `after_cost_price` bigint NULL COMMENT '售后采购金额',
  `collect_count` int NULL COMMENT '取票数量',
  `reprint_count` int NULL COMMENT '重打印数量',
  `after_sale_price` bigint NULL COMMENT '售后销售金额',
  `pay_people_num` int NOT NULL DEFAULT "0" COMMENT '预订人数',
  `verify_people_num` int NOT NULL DEFAULT "0" COMMENT '核销人数',
  `cancel_people_num` int NOT NULL DEFAULT "0" COMMENT '取消人数',
  `revoke_people_num` int NOT NULL DEFAULT "0" COMMENT '撤销人数',
  `after_sale_people_num` int NOT NULL DEFAULT "0" COMMENT '售后人数',
  `created_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录创建时间'
) ENGINE=OLAP
UNIQUE KEY(`operated_at`, `merchant_id`, `business_no`)
COMMENT '通用明细表'
PARTITION BY RANGE(`operated_at`)
(PARTITION pt_20231030 VALUES [('2023-10-30 00:00:00'), ('2023-10-31 00:00:00')),
PARTITION pt_20231031 VALUES [('2023-10-31 00:00:00'), ('2023-11-01 00:00:00')),
PARTITION pt_20231101 VALUES [('2023-11-01 00:00:00'), ('2023-11-02 00:00:00')),
PARTITION pt_20231102 VALUES [('2023-11-02 00:00:00'), ('2023-11-03 00:00:00')),
PARTITION pt_20231103 VALUES [('2023-11-03 00:00:00'), ('2023-11-04 00:00:00')),
PARTITION pt_20231104 VALUES [('2023-11-04 00:00:00'), ('2023-11-05 00:00:00')),
PARTITION pt_20231105 VALUES [('2023-11-05 00:00:00'), ('2023-11-06 00:00:00')),
PARTITION pt_20231106 VALUES [('2023-11-06 00:00:00'), ('2023-11-07 00:00:00')),
PARTITION pt_20231107 VALUES [('2023-11-07 00:00:00'), ('2023-11-08 00:00:00')),
PARTITION pt_20231108 VALUES [('2023-11-08 00:00:00'), ('2023-11-09 00:00:00')),
PARTITION pt_20231109 VALUES [('2023-11-09 00:00:00'), ('2023-11-10 00:00:00')),
PARTITION pt_20231110 VALUES [('2023-11-10 00:00:00'), ('2023-11-11 00:00:00')),
PARTITION pt_20231111 VALUES [('2023-11-11 00:00:00'), ('2023-11-12 00:00:00')),
PARTITION pt_20231112 VALUES [('2023-11-12 00:00:00'), ('2023-11-13 00:00:00')),
PARTITION pt_20231113 VALUES [('2023-11-13 00:00:00'), ('2023-11-14 00:00:00')),
PARTITION pt_20231114 VALUES [('2023-11-14 00:00:00'), ('2023-11-15 00:00:00')),
PARTITION pt_20231115 VALUES [('2023-11-15 00:00:00'), ('2023-11-16 00:00:00')),
PARTITION pt_20231116 VALUES [('2023-11-16 00:00:00'), ('2023-11-17 00:00:00')),
PARTITION pt_20231117 VALUES [('2023-11-17 00:00:00'), ('2023-11-18 00:00:00')),
PARTITION pt_20231118 VALUES [('2023-11-18 00:00:00'), ('2023-11-19 00:00:00')),
PARTITION pt_20231119 VALUES [('2023-11-19 00:00:00'), ('2023-11-20 00:00:00')),
PARTITION pt_20231120 VALUES [('2023-11-20 00:00:00'), ('2023-11-21 00:00:00')),
PARTITION pt_20231121 VALUES [('2023-11-21 00:00:00'), ('2023-11-22 00:00:00')),
PARTITION pt_20231122 VALUES [('2023-11-22 00:00:00'), ('2023-11-23 00:00:00')),
PARTITION pt_20231123 VALUES [('2023-11-23 00:00:00'), ('2023-11-24 00:00:00')),
PARTITION pt_20231124 VALUES [('2023-11-24 00:00:00'), ('2023-11-25 00:00:00')),
PARTITION pt_20231125 VALUES [('2023-11-25 00:00:00'), ('2023-11-26 00:00:00')),
PARTITION pt_20231126 VALUES [('2023-11-26 00:00:00'), ('2023-11-27 00:00:00')),
PARTITION pt_20231127 VALUES [('2023-11-27 00:00:00'), ('2023-11-28 00:00:00')),
PARTITION pt_20231128 VALUES [('2023-11-28 00:00:00'), ('2023-11-29 00:00:00')),
PARTITION pt_20231129 VALUES [('2023-11-29 00:00:00'), ('2023-11-30 00:00:00')),
PARTITION pt_20231130 VALUES [('2023-11-30 00:00:00'), ('2023-12-01 00:00:00')),
PARTITION pt_20231201 VALUES [('2023-12-01 00:00:00'), ('2023-12-02 00:00:00')),
PARTITION pt_20231202 VALUES [('2023-12-02 00:00:00'), ('2023-12-03 00:00:00')),
PARTITION pt_20231203 VALUES [('2023-12-03 00:00:00'), ('2023-12-04 00:00:00')),
PARTITION pt_20231204 VALUES [('2023-12-04 00:00:00'), ('2023-12-05 00:00:00')),
PARTITION pt_20231205 VALUES [('2023-12-05 00:00:00'), ('2023-12-06 00:00:00')),
PARTITION pt_20231206 VALUES [('2023-12-06 00:00:00'), ('2023-12-07 00:00:00')),
PARTITION pt_20231207 VALUES [('2023-12-07 00:00:00'), ('2023-12-08 00:00:00')),
PARTITION pt_20231208 VALUES [('2023-12-08 00:00:00'), ('2023-12-09 00:00:00')),
PARTITION pt_20231209 VALUES [('2023-12-09 00:00:00'), ('2023-12-10 00:00:00')),
PARTITION pt_20231210 VALUES [('2023-12-10 00:00:00'), ('2023-12-11 00:00:00')),
PARTITION pt_20231211 VALUES [('2023-12-11 00:00:00'), ('2023-12-12 00:00:00')),
PARTITION pt_20231212 VALUES [('2023-12-12 00:00:00'), ('2023-12-13 00:00:00')),
PARTITION pt_20231213 VALUES [('2023-12-13 00:00:00'), ('2023-12-14 00:00:00')),
PARTITION pt_20231214 VALUES [('2023-12-14 00:00:00'), ('2023-12-15 00:00:00')),
PARTITION pt_20231215 VALUES [('2023-12-15 00:00:00'), ('2023-12-16 00:00:00')),
PARTITION pt_20231216 VALUES [('2023-12-16 00:00:00'), ('2023-12-17 00:00:00')),
PARTITION pt_20231217 VALUES [('2023-12-17 00:00:00'), ('2023-12-18 00:00:00')),
PARTITION pt_20231218 VALUES [('2023-12-18 00:00:00'), ('2023-12-19 00:00:00')),
PARTITION pt_20231219 VALUES [('2023-12-19 00:00:00'), ('2023-12-20 00:00:00')),
PARTITION pt_20231220 VALUES [('2023-12-20 00:00:00'), ('2023-12-21 00:00:00')),
PARTITION pt_20231221 VALUES [('2023-12-21 00:00:00'), ('2023-12-22 00:00:00')),
PARTITION pt_20231222 VALUES [('2023-12-22 00:00:00'), ('2023-12-23 00:00:00')),
PARTITION pt_20231223 VALUES [('2023-12-23 00:00:00'), ('2023-12-24 00:00:00')),
PARTITION pt_20231224 VALUES [('2023-12-24 00:00:00'), ('2023-12-25 00:00:00')),
PARTITION pt_20231225 VALUES [('2023-12-25 00:00:00'), ('2023-12-26 00:00:00')),
PARTITION pt_20231226 VALUES [('2023-12-26 00:00:00'), ('2023-12-27 00:00:00')),
PARTITION pt_20231227 VALUES [('2023-12-27 00:00:00'), ('2023-12-28 00:00:00')),
PARTITION pt_20231228 VALUES [('2023-12-28 00:00:00'), ('2023-12-29 00:00:00')),
PARTITION pt_20231229 VALUES [('2023-12-29 00:00:00'), ('2023-12-30 00:00:00')),
PARTITION pt_20231230 VALUES [('2023-12-30 00:00:00'), ('2023-12-31 00:00:00')),
PARTITION pt_20231231 VALUES [('2023-12-31 00:00:00'), ('2024-01-01 00:00:00')),
PARTITION pt_20240101 VALUES [('2024-01-01 00:00:00'), ('2024-01-02 00:00:00')),
PARTITION pt_20240102 VALUES [('2024-01-02 00:00:00'), ('2024-01-03 00:00:00')),
PARTITION pt_20240103 VALUES [('2024-01-03 00:00:00'), ('2024-01-04 00:00:00')),
PARTITION pt_20240104 VALUES [('2024-01-04 00:00:00'), ('2024-01-05 00:00:00')),
PARTITION pt_20240105 VALUES [('2024-01-05 00:00:00'), ('2024-01-06 00:00:00')),
PARTITION pt_20240106 VALUES [('2024-01-06 00:00:00'), ('2024-01-07 00:00:00')),
PARTITION pt_20240107 VALUES [('2024-01-07 00:00:00'), ('2024-01-08 00:00:00')),
PARTITION pt_20240108 VALUES [('2024-01-08 00:00:00'), ('2024-01-09 00:00:00')),
PARTITION pt_20240109 VALUES [('2024-01-09 00:00:00'), ('2024-01-10 00:00:00')),
PARTITION pt_20240110 VALUES [('2024-01-10 00:00:00'), ('2024-01-11 00:00:00')),
PARTITION pt_20240111 VALUES [('2024-01-11 00:00:00'), ('2024-01-12 00:00:00')),
PARTITION pt_20240112 VALUES [('2024-01-12 00:00:00'), ('2024-01-13 00:00:00')),
PARTITION pt_20240113 VALUES [('2024-01-13 00:00:00'), ('2024-01-14 00:00:00')),
PARTITION pt_20240114 VALUES [('2024-01-14 00:00:00'), ('2024-01-15 00:00:00')),
PARTITION pt_20240115 VALUES [('2024-01-15 00:00:00'), ('2024-01-16 00:00:00')),
PARTITION pt_20240116 VALUES [('2024-01-16 00:00:00'), ('2024-01-17 00:00:00')),
PARTITION pt_20240117 VALUES [('2024-01-17 00:00:00'), ('2024-01-18 00:00:00')),
PARTITION pt_20240118 VALUES [('2024-01-18 00:00:00'), ('2024-01-19 00:00:00')),
PARTITION pt_20240119 VALUES [('2024-01-19 00:00:00'), ('2024-01-20 00:00:00')),
PARTITION pt_20240120 VALUES [('2024-01-20 00:00:00'), ('2024-01-21 00:00:00')),
PARTITION pt_20240121 VALUES [('2024-01-21 00:00:00'), ('2024-01-22 00:00:00')),
PARTITION pt_20240122 VALUES [('2024-01-22 00:00:00'), ('2024-01-23 00:00:00')),
PARTITION pt_20240123 VALUES [('2024-01-23 00:00:00'), ('2024-01-24 00:00:00')),
PARTITION pt_20240124 VALUES [('2024-01-24 00:00:00'), ('2024-01-25 00:00:00')),
PARTITION pt_20240125 VALUES [('2024-01-25 00:00:00'), ('2024-01-26 00:00:00')),
PARTITION pt_20240126 VALUES [('2024-01-26 00:00:00'), ('2024-01-27 00:00:00')),
PARTITION pt_20240127 VALUES [('2024-01-27 00:00:00'), ('2024-01-28 00:00:00')),
PARTITION pt_20240128 VALUES [('2024-01-28 00:00:00'), ('2024-01-29 00:00:00')),
PARTITION pt_20240129 VALUES [('2024-01-29 00:00:00'), ('2024-01-30 00:00:00')),
PARTITION pt_20240130 VALUES [('2024-01-30 00:00:00'), ('2024-01-31 00:00:00')),
PARTITION pt_20240131 VALUES [('2024-01-31 00:00:00'), ('2024-02-01 00:00:00')),
PARTITION pt_20240201 VALUES [('2024-02-01 00:00:00'), ('2024-02-02 00:00:00')),
PARTITION pt_20240202 VALUES [('2024-02-02 00:00:00'), ('2024-02-03 00:00:00')),
PARTITION pt_20240203 VALUES [('2024-02-03 00:00:00'), ('2024-02-04 00:00:00')),
PARTITION pt_20240204 VALUES [('2024-02-04 00:00:00'), ('2024-02-05 00:00:00')),
PARTITION pt_20240205 VALUES [('2024-02-05 00:00:00'), ('2024-02-06 00:00:00')),
PARTITION pt_20240206 VALUES [('2024-02-06 00:00:00'), ('2024-02-07 00:00:00')),
PARTITION pt_20240207 VALUES [('2024-02-07 00:00:00'), ('2024-02-08 00:00:00')),
PARTITION pt_20240208 VALUES [('2024-02-08 00:00:00'), ('2024-02-09 00:00:00')),
PARTITION pt_20240209 VALUES [('2024-02-09 00:00:00'), ('2024-02-10 00:00:00')),
PARTITION pt_20240210 VALUES [('2024-02-10 00:00:00'), ('2024-02-11 00:00:00')),
PARTITION pt_20240211 VALUES [('2024-02-11 00:00:00'), ('2024-02-12 00:00:00')),
PARTITION pt_20240212 VALUES [('2024-02-12 00:00:00'), ('2024-02-13 00:00:00')),
PARTITION pt_20240213 VALUES [('2024-02-13 00:00:00'), ('2024-02-14 00:00:00')),
PARTITION pt_20240214 VALUES [('2024-02-14 00:00:00'), ('2024-02-15 00:00:00')),
PARTITION pt_20240215 VALUES [('2024-02-15 00:00:00'), ('2024-02-16 00:00:00')),
PARTITION pt_20240216 VALUES [('2024-02-16 00:00:00'), ('2024-02-17 00:00:00')),
PARTITION pt_20240217 VALUES [('2024-02-17 00:00:00'), ('2024-02-18 00:00:00')),
PARTITION pt_20240218 VALUES [('2024-02-18 00:00:00'), ('2024-02-19 00:00:00')),
PARTITION pt_20240219 VALUES [('2024-02-19 00:00:00'), ('2024-02-20 00:00:00')),
PARTITION pt_20240220 VALUES [('2024-02-20 00:00:00'), ('2024-02-21 00:00:00')),
PARTITION pt_20240221 VALUES [('2024-02-21 00:00:00'), ('2024-02-22 00:00:00')),
PARTITION pt_20240222 VALUES [('2024-02-22 00:00:00'), ('2024-02-23 00:00:00')),
PARTITION pt_20240223 VALUES [('2024-02-23 00:00:00'), ('2024-02-24 00:00:00')),
PARTITION pt_20240224 VALUES [('2024-02-24 00:00:00'), ('2024-02-25 00:00:00')),
PARTITION pt_20240225 VALUES [('2024-02-25 00:00:00'), ('2024-02-26 00:00:00')),
PARTITION pt_20240226 VALUES [('2024-02-26 00:00:00'), ('2024-02-27 00:00:00')),
PARTITION pt_20240227 VALUES [('2024-02-27 00:00:00'), ('2024-02-28 00:00:00')),
PARTITION pt_20240228 VALUES [('2024-02-28 00:00:00'), ('2024-02-29 00:00:00')),
PARTITION pt_20240229 VALUES [('2024-02-29 00:00:00'), ('2024-03-01 00:00:00')),
PARTITION pt_20240301 VALUES [('2024-03-01 00:00:00'), ('2024-03-02 00:00:00')),
PARTITION pt_20240302 VALUES [('2024-03-02 00:00:00'), ('2024-03-03 00:00:00')),
PARTITION pt_20240303 VALUES [('2024-03-03 00:00:00'), ('2024-03-04 00:00:00')),
PARTITION pt_20240304 VALUES [('2024-03-04 00:00:00'), ('2024-03-05 00:00:00')),
PARTITION pt_20240305 VALUES [('2024-03-05 00:00:00'), ('2024-03-06 00:00:00')),
PARTITION pt_20240306 VALUES [('2024-03-06 00:00:00'), ('2024-03-07 00:00:00')),
PARTITION pt_20240307 VALUES [('2024-03-07 00:00:00'), ('2024-03-08 00:00:00')),
PARTITION pt_20240308 VALUES [('2024-03-08 00:00:00'), ('2024-03-09 00:00:00')),
PARTITION pt_20240309 VALUES [('2024-03-09 00:00:00'), ('2024-03-10 00:00:00')),
PARTITION pt_20240310 VALUES [('2024-03-10 00:00:00'), ('2024-03-11 00:00:00')),
PARTITION pt_20240311 VALUES [('2024-03-11 00:00:00'), ('2024-03-12 00:00:00')),
PARTITION pt_20240312 VALUES [('2024-03-12 00:00:00'), ('2024-03-13 00:00:00')),
PARTITION pt_20240313 VALUES [('2024-03-13 00:00:00'), ('2024-03-14 00:00:00')),
PARTITION pt_20240314 VALUES [('2024-03-14 00:00:00'), ('2024-03-15 00:00:00')),
PARTITION pt_20240315 VALUES [('2024-03-15 00:00:00'), ('2024-03-16 00:00:00')),
PARTITION pt_20240316 VALUES [('2024-03-16 00:00:00'), ('2024-03-17 00:00:00')),
PARTITION pt_20240317 VALUES [('2024-03-17 00:00:00'), ('2024-03-18 00:00:00')),
PARTITION pt_20240318 VALUES [('2024-03-18 00:00:00'), ('2024-03-19 00:00:00')),
PARTITION pt_20240319 VALUES [('2024-03-19 00:00:00'), ('2024-03-20 00:00:00')),
PARTITION pt_20240320 VALUES [('2024-03-20 00:00:00'), ('2024-03-21 00:00:00')),
PARTITION pt_20240321 VALUES [('2024-03-21 00:00:00'), ('2024-03-22 00:00:00')),
PARTITION pt_20240322 VALUES [('2024-03-22 00:00:00'), ('2024-03-23 00:00:00')),
PARTITION pt_20240323 VALUES [('2024-03-23 00:00:00'), ('2024-03-24 00:00:00')),
PARTITION pt_20240324 VALUES [('2024-03-24 00:00:00'), ('2024-03-25 00:00:00')),
PARTITION pt_20240325 VALUES [('2024-03-25 00:00:00'), ('2024-03-26 00:00:00')),
PARTITION pt_20240326 VALUES [('2024-03-26 00:00:00'), ('2024-03-27 00:00:00')),
PARTITION pt_20240327 VALUES [('2024-03-27 00:00:00'), ('2024-03-28 00:00:00')),
PARTITION pt_20240328 VALUES [('2024-03-28 00:00:00'), ('2024-03-29 00:00:00')),
PARTITION pt_20240329 VALUES [('2024-03-29 00:00:00'), ('2024-03-30 00:00:00')),
PARTITION pt_20240330 VALUES [('2024-03-30 00:00:00'), ('2024-03-31 00:00:00')),
PARTITION pt_20240331 VALUES [('2024-03-31 00:00:00'), ('2024-04-01 00:00:00')),
PARTITION pt_20240401 VALUES [('2024-04-01 00:00:00'), ('2024-04-02 00:00:00')),
PARTITION pt_20240402 VALUES [('2024-04-02 00:00:00'), ('2024-04-03 00:00:00')),
PARTITION pt_20240403 VALUES [('2024-04-03 00:00:00'), ('2024-04-04 00:00:00')),
PARTITION pt_20240404 VALUES [('2024-04-04 00:00:00'), ('2024-04-05 00:00:00')),
PARTITION pt_20240405 VALUES [('2024-04-05 00:00:00'), ('2024-04-06 00:00:00')),
PARTITION pt_20240406 VALUES [('2024-04-06 00:00:00'), ('2024-04-07 00:00:00')),
PARTITION pt_20240407 VALUES [('2024-04-07 00:00:00'), ('2024-04-08 00:00:00')),
PARTITION pt_20240408 VALUES [('2024-04-08 00:00:00'), ('2024-04-09 00:00:00')),
PARTITION pt_20240409 VALUES [('2024-04-09 00:00:00'), ('2024-04-10 00:00:00')),
PARTITION pt_20240410 VALUES [('2024-04-10 00:00:00'), ('2024-04-11 00:00:00')),
PARTITION pt_20240411 VALUES [('2024-04-11 00:00:00'), ('2024-04-12 00:00:00')),
PARTITION pt_20240412 VALUES [('2024-04-12 00:00:00'), ('2024-04-13 00:00:00')),
PARTITION pt_20240413 VALUES [('2024-04-13 00:00:00'), ('2024-04-14 00:00:00')),
PARTITION pt_20240414 VALUES [('2024-04-14 00:00:00'), ('2024-04-15 00:00:00')),
PARTITION pt_20240415 VALUES [('2024-04-15 00:00:00'), ('2024-04-16 00:00:00')),
PARTITION pt_20240416 VALUES [('2024-04-16 00:00:00'), ('2024-04-17 00:00:00')),
PARTITION pt_20240417 VALUES [('2024-04-17 00:00:00'), ('2024-04-18 00:00:00')),
PARTITION pt_20240418 VALUES [('2024-04-18 00:00:00'), ('2024-04-19 00:00:00')),
PARTITION pt_20240419 VALUES [('2024-04-19 00:00:00'), ('2024-04-20 00:00:00')),
PARTITION pt_20240420 VALUES [('2024-04-20 00:00:00'), ('2024-04-21 00:00:00')),
PARTITION pt_20240421 VALUES [('2024-04-21 00:00:00'), ('2024-04-22 00:00:00')),
PARTITION pt_20240422 VALUES [('2024-04-22 00:00:00'), ('2024-04-23 00:00:00')),
PARTITION pt_20240423 VALUES [('2024-04-23 00:00:00'), ('2024-04-24 00:00:00')),
PARTITION pt_20240424 VALUES [('2024-04-24 00:00:00'), ('2024-04-25 00:00:00')),
PARTITION pt_20240425 VALUES [('2024-04-25 00:00:00'), ('2024-04-26 00:00:00')),
PARTITION pt_20240426 VALUES [('2024-04-26 00:00:00'), ('2024-04-27 00:00:00')),
PARTITION pt_20240427 VALUES [('2024-04-27 00:00:00'), ('2024-04-28 00:00:00')),
PARTITION pt_20240428 VALUES [('2024-04-28 00:00:00'), ('2024-04-29 00:00:00')),
PARTITION pt_20240429 VALUES [('2024-04-29 00:00:00'), ('2024-04-30 00:00:00')),
PARTITION pt_20240430 VALUES [('2024-04-30 00:00:00'), ('2024-05-01 00:00:00')),
PARTITION pt_20240501 VALUES [('2024-05-01 00:00:00'), ('2024-05-02 00:00:00')),
PARTITION pt_20240502 VALUES [('2024-05-02 00:00:00'), ('2024-05-03 00:00:00')),
PARTITION pt_20240503 VALUES [('2024-05-03 00:00:00'), ('2024-05-04 00:00:00')),
PARTITION pt_20240504 VALUES [('2024-05-04 00:00:00'), ('2024-05-05 00:00:00')),
PARTITION pt_20240505 VALUES [('2024-05-05 00:00:00'), ('2024-05-06 00:00:00')),
PARTITION pt_20240506 VALUES [('2024-05-06 00:00:00'), ('2024-05-07 00:00:00')),
PARTITION pt_20240507 VALUES [('2024-05-07 00:00:00'), ('2024-05-08 00:00:00')),
PARTITION pt_20240508 VALUES [('2024-05-08 00:00:00'), ('2024-05-09 00:00:00')),
PARTITION pt_20240509 VALUES [('2024-05-09 00:00:00'), ('2024-05-10 00:00:00')),
PARTITION pt_20240510 VALUES [('2024-05-10 00:00:00'), ('2024-05-11 00:00:00')),
PARTITION pt_20240511 VALUES [('2024-05-11 00:00:00'), ('2024-05-12 00:00:00')),
PARTITION pt_20240512 VALUES [('2024-05-12 00:00:00'), ('2024-05-13 00:00:00')),
PARTITION pt_20240513 VALUES [('2024-05-13 00:00:00'), ('2024-05-14 00:00:00')),
PARTITION pt_20240514 VALUES [('2024-05-14 00:00:00'), ('2024-05-15 00:00:00')),
PARTITION pt_20240515 VALUES [('2024-05-15 00:00:00'), ('2024-05-16 00:00:00')),
PARTITION pt_20240516 VALUES [('2024-05-16 00:00:00'), ('2024-05-17 00:00:00')),
PARTITION pt_20240517 VALUES [('2024-05-17 00:00:00'), ('2024-05-18 00:00:00')),
PARTITION pt_20240518 VALUES [('2024-05-18 00:00:00'), ('2024-05-19 00:00:00')),
PARTITION pt_20240519 VALUES [('2024-05-19 00:00:00'), ('2024-05-20 00:00:00')),
PARTITION pt_20240520 VALUES [('2024-05-20 00:00:00'), ('2024-05-21 00:00:00')),
PARTITION pt_20240521 VALUES [('2024-05-21 00:00:00'), ('2024-05-22 00:00:00')),
PARTITION pt_20240522 VALUES [('2024-05-22 00:00:00'), ('2024-05-23 00:00:00')),
PARTITION pt_20240523 VALUES [('2024-05-23 00:00:00'), ('2024-05-24 00:00:00')),
PARTITION pt_20240524 VALUES [('2024-05-24 00:00:00'), ('2024-05-25 00:00:00')),
PARTITION pt_20240525 VALUES [('2024-05-25 00:00:00'), ('2024-05-26 00:00:00')),
PARTITION pt_20240526 VALUES [('2024-05-26 00:00:00'), ('2024-05-27 00:00:00')),
PARTITION pt_20240527 VALUES [('2024-05-27 00:00:00'), ('2024-05-28 00:00:00')),
PARTITION pt_20240528 VALUES [('2024-05-28 00:00:00'), ('2024-05-29 00:00:00')),
PARTITION pt_20240529 VALUES [('2024-05-29 00:00:00'), ('2024-05-30 00:00:00')),
PARTITION pt_20240530 VALUES [('2024-05-30 00:00:00'), ('2024-05-31 00:00:00')),
PARTITION pt_20240531 VALUES [('2024-05-31 00:00:00'), ('2024-06-01 00:00:00')),
PARTITION pt_20240601 VALUES [('2024-06-01 00:00:00'), ('2024-06-02 00:00:00')),
PARTITION pt_20240602 VALUES [('2024-06-02 00:00:00'), ('2024-06-03 00:00:00')),
PARTITION pt_20240603 VALUES [('2024-06-03 00:00:00'), ('2024-06-04 00:00:00')),
PARTITION pt_20240604 VALUES [('2024-06-04 00:00:00'), ('2024-06-05 00:00:00')),
PARTITION pt_20240605 VALUES [('2024-06-05 00:00:00'), ('2024-06-06 00:00:00')),
PARTITION pt_20240606 VALUES [('2024-06-06 00:00:00'), ('2024-06-07 00:00:00')),
PARTITION pt_20240607 VALUES [('2024-06-07 00:00:00'), ('2024-06-08 00:00:00')),
PARTITION pt_20240608 VALUES [('2024-06-08 00:00:00'), ('2024-06-09 00:00:00')),
PARTITION pt_20240609 VALUES [('2024-06-09 00:00:00'), ('2024-06-10 00:00:00')),
PARTITION pt_20240610 VALUES [('2024-06-10 00:00:00'), ('2024-06-11 00:00:00')),
PARTITION pt_20240611 VALUES [('2024-06-11 00:00:00'), ('2024-06-12 00:00:00')),
PARTITION pt_20240612 VALUES [('2024-06-12 00:00:00'), ('2024-06-13 00:00:00')),
PARTITION pt_20240613 VALUES [('2024-06-13 00:00:00'), ('2024-06-14 00:00:00')),
PARTITION pt_20240614 VALUES [('2024-06-14 00:00:00'), ('2024-06-15 00:00:00')),
PARTITION pt_20240615 VALUES [('2024-06-15 00:00:00'), ('2024-06-16 00:00:00')),
PARTITION pt_20240616 VALUES [('2024-06-16 00:00:00'), ('2024-06-17 00:00:00')),
PARTITION pt_20240617 VALUES [('2024-06-17 00:00:00'), ('2024-06-18 00:00:00')),
PARTITION pt_20240618 VALUES [('2024-06-18 00:00:00'), ('2024-06-19 00:00:00')),
PARTITION pt_20240619 VALUES [('2024-06-19 00:00:00'), ('2024-06-20 00:00:00')),
PARTITION pt_20240620 VALUES [('2024-06-20 00:00:00'), ('2024-06-21 00:00:00')),
PARTITION pt_20240621 VALUES [('2024-06-21 00:00:00'), ('2024-06-22 00:00:00')),
PARTITION pt_20240622 VALUES [('2024-06-22 00:00:00'), ('2024-06-23 00:00:00')),
PARTITION pt_20240623 VALUES [('2024-06-23 00:00:00'), ('2024-06-24 00:00:00')),
PARTITION pt_20240624 VALUES [('2024-06-24 00:00:00'), ('2024-06-25 00:00:00')),
PARTITION pt_20240625 VALUES [('2024-06-25 00:00:00'), ('2024-06-26 00:00:00')),
PARTITION pt_20240626 VALUES [('2024-06-26 00:00:00'), ('2024-06-27 00:00:00')),
PARTITION pt_20240627 VALUES [('2024-06-27 00:00:00'), ('2024-06-28 00:00:00')),
PARTITION pt_20240628 VALUES [('2024-06-28 00:00:00'), ('2024-06-29 00:00:00')),
PARTITION pt_20240629 VALUES [('2024-06-29 00:00:00'), ('2024-06-30 00:00:00')),
PARTITION pt_20240630 VALUES [('2024-06-30 00:00:00'), ('2024-07-01 00:00:00')),
PARTITION pt_20240701 VALUES [('2024-07-01 00:00:00'), ('2024-07-02 00:00:00')),
PARTITION pt_20240702 VALUES [('2024-07-02 00:00:00'), ('2024-07-03 00:00:00')),
PARTITION pt_20240703 VALUES [('2024-07-03 00:00:00'), ('2024-07-04 00:00:00')),
PARTITION pt_20240704 VALUES [('2024-07-04 00:00:00'), ('2024-07-05 00:00:00')),
PARTITION pt_20240705 VALUES [('2024-07-05 00:00:00'), ('2024-07-06 00:00:00')),
PARTITION pt_20240706 VALUES [('2024-07-06 00:00:00'), ('2024-07-07 00:00:00')),
PARTITION pt_20240707 VALUES [('2024-07-07 00:00:00'), ('2024-07-08 00:00:00')),
PARTITION pt_20240708 VALUES [('2024-07-08 00:00:00'), ('2024-07-09 00:00:00')),
PARTITION pt_20240709 VALUES [('2024-07-09 00:00:00'), ('2024-07-10 00:00:00')),
PARTITION pt_20240710 VALUES [('2024-07-10 00:00:00'), ('2024-07-11 00:00:00')),
PARTITION pt_20240711 VALUES [('2024-07-11 00:00:00'), ('2024-07-12 00:00:00')),
PARTITION pt_20240712 VALUES [('2024-07-12 00:00:00'), ('2024-07-13 00:00:00')),
PARTITION pt_20240713 VALUES [('2024-07-13 00:00:00'), ('2024-07-14 00:00:00')),
PARTITION pt_20240714 VALUES [('2024-07-14 00:00:00'), ('2024-07-15 00:00:00')),
PARTITION pt_20240715 VALUES [('2024-07-15 00:00:00'), ('2024-07-16 00:00:00')),
PARTITION pt_20240716 VALUES [('2024-07-16 00:00:00'), ('2024-07-17 00:00:00')),
PARTITION pt_20240717 VALUES [('2024-07-17 00:00:00'), ('2024-07-18 00:00:00')),
PARTITION pt_20240718 VALUES [('2024-07-18 00:00:00'), ('2024-07-19 00:00:00')),
PARTITION pt_20240719 VALUES [('2024-07-19 00:00:00'), ('2024-07-20 00:00:00')),
PARTITION pt_20240720 VALUES [('2024-07-20 00:00:00'), ('2024-07-21 00:00:00')),
PARTITION pt_20240721 VALUES [('2024-07-21 00:00:00'), ('2024-07-22 00:00:00')),
PARTITION pt_20240722 VALUES [('2024-07-22 00:00:00'), ('2024-07-23 00:00:00')),
PARTITION pt_20240723 VALUES [('2024-07-23 00:00:00'), ('2024-07-24 00:00:00')),
PARTITION pt_20240724 VALUES [('2024-07-24 00:00:00'), ('2024-07-25 00:00:00')),
PARTITION pt_20240725 VALUES [('2024-07-25 00:00:00'), ('2024-07-26 00:00:00')),
PARTITION pt_20240726 VALUES [('2024-07-26 00:00:00'), ('2024-07-27 00:00:00')),
PARTITION pt_20240727 VALUES [('2024-07-27 00:00:00'), ('2024-07-28 00:00:00')),
PARTITION pt_20240728 VALUES [('2024-07-28 00:00:00'), ('2024-07-29 00:00:00')),
PARTITION pt_20240729 VALUES [('2024-07-29 00:00:00'), ('2024-07-30 00:00:00')),
PARTITION pt_20240730 VALUES [('2024-07-30 00:00:00'), ('2024-07-31 00:00:00')),
PARTITION pt_20240731 VALUES [('2024-07-31 00:00:00'), ('2024-08-01 00:00:00')),
PARTITION pt_20240801 VALUES [('2024-08-01 00:00:00'), ('2024-08-02 00:00:00')),
PARTITION pt_20240802 VALUES [('2024-08-02 00:00:00'), ('2024-08-03 00:00:00')),
PARTITION pt_20240803 VALUES [('2024-08-03 00:00:00'), ('2024-08-04 00:00:00')),
PARTITION pt_20240804 VALUES [('2024-08-04 00:00:00'), ('2024-08-05 00:00:00')),
PARTITION pt_20240805 VALUES [('2024-08-05 00:00:00'), ('2024-08-06 00:00:00')),
PARTITION pt_20240806 VALUES [('2024-08-06 00:00:00'), ('2024-08-07 00:00:00')),
PARTITION pt_20240807 VALUES [('2024-08-07 00:00:00'), ('2024-08-08 00:00:00')),
PARTITION pt_20240808 VALUES [('2024-08-08 00:00:00'), ('2024-08-09 00:00:00')),
PARTITION pt_20240809 VALUES [('2024-08-09 00:00:00'), ('2024-08-10 00:00:00')),
PARTITION pt_20240810 VALUES [('2024-08-10 00:00:00'), ('2024-08-11 00:00:00')),
PARTITION pt_20240811 VALUES [('2024-08-11 00:00:00'), ('2024-08-12 00:00:00')),
PARTITION pt_20240812 VALUES [('2024-08-12 00:00:00'), ('2024-08-13 00:00:00')),
PARTITION pt_20240813 VALUES [('2024-08-13 00:00:00'), ('2024-08-14 00:00:00')),
PARTITION pt_20240814 VALUES [('2024-08-14 00:00:00'), ('2024-08-15 00:00:00')),
PARTITION pt_20240815 VALUES [('2024-08-15 00:00:00'), ('2024-08-16 00:00:00')),
PARTITION pt_20240816 VALUES [('2024-08-16 00:00:00'), ('2024-08-17 00:00:00')),
PARTITION pt_20240817 VALUES [('2024-08-17 00:00:00'), ('2024-08-18 00:00:00')),
PARTITION pt_20240818 VALUES [('2024-08-18 00:00:00'), ('2024-08-19 00:00:00')),
PARTITION pt_20240819 VALUES [('2024-08-19 00:00:00'), ('2024-08-20 00:00:00')),
PARTITION pt_20240820 VALUES [('2024-08-20 00:00:00'), ('2024-08-21 00:00:00')),
PARTITION pt_20240821 VALUES [('2024-08-21 00:00:00'), ('2024-08-22 00:00:00')),
PARTITION pt_20240822 VALUES [('2024-08-22 00:00:00'), ('2024-08-23 00:00:00')),
PARTITION pt_20240823 VALUES [('2024-08-23 00:00:00'), ('2024-08-24 00:00:00')),
PARTITION pt_20240824 VALUES [('2024-08-24 00:00:00'), ('2024-08-25 00:00:00')),
PARTITION pt_20240825 VALUES [('2024-08-25 00:00:00'), ('2024-08-26 00:00:00')),
PARTITION pt_20240826 VALUES [('2024-08-26 00:00:00'), ('2024-08-27 00:00:00')),
PARTITION pt_20240827 VALUES [('2024-08-27 00:00:00'), ('2024-08-28 00:00:00')),
PARTITION pt_20240828 VALUES [('2024-08-28 00:00:00'), ('2024-08-29 00:00:00')),
PARTITION pt_20240829 VALUES [('2024-08-29 00:00:00'), ('2024-08-30 00:00:00')),
PARTITION pt_20240830 VALUES [('2024-08-30 00:00:00'), ('2024-08-31 00:00:00')),
PARTITION pt_20240831 VALUES [('2024-08-31 00:00:00'), ('2024-09-01 00:00:00')),
PARTITION pt_20240901 VALUES [('2024-09-01 00:00:00'), ('2024-09-02 00:00:00')),
PARTITION pt_20240902 VALUES [('2024-09-02 00:00:00'), ('2024-09-03 00:00:00')),
PARTITION pt_20240903 VALUES [('2024-09-03 00:00:00'), ('2024-09-04 00:00:00')),
PARTITION pt_20240904 VALUES [('2024-09-04 00:00:00'), ('2024-09-05 00:00:00')),
PARTITION pt_20240905 VALUES [('2024-09-05 00:00:00'), ('2024-09-06 00:00:00')),
PARTITION pt_20240906 VALUES [('2024-09-06 00:00:00'), ('2024-09-07 00:00:00')),
PARTITION pt_20240907 VALUES [('2024-09-07 00:00:00'), ('2024-09-08 00:00:00')),
PARTITION pt_20240908 VALUES [('2024-09-08 00:00:00'), ('2024-09-09 00:00:00')),
PARTITION pt_20240909 VALUES [('2024-09-09 00:00:00'), ('2024-09-10 00:00:00')),
PARTITION pt_20240910 VALUES [('2024-09-10 00:00:00'), ('2024-09-11 00:00:00')),
PARTITION pt_20240911 VALUES [('2024-09-11 00:00:00'), ('2024-09-12 00:00:00')),
PARTITION pt_20240912 VALUES [('2024-09-12 00:00:00'), ('2024-09-13 00:00:00')),
PARTITION pt_20240913 VALUES [('2024-09-13 00:00:00'), ('2024-09-14 00:00:00')),
PARTITION pt_20240914 VALUES [('2024-09-14 00:00:00'), ('2024-09-15 00:00:00')),
PARTITION pt_20240915 VALUES [('2024-09-15 00:00:00'), ('2024-09-16 00:00:00')),
PARTITION pt_20240916 VALUES [('2024-09-16 00:00:00'), ('2024-09-17 00:00:00')),
PARTITION pt_20240917 VALUES [('2024-09-17 00:00:00'), ('2024-09-18 00:00:00')),
PARTITION pt_20240918 VALUES [('2024-09-18 00:00:00'), ('2024-09-19 00:00:00')),
PARTITION pt_20240919 VALUES [('2024-09-19 00:00:00'), ('2024-09-20 00:00:00')),
PARTITION pt_20240920 VALUES [('2024-09-20 00:00:00'), ('2024-09-21 00:00:00')),
PARTITION pt_20240921 VALUES [('2024-09-21 00:00:00'), ('2024-09-22 00:00:00')),
PARTITION pt_20240922 VALUES [('2024-09-22 00:00:00'), ('2024-09-23 00:00:00')),
PARTITION pt_20240923 VALUES [('2024-09-23 00:00:00'), ('2024-09-24 00:00:00')),
PARTITION pt_20240924 VALUES [('2024-09-24 00:00:00'), ('2024-09-25 00:00:00')),
PARTITION pt_20240925 VALUES [('2024-09-25 00:00:00'), ('2024-09-26 00:00:00')),
PARTITION pt_20240926 VALUES [('2024-09-26 00:00:00'), ('2024-09-27 00:00:00')),
PARTITION pt_20240927 VALUES [('2024-09-27 00:00:00'), ('2024-09-28 00:00:00')),
PARTITION pt_20240928 VALUES [('2024-09-28 00:00:00'), ('2024-09-29 00:00:00')),
PARTITION pt_20240929 VALUES [('2024-09-29 00:00:00'), ('2024-09-30 00:00:00')),
PARTITION pt_20240930 VALUES [('2024-09-30 00:00:00'), ('2024-10-01 00:00:00')),
PARTITION pt_20241001 VALUES [('2024-10-01 00:00:00'), ('2024-10-02 00:00:00')),
PARTITION pt_20241002 VALUES [('2024-10-02 00:00:00'), ('2024-10-03 00:00:00')),
PARTITION pt_20241003 VALUES [('2024-10-03 00:00:00'), ('2024-10-04 00:00:00')),
PARTITION pt_20241004 VALUES [('2024-10-04 00:00:00'), ('2024-10-05 00:00:00')),
PARTITION pt_20241005 VALUES [('2024-10-05 00:00:00'), ('2024-10-06 00:00:00')),
PARTITION pt_20241006 VALUES [('2024-10-06 00:00:00'), ('2024-10-07 00:00:00')),
PARTITION pt_20241007 VALUES [('2024-10-07 00:00:00'), ('2024-10-08 00:00:00')),
PARTITION pt_20241008 VALUES [('2024-10-08 00:00:00'), ('2024-10-09 00:00:00')),
PARTITION pt_20241009 VALUES [('2024-10-09 00:00:00'), ('2024-10-10 00:00:00')),
PARTITION pt_20241010 VALUES [('2024-10-10 00:00:00'), ('2024-10-11 00:00:00')),
PARTITION pt_20241011 VALUES [('2024-10-11 00:00:00'), ('2024-10-12 00:00:00')),
PARTITION pt_20241012 VALUES [('2024-10-12 00:00:00'), ('2024-10-13 00:00:00')),
PARTITION pt_20241013 VALUES [('2024-10-13 00:00:00'), ('2024-10-14 00:00:00')),
PARTITION pt_20241014 VALUES [('2024-10-14 00:00:00'), ('2024-10-15 00:00:00')),
PARTITION pt_20241015 VALUES [('2024-10-15 00:00:00'), ('2024-10-16 00:00:00')),
PARTITION pt_20241016 VALUES [('2024-10-16 00:00:00'), ('2024-10-17 00:00:00')),
PARTITION pt_20241017 VALUES [('2024-10-17 00:00:00'), ('2024-10-18 00:00:00')),
PARTITION pt_20241018 VALUES [('2024-10-18 00:00:00'), ('2024-10-19 00:00:00')),
PARTITION pt_20241019 VALUES [('2024-10-19 00:00:00'), ('2024-10-20 00:00:00')),
PARTITION pt_20241020 VALUES [('2024-10-20 00:00:00'), ('2024-10-21 00:00:00')),
PARTITION pt_20241021 VALUES [('2024-10-21 00:00:00'), ('2024-10-22 00:00:00')),
PARTITION pt_20241022 VALUES [('2024-10-22 00:00:00'), ('2024-10-23 00:00:00')),
PARTITION pt_20241023 VALUES [('2024-10-23 00:00:00'), ('2024-10-24 00:00:00')),
PARTITION pt_20241024 VALUES [('2024-10-24 00:00:00'), ('2024-10-25 00:00:00')),
PARTITION pt_20241025 VALUES [('2024-10-25 00:00:00'), ('2024-10-26 00:00:00')),
PARTITION pt_20241026 VALUES [('2024-10-26 00:00:00'), ('2024-10-27 00:00:00')),
PARTITION pt_20241027 VALUES [('2024-10-27 00:00:00'), ('2024-10-28 00:00:00')),
PARTITION pt_20241028 VALUES [('2024-10-28 00:00:00'), ('2024-10-29 00:00:00')),
PARTITION pt_20241029 VALUES [('2024-10-29 00:00:00'), ('2024-10-30 00:00:00')),
PARTITION pt_20241030 VALUES [('2024-10-30 00:00:00'), ('2024-10-31 00:00:00')),
PARTITION pt_20241031 VALUES [('2024-10-31 00:00:00'), ('2024-11-01 00:00:00')),
PARTITION pt_20241101 VALUES [('2024-11-01 00:00:00'), ('2024-11-02 00:00:00')),
PARTITION pt_20241102 VALUES [('2024-11-02 00:00:00'), ('2024-11-03 00:00:00')),
PARTITION pt_20241103 VALUES [('2024-11-03 00:00:00'), ('2024-11-04 00:00:00')),
PARTITION pt_20241104 VALUES [('2024-11-04 00:00:00'), ('2024-11-05 00:00:00')),
PARTITION pt_20241105 VALUES [('2024-11-05 00:00:00'), ('2024-11-06 00:00:00')),
PARTITION pt_20241106 VALUES [('2024-11-06 00:00:00'), ('2024-11-07 00:00:00')),
PARTITION pt_20241107 VALUES [('2024-11-07 00:00:00'), ('2024-11-08 00:00:00')),
PARTITION pt_20241108 VALUES [('2024-11-08 00:00:00'), ('2024-11-09 00:00:00')),
PARTITION pt_20241109 VALUES [('2024-11-09 00:00:00'), ('2024-11-10 00:00:00')),
PARTITION pt_20241110 VALUES [('2024-11-10 00:00:00'), ('2024-11-11 00:00:00')),
PARTITION pt_20241111 VALUES [('2024-11-11 00:00:00'), ('2024-11-12 00:00:00')),
PARTITION pt_20241112 VALUES [('2024-11-12 00:00:00'), ('2024-11-13 00:00:00')),
PARTITION pt_20241113 VALUES [('2024-11-13 00:00:00'), ('2024-11-14 00:00:00')),
PARTITION pt_20241114 VALUES [('2024-11-14 00:00:00'), ('2024-11-15 00:00:00')),
PARTITION pt_20241115 VALUES [('2024-11-15 00:00:00'), ('2024-11-16 00:00:00')),
PARTITION pt_20241116 VALUES [('2024-11-16 00:00:00'), ('2024-11-17 00:00:00')),
PARTITION pt_20241117 VALUES [('2024-11-17 00:00:00'), ('2024-11-18 00:00:00')),
PARTITION pt_20241118 VALUES [('2024-11-18 00:00:00'), ('2024-11-19 00:00:00')),
PARTITION pt_20241119 VALUES [('2024-11-19 00:00:00'), ('2024-11-20 00:00:00')),
PARTITION pt_20241120 VALUES [('2024-11-20 00:00:00'), ('2024-11-21 00:00:00')),
PARTITION pt_20241121 VALUES [('2024-11-21 00:00:00'), ('2024-11-22 00:00:00')),
PARTITION pt_20241122 VALUES [('2024-11-22 00:00:00'), ('2024-11-23 00:00:00')),
PARTITION pt_20241123 VALUES [('2024-11-23 00:00:00'), ('2024-11-24 00:00:00')),
PARTITION pt_20241124 VALUES [('2024-11-24 00:00:00'), ('2024-11-25 00:00:00')),
PARTITION pt_20241125 VALUES [('2024-11-25 00:00:00'), ('2024-11-26 00:00:00')),
PARTITION pt_20241126 VALUES [('2024-11-26 00:00:00'), ('2024-11-27 00:00:00')),
PARTITION pt_20241127 VALUES [('2024-11-27 00:00:00'), ('2024-11-28 00:00:00')),
PARTITION pt_20241128 VALUES [('2024-11-28 00:00:00'), ('2024-11-29 00:00:00')),
PARTITION pt_20241129 VALUES [('2024-11-29 00:00:00'), ('2024-11-30 00:00:00')),
PARTITION pt_20241130 VALUES [('2024-11-30 00:00:00'), ('2024-12-01 00:00:00')),
PARTITION pt_20241201 VALUES [('2024-12-01 00:00:00'), ('2024-12-02 00:00:00')),
PARTITION pt_20241202 VALUES [('2024-12-02 00:00:00'), ('2024-12-03 00:00:00')),
PARTITION pt_20241203 VALUES [('2024-12-03 00:00:00'), ('2024-12-04 00:00:00')),
PARTITION pt_20241204 VALUES [('2024-12-04 00:00:00'), ('2024-12-05 00:00:00')),
PARTITION pt_20241205 VALUES [('2024-12-05 00:00:00'), ('2024-12-06 00:00:00')),
PARTITION pt_20241206 VALUES [('2024-12-06 00:00:00'), ('2024-12-07 00:00:00')),
PARTITION pt_20241207 VALUES [('2024-12-07 00:00:00'), ('2024-12-08 00:00:00')),
PARTITION pt_20241208 VALUES [('2024-12-08 00:00:00'), ('2024-12-09 00:00:00')),
PARTITION pt_20241209 VALUES [('2024-12-09 00:00:00'), ('2024-12-10 00:00:00')),
PARTITION pt_20241210 VALUES [('2024-12-10 00:00:00'), ('2024-12-11 00:00:00')),
PARTITION pt_20241211 VALUES [('2024-12-11 00:00:00'), ('2024-12-12 00:00:00')),
PARTITION pt_20241212 VALUES [('2024-12-12 00:00:00'), ('2024-12-13 00:00:00')),
PARTITION pt_20241213 VALUES [('2024-12-13 00:00:00'), ('2024-12-14 00:00:00')),
PARTITION pt_20241214 VALUES [('2024-12-14 00:00:00'), ('2024-12-15 00:00:00')),
PARTITION pt_20241215 VALUES [('2024-12-15 00:00:00'), ('2024-12-16 00:00:00')),
PARTITION pt_20241216 VALUES [('2024-12-16 00:00:00'), ('2024-12-17 00:00:00')),
PARTITION pt_20241217 VALUES [('2024-12-17 00:00:00'), ('2024-12-18 00:00:00')),
PARTITION pt_20241218 VALUES [('2024-12-18 00:00:00'), ('2024-12-19 00:00:00')),
PARTITION pt_20241219 VALUES [('2024-12-19 00:00:00'), ('2024-12-20 00:00:00')),
PARTITION pt_20241220 VALUES [('2024-12-20 00:00:00'), ('2024-12-21 00:00:00')),
PARTITION pt_20241221 VALUES [('2024-12-21 00:00:00'), ('2024-12-22 00:00:00')),
PARTITION pt_20241222 VALUES [('2024-12-22 00:00:00'), ('2024-12-23 00:00:00')),
PARTITION pt_20241223 VALUES [('2024-12-23 00:00:00'), ('2024-12-24 00:00:00')),
PARTITION pt_20241224 VALUES [('2024-12-24 00:00:00'), ('2024-12-25 00:00:00')),
PARTITION pt_20241225 VALUES [('2024-12-25 00:00:00'), ('2024-12-26 00:00:00')),
PARTITION pt_20241226 VALUES [('2024-12-26 00:00:00'), ('2024-12-27 00:00:00')),
PARTITION pt_20241227 VALUES [('2024-12-27 00:00:00'), ('2024-12-28 00:00:00')),
PARTITION pt_20241228 VALUES [('2024-12-28 00:00:00'), ('2024-12-29 00:00:00')),
PARTITION pt_20241229 VALUES [('2024-12-29 00:00:00'), ('2024-12-30 00:00:00')),
PARTITION pt_20241230 VALUES [('2024-12-30 00:00:00'), ('2024-12-31 00:00:00')),
PARTITION pt_20241231 VALUES [('2024-12-31 00:00:00'), ('2025-01-01 00:00:00')),
PARTITION pt_20250101 VALUES [('2025-01-01 00:00:00'), ('2025-01-02 00:00:00')),
PARTITION pt_20250102 VALUES [('2025-01-02 00:00:00'), ('2025-01-03 00:00:00')),
PARTITION pt_20250103 VALUES [('2025-01-03 00:00:00'), ('2025-01-04 00:00:00')),
PARTITION pt_20250104 VALUES [('2025-01-04 00:00:00'), ('2025-01-05 00:00:00')),
PARTITION pt_20250105 VALUES [('2025-01-05 00:00:00'), ('2025-01-06 00:00:00')),
PARTITION pt_20250106 VALUES [('2025-01-06 00:00:00'), ('2025-01-07 00:00:00')),
PARTITION pt_20250107 VALUES [('2025-01-07 00:00:00'), ('2025-01-08 00:00:00')),
PARTITION pt_20250108 VALUES [('2025-01-08 00:00:00'), ('2025-01-09 00:00:00')),
PARTITION pt_20250109 VALUES [('2025-01-09 00:00:00'), ('2025-01-10 00:00:00')),
PARTITION pt_20250110 VALUES [('2025-01-10 00:00:00'), ('2025-01-11 00:00:00')),
PARTITION pt_20250111 VALUES [('2025-01-11 00:00:00'), ('2025-01-12 00:00:00')),
PARTITION pt_20250112 VALUES [('2025-01-12 00:00:00'), ('2025-01-13 00:00:00')),
PARTITION pt_20250113 VALUES [('2025-01-13 00:00:00'), ('2025-01-14 00:00:00')),
PARTITION pt_20250114 VALUES [('2025-01-14 00:00:00'), ('2025-01-15 00:00:00')),
PARTITION pt_20250115 VALUES [('2025-01-15 00:00:00'), ('2025-01-16 00:00:00')),
PARTITION pt_20250116 VALUES [('2025-01-16 00:00:00'), ('2025-01-17 00:00:00')),
PARTITION pt_20250117 VALUES [('2025-01-17 00:00:00'), ('2025-01-18 00:00:00')),
PARTITION pt_20250118 VALUES [('2025-01-18 00:00:00'), ('2025-01-19 00:00:00')),
PARTITION pt_20250119 VALUES [('2025-01-19 00:00:00'), ('2025-01-20 00:00:00')),
PARTITION pt_20250120 VALUES [('2025-01-20 00:00:00'), ('2025-01-21 00:00:00')),
PARTITION pt_20250121 VALUES [('2025-01-21 00:00:00'), ('2025-01-22 00:00:00')),
PARTITION pt_20250122 VALUES [('2025-01-22 00:00:00'), ('2025-01-23 00:00:00')),
PARTITION pt_20250123 VALUES [('2025-01-23 00:00:00'), ('2025-01-24 00:00:00')),
PARTITION pt_20250124 VALUES [('2025-01-24 00:00:00'), ('2025-01-25 00:00:00')),
PARTITION pt_20250125 VALUES [('2025-01-25 00:00:00'), ('2025-01-26 00:00:00')),
PARTITION pt_20250126 VALUES [('2025-01-26 00:00:00'), ('2025-01-27 00:00:00')),
PARTITION pt_20250127 VALUES [('2025-01-27 00:00:00'), ('2025-01-28 00:00:00')),
PARTITION pt_20250128 VALUES [('2025-01-28 00:00:00'), ('2025-01-29 00:00:00')),
PARTITION pt_20250129 VALUES [('2025-01-29 00:00:00'), ('2025-01-30 00:00:00')),
PARTITION pt_20250130 VALUES [('2025-01-30 00:00:00'), ('2025-01-31 00:00:00')),
PARTITION pt_20250131 VALUES [('2025-01-31 00:00:00'), ('2025-02-01 00:00:00')),
PARTITION pt_20250201 VALUES [('2025-02-01 00:00:00'), ('2025-02-02 00:00:00')),
PARTITION pt_20250202 VALUES [('2025-02-02 00:00:00'), ('2025-02-03 00:00:00')),
PARTITION pt_20250203 VALUES [('2025-02-03 00:00:00'), ('2025-02-04 00:00:00')),
PARTITION pt_20250204 VALUES [('2025-02-04 00:00:00'), ('2025-02-05 00:00:00')),
PARTITION pt_20250205 VALUES [('2025-02-05 00:00:00'), ('2025-02-06 00:00:00')),
PARTITION pt_20250206 VALUES [('2025-02-06 00:00:00'), ('2025-02-07 00:00:00')),
PARTITION pt_20250207 VALUES [('2025-02-07 00:00:00'), ('2025-02-08 00:00:00')),
PARTITION pt_20250208 VALUES [('2025-02-08 00:00:00'), ('2025-02-09 00:00:00')),
PARTITION pt_20250209 VALUES [('2025-02-09 00:00:00'), ('2025-02-10 00:00:00')),
PARTITION pt_20250210 VALUES [('2025-02-10 00:00:00'), ('2025-02-11 00:00:00')),
PARTITION pt_20250211 VALUES [('2025-02-11 00:00:00'), ('2025-02-12 00:00:00')),
PARTITION pt_20250212 VALUES [('2025-02-12 00:00:00'), ('2025-02-13 00:00:00')),
PARTITION pt_20250213 VALUES [('2025-02-13 00:00:00'), ('2025-02-14 00:00:00')),
PARTITION pt_20250214 VALUES [('2025-02-14 00:00:00'), ('2025-02-15 00:00:00')),
PARTITION pt_20250215 VALUES [('2025-02-15 00:00:00'), ('2025-02-16 00:00:00')),
PARTITION pt_20250216 VALUES [('2025-02-16 00:00:00'), ('2025-02-17 00:00:00')),
PARTITION pt_20250217 VALUES [('2025-02-17 00:00:00'), ('2025-02-18 00:00:00')),
PARTITION pt_20250218 VALUES [('2025-02-18 00:00:00'), ('2025-02-19 00:00:00')),
PARTITION pt_20250219 VALUES [('2025-02-19 00:00:00'), ('2025-02-20 00:00:00')),
PARTITION pt_20250220 VALUES [('2025-02-20 00:00:00'), ('2025-02-21 00:00:00')),
PARTITION pt_20250221 VALUES [('2025-02-21 00:00:00'), ('2025-02-22 00:00:00')),
PARTITION pt_20250222 VALUES [('2025-02-22 00:00:00'), ('2025-02-23 00:00:00')),
PARTITION pt_20250223 VALUES [('2025-02-23 00:00:00'), ('2025-02-24 00:00:00')),
PARTITION pt_20250224 VALUES [('2025-02-24 00:00:00'), ('2025-02-25 00:00:00')),
PARTITION pt_20250225 VALUES [('2025-02-25 00:00:00'), ('2025-02-26 00:00:00')),
PARTITION pt_20250226 VALUES [('2025-02-26 00:00:00'), ('2025-02-27 00:00:00')),
PARTITION pt_20250227 VALUES [('2025-02-27 00:00:00'), ('2025-02-28 00:00:00')),
PARTITION pt_20250228 VALUES [('2025-02-28 00:00:00'), ('2025-03-01 00:00:00')),
PARTITION pt_20250301 VALUES [('2025-03-01 00:00:00'), ('2025-03-02 00:00:00')),
PARTITION pt_20250302 VALUES [('2025-03-02 00:00:00'), ('2025-03-03 00:00:00')),
PARTITION pt_20250303 VALUES [('2025-03-03 00:00:00'), ('2025-03-04 00:00:00')),
PARTITION pt_20250304 VALUES [('2025-03-04 00:00:00'), ('2025-03-05 00:00:00')),
PARTITION pt_20250305 VALUES [('2025-03-05 00:00:00'), ('2025-03-06 00:00:00')),
PARTITION pt_20250306 VALUES [('2025-03-06 00:00:00'), ('2025-03-07 00:00:00')),
PARTITION pt_20250307 VALUES [('2025-03-07 00:00:00'), ('2025-03-08 00:00:00')),
PARTITION pt_20250308 VALUES [('2025-03-08 00:00:00'), ('2025-03-09 00:00:00')),
PARTITION pt_20250309 VALUES [('2025-03-09 00:00:00'), ('2025-03-10 00:00:00')),
PARTITION pt_20250310 VALUES [('2025-03-10 00:00:00'), ('2025-03-11 00:00:00')),
PARTITION pt_20250311 VALUES [('2025-03-11 00:00:00'), ('2025-03-12 00:00:00')),
PARTITION pt_20250312 VALUES [('2025-03-12 00:00:00'), ('2025-03-13 00:00:00')),
PARTITION pt_20250313 VALUES [('2025-03-13 00:00:00'), ('2025-03-14 00:00:00')),
PARTITION pt_20250314 VALUES [('2025-03-14 00:00:00'), ('2025-03-15 00:00:00')),
PARTITION pt_20250315 VALUES [('2025-03-15 00:00:00'), ('2025-03-16 00:00:00')),
PARTITION pt_20250316 VALUES [('2025-03-16 00:00:00'), ('2025-03-17 00:00:00')),
PARTITION pt_20250317 VALUES [('2025-03-17 00:00:00'), ('2025-03-18 00:00:00')),
PARTITION pt_20250318 VALUES [('2025-03-18 00:00:00'), ('2025-03-19 00:00:00')),
PARTITION pt_20250319 VALUES [('2025-03-19 00:00:00'), ('2025-03-20 00:00:00')),
PARTITION pt_20250320 VALUES [('2025-03-20 00:00:00'), ('2025-03-21 00:00:00')),
PARTITION pt_20250321 VALUES [('2025-03-21 00:00:00'), ('2025-03-22 00:00:00')),
PARTITION pt_20250322 VALUES [('2025-03-22 00:00:00'), ('2025-03-23 00:00:00')),
PARTITION pt_20250323 VALUES [('2025-03-23 00:00:00'), ('2025-03-24 00:00:00')),
PARTITION pt_20250324 VALUES [('2025-03-24 00:00:00'), ('2025-03-25 00:00:00')),
PARTITION pt_20250325 VALUES [('2025-03-25 00:00:00'), ('2025-03-26 00:00:00')),
PARTITION pt_20250326 VALUES [('2025-03-26 00:00:00'), ('2025-03-27 00:00:00')),
PARTITION pt_20250327 VALUES [('2025-03-27 00:00:00'), ('2025-03-28 00:00:00')),
PARTITION pt_20250328 VALUES [('2025-03-28 00:00:00'), ('2025-03-29 00:00:00')),
PARTITION pt_20250329 VALUES [('2025-03-29 00:00:00'), ('2025-03-30 00:00:00')),
PARTITION pt_20250330 VALUES [('2025-03-30 00:00:00'), ('2025-03-31 00:00:00')),
PARTITION pt_20250331 VALUES [('2025-03-31 00:00:00'), ('2025-04-01 00:00:00')),
PARTITION pt_20250401 VALUES [('2025-04-01 00:00:00'), ('2025-04-02 00:00:00')),
PARTITION pt_20250402 VALUES [('2025-04-02 00:00:00'), ('2025-04-03 00:00:00')),
PARTITION pt_20250403 VALUES [('2025-04-03 00:00:00'), ('2025-04-04 00:00:00')),
PARTITION pt_20250404 VALUES [('2025-04-04 00:00:00'), ('2025-04-05 00:00:00')),
PARTITION pt_20250405 VALUES [('2025-04-05 00:00:00'), ('2025-04-06 00:00:00')),
PARTITION pt_20250406 VALUES [('2025-04-06 00:00:00'), ('2025-04-07 00:00:00')),
PARTITION pt_20250407 VALUES [('2025-04-07 00:00:00'), ('2025-04-08 00:00:00')),
PARTITION pt_20250408 VALUES [('2025-04-08 00:00:00'), ('2025-04-09 00:00:00')),
PARTITION pt_20250409 VALUES [('2025-04-09 00:00:00'), ('2025-04-10 00:00:00')),
PARTITION pt_20250410 VALUES [('2025-04-10 00:00:00'), ('2025-04-11 00:00:00')),
PARTITION pt_20250411 VALUES [('2025-04-11 00:00:00'), ('2025-04-12 00:00:00')),
PARTITION pt_20250412 VALUES [('2025-04-12 00:00:00'), ('2025-04-13 00:00:00')),
PARTITION pt_20250413 VALUES [('2025-04-13 00:00:00'), ('2025-04-14 00:00:00')),
PARTITION pt_20250414 VALUES [('2025-04-14 00:00:00'), ('2025-04-15 00:00:00')),
PARTITION pt_20250415 VALUES [('2025-04-15 00:00:00'), ('2025-04-16 00:00:00')),
PARTITION pt_20250416 VALUES [('2025-04-16 00:00:00'), ('2025-04-17 00:00:00')),
PARTITION pt_20250417 VALUES [('2025-04-17 00:00:00'), ('2025-04-18 00:00:00')),
PARTITION pt_20250418 VALUES [('2025-04-18 00:00:00'), ('2025-04-19 00:00:00')),
PARTITION pt_20250419 VALUES [('2025-04-19 00:00:00'), ('2025-04-20 00:00:00')),
PARTITION pt_20250420 VALUES [('2025-04-20 00:00:00'), ('2025-04-21 00:00:00')),
PARTITION pt_20250421 VALUES [('2025-04-21 00:00:00'), ('2025-04-22 00:00:00')),
PARTITION pt_20250422 VALUES [('2025-04-22 00:00:00'), ('2025-04-23 00:00:00')),
PARTITION pt_20250423 VALUES [('2025-04-23 00:00:00'), ('2025-04-24 00:00:00')),
PARTITION pt_20250424 VALUES [('2025-04-24 00:00:00'), ('2025-04-25 00:00:00')),
PARTITION pt_20250425 VALUES [('2025-04-25 00:00:00'), ('2025-04-26 00:00:00')),
PARTITION pt_20250426 VALUES [('2025-04-26 00:00:00'), ('2025-04-27 00:00:00')),
PARTITION pt_20250427 VALUES [('2025-04-27 00:00:00'), ('2025-04-28 00:00:00')),
PARTITION pt_20250428 VALUES [('2025-04-28 00:00:00'), ('2025-04-29 00:00:00')),
PARTITION pt_20250429 VALUES [('2025-04-29 00:00:00'), ('2025-04-30 00:00:00')),
PARTITION pt_20250430 VALUES [('2025-04-30 00:00:00'), ('2025-05-01 00:00:00')),
PARTITION pt_20250501 VALUES [('2025-05-01 00:00:00'), ('2025-05-02 00:00:00')),
PARTITION pt_20250502 VALUES [('2025-05-02 00:00:00'), ('2025-05-03 00:00:00')),
PARTITION pt_20250503 VALUES [('2025-05-03 00:00:00'), ('2025-05-04 00:00:00')),
PARTITION pt_20250504 VALUES [('2025-05-04 00:00:00'), ('2025-05-05 00:00:00')),
PARTITION pt_20250505 VALUES [('2025-05-05 00:00:00'), ('2025-05-06 00:00:00')),
PARTITION pt_20250506 VALUES [('2025-05-06 00:00:00'), ('2025-05-07 00:00:00')),
PARTITION pt_20250507 VALUES [('2025-05-07 00:00:00'), ('2025-05-08 00:00:00')),
PARTITION pt_20250508 VALUES [('2025-05-08 00:00:00'), ('2025-05-09 00:00:00')),
PARTITION pt_20250509 VALUES [('2025-05-09 00:00:00'), ('2025-05-10 00:00:00')),
PARTITION pt_20250510 VALUES [('2025-05-10 00:00:00'), ('2025-05-11 00:00:00')),
PARTITION pt_20250511 VALUES [('2025-05-11 00:00:00'), ('2025-05-12 00:00:00')),
PARTITION pt_20250512 VALUES [('2025-05-12 00:00:00'), ('2025-05-13 00:00:00')),
PARTITION pt_20250513 VALUES [('2025-05-13 00:00:00'), ('2025-05-14 00:00:00')),
PARTITION pt_20250514 VALUES [('2025-05-14 00:00:00'), ('2025-05-15 00:00:00')),
PARTITION pt_20250515 VALUES [('2025-05-15 00:00:00'), ('2025-05-16 00:00:00')),
PARTITION pt_20250516 VALUES [('2025-05-16 00:00:00'), ('2025-05-17 00:00:00')),
PARTITION pt_20250517 VALUES [('2025-05-17 00:00:00'), ('2025-05-18 00:00:00')),
PARTITION pt_20250518 VALUES [('2025-05-18 00:00:00'), ('2025-05-19 00:00:00')),
PARTITION pt_20250519 VALUES [('2025-05-19 00:00:00'), ('2025-05-20 00:00:00')),
PARTITION pt_20250520 VALUES [('2025-05-20 00:00:00'), ('2025-05-21 00:00:00')),
PARTITION pt_20250521 VALUES [('2025-05-21 00:00:00'), ('2025-05-22 00:00:00')),
PARTITION pt_20250522 VALUES [('2025-05-22 00:00:00'), ('2025-05-23 00:00:00')),
PARTITION pt_20250523 VALUES [('2025-05-23 00:00:00'), ('2025-05-24 00:00:00')),
PARTITION pt_20250524 VALUES [('2025-05-24 00:00:00'), ('2025-05-25 00:00:00')),
PARTITION pt_20250525 VALUES [('2025-05-25 00:00:00'), ('2025-05-26 00:00:00')),
PARTITION pt_20250526 VALUES [('2025-05-26 00:00:00'), ('2025-05-27 00:00:00')),
PARTITION pt_20250527 VALUES [('2025-05-27 00:00:00'), ('2025-05-28 00:00:00')),
PARTITION pt_20250528 VALUES [('2025-05-28 00:00:00'), ('2025-05-29 00:00:00')),
PARTITION pt_20250529 VALUES [('2025-05-29 00:00:00'), ('2025-05-30 00:00:00')),
PARTITION pt_20250530 VALUES [('2025-05-30 00:00:00'), ('2025-05-31 00:00:00')),
PARTITION pt_20250531 VALUES [('2025-05-31 00:00:00'), ('2025-06-01 00:00:00')),
PARTITION pt_20250601 VALUES [('2025-06-01 00:00:00'), ('2025-06-02 00:00:00')),
PARTITION pt_20250602 VALUES [('2025-06-02 00:00:00'), ('2025-06-03 00:00:00')),
PARTITION pt_20250603 VALUES [('2025-06-03 00:00:00'), ('2025-06-04 00:00:00')),
PARTITION pt_20250604 VALUES [('2025-06-04 00:00:00'), ('2025-06-05 00:00:00')),
PARTITION pt_20250605 VALUES [('2025-06-05 00:00:00'), ('2025-06-06 00:00:00')),
PARTITION pt_20250606 VALUES [('2025-06-06 00:00:00'), ('2025-06-07 00:00:00')),
PARTITION pt_20250607 VALUES [('2025-06-07 00:00:00'), ('2025-06-08 00:00:00')),
PARTITION pt_20250608 VALUES [('2025-06-08 00:00:00'), ('2025-06-09 00:00:00')),
PARTITION pt_20250609 VALUES [('2025-06-09 00:00:00'), ('2025-06-10 00:00:00')),
PARTITION pt_20250610 VALUES [('2025-06-10 00:00:00'), ('2025-06-11 00:00:00')),
PARTITION pt_20250611 VALUES [('2025-06-11 00:00:00'), ('2025-06-12 00:00:00')),
PARTITION pt_20250612 VALUES [('2025-06-12 00:00:00'), ('2025-06-13 00:00:00')),
PARTITION pt_20250613 VALUES [('2025-06-13 00:00:00'), ('2025-06-14 00:00:00')),
PARTITION pt_20250614 VALUES [('2025-06-14 00:00:00'), ('2025-06-15 00:00:00')),
PARTITION pt_20250615 VALUES [('2025-06-15 00:00:00'), ('2025-06-16 00:00:00')),
PARTITION pt_20250616 VALUES [('2025-06-16 00:00:00'), ('2025-06-17 00:00:00')),
PARTITION pt_20250617 VALUES [('2025-06-17 00:00:00'), ('2025-06-18 00:00:00')),
PARTITION pt_20250618 VALUES [('2025-06-18 00:00:00'), ('2025-06-19 00:00:00')),
PARTITION pt_20250619 VALUES [('2025-06-19 00:00:00'), ('2025-06-20 00:00:00')),
PARTITION pt_20250620 VALUES [('2025-06-20 00:00:00'), ('2025-06-21 00:00:00')),
PARTITION pt_20250621 VALUES [('2025-06-21 00:00:00'), ('2025-06-22 00:00:00')),
PARTITION pt_20250622 VALUES [('2025-06-22 00:00:00'), ('2025-06-23 00:00:00')),
PARTITION pt_20250623 VALUES [('2025-06-23 00:00:00'), ('2025-06-24 00:00:00')),
PARTITION pt_20250624 VALUES [('2025-06-24 00:00:00'), ('2025-06-25 00:00:00')),
PARTITION pt_20250625 VALUES [('2025-06-25 00:00:00'), ('2025-06-26 00:00:00')),
PARTITION pt_20250626 VALUES [('2025-06-26 00:00:00'), ('2025-06-27 00:00:00')),
PARTITION pt_20250627 VALUES [('2025-06-27 00:00:00'), ('2025-06-28 00:00:00')),
PARTITION pt_20250628 VALUES [('2025-06-28 00:00:00'), ('2025-06-29 00:00:00')),
PARTITION pt_20250629 VALUES [('2025-06-29 00:00:00'), ('2025-06-30 00:00:00')),
PARTITION pt_20250630 VALUES [('2025-06-30 00:00:00'), ('2025-07-01 00:00:00')),
PARTITION pt_20250701 VALUES [('2025-07-01 00:00:00'), ('2025-07-02 00:00:00')),
PARTITION pt_20250702 VALUES [('2025-07-02 00:00:00'), ('2025-07-03 00:00:00')),
PARTITION pt_20250703 VALUES [('2025-07-03 00:00:00'), ('2025-07-04 00:00:00')),
PARTITION pt_20250704 VALUES [('2025-07-04 00:00:00'), ('2025-07-05 00:00:00')),
PARTITION pt_20250705 VALUES [('2025-07-05 00:00:00'), ('2025-07-06 00:00:00')),
PARTITION pt_20250706 VALUES [('2025-07-06 00:00:00'), ('2025-07-07 00:00:00')),
PARTITION pt_20250707 VALUES [('2025-07-07 00:00:00'), ('2025-07-08 00:00:00')),
PARTITION pt_20250708 VALUES [('2025-07-08 00:00:00'), ('2025-07-09 00:00:00')),
PARTITION pt_20250709 VALUES [('2025-07-09 00:00:00'), ('2025-07-10 00:00:00')),
PARTITION pt_20250710 VALUES [('2025-07-10 00:00:00'), ('2025-07-11 00:00:00')),
PARTITION pt_20250711 VALUES [('2025-07-11 00:00:00'), ('2025-07-12 00:00:00')),
PARTITION pt_20250712 VALUES [('2025-07-12 00:00:00'), ('2025-07-13 00:00:00')),
PARTITION pt_20250713 VALUES [('2025-07-13 00:00:00'), ('2025-07-14 00:00:00')),
PARTITION pt_20250714 VALUES [('2025-07-14 00:00:00'), ('2025-07-15 00:00:00')),
PARTITION pt_20250715 VALUES [('2025-07-15 00:00:00'), ('2025-07-16 00:00:00')),
PARTITION pt_20250716 VALUES [('2025-07-16 00:00:00'), ('2025-07-17 00:00:00')),
PARTITION pt_20250717 VALUES [('2025-07-17 00:00:00'), ('2025-07-18 00:00:00')),
PARTITION pt_20250718 VALUES [('2025-07-18 00:00:00'), ('2025-07-19 00:00:00')),
PARTITION pt_20250719 VALUES [('2025-07-19 00:00:00'), ('2025-07-20 00:00:00')),
PARTITION pt_20250720 VALUES [('2025-07-20 00:00:00'), ('2025-07-21 00:00:00')),
PARTITION pt_20250721 VALUES [('2025-07-21 00:00:00'), ('2025-07-22 00:00:00')),
PARTITION pt_20250722 VALUES [('2025-07-22 00:00:00'), ('2025-07-23 00:00:00')),
PARTITION pt_20250723 VALUES [('2025-07-23 00:00:00'), ('2025-07-24 00:00:00')),
PARTITION pt_20250724 VALUES [('2025-07-24 00:00:00'), ('2025-07-25 00:00:00')),
PARTITION pt_20250725 VALUES [('2025-07-25 00:00:00'), ('2025-07-26 00:00:00')),
PARTITION pt_20250726 VALUES [('2025-07-26 00:00:00'), ('2025-07-27 00:00:00')),
PARTITION pt_20250727 VALUES [('2025-07-27 00:00:00'), ('2025-07-28 00:00:00')),
PARTITION pt_20250728 VALUES [('2025-07-28 00:00:00'), ('2025-07-29 00:00:00')),
PARTITION pt_20250729 VALUES [('2025-07-29 00:00:00'), ('2025-07-30 00:00:00')),
PARTITION pt_20250730 VALUES [('2025-07-30 00:00:00'), ('2025-07-31 00:00:00')),
PARTITION pt_20250731 VALUES [('2025-07-31 00:00:00'), ('2025-08-01 00:00:00')),
PARTITION pt_20250801 VALUES [('2025-08-01 00:00:00'), ('2025-08-02 00:00:00')),
PARTITION pt_20250802 VALUES [('2025-08-02 00:00:00'), ('2025-08-03 00:00:00')),
PARTITION pt_20250803 VALUES [('2025-08-03 00:00:00'), ('2025-08-04 00:00:00')),
PARTITION pt_20250804 VALUES [('2025-08-04 00:00:00'), ('2025-08-05 00:00:00')),
PARTITION pt_20250805 VALUES [('2025-08-05 00:00:00'), ('2025-08-06 00:00:00')),
PARTITION pt_20250806 VALUES [('2025-08-06 00:00:00'), ('2025-08-07 00:00:00')),
PARTITION pt_20250807 VALUES [('2025-08-07 00:00:00'), ('2025-08-08 00:00:00')),
PARTITION pt_20250808 VALUES [('2025-08-08 00:00:00'), ('2025-08-09 00:00:00')),
PARTITION pt_20250809 VALUES [('2025-08-09 00:00:00'), ('2025-08-10 00:00:00')),
PARTITION pt_20250810 VALUES [('2025-08-10 00:00:00'), ('2025-08-11 00:00:00')),
PARTITION pt_20250811 VALUES [('2025-08-11 00:00:00'), ('2025-08-12 00:00:00')),
PARTITION pt_20250812 VALUES [('2025-08-12 00:00:00'), ('2025-08-13 00:00:00')),
PARTITION pt_20250813 VALUES [('2025-08-13 00:00:00'), ('2025-08-14 00:00:00')),
PARTITION pt_20250814 VALUES [('2025-08-14 00:00:00'), ('2025-08-15 00:00:00')),
PARTITION pt_20250815 VALUES [('2025-08-15 00:00:00'), ('2025-08-16 00:00:00')),
PARTITION pt_20250816 VALUES [('2025-08-16 00:00:00'), ('2025-08-17 00:00:00')),
PARTITION pt_20250817 VALUES [('2025-08-17 00:00:00'), ('2025-08-18 00:00:00')),
PARTITION pt_20250818 VALUES [('2025-08-18 00:00:00'), ('2025-08-19 00:00:00')),
PARTITION pt_20250819 VALUES [('2025-08-19 00:00:00'), ('2025-08-20 00:00:00')),
PARTITION pt_20250820 VALUES [('2025-08-20 00:00:00'), ('2025-08-21 00:00:00')),
PARTITION pt_20250821 VALUES [('2025-08-21 00:00:00'), ('2025-08-22 00:00:00')),
PARTITION pt_20250822 VALUES [('2025-08-22 00:00:00'), ('2025-08-23 00:00:00')),
PARTITION pt_20250823 VALUES [('2025-08-23 00:00:00'), ('2025-08-24 00:00:00')),
PARTITION pt_20250824 VALUES [('2025-08-24 00:00:00'), ('2025-08-25 00:00:00')),
PARTITION pt_20250825 VALUES [('2025-08-25 00:00:00'), ('2025-08-26 00:00:00')),
PARTITION pt_20250826 VALUES [('2025-08-26 00:00:00'), ('2025-08-27 00:00:00')),
PARTITION pt_20250827 VALUES [('2025-08-27 00:00:00'), ('2025-08-28 00:00:00')),
PARTITION pt_20250828 VALUES [('2025-08-28 00:00:00'), ('2025-08-29 00:00:00')),
PARTITION pt_20250829 VALUES [('2025-08-29 00:00:00'), ('2025-08-30 00:00:00')),
PARTITION pt_20250830 VALUES [('2025-08-30 00:00:00'), ('2025-08-31 00:00:00')),
PARTITION pt_20250831 VALUES [('2025-08-31 00:00:00'), ('2025-09-01 00:00:00')),
PARTITION pt_20250901 VALUES [('2025-09-01 00:00:00'), ('2025-09-02 00:00:00')),
PARTITION pt_20250902 VALUES [('2025-09-02 00:00:00'), ('2025-09-03 00:00:00')),
PARTITION pt_20250903 VALUES [('2025-09-03 00:00:00'), ('2025-09-04 00:00:00')),
PARTITION pt_20250904 VALUES [('2025-09-04 00:00:00'), ('2025-09-05 00:00:00')),
PARTITION pt_20250905 VALUES [('2025-09-05 00:00:00'), ('2025-09-06 00:00:00')),
PARTITION pt_20250906 VALUES [('2025-09-06 00:00:00'), ('2025-09-07 00:00:00')),
PARTITION pt_20250907 VALUES [('2025-09-07 00:00:00'), ('2025-09-08 00:00:00')),
PARTITION pt_20250908 VALUES [('2025-09-08 00:00:00'), ('2025-09-09 00:00:00')),
PARTITION pt_20250909 VALUES [('2025-09-09 00:00:00'), ('2025-09-10 00:00:00')),
PARTITION pt_20250910 VALUES [('2025-09-10 00:00:00'), ('2025-09-11 00:00:00')),
PARTITION pt_20250911 VALUES [('2025-09-11 00:00:00'), ('2025-09-12 00:00:00')),
PARTITION pt_20250912 VALUES [('2025-09-12 00:00:00'), ('2025-09-13 00:00:00')),
PARTITION pt_20250913 VALUES [('2025-09-13 00:00:00'), ('2025-09-14 00:00:00')),
PARTITION pt_20250914 VALUES [('2025-09-14 00:00:00'), ('2025-09-15 00:00:00')),
PARTITION pt_20250915 VALUES [('2025-09-15 00:00:00'), ('2025-09-16 00:00:00')),
PARTITION pt_20250916 VALUES [('2025-09-16 00:00:00'), ('2025-09-17 00:00:00')),
PARTITION pt_20250917 VALUES [('2025-09-17 00:00:00'), ('2025-09-18 00:00:00')),
PARTITION pt_20250918 VALUES [('2025-09-18 00:00:00'), ('2025-09-19 00:00:00')),
PARTITION pt_20250919 VALUES [('2025-09-19 00:00:00'), ('2025-09-20 00:00:00')),
PARTITION pt_20250920 VALUES [('2025-09-20 00:00:00'), ('2025-09-21 00:00:00')),
PARTITION pt_20250921 VALUES [('2025-09-21 00:00:00'), ('2025-09-22 00:00:00')),
PARTITION pt_20250922 VALUES [('2025-09-22 00:00:00'), ('2025-09-23 00:00:00')),
PARTITION pt_20250923 VALUES [('2025-09-23 00:00:00'), ('2025-09-24 00:00:00')),
PARTITION pt_20250924 VALUES [('2025-09-24 00:00:00'), ('2025-09-25 00:00:00')),
PARTITION pt_20250925 VALUES [('2025-09-25 00:00:00'), ('2025-09-26 00:00:00')),
PARTITION pt_20250926 VALUES [('2025-09-26 00:00:00'), ('2025-09-27 00:00:00')),
PARTITION pt_20250927 VALUES [('2025-09-27 00:00:00'), ('2025-09-28 00:00:00')),
PARTITION pt_20250928 VALUES [('2025-09-28 00:00:00'), ('2025-09-29 00:00:00')),
PARTITION pt_20250929 VALUES [('2025-09-29 00:00:00'), ('2025-09-30 00:00:00')),
PARTITION pt_20250930 VALUES [('2025-09-30 00:00:00'), ('2025-10-01 00:00:00')),
PARTITION pt_20251001 VALUES [('2025-10-01 00:00:00'), ('2025-10-02 00:00:00')),
PARTITION pt_20251002 VALUES [('2025-10-02 00:00:00'), ('2025-10-03 00:00:00')),
PARTITION pt_20251003 VALUES [('2025-10-03 00:00:00'), ('2025-10-04 00:00:00')),
PARTITION pt_20251004 VALUES [('2025-10-04 00:00:00'), ('2025-10-05 00:00:00')),
PARTITION pt_20251005 VALUES [('2025-10-05 00:00:00'), ('2025-10-06 00:00:00')),
PARTITION pt_20251006 VALUES [('2025-10-06 00:00:00'), ('2025-10-07 00:00:00')),
PARTITION pt_20251007 VALUES [('2025-10-07 00:00:00'), ('2025-10-08 00:00:00')),
PARTITION pt_20251008 VALUES [('2025-10-08 00:00:00'), ('2025-10-09 00:00:00')),
PARTITION pt_20251009 VALUES [('2025-10-09 00:00:00'), ('2025-10-10 00:00:00')),
PARTITION pt_20251010 VALUES [('2025-10-10 00:00:00'), ('2025-10-11 00:00:00')),
PARTITION pt_20251011 VALUES [('2025-10-11 00:00:00'), ('2025-10-12 00:00:00')),
PARTITION pt_20251012 VALUES [('2025-10-12 00:00:00'), ('2025-10-13 00:00:00')),
PARTITION pt_20251013 VALUES [('2025-10-13 00:00:00'), ('2025-10-14 00:00:00')),
PARTITION pt_20251014 VALUES [('2025-10-14 00:00:00'), ('2025-10-15 00:00:00')),
PARTITION pt_20251015 VALUES [('2025-10-15 00:00:00'), ('2025-10-16 00:00:00')),
PARTITION pt_20251016 VALUES [('2025-10-16 00:00:00'), ('2025-10-17 00:00:00')),
PARTITION pt_20251017 VALUES [('2025-10-17 00:00:00'), ('2025-10-18 00:00:00')),
PARTITION pt_20251018 VALUES [('2025-10-18 00:00:00'), ('2025-10-19 00:00:00')),
PARTITION pt_20251019 VALUES [('2025-10-19 00:00:00'), ('2025-10-20 00:00:00')),
PARTITION pt_20251020 VALUES [('2025-10-20 00:00:00'), ('2025-10-21 00:00:00')),
PARTITION pt_20251021 VALUES [('2025-10-21 00:00:00'), ('2025-10-22 00:00:00')),
PARTITION pt_20251022 VALUES [('2025-10-22 00:00:00'), ('2025-10-23 00:00:00')),
PARTITION pt_20251023 VALUES [('2025-10-23 00:00:00'), ('2025-10-24 00:00:00')),
PARTITION pt_20251024 VALUES [('2025-10-24 00:00:00'), ('2025-10-25 00:00:00')),
PARTITION pt_20251025 VALUES [('2025-10-25 00:00:00'), ('2025-10-26 00:00:00')),
PARTITION pt_20251026 VALUES [('2025-10-26 00:00:00'), ('2025-10-27 00:00:00')),
PARTITION pt_20251027 VALUES [('2025-10-27 00:00:00'), ('2025-10-28 00:00:00')),
PARTITION pt_20251028 VALUES [('2025-10-28 00:00:00'), ('2025-10-29 00:00:00')),
PARTITION pt_20251029 VALUES [('2025-10-29 00:00:00'), ('2025-10-30 00:00:00')),
PARTITION pt_20251030 VALUES [('2025-10-30 00:00:00'), ('2025-10-31 00:00:00')),
PARTITION pt_20251031 VALUES [('2025-10-31 00:00:00'), ('2025-11-01 00:00:00')),
PARTITION pt_20251101 VALUES [('2025-11-01 00:00:00'), ('2025-11-02 00:00:00')),
PARTITION pt_20251102 VALUES [('2025-11-02 00:00:00'), ('2025-11-03 00:00:00')),
PARTITION pt_20251103 VALUES [('2025-11-03 00:00:00'), ('2025-11-04 00:00:00')),
PARTITION pt_20251104 VALUES [('2025-11-04 00:00:00'), ('2025-11-05 00:00:00')),
PARTITION pt_20251105 VALUES [('2025-11-05 00:00:00'), ('2025-11-06 00:00:00')),
PARTITION pt_20251106 VALUES [('2025-11-06 00:00:00'), ('2025-11-07 00:00:00')),
PARTITION pt_20251107 VALUES [('2025-11-07 00:00:00'), ('2025-11-08 00:00:00')),
PARTITION pt_20251108 VALUES [('2025-11-08 00:00:00'), ('2025-11-09 00:00:00')),
PARTITION pt_20251109 VALUES [('2025-11-09 00:00:00'), ('2025-11-10 00:00:00')),
PARTITION pt_20251110 VALUES [('2025-11-10 00:00:00'), ('2025-11-11 00:00:00')),
PARTITION pt_20251111 VALUES [('2025-11-11 00:00:00'), ('2025-11-12 00:00:00')),
PARTITION pt_20251112 VALUES [('2025-11-12 00:00:00'), ('2025-11-13 00:00:00')),
PARTITION pt_20251113 VALUES [('2025-11-13 00:00:00'), ('2025-11-14 00:00:00')),
PARTITION pt_20251114 VALUES [('2025-11-14 00:00:00'), ('2025-11-15 00:00:00')),
PARTITION pt_20251115 VALUES [('2025-11-15 00:00:00'), ('2025-11-16 00:00:00')),
PARTITION pt_20251116 VALUES [('2025-11-16 00:00:00'), ('2025-11-17 00:00:00')),
PARTITION pt_20251117 VALUES [('2025-11-17 00:00:00'), ('2025-11-18 00:00:00')),
PARTITION pt_20251118 VALUES [('2025-11-18 00:00:00'), ('2025-11-19 00:00:00')),
PARTITION pt_20251119 VALUES [('2025-11-19 00:00:00'), ('2025-11-20 00:00:00')),
PARTITION pt_20251120 VALUES [('2025-11-20 00:00:00'), ('2025-11-21 00:00:00')),
PARTITION pt_20251121 VALUES [('2025-11-21 00:00:00'), ('2025-11-22 00:00:00')),
PARTITION pt_20251122 VALUES [('2025-11-22 00:00:00'), ('2025-11-23 00:00:00')),
PARTITION pt_20251123 VALUES [('2025-11-23 00:00:00'), ('2025-11-24 00:00:00')),
PARTITION pt_20251124 VALUES [('2025-11-24 00:00:00'), ('2025-11-25 00:00:00')),
PARTITION pt_20251125 VALUES [('2025-11-25 00:00:00'), ('2025-11-26 00:00:00')),
PARTITION pt_20251126 VALUES [('2025-11-26 00:00:00'), ('2025-11-27 00:00:00')),
PARTITION pt_20251127 VALUES [('2025-11-27 00:00:00'), ('2025-11-28 00:00:00')),
PARTITION pt_20251128 VALUES [('2025-11-28 00:00:00'), ('2025-11-29 00:00:00')),
PARTITION pt_20251129 VALUES [('2025-11-29 00:00:00'), ('2025-11-30 00:00:00')),
PARTITION pt_20251130 VALUES [('2025-11-30 00:00:00'), ('2025-12-01 00:00:00')),
PARTITION pt_20251201 VALUES [('2025-12-01 00:00:00'), ('2025-12-02 00:00:00')),
PARTITION pt_20251202 VALUES [('2025-12-02 00:00:00'), ('2025-12-03 00:00:00')),
PARTITION pt_20251203 VALUES [('2025-12-03 00:00:00'), ('2025-12-04 00:00:00')),
PARTITION pt_20251204 VALUES [('2025-12-04 00:00:00'), ('2025-12-05 00:00:00')),
PARTITION pt_20251205 VALUES [('2025-12-05 00:00:00'), ('2025-12-06 00:00:00')),
PARTITION pt_20251206 VALUES [('2025-12-06 00:00:00'), ('2025-12-07 00:00:00')),
PARTITION pt_20251207 VALUES [('2025-12-07 00:00:00'), ('2025-12-08 00:00:00')),
PARTITION pt_20251208 VALUES [('2025-12-08 00:00:00'), ('2025-12-09 00:00:00')),
PARTITION pt_20251209 VALUES [('2025-12-09 00:00:00'), ('2025-12-10 00:00:00')),
PARTITION pt_20251210 VALUES [('2025-12-10 00:00:00'), ('2025-12-11 00:00:00')),
PARTITION pt_20251211 VALUES [('2025-12-11 00:00:00'), ('2025-12-12 00:00:00')),
PARTITION pt_20251212 VALUES [('2025-12-12 00:00:00'), ('2025-12-13 00:00:00')),
PARTITION pt_20251213 VALUES [('2025-12-13 00:00:00'), ('2025-12-14 00:00:00')),
PARTITION pt_20251214 VALUES [('2025-12-14 00:00:00'), ('2025-12-15 00:00:00')),
PARTITION pt_20251215 VALUES [('2025-12-15 00:00:00'), ('2025-12-16 00:00:00')),
PARTITION pt_20251216 VALUES [('2025-12-16 00:00:00'), ('2025-12-17 00:00:00')),
PARTITION pt_20251217 VALUES [('2025-12-17 00:00:00'), ('2025-12-18 00:00:00')),
PARTITION pt_20251218 VALUES [('2025-12-18 00:00:00'), ('2025-12-19 00:00:00')),
PARTITION pt_20251219 VALUES [('2025-12-19 00:00:00'), ('2025-12-20 00:00:00')),
PARTITION pt_20251220 VALUES [('2025-12-20 00:00:00'), ('2025-12-21 00:00:00')),
PARTITION pt_20251221 VALUES [('2025-12-21 00:00:00'), ('2025-12-22 00:00:00')),
PARTITION pt_20251222 VALUES [('2025-12-22 00:00:00'), ('2025-12-23 00:00:00')),
PARTITION pt_20251223 VALUES [('2025-12-23 00:00:00'), ('2025-12-24 00:00:00')),
PARTITION pt_20251224 VALUES [('2025-12-24 00:00:00'), ('2025-12-25 00:00:00')),
PARTITION pt_20251225 VALUES [('2025-12-25 00:00:00'), ('2025-12-26 00:00:00')),
PARTITION pt_20251226 VALUES [('2025-12-26 00:00:00'), ('2025-12-27 00:00:00')),
PARTITION pt_20251227 VALUES [('2025-12-27 00:00:00'), ('2025-12-28 00:00:00')),
PARTITION pt_20251228 VALUES [('2025-12-28 00:00:00'), ('2025-12-29 00:00:00')),
PARTITION pt_20251229 VALUES [('2025-12-29 00:00:00'), ('2025-12-30 00:00:00')),
PARTITION pt_20251230 VALUES [('2025-12-30 00:00:00'), ('2025-12-31 00:00:00')),
PARTITION pt_20251231 VALUES [('2025-12-31 00:00:00'), ('2026-01-01 00:00:00')),
PARTITION pt_20260101 VALUES [('2026-01-01 00:00:00'), ('2026-01-02 00:00:00')),
PARTITION pt_20260102 VALUES [('2026-01-02 00:00:00'), ('2026-01-03 00:00:00')),
PARTITION pt_20260103 VALUES [('2026-01-03 00:00:00'), ('2026-01-04 00:00:00')),
PARTITION pt_20260104 VALUES [('2026-01-04 00:00:00'), ('2026-01-05 00:00:00')),
PARTITION pt_20260105 VALUES [('2026-01-05 00:00:00'), ('2026-01-06 00:00:00')),
PARTITION pt_20260106 VALUES [('2026-01-06 00:00:00'), ('2026-01-07 00:00:00')),
PARTITION pt_20260107 VALUES [('2026-01-07 00:00:00'), ('2026-01-08 00:00:00')),
PARTITION pt_20260108 VALUES [('2026-01-08 00:00:00'), ('2026-01-09 00:00:00')),
PARTITION pt_20260109 VALUES [('2026-01-09 00:00:00'), ('2026-01-10 00:00:00')),
PARTITION pt_20260110 VALUES [('2026-01-10 00:00:00'), ('2026-01-11 00:00:00')),
PARTITION pt_20260111 VALUES [('2026-01-11 00:00:00'), ('2026-01-12 00:00:00')),
PARTITION pt_20260112 VALUES [('2026-01-12 00:00:00'), ('2026-01-13 00:00:00')),
PARTITION pt_20260113 VALUES [('2026-01-13 00:00:00'), ('2026-01-14 00:00:00')),
PARTITION pt_20260114 VALUES [('2026-01-14 00:00:00'), ('2026-01-15 00:00:00')),
PARTITION pt_20260115 VALUES [('2026-01-15 00:00:00'), ('2026-01-16 00:00:00')),
PARTITION pt_20260116 VALUES [('2026-01-16 00:00:00'), ('2026-01-17 00:00:00')),
PARTITION pt_20260117 VALUES [('2026-01-17 00:00:00'), ('2026-01-18 00:00:00')),
PARTITION pt_20260118 VALUES [('2026-01-18 00:00:00'), ('2026-01-19 00:00:00')),
PARTITION pt_20260119 VALUES [('2026-01-19 00:00:00'), ('2026-01-20 00:00:00')),
PARTITION pt_20260120 VALUES [('2026-01-20 00:00:00'), ('2026-01-21 00:00:00')),
PARTITION pt_20260121 VALUES [('2026-01-21 00:00:00'), ('2026-01-22 00:00:00')),
PARTITION pt_20260122 VALUES [('2026-01-22 00:00:00'), ('2026-01-23 00:00:00')),
PARTITION pt_20260123 VALUES [('2026-01-23 00:00:00'), ('2026-01-24 00:00:00')),
PARTITION pt_20260124 VALUES [('2026-01-24 00:00:00'), ('2026-01-25 00:00:00')),
PARTITION pt_20260125 VALUES [('2026-01-25 00:00:00'), ('2026-01-26 00:00:00')),
PARTITION pt_20260126 VALUES [('2026-01-26 00:00:00'), ('2026-01-27 00:00:00')),
PARTITION pt_20260127 VALUES [('2026-01-27 00:00:00'), ('2026-01-28 00:00:00')),
PARTITION pt_20260128 VALUES [('2026-01-28 00:00:00'), ('2026-01-29 00:00:00')),
PARTITION pt_20260129 VALUES [('2026-01-29 00:00:00'), ('2026-01-30 00:00:00')),
PARTITION pt_20260130 VALUES [('2026-01-30 00:00:00'), ('2026-01-31 00:00:00')),
PARTITION pt_20260131 VALUES [('2026-01-31 00:00:00'), ('2026-02-01 00:00:00')),
PARTITION pt_20260201 VALUES [('2026-02-01 00:00:00'), ('2026-02-02 00:00:00')),
PARTITION pt_20260202 VALUES [('2026-02-02 00:00:00'), ('2026-02-03 00:00:00')),
PARTITION pt_20260203 VALUES [('2026-02-03 00:00:00'), ('2026-02-04 00:00:00')),
PARTITION pt_20260204 VALUES [('2026-02-04 00:00:00'), ('2026-02-05 00:00:00')),
PARTITION pt_20260205 VALUES [('2026-02-05 00:00:00'), ('2026-02-06 00:00:00')),
PARTITION pt_20260206 VALUES [('2026-02-06 00:00:00'), ('2026-02-07 00:00:00')),
PARTITION pt_20260207 VALUES [('2026-02-07 00:00:00'), ('2026-02-08 00:00:00')),
PARTITION pt_20260208 VALUES [('2026-02-08 00:00:00'), ('2026-02-09 00:00:00')),
PARTITION pt_20260209 VALUES [('2026-02-09 00:00:00'), ('2026-02-10 00:00:00')),
PARTITION pt_20260210 VALUES [('2026-02-10 00:00:00'), ('2026-02-11 00:00:00')),
PARTITION pt_20260211 VALUES [('2026-02-11 00:00:00'), ('2026-02-12 00:00:00')),
PARTITION pt_20260212 VALUES [('2026-02-12 00:00:00'), ('2026-02-13 00:00:00')),
PARTITION pt_20260213 VALUES [('2026-02-13 00:00:00'), ('2026-02-14 00:00:00')),
PARTITION pt_20260214 VALUES [('2026-02-14 00:00:00'), ('2026-02-15 00:00:00')),
PARTITION pt_20260215 VALUES [('2026-02-15 00:00:00'), ('2026-02-16 00:00:00')),
PARTITION pt_20260216 VALUES [('2026-02-16 00:00:00'), ('2026-02-17 00:00:00')),
PARTITION pt_20260217 VALUES [('2026-02-17 00:00:00'), ('2026-02-18 00:00:00')),
PARTITION pt_20260218 VALUES [('2026-02-18 00:00:00'), ('2026-02-19 00:00:00')),
PARTITION pt_20260219 VALUES [('2026-02-19 00:00:00'), ('2026-02-20 00:00:00')),
PARTITION pt_20260220 VALUES [('2026-02-20 00:00:00'), ('2026-02-21 00:00:00')),
PARTITION pt_20260221 VALUES [('2026-02-21 00:00:00'), ('2026-02-22 00:00:00')),
PARTITION pt_20260222 VALUES [('2026-02-22 00:00:00'), ('2026-02-23 00:00:00')),
PARTITION pt_20260223 VALUES [('2026-02-23 00:00:00'), ('2026-02-24 00:00:00')),
PARTITION pt_20260224 VALUES [('2026-02-24 00:00:00'), ('2026-02-25 00:00:00')),
PARTITION pt_20260225 VALUES [('2026-02-25 00:00:00'), ('2026-02-26 00:00:00')),
PARTITION pt_20260226 VALUES [('2026-02-26 00:00:00'), ('2026-02-27 00:00:00')),
PARTITION pt_20260227 VALUES [('2026-02-27 00:00:00'), ('2026-02-28 00:00:00')),
PARTITION pt_20260228 VALUES [('2026-02-28 00:00:00'), ('2026-03-01 00:00:00')),
PARTITION pt_20260301 VALUES [('2026-03-01 00:00:00'), ('2026-03-02 00:00:00')),
PARTITION pt_20260302 VALUES [('2026-03-02 00:00:00'), ('2026-03-03 00:00:00')),
PARTITION pt_20260303 VALUES [('2026-03-03 00:00:00'), ('2026-03-04 00:00:00')),
PARTITION pt_20260304 VALUES [('2026-03-04 00:00:00'), ('2026-03-05 00:00:00')),
PARTITION pt_20260305 VALUES [('2026-03-05 00:00:00'), ('2026-03-06 00:00:00')),
PARTITION pt_20260306 VALUES [('2026-03-06 00:00:00'), ('2026-03-07 00:00:00')),
PARTITION pt_20260307 VALUES [('2026-03-07 00:00:00'), ('2026-03-08 00:00:00')),
PARTITION pt_20260308 VALUES [('2026-03-08 00:00:00'), ('2026-03-09 00:00:00')),
PARTITION pt_20260309 VALUES [('2026-03-09 00:00:00'), ('2026-03-10 00:00:00')),
PARTITION pt_20260310 VALUES [('2026-03-10 00:00:00'), ('2026-03-11 00:00:00')),
PARTITION pt_20260311 VALUES [('2026-03-11 00:00:00'), ('2026-03-12 00:00:00')),
PARTITION pt_20260312 VALUES [('2026-03-12 00:00:00'), ('2026-03-13 00:00:00')),
PARTITION pt_20260313 VALUES [('2026-03-13 00:00:00'), ('2026-03-14 00:00:00')),
PARTITION pt_20260314 VALUES [('2026-03-14 00:00:00'), ('2026-03-15 00:00:00')),
PARTITION pt_20260315 VALUES [('2026-03-15 00:00:00'), ('2026-03-16 00:00:00')),
PARTITION pt_20260316 VALUES [('2026-03-16 00:00:00'), ('2026-03-17 00:00:00')),
PARTITION pt_20260317 VALUES [('2026-03-17 00:00:00'), ('2026-03-18 00:00:00')),
PARTITION pt_20260318 VALUES [('2026-03-18 00:00:00'), ('2026-03-19 00:00:00')),
PARTITION pt_20260319 VALUES [('2026-03-19 00:00:00'), ('2026-03-20 00:00:00')),
PARTITION pt_20260320 VALUES [('2026-03-20 00:00:00'), ('2026-03-21 00:00:00')),
PARTITION pt_20260321 VALUES [('2026-03-21 00:00:00'), ('2026-03-22 00:00:00')),
PARTITION pt_20260322 VALUES [('2026-03-22 00:00:00'), ('2026-03-23 00:00:00')),
PARTITION pt_20260323 VALUES [('2026-03-23 00:00:00'), ('2026-03-24 00:00:00')),
PARTITION pt_20260324 VALUES [('2026-03-24 00:00:00'), ('2026-03-25 00:00:00')),
PARTITION pt_20260325 VALUES [('2026-03-25 00:00:00'), ('2026-03-26 00:00:00')),
PARTITION pt_20260326 VALUES [('2026-03-26 00:00:00'), ('2026-03-27 00:00:00')),
PARTITION pt_20260327 VALUES [('2026-03-27 00:00:00'), ('2026-03-28 00:00:00')),
PARTITION pt_20260328 VALUES [('2026-03-28 00:00:00'), ('2026-03-29 00:00:00')),
PARTITION pt_20260329 VALUES [('2026-03-29 00:00:00'), ('2026-03-30 00:00:00')),
PARTITION pt_20260330 VALUES [('2026-03-30 00:00:00'), ('2026-03-31 00:00:00')),
PARTITION pt_20260331 VALUES [('2026-03-31 00:00:00'), ('2026-04-01 00:00:00')),
PARTITION pt_20260401 VALUES [('2026-04-01 00:00:00'), ('2026-04-02 00:00:00')),
PARTITION pt_20260402 VALUES [('2026-04-02 00:00:00'), ('2026-04-03 00:00:00')),
PARTITION pt_20260403 VALUES [('2026-04-03 00:00:00'), ('2026-04-04 00:00:00')),
PARTITION pt_20260404 VALUES [('2026-04-04 00:00:00'), ('2026-04-05 00:00:00')),
PARTITION pt_20260405 VALUES [('2026-04-05 00:00:00'), ('2026-04-06 00:00:00')),
PARTITION pt_20260406 VALUES [('2026-04-06 00:00:00'), ('2026-04-07 00:00:00')),
PARTITION pt_20260407 VALUES [('2026-04-07 00:00:00'), ('2026-04-08 00:00:00')),
PARTITION pt_20260408 VALUES [('2026-04-08 00:00:00'), ('2026-04-09 00:00:00')),
PARTITION pt_20260409 VALUES [('2026-04-09 00:00:00'), ('2026-04-10 00:00:00')),
PARTITION pt_20260410 VALUES [('2026-04-10 00:00:00'), ('2026-04-11 00:00:00')),
PARTITION pt_20260411 VALUES [('2026-04-11 00:00:00'), ('2026-04-12 00:00:00')),
PARTITION pt_20260412 VALUES [('2026-04-12 00:00:00'), ('2026-04-13 00:00:00')),
PARTITION pt_20260413 VALUES [('2026-04-13 00:00:00'), ('2026-04-14 00:00:00')),
PARTITION pt_20260414 VALUES [('2026-04-14 00:00:00'), ('2026-04-15 00:00:00')),
PARTITION pt_20260415 VALUES [('2026-04-15 00:00:00'), ('2026-04-16 00:00:00')),
PARTITION pt_20260416 VALUES [('2026-04-16 00:00:00'), ('2026-04-17 00:00:00')),
PARTITION pt_20260417 VALUES [('2026-04-17 00:00:00'), ('2026-04-18 00:00:00')),
PARTITION pt_20260418 VALUES [('2026-04-18 00:00:00'), ('2026-04-19 00:00:00')),
PARTITION pt_20260419 VALUES [('2026-04-19 00:00:00'), ('2026-04-20 00:00:00')),
PARTITION pt_20260420 VALUES [('2026-04-20 00:00:00'), ('2026-04-21 00:00:00')),
PARTITION pt_20260421 VALUES [('2026-04-21 00:00:00'), ('2026-04-22 00:00:00')),
PARTITION pt_20260422 VALUES [('2026-04-22 00:00:00'), ('2026-04-23 00:00:00')),
PARTITION pt_20260423 VALUES [('2026-04-23 00:00:00'), ('2026-04-24 00:00:00')),
PARTITION pt_20260424 VALUES [('2026-04-24 00:00:00'), ('2026-04-25 00:00:00')),
PARTITION pt_20260425 VALUES [('2026-04-25 00:00:00'), ('2026-04-26 00:00:00')),
PARTITION pt_20260426 VALUES [('2026-04-26 00:00:00'), ('2026-04-27 00:00:00')),
PARTITION pt_20260427 VALUES [('2026-04-27 00:00:00'), ('2026-04-28 00:00:00')),
PARTITION pt_20260428 VALUES [('2026-04-28 00:00:00'), ('2026-04-29 00:00:00')),
PARTITION pt_20260429 VALUES [('2026-04-29 00:00:00'), ('2026-04-30 00:00:00')),
PARTITION pt_20260430 VALUES [('2026-04-30 00:00:00'), ('2026-05-01 00:00:00')),
PARTITION pt_20260501 VALUES [('2026-05-01 00:00:00'), ('2026-05-02 00:00:00')),
PARTITION pt_20260502 VALUES [('2026-05-02 00:00:00'), ('2026-05-03 00:00:00')),
PARTITION pt_20260503 VALUES [('2026-05-03 00:00:00'), ('2026-05-04 00:00:00')),
PARTITION pt_20260504 VALUES [('2026-05-04 00:00:00'), ('2026-05-05 00:00:00')),
PARTITION pt_20260505 VALUES [('2026-05-05 00:00:00'), ('2026-05-06 00:00:00')),
PARTITION pt_20260506 VALUES [('2026-05-06 00:00:00'), ('2026-05-07 00:00:00')),
PARTITION pt_20260507 VALUES [('2026-05-07 00:00:00'), ('2026-05-08 00:00:00')),
PARTITION pt_20260508 VALUES [('2026-05-08 00:00:00'), ('2026-05-09 00:00:00')),
PARTITION pt_20260509 VALUES [('2026-05-09 00:00:00'), ('2026-05-10 00:00:00')),
PARTITION pt_20260510 VALUES [('2026-05-10 00:00:00'), ('2026-05-11 00:00:00')),
PARTITION pt_20260511 VALUES [('2026-05-11 00:00:00'), ('2026-05-12 00:00:00')),
PARTITION pt_20260512 VALUES [('2026-05-12 00:00:00'), ('2026-05-13 00:00:00')),
PARTITION pt_20260513 VALUES [('2026-05-13 00:00:00'), ('2026-05-14 00:00:00')),
PARTITION pt_20260514 VALUES [('2026-05-14 00:00:00'), ('2026-05-15 00:00:00')),
PARTITION pt_20260515 VALUES [('2026-05-15 00:00:00'), ('2026-05-16 00:00:00')),
PARTITION pt_20260516 VALUES [('2026-05-16 00:00:00'), ('2026-05-17 00:00:00')),
PARTITION pt_20260517 VALUES [('2026-05-17 00:00:00'), ('2026-05-18 00:00:00')),
PARTITION pt_20260518 VALUES [('2026-05-18 00:00:00'), ('2026-05-19 00:00:00')),
PARTITION pt_20260519 VALUES [('2026-05-19 00:00:00'), ('2026-05-20 00:00:00')),
PARTITION pt_20260520 VALUES [('2026-05-20 00:00:00'), ('2026-05-21 00:00:00')),
PARTITION pt_20260521 VALUES [('2026-05-21 00:00:00'), ('2026-05-22 00:00:00')),
PARTITION pt_20260522 VALUES [('2026-05-22 00:00:00'), ('2026-05-23 00:00:00')),
PARTITION pt_20260523 VALUES [('2026-05-23 00:00:00'), ('2026-05-24 00:00:00')),
PARTITION pt_20260524 VALUES [('2026-05-24 00:00:00'), ('2026-05-25 00:00:00')),
PARTITION pt_20260525 VALUES [('2026-05-25 00:00:00'), ('2026-05-26 00:00:00')),
PARTITION pt_20260526 VALUES [('2026-05-26 00:00:00'), ('2026-05-27 00:00:00')),
PARTITION pt_20260527 VALUES [('2026-05-27 00:00:00'), ('2026-05-28 00:00:00')),
PARTITION pt_20260528 VALUES [('2026-05-28 00:00:00'), ('2026-05-29 00:00:00')),
PARTITION pt_20260529 VALUES [('2026-05-29 00:00:00'), ('2026-05-30 00:00:00')),
PARTITION pt_20260530 VALUES [('2026-05-30 00:00:00'), ('2026-05-31 00:00:00')),
PARTITION pt_20260531 VALUES [('2026-05-31 00:00:00'), ('2026-06-01 00:00:00')),
PARTITION pt_20260601 VALUES [('2026-06-01 00:00:00'), ('2026-06-02 00:00:00')),
PARTITION pt_20260602 VALUES [('2026-06-02 00:00:00'), ('2026-06-03 00:00:00')),
PARTITION pt_20260603 VALUES [('2026-06-03 00:00:00'), ('2026-06-04 00:00:00')),
PARTITION pt_20260604 VALUES [('2026-06-04 00:00:00'), ('2026-06-05 00:00:00')),
PARTITION pt_20260605 VALUES [('2026-06-05 00:00:00'), ('2026-06-06 00:00:00')),
PARTITION pt_20260606 VALUES [('2026-06-06 00:00:00'), ('2026-06-07 00:00:00')),
PARTITION pt_20260607 VALUES [('2026-06-07 00:00:00'), ('2026-06-08 00:00:00')),
PARTITION pt_20260608 VALUES [('2026-06-08 00:00:00'), ('2026-06-09 00:00:00')),
PARTITION pt_20260609 VALUES [('2026-06-09 00:00:00'), ('2026-06-10 00:00:00')),
PARTITION pt_20260610 VALUES [('2026-06-10 00:00:00'), ('2026-06-11 00:00:00')),
PARTITION pt_20260611 VALUES [('2026-06-11 00:00:00'), ('2026-06-12 00:00:00')),
PARTITION pt_20260612 VALUES [('2026-06-12 00:00:00'), ('2026-06-13 00:00:00')),
PARTITION pt_20260613 VALUES [('2026-06-13 00:00:00'), ('2026-06-14 00:00:00')),
PARTITION pt_20260614 VALUES [('2026-06-14 00:00:00'), ('2026-06-15 00:00:00')),
PARTITION pt_20260615 VALUES [('2026-06-15 00:00:00'), ('2026-06-16 00:00:00')),
PARTITION pt_20260616 VALUES [('2026-06-16 00:00:00'), ('2026-06-17 00:00:00')),
PARTITION pt_20260617 VALUES [('2026-06-17 00:00:00'), ('2026-06-18 00:00:00')),
PARTITION pt_20260618 VALUES [('2026-06-18 00:00:00'), ('2026-06-19 00:00:00')),
PARTITION pt_20260619 VALUES [('2026-06-19 00:00:00'), ('2026-06-20 00:00:00')),
PARTITION pt_20260620 VALUES [('2026-06-20 00:00:00'), ('2026-06-21 00:00:00')),
PARTITION pt_20260621 VALUES [('2026-06-21 00:00:00'), ('2026-06-22 00:00:00')),
PARTITION pt_20260622 VALUES [('2026-06-22 00:00:00'), ('2026-06-23 00:00:00')),
PARTITION pt_20260623 VALUES [('2026-06-23 00:00:00'), ('2026-06-24 00:00:00')),
PARTITION pt_20260624 VALUES [('2026-06-24 00:00:00'), ('2026-06-25 00:00:00')),
PARTITION pt_20260625 VALUES [('2026-06-25 00:00:00'), ('2026-06-26 00:00:00')),
PARTITION pt_20260626 VALUES [('2026-06-26 00:00:00'), ('2026-06-27 00:00:00')),
PARTITION pt_20260627 VALUES [('2026-06-27 00:00:00'), ('2026-06-28 00:00:00')),
PARTITION pt_20260628 VALUES [('2026-06-28 00:00:00'), ('2026-06-29 00:00:00')),
PARTITION pt_20260629 VALUES [('2026-06-29 00:00:00'), ('2026-06-30 00:00:00')),
PARTITION pt_20260630 VALUES [('2026-06-30 00:00:00'), ('2026-07-01 00:00:00')),
PARTITION pt_20260701 VALUES [('2026-07-01 00:00:00'), ('2026-07-02 00:00:00')),
PARTITION pt_20260702 VALUES [('2026-07-02 00:00:00'), ('2026-07-03 00:00:00')),
PARTITION pt_20260703 VALUES [('2026-07-03 00:00:00'), ('2026-07-04 00:00:00')),
PARTITION pt_20260704 VALUES [('2026-07-04 00:00:00'), ('2026-07-05 00:00:00')),
PARTITION pt_20260705 VALUES [('2026-07-05 00:00:00'), ('2026-07-06 00:00:00')),
PARTITION pt_20260706 VALUES [('2026-07-06 00:00:00'), ('2026-07-07 00:00:00')),
PARTITION pt_20260707 VALUES [('2026-07-07 00:00:00'), ('2026-07-08 00:00:00')),
PARTITION pt_20260708 VALUES [('2026-07-08 00:00:00'), ('2026-07-09 00:00:00')),
PARTITION pt_20260709 VALUES [('2026-07-09 00:00:00'), ('2026-07-10 00:00:00')),
PARTITION pt_20260710 VALUES [('2026-07-10 00:00:00'), ('2026-07-11 00:00:00')),
PARTITION pt_20260711 VALUES [('2026-07-11 00:00:00'), ('2026-07-12 00:00:00')),
PARTITION pt_20260712 VALUES [('2026-07-12 00:00:00'), ('2026-07-13 00:00:00')),
PARTITION pt_20260713 VALUES [('2026-07-13 00:00:00'), ('2026-07-14 00:00:00')),
PARTITION pt_20260714 VALUES [('2026-07-14 00:00:00'), ('2026-07-15 00:00:00')),
PARTITION pt_20260715 VALUES [('2026-07-15 00:00:00'), ('2026-07-16 00:00:00')),
PARTITION pt_20260716 VALUES [('2026-07-16 00:00:00'), ('2026-07-17 00:00:00')),
PARTITION pt_20260717 VALUES [('2026-07-17 00:00:00'), ('2026-07-18 00:00:00')),
PARTITION pt_20260718 VALUES [('2026-07-18 00:00:00'), ('2026-07-19 00:00:00')),
PARTITION pt_20260719 VALUES [('2026-07-19 00:00:00'), ('2026-07-20 00:00:00')),
PARTITION pt_20260720 VALUES [('2026-07-20 00:00:00'), ('2026-07-21 00:00:00')),
PARTITION pt_20260721 VALUES [('2026-07-21 00:00:00'), ('2026-07-22 00:00:00')),
PARTITION pt_20260722 VALUES [('2026-07-22 00:00:00'), ('2026-07-23 00:00:00')),
PARTITION pt_20260723 VALUES [('2026-07-23 00:00:00'), ('2026-07-24 00:00:00')),
PARTITION pt_20260724 VALUES [('2026-07-24 00:00:00'), ('2026-07-25 00:00:00')),
PARTITION pt_20260725 VALUES [('2026-07-25 00:00:00'), ('2026-07-26 00:00:00')),
PARTITION pt_20260726 VALUES [('2026-07-26 00:00:00'), ('2026-07-27 00:00:00')),
PARTITION pt_20260727 VALUES [('2026-07-27 00:00:00'), ('2026-07-28 00:00:00')),
PARTITION pt_20260728 VALUES [('2026-07-28 00:00:00'), ('2026-07-29 00:00:00')),
PARTITION pt_20260729 VALUES [('2026-07-29 00:00:00'), ('2026-07-30 00:00:00')),
PARTITION pt_20260730 VALUES [('2026-07-30 00:00:00'), ('2026-07-31 00:00:00')),
PARTITION pt_20260731 VALUES [('2026-07-31 00:00:00'), ('2026-08-01 00:00:00')),
PARTITION pt_20260801 VALUES [('2026-08-01 00:00:00'), ('2026-08-02 00:00:00')),
PARTITION pt_20260802 VALUES [('2026-08-02 00:00:00'), ('2026-08-03 00:00:00')),
PARTITION pt_20260803 VALUES [('2026-08-03 00:00:00'), ('2026-08-04 00:00:00')),
PARTITION pt_20260804 VALUES [('2026-08-04 00:00:00'), ('2026-08-05 00:00:00')),
PARTITION pt_20260805 VALUES [('2026-08-05 00:00:00'), ('2026-08-06 00:00:00')),
PARTITION pt_20260806 VALUES [('2026-08-06 00:00:00'), ('2026-08-07 00:00:00')),
PARTITION pt_20260807 VALUES [('2026-08-07 00:00:00'), ('2026-08-08 00:00:00')),
PARTITION pt_20260808 VALUES [('2026-08-08 00:00:00'), ('2026-08-09 00:00:00')),
PARTITION pt_20260809 VALUES [('2026-08-09 00:00:00'), ('2026-08-10 00:00:00')),
PARTITION pt_20260810 VALUES [('2026-08-10 00:00:00'), ('2026-08-11 00:00:00')),
PARTITION pt_20260811 VALUES [('2026-08-11 00:00:00'), ('2026-08-12 00:00:00')),
PARTITION pt_20260812 VALUES [('2026-08-12 00:00:00'), ('2026-08-13 00:00:00')),
PARTITION pt_20260813 VALUES [('2026-08-13 00:00:00'), ('2026-08-14 00:00:00')),
PARTITION pt_20260814 VALUES [('2026-08-14 00:00:00'), ('2026-08-15 00:00:00')),
PARTITION pt_20260815 VALUES [('2026-08-15 00:00:00'), ('2026-08-16 00:00:00')),
PARTITION pt_20260816 VALUES [('2026-08-16 00:00:00'), ('2026-08-17 00:00:00')),
PARTITION pt_20260817 VALUES [('2026-08-17 00:00:00'), ('2026-08-18 00:00:00')),
PARTITION pt_20260818 VALUES [('2026-08-18 00:00:00'), ('2026-08-19 00:00:00')),
PARTITION pt_20260819 VALUES [('2026-08-19 00:00:00'), ('2026-08-20 00:00:00')),
PARTITION pt_20260820 VALUES [('2026-08-20 00:00:00'), ('2026-08-21 00:00:00')),
PARTITION pt_20260821 VALUES [('2026-08-21 00:00:00'), ('2026-08-22 00:00:00')),
PARTITION pt_20260822 VALUES [('2026-08-22 00:00:00'), ('2026-08-23 00:00:00')),
PARTITION pt_20260823 VALUES [('2026-08-23 00:00:00'), ('2026-08-24 00:00:00')),
PARTITION pt_20260824 VALUES [('2026-08-24 00:00:00'), ('2026-08-25 00:00:00')),
PARTITION pt_20260825 VALUES [('2026-08-25 00:00:00'), ('2026-08-26 00:00:00')),
PARTITION pt_20260826 VALUES [('2026-08-26 00:00:00'), ('2026-08-27 00:00:00')),
PARTITION pt_20260827 VALUES [('2026-08-27 00:00:00'), ('2026-08-28 00:00:00')),
PARTITION pt_20260828 VALUES [('2026-08-28 00:00:00'), ('2026-08-29 00:00:00')),
PARTITION pt_20260829 VALUES [('2026-08-29 00:00:00'), ('2026-08-30 00:00:00')),
PARTITION pt_20260830 VALUES [('2026-08-30 00:00:00'), ('2026-08-31 00:00:00')),
PARTITION pt_20260831 VALUES [('2026-08-31 00:00:00'), ('2026-09-01 00:00:00')),
PARTITION pt_20260901 VALUES [('2026-09-01 00:00:00'), ('2026-09-02 00:00:00')),
PARTITION pt_20260902 VALUES [('2026-09-02 00:00:00'), ('2026-09-03 00:00:00')),
PARTITION pt_20260903 VALUES [('2026-09-03 00:00:00'), ('2026-09-04 00:00:00')),
PARTITION pt_20260904 VALUES [('2026-09-04 00:00:00'), ('2026-09-05 00:00:00')),
PARTITION pt_20260905 VALUES [('2026-09-05 00:00:00'), ('2026-09-06 00:00:00')),
PARTITION pt_20260906 VALUES [('2026-09-06 00:00:00'), ('2026-09-07 00:00:00')),
PARTITION pt_20260907 VALUES [('2026-09-07 00:00:00'), ('2026-09-08 00:00:00')),
PARTITION pt_20260908 VALUES [('2026-09-08 00:00:00'), ('2026-09-09 00:00:00')),
PARTITION pt_20260909 VALUES [('2026-09-09 00:00:00'), ('2026-09-10 00:00:00')),
PARTITION pt_20260910 VALUES [('2026-09-10 00:00:00'), ('2026-09-11 00:00:00')),
PARTITION pt_20260911 VALUES [('2026-09-11 00:00:00'), ('2026-09-12 00:00:00')),
PARTITION pt_20260912 VALUES [('2026-09-12 00:00:00'), ('2026-09-13 00:00:00')),
PARTITION pt_20260913 VALUES [('2026-09-13 00:00:00'), ('2026-09-14 00:00:00')),
PARTITION pt_20260914 VALUES [('2026-09-14 00:00:00'), ('2026-09-15 00:00:00')),
PARTITION pt_20260915 VALUES [('2026-09-15 00:00:00'), ('2026-09-16 00:00:00')),
PARTITION pt_20260916 VALUES [('2026-09-16 00:00:00'), ('2026-09-17 00:00:00')),
PARTITION pt_20260917 VALUES [('2026-09-17 00:00:00'), ('2026-09-18 00:00:00')),
PARTITION pt_20260918 VALUES [('2026-09-18 00:00:00'), ('2026-09-19 00:00:00')),
PARTITION pt_20260919 VALUES [('2026-09-19 00:00:00'), ('2026-09-20 00:00:00')),
PARTITION pt_20260920 VALUES [('2026-09-20 00:00:00'), ('2026-09-21 00:00:00')),
PARTITION pt_20260921 VALUES [('2026-09-21 00:00:00'), ('2026-09-22 00:00:00')),
PARTITION pt_20260922 VALUES [('2026-09-22 00:00:00'), ('2026-09-23 00:00:00')),
PARTITION pt_20260923 VALUES [('2026-09-23 00:00:00'), ('2026-09-24 00:00:00')),
PARTITION pt_20260924 VALUES [('2026-09-24 00:00:00'), ('2026-09-25 00:00:00')),
PARTITION pt_20260925 VALUES [('2026-09-25 00:00:00'), ('2026-09-26 00:00:00')),
PARTITION pt_20260926 VALUES [('2026-09-26 00:00:00'), ('2026-09-27 00:00:00')),
PARTITION pt_20260927 VALUES [('2026-09-27 00:00:00'), ('2026-09-28 00:00:00')),
PARTITION pt_20260928 VALUES [('2026-09-28 00:00:00'), ('2026-09-29 00:00:00')),
PARTITION pt_20260929 VALUES [('2026-09-29 00:00:00'), ('2026-09-30 00:00:00')),
PARTITION pt_20260930 VALUES [('2026-09-30 00:00:00'), ('2026-10-01 00:00:00')),
PARTITION pt_20261001 VALUES [('2026-10-01 00:00:00'), ('2026-10-02 00:00:00')),
PARTITION pt_20261002 VALUES [('2026-10-02 00:00:00'), ('2026-10-03 00:00:00')),
PARTITION pt_20261003 VALUES [('2026-10-03 00:00:00'), ('2026-10-04 00:00:00')),
PARTITION pt_20261004 VALUES [('2026-10-04 00:00:00'), ('2026-10-05 00:00:00')),
PARTITION pt_20261005 VALUES [('2026-10-05 00:00:00'), ('2026-10-06 00:00:00')),
PARTITION pt_20261006 VALUES [('2026-10-06 00:00:00'), ('2026-10-07 00:00:00')),
PARTITION pt_20261007 VALUES [('2026-10-07 00:00:00'), ('2026-10-08 00:00:00')),
PARTITION pt_20261008 VALUES [('2026-10-08 00:00:00'), ('2026-10-09 00:00:00')),
PARTITION pt_20261009 VALUES [('2026-10-09 00:00:00'), ('2026-10-10 00:00:00')),
PARTITION pt_20261010 VALUES [('2026-10-10 00:00:00'), ('2026-10-11 00:00:00')),
PARTITION pt_20261011 VALUES [('2026-10-11 00:00:00'), ('2026-10-12 00:00:00')),
PARTITION pt_20261012 VALUES [('2026-10-12 00:00:00'), ('2026-10-13 00:00:00')),
PARTITION pt_20261013 VALUES [('2026-10-13 00:00:00'), ('2026-10-14 00:00:00')),
PARTITION pt_20261014 VALUES [('2026-10-14 00:00:00'), ('2026-10-15 00:00:00')),
PARTITION pt_20261015 VALUES [('2026-10-15 00:00:00'), ('2026-10-16 00:00:00')),
PARTITION pt_20261016 VALUES [('2026-10-16 00:00:00'), ('2026-10-17 00:00:00')),
PARTITION pt_20261017 VALUES [('2026-10-17 00:00:00'), ('2026-10-18 00:00:00')),
PARTITION pt_20261018 VALUES [('2026-10-18 00:00:00'), ('2026-10-19 00:00:00')),
PARTITION pt_20261019 VALUES [('2026-10-19 00:00:00'), ('2026-10-20 00:00:00')),
PARTITION pt_20261020 VALUES [('2026-10-20 00:00:00'), ('2026-10-21 00:00:00')),
PARTITION pt_20261021 VALUES [('2026-10-21 00:00:00'), ('2026-10-22 00:00:00')),
PARTITION pt_20261022 VALUES [('2026-10-22 00:00:00'), ('2026-10-23 00:00:00')),
PARTITION pt_20261023 VALUES [('2026-10-23 00:00:00'), ('2026-10-24 00:00:00')),
PARTITION pt_20261024 VALUES [('2026-10-24 00:00:00'), ('2026-10-25 00:00:00')),
PARTITION pt_20261025 VALUES [('2026-10-25 00:00:00'), ('2026-10-26 00:00:00')),
PARTITION pt_20261026 VALUES [('2026-10-26 00:00:00'), ('2026-10-27 00:00:00')),
PARTITION pt_20261027 VALUES [('2026-10-27 00:00:00'), ('2026-10-28 00:00:00')),
PARTITION pt_20261028 VALUES [('2026-10-28 00:00:00'), ('2026-10-29 00:00:00')),
PARTITION pt_20261029 VALUES [('2026-10-29 00:00:00'), ('2026-10-30 00:00:00')),
PARTITION pt_20261030 VALUES [('2026-10-30 00:00:00'), ('2026-10-31 00:00:00')),
PARTITION pt_20261031 VALUES [('2026-10-31 00:00:00'), ('2026-11-01 00:00:00')),
PARTITION pt_20261101 VALUES [('2026-11-01 00:00:00'), ('2026-11-02 00:00:00')),
PARTITION pt_20261102 VALUES [('2026-11-02 00:00:00'), ('2026-11-03 00:00:00')),
PARTITION pt_20261103 VALUES [('2026-11-03 00:00:00'), ('2026-11-04 00:00:00')),
PARTITION pt_20261104 VALUES [('2026-11-04 00:00:00'), ('2026-11-05 00:00:00')),
PARTITION pt_20261105 VALUES [('2026-11-05 00:00:00'), ('2026-11-06 00:00:00')),
PARTITION pt_20261106 VALUES [('2026-11-06 00:00:00'), ('2026-11-07 00:00:00')),
PARTITION pt_20261107 VALUES [('2026-11-07 00:00:00'), ('2026-11-08 00:00:00')),
PARTITION pt_20261108 VALUES [('2026-11-08 00:00:00'), ('2026-11-09 00:00:00')),
PARTITION pt_20261109 VALUES [('2026-11-09 00:00:00'), ('2026-11-10 00:00:00')),
PARTITION pt_20261110 VALUES [('2026-11-10 00:00:00'), ('2026-11-11 00:00:00')),
PARTITION pt_20261111 VALUES [('2026-11-11 00:00:00'), ('2026-11-12 00:00:00')),
PARTITION pt_20261112 VALUES [('2026-11-12 00:00:00'), ('2026-11-13 00:00:00')),
PARTITION pt_20261113 VALUES [('2026-11-13 00:00:00'), ('2026-11-14 00:00:00')),
PARTITION pt_20261114 VALUES [('2026-11-14 00:00:00'), ('2026-11-15 00:00:00')),
PARTITION pt_20261115 VALUES [('2026-11-15 00:00:00'), ('2026-11-16 00:00:00')),
PARTITION pt_20261116 VALUES [('2026-11-16 00:00:00'), ('2026-11-17 00:00:00')),
PARTITION pt_20261117 VALUES [('2026-11-17 00:00:00'), ('2026-11-18 00:00:00')),
PARTITION pt_20261118 VALUES [('2026-11-18 00:00:00'), ('2026-11-19 00:00:00')),
PARTITION pt_20261119 VALUES [('2026-11-19 00:00:00'), ('2026-11-20 00:00:00')),
PARTITION pt_20261120 VALUES [('2026-11-20 00:00:00'), ('2026-11-21 00:00:00')),
PARTITION pt_20261121 VALUES [('2026-11-21 00:00:00'), ('2026-11-22 00:00:00')),
PARTITION pt_20261122 VALUES [('2026-11-22 00:00:00'), ('2026-11-23 00:00:00')),
PARTITION pt_20261123 VALUES [('2026-11-23 00:00:00'), ('2026-11-24 00:00:00')),
PARTITION pt_20261124 VALUES [('2026-11-24 00:00:00'), ('2026-11-25 00:00:00')),
PARTITION pt_20261125 VALUES [('2026-11-25 00:00:00'), ('2026-11-26 00:00:00')),
PARTITION pt_20261126 VALUES [('2026-11-26 00:00:00'), ('2026-11-27 00:00:00')),
PARTITION pt_20261127 VALUES [('2026-11-27 00:00:00'), ('2026-11-28 00:00:00')),
PARTITION pt_20261128 VALUES [('2026-11-28 00:00:00'), ('2026-11-29 00:00:00')))
DISTRIBUTED BY HASH(`merchant_id`) BUCKETS 1
PROPERTIES (
"file_cache_ttl_seconds" = "0",
"dynamic_partition.enable" = "true",
"dynamic_partition.time_unit" = "DAY",
"dynamic_partition.time_zone" = "Asia/Shanghai",
"dynamic_partition.start" = "-2147483648",
"dynamic_partition.end" = "1",
"dynamic_partition.prefix" = "pt_",
"dynamic_partition.buckets" = "1",
"dynamic_partition.create_history_partition" = "true",
"dynamic_partition.history_partition_num" = "366",
"dynamic_partition.hot_partition_num" = "0",
"dynamic_partition.reserved_history_periods" = "NULL",
"enable_unique_key_merge_on_write" = "true",
"light_schema_change" = "true",
"group_commit_interval_ms" = "10000",
"group_commit_data_bytes" = "134217728"
);

-- @table RDS_summary:pft_dc_daycount_info
-- @at 2026-11-27 15:58:57
CREATE TABLE `pft_dc_daycount_info` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `sid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '供应商id',
  `land_id` int(10) NOT NULL DEFAULT '0' COMMENT '景区id',
  `num` smallint(5) NOT NULL DEFAULT '0' COMMENT '单次出入园数量',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `device_key` varchar(32) NOT NULL DEFAULT '' COMMENT '闸机特征码',
  `roll` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0 入园 1 离园',
  `all_num` int(10) NOT NULL DEFAULT '0' COMMENT '当前的出入园总量',
  PRIMARY KEY (`id`),
  KEY `idx_create_time` (`create_time`) USING BTREE,
  KEY `idx_sid_create_time` (`sid`,`create_time`) USING BTREE,
  KEY `idx_devicekey_roll_createtime_num` (`device_key`,`roll`,`create_time`,`num`),
  KEY `idx_lid_roll_time` (`land_id`,`roll`,`create_time`)
) ENGINE=InnoDB AUTO_INCREMENT=764280015 DEFAULT CHARSET=utf8 COMMENT='景区出入园详细记录表';

-- @table RDS_summary:pft_dc_daycount_info_history
-- @at 2026-11-27 15:59:07
CREATE TABLE `pft_dc_daycount_info_history` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `sid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '供应商id',
  `land_id` int(10) NOT NULL DEFAULT '0' COMMENT '景区id',
  `num` smallint(5) NOT NULL DEFAULT '0' COMMENT '单次出入园数量',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `device_key` varchar(32) NOT NULL DEFAULT '' COMMENT '闸机特征码',
  `roll` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0 入园 1 离园',
  `all_num` int(10) NOT NULL DEFAULT '0' COMMENT '当前的出入园总量',
  PRIMARY KEY (`id`),
  KEY `idx_land_id` (`land_id`) USING BTREE,
  KEY `idx_create_time` (`create_time`) USING BTREE,
  KEY `idx_device_key` (`device_key`) USING BTREE,
  KEY `idx_sid_create_time` (`sid`,`create_time`) USING BTREE,
  KEY `idx_devicekey_roll_createtime_num` (`device_key`,`roll`,`create_time`,`num`)
) ENGINE=InnoDB AUTO_INCREMENT=750028910 DEFAULT CHARSET=utf8 COMMENT='景区出入园详细记录表';

-- @table RDS_summary:pft_dc_daycount_two
-- @at 2026-11-27 15:59:19
CREATE TABLE `pft_dc_daycount_two` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `sid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '供应商id',
  `land_id` int(10) unsigned NOT NULL COMMENT '景区ID',
  `num` mediumint(6) unsigned NOT NULL COMMENT '出入园人数',
  `roll` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0 入园 1 离园',
  `device_key` varchar(32) NOT NULL DEFAULT '' COMMENT '闸机特征码',
  `createtime` int(10) NOT NULL COMMENT '开始时间',
  `updatetime` int(10) NOT NULL COMMENT '更新时间',
  `date` int(8) NOT NULL COMMENT '日期',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_date` (`date`) USING BTREE,
  KEY `idx_device_date` (`device_key`,`date`),
  KEY `idx_landid_date_roll_num` (`land_id`,`date`,`roll`,`num`),
  KEY `idx_sid_date` (`sid`,`date`)
) ENGINE=InnoDB AUTO_INCREMENT=3427717 DEFAULT CHARSET=utf8 COMMENT='景区出入园人数统计';

-- @table RDS_summary:pft_report_annual_card_checked
-- @at 2026-11-27 15:57:08
CREATE TABLE `pft_report_annual_card_checked` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `date` int(10) unsigned NOT NULL COMMENT '日期 20171010',
  `fid` int(10) unsigned NOT NULL COMMENT '用户ID',
  `reseller_id` int(10) unsigned NOT NULL COMMENT '分销商ID',
  `lid` int(10) unsigned NOT NULL COMMENT '景区ID',
  `tid` int(10) unsigned NOT NULL COMMENT '票ID',
  `pid` int(10) unsigned NOT NULL COMMENT '产品ID',
  `card_tid` int(10) unsigned NOT NULL COMMENT '年卡票ID',
  `card_pid` int(10) unsigned NOT NULL COMMENT '年卡产品ID',
  `level` tinyint(3) NOT NULL COMMENT '分销链层级',
  `operate_id` int(10) unsigned NOT NULL COMMENT '操作人ID',
  `order_num` int(10) unsigned NOT NULL COMMENT '验证订单数',
  `order_ticket` int(10) unsigned NOT NULL COMMENT '验证门票数',
  `cost_money` int(10) unsigned NOT NULL COMMENT '验证花费金额',
  `sale_money` int(10) unsigned NOT NULL COMMENT '验证金额',
  `orders_info` text COMMENT '订单信息',
  `channel` tinyint(3) unsigned NOT NULL COMMENT '销售渠道',
  `update_time` int(10) unsigned NOT NULL COMMENT '更新时间',
  `site_id` int(10) unsigned NOT NULL COMMENT '站点ID',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `index_date` (`date`) USING BTREE,
  KEY `index_fid` (`fid`) USING BTREE,
  KEY `index_reseller_id` (`reseller_id`) USING BTREE,
  KEY `index_lid` (`lid`) USING BTREE,
  KEY `index_tid` (`tid`) USING BTREE,
  KEY `index_pid` (`pid`) USING BTREE,
  KEY `index_operate_id` (`operate_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=88544595 DEFAULT CHARSET=utf8 COMMENT='年卡验证报表，使用年卡进行消费的报表数据';

-- @table RDS_summary:pft_report_annual_card_order
-- @at 2026-11-27 15:57:22
CREATE TABLE `pft_report_annual_card_order` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `date` int(10) unsigned NOT NULL COMMENT '日期 20171010',
  `fid` int(10) unsigned NOT NULL COMMENT '用户ID',
  `reseller_id` int(10) unsigned NOT NULL COMMENT '分销商ID',
  `lid` int(10) unsigned NOT NULL COMMENT '景区ID',
  `tid` int(10) unsigned NOT NULL COMMENT '年卡票ID',
  `pid` int(10) unsigned NOT NULL COMMENT '年卡产品ID',
  `level` tinyint(3) NOT NULL COMMENT '分销链层级',
  `operate_id` int(10) unsigned NOT NULL COMMENT '操作人ID',
  `order_num` int(10) unsigned NOT NULL COMMENT '预订订单数',
  `order_ticket` int(10) unsigned NOT NULL COMMENT '预订门票数',
  `cost_money` int(10) unsigned NOT NULL COMMENT '预订花费金额',
  `sale_money` int(10) unsigned NOT NULL COMMENT '预定金额',
  `orders_info` text COMMENT '订单信息',
  `trade_type` tinyint(1) unsigned NOT NULL COMMENT '年卡交易类型 0=售卡 1=续费 2=补卡 3=取消 4=激活',
  `pay_way` tinyint(3) unsigned NOT NULL COMMENT '支付方式',
  `channel` tinyint(3) unsigned NOT NULL COMMENT '销售渠道',
  `update_time` int(10) unsigned NOT NULL COMMENT '更新时间',
  `site_id` int(10) unsigned NOT NULL COMMENT '站点ID',
  `cancel_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '取消订单数量',
  `cancel_ticket` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '取消门票数',
  `cancel_sale_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '取消金额',
  `cancel_orders_info` text COMMENT '取消订单信息',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `index_date` (`date`) USING BTREE,
  KEY `index_fid` (`fid`) USING BTREE,
  KEY `index_reseller_id` (`reseller_id`) USING BTREE,
  KEY `index_lid` (`lid`) USING BTREE,
  KEY `index_tid` (`tid`) USING BTREE,
  KEY `index_pid` (`pid`) USING BTREE,
  KEY `index_operate_id` (`operate_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=12086662 DEFAULT CHARSET=utf8 COMMENT='年卡预订报表, 记录年卡售卡、续费、补卡、取消、激活操作时的报表数据';

-- @table RDS_summary:pft_report_checked_two
-- @at 2026-11-27 15:57:34
CREATE TABLE `pft_report_checked_two` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `date` int(10) unsigned NOT NULL COMMENT '日期 20171010',
  `fid` int(10) unsigned NOT NULL COMMENT '用户ID',
  `reseller_id` int(10) unsigned NOT NULL COMMENT '分销商ID',
  `lid` int(10) unsigned NOT NULL COMMENT '景区ID',
  `tid` int(10) unsigned NOT NULL COMMENT '门票ID',
  `pid` int(10) unsigned NOT NULL COMMENT '产品ID',
  `level` tinyint(3) NOT NULL COMMENT '分销链层级',
  `operate_id` int(10) unsigned NOT NULL COMMENT '操作人ID',
  `order_num` int(10) unsigned NOT NULL COMMENT '验证订单数',
  `order_ticket` int(10) unsigned NOT NULL COMMENT '验证门票数',
  `finish_num` int(10) unsigned NOT NULL COMMENT '完结订单数',
  `finish_ticket` int(10) unsigned NOT NULL COMMENT '完结门票数',
  `cost_money` int(10) unsigned NOT NULL COMMENT '预订花费金额',
  `sale_money` int(10) unsigned NOT NULL COMMENT '预定金额',
  `finish_cost_money` int(10) unsigned NOT NULL,
  `finish_sale_money` int(10) unsigned NOT NULL,
  `orders_info` longtext COMMENT '订单信息',
  `finish_orders_info` longtext COMMENT '取消订单信息',
  `pay_way` tinyint(3) unsigned NOT NULL COMMENT '支付方式',
  `channel` tinyint(3) unsigned NOT NULL COMMENT '销售渠道',
  `today_check` tinyint(1) NOT NULL COMMENT '是否当天验证 1 是 2 不是',
  `update_time` int(10) unsigned NOT NULL COMMENT '更新时间',
  `revoke_ticket` int(10) unsigned NOT NULL COMMENT '撤销门票数',
  `revoke_num` int(10) unsigned NOT NULL COMMENT '撤销订单数',
  `revoke_orders_info` longtext COMMENT '撤销订单信息',
  `revoke_cost_money` int(10) unsigned NOT NULL COMMENT '撤销花费金额',
  `revoke_sale_money` int(10) unsigned NOT NULL COMMENT '撤销金额',
  `site_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '站点ID',
  `service_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '退款服务费',
  `main_tid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '主订单tid',
  `sub_merchant_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '子商户id',
  `after_sale_ticket_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后数量',
  `after_sale_refund_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后退回金额',
  `after_sale_income_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后收入金额',
  `after_sale_info` longtext COMMENT '售后订单信息 0.订单号 1.售后数量 2.编号 3.退回金额 4.收入金额',
  `main_type` varchar(4) NOT NULL DEFAULT '' COMMENT '主订单产品类型',
  PRIMARY KEY (`id`),
  KEY `idx_date` (`date`),
  KEY `idx_fid_date` (`fid`,`date`),
  KEY `idx_smid_date` (`sub_merchant_id`,`date`),
  KEY `idx_date_level` (`date`,`level`),
  KEY `idx_fid_date_tid` (`fid`,`date`,`tid`)
) ENGINE=InnoDB AUTO_INCREMENT=1831719491 DEFAULT CHARSET=utf8;

-- @table RDS_summary:pft_report_checked_two_hour
-- @at 2026-11-27 15:57:44
CREATE TABLE `pft_report_checked_two_hour` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `date_hour` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '日期 2017101009',
  `fid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '用户ID',
  `reseller_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '分销商ID',
  `lid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '景区ID',
  `tid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '门票ID',
  `pid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '产品ID',
  `lvl` tinyint(3) NOT NULL DEFAULT '0' COMMENT '分销链层级',
  `operate_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '操作人ID',
  `order_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '验证订单数',
  `order_ticket` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '验证门票数',
  `finish_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '完结订单数',
  `finish_ticket` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '完结门票数',
  `cost_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '预订花费金额',
  `sale_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '预定金额',
  `finish_cost_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '完结订单花费金额',
  `finish_sale_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '完结订单预订金额',
  `orders_info` longtext COMMENT '订单信息',
  `finish_orders_info` longtext COMMENT '取消订单信息',
  `pay_way` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '支付方式',
  `channel` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '销售渠道',
  `today_check` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否当天验证 1 是 2 不是',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `revoke_ticket` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '撤销门票数',
  `revoke_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '撤销订单数',
  `revoke_orders_info` longtext COMMENT '撤销订单信息',
  `revoke_cost_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '撤销花费金额',
  `revoke_sale_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '撤销金额',
  `site_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '站点ID',
  `service_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '退款服务费',
  `main_tid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '主订单tid',
  `sub_merchant_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '子商户id',
  `after_sale_ticket_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后数量',
  `after_sale_refund_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后退回金额',
  `after_sale_income_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后收入金额',
  `after_sale_info` longtext COMMENT '售后订单信息0.订单号 1.售后数量 2.编号 3.退回金额 4.收入金额',
  `main_type` varchar(4) NOT NULL DEFAULT '' COMMENT '主订单产品类型',
  PRIMARY KEY (`id`),
  KEY `idx_date_hour` (`date_hour`),
  KEY `idx_fid_date` (`fid`,`date_hour`)
) ENGINE=InnoDB AUTO_INCREMENT=1602334004 DEFAULT CHARSET=utf8 COMMENT='验证报表 - 按小时汇总';

-- @table RDS_summary:pft_report_order_two
-- @at 2026-11-27 15:57:55
CREATE TABLE `pft_report_order_two` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `date` int(10) unsigned NOT NULL COMMENT '日期 20171010',
  `fid` int(10) unsigned NOT NULL COMMENT '用户ID',
  `reseller_id` int(10) unsigned NOT NULL COMMENT '分销商ID',
  `lid` int(10) unsigned NOT NULL COMMENT '景区ID',
  `tid` int(10) unsigned NOT NULL COMMENT '门票ID',
  `pid` int(10) unsigned NOT NULL COMMENT '产品ID',
  `level` tinyint(3) NOT NULL COMMENT '分销链层级',
  `operate_id` int(10) unsigned NOT NULL COMMENT '操作人ID',
  `order_num` int(10) unsigned NOT NULL COMMENT '预订订单数',
  `order_ticket` int(10) unsigned NOT NULL COMMENT '预订门票数',
  `cancel_num` int(10) unsigned NOT NULL COMMENT '取消订单数',
  `cancel_ticket` int(10) unsigned NOT NULL COMMENT '取消门票数',
  `revoke_num` int(10) unsigned NOT NULL COMMENT '撤销订单数',
  `revoke_ticket` int(10) unsigned NOT NULL COMMENT '撤销门票数',
  `cost_money` int(10) unsigned NOT NULL COMMENT '预订花费金额',
  `sale_money` int(10) unsigned NOT NULL COMMENT '预定金额',
  `cancel_cost_money` int(10) unsigned NOT NULL COMMENT '取消花费金额',
  `cancel_sale_money` int(10) unsigned NOT NULL COMMENT '取消金额',
  `revoke_cost_money` int(10) unsigned NOT NULL COMMENT '撤销花费金额',
  `revoke_sale_money` int(10) unsigned NOT NULL COMMENT '撤销金额',
  `service_money` int(10) unsigned NOT NULL COMMENT '退款服务费',
  `orders_info` longtext COMMENT '订单信息',
  `cancel_orders_info` longtext COMMENT '取消订单信息',
  `revoke_orders_info` longtext COMMENT '撤销订单信息',
  `pay_way` tinyint(3) unsigned NOT NULL COMMENT '支付方式',
  `channel` tinyint(3) unsigned NOT NULL COMMENT '销售渠道',
  `update_time` int(10) unsigned NOT NULL COMMENT '更新时间',
  `site_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '站点ID',
  `print_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '取票数量',
  `print_orders_info` text COMMENT '取票订单信息',
  `main_tid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '主订单tid',
  `sub_merchant_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '子商户id',
  `main_type` varchar(4) NOT NULL DEFAULT '' COMMENT '主订单产品类型',
  `after_sale_ticket_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后数量',
  `after_sale_refund_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后退回金额',
  `after_sale_income_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后收入金额',
  `after_sale_info` longtext COMMENT '售后订单信息 0.订单号 1.售后数量 2.编号 3.退回单价 4.收入单价',
  PRIMARY KEY (`id`),
  KEY `index_date` (`date`),
  KEY `idx_fid_date` (`fid`,`date`),
  KEY `idx_smid_date` (`sub_merchant_id`,`date`),
  KEY `idx_fid_lid_main_date` (`fid`,`lid`,`main_tid`,`date`)
) ENGINE=InnoDB AUTO_INCREMENT=2719392173 DEFAULT CHARSET=utf8;

-- @table RDS_summary:pft_report_order_two_hour
-- @at 2026-11-27 15:58:05
CREATE TABLE `pft_report_order_two_hour` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `date_hour` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '日期 2017101001',
  `fid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '用户ID',
  `reseller_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '分销商ID',
  `lid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '景区ID',
  `tid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '门票ID',
  `pid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '产品ID',
  `lvl` tinyint(3) NOT NULL DEFAULT '0' COMMENT '分销链层级',
  `operate_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '操作人ID',
  `order_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '预订订单数',
  `order_ticket` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '预订门票数',
  `cancel_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '取消订单数',
  `cancel_ticket` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '取消门票数',
  `revoke_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '撤销订单数',
  `revoke_ticket` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '撤销门票数',
  `cost_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '预订花费金额',
  `sale_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '预定金额',
  `cancel_cost_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '取消花费金额',
  `cancel_sale_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '取消金额',
  `revoke_cost_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '撤销花费金额',
  `revoke_sale_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '撤销金额',
  `service_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '退款服务费',
  `orders_info` longtext COMMENT '订单信息',
  `cancel_orders_info` longtext COMMENT '取消订单信息',
  `revoke_orders_info` longtext COMMENT '撤销订单信息',
  `pay_way` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '支付方式',
  `channel` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '销售渠道',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `site_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '站点ID',
  `print_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '取票数量',
  `print_orders_info` text COMMENT '取票订单信息',
  `main_tid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '主订单tid',
  `sub_merchant_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '子商户id',
  `main_type` varchar(4) NOT NULL DEFAULT '' COMMENT '主订单产品类型',
  `after_sale_ticket_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后数量',
  `after_sale_refund_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后退回金额',
  `after_sale_income_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '售后收入金额',
  `after_sale_info` longtext COMMENT '售后订单信息 0.订单号 1.售后数量 2.编号 3.退回单价 4.收入单价',
  PRIMARY KEY (`id`),
  KEY `idx_fid_date_hour` (`fid`,`date_hour`),
  KEY `idx_date_hour` (`date_hour`)
) ENGINE=InnoDB AUTO_INCREMENT=2420248602 DEFAULT CHARSET=utf8 COMMENT='预订报表 - 按小时汇总';

-- @table RDS_summary:pft_report_terminal_pass
-- @at 2026-11-27 15:58:17
CREATE TABLE `pft_report_terminal_pass` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '会员ID',
  `date` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '具体哪一天 - 20160123',
  `lid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '景区ID',
  `tid` int(10) NOT NULL DEFAULT '0' COMMENT '门票ID',
  `pid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '产品ID',
  `level` tinyint(3) NOT NULL DEFAULT '1' COMMENT '分销链层级',
  `operate_id` int(10) NOT NULL DEFAULT '0' COMMENT '操作人员ID',
  `reseller_id` int(10) NOT NULL DEFAULT '0' COMMENT '分销商ID',
  `card_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '卡类型，1=员工卡，2=市民卡，3=年卡，4=一卡通',
  `card_pid` int(10) NOT NULL DEFAULT '0' COMMENT '卡明细（目前只有年卡有，就是具体的卡套餐）',
  `channel` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '销售渠道',
  `terminal_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '终端类型，云票务、手持机、MINI检票机、闸机、PC平台、小程序',
  `order_num` int(10) NOT NULL DEFAULT '0' COMMENT '验证订单数',
  `ticket_num` int(10) NOT NULL DEFAULT '0' COMMENT '验证门票数',
  `cost_money` int(10) NOT NULL DEFAULT '0' COMMENT '验证花费金额',
  `sale_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '验证金额',
  `orders_info` text COMMENT '订单信息',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间s',
  `site_id` int(10) NOT NULL DEFAULT '0' COMMENT '站点ID',
  `ext_content` text COMMENT '扩展信息',
  PRIMARY KEY (`id`),
  KEY `idx_date` (`date`) USING BTREE,
  KEY `idx_card_pid` (`card_pid`) USING BTREE,
  KEY `idx_fid_date` (`fid`,`date`),
  KEY `idx_opid_date` (`operate_id`,`date`)
) ENGINE=InnoDB AUTO_INCREMENT=1883204791 DEFAULT CHARSET=utf8;

-- @table RDS_summary:pft_report_terminal_pass_hour
-- @at 2026-11-27 15:58:29
CREATE TABLE `pft_report_terminal_pass_hour` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '会员ID',
  `date_hour` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '小时段2016012301',
  `lid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '景区ID',
  `tid` int(10) NOT NULL DEFAULT '0' COMMENT '门票ID',
  `pid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '产品ID',
  `lvl` tinyint(3) NOT NULL DEFAULT '1' COMMENT '分销链层级',
  `operate_id` int(10) NOT NULL DEFAULT '0' COMMENT '操作人员ID',
  `reseller_id` int(10) NOT NULL DEFAULT '0' COMMENT '分销商ID',
  `card_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '卡类型，1=员工卡，2=市民卡，3=年卡，4=一卡通',
  `card_pid` int(10) NOT NULL DEFAULT '0' COMMENT '卡明细（目前只有年卡有，就是具体的卡套餐）',
  `channel` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '销售渠道',
  `terminal_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '终端类型，云票务、手持机、MINI检票机、闸机、PC平台、小程序',
  `order_num` int(10) NOT NULL DEFAULT '0' COMMENT '验证订单数',
  `ticket_num` int(10) NOT NULL DEFAULT '0' COMMENT '验证门票数',
  `cost_money` int(10) NOT NULL DEFAULT '0' COMMENT '验证花费金额',
  `sale_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '验证金额',
  `orders_info` text COMMENT '订单信息',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间s',
  `site_id` int(10) NOT NULL DEFAULT '0' COMMENT '站点ID',
  `ext_content` text COMMENT '扩展信息',
  PRIMARY KEY (`id`),
  KEY `idx_fid` (`fid`) USING BTREE,
  KEY `idx_lid` (`lid`) USING BTREE,
  KEY `idx_tid` (`tid`) USING BTREE,
  KEY `idx_date_hour` (`date_hour`) USING BTREE,
  KEY `idx_operate_id` (`operate_id`) USING BTREE,
  KEY `idx_reseller_id` (`reseller_id`),
  KEY `idx_card_pid` (`card_pid`) USING BTREE,
  KEY `idx_pid` (`pid`) USING BTREE,
  KEY `idx_fid_hour` (`fid`,`date_hour`)
) ENGINE=InnoDB AUTO_INCREMENT=1451482132 DEFAULT CHARSET=utf8 COMMENT='终端过闸汇总小时报表';

-- @table RDS_summary:terminal_branch_summary
-- @at 2026-11-27 15:58:45
-- @cmt id 主键ID
CREATE TABLE `terminal_branch_summary` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `fid` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '用户ID',
  `operate_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '操作员工ID',
  `date` int(9) NOT NULL DEFAULT '0' COMMENT '日期20190410',
  `lid` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '景区ID',
  `tid` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '门票ID',
  `terminal` mediumint(8) unsigned NOT NULL DEFAULT '0' COMMENT '终端ID',
  `check_orders` mediumint(8) unsigned NOT NULL DEFAULT '0' COMMENT '验证订单数',
  `check_tickets` mediumint(8) unsigned NOT NULL DEFAULT '0' COMMENT '验证票数',
  `orders_info` text COMMENT '订单信息',
  `check_people` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '验证人次',
  `source` tinyint(3) NOT NULL DEFAULT '-1' COMMENT 'pft_order_track 的source',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间戳',
  PRIMARY KEY (`id`),
  KEY `idx_day` (`date`) USING BTREE,
  KEY `idx_lid_date` (`lid`,`date`) USING BTREE,
  KEY `idx_fid_date` (`fid`,`date`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=178171535 DEFAULT CHARSET=utf8 COMMENT='分终端汇总表';

-- @table ecs_pft001:excel_task
-- @at 2026-11-27 11:32:49
CREATE TABLE `excel_task` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `fid` int(11) NOT NULL DEFAULT '0' COMMENT '用户ID',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '操作人id',
  `request` text NOT NULL COMMENT '生产报表json参数',
  `hash` char(32) NOT NULL DEFAULT '0' COMMENT '生产报表json参数hash值',
  `send` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否发送邮件：1=不发，2=发',
  `email` varchar(20) DEFAULT '0' COMMENT '邮箱',
  `del` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否删除：1=未删 ，2=已删',
  `create_time` int(11) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `done` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态：1=未生成，2=正在生成，3=已生成',
  `msg` varchar(255) DEFAULT '0' COMMENT '错误信息',
  `download` tinyint(3) NOT NULL DEFAULT '0' COMMENT '下载次数',
  `excel_type` tinyint(3) NOT NULL DEFAULT '0' COMMENT '类型：1=交易记录汇总报表，2=合作分销商，3=费用配置，4=预订报表详细信息，5=验证报表详细信息，6=取消报表详细信息，7=撤销撤改报表详细信息，8=应收应付报表详细信息，10=交易记录，9=完结报表详细信息，11=预订报表详细信息(new)，12=验证报表详细信息(new)，13=套票报表，14=订单查询，15=套票验证报表，16=订单日志查询，17=报团订单查询，18=报团验证报表查询',
  `memo` varchar(255) DEFAULT '0' COMMENT '备注',
  `application_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '应用程序类型： 1=旧程序，2=新程序',
  `encrypt_id` varchar(100) NOT NULL DEFAULT '' COMMENT '加密id',
  `first_head` varchar(255) NOT NULL DEFAULT '' COMMENT '头部大标题',
  `self_defined_structure` varchar(5120) NOT NULL DEFAULT '' COMMENT '自定义数据',
  `file_name` varchar(255) NOT NULL DEFAULT '' COMMENT '自定义文件名',
  `page_count` int(11) NOT NULL DEFAULT '0' COMMENT '总页数',
  `template_code` varchar(100) NOT NULL DEFAULT '' COMMENT '模板编码',
  `ext` varchar(2000) NOT NULL DEFAULT '{}' COMMENT '扩展字段（JSON）',
  PRIMARY KEY (`id`),
  KEY `index_excel_hash` (`hash`),
  KEY `index_excel_time` (`create_time`),
  KEY `idx_fid_mid` (`fid`,`member_id`),
  KEY `idx_fid_del` (`fid`,`del`)
) ENGINE=InnoDB AUTO_INCREMENT=2031622 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='报表异步任务表';

-- @table ecs_pft001:pft_authority_role_member_relation
-- @at 2026-11-27 11:33:01
CREATE TABLE `pft_authority_role_member_relation` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `role_id` int(10) unsigned NOT NULL COMMENT '角色ID',
  `member_id` int(10) unsigned NOT NULL COMMENT '用户ID',
  `is_deleted` tinyint(3) unsigned NOT NULL,
  `create_time` int(10) unsigned NOT NULL COMMENT '创建时间',
  `update_time` int(10) unsigned NOT NULL COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_role` (`role_id`),
  KEY `idx_member` (`member_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1094014 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='角色员工关联表';

-- @table ecs_pft001:pft_authority_role_menu_relation
-- @at 2026-11-27 11:37:56
CREATE TABLE `pft_authority_role_menu_relation` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `role_id` int(10) unsigned NOT NULL COMMENT '角色ID',
  `menu_id` int(10) unsigned NOT NULL COMMENT '菜单ID',
  `menu_tag` varchar(255) NOT NULL COMMENT '菜单值',
  `expire_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '过期时间，应用中心模块',
  `begin_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '过期时间，应用中心模块',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `is_deleted` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '状态 0=正常 1=已删除',
  PRIMARY KEY (`id`),
  KEY `idx_tag` (`menu_tag`),
  KEY `idx_roleid` (`role_id`),
  KEY `idx_menuid` (`menu_id`)
) ENGINE=InnoDB AUTO_INCREMENT=35728201 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='角色菜单关联表';

-- @table ecs_pft001:pft_cooperation_other
-- @at 2026-11-27 11:38:15
CREATE TABLE `pft_cooperation_other` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `member_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '申请人ID',
  `cooperat_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '合作类型：1硬件 2软件 3其他',
  `cooperat_money` int(11) NOT NULL DEFAULT '0' COMMENT '合作金额 单位分',
  `cooperat_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '合作日期',
  `repayment_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '回款日期',
  `sales_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '签单人id',
  `remark` varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `is_delete` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除 1是0不是',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=952 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='其他合作(签单人员配置)';

-- @table ecs_pft001:pft_invoice_records
-- @at 2026-11-27 11:38:27
CREATE TABLE `pft_invoice_records` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `member_id` int(10) NOT NULL DEFAULT '0' COMMENT '用户ID',
  `ordernum` varchar(20) NOT NULL DEFAULT '' COMMENT '订单号',
  `out_trade_no` varchar(20) NOT NULL DEFAULT '' COMMENT '订单流水号',
  `serial_num` varchar(20) NOT NULL DEFAULT '' COMMENT '该订单在诺诺网的流水号',
  `ordertel` varchar(20) NOT NULL DEFAULT '' COMMENT '取票人电话',
  `personid` char(18) NOT NULL DEFAULT '' COMMENT '身份证',
  `enterprise_name` varchar(255) NOT NULL DEFAULT '' COMMENT '企业名称',
  `enterprise_code` varchar(10) NOT NULL DEFAULT '' COMMENT '企业开票六位码',
  `tariff_number` varchar(20) NOT NULL DEFAULT '' COMMENT '企业税号',
  `image_url` varchar(750) NOT NULL DEFAULT '' COMMENT '发票图片地址',
  `add_time` int(10) NOT NULL DEFAULT '0' COMMENT '开票时间',
  `operator_id` int(10) NOT NULL DEFAULT '0' COMMENT '操作员ID',
  `invoice_code` varchar(20) NOT NULL DEFAULT '' COMMENT '发票代码',
  `invoice_num` varchar(20) NOT NULL DEFAULT '' COMMENT '发票号码',
  `sys_id` tinyint(2) NOT NULL DEFAULT '1' COMMENT '对接系统id',
  `invoice_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0 增值税普通电子发票 1 增值税电子专用发票 3 增值税专用发票, 4 增值税普通发票',
  `records_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '开票类型 1普通开票 2合并开票 3被合并开票',
  `invoice_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '发票开票状态 0未开票 1进行中 2已开票',
  `order_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '订单类型 1普通订单 2旅游券订单',
  `invoice_state` int(11) NOT NULL DEFAULT '0' COMMENT '电子发票的开票状态 0未开票 1进行中 2已开票 3红冲中 4已红冲',
  `red_info` json NOT NULL COMMENT '发票红票信息',
  `original_order_info` json NOT NULL COMMENT '原始订单数据',
  `reason` varchar(255) NOT NULL DEFAULT '' COMMENT '开票失败原因',
  `is_complex` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '是否被合并订单无开票对象',
  `source` varchar(20) NOT NULL DEFAULT '' COMMENT '开票渠道',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_ordernum_ordertel_personid` (`ordernum`,`ordertel`,`personid`),
  KEY `idx_enterprise_code` (`enterprise_code`),
  KEY `idx_tariff_number` (`tariff_number`),
  KEY `idx_add_time` (`add_time`),
  KEY `idx_operator_id` (`operator_id`),
  KEY `idx_invoice_num` (`invoice_num`),
  KEY `idx_member_id` (`member_id`),
  KEY `idx_out_trade_no` (`out_trade_no`),
  KEY `idx_sys_state_records` (`sys_id`,`invoice_state`,`records_type`,`id`),
  KEY `idx_source_ordertel_id` (`source`,`ordertel`,`id`),
  KEY `idx_source_personid_id` (`source`,`personid`,`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1884725 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户开票记录';

-- @table ecs_pft001:pft_member_access_account
-- @at 2026-11-27 11:38:42
CREATE TABLE `pft_member_access_account` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sid` int(10) NOT NULL COMMENT '账号sid',
  `account` varchar(32) DEFAULT NULL,
  `app_id` smallint(4) NOT NULL COMMENT '应用ID',
  `dname` varchar(40) NOT NULL COMMENT '账户名',
  `settime` int(10) NOT NULL COMMENT '设置时间',
  `operate_id` int(10) NOT NULL DEFAULT '0' COMMENT '操作员id',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16923 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='应用权限开通-用户表';

-- @table ecs_pft001:pft_member_product_config
-- @at 2026-11-27 11:41:27
CREATE TABLE `pft_member_product_config` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `fid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '供应商ID',
  `product_type` varchar(4) NOT NULL DEFAULT '0' COMMENT '产品类型',
  `package_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '套餐id, 当前配置生效的套餐',
  `begin_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开始时间',
  `expire_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '结束时间',
  `open_status` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '开通状态 1=已开通 2=已关闭',
  `is_deleted` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否删除状态 0=未删除 1=已删除',
  `remark` varchar(255) NOT NULL DEFAULT ' ' COMMENT '备注',
  `amount` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '协议金额，单位分',
  `operate_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '操作人员id',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_fid` (`fid`)
) ENGINE=InnoDB AUTO_INCREMENT=12505 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='管理员配置的商户可发布的产品类型。(管理员有单独配置的才会记录，否则以商户购买的套餐中的产品类型为准)';

-- @table ecs_pft001:pft_merchant_alipay
-- @at 2026-11-27 11:41:40
CREATE TABLE `pft_merchant_alipay` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `memberid` int(10) NOT NULL COMMENT '票付通供应商ID',
  `name` varchar(100) NOT NULL COMMENT '商户名称',
  `appid` varchar(32) NOT NULL COMMENT '服务商appid',
  `app_auth_token` varchar(64) NOT NULL COMMENT '商户授权令牌',
  `app_refresh_token` varchar(64) NOT NULL COMMENT '刷新令牌时使用',
  `expires_in` int(10) NOT NULL COMMENT '令牌有效期',
  `re_expires_in` int(10) NOT NULL COMMENT '刷新令牌有效期',
  `user_id` varchar(32) NOT NULL COMMENT '授权商户的ID',
  `created_at` int(10) NOT NULL DEFAULT '0' COMMENT '授权日期',
  `master_pid` varchar(32) NOT NULL DEFAULT '2088021989927151',
  `sub_appid` varchar(32) NOT NULL COMMENT '授权应用appid',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=428 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='支付宝服务商配置表';

-- @table ecs_pft001:pft_merchant_payment_method
-- @at 2026-11-27 11:41:52
CREATE TABLE `pft_merchant_payment_method` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `member_id` int(11) NOT NULL COMMENT '供应商id',
  `channel_id` varchar(10) NOT NULL COMMENT '收款方式ID',
  `channel_name` varchar(255) NOT NULL COMMENT '收款方式名称',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=105 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='商家独立收款配置列表';

-- @table ecs_pft001:pft_merchant_wepay
-- @at 2026-11-27 11:42:03
CREATE TABLE `pft_merchant_wepay` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `memberid` int(10) NOT NULL COMMENT '票付通供应商ID',
  `name` varchar(100) NOT NULL COMMENT '商户名称',
  `appid` varchar(32) NOT NULL COMMENT '服务商appid',
  `merchant_id` varchar(32) NOT NULL COMMENT '商户ID（支付宝partner_id）',
  `sub_appid` varchar(32) NOT NULL COMMENT '子商户appid',
  `sub_merchant_id` varchar(32) NOT NULL COMMENT '子商户ID',
  `app_key` varchar(32) NOT NULL COMMENT '接口密钥',
  `sslcert_path` text NOT NULL COMMENT '证书pem格式路径',
  `sslkey_path` text NOT NULL COMMENT '证书密钥pem格式证书路径',
  `use_env` tinyint(1) NOT NULL DEFAULT '0' COMMENT '使用环境,0:线下，1:线上，2：线上+线下, 3小程序',
  `status` tinyint(4) NOT NULL DEFAULT '1' COMMENT '是否独立收款，默认1开启，0不开启',
  `create_time` int(11) NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `memberid_index` (`memberid`),
  KEY `sub_appid` (`sub_appid`)
) ENGINE=InnoDB AUTO_INCREMENT=748 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='微信支付服务商配置表';

-- @table ecs_pft001:pft_module
-- @at 2026-11-27 11:42:18
CREATE TABLE `pft_module` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '模块ID',
  `name` varchar(25) NOT NULL DEFAULT '' COMMENT '模块名称',
  `category` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '所属的分类 1=直销 2=营销 3=对接 4=一卡通 5=票务系统 6=智能终端 7=其他， 废弃',
  `is_free` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否免费， 0=非免费 1=免费',
  `icon` varchar(100) NOT NULL DEFAULT '' COMMENT '模块icon地址',
  `free_day` smallint(4) unsigned NOT NULL DEFAULT '0' COMMENT '模块的免费天数 0=不免费',
  `summary` varchar(255) NOT NULL DEFAULT '' COMMENT '简介',
  `open_num` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开通用户数',
  `charge_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '开始收费日期',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `online_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '上线时间，0=还没有上线',
  `status` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '状态 0=下架，1=上架',
  `guide` varchar(10000) NOT NULL DEFAULT '' COMMENT '指南',
  `is_sync_java` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否同步该模块的信息给java（会员体系用到）0-不同步 1-同步会员中心 2-xxxx',
  `is_admin_visible` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否管理员可见 0全部可见 1-管理员可见',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=354 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='应用中心基础功能模块';

-- @table ecs_pft001:pft_module_package
-- @at 2026-11-27 11:45:03
CREATE TABLE `pft_module_package` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '套餐ID',
  `name` varchar(25) NOT NULL DEFAULT '' COMMENT '套餐名称',
  `summary` varchar(1000) NOT NULL DEFAULT '' COMMENT '套餐简介',
  `add_time` int(11) NOT NULL DEFAULT '0' COMMENT '套餐添加时间',
  `role` tinyint(1) NOT NULL DEFAULT '1' COMMENT '0 供应商 1 分销商',
  `admin_visible` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0:全部可见 1:仅后台可见的套餐',
  `fee` int(11) NOT NULL DEFAULT '0' COMMENT '费用 单位分',
  `unit` tinyint(1) NOT NULL DEFAULT '12' COMMENT '月份数',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1有效 2无效',
  `is_recommend` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否推荐 0=否 1=是',
  `rank` int(3) NOT NULL DEFAULT '0' COMMENT '权重越大越靠前，置顶999',
  `version` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '套餐版本号 1=原始版本 2=增加了产品类别的版本',
  `ext_config` json DEFAULT NULL COMMENT '套餐增值配置',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `upgrade` json DEFAULT NULL COMMENT '可升级的套餐',
  `apply_for` tinyint(4) NOT NULL DEFAULT '3' COMMENT '适用范围类型 1=景区 2=旅行社 3=其他',
  `ticket_attr_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '票属性限制配置id',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=343 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='应用中心模块套餐';

-- @table ecs_pft001:pft_module_package_classify
-- @at 2026-11-27 11:45:15
CREATE TABLE `pft_module_package_classify` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `classify_name` varchar(30) NOT NULL DEFAULT '' COMMENT '分类名称',
  `package_ids` varchar(1000) NOT NULL DEFAULT '' COMMENT '包含的套餐逗号隔开',
  `op_id` int(10) NOT NULL DEFAULT '0' COMMENT '最后操作人',
  `is_delete` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='套餐类型关联表-按套餐分类查询用';

-- @table ecs_pft001:pft_module_package_detail
-- @at 2026-11-27 11:45:29
CREATE TABLE `pft_module_package_detail` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `package_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '套餐ID',
  `module_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '模块ID',
  `add_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_package_id` (`package_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4941 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='套餐包含模块表';

-- @table ecs_pft001:pft_module_package_log
-- @at 2026-11-27 11:45:41
CREATE TABLE `pft_module_package_log` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `member_id` int(10) DEFAULT '0' COMMENT '用户ID',
  `package_id` int(10) DEFAULT '0' COMMENT '套餐ID',
  `out_trade_no` varchar(64) DEFAULT '0' COMMENT '外部交易流水ID',
  `remarks` varchar(255) DEFAULT '' COMMENT '备注',
  `is_update` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否是升级 0不是 1是',
  `add_time` int(10) DEFAULT '0' COMMENT '添加时间',
  `begin_time` int(11) NOT NULL DEFAULT '0' COMMENT '开始时间',
  `end_time` int(11) NOT NULL DEFAULT '0' COMMENT '结束时间',
  `is_ignore` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否忽略过期提示 0 -不忽略 1-忽略',
  `saleman` int(10) NOT NULL DEFAULT '0' COMMENT '签单人',
  `customer_service` int(10) NOT NULL DEFAULT '0' COMMENT '客服',
  `is_pay` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否回款 0-未回款 1回款',
  `details` varchar(255) NOT NULL DEFAULT '' COMMENT '存一些金额信息',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `member_id` (`member_id`),
  KEY `out_trade_no` (`out_trade_no`),
  KEY `begin_time` (`begin_time`),
  KEY `end_time` (`end_time`),
  KEY `idx_package` (`package_id`),
  KEY `idx_add_time` (`add_time`)
) ENGINE=InnoDB AUTO_INCREMENT=1093169 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户开通套餐情况';

-- @table ecs_pft001:pft_module_package_log_ext
-- @at 2026-11-27 11:45:52
CREATE TABLE `pft_module_package_log_ext` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `package_log_id` int(10) NOT NULL DEFAULT '0' COMMENT '套餐开通日志id',
  `stop_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '终止类型：1作废, 2提前终止',
  `time_details` varchar(255) NOT NULL DEFAULT '' COMMENT '终止相关时间记录',
  `contract_no` varchar(255) NOT NULL DEFAULT '' COMMENT '合同编号',
  `sign_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '签约时间',
  `repayment_record` varchar(1500) NOT NULL DEFAULT '' COMMENT '回款记录',
  `cooperation_mode` tinyint(1) NOT NULL DEFAULT '0' COMMENT '合作模式: 1套餐, 2项目, 3订单预存',
  `open_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '开通类型: 1.新开通，2.未到期套餐升级，3.通用转付费，4.分销商转供应商， 5.流失召回， 6.平级续费，7.升级续费， 8.降级续费，9.预存转付费，10.付费转预存, 11.供应商转分销商，12.试用，13.通用版，14.赠送，15.赔付，16.临时延期，17.测试',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_package_log_id` (`package_log_id`)
) ENGINE=InnoDB AUTO_INCREMENT=456803 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户开通套餐情况扩展表';

-- @table ecs_pft001:pft_module_price
-- @at 2026-11-27 11:47:56
CREATE TABLE `pft_module_price` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '资费配置ID',
  `name` varchar(50) NOT NULL DEFAULT '' COMMENT '资费名称',
  `target_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '功能模块ID/套餐ID',
  `begin_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '配置开始时间',
  `end_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '配置结束时间',
  `type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '类型 1=功能模块 2=套餐ID',
  `mode` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '模式 1=年，2=季度，3=月',
  `fee` int(8) unsigned NOT NULL DEFAULT '0' COMMENT '费用 - 分',
  `rank` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '排序值，越大排名越靠前',
  `is_hot` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否推荐 0=否 1=是',
  `add_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '记录添加时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '记录更新时间',
  `is_discount` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否优惠',
  `discount_price` int(10) NOT NULL DEFAULT '0' COMMENT '优惠价',
  `discount_begin_time` int(10) NOT NULL DEFAULT '0' COMMENT '优惠开始时间',
  `discount_end_time` int(10) NOT NULL DEFAULT '0' COMMENT '优惠结束时间',
  PRIMARY KEY (`id`),
  KEY `idx_begin_time_end_time` (`begin_time`,`end_time`),
  KEY `idx_target_id_type` (`target_id`,`type`)
) ENGINE=InnoDB AUTO_INCREMENT=969 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='功能模块价格配置';

-- @table ecs_pft001:pft_module_used
-- @at 2026-11-27 11:48:08
CREATE TABLE `pft_module_used` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `member_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开通用户ID',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '上级id',
  `module_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '功能模块ID',
  `use_free` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否免费试用过 0=不是，1=是',
  `begin_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '模块开始使用时间',
  `expire_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '模块到期时间',
  `status` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '状态  1=正常使用，2=过期',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `type` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '开通类型 0自开通 1管理员开通',
  `is_ignore` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否忽略过期提示 0 -不忽略 1-忽略',
  `is_history` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '是否历史数据，新数据member_id=sid',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_member_id_module_id` (`member_id`,`module_id`),
  KEY `idx_module_id_sid` (`module_id`,`sid`),
  KEY `idx_expire_time` (`expire_time`),
  KEY `idx_module_history_status_begin_expire` (`module_id`,`is_history`,`status`,`begin_time`,`expire_time`)
) ENGINE=InnoDB AUTO_INCREMENT=5477463 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户使用模块表';

-- @table ecs_pft001:pft_module_used_ext
-- @at 2026-11-27 11:48:17
CREATE TABLE `pft_module_used_ext` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `member_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '用户ID',
  `module_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '模块ID',
  `module_type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '类型 1=应用 2=应用组合',
  `out_trade_no` varchar(64) NOT NULL DEFAULT '' COMMENT '支付流水ID',
  `stop_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '终止类型：1作废, 2提前终止',
  `time_details` varchar(255) NOT NULL DEFAULT '' COMMENT '终止相关时间记录',
  `contract_no` varchar(255) NOT NULL DEFAULT '' COMMENT '合同编号',
  `sign_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '签约时间',
  `saleman` int(10) NOT NULL DEFAULT '0' COMMENT '签单人',
  `details` varchar(255) NOT NULL DEFAULT '' COMMENT '存一些金额信息(发票金额、实收金额、业绩金额、实际消费金额)',
  `repayment_record` varchar(1500) NOT NULL DEFAULT '' COMMENT '回款记录',
  `sign_remark` varchar(255) NOT NULL DEFAULT '' COMMENT '签单备注',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_member_id` (`member_id`),
  KEY `idx_module_id` (`module_id`),
  KEY `idx_outtradeno` (`out_trade_no`)
) ENGINE=InnoDB AUTO_INCREMENT=275243 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户使用应用扩展记录表';

-- @table ecs_pft001:pft_module_used_log
-- @at 2026-11-27 11:48:35
CREATE TABLE `pft_module_used_log` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '开通历史ID',
  `member_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '用户ID',
  `module_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '模块ID',
  `price_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '资费配置ID',
  `type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '开通的类型 1=模块 2=套餐',
  `out_trade_no` varchar(64) NOT NULL DEFAULT '' COMMENT '支付流水ID',
  `remarks` varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `add_time` int(11) unsigned NOT NULL DEFAULT '1' COMMENT '开通时间',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态 1未支付 2已支付 3支付失败 4免费试用 5员工权限开通 6管理员模块修改  7管理员关闭（套餐/模块） 8套餐开通或续费 9升级套餐 10特殊处理',
  PRIMARY KEY (`id`),
  KEY `member_id` (`member_id`),
  KEY `target_id` (`module_id`),
  KEY `price_id` (`price_id`),
  KEY `idx_out_trade_no` (`out_trade_no`)
) ENGINE=InnoDB AUTO_INCREMENT=1992050 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户开通功能模块历史表';

-- @table ecs_pft001:pft_package_product_config
-- @at 2026-11-27 11:48:45
CREATE TABLE `pft_package_product_config` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `package_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '套餐id',
  `product_type` varchar(4) NOT NULL DEFAULT '0' COMMENT '产品类型，与uu_land表p_type字段对应',
  `is_deleted` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '状态 0=正常 1=停用',
  `create_time` int(10) unsigned NOT NULL DEFAULT '1' COMMENT '创建时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '1' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2583 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='套餐包含的产品类型（允许发布的产品类型）';

-- @table ecs_pft001:pft_rebate
-- @at 2026-11-27 11:48:57
CREATE TABLE `pft_rebate` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sid` int(10) unsigned NOT NULL COMMENT '供应商id',
  `name` varchar(20) NOT NULL COMMENT '返利活动名称',
  `target` text NOT NULL COMMENT '返利对象',
  `cycle` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '1每日2每周3每月4每季度5每半年6每年',
  `paymode` varchar(20) NOT NULL DEFAULT '1' COMMENT '1余额支付2授信支付3现金',
  `deal_type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '1自动2人工',
  `account_type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '1余额2授信',
  `begin` int(10) unsigned NOT NULL COMMENT '开始时间',
  `end` int(10) unsigned NOT NULL COMMENT '结束时间',
  `status` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '状态',
  `money` varchar(200) NOT NULL COMMENT '阶梯返利',
  `money_type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '金额类型：0=帐号资金 1=支付宝 2=供应商处可用资金 3=供应商信用额度设置 4=财付通',
  `pid` varchar(1024) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_status` (`status`),
  KEY `idx_begin` (`begin`),
  KEY `idx_end` (`end`)
) ENGINE=InnoDB AUTO_INCREMENT=397 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='返利活动表';

-- @table ecs_pft001:pft_rebate_combine_log
-- @at 2026-11-27 11:49:08
CREATE TABLE `pft_rebate_combine_log` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sid` int(10) unsigned NOT NULL COMMENT '供应商id',
  `fid` int(10) unsigned NOT NULL COMMENT '分销商id',
  `rebate_date` int(10) unsigned NOT NULL COMMENT '返利日期',
  `money` int(10) unsigned NOT NULL COMMENT '预计返利金额',
  `final_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '实际返利金额',
  `order_begin` int(10) unsigned NOT NULL COMMENT '订单统计开始时间',
  `order_end` int(10) unsigned NOT NULL COMMENT '订单统计结束时间',
  `account_type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '1余额2授信',
  `deal_type` tinyint(2) unsigned NOT NULL DEFAULT '1' COMMENT '1自动2人工',
  `rebate_detail` text NOT NULL COMMENT '返利详情',
  `cycle` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '返利周期',
  `status` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '0未返利1已返利',
  `error` varchar(200) NOT NULL COMMENT '失败信息',
  `rebate_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '返利时间',
  `create_time` int(10) unsigned NOT NULL COMMENT '记录生成时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_uniq` (`sid`,`rebate_date`,`cycle`,`fid`),
  KEY `idx_fid` (`fid`),
  KEY `idx_rdate_cycle` (`rebate_date`,`cycle`)
) ENGINE=InnoDB AUTO_INCREMENT=1965 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='返利活动报表(多维度)';

-- @table ecs_pft001:pft_sms_diy_apply
-- @at 2026-11-27 11:49:43
CREATE TABLE `pft_sms_diy_apply` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '上级ID',
  `member_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '申请人ID',
  `content` varchar(255) NOT NULL DEFAULT '' COMMENT '模板内容',
  `p_type` varchar(32) NOT NULL DEFAULT '' COMMENT '产品类型 all表示全部',
  `state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '审核状态：1待审核 2已审核 3未通过',
  `use_state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '应用状态:1.启用 2禁用',
  `is_delete` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除 1是0不是',
  `is_system` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是系统模板 1是2不是',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `examine_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '审核时间',
  `title` varchar(100) NOT NULL DEFAULT '' COMMENT '模板名称',
  `use_scene` tinyint(3) NOT NULL DEFAULT '1' COMMENT '1=非期票下单 2=期票下单',
  `template_code` varchar(64) NOT NULL DEFAULT '' COMMENT '消息中心模板编码',
  PRIMARY KEY (`id`),
  KEY `idx_member_id` (`member_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2612 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='短信自定义模板申请表';

-- @table ecs_pft001:pft_sms_sign_apply
-- @at 2026-11-27 11:49:56
CREATE TABLE `pft_sms_sign_apply` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `sid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '上级ID',
  `member_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '申请人ID',
  `sign` varchar(32) NOT NULL DEFAULT '' COMMENT '抬头内容/抬头名',
  `state` tinyint(1) NOT NULL DEFAULT '1' COMMENT '审核状态：1待审核 2已审核 3未通过',
  `customer` varchar(255) NOT NULL DEFAULT '' COMMENT '企业名称',
  `trade` varchar(32) NOT NULL DEFAULT '' COMMENT '行业信息',
  `prove` varchar(1000) NOT NULL DEFAULT '' COMMENT '证明图片，逗号隔开',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  `examine_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '审核时间',
  `ext` json DEFAULT NULL COMMENT '扩展信息',
  PRIMARY KEY (`id`),
  KEY `idx_member_id` (`member_id`)
) ENGINE=InnoDB AUTO_INCREMENT=127 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='短信抬头申请表';

-- @table ecs_pft001:pft_staff
-- @at 2026-11-27 11:50:07
CREATE TABLE `pft_staff` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `st_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '类型 0是签单人员 1是客服 2:区域经理 3:部门经理 4:其它',
  `st_personid` int(11) NOT NULL DEFAULT '0' COMMENT 'ä¸ªäººID',
  `st_group` tinyint(4) NOT NULL DEFAULT '0' COMMENT 'ç»„åˆ«',
  `st_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0正常 1离职 2已删除',
  `st_name` varchar(50) NOT NULL DEFAULT '0' COMMENT 'å§“å',
  `st_memberid` int(11) NOT NULL DEFAULT '0' COMMENT 'å¯¹åº”pft_memberè¡¨çš„id',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=683 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- @table ecs_pft001:pft_wx_new_reseller
-- @at 2026-11-27 11:50:27
CREATE TABLE `pft_wx_new_reseller` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `memberid` int(10) unsigned NOT NULL,
  `openid` varchar(32) NOT NULL COMMENT '新注册分销商的openid',
  `appid` varchar(32) NOT NULL COMMENT '公众号的appid',
  `createtime` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_openid` (`openid`)
) ENGINE=InnoDB AUTO_INCREMENT=155038 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='微信注册分销商表';

-- @table ecs_pft002:pft_all_dis
-- @at 2026-11-27 11:51:30
CREATE TABLE `pft_all_dis` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `sid` int(11) NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT '0',
  `config` varchar(200) NOT NULL,
  `description` text NOT NULL COMMENT '营销说明',
  `close_pids` text NOT NULL COMMENT '关闭营销状态的产品集合',
  `commission_config` text NOT NULL COMMENT '自定义佣金的门票',
  `auto_issue` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否自动发放',
  `all_dis_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '全民营销类型：0逆推三级1正算三级',
  `join_config` json DEFAULT NULL COMMENT '操作内容',
  `customer_config` varchar(200) NOT NULL DEFAULT '' COMMENT '客户关系配置',
  `commission_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '佣金结算方式：0正算1倒推叠加',
  `invite_poster_config` json DEFAULT NULL COMMENT '营销员邀请下级海报配置{templateType: "1", //1默认模板 2自定义模板,\r\n        defaultTemplate: "1", // 1默认模板一 2默认模板二 3默认模板二\r\n        showShopName: "1", //店铺名称\r\n        showLogo: "1", //二维码LOGO\r\n        invitation: "#旅游神器#自己购买省钱，分享推荐赚钱", //邀请文案\r\n        customPosterImg: "", //自定义海报图片\r\n        qrcodeConfig: { //自定义模板二维码信息\r\n            x: 275, //距离左边的坐标\r\n            y: 0, //距离顶部的坐标\r\n            w: 100, //二维码宽度\r\n			h: 100 //二维码高度\r\n        }',
  `tax_withholding_config` json DEFAULT NULL COMMENT '个税缴纳配置',
  `flexible_config` json DEFAULT NULL COMMENT '灵工平台租户配置',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_status_auto_issue` (`status`,`auto_issue`)
) ENGINE=InnoDB AUTO_INCREMENT=31316 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='全民分销配置表';

-- @table ecs_pft002:pft_all_dis_orders
-- @at 2026-11-27 11:51:39
CREATE TABLE `pft_all_dis_orders` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `order_id` varchar(20) NOT NULL DEFAULT '' COMMENT '订单号',
  `member_id` int(11) NOT NULL,
  `sid` int(11) NOT NULL,
  `pid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '门票pid',
  `aid` int(11) NOT NULL DEFAULT '0' COMMENT '上级供应商id',
  `tnum` mediumint(9) NOT NULL DEFAULT '0' COMMENT '门票数',
  `parent_id` int(11) NOT NULL,
  `grand_id` int(11) NOT NULL,
  `total_money` int(11) NOT NULL,
  `develop_money` int(11) NOT NULL,
  `recommend_money` int(11) NOT NULL,
  `return_money` int(11) NOT NULL,
  `update_time` int(11) NOT NULL,
  `status` tinyint(1) NOT NULL,
  `order_status` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '订单状态',
  `order_pay_status` tinyint(1) unsigned NOT NULL DEFAULT '2' COMMENT '订单支付状态',
  `create_time` int(10) unsigned NOT NULL COMMENT '创建时间',
  `all_dis_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '全民营销类型：0逆推三级1正算三级',
  `dis_id` int(11) NOT NULL DEFAULT '0' COMMENT '一级分销员id',
  `remain_money` int(11) NOT NULL COMMENT '剩余商家金额',
  `money_config` varchar(20) NOT NULL DEFAULT '' COMMENT '佣金比例',
  `is_new` tinyint(1) NOT NULL DEFAULT '0' COMMENT '订单数据格式：0旧全民营销1新全民营销',
  `is_issue` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否自动发放：0否1是',
  `is_self` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否自购订单0否1是',
  `rec_id` int(11) NOT NULL DEFAULT '0' COMMENT '推荐关系id',
  `profit` int(11) NOT NULL DEFAULT '0' COMMENT '订单总利润',
  `commission_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '佣金结算方式：0正算1倒推叠加',
  `complete_time` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '发放时间',
  `is_tax_withholding` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否代缴个税 0否 1是',
  `last_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '上次发放结果 0待发放 1发放成功 2发放失败',
  `last_error_code` tinyint(4) NOT NULL DEFAULT '0' COMMENT '佣金发放失败码',
  `invoicing_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '开票状态 0待开票 1开票中 2开票成功',
  `develop_individual_income_tax` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '个人所得税',
  `develop_invoicing_service_fee` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开票服务费',
  `develop_pft_invoicing_service_fee` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开票服务费',
  `recommend_individual_income_tax` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '个人所得税',
  `recommend_invoicing_service_fee` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开票服务费',
  `recommend_pft_invoicing_service_fee` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开票服务费',
  `return_individual_income_tax` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '个人所得税',
  `return_invoicing_service_fee` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开票服务费',
  `return_pft_invoicing_service_fee` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开票服务费',
  `debug_flag` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '汇总数据用的标识',
  PRIMARY KEY (`id`),
  KEY `idx_orderid` (`order_id`),
  KEY `idx_memberid` (`member_id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_parentid` (`parent_id`),
  KEY `idx_grandid` (`grand_id`),
  KEY `idx_time` (`create_time`),
  KEY `idx_pid` (`pid`),
  KEY `idx_disid_sid_status_developmoney` (`dis_id`,`sid`,`status`,`develop_money`),
  KEY `idx_sid_status_alldistype_isnew_completetime_createtime` (`sid`,`status`,`all_dis_type`,`is_new`,`complete_time`,`create_time`),
  KEY `idx_sid_status_debug` (`sid`,`status`,`debug_flag`),
  KEY `idx_sid_alldistype_isnew_ctime` (`sid`,`all_dis_type`,`is_new`,`complete_time`,`create_time`,`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1257033 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='全民分销订单表';

-- @table ecs_pft002:pft_all_dis_recommend
-- @at 2026-11-27 11:52:03
CREATE TABLE `pft_all_dis_recommend` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `member_id` int(11) NOT NULL,
  `fid` int(11) NOT NULL,
  `grand_id` int(11) NOT NULL,
  `update_time` int(11) NOT NULL,
  `belong_id` int(11) NOT NULL,
  `all_dis_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '全民营销类型：0逆推三级1正算三级',
  `is_customer` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否为客户0否1是',
  `join_way` tinyint(1) NOT NULL DEFAULT '0' COMMENT '加入方式0：无1扫码2分销商导入',
  `level` tinyint(1) NOT NULL DEFAULT '0' COMMENT '分销员等级',
  `is_del` tinyint(1) NOT NULL DEFAULT '0' COMMENT '会否删除0否1是',
  `role_id` int(11) NOT NULL DEFAULT '0' COMMENT '角色id',
  `rec_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '关系状态:0正常1清退2待审核',
  `bind_time` int(11) NOT NULL DEFAULT '0' COMMENT '绑定时间',
  `create_time` int(11) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `unbind_time` int(11) NOT NULL DEFAULT '0' COMMENT '解绑时间',
  `certification_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '认证状态 0未认证 1已认证',
  `personal_certification_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'pft_invoice.pft_personal_certification.id',
  `migrate_status` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '迁移小程序状态0=待迁移 1=已迁移 2=迁移失败',
  `migrate_error_msg` varchar(255) NOT NULL DEFAULT '' COMMENT '迁移失败原因',
  PRIMARY KEY (`id`),
  KEY `idx` (`member_id`),
  KEY `idx_belong_id` (`belong_id`),
  KEY `idx_fid` (`fid`),
  KEY `idx_grand_id` (`grand_id`),
  KEY `idx_memberid_belongid_recstatus_iscustomer_isdel_level` (`member_id`,`belong_id`,`rec_status`,`is_customer`,`is_del`,`level`),
  KEY `idx_level_belong_fid` (`level`,`belong_id`,`fid`)
) ENGINE=InnoDB AUTO_INCREMENT=2937876 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='全民营销推荐关系表';

-- @table ecs_pft002:pft_coupon_use_log
-- @at 2026-11-27 11:52:22
CREATE TABLE `pft_coupon_use_log` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `fid` int(11) unsigned NOT NULL COMMENT '使用优惠券用户id',
  `aid` int(11) unsigned NOT NULL COMMENT '优惠券供应商id',
  `use_order_num` varchar(20) COLLATE utf8_bin NOT NULL COMMENT '使用了该优惠码的订单',
  `all_use_coupon_money` int(11) unsigned NOT NULL COMMENT '分配使用到的优惠券总金额',
  `use_time` int(10) unsigned NOT NULL COMMENT '使用时间',
  `status` tinyint(3) unsigned NOT NULL COMMENT '1:占用中，2:已使用, 3:已释放',
  `async_status` tinyint(3) unsigned NOT NULL COMMENT '1:未同步到pft_member_coupon 2:已同步',
  `coupon_code` varchar(100) COLLATE utf8_bin NOT NULL COMMENT '优惠券码，多个用逗号分隔',
  `tradeid` varchar(30) COLLATE utf8_bin NOT NULL COMMENT '支付订单号（合并付款订单号）',
  PRIMARY KEY (`id`),
  KEY `idx_fix` (`fid`),
  KEY `idx_status` (`status`),
  KEY `idx_tradeid` (`tradeid`),
  KEY `idx_use_order` (`use_order_num`),
  KEY `idx_status_asyncstatus_usetime` (`use_time`,`status`,`async_status`)
) ENGINE=InnoDB AUTO_INCREMENT=61042 DEFAULT CHARSET=utf8 COLLATE=utf8_bin ROW_FORMAT=DYNAMIC COMMENT='优惠券使用记录表';

-- @table ecs_pft002:pft_cut_price
-- @at 2026-11-27 11:53:33
CREATE TABLE `pft_cut_price` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `aid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '上级供应商id',
  `sid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '供应商id',
  `pid` mediumint(8) unsigned NOT NULL DEFAULT '0' COMMENT '门票pid',
  `begin` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开始时间',
  `end` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '结束时间',
  `poster_id` mediumint(8) unsigned NOT NULL DEFAULT '0' COMMENT '海报id',
  `quantity_sold` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '出售数量',
  `is_cycle` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否周期重复',
  `cycle_type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '周期重复类型1每日2每周3每月',
  `cycle_detail` varchar(1024) NOT NULL DEFAULT '' COMMENT '周期重复详情',
  `price` mediumint(8) unsigned NOT NULL DEFAULT '0' COMMENT '价格',
  `market_price` mediumint(8) unsigned NOT NULL DEFAULT '0' COMMENT '发布活动时的门市价',
  `storage` int(10) NOT NULL DEFAULT '0' COMMENT '库存',
  `storage_type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '1总库存2周期库存',
  `humor_talk` varchar(500) NOT NULL DEFAULT '[]' COMMENT '俏皮语',
  `cut_limit` int(10) NOT NULL DEFAULT '1' COMMENT '限制每人砍价次数',
  `min_cut_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '最低砍价金额',
  `max_cut_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '最高砍价金额',
  `status` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '0正常,1删除',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_pid` (`pid`),
  KEY `idx_end` (`end`)
) ENGINE=InnoDB AUTO_INCREMENT=1104 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='砍价活动表';

-- @table ecs_pft002:pft_cut_price_help
-- @at 2026-11-27 11:53:42
CREATE TABLE `pft_cut_price_help` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `mid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '砍价用户id',
  `join_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '发起砍价的记录id',
  `cut_money` mediumint(8) unsigned NOT NULL DEFAULT '0' COMMENT '砍价金额',
  `humor_talk` varchar(20) NOT NULL DEFAULT '' COMMENT '俏皮语',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '砍价时间',
  PRIMARY KEY (`id`),
  KEY `idx_mid` (`mid`),
  KEY `idx_joinid` (`join_id`)
) ENGINE=InnoDB AUTO_INCREMENT=464637 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='帮砍记录表';

-- @table ecs_pft002:pft_cut_price_join
-- @at 2026-11-27 11:53:54
CREATE TABLE `pft_cut_price_join` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `mid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '用户id',
  `aid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '上级供应商id',
  `sid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '微商城所有者id',
  `cut_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '砍价活动id',
  `cut_money` mediumint(8) unsigned NOT NULL DEFAULT '0' COMMENT '已砍金额',
  `cut_times` smallint(5) unsigned NOT NULL DEFAULT '0' COMMENT '砍价次数',
  `ordernum` varchar(20) NOT NULL DEFAULT '' COMMENT '订单号',
  `begin` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '周期开始时间',
  `end` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '周期结束时间',
  `status` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '0未完成1砍价完成2下单完成',
  `error` varchar(20) NOT NULL DEFAULT '' COMMENT '错误信息',
  `openid` varchar(28) NOT NULL DEFAULT '' COMMENT '用户的openid',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_mid` (`mid`),
  KEY `idx_cutid` (`cut_id`),
  KEY `idx_ordernum` (`ordernum`)
) ENGINE=InnoDB AUTO_INCREMENT=51609 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='砍价发起记录表';

-- @table ecs_pft002:pft_group_booking
-- @at 2026-11-27 11:54:11
CREATE TABLE `pft_group_booking` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '供应商id',
  `tid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '门票id',
  `aid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '产品的上级供应商id',
  `begin` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开始时间',
  `end` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '结束时间',
  `valid_hours` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '拼团时长',
  `valid_mans` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '成团人数',
  `price` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '价格',
  `storage` int(10) NOT NULL DEFAULT '1' COMMENT '库存',
  `sold_num` int(10) NOT NULL DEFAULT '0' COMMENT '已售数量',
  `limit_buy` tinyint(1) NOT NULL DEFAULT '1' COMMENT '⁮限购',
  `poster_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '海报id',
  `is_open` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '0不公开1公开',
  `auto_complete` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '0不模拟成团1模拟',
  `discounts_money` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '团长优惠金额',
  `discounts_type` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '优惠类型，0没优惠1元2百分比',
  `status` tinyint(1) unsigned NOT NULL COMMENT '1正常2删除',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `lid` int(10) NOT NULL DEFAULT '0' COMMENT '景区id',
  `activity_id` int(4) NOT NULL DEFAULT '0' COMMENT '拼团主活动id',
  `start_num` int(4) NOT NULL DEFAULT '0' COMMENT '初始拼团数',
  `start_pre` int(4) NOT NULL DEFAULT '0' COMMENT '初始预约数',
  `saleout_down` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否售罄自动下架0否1是',
  `over_down` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否结束自动下架：0否1是',
  `is_pre` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否启用虚拟预约数：0否1是',
  `ori_price` int(10) NOT NULL DEFAULT '0' COMMENT '零售价',
  `ori_price_xcx` int(10) NOT NULL DEFAULT '0' COMMENT '窗口价',
  `activity_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '活动上下架状态0下架1上架',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品id',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_tid` (`tid`),
  KEY `idx_activity_id` (`activity_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2901 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='拼团配置表';

-- @table ecs_pft002:pft_group_booking_collect
-- @at 2026-11-27 11:54:26
CREATE TABLE `pft_group_booking_collect` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `mid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '参与者id',
  `group_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '活动id',
  `open_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开团id',
  `group_price` int(6) unsigned NOT NULL DEFAULT '0' COMMENT '拼团价格',
  `ordernum` varchar(20) NOT NULL DEFAULT '' COMMENT '订单号',
  `num` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '购买数量',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '凑团时间',
  `status` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `openid` varchar(28) NOT NULL DEFAULT '' COMMENT '微信openid',
  `relate_id` int(10) NOT NULL DEFAULT '0' COMMENT '开团总id',
  PRIMARY KEY (`id`),
  KEY `idx_mid` (`mid`),
  KEY `idx_openid` (`open_id`),
  KEY `idx_gid` (`group_id`),
  KEY `idx_ordernum` (`ordernum`)
) ENGINE=InnoDB AUTO_INCREMENT=22033 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='拼团参与表';

-- @table ecs_pft002:pft_group_booking_open
-- @at 2026-11-27 11:54:37
CREATE TABLE `pft_group_booking_open` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `mid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '参与用户id',
  `aid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '上级供应商id',
  `sid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '供应商id',
  `own_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '微商城所有者id',
  `begin` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '有效期开始时间',
  `end` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '有效期结束时间',
  `group_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '拼团活动id',
  `gather_num` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '凑团人数',
  `real_gather_num` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '实际凑团人数',
  `status` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '0进行中1成功2失败',
  `error` varchar(20) NOT NULL DEFAULT '' COMMENT '失败信息',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '开团时间',
  `sale_channel` tinyint(1) NOT NULL DEFAULT '0' COMMENT '销售渠道：1微商城2小程序',
  `relate_id` int(10) NOT NULL DEFAULT '0' COMMENT '开团总id',
  `is_new` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否新客户：0否1是',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_time` (`create_time`),
  KEY `idx_mid` (`mid`),
  KEY `idx_relate_id` (`relate_id`)
) ENGINE=InnoDB AUTO_INCREMENT=21288 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='开团记录表';

-- @table ecs_pft002:pft_group_booking_orders
-- @at 2026-11-27 11:54:49
CREATE TABLE `pft_group_booking_orders` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ordernum` varchar(20) NOT NULL DEFAULT '' COMMENT '订单号',
  `data` varchar(1024) NOT NULL DEFAULT '' COMMENT '拼团数据',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '时间',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `mid` int(10) NOT NULL DEFAULT '0' COMMENT '用户id',
  `sale_channel` tinyint(1) NOT NULL DEFAULT '1' COMMENT '销售渠道：1微商城2小程序',
  `activity_id` int(10) NOT NULL DEFAULT '0' COMMENT '活动总id',
  `group_id` int(10) NOT NULL DEFAULT '0' COMMENT '拼团id',
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_ordernum` (`ordernum`),
  KEY `idx_sid` (`sid`),
  KEY `idx_mid` (`mid`),
  KEY `idx_group_id` (`group_id`)
) ENGINE=InnoDB AUTO_INCREMENT=27429 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='拼团订单记录表';

-- @table ecs_pft002:pft_mall_order_record
-- @at 2026-11-27 11:55:01
CREATE TABLE `pft_mall_order_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '表id',
  `order_num` varchar(20) NOT NULL DEFAULT '' COMMENT '订单号',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '购买用户id',
  `sid` int(11) NOT NULL DEFAULT '0' COMMENT '店铺供应商id',
  `lid` int(6) NOT NULL DEFAULT '0' COMMENT '景区id',
  `pid` int(6) NOT NULL DEFAULT '0' COMMENT '产品id',
  `tid` int(6) NOT NULL DEFAULT '0' COMMENT '门票id',
  `order_time` int(11) NOT NULL DEFAULT '0' COMMENT '逻辑下单时间',
  `ordertime` datetime NOT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '下单时间',
  `order_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '订单状态：0=未使用,1=已使用,2=已过期,3=被取消,4=待确认(酒店)，待收货(特产),5=被终端修改,6=被终端撤销,7=部分使用,8=订单完结,9=被删除',
  `pay_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '支付方式:0=现场支付,1=已支付,2=未支付',
  `total_money` int(10) NOT NULL DEFAULT '0' COMMENT '总的支付金额',
  `activity_id` int(11) NOT NULL DEFAULT '0' COMMENT '活动id',
  `activity_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '活动类型：1拼团，2抢购，3砍价, 4红包',
  `is_all_dis` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否参与全民营销0否1是',
  `quota` int(10) NOT NULL DEFAULT '0' COMMENT '该笔订单剩余额度,用户红包统计优惠券兑换消费额度使用',
  PRIMARY KEY (`id`),
  KEY `idx_lid` (`lid`),
  KEY `idx_tid` (`tid`),
  KEY `idx_mid` (`member_id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_activity_id` (`activity_id`),
  KEY `idx_ordertime` (`ordertime`),
  KEY `idx_order_num` (`order_num`)
) ENGINE=InnoDB AUTO_INCREMENT=111969548 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='微商城订单流水表';

-- @table ecs_pft002:pft_material_center
-- @at 2026-11-27 11:55:14
CREATE TABLE `pft_material_center` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id',
  `sid` int(11) NOT NULL DEFAULT '0' COMMENT '供应商id',
  `material_name` varchar(10) NOT NULL DEFAULT '' COMMENT '物料名称',
  `main_title` varchar(25) NOT NULL DEFAULT '' COMMENT '主标题',
  `sub_title` varchar(25) NOT NULL DEFAULT '' COMMENT '子标题',
  `com_name` varchar(25) NOT NULL DEFAULT '' COMMENT '标题名称（公司或者景区名称）',
  `style_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '样式类型：1默认 2 自定义',
  `material_img_url` varchar(255) NOT NULL DEFAULT '' COMMENT '自定义类型物料图url',
  `bg_img_url` varchar(255) NOT NULL DEFAULT '' COMMENT '物料背景图url',
  `rule_json` json DEFAULT NULL COMMENT '跳转规则json',
  `time_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '有效期类型：1长期有效 2指定时间范围',
  `start_time` int(11) NOT NULL DEFAULT '0' COMMENT '有效期开始时间',
  `end_time` int(11) NOT NULL DEFAULT '0' COMMENT '有效期结束时间',
  `material_status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态：1上架 2下架 3删除',
  `create_time` int(11) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '修改时间',
  `count_num` int(10) NOT NULL DEFAULT '0' COMMENT '扫码次数',
  `save_status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '保存进度状态：1 保存背景图 2 保存合成图 ',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=1356 DEFAULT CHARSET=utf8 COMMENT='物料表';

-- @table ecs_pft002:pft_posters
-- @at 2026-11-27 14:43:13
CREATE TABLE `pft_posters` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `member_id` int(10) unsigned NOT NULL COMMENT '会员id',
  `lid` int(10) unsigned NOT NULL COMMENT '景区id',
  `sid` int(10) unsigned NOT NULL COMMENT '上级供应商id',
  `url` varchar(255) NOT NULL DEFAULT '' COMMENT '旧版微商城海报',
  `new_url` varchar(255) NOT NULL DEFAULT '' COMMENT '新版微商城图片url',
  `type` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '0微商城海报，1产品海报',
  `extra` varchar(1024) NOT NULL COMMENT '额外信息',
  `is_supply` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否是供应商海报',
  `create_time` int(10) NOT NULL COMMENT '创建时间',
  `pid` int(10) unsigned NOT NULL,
  `begin` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '有效开始时间',
  `end` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '有效结束时间',
  `stick` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否置顶',
  `desc` varchar(20) NOT NULL DEFAULT '' COMMENT '简介',
  `status` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '海报状态1上架0下架',
  `is_update` tinyint(1) NOT NULL DEFAULT '0' COMMENT '海报更新标记：0否1是',
  `bg_url` varchar(255) NOT NULL DEFAULT '' COMMENT '背景图片地址',
  `tid` int(10) NOT NULL DEFAULT '0' COMMENT '门票id',
  `share_name` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否添加分享者名称：0否1是',
  `share_content` varchar(100) NOT NULL DEFAULT '' COMMENT '分享文案',
  `follow_push` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否关注后推送：0否；1是',
  `propaganda` varchar(100) NOT NULL DEFAULT '' COMMENT '宣传语',
  `logo_show` tinyint(1) NOT NULL DEFAULT '2' COMMENT 'logo显示: 1 显示， 2 不显示',
  `distributor_sync` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '是否同步给下级分销商',
  PRIMARY KEY (`id`),
  KEY `idx_mid` (`member_id`),
  KEY `idx_lid` (`lid`),
  KEY `idx_sid` (`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=103491 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='海报信息表';

-- @table ecs_pft002:pft_seckill_log
-- @at 2026-11-27 15:28:03
CREATE TABLE `pft_seckill_log` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seckill_id` int(10) unsigned NOT NULL COMMENT '抢购活动id',
  `job_id` varchar(32) NOT NULL COMMENT '队列id',
  `ordernum` varchar(20) NOT NULL COMMENT '成功订单号',
  `msg` varchar(50) NOT NULL COMMENT '任务执行说明',
  `cycle_key` varchar(50) NOT NULL COMMENT '周期标识',
  `tnum` mediumint(8) unsigned NOT NULL COMMENT '票数',
  `create_time` int(10) unsigned NOT NULL COMMENT '插入时间',
  `is_new` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是不是新客户：0否1是',
  `money` int(11) NOT NULL DEFAULT '0' COMMENT '订单总价',
  `sale_channel` tinyint(1) NOT NULL DEFAULT '0' COMMENT '销售渠道1微商城2小程序',
  `member_id` int(11) NOT NULL DEFAULT '0' COMMENT '订单用户id',
  `tid` int(11) NOT NULL DEFAULT '0' COMMENT '门票id',
  `activity_id` int(11) NOT NULL DEFAULT '0' COMMENT '活动id',
  `play_time` int(10) NOT NULL DEFAULT '0' COMMENT '游玩时间',
  PRIMARY KEY (`id`),
  KEY `idx_ordernum` (`ordernum`),
  KEY `idx_seckill_id` (`seckill_id`),
  KEY `idx_activity_id` (`activity_id`),
  KEY `idx_create_time` (`create_time`),
  KEY `idx_seckillid_tid_cyclekey_ordernum_tnum` (`seckill_id`,`tid`,`cycle_key`,`ordernum`,`tnum`),
  KEY `idx_seckillid_tid_playtime_ordernum_tnum` (`seckill_id`,`tid`,`play_time`,`ordernum`,`tnum`)
) ENGINE=InnoDB AUTO_INCREMENT=542758 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='抢购活动日志表';

-- @table ecs_pft002:pft_seckill_v2
-- @at 2026-11-27 15:29:08
CREATE TABLE `pft_seckill_v2` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sid` int(10) unsigned NOT NULL COMMENT '供应商id',
  `begin` int(10) unsigned NOT NULL COMMENT '开始时间',
  `end` int(10) unsigned NOT NULL COMMENT '结束时间',
  `poster_id` mediumint(6) unsigned NOT NULL COMMENT '海报id',
  `quantity_sold` int(10) unsigned NOT NULL COMMENT '出售数量',
  `is_cycle` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '是否周期重复',
  `cycle_type` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '周期重复类型1每日2每周3每月',
  `cycle_detail` varchar(1024) NOT NULL COMMENT '周期重复详情',
  `price` int(10) unsigned NOT NULL COMMENT '价格',
  `storage` int(10) NOT NULL COMMENT '库存',
  `cancel_time` mediumint(9) NOT NULL COMMENT '多少分钟未支付就取消',
  `buy_limit` mediumint(9) NOT NULL COMMENT '限购',
  `status` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '0删除,1正常',
  `create_time` int(10) NOT NULL COMMENT '创建时间',
  `sale_channel` varchar(32) NOT NULL DEFAULT '1' COMMENT '发售渠道',
  `activity_name` varchar(200) NOT NULL DEFAULT '' COMMENT '活动名称',
  `limit_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '限制类型',
  `suit_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '适用人群',
  `start_time` int(11) NOT NULL DEFAULT '0' COMMENT '上架时间',
  `end_time` int(11) NOT NULL DEFAULT '0' COMMENT '下架时间',
  `down_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '下架类型',
  `activity_id` int(11) NOT NULL DEFAULT '0' COMMENT '活动ID',
  `is_pre` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否启用预约数：0否，1是',
  `start_type` tinyint(1) NOT NULL DEFAULT '2' COMMENT '上架类型：0立即上架，1定时上架2仅保存',
  `saleout_down` tinyint(1) NOT NULL DEFAULT '0' COMMENT '售罄自动下架：0否1是',
  `over_down` tinyint(1) NOT NULL DEFAULT '0' COMMENT '结束自动下架：0否1是',
  `lid` int(11) NOT NULL DEFAULT '0' COMMENT '景区id',
  `is_custom_poster` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否自定义海报：0否1是',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_sid_lid` (`sid`,`lid`),
  KEY `idx_activity_id` (`activity_id`),
  KEY `idx_start_time` (`start_time`)
) ENGINE=InnoDB AUTO_INCREMENT=18445 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='抢购活动表';

-- @table ecs_pft002:pft_wx_open
-- @at 2026-11-27 15:29:28
CREATE TABLE `pft_wx_open` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `fid` int(10) unsigned NOT NULL,
  `account` varchar(32) DEFAULT NULL,
  `nick_name` varchar(20) NOT NULL,
  `user_name` varchar(32) NOT NULL,
  `appid` char(18) NOT NULL,
  `service_type_info` tinyint(1) NOT NULL DEFAULT '1',
  `verify_type_info` tinyint(1) NOT NULL DEFAULT '1',
  `head_img` varchar(500) DEFAULT NULL,
  `qrcode_url` varchar(500) NOT NULL,
  `isconnect` tinyint(1) NOT NULL,
  `func_info` varchar(50) NOT NULL DEFAULT '0',
  `authorizer_refresh_token` varchar(100) NOT NULL,
  `auth_type` tinyint(4) NOT NULL DEFAULT '1' COMMENT '1-公众号,2小程序',
  `template_id` tinyint(4) NOT NULL DEFAULT '0' COMMENT '小程序商城模板小程序独有',
  `applet_id` int(11) NOT NULL DEFAULT '0' COMMENT '小程序应用id',
  `chk_status` enum('Y','N') NOT NULL DEFAULT 'N',
  `create_time` datetime NOT NULL,
  `update_time` datetime NOT NULL COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_appid_isconnect` (`appid`,`isconnect`),
  KEY `idx_fid` (`fid`),
  KEY `idx_user_name` (`user_name`)
) ENGINE=InnoDB AUTO_INCREMENT=5604 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='用户微信公众号授权信息表';

-- @table pft_logging:pft_login_log
-- @at 2026-11-27 15:30:26
CREATE TABLE `pft_login_log` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `mid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '登录用户ID',
  `login_ip` bigint(10) unsigned NOT NULL DEFAULT '0' COMMENT '登录ip',
  `login_source` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT '登录来源  1=平台，2=终端设备，3=微信端，4=手机验证码登录',
  `login_location` varchar(255) NOT NULL DEFAULT '' COMMENT '登录地',
  `login_browser` varchar(255) NOT NULL DEFAULT '' COMMENT '登录浏览器',
  `login_os` varchar(255) NOT NULL DEFAULT '' COMMENT '登录设备',
  `login_time` int(10) NOT NULL COMMENT '登录时间',
  PRIMARY KEY (`id`),
  KEY `mid` (`mid`),
  KEY `idx_login_time` (`login_time`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=3702388 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='登录日志表';

-- @table pft_open:all_api_order
-- @at 2026-11-27 15:53:19
-- @cmt errormsg 错误信息
-- @cmt fid 用户ID
-- @cmt single_num 1
-- @cmt tourist_info 游客信息
CREATE TABLE `all_api_order` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '表id',
  `pftOrder` varchar(30) NOT NULL,
  `apiOrder` varchar(40) NOT NULL COMMENT 'api订单号',
  `coopB` int(11) unsigned NOT NULL COMMENT '合作商家',
  `bCode` int(10) NOT NULL COMMENT 'api商品编码',
  `oStatus` tinyint(1) NOT NULL COMMENT '订单状态:0=未使用，1=已使用，2=已过期，3=取消成功，4=修改成功，5=申请成功，6=拒绝退款，9=取消超时, 10=出票中',
  `oStnum` int(10) NOT NULL COMMENT '订单数量',
  `apiCode` varchar(255) NOT NULL COMMENT 'api凭证码',
  `cTime` datetime NOT NULL COMMENT '记录时间',
  `uTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `tempOrder` varchar(20) NOT NULL,
  `handleStatus` tinyint(1) NOT NULL,
  `tourist_info` text COMMENT 'æ¸¸å®¢ä¿¡æ¯',
  `single_num` tinyint(1) DEFAULT '0' COMMENT 'è¡¥å•æ¬¡æ•°',
  `errormsg` varchar(128) DEFAULT NULL COMMENT 'é”™è¯¯æè¿°',
  `fid` int(10) DEFAULT NULL COMMENT 'åˆ†é”€å•†id',
  `remoteorder` varchar(50) NOT NULL DEFAULT '' COMMENT '票付通外部接口远端订单号',
  `code_query_status` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '向第三方请求消费码状态 0=没有查询，1=已经查询过，2=非异步返码，不要查询',
  `select_time` int(10) NOT NULL DEFAULT '0' COMMENT '查询订单状态时间',
  `select_status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '查询状态,1可以核销，0不可核销，2退票',
  PRIMARY KEY (`id`),
  UNIQUE KEY `border` (`apiOrder`,`coopB`) USING BTREE,
  UNIQUE KEY `pftOrder` (`pftOrder`)
) ENGINE=InnoDB AUTO_INCREMENT=153436 DEFAULT CHARSET=utf8 COMMENT='票付通对接OTA表';

-- @table pft_open:api_doudian_token
-- @at 2026-11-27 15:53:54
CREATE TABLE `api_doudian_token` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `shop_id` varchar(32) NOT NULL DEFAULT '' COMMENT '抖店商户id',
  `access_token` varchar(255) NOT NULL DEFAULT '' COMMENT '接口请求token值',
  `refresh_token` varchar(255) NOT NULL DEFAULT '' COMMENT '更新token',
  `expires_in` int(13) unsigned NOT NULL DEFAULT '0' COMMENT '13位时间戳，access_token过期时间',
  `member_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '票付通平台账户id',
  `shop_name` varchar(64) NOT NULL DEFAULT '' COMMENT '抖店店铺名称',
  `create_time` int(11) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) NOT NULL DEFAULT '0' COMMENT '修改时间',
  `opid` int(11) NOT NULL DEFAULT '0' COMMENT '操作人id',
  PRIMARY KEY (`id`),
  KEY `idx_shop_id` (`shop_id`) USING BTREE,
  KEY `idx_member_id` (`member_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8 COMMENT='抖店用户授权记录表';

-- @table pft_open:api_kuaishou_conf
-- @at 2026-11-27 15:54:06
CREATE TABLE `api_kuaishou_conf` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `member_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '用户id',
  `app_id` varchar(16) NOT NULL DEFAULT '' COMMENT '快手 appid',
  `app_secret` varchar(64) NOT NULL DEFAULT '' COMMENT '快手秘钥',
  `shop_id` varchar(32) NOT NULL DEFAULT '0' COMMENT '快手店铺编码',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_app_id` (`app_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8 COMMENT='快手对接秘钥配置表';

-- @table pft_open:api_kuaishou_open_token
-- @at 2026-11-27 15:54:18
CREATE TABLE `api_kuaishou_open_token` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增主键',
  `aid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '票付通平台账户id',
  `operator_id` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '票付通平台操作人id',
  `appid` varchar(32) NOT NULL DEFAULT '' COMMENT '快手平台分配的appId',
  `seller_id` varchar(32) NOT NULL DEFAULT '' COMMENT '快手平台商家id (主子账号共用同一个商家id,替换原有url中的shopId即seller)',
  `seller_name` varchar(32) NOT NULL DEFAULT '' COMMENT '快手平台商家名称',
  `openid` varchar(32) NOT NULL DEFAULT '' COMMENT '商家在快手的唯一标识,在同一开发主体下唯一',
  `access_token` varchar(512) NOT NULL DEFAULT '' COMMENT '临时访问令牌,作为调用授权API时的入参,过期时间为expires_in值',
  `expires_in` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'access_token 过期时间,单位秒,默认为172800,即48小时',
  `refresh_token` varchar(512) NOT NULL DEFAULT '' COMMENT '长时访问令牌,默认为180天,会返回新的refresh_token,原有的refresh_token即失效',
  `refresh_token_expires_in` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'refresh_token 过期时间,单位秒,默认为180天',
  `create_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `update_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_seller_id` (`seller_id`) USING BTREE,
  KEY `idx_aid` (`aid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8 COMMENT='快手开放平台授权表';

-- @table pft_open:api_order_track
-- @at 2026-11-27 17:02:23
-- @cmt ctime 取消时间
-- @cmt pftOrder 票付通订单id
-- @cmt tempOrder 临时订单号
CREATE TABLE `api_order_track` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '表id',
  `pftOrder` varchar(128) NOT NULL,
  `apiOrder` varchar(128) NOT NULL COMMENT 'api订单号',
  `tempOrder` varchar(128) NOT NULL,
  `request` text NOT NULL COMMENT '请求报文',
  `response` text NOT NULL COMMENT '响应报文',
  `ctime` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `requestId` varchar(50) NOT NULL COMMENT '唯一请求id',
  PRIMARY KEY (`id`),
  KEY `idx_requestId` (`requestId`) USING BTREE,
  KEY `idx_tempOrder` (`tempOrder`) USING BTREE,
  KEY `idx_ctime` (`ctime`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=80957603 DEFAULT CHARSET=utf8 COMMENT='OTA订单交互报文记录';

-- @table pft_open:pft_con_sys
-- @at 2026-11-27 15:55:24
CREATE TABLE `pft_con_sys` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL COMMENT '第三方票务系统名称',
  `Mpath` varchar(255) NOT NULL COMMENT '对接程序地址',
  `sourceT` varchar(255) NOT NULL COMMENT '对接类型：0=票付通，1=九天闸机权限，2=第三方，3=开放接口',
  `Mdetails` tinyint(1) NOT NULL COMMENT '1 第三方请求权限（二次交互时）0 票付通',
  `system_type` tinyint(1) NOT NULL COMMENT '团购标志0-- 非团购1-- 团购网',
  `account_name` varchar(20) NOT NULL COMMENT '票务系统的账号标识',
  `password_name` varchar(100) NOT NULL DEFAULT '' COMMENT '票务系统的账号密码标识',
  `if_Pftcode` tinyint(1) NOT NULL COMMENT '是否采用票务系统的凭证码,0-- 使用票付通凭证码1-- 使用票务系统凭证码2-- 异步返回票务系统凭证码',
  `sms` tinyint(1) NOT NULL COMMENT '发短信方,0-- 票付通1-- 票务系统',
  `coopB` int(11) NOT NULL COMMENT '三方系统标识',
  `encoding_products` text NOT NULL COMMENT '填写格式：由三方系统提供',
  `timeout` tinyint(1) NOT NULL DEFAULT '15' COMMENT '接口请求超时时间',
  `errortime` tinyint(1) NOT NULL DEFAULT '3' COMMENT '最大的错误次数',
  `is_offline` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '该对接系统是不是被下线',
  `offline_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '系统被下线的时间',
  `contact_info` varchar(255) NOT NULL DEFAULT '' COMMENT '对接系统联系人信息[{mobile:'''',phone:'''',qq:'''',name:''''},{}]',
  `notice_code` varchar(50) NOT NULL DEFAULT '0' COMMENT '1:同步发码 2:异步发码 3:不发码',
  `white_ip` varchar(255) NOT NULL COMMENT '白名单ip 多个地址逗号分隔',
  `create_time` int(10) unsigned NOT NULL COMMENT '创建时间戳',
  `version` varchar(10) NOT NULL DEFAULT '' COMMENT '系统当前版本号',
  `ext` text COMMENT '扩展属性，数据格式为json',
  `sys_desc` text COMMENT '系统说明',
  `question_desc` text COMMENT 'FAQ列表',
  `is_display` tinyint(3) NOT NULL DEFAULT '2' COMMENT '是否显示在客户端 1-显示，2-不显示',
  `secret_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '秘钥类型 1-一对一，2一对多',
  `relevance_tag` varchar(20) NOT NULL DEFAULT '' COMMENT '关联标签',
  `dock_module` varchar(20) NOT NULL DEFAULT '' COMMENT '对接模块',
  `sort` int(10) NOT NULL DEFAULT '0' COMMENT '排序id',
  `video_url` varchar(500) NOT NULL DEFAULT '0' COMMENT '视频地址',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作人ID',
  `sys_type` varchar(50) NOT NULL DEFAULT 'A' COMMENT '对接系统类型(A: 景区 Q: 旅游券 H:演出 F:套票)',
  `system_code` varchar(50) NOT NULL DEFAULT '' COMMENT '系统编码',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `name` (`name`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=636 DEFAULT CHARSET=utf8 COMMENT='对接系统';

-- @table pft_open:pft_con_sys_member
-- @at 2026-11-27 15:55:38
CREATE TABLE `pft_con_sys_member` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `cid` int(11) NOT NULL COMMENT '对接系统表ID',
  `pft_memberid` int(11) NOT NULL COMMENT '对接会员ID列表',
  `status` tinyint(1) NOT NULL COMMENT '状态',
  `sort` int(10) NOT NULL DEFAULT '0' COMMENT '排序id',
  `system_status` int(10) NOT NULL DEFAULT '0' COMMENT '系统状态，1-正常,2-受限',
  `opid` int(10) NOT NULL DEFAULT '0' COMMENT '操作人id',
  `open_source` tinyint(3) NOT NULL DEFAULT '2' COMMENT '开通方式 1-自主添加，2-管理员操作',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '添加时间',
  `update_time` int(10) NOT NULL DEFAULT '0' COMMENT '处理时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_member_id_status` (`pft_memberid`,`status`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=6717 DEFAULT CHARSET=utf8 COMMENT='对接系统使用对接系统的会员';

-- @table pft_open:pft_tb_bind
-- @at 2026-11-27 15:55:51
CREATE TABLE `pft_tb_bind` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '表id',
  `id2` int(10) unsigned NOT NULL DEFAULT '0',
  `id3` int(10) unsigned NOT NULL DEFAULT '0',
  `data1` varchar(100) NOT NULL COMMENT '预留',
  `data2` varchar(100) NOT NULL COMMENT '预留2',
  `msg1` varchar(255) NOT NULL COMMENT '审核信息或拒绝信息',
  `seller_nick` varchar(255) NOT NULL,
  `status` tinyint(1) NOT NULL COMMENT '审核状态0未审1已审',
  `createtime` datetime NOT NULL COMMENT '申请时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1300 DEFAULT CHARSET=utf8 COMMENT='票付通码商申请表';

-- @table pft_open:uu_qunar_use
-- @at 2026-11-27 15:56:05
CREATE TABLE `uu_qunar_use` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '表id',
  `fid` int(10) NOT NULL,
  `tid_aid` varchar(255) NOT NULL COMMENT '产品id_供应商id',
  `supplierIdentity` varchar(255) NOT NULL COMMENT '供应商通信标识',
  `signkey` varchar(2500) NOT NULL DEFAULT '' COMMENT '交互密钥',
  `itime` datetime NOT NULL COMMENT '添加时间',
  `uptime` datetime NOT NULL COMMENT '更新时间',
  `cooperation_way` tinyint(1) NOT NULL,
  `coop_id` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '系统id',
  `DockingMode` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '系统dockeringmode',
  `tid` int(10) NOT NULL DEFAULT '0',
  `third_part_teamwork_id` varchar(255) NOT NULL DEFAULT '' COMMENT '给第三方的合作产品id',
  `third_part_teamwork_id_original` varchar(255) NOT NULL DEFAULT '' COMMENT '给第三方的合作产品id--原始值',
  `opid` int(11) NOT NULL DEFAULT '0' COMMENT '操作人id',
  `ptype` varchar(3) NOT NULL DEFAULT '' COMMENT '产品类型',
  `lid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '产品 id',
  `ext_info` json NOT NULL COMMENT '门票绑定扩展信息',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `fid` (`fid`) USING BTREE,
  KEY `idx_vmid` (`third_part_teamwork_id`) USING BTREE,
  KEY `idx_supplierIdentity` (`supplierIdentity`) USING BTREE,
  KEY `idx_tid` (`tid`) USING BTREE,
  KEY `idx_tptio` (`third_part_teamwork_id_original`) USING BTREE,
  KEY `idx_tid_aid` (`tid_aid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=99799 DEFAULT CHARSET=utf8 COMMENT='去哪儿商家记录表';

-- @table pterminalmanager_data_middle_bi_batch:pft_device_inout_journal
-- @at 2026-11-27 15:38:29
CREATE TABLE `pft_device_inout_journal` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `sid` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '供应商id',
  `land_id` int(10) NOT NULL DEFAULT '0' COMMENT '景区id',
  `site_id` int(10) NOT NULL DEFAULT '0' COMMENT '站点id（预留）',
  `tid` int(10) NOT NULL DEFAULT '0' COMMENT '门票id，订单验证入园的会门票ID;无法记录到门票的为数据为0',
  `num` smallint(5) NOT NULL DEFAULT '0' COMMENT '单次出入园数量',
  `device_key` varchar(32) NOT NULL DEFAULT '' COMMENT '设备特征码',
  `roll_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '类型：0 入园 1 离园',
  `create_day` int(10) NOT NULL DEFAULT '0' COMMENT '年月日',
  `create_time` int(10) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `node_id` int(10) NOT NULL DEFAULT '0' COMMENT '节点id',
  PRIMARY KEY (`id`),
  KEY `idx_create_time` (`create_time`),
  KEY `idx_sid` (`sid`),
  KEY `idx_device_key` (`device_key`,`create_day`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=105827516 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='设备出入园详细记录表';

-- @table rds_distri_center:pft_evolute_group
-- @at 2026-11-27 15:40:13
CREATE TABLE `pft_evolute_group` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id ',
  `group_name` varchar(64) NOT NULL DEFAULT '' COMMENT '分组名称 ',
  `group_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '分组类型:0=普通分组,2=未分组,3=资源中心分组',
  `parent_group_id` int(10) NOT NULL DEFAULT '0' COMMENT '父id',
  `group_default` tinyint(1) NOT NULL DEFAULT '0' COMMENT '默认分组,普通分组和未分组才能为默认分组: 1=是,0=否',
  `operator_id` int(10) NOT NULL DEFAULT '0' COMMENT '最新操作员id，关联pft_member.id',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应上级ID',
  `rectime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  `order_by` int(10) NOT NULL DEFAULT '0' COMMENT '排序：数字小排序靠前',
  PRIMARY KEY (`id`),
  KEY `idx_sid` (`sid`),
  KEY `idx_parent_group_id` (`parent_group_id`)
) ENGINE=InnoDB AUTO_INCREMENT=30725073 DEFAULT CHARSET=utf8 COMMENT='用户分组表';

-- @table rds_distri_center:pft_evolute_group_fid
-- @at 2026-11-27 15:40:26
CREATE TABLE `pft_evolute_group_fid` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id ',
  `group_id` int(10) NOT NULL DEFAULT '0' COMMENT '分组ID ',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '下级分销商ID',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应上级ID',
  `operator_id` int(10) NOT NULL DEFAULT '0' COMMENT '最新操作员id，关联pft_member.id',
  `rectime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  `parent_group_id` int(10) NOT NULL DEFAULT '0' COMMENT '父分组id',
  PRIMARY KEY (`id`),
  KEY `idx_group_id_fid` (`group_id`,`fid`),
  KEY `idx_sid_fid` (`sid`,`fid`),
  KEY `idx_fid` (`fid`)
) ENGINE=InnoDB AUTO_INCREMENT=12159 DEFAULT CHARSET=utf8 COMMENT='用户分组成员表';

-- @table rds_distri_center:pft_evolute_group_speciality
-- @at 2026-11-27 15:40:39
CREATE TABLE `pft_evolute_group_speciality` (
  `id` bigint(14) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id ',
  `group_product_id` int(10) NOT NULL DEFAULT '0' COMMENT '分组产品主键ID',
  `fid` int(10) NOT NULL DEFAULT '0' COMMENT '会员（外键）ID ',
  `sid` int(10) NOT NULL DEFAULT '0' COMMENT '供应上级ID',
  `aids` varchar(200) NOT NULL DEFAULT '' COMMENT '分销链',
  `group_id` int(10) NOT NULL DEFAULT '0' COMMENT '分组id',
  `parent_group_id` int(10) NOT NULL DEFAULT '0' COMMENT '上级分组id',
  `group_ids` varchar(200) NOT NULL DEFAULT '' COMMENT '分组链',
  `sourceid` int(10) NOT NULL DEFAULT '0' COMMENT '最初供应方ID 即：apply_did',
  `pid` int(10) NOT NULL DEFAULT '0' COMMENT '产品pid',
  `ticket_id` int(10) DEFAULT '0' COMMENT '门票id',
  `gid` int(10) NOT NULL DEFAULT '0' COMMENT '商品id',
  `lid` int(10) NOT NULL DEFAULT '0' COMMENT '景点ID',
  `lvl` tinyint(1) NOT NULL DEFAULT '0' COMMENT '供应进化级别默认1二手供应，以此类推',
  `reason` varchar(200) NOT NULL DEFAULT '' COMMENT '其他说明',
  `status` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0有效1无效',
  `price_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '分销价格配置类型:0=直接差价,1=百分比差价',
  `dprice` int(10) NOT NULL DEFAULT '0' COMMENT '配置的差价',
  `origin_type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '数据来源:0=自供应,1=转分销,2=资源中心',
  `rectime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  `active` tinyint(1) NOT NULL DEFAULT '0' COMMENT '当前使用供应商1表示活动状态',
  `channel` varchar(50) DEFAULT '',
  `px` smallint(4) unsigned NOT NULL DEFAULT '0' COMMENT '分销商级别',
  `tx` smallint(4) NOT NULL DEFAULT '0' COMMENT '供应商排序',
  `operator_id` int(10) NOT NULL DEFAULT '0' COMMENT '最新操作员id，关联pft_member.id',
  `parent_channel` varchar(50) DEFAULT '' COMMENT '上级分销渠道',
  `parent_px` smallint(4) unsigned NOT NULL DEFAULT '0' COMMENT '上级景区排序',
  `parent_tx` smallint(4) NOT NULL DEFAULT '0' COMMENT '上级票 排序',
  PRIMARY KEY (`id`,`fid`),
  UNIQUE KEY `idx_fid_sid_pid_aids` (`fid`,`sid`,`pid`,`aids`) USING BTREE,
  KEY `idx_pid` (`pid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=2479581 DEFAULT CHARSET=utf8 COMMENT='用户产品渠道及优先级 - 用户分区'
/*!50100 PARTITION BY HASH (`fid`)
PARTITIONS 512 */;

-- @table rds_distri_center:pft_price_group
-- @at 2026-11-27 15:40:58
-- @cmt disabled_pids 停用产品ID
CREATE TABLE `pft_price_group` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '表ID',
  `name` varchar(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL COMMENT '分组名称',
  `sid` int(10) NOT NULL COMMENT '供应商id',
  `dids` text NOT NULL COMMENT '分销商id',
  `default_inc` text NOT NULL COMMENT '价格数据',
  `disabled_pids` text NOT NULL,
  `default` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '0:非默认分组 1:默认分组',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=70147 DEFAULT CHARSET=utf8 COMMENT='分销商分组';

-- @table vscreen_data_middle_bi_batch:sbs_account
-- @at 2026-11-27 15:47:25
-- @cmt account 账户
-- @cmt created_at 创建
-- @cmt id 主键ID
-- @cmt identifier 标识
-- @cmt name 景区名称
-- @cmt scenic 景区
-- @cmt setting 设置
-- @cmt updated_at 更新
CREATE TABLE `sbs_account` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `account` int(11) NOT NULL DEFAULT '0',
  `name` varchar(64) DEFAULT NULL,
  `identifier` varchar(64) NOT NULL,
  `scenic` json NOT NULL,
  `setting` json NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `idx_account` (`account`),
  KEY `idx_identifier` (`identifier`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=49 DEFAULT CHARSET=utf8mb4;

-- @table vscreen_data_middle_bi_batch:sbs_foundation_data
-- @at 2026-11-27 15:47:39
CREATE TABLE `sbs_foundation_data` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增编号',
  `name` varchar(64) NOT NULL COMMENT '名称说明',
  `scenic` varchar(64) NOT NULL COMMENT '景区标识',
  `scenic_id` int(10) unsigned NOT NULL COMMENT '景区编号',
  `auth_key` varchar(24) NOT NULL COMMENT '鉴权密钥',
  `ext` json NOT NULL COMMENT '扩展数据，用于配置原始数据',
  `configuration` json NOT NULL COMMENT '区域及摄像头配置',
  `flat` json DEFAULT NULL COMMENT '配置扁平化数据',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `idx_scenic` (`scenic`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=76 DEFAULT CHARSET=utf8mb4;

-- @table vscreen_data_middle_bi_batch:sbs_region_tourist_track
-- @at 2026-11-27 15:47:51
CREATE TABLE `sbs_region_tourist_track` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '自增',
  `scenic` varchar(64) NOT NULL COMMENT '景区标识',
  `scenic_id` int(11) NOT NULL COMMENT '景区编号',
  `region` varchar(64) NOT NULL COMMENT '区域标识',
  `region_id` int(11) NOT NULL COMMENT '区域编号',
  `track_date` date NOT NULL COMMENT '轨迹日期',
  `tracks` json NOT NULL COMMENT '游客轨迹',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_track` (`track_date`,`scenic`,`region`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
