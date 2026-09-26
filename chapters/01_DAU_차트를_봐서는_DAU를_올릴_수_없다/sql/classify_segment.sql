-- 실습 1, 단계 2) 정해진 기준에 따라 5개 세그먼트로 분류 (오늘 시점, 기준일 2026-05-20)
--
-- 앞 단계(build_metrics.sql)가 만든 user_metrics 테이블의 3개 지표를
-- CASE WHEN 한 단계로 5개 세그먼트(new / heavy / light / risk / dormant)로 분류한다.

SELECT
  *,
  CASE
    WHEN days_since_signup < 7           THEN 'new'
    WHEN active_day_count >= 5           THEN 'heavy'
    WHEN active_day_count BETWEEN 1 AND 4 THEN 'light'
    -- active_day_count = 0 이면 최근 7일 기록이 없다는 뜻이므로,
    -- risk/dormant 는 마지막 기록일이 30일 안쪽인지로만 가르면 된다.
    WHEN last_active_date >= DATE '2026-05-20' - INTERVAL 30 DAY THEN 'risk'
    ELSE 'dormant'
  END AS user_seg
FROM user_metrics
ORDER BY user_id;
