-- 실습 1, 단계 1) 4개 파생지표 만들기 (오늘 시점, 기준일 2026-05-20)
--
-- user_master 와 user_activity 를 LEFT JOIN 한 뒤 유저 단위로 집계해
-- is_newbie / d0_active / active_day_count / last_active_date 4개 지표를 만들고
-- user_metrics 테이블로 저장한다. (다음 단계 classify_segment.sql 의 입력)
-- 가입 당일은 반드시 활동이 찍히므로(가입 = 첫 접속) 활동 0행 유저는 없다.

CREATE OR REPLACE TABLE user_metrics AS
SELECT
  m.user_id,
  -- 1. 오늘 가입한 유저 여부
  (m.first_active_date = DATE '2026-05-20') AS is_newbie,
  -- 2. 오늘 접속 여부
  bool_or(a.event_date = DATE '2026-05-20') AS d0_active,
  -- 3. 최근 7일(기준일 포함) 접속 일수
  count_if(a.event_date BETWEEN DATE '2026-05-20' - INTERVAL 6 DAY
                            AND DATE '2026-05-20') AS active_day_count,
  -- 4. 마지막 활동일 (가입 당일 활동이 보장되므로 항상 존재)
  max(CASE WHEN a.event_date <= DATE '2026-05-20' THEN a.event_date END) AS last_active_date
FROM read_csv_auto('data/user_master.csv') m
LEFT JOIN read_csv_auto('data/user_activity.csv') a USING (user_id)
GROUP BY m.user_id, m.first_active_date;
