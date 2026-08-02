-- 실습 1. order_number에서 유저(pid)와 누적 결제 회차(order_cnt) 식별
-- prefix('..' 앞부분)가 동일 유저, row_number()가 결제 회차.
-- suffix가 없거나(첫 결제) '..1', '..2'로 붙는(갱신) 실제 스토어 리포트 구조를 가정.
SELECT
    split_part(order_number, '..', 1)  AS pid
  , order_charged_date
  , product_id
  , sales_amount_krw
  , row_number() OVER (PARTITION BY split_part(order_number, '..', 1)
                       ORDER BY order_charged_date) AS order_cnt
FROM sales
