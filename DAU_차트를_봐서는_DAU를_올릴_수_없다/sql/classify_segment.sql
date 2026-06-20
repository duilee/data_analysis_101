-- 실습 1, 단계 2) 정해진 기준에 따라 7개 세그먼트로 분류 (오늘 시점, 기준일 2026-05-20)
--
-- 앞 단계(build_metrics.sql)가 만든 user_metrics 테이블의 4개 지표를
-- CASE WHEN 한 단계로 7개 세그먼트로 분류한다.

SELECT
  user_id,
  is_newbie,
  d0_active,
  active_day_count,
  last_active_date,
  CASE
    WHEN is_newbie                                                        THEN 'new'
    WHEN d0_active     AND active_day_count >= 5                          THEN 'heavy_active'
    WHEN d0_active     AND active_day_count BETWEEN 1 AND 4               THEN 'light_active'
    WHEN NOT d0_active AND active_day_count >= 5                          THEN 'heavy_inactive'
    WHEN NOT d0_active AND active_day_count BETWEEN 1 AND 4               THEN 'light_inactive'
    -- active_day_count = 0 이면 최근 7일 접속이 없다는 뜻이므로 d0_active 조건은 불필요하다.
    WHEN active_day_count = 0
         AND last_active_date BETWEEN DATE '2026-05-20' - INTERVAL 30 DAY
                                  AND DATE '2026-05-20' - INTERVAL 6 DAY THEN 'risk'
    WHEN active_day_count = 0
         AND last_active_date <  DATE '2026-05-20' - INTERVAL 30 DAY     THEN 'dormant'
  END AS user_seg
FROM user_metrics
ORDER BY user_id;
