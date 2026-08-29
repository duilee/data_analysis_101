-- 실습 2. 결제 건을 new / renew / reactivation으로 분류
-- 직전 결제일과의 간격이 한 주기(약 30일) 안이면 renew, 그보다 길면 reactivation.
-- [내 데이터 적용] 월구독이 아니면 32일 임계값을 결제 주기에 맞게 조정합니다.
-- (노트북은 이 결과를 classified 뷰로 만들어 MRR 분해가 재사용한다)
WITH orders AS (
    SELECT
        split_part(order_number, '..', 1)  AS pid
      , order_charged_date
      , product_id
      , sales_amount_krw
      , row_number() OVER (PARTITION BY split_part(order_number, '..', 1)
                           ORDER BY order_charged_date) AS order_cnt
      , lag(order_charged_date) OVER (PARTITION BY split_part(order_number, '..', 1)
                                      ORDER BY order_charged_date) AS prev_date
    FROM sales
)
SELECT *
     , CASE WHEN order_cnt = 1 THEN 'new'
            WHEN date_diff('day', prev_date, order_charged_date) < 32 THEN 'renew'
            ELSE 'reactivation' END AS pay_type
FROM orders
