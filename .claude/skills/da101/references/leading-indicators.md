# 선행지표 탐색 — EDA·SHAP·Sankey 3렌즈 교차 확인

**챕터**: `선행지표를_찾는_3가지_방법/` · 노트북: `leading_indicators.ipynb`

## 이 방법이 푸는 문제

후행지표(D7 잔존)는 결과라서 직접 움직일 수 없다. 같은 신규 유저 이벤트 로그 한 벌에서
D7 잔존을 미리 알려주는 **선행지표(아하 모먼트 행동)**를 세 가지 렌즈로 찾고, 세 방법이
공통으로 가리키는 행동만 최종 후보로 확정한다:

- **실습 1. EDA 비교** — D7 잔존/비잔존 코호트의 D0~D1 행동 발생 비중·평균 횟수 차이.
- **실습 2. SHAP** — LGBM으로 D7 잔존 예측 모델을 학습(Optuna 튜닝)하고, SHAP summary로
  기여도, dependence plot으로 임계점("N회 이상부터 효과")을 읽는다.
- **실습 3. Sankey** — 설치 직후 행동 흐름을 그리고 전이별 D7 잔존율로 색칠해, 어느
  갈림길에서 잔존이 갈리는지 본다.

## 실행·검증

```bash
python generate_data.py      # data/event_log.csv 생성 (SEED=314, 유저 12,000명)
jupyter nbconvert --to notebook --execute --inplace leading_indicators.ipynb
```

- 입력: `data/event_log.csv` (`event_timestamp, event_date, user_id, event_name, screen_name,
  event_count, description`).
- SQL 3개: `eda_leading_indicator.sql`, `feature_matrix.sql`, `sankey_transitions.sql`.
- **기대 결과**: 생성기가 잠재 품질·경로 의존 잔존을 심어 두었으므로, 세 렌즈가 **같은
  행동들**을 상위 선행지표로 가리켜야 한다(EDA `share_diff` 상위 ≈ SHAP 상위 피처 ≈ Sankey의
  고잔존 갈림길). 세 실습의 결과를 나란히 놓고 이 일치를 확인한다.
- 의존성이 가장 무거운 챕터다(lightgbm, shap, optuna, plotly 등) — 첫 실행 시 설치 시간이 걸린다.

## 내 데이터에 적용 — 인터랙티브 프로토콜

아래 1→5 순서로 진행한다. 각 단계 결과를 독자에게 보여주고 확인한 뒤 다음으로 간다.
이 노트북에는 `[내 데이터 적용]` 주석이 없다 — 아래 치환 지도가 유일한 안내이며,
⚠ D7 윈도가 **4개 쿼리**에 흩어져 있는 점이 최대 함정이다.

### 1. 인테이크 — 독자에게 물을 것

- 신규 유저 이벤트 로그의 **파일 경로**는?

| 역할 (노트북 예시명) | 타입 | 의미 | 필수 |
| --- | --- | --- | --- |
| `user_id` | TEXT | 유저 식별자 | 필수 |
| `event_name` | TEXT | 이벤트명 | 필수 |
| `event_timestamp` / `event_date` | TIMESTAMP / DATE | 이벤트 시각·일자 | 필수 |
| `event_count` | INT | 이벤트 횟수 (없으면 행당 1) | 선택 |

- **설치(기준) 이벤트**의 이벤트명은? (노트북 앵커: `'application_install'` — 없으면 유저별
  첫 이벤트로 파생)
- **타깃(후행지표) 정의**는? — 기본 D7 잔존 외에 구독 전환·재구매 등 무엇이든 가능. 라벨
  관측에 필요한 경과일도 함께 정한다.
- **행동 관찰 윈도**는? (노트북: EDA는 D0~D1, 피처 행렬은 D0만 — 독자 서비스의 "결정적
  초기 구간"으로)
- 분석 대상 설치 기간과 유저 수는? — **타깃 관측 경과일이 지난 유저만** 포함해야 한다.

### 2. 데이터 점검 — 통과 전 분석 시작 금지

```python
duckdb.query("""SELECT COUNT(DISTINCT user_id) AS users,
    COUNT(DISTINCT event_name) AS event_kinds, MIN(event_date) AS min_d, MAX(event_date) AS max_d
    FROM read_csv_auto('YOUR_CSV_PATH')""").to_df()
```

- 통과 기준: 설치 이벤트가 유저마다 존재하는지(없는 유저 비율), 유저 ≥ 수천 명(실습 2 모델
  학습 안정성), `max_d`가 마지막 설치일 + 타깃 경과일 이후인지(라벨 누수·미성숙 방지),
  타깃 라벨의 양/음 비율(극단 불균형이면 경고).

### 3. 코드 치환 지도

| 앵커 (실습/식별자) | 무엇을 | 어떻게 |
| --- | --- | --- |
| 로드 셀 | `data/event_log.csv` 경로, 컬럼명 | 독자 데이터로 |
| `label_query` | 기준 이벤트 `'application_install'` | 독자 정의로 |
| ⚠ D7 윈도 | `= 7` 조건이 **`label_query`·`eda_query`·`fm_query`·`sankey_query` 4곳** + `eda_query`의 `retention_label` 조인 캡 `AND date_diff('day', i.event_date, l.event_date) <= 7` **1곳, 총 5곳** | 타깃 경과일 변경 시 5곳 모두 (조인 캡을 빼먹으면 EDA 라벨이 전부 0이 된다) |
| `eda_query` | 분석 기간 필터 `WHERE event_date BETWEEN DATE '2026-01-01' AND DATE '2026-01-31'`, 행동 윈도 `<= 1` (D0~D1), 노이즈 컷 `HAVING d7_ret1_share >= 10 OR d7_ret0_share >= 10` | 독자 기간·윈도·데이터 크기에 맞게 |
| `fm_query` ⚠ | 피처 이벤트명 리스트 (`content_view, like_content, search_used, share_content, page_view_profile, settings_open, error_popup, tutorial_complete, push_allow`)가 하드코딩 | 독자 이벤트 택소노미로 재작성 + SHAP 셀의 `NUMERIC` 리스트도 **함께** |
| 모델 셀 | `train_test_split(test_size=0.10, random_state=314, stratify=y)`, LGBM 파라미터, Optuna `n_trials=25` | 기본 유지 권장, 데이터가 작으면 `test_size` 상향 |
| Sankey CONFIG | `MAX_STEPS = 10`, `TOP_K = 6`, `MIN_USERS = 20`, 세션 윈도 `INTERVAL 1 HOUR` | 이벤트 종류 많으면 `TOP_K`↓·`MIN_USERS`↑로 노이즈 전이 제거 |
| 진단 셀 | `ret_gap_at_source > 15`, `user_count >= 50` 컷 | 데이터 크기에 맞게 |

- `sql/*.sql` 3개는 인라인 쿼리의 전시용 사본 — 노트북만 고치면 sql 파일은 구버전으로 남는다.

### 4. 단계별 진행

1. `label_query` → 라벨 분포(잔존율) 확인. 상식과 크게 다르면 라벨 정의 재점검.
2. 실습 1 EDA → `share_diff` 상위 표·차트 제시, 후보 행동 목록을 독자와 합의.
3. 실습 2: `fm_query` → baseline LGBM(`report`) → ROC-AUC가 0.5 근처면 피처 재설계로 회귀.
   Optuna 튜닝 → SHAP summary → 상위 피처를 EDA 결과와 대조. dependence plot으로 임계점 읽기.
4. 실습 3: Sankey 생성 → 색(전이별 잔존율)이 갈리는 갈림길 확인 → `branches` 진단.
5. 세 렌즈의 결과를 나란히 정리해 공통 행동만 선행지표 후보로 확정 → A/B 실험 후보로 번역.

### 5. 결과 해석

- 세 렌즈가 겹치는 행동만 후보로 올린다. 한 렌즈에만 나오면 그 렌즈의 맹점을 의심한다.
- dependence plot의 임계점은 "온보딩에서 N회 유도" 같은 액션 기준으로 번역한다.
- 최종 결론은 언제나 "실험할 가설 목록"이다 — 인과 확정이 아니다.

## 함정

- 찾은 것은 **상관**이다. 인과 주장은 실험(A/B)으로 확인한다.
- 미래 정보 누수 주의: 피처는 반드시 라벨 시점 이전 구간의 행동만으로 만든다.
- 발생 비중이 극히 낮은 이벤트는 SHAP 상위에 올라도 액션 대상이 되기 어렵다 — 비중과 함께 본다.

## 학습 가이드

### 핵심 개념 — 이 챕터를 마치면 설명할 수 있어야 하는 것

- **선행 vs 후행지표** — 움직일 수 있는 초기 행동 vs 그 결과로 나타나는 지표. 액션은 선행에만
  걸 수 있다.
- **아하 모먼트** — 잔존 유저와 비잔존 유저를 가르는 결정적 초기 경험(행동 + 임계 횟수).
- **SHAP value** — 각 피처가 개별 예측을 얼마나 밀고 당겼는지의 기여도 분해. summary는 전체
  경향, dependence는 피처값-기여도 관계(임계점).
- **데이터 누수(leakage)** — 라벨 이후의 정보가 피처에 섞이는 것. 시간 경계를 지키는 것이
  이 분석의 생명선.
- **세 방법의 교차 확인** — 가정이 다른 방법들이 같은 답을 가리킬 때만 믿는 태도. EDA(단변량)·SHAP
  (다변량 모델)·Sankey(경로) 는 서로의 맹점을 보완한다.

### 개념 체크

1. 선행지표를 한 방법이 아니라 세 방법으로 찾는 이유는? 각 렌즈의 맹점을 하나씩 말해 보라.
   - 힌트: EDA는 교호작용을 못 보고, SHAP은 모델이 틀리면 같이 틀리고, Sankey는 순서는 보지만
     횟수·강도를 뭉갠다.
2. SHAP dependence plot에서 "임계점"은 무엇을 뜻하고, 액션으로 어떻게 번역되는가?
   - 힌트: 기여도가 양(+)으로 꺾이는 피처값 — "그 횟수까지 유도"가 온보딩 목표가 된다.
3. 모델 정확도(ROC-AUC)가 높다는 것과 좋은 선행지표를 찾았다는 것은 왜 다른 문제인가?
   - 힌트: 예측력 좋은 피처가 실행 불가능하거나(예: 총 사용시간), 결과의 동어반복일 수 있다.

### 심화 과제

1. **[샌드박스]** `generate_data.py`의 `EVENT_META`에서 핵심 이벤트 하나의 잔존 연관 강도를
   낮추면(생성기를 열어 해당 이벤트의 품질 결합 파라미터 확인) SHAP 순위와 EDA `share_diff`
   순위가 어떻게 바뀔지 예측하게 한다 → 수정 → 재생성 → 재실행 → 대조. 끝나면
   `git checkout -- generate_data.py data/` 후 재생성으로 원복.
2. **[샌드박스]** `fm_query`의 피처 윈도는 현재 D0만이다(`d0_session` CTE의
   `date_diff('day', b.install_date, e.event_date) = 0`). 이를 `<= 1`(D0~D1)로 넓히면
   모델 AUC와 SHAP 상위 피처가 어떻게 변할지 예측 → 실행 → 대조. "관찰 윈도를 넓히면
   예측력은 오르지만 액션 가능 시점은 늦어진다"는 트레이드오프를 토론. 원복 필수.
3. **[사고]** 세 렌즈가 서로 다른 행동을 1위로 가리켰다. 어느 것을 믿을지 정하는 절차를
   설계해 보라. (각 렌즈의 가정 점검 → 교집합 우선 → 실험 설계로 유도, 정답 없음)
