-- Case 2. 리텐션 카탈로그 매칭
-- 미리 만들어 둔 곡선 카탈로그(lifetime_catalog)에서, 신규 코호트의 관측 (D1, D3, D7)과
-- SSE(제곱오차의 합)가 최소가 되는 행을 찾아 그 행의 lifetime을 추정치로 가져온다.
--   (lifetime_catalog 은 노트북에서 멱함수 D_t = D1 * t^(-b) 격자로 생성해 등록한 3,456행 테이블)

WITH new_obs AS (
  SELECT
    MAX(CASE WHEN day = 1 THEN retention END) AS d1,
    MAX(CASE WHEN day = 3 THEN retention END) AS d3,
    MAX(CASE WHEN day = 7 THEN retention END) AS d7
  FROM cohort_retention
),
errors AS (
  SELECT cat.D1, cat.b, cat.lifetime,
         POW(cat.D1 - obs.d1, 2) + POW(cat.D3 - obs.d3, 2)
           + POW(cat.D7 - obs.d7, 2) AS sse
  FROM lifetime_catalog AS cat, new_obs AS obs
)
SELECT
  ROUND(D1, 2)       AS matched_d1,
  ROUND(b, 2)        AS matched_b,
  ROUND(sse, 6)      AS sse,
  ROUND(lifetime, 2) AS lifetime_estimate
FROM errors ORDER BY sse LIMIT 1;
