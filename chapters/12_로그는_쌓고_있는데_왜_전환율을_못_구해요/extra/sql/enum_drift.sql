-- enum 프로퍼티에 허용값 밖의 값이 들어온 경우
WITH enum_props AS (
  SELECT property_name, string_split(allowed_values, '|') AS allowed
  FROM taxonomy_properties
  WHERE data_type = 'enum' AND allowed_values <> ''
),
observed AS (
  SELECT p.property_name,
         json_extract_string(l.properties, '$.' || p.property_name) AS value,
         l.event_name, l.platform, l.app_version
  FROM event_log l
  JOIN enum_props p ON json_extract_string(l.properties, '$.' || p.property_name) IS NOT NULL
)
SELECT o.property_name, o.value, o.event_name, o.platform, o.app_version, COUNT(*) AS events
FROM observed o
JOIN enum_props p USING (property_name)
WHERE NOT list_contains(p.allowed, o.value)
GROUP BY ALL
ORDER BY events DESC;
