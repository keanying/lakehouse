-- ================================================================================================
-- ads.ads_prd_attraction_visitor_stats_di  西安博物院客群日报
-- 粒度：1行=1天×供应商（西安博物院）
-- 分区：travel_date（YYYYMMDD）
-- 调度：每日，依赖上游 DWS 当日分区；完成后回流 / 服务层读取
-- 上游：ods_ord_order_traveler_track_di、ods_ord_order_traveler_ext_di、dwd_ord_traveler_di、dwd_ord_order_di
-- 替代旧任务 2 个（上线对数一致后下线）：
--   · 数据平台/业务需求工作流/西安博物院_日报/ads_prd_attraction_visitor_stats_df（EMR_SPARK_SQL，cron 00 07 05 * * ?）
--   · 数据平台/业务需求工作流/西安博物院_日报/西安博物院_日报数据/ads_prd_attraction_visitor_stats_di（EMR_SPARK_SQL，cron 00 05 18 * * ?）
-- 业务规则 / 修正：
--   · 替代旧 ads_prd_attraction_visitor_stats_di / _df 两套同逻辑脚本：游客属性改用标准游客明细（客源地、年龄已在 DWD 解析），不再在报表里重复解析证件 / 手机号
--   · 修正：旧逻辑游客属性只关联「当日下单」的游客，提前几天下单的入园游客没有客源地 / 年龄（省内外合计小于入园人数）；改为关联近 90 天下单的游客
--   · 修正：旧「本月重复核销」把证件、手机都为空的游客合成同一个人（md5('-'-'-')）计入复购；改为必须有证件或手机标识
--   · 口径差异（上线前与客户核对）：客源地标准为「证件优先、手机号段次之」（旧为手机优先）；境外标准按境外证件（旧另按手机国际区号）；散约旧为 OTA 渠道配置里 target_id = 2022 的聚合渠道，标准渠道维表不保留 target_id，按下单渠道 20（第三方 / OTA 对接）统计
-- 性能：
--   · 游客轨迹只读当日 / 本月分区并在源头过滤供应商与动作
--   · 游客明细只取关联需要的列，按 订单号 + 游客序号 等值关联
-- ================================================================================================
WITH vt AS (                                                                      -- 当日首次入园的游客（游客轨迹 1 行 = 1 位游客 1 次动作）
    SELECT ordernum AS order_no,                                                  -- 订单号
           CAST(idx AS INT) AS traveler_seq,                                      -- 订单内游客序号
           tid AS ticket_id,                                                      -- 票ID
           CAST(apply_did AS BIGINT) AS supplier_id                               -- 供应商ID（租户ID）
    FROM ods.ods_ord_order_traveler_track_di
    WHERE travel_date = '${bizdate}'                                              -- 只取当日分区
      AND FROM_UNIXTIME(insert_time, 'yyyyMMdd') = '${bizdate}'
      AND apply_did = 38322930                                                    -- 西安博物院（供应商）
      AND track_action IN (1, 4)                                                  -- 入园核销类动作（沿用旧口径）
      AND COALESCE(msg, '') NOT LIKE '%过期%'                                       -- 剔除过期票的核销提示
      AND CAST(GET_JSON_OBJECT(ext_content, '$.is_first_used') AS INT) = 1        -- 只计首次入园
),
tr AS (                                                                           -- 游客属性：近 90 天下单的游客明细（客源省、证件类型、年龄、下单渠道、证件 / 手机哈希）
    SELECT order_no,
           traveler_seq,
           scenic_id,
           CAST(province_code AS STRING) AS province_code,                        -- 客源省编码（取票人证件 / 手机号归属）
           id_card_type,
           age,
           order_mode,
           IF(id_card_hash IS NULL AND phone_hash IS NULL, NULL, CONCAT(
               COALESCE(id_card_hash, '-'),
               '-',
               COALESCE(phone_hash, '-')
           )) AS person_key,
           travel_date AS order_date
    FROM dwd.dwd_ord_traveler_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 90), 'yyyyMMdd')
      AND '${bizdate}'
),
ext AS (                                                                          -- 下单时登记的年龄（游客扩展信息；旧口径优先用它，无则用证件解析年龄）
    SELECT orderid AS order_no,                                                   -- 订单号
           CAST(idx AS INT) AS traveler_seq,                                      -- 订单内游客序号
           MAX(CAST(GET_JSON_OBJECT(ext_info, '$.age') AS INT)) AS ext_age
    FROM ods.ods_ord_order_traveler_ext_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 90), 'yyyyMMdd')
      AND '${bizdate}'
      AND apply_did = 38322930
    GROUP BY orderid, idx                                                         -- 按粒度键汇总
),
d AS (                                                                            -- 当日入园客群
    SELECT vt.supplier_id,                                                        -- 供应商ID（租户ID）
           SUM(IF(tr.province_code = '610000', 1, 0))                                            AS in_province_qty,  -- 省内游客入园人数（客源省 = 陕西）
           SUM(IF(
               tr.province_code NOT IN ('610000', '710000', '810000', '820000') AND COALESCE(tr.id_card_type, '') <> '2',
               1,
               0
           )) AS out_province_qty,                                                -- 省外游客入园人数
           SUM(IF(tr.province_code IN ('710000', '810000', '820000'), 1, 0))                     AS hmt_qty,  -- 港澳台游客入园人数｜台湾 / 香港 / 澳门
           SUM(IF(tr.id_card_type = '2', 1, 0))                                                 AS foreign_qty,  -- 境外游客入园人数（境外证件）｜证件类型 2 = 境外证件
           SUM(IF(COALESCE(e.ext_age, tr.age) >= 65, 1, 0))                                     AS elderly_qty,  -- 老人入园人数（≥65 岁）
           SUM(IF(COALESCE(e.ext_age, tr.age) <= 6, 1, 0))                                      AS children_qty,  -- 儿童入园人数（≤6 岁）
           SUM(IF(vt.ticket_id = 5373157, 1, 0))                                                AS morning_exercise_qty,  -- 晨练人员入园人数（晨练票）｜晨练票
           SUM(IF(vt.ticket_id = 5376735, 1, 0))                                                AS special_group_qty,  -- 特殊人群入园人数（特殊人群票）｜特殊人群票
           SUM(IF(tr.order_mode = 20, 1, 0))                                                    AS online_booking_qty,  -- 散约入园人数（线上第三方渠道预约）｜第三方 / OTA 对接下单
           SUM(IF(tr.order_mode IN (0, 3, 10), 1, 0))                                           AS onsite_booking_qty,  -- 现场预约入园人数｜平台 / 现场 / 云票务下单
           COUNT(1)                                                                              AS in_park_qty  -- 实际入园人数（首次入园游客）
    FROM vt
    LEFT JOIN tr ON tr.order_no = vt.order_no AND tr.traveler_seq = vt.traveler_seq
    LEFT JOIN ext e ON e.order_no = vt.order_no AND e.traveler_seq = vt.traveler_seq
    GROUP BY vt.supplier_id                                                       -- 按粒度键汇总
),
adv AS (                                                                          -- 提前预约：游玩日 = 统计日、近 10 天内下单且已支付的票数（景区 714738）
    SELECT SUM(ticket_qty) AS advance_book_qty                                    -- 提前预约人数
    FROM dwd.dwd_ord_order_di
    WHERE travel_date BETWEEN DATE_FORMAT(DATE_SUB(TO_DATE('${bizdate}', 'yyyyMMdd'), 10), 'yyyyMMdd')
      AND '${bizdate}'
      AND supplier_id = 38322930
      AND scenic_id = 714738
      AND pay_status = '1'
      AND play_date = DATE_FORMAT(TO_DATE('${bizdate}', 'yyyyMMdd'), 'yyyy-MM-dd')
),
mvt AS (                                                                          -- 本月 1 日至统计日的首次入园游客
    SELECT ordernum AS order_no,                                                  -- 订单号
           CAST(idx AS INT) AS traveler_seq                                       -- 订单内游客序号
    FROM ods.ods_ord_order_traveler_track_di
    WHERE travel_date BETWEEN CONCAT(SUBSTR('${bizdate}', 1, 6), '01') AND '${bizdate}'
      AND apply_did = 38322930                                                    -- 西安博物院（供应商）
      AND track_action IN (1, 4)                                                  -- 入园核销类动作（沿用旧口径）
      AND COALESCE(msg, '') NOT LIKE '%过期%'                                       -- 剔除过期票的核销提示
      AND CAST(GET_JSON_OBJECT(ext_content, '$.is_first_used') AS INT) = 1        -- 只计首次入园
),
mtr AS (                                                                          -- 本月下单的游客（证件 / 手机哈希作为同一游客的标识）
    SELECT order_no,
           traveler_seq,
           scenic_id,
           person_key FROM tr WHERE order_date >= CONCAT(SUBSTR('${bizdate}', 1, 6), '01') AND person_key IS NOT NULL
),
rb AS (                                                                           -- 本月重复预订：同一游客本月在景区 714738 下单 ≥2 次
    SELECT COUNT(1) AS month_repeat_book_qty                                      -- 本月重复预订游客数（本月下单 ≥2 次）
    FROM (SELECT person_key FROM mtr WHERE scenic_id = 714738 GROUP BY person_key HAVING COUNT(1) > 1) x
),
rt AS (                                                                           -- 本月重复核销：同一游客本月核销 ≥2 张不同订单
    SELECT COUNT(1) AS month_repeat_track_qty                                     -- 本月重复核销游客数（本月核销 ≥2 单）
    FROM (SELECT t.person_key
          FROM mvt v
          JOIN mtr t ON t.order_no = v.order_no AND t.traveler_seq = v.traveler_seq
          GROUP BY t.person_key                                                   -- 按粒度键汇总
          HAVING COUNT(DISTINCT v.order_no) > 1) x
),
mv AS (SELECT COUNT(1) AS month_verify_total_qty FROM mvt)
INSERT OVERWRITE TABLE ads.ads_prd_attraction_visitor_stats_di PARTITION (travel_date = '${bizdate}')  -- 写入当日分区
SELECT /*+ BROADCAST(adv, rb, rt, mv) */
    d.supplier_id,                                                                -- 供应商ID（租户ID）
    DATE_FORMAT(TO_DATE('${bizdate}', 'yyyyMMdd'), 'yyyy-MM-dd') AS verify_date,  -- 入园日期（yyyy-MM-dd）
    d.in_province_qty,                                                            -- 省内游客入园人数（客源省 = 陕西）
    d.out_province_qty,                                                           -- 省外游客入园人数
    d.hmt_qty,                                                                    -- 港澳台游客入园人数
    d.foreign_qty,                                                                -- 境外游客入园人数（境外证件）
    d.elderly_qty,                                                                -- 老人入园人数（≥65 岁）
    d.children_qty,                                                               -- 儿童入园人数（≤6 岁）
    d.morning_exercise_qty,                                                       -- 晨练人员入园人数（晨练票）
    d.special_group_qty,                                                          -- 特殊人群入园人数（特殊人群票）
    d.online_booking_qty,                                                         -- 散约入园人数（线上第三方渠道预约）
    d.onsite_booking_qty,                                                         -- 现场预约入园人数
    d.in_park_qty,                                                                -- 实际入园人数（首次入园游客）
    COALESCE(adv.advance_book_qty, 0) AS advance_book_qty,                        -- 提前预约人数
    COALESCE(rb.month_repeat_book_qty, 0) AS month_repeat_book_qty,               -- 本月重复预订游客数（本月下单 ≥2 次）
    COALESCE(rt.month_repeat_track_qty, 0) AS month_repeat_track_qty,             -- 本月重复核销游客数（本月核销 ≥2 单）
    COALESCE(mv.month_verify_total_qty, 0) AS month_verify_total_qty,             -- 本月累计入园人数（月初至统计日）
    DATE_FORMAT(CURRENT_TIMESTAMP(), 'yyyy-MM-dd HH:mm:ss') AS etl_time           -- ETL 加载时间
FROM d
CROSS JOIN adv
CROSS JOIN rb
CROSS JOIN rt
CROSS JOIN mv
