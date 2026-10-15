-- 6.3.2. order_number에서 유저(pid)와 누적 결제 회차(order_cnt) 식별
-- prefix('..' 앞부분)가 동일 유저, row_number()가 결제 회차.
-- 실습 데이터는 suffix가 없거나(첫 결제) '..1', '..2'로 붙는(갱신) 구조(실제 Google Play는 첫 갱신이 '..0').
-- 실데이터는 업그레이드·재구독 때 새 주문번호가 생겨 prefix만으로는 같은 유저로 이어지지 않는다(본문 6.3.2 참고).
-- (노트북은 이 결과를 orders 뷰로 만들어 이후 단계가 재사용한다)
SELECT
    split_part(order_number, '..', 1)  AS pid
  , order_charged_date
  , product_id
  , sales_amount_krw
  , row_number() OVER (PARTITION BY split_part(order_number, '..', 1)
                       ORDER BY order_charged_date) AS order_cnt
FROM sales
