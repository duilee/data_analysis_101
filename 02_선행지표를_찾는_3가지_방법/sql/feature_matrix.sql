-- 실습 2) 유저별 행동 피처 행렬 + D7 잔존 라벨
-- 설치 첫 세션(D0)의 행동을 유저 단위 피처로 집계하고, D7 잔존 여부를 라벨로 붙인다.
-- 이 행렬로 LGBM 모델을 학습시켜 SHAP으로 각 행동의 기여도를 분해한다.
--
-- 전제: event_log 테이블이 등록돼 있어야 한다 (노트북 준비 셀과 동일):
--   CREATE OR REPLACE TABLE event_log AS SELECT * FROM read_csv_auto('data/event_log.csv');
-- 아래 공용 뷰(installs·d7_label)는 실습 1·2·3 sql 파일마다 같은 정의를 반복해 두어 어느 파일이든 단독 실행된다.

-- 설치(D0) 시점: 유저별 첫 application_install
CREATE OR REPLACE VIEW installs AS
  SELECT user_id, MIN(event_timestamp) AS install_ts, MIN(event_date) AS install_date
  FROM event_log WHERE event_name = 'application_install' GROUP BY 1;

-- D7 잔존 라벨: 설치 7일째에 활동이 있으면 1. 실습 1·2·3 이 모두 이 뷰를 쓴다
CREATE OR REPLACE VIEW d7_label AS
  SELECT i.user_id, i.install_ts, i.install_date,
         MAX(CASE WHEN date_diff('day', i.install_date, e.event_date) = 7 THEN 1 ELSE 0 END) AS d7_retention_flag
  FROM installs AS i LEFT JOIN event_log AS e ON i.user_id = e.user_id
  GROUP BY 1, 2, 3;

WITH d0_session AS (   -- 설치 당일(D0) 세션 이벤트만. D1 이후 행동이 섞이면 미래 정보가 새어 든다(누수)
    SELECT e.user_id, e.event_name, e.event_count, e.event_timestamp
    FROM installs AS i
    JOIN event_log AS e ON i.user_id = e.user_id AND date_diff('day', i.install_date, e.event_date) = 0
),
feat AS (
    SELECT user_id,
           MAX(CASE WHEN event_name = 'tutorial_complete' THEN 1 ELSE 0 END) AS tutorial_complete,
           MAX(CASE WHEN event_name = 'push_allow'        THEN 1 ELSE 0 END) AS push_allow,
           COUNT(*) FILTER (WHERE event_name = 'content_view')      AS content_view,
           COUNT(*) FILTER (WHERE event_name = 'like_content')      AS like_content,
           COUNT(*) FILTER (WHERE event_name = 'search_used')       AS search_used,
           COUNT(*) FILTER (WHERE event_name = 'share_content')     AS share_content,
           COUNT(*) FILTER (WHERE event_name = 'page_view_profile') AS profile_view,
           COUNT(*) FILTER (WHERE event_name = 'settings_open')     AS settings_open,
           COUNT(*) FILTER (WHERE event_name = 'error_popup')       AS error_popup,
           -- 설치 세션 길이(초): 첫 이벤트 ~ 마지막 이벤트
           date_diff('second', MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_sec
    FROM d0_session
    GROUP BY 1
)
SELECT l.d7_retention_flag, f.*
FROM d7_label AS l JOIN feat AS f USING (user_id)
ORDER BY user_id   -- 행 순서를 고정해야 train/test 분할(따라서 정확도)이 실행마다 같다;
