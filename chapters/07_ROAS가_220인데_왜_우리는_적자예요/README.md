# 7장. ROAS가 220%인데 왜 우리는 적자예요?

유닛 이코노믹스 실습 코드입니다. 마케팅 비용·유입·결제라는 원본 로그 세 장에서
출발해, 본문에서 완성한 표들(CAC 캐스케이드·채널 표·회수 곡선)을 직접 계산해 복원합니다.

- **7.4.2.** 채널별 CAC를 매체비 기준과 fully-loaded 기준으로 계산합니다 (12,000원 → 14,500원).
- **7.4.3.** 획득 후 1년이 지난 장기 코호트의 실측 결제로 LTR → LTV(공헌이익)를 계산합니다 (3.1 → 2.0 → 1.7 캐스케이드).
- **7.4.4.** CAC와 LTV를 채널 단위로 붙여 본문의 채널 표를 복원합니다.
- **7.4.5.** 코호트별 회수 곡선을 그려 회수 기간(Payback Period)을 실측합니다 (검색 4월 코호트 3개월째 본전, 관측 12개월).
- **7.4.6.** 목표 회수 기간 × 유저당 월평균 공헌이익으로 CAC 가이드라인을 계산합니다.

## 실행 방법

```bash
python generate_data.py                  # 예시 데이터 생성 (data/*.csv)
jupyter notebook unit_economics.ipynb    # 노트북을 위에서 아래로 실행 (첫 셀이 의존성 설치)
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `generate_data.py` | 합성 데이터 생성기 (시드 고정 — 채널별 CAC·LTV·회수 곡선을 정답으로 심음) |
| `data/marketing_costs.csv` | 월×채널 마케팅 비용 (`month, channel, media_cost_krw, other_cost_krw`) |
| `data/users.csv` | 유입 유저 명부 (`user_id, channel, signup_date`) — 결제 안 한 유저 포함 |
| `data/payments.csv` | 결제 건별 로그 (`user_id, payment_date, amount_krw`) |
| `sql/cac_by_channel.sql` | 채널별 매체비/fully-loaded CAC |
| `sql/mature_cohort.sql` | 장기 코호트(획득 후 12개월 경과) 뷰 — 아래 백테스트와 7.4.6이 재사용 |
| `sql/ltv_backtest.sql` | 장기 코호트 12개월 실측 LTR → LTV(공헌이익) (선행: mature_cohort.sql) |
| `sql/payback_curve.sql` | 코호트 회수 곡선 (누적 공헌이익 ÷ CAC 총액) |
| `unit_economics.ipynb` | 7.4 실습 노트북 (7.4.1~7.4.6) |
