-- 11.6.4) fact 1 — 구독 이벤트 (one row per 구매·갱신·해지·환불)
--
-- 환율 조인으로 price_usd, SKU 조인으로 기간(체험은 trial_days)을 붙인다.
-- 전제: stg_views.sql · dim_tables.sql 을 먼저 실행.
-- 전제: 챕터 폴더에서 실행 (read_csv_auto 경로가 data/ 기준)

-- fact 1: 구독 이벤트 (grain: one row per 구매·갱신·해지·환불 이벤트)
CREATE OR REPLACE TABLE fact_subscription_events AS
SELECT s.sub_event_id, s.event_date, s.received_date, s.user_id, s.sku_id, s.event_type, s.is_trial,
       s.event_time, s.price_local, s.currency,
       s.price_local * r.rate_to_usd AS price_usd,                            -- 환율 조인
       CAST(CASE WHEN s.is_trial THEN k.trial_days ELSE k.duration_days END AS INTEGER) AS period_days
FROM stg_subscription_events s
LEFT JOIN stg_exchange_rates r ON r.date = s.event_date AND r.currency = s.currency
JOIN dim_sku k USING (sku_id);
