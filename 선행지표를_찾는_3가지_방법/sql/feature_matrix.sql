-- 실습 2) 유저별 행동 피처 행렬 + D7 잔존 라벨
-- 설치 첫 세션(D0)의 행동을 유저 단위 피처로 집계하고, D7 잔존 여부를 라벨로 붙인다.
-- 이 행렬로 LGBM 모델을 학습시켜 SHAP으로 각 행동의 기여도를 분해한다.
WITH base AS (
    SELECT user_id
         , MIN(event_timestamp) AS install_ts
         , MIN(event_date)      AS install_date
    FROM event_log
    WHERE event_name = 'application_install'
    GROUP BY 1
),
labeled AS (
    -- 설치 이후 7일째 활동이 있으면 D7 잔존
    SELECT b.user_id
         , MAX(CASE WHEN date_diff('day', b.install_date, e.event_date) = 7 THEN 1 ELSE 0 END) AS d7_retention_flag
    FROM base AS b
    LEFT JOIN event_log AS e ON b.user_id = e.user_id
    GROUP BY 1
),
d0_session AS (
    -- 설치 당일(D0) 세션 이벤트만
    SELECT e.user_id
         , e.event_name
         , e.event_count
         , e.event_timestamp
    FROM base AS b
    JOIN event_log AS e
      ON b.user_id = e.user_id
     AND date_diff('day', b.install_date, e.event_date) = 0
),
feat AS (
    SELECT user_id
         , COUNT(*) FILTER (WHERE event_name = 'content_view')      AS content_view
         , COUNT(*) FILTER (WHERE event_name = 'like_content')      AS like_content
         , COUNT(*) FILTER (WHERE event_name = 'search_used')       AS search_used
         , COUNT(*) FILTER (WHERE event_name = 'share_content')     AS share_content
         , COUNT(*) FILTER (WHERE event_name = 'page_view_profile') AS profile_view
         , COUNT(*) FILTER (WHERE event_name = 'settings_open')     AS settings_open
         , COUNT(*) FILTER (WHERE event_name = 'error_popup')       AS error_popup
         , MAX(CASE WHEN event_name = 'tutorial_complete' THEN 1 ELSE 0 END) AS tutorial_complete
         , MAX(CASE WHEN event_name = 'push_allow'        THEN 1 ELSE 0 END) AS push_allow
         -- 설치 세션 길이(초): 첫 이벤트 ~ 마지막 이벤트
         , date_diff('second', MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_sec
    FROM d0_session
    GROUP BY 1
)
SELECT l.d7_retention_flag
     , f.user_id
     , f.tutorial_complete
     , f.push_allow
     , f.content_view
     , f.like_content
     , f.search_used
     , f.share_content
     , f.profile_view
     , f.settings_open
     , f.error_popup
     , f.session_duration_sec
FROM labeled AS l
JOIN feat AS f ON l.user_id = f.user_id
