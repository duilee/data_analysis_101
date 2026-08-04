---
name: data-analysis-101
description: This skill should be used when a reader of the 데이터 분석 book works through or applies this repo's practice chapters — asks to "run/verify a chapter", "apply a method to my own data", "predict DAU", "estimate lifetime/LTV from retention", "segment users", "cluster usage patterns", "use Thompson Sampling / MAB instead of A/B test", "find leading indicators", "decompose MRR / GRR / NRR", "analyze reviews or VOC text", or in Korean "챕터 실행/검증", "내 데이터에 적용", "DAU 예측", "라이프타임 추정", "유저 세그먼트", "클러스터링", "선행지표 찾기", "MRR 분해", "리뷰 분석" — or asks which chapter/method fits a business question.
---

# 데이터 분석 실습 도우미 (data-analysis-101)

데이터 분석 책의 실습 레포(챕터별 폴더)를 독자가 실행·검증하고, 각 챕터의 방법을
독자 자신의 데이터에 적용하도록 돕는 스킬. 아래 4가지 모드 중 독자의 요청에 맞는
모드로 동작하고, 해당 챕터의 reference 파일을 **그 챕터를 다룰 때만** 읽는다.

## 4가지 모드

요청 문구에서 모드를 추론한다. 모드는 자연스럽게 이어질 수 있다(방법 선택 → 실행 → 적용).

1. **실행·검증** — "○○ 챕터 실행해줘", "노트북이 에러나요".
   실행은 한 번에 하되 결과는 단계별로 나눠 보여준다. 아래 5단계 flow로 진행한다:
   ① **예고** — 실행 전에 이 챕터의 실습이 몇 단계(노트북 마크다운 섹션 기준)로
   구성되는지, 지금부터 데이터 생성 → 노트북 전체 실행을 먼저 돌린다는 것(1~2분
   소요)을 알려준다. ② **일괄 실행** — 공통 규약의 워크플로로 노트북을 끝까지
   실행한다(노트북이 진실의 원천 — 셀을 따로 실행해 채팅과 노트북이 어긋나게 하지
   않는다). 실행이 끝나면 "그래프까지 보면서 진행할까요? 브라우저로 열어드릴게요"라고
   **opt-in으로 묻고**, 원하면 노트북을 HTML로 내보내 기본 브라우저로 연다
   (`jupyter nbconvert --to html` → 임시 폴더에 저장, 저장소 밖 — 읽기 전용 사본이라
   커밋된 노트북이 더럽혀지지 않는다). ③ **단계별 워크스루** — 실행 완료된 노트북에서 출력을 추출해 노트북
   섹션 순서대로 하나씩 보여준다. 단계마다 결과(표·숫자)와 의미 1~2문장을 제시하고
   가벼운 확인("다음으로 갈까요? 궁금한 점은 질문하세요")을 받은 뒤 진행한다.
   브라우저를 열어둔 경우, 그래프가 있는 단계에서는 해당 섹션 제목을 짚어 브라우저에서
   보도록 안내한다. 독자가 원하면 일괄 리포트로 전환한다. ④ **검증 판정** — 종료 코드 0만 확인하지
   말고 reference에 적힌 **기대 결과**(심어둔 정답 파라미터가 복원되는지)와 대조한
   판정을 명시적으로 보여준다. ⑤ **마무리 안내** — 결과가 남은 위치를 안내한다:
   실행된 노트북 파일 경로, 그리고 브라우저 HTML은 일회성 읽기 전용 사본이므로
   셀을 수정하거나 실험하려면 노트북 파일을 VS Code 또는 Jupyter로 열라는 것.
   브라우저를 열지 않았다면 그래프는 채팅으로 볼 수 없으니 노트북을 열어 확인하라고
   안내한다.
2. **내 데이터에 적용** — "우리 서비스 데이터로 ○○ 해줘".
   reference의 인터랙티브 프로토콜을 5단계 순서대로 진행한다:
   ① **인테이크** — reference의 질문 목록으로 독자에게 데이터(경로·컬럼·기간·정의 선택)를
   먼저 요청한다. ② **데이터 점검** — 독자 파일에 reference의 검증 체크를 돌리고, 통과하기
   전에는 분석을 시작하지 않는다(미달이면 무엇이 부족한지 알려주고 멈춘다). ③ **코드 치환** —
   reference의 치환 지도를 따라 노트북의 해당 셀을 읽고 독자 데이터용으로 고친다(⚠ 표시된
   중복 상수는 반드시 함께 바꾼다). ④ **단계별 진행** — 한 단계 실행할 때마다 중간 결과를
   보여주고 독자와 확인한 뒤 다음 단계로 간다. ⑤ **해석** — 챕터의 해석 프레임으로 결과를
   읽어 주고 액션 후보로 번역한다.
3. **방법 선택** — 비즈니스 질문만 있고 챕터를 모를 때. 아래 라우팅 표로 챕터를
   추천하고, 후보가 여럿이면 차이(무엇을 진단하는지)를 설명한 뒤 실행/적용으로 잇는다.
4. **개념 설명·퀴즈** — "○○이 뭐야?", "이해했는지 확인해줘", "더 공부해보고 싶어".
   reference의 학습 가이드를 따른다: 핵심 개념 목록으로 무엇을 알아야 하는지 먼저 보여주고 →
   개념 체크 질문을 내고 힌트 줄 기준으로 답을 평가하고 → 더 원하면 심화 과제를 제안한다.
   샌드박스 과제는 **predict-first**: 독자의 예측을 먼저 받은 뒤에 수정·재실행해서 예측과
   실제를 대조한다. 정답을 바로 알려주지 말고 소크라틱하게 되묻는다.

## 라우팅 표 — 비즈니스 질문 → 챕터

| 독자의 질문 | 챕터 (폴더) | reference |
| --- | --- | --- |
| "이 기능을 붙이면 DAU가 얼마나 오를까?" — 기능·신규유입의 DAU 기여 추정 | `이_기능은_DAU_얼마짜리_기능일까` | `references/dau-forecast.md` |
| "DAU가 왜 정체지? 어디서 새고 있지?" — DAU 구성·이동 진단 | `DAU_차트를_봐서는_DAU를_올릴_수_없다` | `references/dau-segments.md` |
| "일주일 데이터로 LTV/라이프타임을 알 수 있나?" | `일주일_데이터로_Lifetime을_예측하라구요` | `references/lifetime.md` |
| "유저 유형(페르소나)을 데이터로 나누고 싶다" | `Machine_Learning으로_찾아보는_유저들의_사용패턴` | `references/clustering.md` |
| "A/B 테스트 비용 없이 배너/문구를 최적화하고 싶다" | `MAB_그거_어떻게_쓰는건데` | `references/mab.md` |
| "D7 리텐션을 미리 알려주는 행동(아하 모먼트)을 찾고 싶다" | `선행지표를_찾는_3가지_방법` | `references/leading-indicators.md` |
| "구독 매출이 건강하게 크고 있나? 이탈이 문제인가?" | `구독_서비스의_성장_지표_확인하기` | `references/mrr.md` |
| "숫자로 안 보이는 불만/만족의 이유를 알고 싶다 (리뷰·VOC)" | `숫자가_말해주지_않는_Why를_읽는_법` | `references/review-analysis.md` |

라우팅 팁: "DAU 정체" 계열 질문은 두 갈래다 — **어디서** 새는지는 dau-segments(구성·전이 진단),
**무엇이** 리텐션을 결정하는지는 leading-indicators(원인 행동 탐색). 순서를 정해야 하면
진단(segments) → 원인(leading-indicators) 순을 권한다.

## 공통 규약 (모든 챕터 동일)

- **실행·검증 워크플로** (챕터 폴더 안에서):
  ```bash
  python generate_data.py                                              # 데이터 (재)생성
  jupyter nbconvert --to notebook --execute --inplace <노트북>.ipynb     # 끝까지 실행
  ```
  노트북 첫 셀이 `%pip install -q -r requirements.txt`로 의존성을 설치하므로 별도 pip 불필요.
  예외: MAB 챕터는 데이터 파일이 없어 `generate_data.py` 단계가 없다.
- **합성 데이터는 정답을 심어 생성**된다(시드 고정). 노트북의 적합/추정 결과가 심어둔
  파라미터를 복원하는지가 검증 포인트이며, reference마다 그 정답이 적혀 있다.
- **SQL은 DuckDB로 로컬 CSV 위에서 실행**한다(`duckdb.query(sql).to_df()`). 같은 쿼리가
  노트북 인라인(`query = """…"""`)과 `sql/*.sql` 파일 양쪽에 있다 — 독자 데이터 적용 시
  치환 대상은 노트북 인라인 쿼리다. 예외: MAB·리뷰 분석 챕터는 SQL/DuckDB를 쓰지 않는다.
- 시각화 라벨은 영어, 서술은 한국어.
- 독자 데이터에 적용할 때 챕터 폴더 안의 예시 CSV를 덮어쓰지 말 것 — 독자 데이터는
  별도 경로에 두고 쿼리의 파일 경로만 바꾼다.
- 샌드박스 과제로 생성기·노트북을 수정한 뒤에는 반드시 원상 복구를 확인한다
  (`git status`로 잔여 변경 확인 → `git checkout -- <파일>` 또는 원래 값 복원 후 재생성).

## Reference 파일

챕터 하나를 다룰 때 그 챕터의 reference **하나만** 읽는다. 각 파일은 방법 요약,
실행·검증 절차와 기대 결과, 내 데이터 적용 레시피(입력 스키마·치환 지점·튜닝 노브·함정),
개념 체크 질문을 담고 있다.

- `references/dau-forecast.md` — power law 리텐션 적합 → DAU 기여 공식
- `references/dau-segments.md` — 7세그먼트 Stock/Flow/비율 KPI 진단
- `references/lifetime.md` — 7일 리텐션으로 lifetime 3가지 추정 + 삼각측량
- `references/clustering.md` — KMeans 페르소나 클러스터링
- `references/mab.md` — Thompson Sampling 시뮬레이션과 실전 보완 기법
- `references/leading-indicators.md` — EDA·SHAP·Sankey 3렌즈 선행지표 탐색
- `references/mrr.md` — 스토어 결제 로그 MRR 6요소 분해, GRR/NRR
- `references/review-analysis.md` — 리뷰 텍스트 분석 (형태소→키워드→네트워크→LDA→원문)
