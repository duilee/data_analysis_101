# DAU 구성 진단 — 5세그먼트 Stock/Flow 분석

**챕터**: `01_DAU_차트를_봐서는_DAU를_올릴_수_없다/` · 노트북: `dau_segment.ipynb`
<!-- 동기화: 코드 기준 커밋 `8e8b97c` (2026-09-13) — 노트북·README·sql과 대조 완료. 책 본문 대조 완료 (2026-09-13). -->

## 이 방법이 푸는 문제

DAU 한 줄 차트로는 서비스가 왜 정체인지 알 수 없다. 유저를 5개 세그먼트
(new / heavy / light / risk / dormant — new 는 가입 후 7일 이내, heavy/light 는 최근 7일 기록
일수 5일 이상/1~4일, risk/dormant 는 마지막 기록 7~30일/30일 초과)로 분류하고, 분포(Stock)·전이 행렬(Flow)·비율 KPI 5종(HURR/CURR/Heavy Loss/Light Loss/
Reactivation)으로 **어디서 유저가 새고 어디로 이동하는지**를 입체적으로 진단한다.
전 과정이 DuckDB SQL이라 그대로 웨어하우스 쿼리로 옮기기 좋다.

**책 이론부 포인터** (QnA 모드는 요지만 말하고 자세한 설명은 책의 해당 절로 안내한다):
- 1절 — 월간 재방문율이 같은 두 서비스의 성장 궤적이 신규 유입의 성장 속도(CCGR)에 따라
  갈린다는 논지. 재방문율은 성장 단계에 따라 뜻이 달라지는 착시 지표이므로 단독으로 쓰지 않는다.
- 2절 — 듀오링고(세그먼트별 유지율 중 CURR이 DAU 성장의 핵심 레버)와 알라미(세그먼트와
  전이 경로 모니터링) 사례가 이 챕터 프레임워크의 출처.
- 2.2 — Stock은 시점 스냅샷, Flow는 기간 변화. 세그먼트 변화 10가지 정의는 책 표 2:
  New Activation(new → light/heavy) · New Loss(new → risk) · Loyalization(light → heavy) ·
  Heavy Loss(heavy → light) · Light Loss(light → risk) · Risk Loss(risk → dormant) ·
  Reactivation(risk → light) · Resurrection(dormant → light) · HURR(heavy → heavy) ·
  CURR(light+heavy → light+heavy). 노트북의 KPI 5종은 이 중 HURR·CURR·Heavy Loss·Light Loss·
  Reactivation. 하루 단위로는 heavy → risk, risk → heavy가 한 번에 일어나지 않고 light를 거친다.

## 실행·검증

```bash
python generate_data.py      # data/user_master.csv, data/user_activity.csv 생성
jupyter nbconvert --to notebook --execute --inplace dau_segment.ipynb
```

- 입력: `user_master.csv` (`user_id, first_active_date`), `user_activity.csv` (`user_id, event_date`).
- 파이프라인: 파생지표 쿼리(3개 지표: `days_since_signup, active_day_count,
  last_active_date` + DAU 교차용 `d0_active` → 테이블 `user_metrics`) → 분류 CASE(5분류, 컬럼 `user_seg`) →
  세그먼트×오늘 기록 여부 교차(`dau_by_seg`) →
  분류 CASE를 매크로화한 `classify_seg` + `build_mart_query`(어제·오늘 2시점 → 테이블
  `mart_user_segment`) → Stock(`dist`)/Flow(`trans`)/KPI(`kpi`) → 실습 4에서 31일치 백필 후
  N일 추적(30일 전 heavy → 오늘, 30일 전 new → 오늘).
- **기대 결과**: 생성기(시드 42, 유저 200명, 기준일 `TARGET = "2026-05-20"`)가 활동 티어와
  이탈 유형(recent/mid/old)을 심어 두었으므로, Stock에 dormant·risk가 뚜렷이 나타나고
  전이 행렬에서 heavy → light → risk → dormant 흐름과 new → heavy/light 안착이 읽혀야 한다.
  예시 데이터 기준 HURR 92.1% · CURR 96.4% · Heavy Loss 7.9% · Light Loss 5.4% · Reactivation 2.0%,
  30일 HURR 55.6%.

## 내 데이터에 적용 — 인터랙티브 프로토콜

아래 1→5 순서로 진행한다. 각 단계 결과를 독자에게 보여주고 확인한 뒤 다음으로 간다.
노트북에 `[내 데이터 적용]` 주석이 4곳 있다 — 그 지점을 기본으로 따라가되, 아래 ⚠ 항목이
주석보다 넓은 범위를 다룬다.

### 1. 인테이크 — 독자에게 물을 것

- 두 테이블의 **파일 경로**는?

| 역할 (노트북 예시명) | 컬럼 | 타입 | 필수 |
| --- | --- | --- | --- |
| 유저 마스터 (`user_master.csv`) | `user_id` | TEXT | 필수 |
| 〃 | `first_active_date` | DATE | 필수 (없으면 활동 로그의 유저별 MIN으로 파생) |
| 활동 로그 (`user_activity.csv`) | `user_id` | TEXT | 필수 |
| 〃 | `event_date` | DATE | 필수 (일 단위 중복 제거된 활동 로그 — 루틴로그 예시에서는 습관 체크를 남긴 날) |

- **분석 기준일**은? (노트북의 `TARGET` — 보통 어제)
- 서비스의 **사용 주기**는? (매일 쓰는 앱인지, 주 단위인지 — 세그먼트 경계 조정에 필요)
- 활동 로그 보유 기간은? — 최소 **기준일 이전 60일**(dormant 판정 30일 + 여유) 필요.

### 2. 데이터 점검 — 통과 전 분석 시작 금지

```python
con.execute("""SELECT COUNT(DISTINCT user_id) AS users, MIN(event_date) AS min_d,
    MAX(event_date) AS max_d FROM read_csv_auto('YOUR_ACTIVITY_PATH')""").df()   # 노트북의 con 재사용
```

- 통과 기준: `max_d` ≥ 기준일, 로그 기간 ≥ 60일, 마스터의 유저가 활동 로그 유저를 포함
  (LEFT JOIN 후 null `first_active_date` 비율 확인). 활동 로그가 이벤트 단위(하루 여러 행)면
  일 단위로 dedup해서 쓰라고 안내한다.

### 3. 코드 치환 지도

| 앵커 (실습/식별자) | 무엇을 | 어떻게 |
| --- | --- | --- |
| ⚠ CSV 경로 | 준비 셀 `for t in ["user_master", "user_activity"]` 루프의 f-string `read_csv_auto('data/{t}.csv')` 1곳 | 경로가 테이블명에서 파생된다 — 파일명이 테이블명과 다르면 루프를 풀어 두 줄로 쓰거나 `{테이블명: 경로}` dict로 바꾼다. 이후 쿼리는 테이블명 참조라 추가 수정 불필요 |
| ⚠ 기준일 | SQL 문자열 안에 `'2026-05-20'` 리터럴로 하드코딩 | 실습 4의 `build_mart_query.replace("2026-05-20", t.date().isoformat())` 패턴처럼 `TARGET` 변수 치환으로 통일 |
| ⚠ 세그먼트 경계 | new 윈도 7일, heavy 기준 활동일 5일, dormant 기준 `INTERVAL 30 DAY` | **실습 1의 분류 CASE(`days_since_signup`/`active_day_count`/`last_active_date`) + `classify_seg` 매크로(`days`/`cnt`/`last_active`) 두 곳** — 이름은 다르지만 같은 기준이라 반드시 함께 수정 |
| ⚠ 최근성 윈도 | 오늘 `INTERVAL 6 DAY`, 어제 `INTERVAL 7 DAY ~ 1 DAY` | 파생지표 쿼리(`user_metrics`)와 `build_mart_query` 의 오늘/어제 윈도를 함께 수정 |
| 실습 4 | `pd.date_range(end=TARGET, periods=31)` | 추적 기간에 맞게 |
| 실습 4 | `nday_query.format(seg="heavy")` | 추적할 출발 세그먼트 — 노트북이 `heavy`·`new` 둘 다 실행한다 |

- `SEG_ORDER`(5개 세그먼트명)와 KPI 5종(`hurr_pct, curr_pct, heavy_loss_pct, light_loss_pct,
  reactivation_pct`) 계산 로직은 그대로 둔다.
- 경계 조정 가이드: 주기가 긴 서비스일수록 최근성 윈도(6일)와 heavy 기준(7일 중 5일)을
  주기 배수로 늘린다(책 정리하며: 매일 쓰는 서비스 7일, 주간 단위 서비스 14·28일). '활동'의
  정의도 접속 대신 구매·콘텐츠 소비·핵심 기능 사용으로 바꿀 수 있다.
- `sql/*.sql` 8개는 인라인 쿼리의 전시용 사본 — 노트북만 고치면 sql 파일은 구버전으로 남는다.

### 4. 단계별 진행

1. 파생지표 쿼리 실행 → `user_metrics` 분포(3개 지표 요약 통계) 확인 — 경계값이 실제 분포의
   의미 있는 지점에 있는지 독자와 함께 본다.
2. 분류 CASE 쿼리 → 세그먼트별 인원수. 특정 세그먼트가 0명이거나 90% 이상이면 경계 재조정.
3. `build_mart_query` → 대표 유저 몇 명의 from→to 이동을 보여주고 분류가 직관과 맞는지 확인.
4. Stock → Flow → KPI 순서로 실행하며 각각 해석을 붙인다.
5. (독자가 원하면) 실습 4 백필로 30일 추적까지 — 실무에서는 일 배치 적재 구조를 권한다.

### 5. 결과 해석

- Stock으로 현재 구성 → Flow로 이동 방향 → KPI 5종으로 추세. 가장 큰 유출 전이
  (예: heavy → light, light → risk)를 액션 타깃으로 잡는다.
- Stock이 좋아 보여도 Flow가 나쁘면(heavy → light, light → risk 전이 증가) 곧 무너진다 — 두 축을 항상 같이.
- DAU 는 세그먼트 Stock 에 ‘오늘 기록 여부’를 교차한 값(`dau_by_seg`) — 같은 DAU 라도 heavy 가 채운 날과 new 가 채운 날은 다르다.

## 함정

- 실습 4(N일 추적)는 마트를 여러 날 적재해야 의미가 있다 — 실무에서는 일 배치로 적재하는
  구조를 먼저 만든다.
- 세그먼트 기준을 자주 바꾸면 시계열 비교가 깨진다. 기준 변경은 버전을 남기고 소급 재계산한다.
- **비율 지표는 분모 크기와 함께** 본다(책 실습 3.3). 인원이 적은 세그먼트는 한두 명에 수치가
  크게 출렁인다 — 분모를 나란히 표기하거나 기간을 누적해 분모를 키운 뒤 해석한다.
- **1일 유지율을 N번 곱해 장기 유지율을 계산하지 않는다**(책 실습 4). 세그먼트 사이 왕복을
  놓친다 — 실습 4처럼 마트를 N일 쌓아 실측한다.
- **재방문율 단독 해석의 착시**(책 1절) — 세그먼트 진단도 유입 코호트의 추세와 같이 본다.

## 학습 가이드

### 핵심 개념 — 이 챕터를 마치면 설명할 수 있어야 하는 것

- **Stock vs Flow** — 어느 시점의 구성(저량) vs 시점 간 이동(유량). DAU는 Stock 위에 얹힌 하루짜리
  관찰값일 뿐, 건강도는 Flow에 있다.
- **5세그먼트** — 가입 첫 주(new)/활동빈도(heavy·light)/이탈 단계(risk·dormant)를 같은 7일
  윈도우 위에서 이산화한 것. new 에서 나가는 경로(→ heavy/light vs → risk)가 곧 첫 주 안착 여부.
- **전이 행렬** — 어제 세그먼트 × 오늘 세그먼트 교차표. 서비스의 "유저 흐름 지도".
- **비율 KPI 5종** — HURR(헤비 유지율)·CURR·Heavy/Light Loss·Reactivation. 전이 행렬을 추적
  가능한 소수 지표로 요약한 것.
- **세그먼트 마트** — 두 시점을 한 행에 담은 테이블. 일 배치로 적재하면 모든 분석의 원천이 된다.

### 개념 체크

1. Stock은 좋아 보이는데(활성 비중 높음) 서비스가 위험할 수 있는 이유는?
   - 힌트: Flow — heavy → light, light → risk 전이가 유입보다 크면 Stock은 시차를 두고 무너진다.
2. HURR와 Reactivation 중 지금 우리 서비스에 먼저 볼 지표는 무엇이고, 판단 근거는?
   - 힌트: heavy 비중이 크면 HURR(지키기), risk 풀이 크면 Reactivation(risk → light 되살리기) —
     Stock 구성이 우선순위를 정한다. 분모 크기도 근거에 포함(risk 51명 중 1명 = 2.0%).
3. DAU가 같은 두 서비스의 세그먼트 구성이 다르면 무엇이 달라지는가?
   - 힌트: 미래 DAU 궤적과 액션 포트폴리오 — heavy 중심은 안정적, new 중심은 리텐션에 취약.
4. 1일 HURR이 92.1%인데 같은 heavy 그룹을 30일 기준으로 보면 55.6%다. 두 숫자가 왜 이렇게
   다르고, 1일 HURR을 30번 곱하면 안 되는 이유는?
   - 힌트: 매일의 작은 이탈이 누적된다 + light로 내려갔다 heavy로 돌아오는 왕복은 곱셈이
     못 잡는다 — 그래서 마트를 N일 쌓아 실측한다(실습 4).
5. 월간 재방문율이 75%로 같은 두 서비스의 Active User 궤적이 완전히 다를 수 있는 이유는?
   - 힌트: 신규 유입의 성장 속도(CCGR) — 재방문율은 성장 단계에 따라 뜻이 달라지는 착시
     지표라, 유입 코호트의 성장과 리텐션 커브의 평평해지는 수준을 같이 봐야 한다.

### 심화 과제

1. **[샌드박스]** `generate_data.py`의 `CHURN_TYPES` 비중에서 `recent` 이탈을 크게 늘리면
   Stock과 전이 행렬이 어떻게 변할지 예측하게 한다(어느 세그먼트가 불고, 어느 전이가 커지나).
   수정 → 재생성 → 노트북 재실행 → 대조. 끝나면 `git checkout -- generate_data.py data/` 후
   재생성으로 원복.
2. **[샌드박스]** heavy 기준을 `active_day_count >= 5 → >= 3`으로 낮추면(⚠ 분류 CASE와 매크로 두 곳 모두)
   HURR와 Heavy Loss가 각각 어느 방향으로 움직일지 예측 → 실행 → 대조. "경계를 낮추면 지표가
   좋아 보이는 착시"를 토론. 원복 필수.
3. **[사고]** 우리 서비스에 "구독 결제했지만 접속 안 하는 유저"가 많다면, 5세그먼트 체계를
   어떻게 확장해야 할까? (접속 외 가치 행동 축 추가, 세그먼트 수의 트레이드오프를 중심으로
   소크라틱하게 토론)
