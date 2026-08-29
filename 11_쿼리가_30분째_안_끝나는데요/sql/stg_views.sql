-- 실습 2) staging — 소스마다 뷰 하나씩
--
-- 이름·타입 정리, 재전송 중복 제거, 시스템 이벤트 제외만 한다. 조인·집계·비즈니스 로직 없음.
-- 전제: 챕터 폴더에서 실행 (read_csv_auto 경로가 data/ 기준)

CREATE OR REPLACE VIEW stg_events AS
SELECT event_id, user_id, event_name, session_id,
       CAST(event_time AS TIMESTAMP)    AS event_time,
       CAST(received_time AS TIMESTAMP) AS received_time,
       CAST(event_time AS DATE)         AS event_date,
       CAST(received_time AS DATE)      AS received_date,
       properties
FROM read_csv_auto('data/events.csv')
WHERE user_id IS NOT NULL
  AND event_name NOT LIKE 'system%'                                            -- 시스템 이벤트 제외
  AND event_name <> 'heartbeat'
QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY received_time) = 1;  -- 재전송 중복 제거

CREATE OR REPLACE VIEW stg_subscription_events AS
SELECT sub_event_id, user_id, LOWER(event_type) AS event_type, sku_id, is_trial,
       CAST(event_time AS TIMESTAMP)    AS event_time,
       CAST(received_time AS TIMESTAMP) AS received_time,
       CAST(event_time AS DATE)         AS event_date,
       CAST(received_time AS DATE)      AS received_date,
       price_local, UPPER(currency) AS currency
FROM read_csv_auto('data/subscription_events.csv')
QUALIFY ROW_NUMBER() OVER (PARTITION BY sub_event_id ORDER BY received_time) = 1;

CREATE OR REPLACE VIEW stg_user_snapshots AS
SELECT snapshot_date, user_id, LOWER(platform) AS platform, UPPER(country) AS country,
       app_version, install_date
FROM read_csv_auto('data/user_snapshots.csv');

CREATE OR REPLACE VIEW stg_sku AS
SELECT sku_id, duration_days, trial_days, base_price_usd FROM read_csv_auto('data/sku.csv');

CREATE OR REPLACE VIEW stg_exchange_rates AS
SELECT date, UPPER(currency) AS currency, rate_to_usd FROM read_csv_auto('data/exchange_rates.csv');
