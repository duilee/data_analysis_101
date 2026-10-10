# 6장. 구독 서비스의 성장 지표 확인하기

MRR 분석 실습 코드입니다. 유저 ID가 없는 스토어 결제 로그(Google Play Sales Report 형태)에서
유저를 식별하고, 월별 MRR을 분해해 구독 비즈니스의 건강도를 진단합니다.

- **6.3.2.** `order_number`의 prefix/suffix를 파싱해 유저(pid)와 누적 결제 회차를 식별합니다.
- **6.3.3.** `LAG()`로 직전 결제와의 간격을 재서 renew와 reactivation을 구분합니다 (32일 임계값).
- **6.3.4.** 전월과의 FULL OUTER JOIN으로 월별 MRR을 new/renew/reactivation/expansion/contraction/churn으로 분해합니다.
- **6.3.5.** GRR(방어력)과 NRR(성장력)을 계산하고 두 지표의 갭을 해석합니다.
- **6.3.6.** 데이터에 심어 둔 월 이탈률 5%를 복원하고, LTV ≈ ARPU ÷ churn rate 어림으로 연결합니다.

책에는 없는 **[노트북 보충]** 구간 세 곳(결제 간격 확인, MRR 항등식 검증, 구독자 수 단위 분해 — 6.2.4.7)은
노트북에서만 다룹니다. 절 번호는 책 6장의 실습 절(6.3.x)과 같습니다.

## 실행 방법

```bash
pip install -r requirements.txt     # 의존성 설치
python generate_data.py             # 예시 데이터 생성 (data/subscription_sales.csv)
jupyter notebook mrr_analysis.ipynb # 노트북을 위에서 아래로 실행
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `generate_data.py` | 결제 로그 합성 데이터 생성기 (시드 고정, 월 이탈률 5% 심음) |
| `data/subscription_sales.csv` | 결제 건별 로그 (`order_number, order_charged_date, product_id, sales_amount_krw`) |
| `sql/identify_orders.sql` | 유저(pid) 식별 + 누적 결제 회차 |
| `sql/classify_payment.sql` | new / renew / reactivation 분류 |
| `sql/mrr_breakdown.sql` | 월별 MRR 6개 요소 분해 |
| `sql/subscriber_counts.sql` | 구독자 수 단위의 동일 분해 |
| `mrr_analysis.ipynb` | 6.3 실습 노트북 (6.3.1~6.3.6 + 노트북 보충) |
