-- 프로퍼티 채움률(not-null 비율)이 일주일 전보다 60% 넘게 떨어진 (이벤트, 프로퍼티)를 찾는다
WITH params AS (SELECT DATE '2026-08-28' AS basis_date, 0.6 AS threshold,
                50 AS min_cnt),
d1 AS (SELECT m.* FROM mart_event_param_daily m, params p
       WHERE m.event_date = p.basis_date),
d8 AS (SELECT m.* FROM mart_event_param_daily m, params p
       WHERE m.event_date = p.basis_date - INTERVAL 7 DAY),
diff AS (
  SELECT coalesce(d1.not_null_ratio, 0) / d8.not_null_ratio - 1
           AS null_ratio_diff,
         d8.platform, d8.event_name, d8.param_key,
         d8.not_null_ratio AS prev_not_null_ratio,
         coalesce(d1.not_null_ratio, 0) AS not_null_ratio,
         coalesce(d1.event_cnt, 0) AS event_cnt
  FROM d8 LEFT JOIN d1 USING (event_name, platform, param_key)
)
SELECT diff.* FROM diff, params p
WHERE event_cnt > p.min_cnt
  AND prev_not_null_ratio > 0
  AND null_ratio_diff < -p.threshold
ORDER BY null_ratio_diff;
