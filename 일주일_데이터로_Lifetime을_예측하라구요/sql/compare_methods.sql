-- 세 가지 lifetime 추정 방법을 하나의 SQL로 나란히 비교 (단독 실행용)
--
-- 노트북은 앞 단계에서 계산한 결과(heuristic / catalog_match / mature)를 pandas 로
-- 재사용해 표를 만들지만, SQL만으로 한 번에 보고 싶을 때는 이 쿼리를 쓴다.
-- (cohort_retention 테이블과 lifetime_catalog 등록이 선행되어야 한다)
-- 휴리스틱의 r은 별도 CTE로 분리해 계산한다 — 집계함수 안에 윈도우 함수를 중첩하면
-- DuckDB에서 실행되지 않고, WHERE가 윈도우보다 먼저 적용되어 r이 달라질 수 있기 때문.

WITH params AS (
  SELECT 51.5 AS lifetime_mature, 1.875 AS area_d1_d7_mature
),
obs AS (
  SELECT
    SUM(retention) FILTER (WHERE day BETWEEN 1 AND 7) AS area_d1_d7,
    MAX(CASE WHEN day = 1 THEN retention END)         AS d1,
    MAX(CASE WHEN day = 3 THEN retention END)         AS d3,
    MAX(CASE WHEN day = 7 THEN retention END)         AS d7
  FROM cohort_retention
),
daily_ratios AS (
  SELECT day, retention / LAG(retention) OVER (ORDER BY day) AS ratio
  FROM cohort_retention
),
r_estimate AS (
  SELECT AVG(ratio) AS r FROM daily_ratios WHERE day BETWEEN 5 AND 7
),
heuristic AS (
  SELECT obs.area_d1_d7 + obs.d7 * r.r / (1 - r.r) AS lifetime_estimate
  FROM obs, r_estimate r
),
lookup_match AS (
  SELECT cat.lifetime AS lifetime_estimate
  FROM lifetime_catalog AS cat, obs
  ORDER BY POW(cat.D1 - obs.d1, 2) + POW(cat.D3 - obs.d3, 2) + POW(cat.D7 - obs.d7, 2)
  LIMIT 1
),
mature_extrap AS (
  SELECT p.lifetime_mature * obs.area_d1_d7 / p.area_d1_d7_mature AS lifetime_estimate
  FROM params p, obs
)
SELECT 'Case 1. 이탈률 휴리스틱'      AS method, ROUND(lifetime_estimate, 2) AS lifetime FROM heuristic
UNION ALL
SELECT 'Case 2. 리텐션 카탈로그 매칭', ROUND(lifetime_estimate, 2)           FROM lookup_match
UNION ALL
SELECT 'Case 3. 장기 코호트 직접 측정', ROUND(lifetime_estimate, 2)          FROM mature_extrap;
