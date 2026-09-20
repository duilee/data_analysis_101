-- 프로퍼티 채움률(not-null 비율)이 일주일 전보다 60% 넘게 떨어진 (이벤트, 프로퍼티)를 찾는다
WITH params AS (SELECT DATE '2026-08-28' AS basis_date, 0.6 AS threshold, 50 AS min_cnt),
d1 AS (SELECT m.* FROM mart_event_param_daily m, params p WHERE m.event_date = p.basis_date),
d8 AS (SELECT m.* FROM mart_event_param_daily m, params p WHERE m.event_date = p.basis_date - INTERVAL 7 DAY)
SELECT coalesce(d1.not_null_ratio, 0) / d8.not_null_ratio - 1 AS null_ratio_diff,
       d8.platform,
       d8.event_name,
       d8.param_key,
       d8.not_null_ratio AS prev_not_null_ratio,
       coalesce(d1.not_null_ratio, 0) AS not_null_ratio,
       coalesce(d1.event_cnt, 0) AS event_cnt
FROM d8
LEFT JOIN d1 USING (event_name, platform, param_key), params p
WHERE d1.event_cnt > p.min_cnt          -- 기준일에 온 이벤트의 값만 본다 (안 온 것은 2단계 몫)
  AND d8.not_null_ratio > 0
  AND coalesce(d1.not_null_ratio, 0) / d8.not_null_ratio - 1 < -p.threshold
ORDER BY null_ratio_diff;
