-- Case 1. 이탈률 휴리스틱
-- 신규 코호트의 D1~D7 면적에다, D7 이후의 무한 등비급수 꼬리를 더해 lifetime을 추정한다.
--   lifetime ≈ (D1 + D2 + ... + D7) + D7 × r / (1 − r)
-- r 은 후반부 며칠치 일별 retention 비율(D5/D4, D6/D5, D7/D6)의 평균.
-- 1) daily_ratios: LAG로 8일치 전체의 일별 비율을 계산해 두고
-- 2) stats: 관측 면적(D1~D7 합)·D7·r(day 5~7 비율 평균)을 조건부 집계(CASE WHEN)로 한 번에 구한다.

WITH daily_ratios AS (
  SELECT day, retention,
         retention / LAG(retention) OVER (ORDER BY day) AS ratio
  FROM cohort_retention
),
-- 관측 면적·D7·후반부 잔존비율 r 을 한 번에 집계
stats AS (
  SELECT
    SUM(CASE WHEN day BETWEEN 1 AND 7 THEN retention END) AS area_d1_d7,
    MAX(CASE WHEN day = 7 THEN retention END)             AS d7,
    AVG(CASE WHEN day BETWEEN 5 AND 7 THEN ratio END)     AS r
  FROM daily_ratios
)
SELECT
  ROUND(area_d1_d7, 3)                    AS observed_d1_d7_area,
  ROUND(d7, 3)                            AS d7,
  ROUND(r, 4)                             AS estimated_r,
  ROUND(d7 * r / (1 - r), 2)              AS extrapolated_tail_area,
  ROUND(area_d1_d7 + d7 * r / (1 - r), 2) AS lifetime_estimate
FROM stats;
