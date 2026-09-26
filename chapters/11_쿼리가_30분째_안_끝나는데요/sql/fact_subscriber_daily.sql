-- 실습 3) fact 2 — 일별 활성 구독 스냅샷 (one row per 구독 중인 유저 × 날짜)
--
-- 구매·갱신 기간을 날짜로 펼치고 해지·환불 이후를 제외한다. semi-additive 한 '활성 구독자 수'의 원천.
-- 전제: fact_subscription_events.sql 을 먼저 실행.
-- 전제: 챕터 폴더에서 실행 (read_csv_auto 경로가 data/ 기준)

-- fact 2: 일별 활성 구독 스냅샷 (grain: one row per 구독 중인 유저 × 날짜)
CREATE OR REPLACE TABLE fact_subscriber_daily AS
WITH periods AS (
  SELECT user_id, sku_id, is_trial, event_date AS start_date,
         event_date + period_days - 1 AS end_date
  FROM fact_subscription_events WHERE event_type IN ('purchase', 'renewal')
),
ends AS (
  SELECT user_id, MIN(event_date) AS end_date
  FROM fact_subscription_events WHERE event_type IN ('cancel', 'refund') GROUP BY user_id
),
expanded AS (
  SELECT user_id, sku_id, is_trial,
         CAST(UNNEST(generate_series(start_date, end_date, INTERVAL 1 DAY)) AS DATE) AS date
  FROM periods
)
SELECT x.date, x.user_id, x.sku_id, x.is_trial
FROM expanded x LEFT JOIN ends e USING (user_id)
WHERE (e.end_date IS NULL OR x.date < e.end_date) AND x.date <= DATE '2026-06-29'
QUALIFY ROW_NUMBER() OVER (PARTITION BY x.date, x.user_id ORDER BY x.is_trial) = 1;   -- 유니크 키 (date, user_id)
