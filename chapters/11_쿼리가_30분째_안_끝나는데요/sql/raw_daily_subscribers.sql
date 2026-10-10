-- 11.6.2) raw에서 바로 뽑기 — 마트 없이 한 쿼리로 답하기
--
-- 다섯 CSV를 직접 조인해 날짜·플랫폼·국가별 활성 구독자 수와 매출(USD)을 구한다.
-- 중복 제거·통화 정리·기간 펼치기·스냅샷 조인·환율 조인이 전부 한 쿼리에 들어 있다.
-- 전제: 챕터 폴더에서 실행 (read_csv_auto 경로가 data/ 기준)

WITH sub AS (                     -- 구독 이벤트: 중복 제거 + 이름·통화 정리 + SKU 기간 붙이기
  SELECT s.user_id, LOWER(s.event_type) AS event_type, s.sku_id,
         CAST(s.event_time AS TIMESTAMP) AS event_time,
         s.price_local, UPPER(s.currency) AS currency,
         CAST(CASE WHEN s.is_trial THEN k.trial_days ELSE k.duration_days END AS INTEGER) AS period_days
  FROM read_csv_auto('data/subscription_events.csv') s
  JOIN read_csv_auto('data/sku.csv') k USING (sku_id)
  QUALIFY ROW_NUMBER() OVER (PARTITION BY s.sub_event_id ORDER BY s.received_time) = 1
),
periods AS (                      -- 구매·갱신 1건 = 구독 기간 1개
  SELECT user_id, CAST(event_time AS DATE) AS start_date,
         CAST(event_time AS DATE) + period_days - 1 AS end_date
  FROM sub WHERE event_type IN ('purchase', 'renewal')
),
ends AS (                         -- 해지·환불은 그날로 종료
  SELECT user_id, MIN(CAST(event_time AS DATE)) AS end_date
  FROM sub WHERE event_type IN ('cancel', 'refund') GROUP BY user_id
),
expanded AS (                     -- 기간을 날짜 하나하나로 펼치기
  SELECT user_id, CAST(UNNEST(generate_series(start_date, end_date, INTERVAL 1 DAY)) AS DATE) AS date
  FROM periods
),
active AS (
  SELECT DISTINCT x.user_id, x.date
  FROM expanded x LEFT JOIN ends e USING (user_id)
  WHERE (e.end_date IS NULL OR x.date < e.end_date) AND x.date <= DATE '2026-06-29'
),
snap AS (                         -- 그날 기준 유저 속성
  SELECT snapshot_date, user_id, platform, UPPER(country) AS country
  FROM read_csv_auto('data/user_snapshots.csv')
),
revenue AS (                      -- 그날 결제액을 USD 로 환산 (환불은 음수)
  SELECT CAST(s.event_time AS DATE) AS date, s.user_id,
         SUM(s.price_local * r.rate_to_usd) AS revenue_usd
  FROM sub s
  JOIN read_csv_auto('data/exchange_rates.csv') r
    ON r.date = CAST(s.event_time AS DATE) AND r.currency = s.currency
  GROUP BY 1, 2
)
SELECT a.date, sn.platform, sn.country,
       COUNT(DISTINCT a.user_id)        AS active_subscribers,
       COALESCE(SUM(rv.revenue_usd), 0) AS revenue_usd
FROM active a
JOIN snap sn ON sn.user_id = a.user_id AND sn.snapshot_date = a.date
LEFT JOIN revenue rv ON rv.user_id = a.user_id AND rv.date = a.date
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
