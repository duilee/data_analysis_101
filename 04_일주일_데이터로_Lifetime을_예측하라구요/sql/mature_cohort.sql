-- Case 3. 장기 코호트 직접 측정
-- 1년 전 장기 코호트의 실측 lifetime을, 신규 코호트의 D1~D7 면적 비율만큼 보정한다.
--   lifetime_new ≈ lifetime_mature × (신규 D1~D7 면적 / 장기 D1~D7 면적)
-- 장기 코호트의 두 집계값은 사전 계산된 상수로 받는다(BigQuery DECLARE 대신 params CTE 사용).

WITH params AS (
  SELECT
    51.5  AS lifetime_mature,    -- 장기 코호트의 1년치 실측 lifetime = SUM(retention) over D1~D365
    1.875 AS area_d1_d7_mature   -- 장기 코호트의 D1~D7 면적 = SUM(retention) over D1~D7
),
new_area AS (
  SELECT SUM(retention) AS area_d1_d7_new
  FROM cohort_retention
  WHERE day BETWEEN 1 AND 7
)
SELECT
  p.lifetime_mature                                                    AS lifetime_mature,
  p.area_d1_d7_mature                                                  AS area_d1_d7_mature,
  ROUND(n.area_d1_d7_new, 4)                                           AS area_d1_d7_new,
  ROUND(n.area_d1_d7_new / p.area_d1_d7_mature, 4)                     AS scaling_factor,
  ROUND(p.lifetime_mature * n.area_d1_d7_new / p.area_d1_d7_mature, 2) AS lifetime_estimate
FROM new_area AS n, params AS p;
