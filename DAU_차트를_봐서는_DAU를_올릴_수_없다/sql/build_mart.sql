-- 유저 세그먼트 마트 생성 (mart_user_segment)
--
-- 두 원천 CSV에서 4개 파생지표를 '오늘'과 '어제' 두 시점으로 계산하고,
-- 각 시점을 7개 세그먼트로 분류해 한 행에 user_seg(오늘) / user_seg_from(어제)으로 담는다.
-- 기준일(target_date)은 2026-05-20.
--
-- DuckDB 주의점: 활동 기록이 한 줄도 없는 유저는 LEFT JOIN 결과가 전부 NULL이라
--   count_if(...) 가 0이 아니라 NULL 을 돌려준다(BigQuery COUNTIF 와 다른 점).
--   그래서 active_day_count 를 coalesce(..., 0) 으로 감싸 0 으로 보정한다.

CREATE OR REPLACE TABLE mart_user_segment AS
WITH metrics AS (
  SELECT
    m.user_id,

    -- [오늘 시점 지표]
    (m.first_active_date = DATE '2026-05-20') AS is_newbie,
    bool_or(a.event_date = DATE '2026-05-20') AS d0_active,
    coalesce(count_if(a.event_date BETWEEN DATE '2026-05-20' - INTERVAL 6 DAY
                                       AND DATE '2026-05-20'), 0) AS active_day_count,
    coalesce(max(CASE WHEN a.event_date <= DATE '2026-05-20' THEN a.event_date END),
             m.first_active_date) AS last_active_date,

    -- [어제 시점 지표] (윈도우를 하루씩 미룬다)
    (m.first_active_date = DATE '2026-05-20' - INTERVAL 1 DAY) AS is_newbie_from,
    bool_or(a.event_date = DATE '2026-05-20' - INTERVAL 1 DAY) AS d0_active_from,
    coalesce(count_if(a.event_date BETWEEN DATE '2026-05-20' - INTERVAL 7 DAY
                                       AND DATE '2026-05-20' - INTERVAL 1 DAY), 0) AS active_day_count_from,
    -- 어제 이전에 이미 가입한 유저만 가입일로 보정한다.
    -- 오늘 막 가입한 신규는 어제 존재하지 않았으므로 NULL 로 남겨 user_seg_from 이 NULL 이 되게 한다.
    coalesce(max(CASE WHEN a.event_date <= DATE '2026-05-20' - INTERVAL 1 DAY THEN a.event_date END),
             CASE WHEN m.first_active_date <= DATE '2026-05-20' - INTERVAL 1 DAY
                  THEN m.first_active_date END) AS last_active_date_from
  FROM read_csv_auto('data/user_master.csv') m
  LEFT JOIN read_csv_auto('data/user_activity.csv') a USING (user_id)
  GROUP BY m.user_id, m.first_active_date
)
SELECT
  DATE '2026-05-20' AS target_date,
  user_id,

  -- [어제 시점 분류]
  CASE
    WHEN is_newbie_from                                                          THEN 'new'
    WHEN d0_active_from     AND active_day_count_from >= 5                        THEN 'heavy_active'
    WHEN d0_active_from     AND active_day_count_from BETWEEN 1 AND 4             THEN 'light_active'
    WHEN NOT d0_active_from AND active_day_count_from >= 5                        THEN 'heavy_inactive'
    WHEN NOT d0_active_from AND active_day_count_from BETWEEN 1 AND 4             THEN 'light_inactive'
    WHEN active_day_count_from = 0
         AND last_active_date_from >  DATE '2026-05-20' - INTERVAL 7 DAY         THEN 'light_inactive'
    WHEN active_day_count_from = 0
         AND last_active_date_from BETWEEN DATE '2026-05-20' - INTERVAL 31 DAY
                                       AND DATE '2026-05-20' - INTERVAL 7 DAY    THEN 'risk'
    WHEN active_day_count_from = 0
         AND last_active_date_from <  DATE '2026-05-20' - INTERVAL 31 DAY        THEN 'dormant'
  END AS user_seg_from,

  -- [오늘 시점 분류]
  CASE
    WHEN is_newbie                                                          THEN 'new'
    WHEN d0_active     AND active_day_count >= 5                            THEN 'heavy_active'
    WHEN d0_active     AND active_day_count BETWEEN 1 AND 4                 THEN 'light_active'
    WHEN NOT d0_active AND active_day_count >= 5                            THEN 'heavy_inactive'
    WHEN NOT d0_active AND active_day_count BETWEEN 1 AND 4                 THEN 'light_inactive'
    -- 활동이 전혀 없는 유저는 d0_active 가 NULL 이므로 NOT d0_active 조건을 두지 않는다.
    -- active_day_count = 0 이면 오늘 접속이 없다는 뜻이라 d0 조건은 어차피 불필요하다.
    WHEN active_day_count = 0
         AND last_active_date >  DATE '2026-05-20' - INTERVAL 6 DAY        THEN 'light_inactive'
    WHEN active_day_count = 0
         AND last_active_date BETWEEN DATE '2026-05-20' - INTERVAL 30 DAY
                                  AND DATE '2026-05-20' - INTERVAL 6 DAY   THEN 'risk'
    WHEN active_day_count = 0
         AND last_active_date <  DATE '2026-05-20' - INTERVAL 30 DAY       THEN 'dormant'
  END AS user_seg
FROM metrics
ORDER BY user_id;
