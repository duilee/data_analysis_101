-- 문서에는 Live인데 로그에는 한 건도 없는 이벤트
SELECT t.event_name, t.event_type, t.version_added, t.description
FROM taxonomy_events t
LEFT JOIN event_log l ON l.event_name = t.event_name
WHERE t.status = 'Live'
GROUP BY 1, 2, 3, 4
HAVING COUNT(l.event_name) = 0
ORDER BY 1;
