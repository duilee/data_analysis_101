-- 기준일별 세그먼트 테이블 매크로 (실습 2 준비)
--
-- 실습 1.1의 지표 계산(build_metrics.sql)에 classify_macro.sql 의 classify_seg 를 붙여,
-- 기준일(ref_date) 하나를 넣으면 그날의 유저별 세그먼트가 나오는 테이블 매크로로 정의한다.
-- build_mart.sql 이 오늘/어제 두 시점에 이 매크로를 호출한다 (classify_macro.sql 을 먼저 실행할 것).
-- '최근 7일' 활동 윈도우를 바꿀 때는 build_metrics.sql 과 이 매크로의 INTERVAL 6 DAY 를 함께 고친다.
-- 준비: 두 원천 CSV를 테이블로 등록해 두었다는 전제 (노트북 0단계)
--   CREATE TABLE user_master   AS SELECT * FROM read_csv_auto('data/user_master.csv');
--   CREATE TABLE user_activity AS SELECT * FROM read_csv_auto('data/user_activity.csv');

CREATE OR REPLACE MACRO segment_at(ref_date) AS TABLE
SELECT user_id, classify_seg(days, cnt, last_active, ref_date) AS user_seg
FROM (
  SELECT
    m.user_id,
    datediff('day', m.first_active_date, ref_date) AS days,
    count_if(a.event_date BETWEEN ref_date - INTERVAL 6 DAY
                              AND ref_date) AS cnt,
    max(CASE WHEN a.event_date <= ref_date THEN a.event_date END) AS last_active
  FROM user_master m LEFT JOIN user_activity a USING (user_id)
  GROUP BY m.user_id, m.first_active_date
);
