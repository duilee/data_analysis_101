-- 장기 코호트 뷰: 획득 후 12개월이 지난 유저 (2024-01 ~ 2024-12 유입) — 4장과 같은 1년 기준
-- ltv_backtest.sql 과 노트북 실습 5(CAC 가이드라인)가 재사용한다 — 먼저 실행할 것
-- 준비: users 테이블 등록 (data/users.csv)
CREATE OR REPLACE VIEW mature AS
SELECT user_id, channel, date_trunc('month', signup_date) AS cohort_month
FROM users WHERE signup_date BETWEEN DATE '2024-01-01' AND DATE '2024-12-31';
