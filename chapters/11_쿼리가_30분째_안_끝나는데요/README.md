# 11장. 쿼리가 30분째 안 끝나는데요?

분석 쿼리가 느리고, 보고 싶은 데이터는 DW에 없고, 팀마다 구독자 수가 다르다 — 세 문제는 모두
데이터가 놓인 '자리'의 문제입니다. 가상의 구독형 앱 데이터(소스 다섯 개)로 **raw → staging →
dimension/fact → mart** 네 층을 직접 쌓아 보고, 같은 질문("일별 활성 구독자 수와 매출")이 raw와
마트에서 어떻게 다르게 답해지는지 확인하는 실습 코드입니다.

- **실습 1. raw에서 바로 뽑기.** 다섯 CSV를 한 쿼리로 조인해 답을 구하고 쿼리 길이·시간을 잽니다.
- **실습 2. staging.** 소스마다 뷰 하나씩 — 이름·타입·중복·시스템 이벤트만 정리하고 비즈니스 로직은 넣지 않습니다.
- **실습 3. dimension / fact.** 유저 일별 스냅샷 디멘션과 구독 이벤트(거래)·일별 활성 구독(스냅샷) 팩트 두 개를 만듭니다.
- **실습 4. mart.** 파티션(날짜) 하나씩 만드는 배치 함수로 90일을 채우고, 같은 질문을 세 줄로 답해 raw와 숫자가 같음을 확인합니다.
- **실습 5. 파티션 재적재.** 같은 날짜를 두 번 돌려 멱등성을 확인하고, DELETE 없이 INSERT만 했을 때 유니크 키 테스트가 잡아내는 중복을 봅니다.
- **실습 6. 늦게 도착한 이벤트.** 배치 시점(D+1~D+4 새벽)별로 같은 파티션의 숫자가 어떻게 채워지는지 보고 4일 재적재 창을 적용합니다.

## 실행 방법

```bash
python generate_data.py                       # 예시 데이터 생성 (data/*.csv 5개)
jupyter notebook data_mart_layers.ipynb       # 노트북을 위에서 아래로 실행 (첫 셀이 의존성 설치)
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `generate_data.py` | 구독형 앱 합성 데이터 생성기 (시드 고정 — 재전송 중복·시스템 이벤트·대소문자 혼재·늦은 도착을 일부러 심음) |
| `data/events.csv` | 앱 이벤트 로그 (event_time / received_time 분리) |
| `data/subscription_events.csv` | 구독 이벤트 — purchase / renewal / cancel / refund |
| `data/user_snapshots.csv` | 유저 × 날짜 속성 스냅샷 (플랫폼·국가·앱 버전) |
| `data/sku.csv`, `data/exchange_rates.csv` | 상품 정의 · 통화별 일별 환율 |
| `sql/raw_daily_subscribers.sql` | 실습 1 — 마트 없이 한 쿼리로 답하기 |
| `sql/stg_views.sql` | 실습 2 — 스테이징 뷰 다섯 개 |
| `sql/dim_tables.sql`, `sql/fact_subscription_events.sql`, `sql/fact_subscriber_daily.sql` | 실습 3 — 디멘션·팩트 |
| `sql/mart_subscription_daily.sql` | 실습 4 — 마트 (파티션 하나를 채우는 배치 한 번의 SQL) |
| `data_mart_layers.ipynb` | 실습 1~6 노트북 |
