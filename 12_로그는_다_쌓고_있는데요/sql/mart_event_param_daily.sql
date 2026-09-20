-- 일별 프로퍼티 마트: 이벤트마다 붙기로 한 프로퍼티가 실제로 채워진 비율
WITH keys AS (
  SELECT property_name AS param_key,
         unnest(string_split(events, '|')) AS event_name
  FROM taxonomy_properties
  WHERE scope = 'event' AND events <> ''
)
SELECT CAST(l.event_time AS DATE) AS event_date,
       l.platform,
       l.event_name,
       k.param_key,
       COUNT(*) AS event_cnt,
       COUNT(json_extract_string(l.properties, '$.' || k.param_key)) AS not_null_event_cnt,
       COUNT(json_extract_string(l.properties, '$.' || k.param_key)) * 1.0 / COUNT(*) AS not_null_ratio
FROM event_log l
JOIN keys k USING (event_name)
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3, 4;
