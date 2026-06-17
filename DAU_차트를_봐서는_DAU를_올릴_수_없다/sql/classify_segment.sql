-- 4개 파생지표 계산 + 7개 세그먼트 분류 (오늘 시점, 기준일 2026-05-20)
--
-- user_master 와 user_activity 를 LEFT JOIN 한 뒤 유저 단위로 집계해
-- is_newbie / d0_active / active_day_count / last_active_date 4개 지표를 만들고,
-- CASE WHEN 한 단계로 7개 세그먼트로 분류한다.

WITH metrics AS (
  SELECT
    m.user_id,
    -- 1. 오늘 가입한 유저 여부
    (m.first_active_date = DATE '2026-05-20') AS is_newbie,
    -- 2. 오늘 접속 여부
    bool_or(a.event_date = DATE '2026-05-20') AS d0_active,
    -- 3. 최근 7일(기준일 포함) 접속 일수. 활동이 없으면 count_if 가 NULL 이므로 0 으로 보정.
    coalesce(count_if(a.event_date BETWEEN DATE '2026-05-20' - INTERVAL 6 DAY
                                       AND DATE '2026-05-20'), 0) AS active_day_count,
    -- 4. 마지막 활동일. 활동 이력이 없으면 가입일을 마지막 활동일로 간주.
    coalesce(max(CASE WHEN a.event_date <= DATE '2026-05-20' THEN a.event_date END),
             m.first_active_date) AS last_active_date
  FROM read_csv_auto('data/user_master.csv') m
  LEFT JOIN read_csv_auto('data/user_activity.csv') a USING (user_id)
  GROUP BY m.user_id, m.first_active_date
)
SELECT
  user_id,
  CASE
    WHEN is_newbie                                                        THEN 'new'
    WHEN d0_active     AND active_day_count >= 5                          THEN 'heavy_active'
    WHEN d0_active     AND active_day_count BETWEEN 1 AND 4               THEN 'light_active'
    WHEN NOT d0_active AND active_day_count >= 5                          THEN 'heavy_inactive'
    WHEN NOT d0_active AND active_day_count BETWEEN 1 AND 4               THEN 'light_inactive'
    -- 활동이 전혀 없는 유저는 d0_active 가 NULL 이므로 NOT d0_active 조건을 두지 않는다.
    WHEN active_day_count = 0
         AND last_active_date >  DATE '2026-05-20' - INTERVAL 6 DAY      THEN 'light_inactive'
    WHEN active_day_count = 0
         AND last_active_date BETWEEN DATE '2026-05-20' - INTERVAL 30 DAY
                                  AND DATE '2026-05-20' - INTERVAL 6 DAY THEN 'risk'
    WHEN active_day_count = 0
         AND last_active_date <  DATE '2026-05-20' - INTERVAL 30 DAY     THEN 'dormant'
  END AS user_seg
FROM metrics
ORDER BY user_id;
