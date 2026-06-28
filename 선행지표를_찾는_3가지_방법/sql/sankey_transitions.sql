-- 실습 3) 설치 세션의 스텝 전이 + 전이별 D7 잔존율
-- 설치 직후 1시간 이내 이벤트를 순서대로 늘어놓고(연속 중복 제거), 스텝 N → N+1
-- 전이를 만든다. 각 전이를 지나간 유저 수와 그 유저들의 D7 잔존율을 함께 집계해
-- "어느 갈림길에서 잔존이 갈리는지"를 Sankey로 색칠해 본다.
-- (노트북에서는 MAX_STEPS / TOP_K / MIN_USERS 를 변수로 주입한다. 여기서는 기본값 사용.)
WITH base AS (
    SELECT user_id
         , MIN(event_timestamp) AS install_ts
         , MIN(event_date)      AS install_date
    FROM event_log
    WHERE event_name = 'application_install'
    GROUP BY 1
),
user_retention AS (
    SELECT b.user_id
         , MAX(CASE WHEN date_diff('day', b.install_date, e.event_date) = 7 THEN 1 ELSE 0 END) AS d7_retained
    FROM base AS b
    LEFT JOIN event_log AS e ON b.user_id = e.user_id
    GROUP BY 1
),
session_events AS (
    -- 설치 후 1시간 이내 이벤트 + 직전 이벤트(연속 중복 제거용)
    SELECT b.user_id
         , e.event_name
         , e.event_timestamp
         , LAG(e.event_name) OVER (PARTITION BY b.user_id ORDER BY e.event_timestamp) AS prev_event
    FROM base AS b
    JOIN event_log AS e
      ON b.user_id = e.user_id
     AND e.event_timestamp >= b.install_ts
     AND e.event_timestamp <= b.install_ts + INTERVAL 1 HOUR
),
deduped AS (
    SELECT user_id, event_name, event_timestamp
    FROM session_events
    WHERE prev_event IS NULL OR event_name != prev_event
),
user_steps AS (
    SELECT user_id
         , event_name
         , event_timestamp
         , ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_timestamp) AS step_num
    FROM deduped
    QUALIFY step_num <= 10               -- MAX_STEPS
),
event_volume AS (
    -- 스텝 위치별 이벤트 유저 수 순위 (상위 K개만 남기고 나머지는 ETC)
    SELECT step_num
         , event_name
         , COUNT(DISTINCT user_id) AS user_cnt
         , ROW_NUMBER() OVER (PARTITION BY step_num ORDER BY COUNT(DISTINCT user_id) DESC) AS rnk
    FROM user_steps
    GROUP BY 1, 2
),
top_events AS (
    SELECT step_num, event_name FROM event_volume WHERE rnk <= 6   -- TOP_K
),
steps_resolved AS (
    SELECT s.user_id
         , s.step_num
         , CASE WHEN t.event_name IS NOT NULL THEN s.event_name ELSE 'ETC' END AS event_name
    FROM user_steps AS s
    LEFT JOIN top_events AS t
      ON s.step_num = t.step_num
     AND s.event_name = t.event_name
),
transitions AS (
    SELECT a.user_id
         , a.step_num                                          AS from_step
         , CAST(a.step_num AS VARCHAR) || '-' || a.event_name  AS source
         , CAST(b.step_num AS VARCHAR) || '-' || b.event_name  AS target
    FROM steps_resolved AS a
    JOIN steps_resolved AS b
      ON a.user_id = b.user_id
     AND b.step_num = a.step_num + 1
)
SELECT t.from_step
     , t.source
     , t.target
     , COUNT(DISTINCT t.user_id) AS user_count
     , COUNT(DISTINCT CASE WHEN r.d7_retained = 1 THEN t.user_id END) * 100.0
       / NULLIF(COUNT(DISTINCT t.user_id), 0) AS d7_retention
FROM transitions AS t
LEFT JOIN user_retention AS r ON t.user_id = r.user_id
GROUP BY 1, 2, 3
HAVING COUNT(DISTINCT t.user_id) >= 20    -- MIN_USERS
ORDER BY from_step, user_count DESC
