-- 실습 1, 단계 1) 파생지표 만들기 (오늘 시점, 기준일 2026-05-20)
--
-- user_master 와 user_activity 를 LEFT JOIN 한 뒤 유저 단위로 집계해
-- days_since_signup / active_day_count / last_active_date 3개 지표(+ DAU 교차용 d0_active)를
-- 만들고 user_metrics 테이블로 저장한다. (다음 단계 classify_segment.sql 의 입력)
-- 가입 당일은 반드시 기록이 찍히므로(가입 = 첫 기록) 활동 0행 유저는 없다.
-- 준비: 두 원천 CSV를 테이블로 등록해 두었다는 전제 (노트북 0단계)
--   CREATE TABLE user_master   AS SELECT * FROM read_csv_auto('data/user_master.csv');
--   CREATE TABLE user_activity AS SELECT * FROM read_csv_auto('data/user_activity.csv');

CREATE OR REPLACE TABLE user_metrics AS
SELECT
  m.user_id,
  -- 1. 가입(첫 기록) 후 며칠째인가 (가입 당일 = 0)
  datediff('day', m.first_active_date, DATE '2026-05-20') AS days_since_signup,
  -- 2. 최근 7일(기준일 포함) 기록 일수
  count_if(a.event_date BETWEEN DATE '2026-05-20' - INTERVAL 6 DAY
                            AND DATE '2026-05-20') AS active_day_count,
  -- 3. 마지막 기록일 (가입 당일 기록이 보장되므로 항상 존재)
  max(CASE WHEN a.event_date <= DATE '2026-05-20' THEN a.event_date END) AS last_active_date,
  -- (+) 오늘 기록 여부 — 세그먼트 분류에는 쓰지 않고 DAU 구성을 볼 때만 사용
  bool_or(a.event_date = DATE '2026-05-20') AS d0_active
FROM user_master m LEFT JOIN user_activity a USING (user_id)
GROUP BY m.user_id, m.first_active_date;
