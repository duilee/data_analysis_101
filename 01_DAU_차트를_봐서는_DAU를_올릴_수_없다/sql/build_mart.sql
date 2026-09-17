-- 유저 세그먼트 마트 생성 (mart_user_segment)
--
-- segment_at_macro.sql 의 segment_at 을 오늘/어제 두 시점으로 호출해 user_seg(오늘)와
-- user_seg_from(어제)을 한 행에 담아 적재한다. 기준일 2026-05-20.
-- classify_macro.sql → segment_at_macro.sql 순으로 먼저 실행할 것.
-- 오늘 막 가입한 유저는 '어제' 시점에 존재하지 않았으므로 user_seg_from 이 NULL 이 된다.
-- 준비: 두 원천 CSV를 테이블로 등록해 두었다는 전제 (노트북 0단계)
--   CREATE TABLE user_master   AS SELECT * FROM read_csv_auto('data/user_master.csv');
--   CREATE TABLE user_activity AS SELECT * FROM read_csv_auto('data/user_activity.csv');

CREATE OR REPLACE TABLE mart_user_segment AS
SELECT
  DATE '2026-05-20' AS target_date, user_id,
  y.user_seg AS user_seg_from,
  t.user_seg
FROM segment_at(DATE '2026-05-20') AS t
JOIN segment_at(DATE '2026-05-20' - INTERVAL 1 DAY) AS y USING (user_id)
ORDER BY user_id;
