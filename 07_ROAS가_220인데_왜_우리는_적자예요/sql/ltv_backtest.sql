-- 성숙 코호트 백테스트: 획득 후 36개월이 지난 유저의 실측 LTR → LTV(공헌이익)
-- 외삽·할인 없이 '이미 끝난 경기의 기록'만 사용한다
-- (노트북은 mature 를 VIEW 로 만들어 CAC 가이드라인 계산에서도 재사용한다)
WITH mature AS (
    SELECT user_id, channel, date_trunc('month', signup_date) AS cohort_month
    FROM users
    WHERE signup_date < DATE '2023-07-01'
),
rev AS (
    SELECT m.channel, m.user_id, COALESCE(SUM(p.amount_krw), 0) AS ltr_36m
    FROM mature m
    LEFT JOIN payments p
      ON p.user_id = m.user_id
     AND p.payment_date < m.cohort_month + INTERVAL 36 MONTH
    GROUP BY 1, 2
)
SELECT channel
     , COUNT(*)                     AS users
     , ROUND(AVG(ltr_36m))          AS ltr
     , ROUND(AVG(ltr_36m) * 0.65)   AS ltv_cm    -- 공헌이익률 65% (본문 2.1 가정)
FROM rev
GROUP BY channel
ORDER BY ltv_cm DESC;
