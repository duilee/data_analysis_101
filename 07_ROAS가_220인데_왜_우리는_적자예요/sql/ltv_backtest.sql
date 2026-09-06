-- 장기 코호트 백테스트: 획득 후 36개월이 지난 유저의 실측 LTR → LTV(공헌이익)
-- 외삽·할인 없이 '이미 끝난 경기의 기록'만 사용한다
-- 선행: mature_cohort.sql (mature 뷰) · 준비: payments 테이블 등록 (data/payments.csv)
-- 공헌이익률 0.65 = 본문 2.1의 변동비 가정(합계 35%)
WITH rev AS (  -- 유저별 36개월 누적 결제금액 (미결제 유저는 0)
  SELECT m.channel, m.user_id, COALESCE(SUM(p.amount_krw), 0) AS ltr_36m
  FROM mature m
  LEFT JOIN payments p
    ON p.user_id = m.user_id
   AND p.payment_date < m.cohort_month + INTERVAL 36 MONTH
  GROUP BY 1, 2
)
SELECT channel
     , COUNT(*) AS users
     , ROUND(AVG(ltr_36m)) AS ltr
     , ROUND(AVG(ltr_36m) * 0.65) AS ltv_cm
FROM rev
GROUP BY channel
ORDER BY ltv_cm DESC;
