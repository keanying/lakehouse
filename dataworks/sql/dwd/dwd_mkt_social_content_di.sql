-- ================================================================================================
-- dwd.dwd_mkt_social_content_di  舆情内容明细
-- 粒度：1行=1条发布内容 / 评论
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 ODS 当日分区与相关维表
-- 上游：ods_trf_social_opinion_comment_core_df
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据平台/DWD/dwd_全网舆论/废弃dwd_content_comment_detail_di（SERVERLESS_SPARK_SQL，cron 00 26 00 * * ?）
--   · 数据平台/DWD/dwd_全网舆论/废弃dwd_content_publish_info_di（SERVERLESS_SPARK_SQL，cron 00 27 00 * * ?）
-- 业务规则 / 修正：
--   · 过渡期从旧表 dwd_content_comment_detail_di 平移：旧逻辑由多张中间表 / 外部采集加工，字段与 ODS 不能直接对应；字段口径按字典，上线顺序：先平移保证下游可切换，再按字段清单把「待确认」逐个改为从 ODS 计算后下线旧链路
-- ================================================================================================
INSERT OVERWRITE TABLE dwd.dwd_mkt_social_content_di PARTITION (travel_date = '${bizdate}')
SELECT
    content_id,
    CAST(NULL AS STRING)                                         AS publish_time,   -- 待确认：来源未同步
    CAST(NULL AS STRING)                                         AS platform_code,   -- 待确认：来源未同步
    user_id,
    nickname,
    avatar,
    gender,
    profile_url,
    ip_location,
    create_date_time,
    comment_id,
    content,
    sub_comment_count                                            AS sub_comment_qty,
    parent_comment_id,
    like_count                                                   AS like_qty,
    sentiment_label,
    sentiment_score,
    dimension_tags,
    entity_tags,
    keyword_tags,
    CAST(NULL AS STRING)                                         AS platform,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.platform）
    CAST(NULL AS STRING)                                         AS source_keyword,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.source_keyword）
    CAST(NULL AS STRING)                                         AS title,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.title）
    CAST(NULL AS STRING)                                         AS content_desc,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.content_desc）
    CAST(NULL AS STRING)                                         AS liked_qty,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.liked_count）
    CAST(NULL AS STRING)                                         AS comments_qty,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.comments_count）
    CAST(NULL AS STRING)                                         AS collected_qty,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.collected_count）
    CAST(NULL AS STRING)                                         AS shared_qty,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.shared_count）
    CAST(NULL AS STRING)                                         AS content_url,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.content_url）
    CAST(NULL AS STRING)                                         AS cover_image_list,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.cover_image_list）
    CAST(NULL AS STRING)                                         AS video_url,   -- 待确认：来源未同步（旧字段 dwd_content_publish_info_di.video_url）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time
FROM dwd_content_comment_detail_di
