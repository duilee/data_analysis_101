-- 실습 3) dimension — 유저 일별 스냅샷 · SKU
--
-- 천천히 바뀌는 속성(국가·앱 버전)은 매일 스냅샷으로 쌓고, '지금 상태'는 _latest 뷰로 본다.
-- 전제: stg_views.sql 을 먼저 실행.
-- 전제: 챕터 폴더에서 실행 (read_csv_auto 경로가 data/ 기준)

-- dim: 유저 × 날짜 스냅샷 — 천천히 바뀌는 속성은 그냥 매일 찍어 둔다
CREATE OR REPLACE TABLE dim_user_daily AS
SELECT snapshot_date AS date, user_id, platform, country, app_version, install_date,
       snapshot_date - install_date AS days_since_install
FROM stg_user_snapshots;

CREATE OR REPLACE VIEW dim_user_latest AS                 -- '지금 상태'가 필요할 때
SELECT * FROM dim_user_daily
QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY date DESC) = 1;

CREATE OR REPLACE TABLE dim_sku AS SELECT * FROM stg_sku;
