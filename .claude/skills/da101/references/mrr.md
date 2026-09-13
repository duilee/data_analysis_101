# 구독 성장 지표 — MRR 6요소 분해와 GRR/NRR

**챕터**: `06_구독_서비스의_성장_지표_확인하기/` · 노트북: `mrr_analysis.ipynb`
<!-- 동기화: 코드 기준 커밋 `8e8b97c` (2026-09-13) — 노트북·README·sql과 대조 완료. 책 본문 대조는 미실시. -->

## 이 방법이 푸는 문제

유저 ID가 없는 스토어 결제 로그(Google Play Sales Report 형태)만으로 구독 비즈니스의
건강도를 진단한다. `order_number` 파싱으로 유저를 식별하고, 월별 MRR을
**new / renew / reactivation / expansion / contraction / churn** 6요소로 분해한 뒤,
GRR(방어력)·NRR(성장력)로 요약한다. "MRR이 늘고 있다"가 신규 유입 덕인지, 기존 매출
방어 덕인지를 구분할 수 있게 된다.

## 실행·검증

```bash
python generate_data.py      # data/subscription_sales.csv 생성
jupyter nbconvert --to notebook --execute --inplace mrr_analysis.ipynb
```

- 입력: `data/subscription_sales.csv` (`order_number, order_charged_date, product_id,
  sales_amount_krw`).
- 흐름: 실습 1 `split_part(order_number, '..', 1) AS pid` + `row_number()` 결제 회차 →
  실습 2 `lag()` 간격 + `pay_type`(new/renew/reactivation, 32일 임계값) → 실습 3 전월
  FULL OUTER JOIN으로 6요소 분해(`mrr` df) + 항등식 검증(`check`) → 실습 4 `grr`/`nrr` →
  실습 5 구독자 수 단위 동일 분해(`sql/subscriber_counts.sql` — 유일하게 디스크에서 읽는 SQL) →
  실습 6 이탈률 복원·LTV 어림.
- **기대 결과**: 생성기가 심은 정답은 **월 이탈률 5%**(`CHURN_RATE=0.05`). 실습 6에서
  `stable = mrr[mrr.month >= "2025-04"]` 구간의 churn rate가 5% 근처로 수렴하고
  `LTV ≈ ARPU ÷ churn rate`로 연결된다. 플랜은 monthly_basic 4,900원 / monthly_plus 9,900원 —
  expansion/contraction은 갱신 시 업/다운그레이드에서 나온다. 실습 5에서 업/다운그레이드가
  매출은 바꾸지만 구독자 수는 바꾸지 않음을 확인한다.

## 내 데이터에 적용 — 인터랙티브 프로토콜

아래 1→5 순서로 진행한다. 각 단계 결과를 독자에게 보여주고 확인한 뒤 다음으로 간다.
노트북에 `[내 데이터 적용]` 주석이 2곳 있지만 ⚠ 32일 임계값이 `sql/subscriber_counts.sql`에도
따로 있다는 점은 주석에 없다 — 아래 표가 기준이다.

### 1. 인테이크 — 독자에게 물을 것

- 결제 로그의 **파일 경로**는?

| 역할 (노트북 예시명) | 타입 | 의미 | 필수 |
| --- | --- | --- | --- |
| `order_number` | TEXT | 주문번호 (유저 식별 원천) | 필수* |
| `order_charged_date` | DATE | 결제일 | 필수 |
| `product_id` | TEXT | 플랜 식별자 | 필수 |
| `sales_amount_krw` | NUMERIC | 결제 금액 | 필수 |

  *유저 ID 컬럼이 이미 있으면 실습 1(주문번호 파싱)을 건너뛰고 그 컬럼을 `pid`로 쓴다.
- 주문번호 체계는? — 구글처럼 `기본주문번호..회차` 구조인가? 아니면 다른 규칙인가?
  (샘플 5~10개를 보여 달라고 요청해 파싱 규칙을 함께 정한다.)
- **구독 주기**는? 월만인가, 연 구독이 섞여 있나? (renew 임계값 분리 필요)
- 금액은 gross(스토어 수수료 차감 전)인가 net인가? 환불이 로그에 어떻게 남는가?
  (음수 행? 별도 파일?)
- 무료 체험은 로그에 0원 행으로 남는가? 분해에서 제외할 것인가?
- 데이터 기간은? — 안정 구간 판단을 위해 **최소 6개월** 권장.

### 2. 데이터 점검 — 통과 전 분석 시작 금지

```python
duckdb.query("""SELECT COUNT(*) AS rows, MIN(order_charged_date) AS min_d,
    MAX(order_charged_date) AS max_d, COUNT(DISTINCT product_id) AS plans,
    SUM(CASE WHEN sales_amount_krw <= 0 THEN 1 ELSE 0 END) AS nonpos_rows
    FROM read_csv_auto('YOUR_CSV_PATH')""").to_df()
```

- 통과 기준: 기간 ≥ 6개월, `nonpos_rows`(환불/무료 행) 존재 시 처리 규칙을 먼저 합의,
  플랜 수가 인테이크 답변과 일치. 파싱 규칙을 정했다면 샘플에 적용해 pid·회차가 올바르게
  나오는지 독자와 확인한다.

### 3. 코드 치환 지도

| 앵커 (실습/식별자) | 무엇을 | 어떻게 |
| --- | --- | --- |
| 로드 셀 `CREATE TABLE sales AS …` | CSV 경로, 컬럼명 | 독자 데이터로 — 테이블명 `sales`는 유지 (이후 모든 SQL과 `sql/*.sql`이 참조) |
| 실습 1 `orders` 뷰 셀 | `split_part(order_number, '..', 1)`의 구분자·파싱 규칙 | 독자 주문번호 체계로 (유저 ID 있으면 이 실습 생략) |
| ⚠ renew 임계값 | `date_diff('day', prev_date, order_charged_date) < 32` — 노트북은 **실습 2 `classified` 뷰 한 곳**(실습 3·4·6이 이 뷰를 재사용), 그리고 실습 5가 읽는 **`sql/subscriber_counts.sql`**에 별도로 한 번 더 | 월 구독 32일 기준. 연 구독 혼재 시 플랜별 주기+유예로 분리, **두 곳 함께** 수정 (참고용 사본 `sql/classify_payment.sql`·`sql/mrr_breakdown.sql`도 맞춰 두면 좋다) |
| 실습 3 `paired` 뷰 셀 | `INTERVAL 1 MONTH` 2곳 (coalesce와 JOIN 조건) | 주 단위 분해가 필요하면 함께 변경 |
| 실습 5 | `open("sql/subscriber_counts.sql")` — 유일하게 디스크에서 읽는 SQL | 이 파일은 실제 실행 대상이므로 직접 수정 |
| 실습 6 | 안정 구간 컷 `mrr[mrr.month >= "2025-04"]` | 독자 데이터의 초기 성장 왜곡 구간을 제외한 시점으로 |

- 6요소 분해의 FULL OUTER JOIN 구조와 항등식 검증 셀(`check`)은 그대로 둔다 — 치환 후
  항등식이 깨지면 분류 규칙이 잘못된 것이다(디버깅 신호로 활용).
- `paired` 뷰의 `stayed`(두 달 모두 결제)·`delta`(이번 달 − 전월 금액) 컬럼이 6요소의 핵심이다:
  renew = `least(amt, prev_amt)`, expansion = `greatest(delta, 0)`, contraction = `greatest(-delta, 0)`.
  주기를 바꿔도 이 컬럼명은 유지한다.

### 4. 단계별 진행

1. (필요시) 파싱 실행 → pid 수·회차 분포 제시 → 실습 2의 `gap` 셀로 결제 간격 분포 확인(월
   구독이면 28~31일에 몰려야 함 — 여기서 임계값의 타당성을 독자와 확인). ⚠ 실습 4에서 같은
   이름 `gap`이 NRR−GRR 갭으로 재정의되므로, 나중에 간격 분포를 다시 보려면 실습 2 셀을 재실행.
2. `pay_type` 분류 → new/renew/reactivation 비중 제시, 상식과 대조.
3. 6요소 분해 → **항등식 검증 통과 확인** → 월별 스택 차트 제시.
4. GRR/NRR 계산 → 추이 차트.
5. 구독자 수 분해 → 매출 분해와 대조 (업/다운그레이드 효과 분리).
6. 안정 구간 churn rate → LTV 어림 → 해석.

### 5. 결과 해석

- GRR은 이탈+contraction만 반영한 방어력(상한 100%), NRR은 expansion까지 더한 성장력.
  **NRR−GRR 갭이 크면 소수 유저의 업그레이드가 성장을 견인** — 방어(GRR)가 나쁘면 취약한
  성장이다.
- 월별 6요소 스택에서 churn 막대가 커지는 시점을 이벤트(가격 변경, 캠페인)와 대조한다.
- reactivation이 크면 "이탈"의 정의(일시 미결제 vs 진짜 이탈)를 재점검한다.

## 함정

- 환불·부분 환불의 로그 표현 방식은 스토어마다 다르다 — 분해 전에 정제 규칙을 먼저 확정한다.
- MRR 분해는 월 스냅샷 비교라 월 중 가입-이탈은 상쇄되어 안 보인다. 짧은 주기 문제는
  주 단위로 내려서 본다.
- `LTV ≈ ARPU ÷ churn`은 이탈률 일정 가정의 어림이다 — 코호트별 이탈률이 변하면 lifetime
  챕터의 방법으로 보정한다.

## 학습 가이드

### 핵심 개념 — 이 챕터를 마치면 설명할 수 있어야 하는 것

- **MRR 6요소 분해** — 이번 달 MRR = 전월 + new + reactivation + expansion − contraction −
  churn (renew는 유지분). 성장의 "출처"를 밝히는 회계.
- **GRR vs NRR** — 기존 매출 기준 방어력(이탈·축소만 반영, ≤100%) vs 성장력(확장 포함,
  100% 초과 가능). 둘의 갭이 성장의 질을 말한다.
- **renew/reactivation 구분** — 결제 간격 임계값으로 "이어진 구독"과 "돌아온 구독"을 나누는
  것. 임계값 = 결제 주기 + 유예.
- **항등식 검증** — 분해의 합이 실제 MRR 변화와 일치하는지 확인하는 습관. 회계는 안 맞으면
  분류가 틀린 것.
- **ARPU ÷ churn LTV 어림** — 이탈률이 일정하다면 기대 구독 개월 = 1/churn이라는 등비급수
  결과.

### 개념 체크

1. NRR 115%인데 GRR 80%인 서비스는 어떤 상태인가? 무엇부터 확인해야 하는가?
   - 힌트: 소수 헤비 고객의 업그레이드가 큰 이탈을 가리는 상태 — expansion 집중도(상위 고객
     의존)와 churn 원인부터.
2. reactivation을 new와 구분하는 이유는? 구분하지 않으면 어떤 착시가 생기는가?
   - 힌트: 획득 효율 착시 — 돌아온 유저를 신규로 세면 마케팅 성과가 부풀고, 이탈 문제가
     가려진다.
3. MRR 분해에서 expansion이 계속 0인데 매출이 성장 중이라면, 성장의 원천은 무엇이고 어떤
   리스크가 있나?
   - 힌트: 전적으로 new 유입 의존 — 유입이 꺾이면 즉시 정체. upsell 여지 부재도 점검.

### 심화 과제

1. **[샌드박스]** `generate_data.py`의 `CHURN_RATE = 0.05 → 0.08`로 바꾸면 실습 6의 복원
   churn rate, LTV, 그리고 NRR이 각각 어떻게 변할지 예측하게 한다 → 수정 →
   `python generate_data.py` → 노트북 재실행 → 대조. 끝나면
   `git checkout -- generate_data.py data/` 후 재생성으로 원복.
2. **[샌드박스]** `P_UPGRADE = 0.015 → 0`으로 바꾸면(업그레이드 소멸) 6요소 중 무엇이 사라지고
   NRR−GRR 갭이 어떻게 될지 예측 → 실행 → 대조. "expansion의 회계적 위치"를 체득. 원복 필수.
3. **[사고]** 연 구독 플랜을 새로 출시하면 이 분해의 어디가 깨지는가? (월 정규화(MRR화) 규칙,
   renew 임계값, churn 판정 시점을 중심으로 설계안을 토론 — 정답 없음)
