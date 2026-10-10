-- 회수 곡선: 코호트(채널×획득월)의 경과월별 공헌이익 누적 ÷ CAC 총액
-- 7.3.1의 작도법 5단계를 그대로 구현 (예: 2025-04 검색 코호트)
-- (노트북은 이 쿼리를 채널·획득월 인자를 받는 payback_df 함수로 감싸 표와 차트가 재사용한다)
WITH cohort AS (
    SELECT user_id FROM users
    WHERE channel = 'search'
      AND date_trunc('month', signup_date) = DATE '2025-04-01'
),
cost AS (
    SELECT SUM(media_cost_krw + other_cost_krw) AS cac_total
    FROM marketing_costs
    WHERE channel = 'search' AND month = DATE '2025-04-01'
)
SELECT date_diff('month', DATE '2025-04-01',
                 date_trunc('month', p.payment_date))  AS elapsed
     , SUM(p.amount_krw) * 0.65                        AS monthly_contrib
     , SUM(SUM(p.amount_krw) * 0.65) OVER (ORDER BY date_trunc('month', p.payment_date))
       / (SELECT cac_total FROM cost)                  AS cum_ratio
FROM payments p
JOIN cohort USING (user_id)
GROUP BY date_trunc('month', p.payment_date)
ORDER BY 1;
