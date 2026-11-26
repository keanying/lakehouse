"""字段中文名：优先用旧系统里真实写过的注释（建表 COMMENT、SQL 行尾注释），没有的再按字段名翻译。

翻译顺序：同表旧注释 → 全库同名字段注释 → OA 泛微系统字段 → 拼音缩写 → 英文词逐个翻译。
词不全认识或拼音含义不确定的，结果后面带「（待确认）」。
"""
import collections, re

ZH = re.compile(r'[一-鿿]')

OA_SYS = {'requestid': '流程请求ID', 'mainid': '主表记录ID', 'formmodeid': '建模表单ID', 'modedatacreater': '数据创建人', 'modedatacreatertype': '数据创建人类型',
          'modedatacreatedate': '数据创建日期', 'modedatacreatetime': '数据创建时间', 'modedatamodifier': '数据修改人', 'modedatamodifydatetime': '数据修改时间',
          'modeuuid': '建模数据UUID', 'ecology_pinyin_search': '拼音检索码', 'outkey': '外部系统主键', 'subcompanyid1': '所属分部ID', 'departmentid': '部门ID',
          'departmentname': '部门名称', 'jobtitle': '岗位ID', 'groupid': '考勤组ID', 'belongdate': '归属日期', 'workmins': '工作时长（分钟）', 'durationrule': '时长计算规则',
          'fromdate': '开始日期', 'todate': '结束日期', 'fromtime': '开始时间', 'totime': '结束时间', 'fromdatedb': '开始日期（库存值）', 'fromtimedb': '开始时间（库存值）',
          'todatedb': '结束日期（库存值）', 'totimedb': '结束时间（库存值）', 'changetype': '变更类型', 'serialid': '流水号', 'countryid': '国家ID', 'canceled': '是否作废',
          'created': '创建时间', 'creater': '创建人', 'modified': '修改时间', 'modifier': '修改人', 'lastname': '姓名', 'workcode': '工号', 'loginid': '登录账号',
          'managerid': '直属上级ID', 'seclevel': '安全级别', 'dsporder': '显示顺序', 'supdepid': '上级部门ID', 'departmentmark': '部门简称', 'subcompanyid': '分部ID'}

# OA 表单常见拼音缩写（含义明确的；不确定的留给「待确认」）
PINYIN = {
    'sqr': '申请人', 'sqrq': '申请日期', 'sqsj': '申请时间', 'sqbm': '申请部门', 'sqrbm': '申请人部门', 'lcbh': '流程编号', 'lcbm': '流程编码', 'lcmb': '流程模板',
    'htbh': '合同编号', 'htje': '合同金额', 'htzje': '合同总金额', 'htlx': '合同类型', 'bz': '备注', 'bh': '编号', 'sl': '数量', 'fj': '附件', 'scfj': '上传附件',
    'fjsc': '附件上传', 'jqmc': '景区名称', 'jqlx': '景区类型', 'xmmc': '项目名称', 'xmlx': '项目类型', 'lxdh': '联系电话', 'lxr': '联系人', 'jfmc': '甲方名称',
    'yfmc': '乙方名称', 'khmc': '客户名称', 'khlx': '客户类型', 'khjl': '客户经理', 'yfkje': '预付款金额', 'xb': '性别', 'csrq': '出生日期', 'wldh': '物流单号',
    'wlfs': '物流方式', 'ptid': '平台ID', 'ptzh': '平台账号', 'cpmc': '产品名称', 'cpxh': '产品型号', 'cpfl': '产品分类', 'cplx': '产品类型', 'hzlx': '合作类型',
    'kprq': '开票日期', 'kpje': '开票金额', 'ykpje': '已开票金额', 'dhkje': '待回款金额', 'hkje': '回款金额', 'yhkje': '已回款金额', 'yskje': '已收款金额',
    'fph': '发票号', 'fpje': '发票金额', 'gw': '岗位', 'bm': '部门', 'gh': '工号', 'rzrq': '入职日期', 'lzrq': '离职日期', 'ywlx': '业务类型', 'xsry': '销售人员',
    'zbj': '质保金', 'sfhg': '是否合格', 'bhgyyms': '不合格原因描述', 'bmfzr': '部门负责人', 'bmfgld': '部门分管领导', 'zzjgbmfzr': '组织架构部门负责人',
    'zzjgbmfgld': '组织架构部门分管领导', 'jzglbmfzr': '兼职管理部门负责人', 'jzglbmfgld': '兼职管理部门分管领导', 'sfbzhxm': '是否标准化项目',
    'dsfcz': '第三方厂商', 'jsr': '经手人', 'ksrq': '开始日期', 'jsrq': '结束日期', 'je': '金额', 'zje': '总金额', 'dj': '单价', 'mc': '名称', 'lx': '类型',
    'zt': '状态', 'rq': '日期', 'sj': '时间', 'sm': '说明', 'ms': '描述', 'yy': '原因', 'dz': '地址', 'sf': '省份', 'cs': '城市', 'qy': '区域', 'fzr': '负责人',
    'shr': '审核人', 'shrq': '审核日期', 'spr': '审批人', 'sprq': '审批日期', 'ywy': '业务员', 'xsdd': '销售订单', 'ddh': '订单号', 'gys': '供应商', 'kh': '客户',
    'hth': '合同号', 'htmc': '合同名称', 'qdrq': '签订日期', 'yxq': '有效期', 'fkfs': '付款方式', 'skzh': '收款账号', 'khh': '开户行', 'sjhm': '手机号码',
    'zjhm': '证件号码', 'yx': '邮箱', 'cz': '传真', 'tc': '提成', 'yj': '业绩', 'ywlxxx': '业务联系信息', 'xmgzbm': '项目跟踪编码', 'rjxq': '软件需求',
    'ddyc': '订单异常', 'zjsj': '增加时间', 'gj': '国家', 'hy': '行业', 'gm': '规模', 'ly': '来源', 'jd': '进度', 'jb': '级别', 'dj2': '等级',
}

W = {
    'id': 'ID', 'no': '编号', 'code': '编码', 'name': '名称', 'type': '类型', 'status': '状态', 'state': '状态', 'flag': '标志', 'desc': '描述', 'description': '描述',
    'remark': '备注', 'remarks': '备注', 'memo': '备注', 'note': '说明', 'comment': '评论', 'content': '内容', 'title': '标题', 'tag': '标签', 'tags': '标签',
    'create': '创建', 'created': '创建', 'update': '更新', 'updated': '更新', 'modify': '修改', 'modified': '修改', 'delete': '删除', 'deleted': '删除', 'by': '人',
    'time': '时间', 'date': '日期', 'datetime': '时间', 'day': '天', 'days': '天数', 'hour': '小时', 'minute': '分钟', 'month': '月份', 'year': '年份', 'week': '周',
    'begin': '开始', 'start': '开始', 'end': '结束', 'expire': '到期', 'expires': '有效期', 'expiration': '过期', 'valid': '有效', 'effective': '生效', 'invalid': '失效',
    'order': '订单', 'orders': '订单', 'ordernum': '订单号', 'sub': '子', 'main': '主', 'parent': '父级', 'child': '子级', 'ticket': '门票', 'tickets': '门票',
    'product': '产品', 'prod': '产品', 'goods': '商品', 'item': '明细项', 'items': '明细项', 'sku': 'SKU', 'spu': 'SPU', 'scenic': '景区', 'land': '景区', 'park': '园区',
    'member': '会员', 'user': '用户', 'users': '用户', 'customer': '客户', 'cus': '客户', 'tourist': '游客', 'traveler': '游客', 'visitor': '游客', 'person': '人员',
    'staff': '员工', 'employee': '员工', 'operator': '操作人', 'operater': '操作人', 'op': '操作', 'oper': '操作', 'admin': '管理员', 'account': '账户', 'accounts': '账户',
    'supplier': '供应商', 'sup': '供应商', 'distributor': '分销商', 'reseller': '分销商', 'dis': '分销', 'distribute': '分销', 'distribution': '分销', 'seller': '卖家',
    'buyer': '买家', 'merchant': '商户', 'company': '公司', 'com': '公司', 'tenant': '租户', 'shop': '门店', 'store': '门店', 'channel': '渠道', 'channels': '渠道',
    'sale': '销售', 'sales': '销售', 'sell': '销售', 'buy': '购买', 'pay': '支付', 'paid': '已支付', 'payment': '支付', 'refund': '退款', 'cancel': '取消',
    'verify': '核销', 'check': '核验', 'checked': '已核验', 'print': '打印', 'book': '预订', 'booking': '预订', 'reserve': '预约', 'use': '使用', 'used': '已使用',
    'amount': '金额', 'amt': '金额', 'money': '金额', 'price': '价格', 'fee': '费用', 'cost': '成本', 'total': '总', 'sum': '合计', 'balance': '余额', 'income': '收入',
    'expense': '支出', 'discount': '优惠', 'coupon': '优惠券', 'rebate': '返利', 'commission': '佣金', 'deposit': '押金', 'deposite': '押金', 'frozen': '冻结',
    'num': '数量', 'number': '数量', 'qty': '数量', 'count': '数量', 'cnt': '数量', 'quantity': '数量', 'amount_num': '数量', 'rate': '比率', 'ratio': '比例',
    'proportion': '占比', 'percent': '百分比', 'level': '级别', 'lv1': '一级', 'lv2': '二级', 'rank': '排名', 'ranking': '排名', 'sort': '排序', 'seq': '序号',
    'idx': '序号', 'index': '序号', 'version': '版本', 'config': '配置', 'conf': '配置', 'setting': '设置', 'rule': '规则', 'rules': '规则', 'template': '模板',
    'info': '信息', 'detail': '明细', 'details': '明细', 'ext': '扩展', 'extend': '扩展', 'extra': '额外', 'data': '数据', 'value': '值', 'key': '键', 'url': '链接',
    'link': '链接', 'img': '图片', 'image': '图片', 'pic': '图片', 'photo': '照片', 'file': '文件', 'path': '路径', 'address': '地址', 'addr': '地址',
    'province': '省', 'city': '市', 'district': '区县', 'county': '区县', 'country': '国家', 'area': '区域', 'region': '地区', 'zip': '邮编', 'lng': '经度',
    'longitude': '经度', 'lat': '纬度', 'latitude': '纬度', 'location': '位置', 'poi': 'POI', 'phone': '手机号', 'mobile': '手机号', 'tel': '电话', 'email': '邮箱',
    'fax': '传真', 'idcard': '身份证号', 'card': '卡', 'cards': '卡', 'certificate': '证件', 'cert': '证件', 'identity': '身份', 'real': '真实', 'sex': '性别',
    'gender': '性别', 'age': '年龄', 'birthday': '生日', 'nick': '昵称', 'avatar': '头像', 'openid': '微信OpenID', 'unionid': '微信UnionID', 'appid': '应用ID',
    'app': '应用', 'wx': '微信', 'wechat': '微信', 'alipay': '支付宝', 'mini': '小程序', 'mp': '小程序', 'api': '接口', 'token': '令牌', 'secret': '密钥',
    'source': '来源', 'from': '来源', 'to': '目标', 'target': '目标', 'origin': '原始', 'original': '原始', 'remote': '远端', 'third': '第三方', 'thirdparty': '第三方',
    'party': '方', 'platform': '平台', 'plat': '平台', 'system': '系统', 'sys': '系统', 'module': '模块', 'package': '套餐', 'combo': '组合', 'function': '功能',
    'permission': '权限', 'role': '角色', 'menu': '菜单', 'auth': '授权', 'authorize': '授权', 'login': '登录', 'log': '日志', 'track': '轨迹', 'record': '记录',
    'records': '记录', 'history': '历史', 'journal': '流水', 'trade': '交易', 'trans': '交易', 'transaction': '交易', 'serial': '流水', 'bill': '账单', 'invoice': '发票',
    'settle': '结算', 'settlement': '结算', 'withdraw': '提现', 'cash': '现金', 'bank': '银行', 'subject': '科目', 'book': '账本', 'apply': '申请', 'audit': '审核',
    'approve': '审批', 'reason': '原因', 'result': '结果', 'error': '错误', 'msg': '消息', 'message': '消息', 'sms': '短信', 'notify': '通知', 'notice': '通知',
    'remind': '提醒', 'send': '发送', 'receive': '接收', 'task': '任务', 'job': '作业', 'activity': '活动', 'act': '活动', 'poster': '海报', 'posters': '海报',
    'material': '素材', 'group': '组', 'team': '团队', 'fellow': '同行', 'seckill': '秒杀', 'cut': '砍价', 'help': '助力', 'join': '参与', 'open': '开通', 'opened': '已开通',
    'close': '关闭', 'enabled': '启用', 'enable': '启用', 'disabled': '停用', 'online': '上线', 'offline': '下线', 'shelf': '上架', 'onshelf': '上架', 'offshelf': '下架',
    'stock': '库存', 'storage': '库存', 'inventory': '库存', 'remain': '剩余', 'left': '剩余', 'capacity': '容量', 'limit': '限制', 'max': '最大', 'min': '最小',
    'avg': '平均', 'first': '首次', 'last': '最近', 'latest': '最新', 'next': '下次', 'pre': '预', 'prev': '上一', 'new': '新', 'old': '旧', 'all': '全部',
    'is': '是否', 'has': '是否有', 'can': '可', 'need': '需要', 'cycle': '周期', 'period': '周期', 'granularity': '粒度', 'metric': '指标', 'kpi': 'KPI',
    'stat': '统计', 'statistics': '统计', 'report': '报表', 'summary': '汇总', 'analysis': '分析', 'score': '评分', 'grade': '等级', 'baseline': '基线',
    'national': '全国', 'yoy': '同比', 'mom': '环比', 'growth': '增长', 'popularity': '热度', 'hot': '热门', 'visit': '到访', 'visits': '到访', 'view': '浏览',
    'pv': '浏览量', 'uv': '访客数', 'click': '点击', 'search': '搜索', 'recommend': '推荐', 'consume': '消费', 'wealth': '财富', 'work': '工作', 'live': '居住',
    'travel': '出行', 'behavior': '行为', 'preference': '偏好', 'tgi': 'TGI 指数', 'contract': '合同', 'project': '项目', 'opportunity': '商机', 'call': '回访',
    'back': '回', 'post': '岗位', 'department': '部门', 'dept': '部门', 'organization': '组织', 'org': '组织', 'job_title': '岗位', 'mode': '方式', 'way': '方式',
    'method': '方式', 'terminal': '终端', 'device': '设备', 'gate': '闸机', 'wrist': '手环', 'physics': '物理', 'virtual': '虚拟', 'qr': '二维码', 'voucher': '凭证',
    'plate': '车牌', 'car': '车辆', 'entry': '入场', 'exit': '出场', 'enter': '进入', 'inout': '出入', 'in': '入', 'out': '出', 'hotel': '酒店', 'room': '房间',
    'retail': '零售', 'unit': '单位', 'currency': '币种', 'lang': '语言', 'language': '语言', 'letters': '字母', 'topic': '主题', 'humor': '幽默', 'talk': '话术',
    'guide': '导览', 'ignore': '忽略', 'relate': '关联', 'related': '关联', 'relation': '关系', 'relationship': '关系', 'bind': '绑定', 'mapping': '映射',
    'dw': '数仓', 'etl': 'ETL', 'ins': '写入', 'sync': '同步', 'deal': '处理', 'action': '动作', 'daction': '动作', 'dtype': '类型', 'request': '请求',
    'response': '响应', 'uuid': 'UUID', 'line': '线路', 'off': '下', 'up': '上', 'down': '下', 'over': '超', 'saleout': '售罄', 'mark': '标记', 'contribution': '贡献',
    'lmoney': '余额', 'dprice': '分销价', 'tprice': '单价', 'recmonth': '记录月份', 'rectime': '记录时间', 'op_id': '操作人ID', 'memberid': '会员ID',
    'resourceid': '资源ID', 'resource': '资源', 'purchase': '采购', 'procurement': '采购', 'quota': '配额', 'share': '共享', 'shared': '共享', 'annual': '年卡',
    'privilege': '特权', 'renew': '续费', 'active': '激活', 'photos': '照片', 'face': '人脸', 'aliface': '支付宝人脸', 'async': '异步', 'cover': '覆盖', 'suit': '适用',
    'desensitization': '脱敏', 'manage': '管理', 'management': '管理', 'external': '外部', 'internal': '内部', 'mall': '商城', 'collect': '收集', 'v2': 'V2',
    'serial_num': '流水号', 'trade_no': '交易号', 'out_trade_no': '外部交易号', 'tid': '门票ID', 'lid': '景区ID', 'aid': '供应商ID', 'fid': '用户ID', 'sid': '供应商ID',
    'pid': '产品ID', 'mid': '会员ID', 'uid': '用户ID', 'oid': '订单ID', 'ptype': '产品类型', 'apply_did': '原始供应商ID', 'px': '排序', 'q': '季度', 'mx5': '明细5',
    'sj': '时间', 'yj': '业绩', 'tc': '提成', 'fp': '发票', 'fph': '发票号', 'hz': '合作', 'xx': '信息', 'wl': '物流', 'kd': '快递', 'dsf': '第三方',
}
W.update({'crm': 'CRM', 'lot': '场', 'parking_lot': '停车场'})
W.update({'signdate': '签到日期', 'scheduletime': '排班时间', 'attestatus': '考勤状态', 'signtype': '签到类型', 'signtime': '签到时间', 'srch': '搜索', 'activate': '激活', 'holiday': '节假日', 'space': '间隔', 'take': '取票', 'p_name': '产品名称', 't_status': '门票状态', 'v_code': '验证码', 'page_num': '页数', '12301page': '12301 页面', 'pwxt': '票务系统', 'zhdl': '智慧导览', 'cylsxt': '餐饮零售系统', 'attend': '考勤', 'schedule': '排班', 'signin': '签到', 'signout': '签退', 'checkin': '签到'})
W.update({'redeploydate': '调岗日期', 'redeployreason': '调岗原因', 'ischangesalary': '是否调薪', 'sfjsoffer': '是否接受 offer', 'wjsofferyy': '未接受 offer 原因', 'sfktcrmzh': '是否开通 CRM 账号', 'oldjob': '原岗位', 'newjob': '新岗位', 'pmanager': '项目经理', 'infoman': '信息维护人', 'resource_n': '资源数', 'n': '数'})
W.update({'offset': '偏移量', 'current': '当前', 'logistics': '物流', 'submit': '提交', 'completed': '已完成', 'completion': '完成', 'filling': '填写', 'checker': '核对人', 'uniform_social_credit_code': '统一社会信用代码', 'catalogue': '目录', 'gratuity': '小费', 'box': '包装', 'rounding': '抹零', 'web': '网页', 'spend': '消费', 'on': '在', 'table': '桌台', 'usage': '使用量', 'or': '或', 'identifier': '标识', 'configuration': '配置', 'flat': '平铺', 'scene': '场景', 'wordscnt': '字数', 'msgcnt': '短信条数', 'smstxt': '短信内容', 'tob': 'ToB', 'platformid': '平台ID', 'resend': '重发', 'prove': '证明', 'layering': '分层', 'aio': '一卡通', 'params': '参数', 'param': '参数', 'pri': '优先', 'mins': '分钟', 'load': '加载', 'authority': '权限', 'party': '方', 'operid': '操作人ID', 'err': '错误', 'options': '选项', 'option': '选项', 'active': '激活', 'apply_for': '申请事项', 'h': 'H', 'a': 'A', 'b': 'B', 'for': '', 'd': '天', 'min': '最小', 'social': '社会', 'credit_code': '信用代码', 'high_seas': '公海', 'own': '所属', 'social_credit_code': '社会信用代码', 'party_a': '甲方', 'party_b': '乙方', 'cwqrskje': '财务确认收款金额', 'htztai': '合同状态', 'fpmc': '发票名称'})
W.update({'field': '字段', 'center': '中心', 'positive': '正面', 'neutral': '中性', 'negative': '负面', 'service': '服务', 'cooperation': '合作', 'business': '业务', 'revoke': '撤销', 'push': '推送', 'rsv': '预约', 'lock': '锁定', 'at': '', 'pft': '票付通', 'invoicing': '开票', 'sold': '已售', 'amb': '阿米巴', 'des': '描述', 'return': '退货', 'emotional': '情感', 'refresh': '刷新', 'wd': '提现', 'auto': '自动', 'dep': '部门', 'batch': '批次', 'after': '后', 'operate': '操作', 'son': '子', 'receipt': '收据', 'tax': '税', 'default': '默认', 'transfer': '转账', 'available': '可用', 'charge': '收费', 'del': '删除', 'short': '简', 'physical': '实体', 'avalid': '有效', 'attr': '属性', 'protocol': '协议', 'develop': '开发', 'oa': 'OA', 'category': '类目', 'object': '对象', 'enterprise': '企业', 'paymode': '支付方式', 'market': '市场', 'level1': '一级', 'level2': '二级', 'level3': '三级', 'lv3': '三级', 'add': '新增', 'sign': '签约', 'head': '负责人', 'self': '自营', 'page': '页面', 'cooper': '合作', 'coop': '合作', 'map': '地图', 'opt': '操作', 'before': '前', 'property': '属性', 'early': '提前', 'changing': '变更', 'change': '变更', 'owner': '负责人', 'industry': '行业', 'describe': '描述', 'ship': '发货', 'shipments': '发货', 'individual': '个人', 'belong': '所属', 'overall': '整体', 'publish': '发布', 'test': '测试', 'thirdsystem': '第三方系统', 'event': '事件', 'integral': '积分', 'remaining': '剩余', 'freeze': '冻结', 'award': '奖励', 're': '重新', 'credit': '授信', 'complete': '完成', 'ori': '原始', 'own': '自有', 'gather': '汇总', 'bg': '背景', 'supply': '供应', 'show': '展示', 'custom': '自定义', 'home': '归属', 'forcast': '预测', 'forecast': '预测', 'contacts': '联系人', 'contact': '联系人', 'dcodeurl': '二维码链接', 'adcode': '行政区划码', 'done': '完成', 'accnt': '账户', 'accuont': '账户', 'man': '人', 'mans': '人数', 'agent': '代理', 'src': '来源', 'rmtype': '房型', 'duration': '时长', 'merger': '合并', 'merge': '合并', 'free': '免费', 'class': '分类', 'row': '行', 'cashier': '收银员', 'point': '点位', 'examine': '审核', 'errmsg': '错误信息', 'principal': '负责人', 'bonus': '奖金', 'operation': '运营', 'ordermode': '下单方式', 'payway': '支付方式', 'validity': '有效期', 'dt': '日期', 'dstatus': '状态', 'site': '站点', 'jtype': '类型', 'mtype': '类型', 'pos': 'POS', 'oversea': '境外', 'website': '网站', 'runtime': '运行时间', 'cron': '调度表达式', 'expand': '展开', 'spread': '推广', 'ddays': '天数', 'dhour': '小时', 'certi': '证件', 'cname': '中文名', 'hotline': '热线', 'uptime': '更新时间', 'delaytime': '延迟时间', 'list': '列表', 'reb': '返利', 'low': '低', 'chk': '核验', 'if': '是否', 'weekdays': '星期', 'biz': '业务', 'reg': '注册', 'high': '高', 'seas': '公海', 'followed': '已跟进', 'follow': '跟进', 'scope': '范围', 'returned': '已退回', 'confirm': '确认', 'select': '选择', 'issue': '发放', 'grand': '总', 'rec': '记录', 'access': '访问', 'reward': '奖励', 'tx': '交易', 'signing': '签约', 'turnover': '营业额', 'validated': '已验证', 'spot': '景点', 'sentiment': '情感', 'parking': '停车', 'vendor': '厂商', 'insight': '洞察', 'interpretation': '解读', 'payout': '支出', 'effect': '生效', 'dead': '截止', 'priority': '优先级', 'repeatable': '可重复', 'outter': '外部', 'outer': '外部', 'exclusive': '专属', 'tariff': '税则', 'red': '红冲', 'complex': '复合', 'master': '主', 'sslcert': 'SSL 证书', 'sslkey': 'SSL 密钥', 'env': '环境', 'final': '最终', 'reversal': '冲正', 'adjust': '调整', 'sequence': '序列', 'present': '赠送', 'batchno': '批次号', 'once': '一次性', 'acctype': '账户类型', 'tradeid': '交易ID', 'xcx': '小程序', 'timing': '定时', 'finish': '完结', 'style': '样式', 'json': 'JSON', 'save': '保存', 'stick': '置顶', 'propaganda': '宣传', 'logo': '标志', 'dict': '字典', 'depid': '部门ID', 'meituan': '美团', 'datav': '大屏', 'analyst': '分析师', 'slice': '切片', 'preplay': '预约游玩', 'nonchecked': '未核验', 'like': '点赞', 'hash': '哈希', 'download': '下载', 'excel': 'Excel', 'application': '应用', 'encrypt': '加密', 'defined': '定义', 'structure': '结构', 'sta': '统计', 'grp': '组', 'ota': 'OTA', 'compan': '公司', 'ratecode': '房价码', 'rmnum': '房间数', 'rmno': '房号', 'arr': '到达', 'adult': '成人', 'children': '儿童', 'child': '儿童', 'success': '成功', 'fail': '失败', 'failed': '失败', 'total_num': '总数', 'real_name': '真实姓名', 'nickname': '昵称', 'password': '密码', 'pwd': '密码', 'salt': '盐值', 'ip': 'IP', 'browser': '浏览器', 'os': '操作系统', 'platform_id': '平台ID', 'channel_id': '渠道ID', 'channel_name': '渠道名称', 'score_type': '评分类型', 'dimension': '维度', 'core': '核心', 'macro': '宏观', 'gran': '粒度', 'comment_core': '评论核心', 'quarter': '季度', 'half': '半年', 'daily': '日', 'weekly': '周', 'monthly': '月', 'yearly': '年', 'hourly': '小时', 'minutely': '分钟', 'today': '今日', 'yesterday': '昨日', 'cancelled': '已取消', 'canceled': '已取消', 'refunded': '已退款', 'verified': '已核销', 'printed': '已打印', 'finished': '已完结', 'expired': '已过期', 'pending': '待处理', 'audit_status': '审核状态', 'apply_status': '申请状态', 'join_num': '参与人数', 'help_num': '助力人数', 'visit_num': '访问次数', 'view_num': '浏览次数', 'brand': '品牌', 'model': '型号', 'spec': '规格', 'specs': '规格', 'color': '颜色', 'size': '尺寸', 'weight': '重量', 'length': '长度', 'width': '宽度', 'height': '高度', 'qrcode': '二维码', 'barcode': '条码', 'sn': '序列号', 'imei': 'IMEI', 'mac': 'MAC 地址', 'gps': 'GPS', 'online_time': '上线时间', 'heartbeat': '心跳', 'january': '一月', 'february': '二月', 'march': '三月', 'april': '四月', 'may': '五月', 'june': '六月', 'july': '七月', 'august': '八月', 'september': '九月', 'october': '十月', 'november': '十一月', 'december': '十二月', 'certificatenum': '身份证号', 'nativeplace': '籍贯', 'educationlevel': '学历', 'bememberdate': '入团日期', 'bepartydate': '入党日期', 'regresidentplace': '户口所在地', 'healthinfo': '健康状况', 'residentplace': '现居住地', 'policy': '政治面貌', 'degree': '学位', 'usekind': '用工性质', 'jobcall': '职称', 'accumfundaccount': '公积金账号', 'birthplace': '出生地', 'folk': '民族', 'residentpostcode': '居住地邮编', 'managerstr': '上级链路', 'islabouunion': '是否工会会员', 'tempresidentnumber': '暂住证号', 'probationenddate': '试用期结束日期', 'passwdchgdate': '密码修改日期', 'needusb': '是否需要 USB Key', 'lloginid': '登录名', 'needdynapass': '是否动态密码', 'accounttype': '账号类型', 'belongto': '所属主账号', 'dactylogram': '指纹', 'assistantdactylogram': '辅助指纹', 'msgstyle': '消息样式', 'messagerurl': '头像地址', 'pinyinlastname': '姓名拼音', 'tokenkey': '令牌', 'userusbtype': 'USB Key 类型', 'adsjgs': 'AD 上级公司', 'adgs': 'AD 公司', 'adbm': 'AD 部门', 'mobileshowtype': '手机号显示方式', 'usbstate': 'USB Key 状态', 'totalspace': '总空间', 'occupyspace': '已用空间', 'isadaccount': '是否 AD 账号', 'accountname': '账号名', 'mobilecaflag': '手机 CA 标志', 'companystartdate': '入职日期', 'workstartdate': '参加工作日期', 'classification': '密级', 'companyworkyear': '司龄', 'workyear': '工龄', 'dismissdate': '离职日期', 'maritalstatus': '婚姻状况', 'nationality': '国籍', 'systemlanguage': '系统语言', 'mobilecall': '手机号', 'locationid': '办公地点ID', 'workroom': '办公室', 'resourcetype': '人员类型', 'startdate': '开始日期', 'enddate': '结束日期', 'jobactivitydesc': '职务描述', 'joblevel': '职级', 'costcenterid': '成本中心ID', 'assistantid': '助理ID', 'bankid1': '开户银行ID', 'accountid1': '银行账号', 'resourceimageid': '照片ID', 'createrid': '创建人ID', 'lastmodid': '最后修改人ID', 'lastmoddate': '最后修改日期', 'lastlogindate': '最后登录日期', 'jobtitlemark': '岗位简称', 'jobtitlename': '岗位名称', 'provincename': '省份名称', 'provincedesc': '省份描述', 'cityname': '城市名称', 'citylongitude': '城市经度', 'citylatitude': '城市纬度', 'provinceid': '省份ID', 'allsupdepid': '全部上级部门ID', 'departmentcode': '部门编码', 'coadjutant': '协办人', 'tlevel': '层级', 'showorder': '显示顺序', 'showorderoftree': '树形显示顺序', 'yjbq': '一级标签', 'ejbq': '二级标签', 'sjbq': '三级标签', 'paidleaveenable': '是否带薪假', 'computingmode': '计算方式', 'expiringdate': '到期日期', 'workflowid': '流程ID', 'dataid': '数据ID', 'detailid': '明细ID', 'newleavetype': '请假类型', 'usedetail': '使用明细', 'tablenamedb': '来源表名', 'durationdb': '时长', 'kqdate': '考勤日期', 'serialnumber': '流水号', 'workbegindate': '上班日期', 'workbegintime': '上班时间', 'workenddate': '下班日期', 'workendtime': '下班时间', 'signindate': '签到日期', 'signintime': '签到时间', 'signinid': '签到记录ID', 'signoutdate': '签退日期', 'signouttime': '签退时间', 'signoutid': '签退记录ID', 'attendancemins': '出勤分钟', 'belatemins': '迟到分钟', 'gravebelatemins': '严重迟到分钟', 'leaveearlymins': '早退分钟', 'graveleaveearlymins': '严重早退分钟', 'absenteeismmins': '旷工分钟', 'leavemins': '请假分钟', 'evectionmins': '出差分钟', 'outmins': '外出分钟', 'forgotcheckmins': '漏签分钟', 'signmins': '签卡分钟', 'leaveinfo': '请假信息', 'forgotbeginworkcheckmins': '上班漏签分钟', 'groupname': '考勤组名称', 'validityfromdate': '有效开始日期', 'validityenddate': '有效结束日期', 'holidaydate': '节假日日期', 'holidaydesc': '节假日说明', 'relatedday': '关联日期', 'leavename': '假期名称', 'resttype': '休息类型', 'across': '是否跨天', 'isdelete': '是否删除', 'shortname': '简称', 'pinyin': '拼音', 'icon': '图标', 'classify': '分类', 'visible': '是否可见', 'upgrade': '升级', 'budgetatuomoveorder': '预算自动排序', 'lastname': '姓名', 'workcode': '工号'})
GENERIC = {'id', 'name', 'status', 'state', 'type', 'remark', 'remarks', 'memo', 'create_time', 'update_time', 'create_by', 'update_by', 'created_at',
           'updated_at', 'province', 'city', 'district', 'country', 'title', 'content', 'description', 'sort', 'version', 'deleted', 'is_delete', 'code',
           'create_date', 'update_date', 'modify_time', 'modify_date', 'amount', 'money', 'price', 'total', 'num', 'level', 'year', 'month', 'week', 'date', 'time'}
ORDER_FIX = [(r'^是否(.*)', r'是否\1')]


def _guess_word(tok):
    tok = tok.lower()
    if tok in W:
        return W[tok]
    if tok in PINYIN:
        return PINYIN[tok]
    if tok.isdigit():
        return tok
    m = re.fullmatch(r'(\d+)d', tok)
    if m:
        return f'近{m.group(1)}天'
    if tok.endswith('s') and tok[:-1] in W:
        return W[tok[:-1]]
    return None


def translate(col):
    """英文 / 拼音字段名 → (中文名, 是否确定)"""
    c = col.lower().strip('`')
    if c == 'id':
        return '主键ID', True
    m = re.fullmatch(r'field_([a-z0-9]{4,6})__c', c)
    if m:
        return f'CRM 自定义字段 field_{m.group(1)}（纷享销客 API 名，含义见 CRM 对象描述）', False
    m = re.fullmatch(r'(.+?)__(c|r)', c)
    if m:
        base, sure = translate(m.group(1))
        return (base + '（关联对象显示名）' if m.group(2) == 'r' else base), sure
    m = re.fullmatch(r'([a-z]{2,})(\d+)', c)
    if m and (m.group(1) in PINYIN or m.group(1) in W):
        base, sure = translate(m.group(1))
        return base + m.group(2), sure
    if c in OA_SYS:
        return OA_SYS[c], True
    if c in PINYIN:
        return PINYIN[c], True
    if c in W:
        return W[c], True
    m = re.match(r'^(.*)_(mask|hash)$', c)
    if m:
        base, sure = translate(m.group(1))
        return base + ('（掩码）' if m.group(2) == 'mask' else '（哈希）'), sure
    m = re.fullmatch(r'(date|number|text|tinyint)field(\d+)', c)
    if m:
        return f'自定义{ {"date": "日期", "number": "数值", "text": "文本", "tinyint": "选项"}[m.group(1)] }字段{m.group(2)}', True
    m = re.fullmatch(r'(\d+)d', c)
    if m:
        return f'近{m.group(1)}天', True
    toks = [t for t in re.split(r'_+', c) if t]
    out, sure = [], True
    i = 0
    while i < len(toks):
        two = '_'.join(toks[i:i + 2])
        if i + 1 < len(toks) and two in W:          # 词组（job_title、trade_no …）
            out.append(W[two])
            i += 2
            continue
        w = _guess_word(toks[i])
        if w is None:                                    # 连写的两个词：landid → land + id
            t0 = toks[i]
            for k in range(2, len(t0) - 1):
                a_, b_ = _guess_word(t0[:k]), _guess_word(t0[k:])
                if a_ and b_ and len(t0[:k]) >= 2 and len(t0[k:]) >= 2:
                    w = a_ + b_
                    break
        if w is None:
            # 驼峰 / 连写：updatetime → update + time
            sp = re.findall(r'(create|update|modify|order|pay|time|date|num|id|name|type|status|code|money|price|user|member|ticket)', toks[i])
            if sp and ''.join(sp) == toks[i]:
                w = ''.join(W.get(x, x) for x in sp)
            else:
                w, sure = toks[i], False
        out.append(w)
        i += 1
    s = ''
    for w in out:                                        # 英文缩写相邻时加空格：SKU ID、POI ID
        if s and re.search(r'[A-Za-z]$', s) and re.match(r'[A-Za-z]', w):
            s += ' '
        s += w
    s = s.replace('人人', '人').replace('ID ID', 'ID')
    if toks and toks[0] == 'is':
        s = '是否' + ''.join(out[1:]).replace('是否', '')
    if re.fullmatch(r'(创建|更新|修改)人', s):
        pass
    return s, sure


class Namer:
    """收集旧系统真实注释后，为字段给出中文名"""

    def __init__(self, schemas, nodes):
        self.by_table = collections.defaultdict(dict)
        self.glob = collections.defaultdict(collections.Counter)
        for t, x in schemas.items():
            for c, ty, cm in x['cols']:
                cm = (cm or '').strip()
                if ZH.search(cm):
                    self.by_table[t][c] = cm
                    self.glob[c][cm] += 1
        for n in nodes:                                   # SQL 行尾注释：col AS alias, -- 中文
            if n['lang'] != 'sql':
                continue
            for line in n['script'].split('\n'):
                if re.match(r'\s*--', line):
                    continue
                m = re.search(r"(?:\bas\s+)?`?([a-zA-Z_]\w*)`?\s*,?\s*--\s*(.+?)\s*$", line, re.I)
                if m and ZH.search(m.group(2)):
                    self.glob[m.group(1).lower()][m.group(2)[:60]] += 1
        self.stats = collections.Counter()

    def best(self, c):
        cs = self.glob.get(c.lower())
        if not cs:
            return None
        # 取出现最多的；并列取较短（更像名称）
        return sorted(cs.items(), key=lambda x: (-x[1], len(x[0])))[0][0]

    def name(self, col, tables=(), legacy_cols=()):
        for t in tables:
            cm = self.by_table.get(t, {}).get(col.lower())
            if cm:
                self.stats['同表旧注释'] += 1
                return cm
        tr, sure = translate(col)
        generic = sure and (col.lower() in GENERIC or ('_' not in col and col.lower() in W))
        for c in (col, *legacy_cols):
            if generic:
                break
            cm = self.best(c)
            if cm:
                self.stats['旧系统同名字段注释'] += 1
                return cm
        s, sure = tr, sure
        self.stats['按字段名翻译' if sure else '翻译待确认'] += 1
        if sure:
            return s
        if not re.search(r'[\u4e00-\u9fff]', s):
            if any(re.search(r'oa_|hr_|formtable|uf_|hrm|kq_|crm', str(t)) for t in tables):
                return f'OA 表单字段 {col}（拼音缩写，待确认）'
            return f'缩写字段 {col}（待确认）'
        return s if '待确认' in s or 'CRM' in s and '（' in s and s.endswith('）') and '待确认' in s else f'{s}（待确认）'


def needs_name(cmt, col):
    c = str(cmt or '').strip()
    return not c or c.lower() == str(col).lower() or not ZH.search(c)
