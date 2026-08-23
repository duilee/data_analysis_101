# 데이터 마트 층 쌓기 — raw → staging → dim/fact → mart

**챕터**: `쿼리가_30분째_안_끝나는데요/` · 노트북: `data_mart_layers.ipynb`

## 이 방법이 푸는 문제

느린 쿼리, DW에 없는 데이터, 팀마다 다른 숫자는 쿼리 실력이 아니라 **데이터가 놓인 자리**의
문제다. 이 챕터는 가상의 구독형 앱 데이터(소스 다섯 개)로 네 층을 직접 쌓아 같은 질문
("일별 활성 구독자 수와 매출")을 raw와 마트에서 답해 보며 차이를 체감하게 한다.

- 실습 1 raw: 다섯 CSV를 한 쿼리(47줄)로 조인 — 정의가 쿼리 안에 흩어져 있어 사람마다 숫자가 달라지는 구조
- 실습 2 staging: 소스 1:1 뷰 — 이름·타입·중복·시스템 이벤트만 정리, 비즈니스 로직 금지
- 실습 3 dim/fact: 유저 일별 스냅샷 디멘션 + 거래 팩트(구독 이벤트) + 스냅샷 팩트(일별 활성 구독)
- 실습 4 mart: 파티션(날짜) 하나씩 채우는 `run_partition()` 배치로 90일 backfill, 같은 질문을 3줄로
- 실습 5 멱등성·유니크 키 테스트, 실습 6 늦게 도착한 이벤트와 3일 재적재 창

## 실행·검증

```bash
python generate_data.py      # data/*.csv 5개 생성 (SEED=42, 유저 3,000명 × 90일, 총 ~16MB)
jupyter nbconvert --to notebook --execute --inplace data_mart_layers.ipynb
```

- 입력: `data/events.csv`(event_id, user_id, event_name, session_id, event_time, received_time, properties),
  `data/subscription_events.csv`(sub_event_id, user_id, event_type, sku_id, is_trial, event_time, received_time, price_local, currency),
  `data/user_snapshots.csv`(snapshot_date, user_id, platform, country, app_version, install_date), `data/sku.csv`, `data/exchange_rates.csv`.
- SQL 파일(인라인과 동일): `sql/raw_daily_subscribers.sql`, `sql/stg_views.sql`, `sql/dim_tables.sql`,
  `sql/fact_subscription_events.sql`, `sql/fact_subscriber_daily.sql`, `sql/mart_subscription_daily.sql`. 챕터 폴더에서 실행한다.
- **기대 결과**: 생성기가 심은 정답은 6월 일평균 활성 구독자 **574명(체험 포함)**, 기간 매출 합계 **$5,953**(환불 반영),
  도착 지연 분포 앱 이벤트 70/20/8/2%, 구독 이벤트 55/25/12/8%. 노트북에서 확인할 것:
  - 실습 1 raw 쿼리 결과 885행, 실습 2 raw 95,313행 → staging 86,040행(중복·시스템 이벤트 제거분)
  - 실습 4 `raw 쿼리와 마트의 활성 구독자 수 차이(합): 0` — raw와 마트가 같은 숫자
  - 실습 5 두 번 실행 전/후 동일, DELETE 없이 INSERT만 하면 유니크 키 위반 38건
  - 실습 6 2026-06-14 파티션이 D+0 13건 → D+1 20건 → D+2 24건 → D+3 26건으로 채워짐(50% → 77% → 92% → 100%)
- 이 챕터의 **apply 모드는 코드 치환이 아니라 설계 문서 작성**이다 (아래 프로토콜).

## 내 데이터에 적용 — 인터랙티브 프로토콜

독자의 요구사항 한 줄이나 지금 쓰고 있는 느린 쿼리를 받아, **마트 설계 다섯 단계 템플릿**을 같이 채운다.
코드에서 뽑을 수 있는 것은 먼저 채우고, 비즈니스 맥락만 독자에게 묻는다. 각 단계 결과를 보여주고 확인한 뒤 다음으로 간다.

### 1. 인테이크 — 독자에게 물을 것

- 지금 이 숫자를 어떻게 보고 있는가? (없음 / 누군가의 쿼리 / 대시보드) 무엇이 불편한가? (느림 / 못 봄 / 팀마다 다름)
- 어느 레벨까지 쪼개 보고 싶은가? (플랫폼·국가·상품·채널·체험 여부 …)
- 핵심 지표의 정의 — 예: "구독자"에 체험을 포함하는가, 환불 건은 빼는가
- 소스는 어디인가, 늦게 도착하는 소스가 있는가 (어트리뷰션·스토어 통지 등 → 재적재 창)
- 쿼리를 가져왔다면: 어떤 테이블을 읽는지, CTE 각각이 정리/조인/집계 중 무엇인지 분류한다

| 역할 (노트북 예시명) | 타입 | 의미 | 필수 |
| --- | --- | --- | --- |
| 이벤트/거래 로그 (`subscription_events`) | 행 단위 | grain 후보 — 한 행이 무엇인가 | ✅ |
| 속성 소스 (`user_snapshots`) | 유저 × 날짜 | 디멘션 후보 (천천히 변함) | ✅ |
| 참조 테이블 (`sku`, `exchange_rates`) | 작은 표 | 디멘션·환산 | 선택 |
| `event_time` / `received_time` | timestamp | 늦은 도착 판단 | 권장 |

### 2. 데이터 점검 — 통과 전 분석 시작 금지

```python
import duckdb
con = duckdb.connect()
con.execute("""
SELECT COUNT(*) AS rows, COUNT(DISTINCT <id>) AS ids, MIN(<ts>) AS t0, MAX(<ts>) AS t1,
       COUNT(*) - COUNT(DISTINCT <id>) AS dup_rows
FROM read_csv_auto('<파일>')""").df()
```

통과 기준: 행 식별자가 있거나 만들 수 있다(없으면 grain을 선언할 수 없다) · 시간 컬럼이 있다 · 중복 비율을 알고 있다
· 속성이 바뀌는 엔티티(유저·상품)가 무엇인지 안다.

### 3. 코드 치환 지도

| 앵커 (실습/식별자) | 무엇을 | 어떻게 |
| --- | --- | --- |
| 실습 2 `stg_*` 뷰 | 소스 파일 경로·컬럼 이름 | 소스 하나당 뷰 하나. 이름·타입·중복·잡음만 |
| 실습 3 `fact_subscription_events` | grain 한 문장 → 한 행 | 2단계에서 선언한 grain 그대로. 환산(환율 등)은 여기서 |
| 실습 3 `fact_subscriber_daily` | 상태 스냅샷(semi-additive) | "그 시점에 ~인 엔티티 × 날짜"가 필요할 때만 |
| 실습 3 `dim_user_daily` | 천천히 바뀌는 속성 | 매일 전체 스냅샷 + `_latest` 뷰 |
| 실습 4 `MART_SQL` | `{partition_date}` 한 파티션 집계 | 1단계에서 정한 레벨(차원)로 GROUP BY |
| 실습 6 `window_days` | 재적재 창 | 소스의 최대 지연일 + 1 |

⚠ `MART_SQL`의 `{received_filter}` 자리는 실습 6에서만 채운다 — 실무 배치에서는 비워 둔다.

### 4. 단계별 진행

1. **업무 프로세스** — 현 상황·어려움·보고 있는 지표와 레벨·추가로 볼 지표를 한 장으로. 업무 파트너와 이야기했는지 확인.
2. **Grain 선언** — "One row per …" 한 문장. 가장 낮은 레벨(이벤트)을 권하고, 기존 마트와 겹치는지 묻는다.
3. **디멘션** — 누가·무엇을·어디서·언제·왜·어떻게. 별도 디멘션으로 뺄 키(유저·상품)를 표시.
4. **팩트** — 측정값 목록 + additive / semi-additive / non-additive 구분.
5. **배치** — 파티션 키, 전체/증분/뷰, 한 배치 = 한 파티션, 테스트(유니크·not null·허용값·신선도), 재적재 창.
6. 산출물은 아래 템플릿을 채운 마크다운 한 장. 쿼리를 가져온 경우 CTE를 staging / fact / mart로 분류한 표를 덧붙인다.

```markdown
# 마트 설계 — <마트 이름>
## 1. 업무 프로세스 (Select the Business Process)
- 현 상황: / 어려움: / 현재 보는 지표와 레벨: / 추가로 볼 지표:
- [ ] 업무 파트너와 직접 이야기했는가  [ ] 운영 프로세스가 실제로 존재하는가
## 2. Grain (Declare the Grain)
- One row per …
- [ ] 한 문장인가  [ ] 1의 프로세스를 대부분 포함하는가  [ ] 기존 모델과 겹치지 않는가
## 3. 디멘션 (Identify the Dimensions)
- 누가: / 무엇을: / 어디서: / 언제: / 왜·어떻게:
- [ ] 별도 디멘션 테이블로 뺄 키  [ ] 기존 디멘션과 겹치지 않는가
## 4. 팩트 (Identify the Facts)
- 측정값 (additive / semi-additive / non-additive 표시)
- [ ] 1의 지표를 전부 담았는가  [ ] 기존 팩트와 겹치지 않는가
## 5. 배치 (Define Batch Process)
- 파티션 키: / 방식(전체·증분·뷰): / 재적재 창: / 테스트: / 스케줄:
- [ ] 한 배치 = 한 파티션  [ ] 불변 소스  [ ] 테스트 정의
```

### 5. 결과 해석

- grain 한 문장이 써지지 않으면 마트가 아니라 **정의**가 없는 것이다 — 1·2단계로 돌아간다.
- 같은 grain의 마트가 이미 있으면 새로 만들지 말고 디멘션·팩트를 **붙이는** 쪽을 먼저 검토한다.
- 재적재 창이 0이 아니면 "어제 숫자는 아직 바뀔 수 있다"를 대시보드·회의에서 같이 안내한다.

## 함정

- staging에 비즈니스 로직(예: "체험 유저 제외")이 한 줄 들어가는 순간 정의가 두 곳이 된다 — 팩트/마트로 내린다.
- semi-additive 값(활성 구독자·DAU·잔고)을 날짜를 가로질러 SUM하면 안 된다. 주간은 합이 아니라 마지막 날 값이나 평균.
- DELETE 없이 INSERT만 하는 배치는 두 번 실행되면 중복된다(실습 5). 유니크 키 테스트가 없으면 조용히 틀린다.
- DuckDB 문법: `DATE + BIGINT`는 안 된다(CSV 정수는 BIGINT로 들어옴 → `CAST(... AS INTEGER)`), 파티션 펼치기는
  `UNNEST(generate_series(start, end, INTERVAL 1 DAY))`.
- 노트북 규모에서는 raw 쿼리도 0.1초대라 "30분"은 재현되지 않는다 — 구조·재현성 차이를 보여주는 실습이다.

## 학습 가이드

### 핵심 개념 — 이 챕터를 마치면 설명할 수 있어야 하는 것

- 네 층(src·staging·dim/fact·mart)의 역할과 각 층이 **하지 않는 일**
- grain 한 문장이 왜 설계의 절반인가, 가장 낮은 레벨로 잡는 이유
- additive / semi-additive / non-additive
- 한 배치 = 한 파티션(멱등성)과 backfill, 매일 스냅샷으로 SCD를 푸는 방식
- 늦게 도착하는 데이터와 재적재 창, 테스트 4종(유니크·not null·허용값·신선도)

### 개념 체크

1. 동료가 staging 뷰에 "체험 유저 제외" WHERE 절을 넣자고 한다. 어느 층의 로직이고, staging에 넣으면 무엇이 생기는가?
   - 힌트: 정의가 두 곳 — 누군가는 staging을, 누군가는 마트를 믿는다.
2. "일별 구독자 수"가 목표인데 grain을 '이벤트 한 건'으로 잡았다. '유저 × 날짜'로 잡았을 때와 비교해 무엇을 얻고 잃는가?
   - 힌트: 드릴다운과 재집계 vs 테이블 크기.
3. 마트의 `active_subscribers`를 주간으로 보려면 어떻게 해야 하는가?
   - 힌트: semi-additive.
4. 배치가 두 번 실행됐다. `run_partition`은 왜 안전하고, INSERT만 하는 배치는 왜 위험한가?
   - 힌트: 실습 5의 유니크 키 위반 38건.
5. 어트리뷰션이 설치 후 최대 3일 뒤에 확정된다. 배치와 대시보드에서 각각 무엇을 바꿔야 하는가?
   - 힌트: 재적재 창 + "어제 숫자는 확정치가 아니다".

### 심화 과제

1. **[샌드박스]** `generate_data.py`의 `SUB_ARRIVAL_LAG`를 `{0: 0.3, 1: 0.3, 2: 0.2, 3: 0.2}`로 바꾸면 실습 6의 D+0~D+3 표가 어떻게 바뀔지 예측 → 재생성·재실행 → 확인 → `git checkout -- generate_data.py data/` 로 원복.
2. **[샌드박스]** `fact_subscriber_daily`의 `QUALIFY`를 지우고 실습 5를 다시 돌려, 유니크 키 테스트가 무엇을 잡아내는지 본다. 원복 필수.
3. **[사고]** 우리 팀에서 가장 자주 다시 짜는 쿼리 하나를 골라 grain을 "One row per …"로 써 본다. 써지지 않는다면 왜인가?
