-- 6.3.4. 월별 MRR 분해: new / renew / reactivation / expansion / contraction / churn
-- 유저×월 단위로 결제를 모은 뒤 전월과 FULL OUTER JOIN:
--   양쪽에 있으면 계속 구독(renew + 업/다운그레이드 증감), 전월에만 있으면 churn.
-- 준비: sales 테이블(data/subscription_sales.csv)만 있으면 단독 실행 가능.
-- (단독 실행용 전체 쿼리 — 노트북은 orders/classified/monthly/paired 뷰 체인으로
--  같은 계산을 단계화하고, '두 달 모두 결제' 조건은 stayed 플래그로 한 번만 계산한다)
WITH payments AS (
    SELECT
        split_part(order_number, '..', 1)  AS pid
      , date_trunc('month', order_charged_date) AS month
      , sales_amount_krw                   AS amt
      , CASE WHEN row_number() OVER (PARTITION BY split_part(order_number, '..', 1)
                                     ORDER BY order_charged_date) = 1 THEN 'new'
             WHEN order_charged_date
                  - lag(order_charged_date) OVER (PARTITION BY split_part(order_number, '..', 1)
                                                  ORDER BY order_charged_date) < 32 THEN 'renew'
             ELSE 'reactivation' END AS pay_type
    FROM sales
),
classified AS (   -- 유저×월 집계: 같은 달의 여러 결제(월중 플랜 변경 등)를 한 행으로
    SELECT
        pid
      , month
      , sum(amt) AS amt
      -- pay_type 우선순위: new > reactivation > renew (알파벳순과 우연히 일치)
      , min(pay_type) AS pay_type
    FROM payments
    GROUP BY pid, month
),
paired AS (
    SELECT
        coalesce(c.month, p.month + INTERVAL 1 MONTH) AS month
      , c.amt AS amt             -- 이번 달 결제액 (없으면 NULL = 이탈)
      , p.amt AS prev_amt        -- 전월 결제액 (없으면 NULL = 신규/복귀)
      , c.amt - p.amt AS delta   -- 증감분 (expansion/contraction 계산용)
      , c.pay_type
      , c.amt IS NOT NULL AND p.amt IS NOT NULL AS stayed  -- 두 달 모두 결제
    FROM classified c
    FULL OUTER JOIN classified p
      ON c.pid = p.pid AND p.month = c.month - INTERVAL 1 MONTH
)
SELECT
    month
  , sum(amt)                                            AS mrr
  , sum(CASE pay_type WHEN 'new' THEN amt END)          AS new_mrr
  , sum(CASE pay_type WHEN 'reactivation' THEN amt END) AS reactivation_mrr
  , sum(CASE WHEN stayed THEN least(amt, prev_amt) END) AS renew_mrr
  , sum(CASE WHEN stayed THEN greatest(delta, 0) END)   AS expansion_mrr
  , sum(CASE WHEN stayed THEN greatest(-delta, 0) END)  AS contraction_mrr
  , sum(CASE WHEN amt IS NULL THEN prev_amt END)        AS churn_mrr
  , sum(prev_amt)                                       AS baseline_mrr
FROM paired
-- 마지막 월 다음에 생기는 '유령 월'(전월만 있는 행) 제거
WHERE month <= (SELECT max(month) FROM classified)
GROUP BY month
ORDER BY month
