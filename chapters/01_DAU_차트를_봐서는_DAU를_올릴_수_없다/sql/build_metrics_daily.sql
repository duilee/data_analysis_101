-- 실습 2, 단계 1) 날짜별 파생지표 (user_metrics_daily)
--
-- build_metrics.sql(실습 1.1)과 같은 지표 정의에 날짜 축을 더한다. 달력(generate_series,
-- 2026-04-20 ~ 2026-05-20 31일)을 유저 마스터와 조인해 날짜 × 유저 단위로 3개 지표를 계산하고,
-- 그 날짜에 아직 가입하지 않은 유저는 조인 조건(first_active_date <= target_date)으로 거른다.
-- '최근 7일' 활동 윈도우를 바꿀 때는 build_metrics.sql 과 이 파일의 INTERVAL 6 DAY 를 함께 고친다.
-- 준비: 두 원천 CSV를 테이블로 등록해 두었다는 전제 (노트북 0단계)
--   CREATE TABLE user_master   AS SELECT * FROM read_csv_auto('data/user_master.csv');
--   CREATE TABLE user_activity AS SELECT * FROM read_csv_auto('data/user_activity.csv');

CREATE OR REPLACE TABLE user_metrics_daily AS
SELECT
  d.target_date::DATE AS target_date, m.user_id,
  datediff('day', m.first_active_date, d.target_date) AS days_since_signup,
  count_if(a.event_date BETWEEN d.target_date - INTERVAL 6 DAY
                            AND d.target_date) AS active_day_count,
  max(CASE WHEN a.event_date <= d.target_date
      THEN a.event_date END) AS last_active_date
FROM generate_series(DATE '2026-04-20', DATE '2026-05-20', INTERVAL 1 DAY)
     AS d(target_date)
JOIN user_master m ON m.first_active_date <= d.target_date
LEFT JOIN user_activity a USING (user_id)
GROUP BY d.target_date, m.user_id, m.first_active_date;
