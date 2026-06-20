-- Case 1. 이탈률 휴리스틱
-- 신규 코호트의 D1~D7 면적에다, D7 이후의 무한 등비급수 꼬리를 더해 lifetime을 추정한다.
--   lifetime ≈ (D1 + D2 + ... + D7) + D7 × r / (1 − r)
-- r 은 후반부 며칠치 일별 retention 비율(D5/D4, D6/D5, D7/D6)의 평균.

-- 1) D1 ~ D7의 면적 (직접 관측된 부분)
WITH observed_area AS (
  SELECT SUM(retention) AS area_d1_d7
  FROM cohort_retention
  WHERE day BETWEEN 1 AND 7
),
-- 2) 후반 며칠의 일별 retention 비율을 모아 r 추정
--    (LAG는 8일치 전체에서 계산한 뒤 day 5~7만 골라 평균낸다)
daily_ratios AS (
  SELECT
    day,
    retention,
    retention / LAG(retention) OVER (ORDER BY day) AS ratio
  FROM cohort_retention
),
r_estimate AS (
  SELECT AVG(ratio) AS r
  FROM daily_ratios
  WHERE day BETWEEN 5 AND 7  -- D5/D4, D6/D5, D7/D6
),
-- 3) D7과 r로 꼬리 면적 계산
d7_value AS (
  SELECT retention AS d7
  FROM cohort_retention
  WHERE day = 7
)
SELECT
  ROUND(o.area_d1_d7, 3)                          AS observed_d1_d7_area,
  ROUND(d.d7, 3)                                  AS d7,
  ROUND(r.r, 4)                                   AS estimated_r,
  ROUND(d.d7 * r.r / (1 - r.r), 2)                AS extrapolated_tail_area,
  ROUND(o.area_d1_d7 + d.d7 * r.r / (1 - r.r), 2) AS lifetime_estimate
FROM observed_area o, r_estimate r, d7_value d;
