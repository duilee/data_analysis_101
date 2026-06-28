-- 실습 1) EDA로 선행지표 후보 찾기
-- 신규 설치(D0) 유저를 D7 잔존/비잔존으로 라벨링하고, D0~D1 구간 행동의
-- 발생 비중(share)과 평균 횟수(avg_event_count)를 코호트별로 비교한다.
-- 잔존 유저가 특별히 많이/자주 하는 행동을 선행지표 후보로 추려 본다.
WITH log_data AS (
    -- raw 이벤트 로그를 (유저, 이벤트, 화면, 일자) 단위 발생 횟수로 집계
    SELECT event_date
         , event_name
         , screen_name
         , user_id
         , SUM(event_count) AS event_count
         , MAX(description)  AS description
    FROM event_log
    WHERE event_date BETWEEN DATE '2026-01-01' AND DATE '2026-01-31'
    GROUP BY 1, 2, 3, 4
),
retention_label AS (
    -- 설치(D0) 시점과 D7 잔존 여부를 라벨링
    SELECT i.event_date
         , i.user_id
         , MAX(CASE WHEN date_diff('day', i.event_date, l.event_date) = 7 THEN 1 ELSE 0 END) AS d7_retention_flag
    FROM (
        SELECT event_date, user_id
        FROM log_data
        WHERE event_name = 'application_install'
        GROUP BY 1, 2
    ) AS i
    LEFT JOIN (
        SELECT event_date, user_id FROM log_data GROUP BY 1, 2
    ) AS l
      ON i.user_id = l.user_id
     AND l.event_date > i.event_date
     AND date_diff('day', i.event_date, l.event_date) <= 7
    GROUP BY 1, 2
),
population AS (
    SELECT d7_retention_flag
         , COUNT(DISTINCT user_id) AS total_user_cnt
    FROM retention_label
    GROUP BY 1
),
event_stat AS (
    -- D0 ~ D1 구간의 행동만 집계
    SELECT r.d7_retention_flag
         , l.event_name
         , l.screen_name
         , COUNT(DISTINCT r.user_id) AS user_cnt
         , AVG(l.event_count)        AS avg_event_count
         , MAX(l.description)        AS description
    FROM retention_label AS r
    LEFT JOIN log_data AS l
      ON r.user_id    = l.user_id
     AND l.event_date >= r.event_date
     AND date_diff('day', r.event_date, l.event_date) <= 1
    GROUP BY 1, 2, 3
),
cohort_info AS (
    SELECT e.d7_retention_flag
         , e.event_name
         , e.screen_name
         , e.user_cnt
         , p.total_user_cnt
         , (e.user_cnt * 1.0 / p.total_user_cnt) * 100 AS share
         , e.avg_event_count
    FROM event_stat AS e
    LEFT JOIN population AS p
      ON e.d7_retention_flag = p.d7_retention_flag
)
SELECT event_name
     , screen_name
     , MAX(CASE WHEN d7_retention_flag = 0 THEN share           END) AS d7_ret0_share
     , MAX(CASE WHEN d7_retention_flag = 0 THEN avg_event_count END) AS d7_ret0_avg_cnt
     , MAX(CASE WHEN d7_retention_flag = 1 THEN share           END) AS d7_ret1_share
     , MAX(CASE WHEN d7_retention_flag = 1 THEN avg_event_count END) AS d7_ret1_avg_cnt
     , MAX(CASE WHEN d7_retention_flag = 1 THEN share END)
     - MAX(CASE WHEN d7_retention_flag = 0 THEN share END)           AS share_diff
     , MAX(CASE WHEN d7_retention_flag = 1 THEN avg_event_count END)
     - MAX(CASE WHEN d7_retention_flag = 0 THEN avg_event_count END) AS event_cnt_diff
FROM cohort_info
WHERE event_name IS NOT NULL
GROUP BY 1, 2
HAVING d7_ret1_share >= 10 OR d7_ret0_share >= 10
ORDER BY share_diff DESC
