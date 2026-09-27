-- 로그에는 있지만 택소노미 문서에는 없는 이벤트
SELECT l.event_name,
       COUNT(*)                      AS events,
       COUNT(DISTINCT l.user_id)     AS users,
       MIN(l.event_time)             AS first_seen
FROM event_log l
LEFT JOIN taxonomy_events t ON t.event_name = l.event_name
WHERE t.event_name IS NULL
GROUP BY 1
ORDER BY events DESC;
