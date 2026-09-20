-- 일별 이벤트 마트: 날짜·플랫폼·이벤트별 건수와 유저 수
SELECT CAST(event_time AS DATE) AS event_date,
       platform,
       event_name,
       COUNT(*)               AS event_cnt,
       COUNT(DISTINCT user_id) AS user_cnt
FROM event_log
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
