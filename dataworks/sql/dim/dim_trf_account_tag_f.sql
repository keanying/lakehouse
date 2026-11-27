-- ================================================================================================
-- dim.dim_trf_account_tag_f  分销账号标签
-- 粒度：1行=1个平台账号×1个标签
-- 分区：无分区
-- 调度：每日，ODS 全部完成后；维表之间按上游顺序
-- 上游：配置（旧 channel_aids SQL 硬编码的账号清单，迁入 dataworks/standard/account_tags.json）
-- 业务规则 / 修正：
--   · 共 20 个账号；名称按旧字段缩写整理（dylk、ksbdsh、mtqq 等缩写含义待业务核对）
-- ================================================================================================
INSERT OVERWRITE TABLE dim.dim_trf_account_tag_f                                -- 整表覆盖写入
SELECT
    CAST(member_id AS BIGINT)                                    AS member_id,  -- 平台账号ID
    tag_group,                                                                  -- 标签组
    tag_code,                                                                   -- 标签编码
    tag_name,                                                                   -- 标签名称
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time         -- ETL 加载时间
FROM (
        SELECT * FROM VALUES
       (12404122, 'NEW_MEDIA', 'NEW_MEDIA_DY', '新媒体·抖音团购'),
       (12513404, 'NEW_MEDIA', 'NEW_MEDIA_KS', '新媒体·快手'),
       (13913690, 'NEW_MEDIA', 'NEW_MEDIA_DD', '新媒体·抖店'),
       (15467659, 'NEW_MEDIA', 'NEW_MEDIA_KSDS', '新媒体·快手电商开放平台'),
       (26856539, 'NEW_MEDIA', 'NEW_MEDIA_DYLK', '新媒体·抖音来客（按旧字段缩写 dylk）'),
       (27003241, 'NEW_MEDIA', 'NEW_MEDIA_KSBDSH', '新媒体·快手本地生活（按旧字段缩写 ksbdsh）'),
       (2175, 'OTA', 'OTA_QNR', 'OTA·去哪儿'),
       (28227, 'OTA', 'OTA_MTZL', 'OTA·美团直连'),
       (3663752, 'OTA', 'OTA_XCWL', 'OTA·携程网络'),
       (1214, 'OTA', 'OTA_XCWL', 'OTA·携程网络'),
       (9718585, 'OTA', 'OTA_MTQQ', 'OTA·美团（mtqq）'),
       (1252953, 'OTA', 'OTA_MFW', 'OTA·马蜂窝'),
       (9011093, 'OTA', 'OTA_ALI', 'OTA·阿里飞猪'),
       (10406130, 'OTA', 'OTA_KBW', 'OTA·口碑'),
       (13151618, 'OTA', 'OTA_MFWZY', 'OTA·马蜂窝自营'),
       (768763, 'OTA', 'OTA_YZWSC', 'OTA·有赞微商城'),
       (5624150, 'OTA', 'OTA_JD', 'OTA·京东'),
       (4560136, 'OTA', 'OTA_WM', 'OTA·微盟'),
       (10141128, 'OTA', 'OTA_GD', 'OTA·高德'),
       (5269593, 'OTA', 'OTA_MTTYYD', 'OTA·美团通用预订')
        AS v(member_id, tag_group, tag_code, tag_name)
    ) t
