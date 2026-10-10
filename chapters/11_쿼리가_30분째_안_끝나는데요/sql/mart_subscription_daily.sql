-- 11.6.5) mart — 날짜 × 플랫폼 × 국가 × SKU × 체험 여부 집계 (파티션 하나 = 배치 한 번)
--
-- 노트북의 MART_SQL 에서 {partition_date} 를 2026-06-14 으로 전개한 예시. 배치는 날짜를 바꿔 가며 이 문을 반복한다.
-- 전제: 11.6.4의 팩트·디멘션이 있어야 하고, 아래 CREATE TABLE 을 먼저 실행.
-- 전제: 챕터 폴더에서 실행 (read_csv_auto 경로가 data/ 기준)

CREATE OR REPLACE TABLE mart_subscription_daily (
  date DATE, platform VARCHAR, country VARCHAR, sku_id VARCHAR, is_trial BOOLEAN,
  new_count BIGINT, renewal_count BIGINT, cancel_count BIGINT, refund_count BIGINT,
  revenue_usd DOUBLE, active_subscribers BIGINT
);

DELETE FROM mart_subscription_daily WHERE date = DATE '2026-06-14';
INSERT INTO mart_subscription_daily
WITH ev AS (                                  -- 그날의 구독 이벤트
  SELECT f.event_date AS date, d.platform, d.country, f.sku_id, f.is_trial,
         f.event_type, f.price_usd, NULL AS active_user
  FROM fact_subscription_events f
  JOIN dim_user_daily d ON d.user_id = f.user_id AND d.date = f.event_date
  WHERE f.event_date = DATE '2026-06-14'
),
act AS (                                      -- 그날의 활성 구독자
  SELECT a.date, d.platform, d.country, a.sku_id, a.is_trial,
         NULL AS event_type, 0 AS price_usd, a.user_id AS active_user
  FROM fact_subscriber_daily a
  JOIN dim_user_daily d ON d.user_id = a.user_id AND d.date = a.date
  WHERE a.date = DATE '2026-06-14'
)
SELECT date, platform, country, sku_id, is_trial,
       COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS new_count,
       COUNT(CASE WHEN event_type = 'renewal'  THEN 1 END) AS renewal_count,
       COUNT(CASE WHEN event_type = 'cancel'   THEN 1 END) AS cancel_count,
       COUNT(CASE WHEN event_type = 'refund'   THEN 1 END) AS refund_count,
       SUM(price_usd)                                      AS revenue_usd,
       COUNT(DISTINCT active_user)                         AS active_subscribers
FROM (SELECT * FROM ev UNION ALL SELECT * FROM act)
GROUP BY ALL;
