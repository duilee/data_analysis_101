-- 유저 세그먼트 마트 생성 (mart_user_segment)
--
-- 3개 파생지표를 오늘/어제 두 시점으로 계산해 세그먼트 마트를 적재한다. 기준일 2026-05-20.
-- 분류는 classify_macro.sql 의 classify_seg 매크로를 두 시점에 재사용한다 (먼저 실행할 것).
-- 오늘 막 가입한 유저는 '어제' 시점에 존재하지 않았으므로 user_seg_from 이 NULL 이 된다.
-- 준비: 두 원천 CSV를 테이블로 등록해 두었다는 전제 (노트북 0단계)
--   CREATE TABLE user_master   AS SELECT * FROM read_csv_auto('data/user_master.csv');
--   CREATE TABLE user_activity AS SELECT * FROM read_csv_auto('data/user_activity.csv');

CREATE OR REPLACE TABLE mart_user_segment AS
WITH metrics AS (
  SELECT
    m.user_id,
    -- 오늘(기준일) 지표
    datediff('day', m.first_active_date, DATE '2026-05-20') AS days,
    count_if(a.event_date BETWEEN DATE '2026-05-20' - INTERVAL 6 DAY
                              AND DATE '2026-05-20') AS cnt,
    max(CASE WHEN a.event_date <= DATE '2026-05-20' THEN a.event_date END) AS last_active,
    -- 어제 지표 (같은 정의에서 윈도우만 하루 미룸)
    datediff('day', m.first_active_date, DATE '2026-05-20' - INTERVAL 1 DAY) AS days_from,
    count_if(a.event_date BETWEEN DATE '2026-05-20' - INTERVAL 7 DAY
                              AND DATE '2026-05-20' - INTERVAL 1 DAY) AS cnt_from,
    max(CASE WHEN a.event_date <= DATE '2026-05-20' - INTERVAL 1 DAY THEN a.event_date END) AS last_active_from
  FROM user_master m LEFT JOIN user_activity a USING (user_id)
  GROUP BY m.user_id, m.first_active_date
)
SELECT
  DATE '2026-05-20' AS target_date, user_id,
  classify_seg(days_from, cnt_from, last_active_from, DATE '2026-05-20' - INTERVAL 1 DAY) AS user_seg_from,
  classify_seg(days, cnt, last_active, DATE '2026-05-20') AS user_seg
FROM metrics ORDER BY user_id;
