-- 기준일(D-2)과 일주일 전(D-9)의 이벤트 수를 비교해 ±60% 넘게 변한 이벤트를 찾는다
WITH params AS (SELECT DATE '2026-08-28' AS basis_date, 0.6 AS threshold,
                50 AS min_cnt),
d1 AS (SELECT m.* FROM mart_event_daily m, params p
       WHERE m.event_date = p.basis_date),
d8 AS (SELECT m.* FROM mart_event_daily m, params p
       WHERE m.event_date = p.basis_date - INTERVAL 7 DAY),
diff AS (
  SELECT coalesce(d1.event_cnt, 0) * 1.0 / d8.event_cnt - 1 AS diff_ratio,
         d8.platform, d8.event_name,
         d8.event_cnt AS prev_event_cnt,
         coalesce(d1.event_cnt, 0) AS event_cnt
  FROM d8 LEFT JOIN d1 USING (event_name, platform)
)
SELECT diff.* FROM diff, params p
WHERE (prev_event_cnt > p.min_cnt OR event_cnt > p.min_cnt)
  AND abs(diff_ratio) > p.threshold
ORDER BY diff_ratio;
