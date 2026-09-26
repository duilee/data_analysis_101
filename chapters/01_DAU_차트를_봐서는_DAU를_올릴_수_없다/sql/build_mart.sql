-- 실습 2, 단계 2) 유저 세그먼트 마트 생성 (mart_user_segment)
--
-- build_metrics_daily.sql 이 만든 날짜별 지표에 classify_segment.sql(실습 1.2)과 같은 CASE를
-- 적용해 날짜별 세그먼트(user_seg)를 만들고, 어제 세그먼트(user_seg_from)는 윈도우 함수
-- lag 로 같은 유저의 바로 앞 날짜 행에서 가져온다. 오늘 막 가입한 유저는 앞 행이 없어 NULL.
-- 임계값(new 윈도·heavy 컷·경계일)을 바꿀 때는 classify_segment.sql 과 이 파일의 CASE 두 곳을 똑같이 고친다.
-- build_metrics_daily.sql 을 먼저 실행할 것.

CREATE OR REPLACE TABLE mart_user_segment AS
WITH seg AS (
  SELECT target_date, user_id,
    CASE
      WHEN days_since_signup < 7           THEN 'new'
      WHEN active_day_count >= 5           THEN 'heavy'
      WHEN active_day_count BETWEEN 1 AND 4 THEN 'light'
      WHEN last_active_date >= target_date - INTERVAL 30 DAY THEN 'risk'
      ELSE 'dormant'
    END AS user_seg
  FROM user_metrics_daily
)
SELECT
  target_date, user_id,
  lag(user_seg) OVER (PARTITION BY user_id ORDER BY target_date)
    AS user_seg_from,
  user_seg
FROM seg;
