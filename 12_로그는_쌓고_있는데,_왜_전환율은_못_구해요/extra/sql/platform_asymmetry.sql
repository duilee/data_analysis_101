-- 문서에는 양쪽 플랫폼인데 로그는 한쪽에서만 찍히는 이벤트
WITH by_platform AS (
  SELECT event_name,
         COUNT(DISTINCT CASE WHEN platform = 'iOS'     THEN user_id END) AS ios_users,
         COUNT(DISTINCT CASE WHEN platform = 'Android' THEN user_id END) AS android_users
  FROM event_log
  GROUP BY 1
)
SELECT b.event_name, t.platform AS documented, b.ios_users, b.android_users
FROM by_platform b
JOIN taxonomy_events t USING (event_name)
WHERE t.platform = 'iOS|Android'
  AND (b.ios_users = 0 OR b.android_users = 0)
ORDER BY 1;
