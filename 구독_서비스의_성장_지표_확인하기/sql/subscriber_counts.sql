-- 실습 5. 같은 로직을 '사람 수' 단위로 — 업/다운그레이드는 구독자 수를 바꾸지 않는다
WITH payments AS (
    SELECT
        split_part(order_number, '..', 1)  AS pid
      , date_trunc('month', order_charged_date) AS month
      , CASE WHEN row_number() OVER (PARTITION BY split_part(order_number, '..', 1)
                                     ORDER BY order_charged_date) = 1 THEN 'new'
             WHEN date_diff('day',
                            lag(order_charged_date) OVER (PARTITION BY split_part(order_number, '..', 1)
                                                          ORDER BY order_charged_date),
                            order_charged_date) < 32 THEN 'renew'
             ELSE 'reactivation' END AS pay_type
    FROM sales
),
classified AS (   -- 유저×월 집계: 같은 달 결제가 여러 건이어도 구독자는 1명으로 센다
    SELECT
        pid
      , month
      , min(pay_type) AS pay_type   -- 우선순위 new > reactivation > renew (알파벳순과 우연히 일치)
    FROM payments
    GROUP BY pid, month
),
paired AS (
    SELECT
        coalesce(c.month, p.month + INTERVAL 1 MONTH) AS month
      , c.pid  AS cur_pid
      , p.pid  AS prev_pid
      , c.pay_type
    FROM classified c
    FULL OUTER JOIN classified p
      ON c.pid = p.pid AND p.month = c.month - INTERVAL 1 MONTH
)
SELECT
    month
  , count(cur_pid)                                                  AS subscribers
  , count(CASE WHEN pay_type = 'new'          THEN 1 END)           AS new_subs
  , count(CASE WHEN pay_type = 'reactivation' THEN 1 END)           AS reactivation_subs
  , count(CASE WHEN cur_pid IS NULL THEN 1 END)                     AS churned_subs
FROM paired
WHERE month <= (SELECT max(month) FROM classified)
GROUP BY month
ORDER BY month
