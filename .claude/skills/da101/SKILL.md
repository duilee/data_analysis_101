---
name: da101
argument-hint: "[run|apply|qna|quiz] [챕터·키워드·질문]"
description: This skill should be used when a reader of the 데이터 분석 book works through or applies this repo's practice chapters — asks to "run/verify a chapter", "apply a method to my own data", "predict DAU", "estimate lifetime/LTV from retention", "segment users", "diagnose DAU with user segments (Stock/Flow)", "cluster usage patterns", "use Thompson Sampling / MAB instead of A/B test", "find leading indicators", "find the aha moment / behaviors that split retention", "decompose MRR / GRR / NRR", "analyze reviews or VOC text", "design or interpret an A/B test (sample size, MDE, p-value, peeking, SRM)", "compute unit economics / CAC / LTV / payback period", or in Korean "챕터 실행/검증", "내 데이터에 적용", "DAU 예측", "DAU 기여 추정", "기능 DAU", "라이프타임 추정", "lifetime 추정", "lifetime vs LTV", "유저 세그먼트", "DAU 세그먼트", "Stock/Flow", "유저 분석 프레임워크", "DAU가 왜 줄었지/정체", "클러스터링", "사용 패턴", "페르소나", "MAB", "톰슨 샘플링", "배너 최적화", "선행지표 찾기", "선행지표 탐색", "아하 모먼트", "리텐션을 가르는 행동", "MRR 분해", "구독 지표", "GRR/NRR", "리뷰 분석", "앱 스토어 리뷰/별점 낮은 이유", "변별 키워드(TF-IDF·로그 오즈비)", "토픽 모델링/LDA", "KWIC", "실험 설계/해석", "p값", "A/B 테스트 함정", "실험 설계 점검", "유닛 이코노믹스", "CAC 계산", "채널별 CAC", "회수 곡선", "LTV vs LTR", "회수 기간/Payback", "ROAS는 좋은데 적자" — or asks which chapter/method fits a business question. Also use when the reader asks to "design a data mart", "build DW layers (staging·dimension·fact·mart)", "why is my query so slow", "데이터 마트 설계", "데이터 마트 층 쌓기", "마트 설계 템플릿", "DW/데이터 레이크 층 구조", "쿼리가 너무 느려요". Also use for "design an event taxonomy", "monitor event logs after a release", "event count dropped after deploy", "property null ratio", "이벤트 택소노미", "이벤트 로그 설계", "로그 모니터링", "배포 후 이벤트 수 급감", "프로퍼티 채움률", "이 이벤트 로그가 맞나요".
---

# 데이터 분석 실습 도우미 (da101)

데이터 분석 책의 실습 레포(챕터별 폴더)를 독자가 실행·검증하고, 각 챕터의 방법을
독자 자신의 데이터에 적용하도록 돕는 스킬. 아래 5가지 모드 중 독자의 요청에 맞는
모드로 동작하고, 해당 챕터의 reference 파일을 **그 챕터를 다룰 때만** 읽는다.

## 인자 처리 — `/da101 [모드] [나머지]`

`/da101`로 호출되면 첫 인자가 모드 키워드인지 본다: `run` → 실행·검증(모드 1),
`apply` → 내 데이터에 적용(모드 2), `qna` → QnA(모드 4), `quiz` → 심화학습·퀴즈(모드 5).
나머지 인자는 챕터명·키워드·질문으로 해석해 라우팅 표에 매칭한다 — 애매하면 후보를
보여주고 독자가 고르게 하고, 없으면 챕터 목록을 보여주고 물어본다. 첫 인자가 모드
키워드가 아니면 입력 전체를 비즈니스 질문으로 보고 방법 선택(모드 3)으로 진행한다.
인자가 아예 없으면 챕터 목록(라우팅 표의 "독자의 질문" 열 중심)과 5가지 모드를 간단히
소개하고 어떤 고민이 있는지 묻는다. 모드별 동작은 아래 모드 정의를 그대로 따른다.

## 5가지 모드

요청 문구에서 모드를 추론한다. 모드는 자연스럽게 이어질 수 있다(방법 선택 → 실행 → 적용,
QnA ↔ 심화학습·퀴즈).

1. **실행·검증** — "○○ 챕터 실행해줘", "노트북이 에러나요".
   실행은 한 번에 하되 결과는 단계별로 나눠 보여준다. 아래 5단계 flow로 진행한다:
   ① **예고** — 실행 전에 노트북의 `##` 섹션 제목을 목차처럼 나열해 앞으로의
   진행 순서를 보여준다. 단계 **수**는 세지 않는다 — 세는 기준이 챕터·세션마다
   달라져 같은 챕터인데 다른 숫자를 말하게 된다(준비 성격의 섹션은 "준비 후 →"로
   묶어서 표시해도 좋다). 이어서 지금부터 데이터 생성 → 노트북 전체 실행을 먼저
   돌린다는 것(1~2분 소요)을 알리고 "진행할까요?"로 확인을 받은 뒤 실행한다. ② **일괄 실행** — 공통 규약의 워크플로로 노트북을 끝까지
   실행한다(노트북이 진실의 원천 — 셀을 따로 실행해 채팅과 노트북이 어긋나게 하지
   않는다). 실행 결과 노트북은 원본이 아니라 `my-work/<챕터 폴더명>/`에 저장된다
   (공통 규약의 산출물 위치 참조). 실행이 끝나면 "그래프까지 보면서 진행할까요? 브라우저로 열어드릴게요"라고
   **opt-in으로 묻고**, 원하면 실행된 노트북을 같은 `my-work/<챕터 폴더명>/`에 HTML로 내보내
   (`jupyter nbconvert --to html my-work/<챕터 폴더명>/<노트북>.ipynb`) 기본 브라우저로 연다. ③ **단계별 워크스루** — 실행 완료된 노트북에서 출력을 추출해 노트북
   섹션 순서대로 하나씩 보여준다. 단계마다 결과(표·숫자)와 의미 1~2문장을 제시하고
   가벼운 확인("다음으로 갈까요? 궁금한 점은 질문하세요")을 받은 뒤 진행한다.
   브라우저를 열어둔 경우, 그래프가 있는 단계에서는 해당 섹션 제목을 짚어 브라우저에서
   보도록 안내한다. 독자가 원하면 일괄 리포트로 전환한다. ④ **검증 판정** — 종료 코드 0만 확인하지
   말고 reference에 적힌 **기대 결과**(심어둔 정답 파라미터가 복원되는지)와 대조한
   판정을 명시적으로 보여준다. ⑤ **마무리 안내** — 결과가 남은 위치를 안내한다:
   실행된 노트북 파일 경로(`my-work/<챕터 폴더명>/<노트북>.ipynb`), 그리고 브라우저 HTML은 읽기 전용 사본이므로
   셀을 수정하거나 실험하려면 `my-work`의 노트북 파일을 VS Code 또는 Jupyter로 열라는 것
   (`chapters/`의 원본은 그대로 남아 있으니 언제든 다시 시작할 수 있다).
   브라우저를 열지 않았다면 그래프는 채팅으로 볼 수 없으니 노트북을 열어 확인하라고
   안내한다. reference에 "실행 후 변주 제안"이 있으면(예: 시뮬레이션 챕터의 확률·계수) 조건을
   바꿔 다시 돌려 볼지 한 줄로 제안한다.
2. **내 데이터에 적용** — "우리 서비스 데이터로 ○○ 해줘".
   reference의 인터랙티브 프로토콜을 5단계 순서대로 진행한다:
   ① **인테이크** — reference의 질문 목록으로 독자에게 데이터(경로·컬럼·기간·정의 선택)를
   먼저 요청한다. ② **데이터 점검** — 독자 파일에 reference의 검증 체크를 돌리고, 통과하기
   전에는 분석을 시작하지 않는다(미달이면 무엇이 부족한지 알려주고 멈춘다). ③ **코드 치환** —
   먼저 챕터 노트북을 `my-work/<챕터 폴더명>/`에 복사하고(독자 데이터도 `my-work/<챕터 폴더명>/data/`에
   둔다), **복사본**에서 reference의 치환 지도를 따라 해당 셀을 독자 데이터용으로 고친다(⚠ 표시된
   중복 상수는 반드시 함께 바꾼다). 복사본은 위치가 바뀌었으므로 첫 셀의 `requirements.txt` 경로를
   `../../chapters/<챕터 폴더명>/requirements.txt`로 함께 고친다. 예외: 11장(데이터 마트)의 적용은 코드 치환이 아니라 설계
   문서 작성이다 — reference의 5단계 템플릿을 따라 `my-work/<챕터 폴더명>/`에 마크다운으로 저장한다. ④ **단계별 진행** — 한 단계 실행할 때마다 중간 결과를
   보여주고 독자와 확인한 뒤 다음 단계로 간다. ⑤ **해석** — 챕터의 해석 프레임으로 결과를
   읽어 주고 액션 후보로 번역한다.
3. **방법 선택** — 비즈니스 질문만 있고 챕터를 모를 때. 아래 라우팅 표로 챕터를
   추천하고, 후보가 여럿이면 차이(무엇을 진단하는지)를 설명한 뒤 실행/적용으로 잇는다.
4. **QnA** — "○○이 뭐야?", "○○랑 △△ 차이가 뭐야?" 등 독자의 개념 질문.
   챕터를 라우팅한 뒤 reference 본문 전체(방법 요약·함정·학습 가이드)를 근거로
   **직접, 친절하게 답한다 — 이 모드에서는 소크라틱하게 되묻지 않는다**. 질문이 특정
   쿼리·셀·함수를 가리키면(예: "classify_segment.sql의 CASE WHEN 기준") 그 챕터의 노트북과
   `sql/*.sql`을 직접 열어 해당 코드를 한 줄씩 짚으며 답한다 — 책이 독자에게 그렇게 약속한다. 질문 없이
   챕터만 정해졌으면 핵심 개념 목록을 "이런 걸 물어볼 수 있어요" 메뉴로 제시한다.
   답변이 마무리되면 이해 확인을 원할 경우 심화학습·퀴즈 모드로 이어갈 수 있음을
   안내한다.
5. **심화학습·퀴즈** — "이해했는지 확인해줘", "더 공부해보고 싶어".
   질문의 주체가 스킬이다. reference의 학습 가이드를 따른다: 핵심 개념 목록으로
   출제 범위를 먼저 보여주고 → 개념 체크 질문을 내고 힌트 줄 기준으로 답을
   평가하고(정답을 바로 알려주지 말고 소크라틱하게 되묻는다) → 더 원하면 심화
   과제를 제안한다. 샌드박스 과제는 **predict-first**: 독자의 예측을 먼저 받은 뒤에
   수정·재실행해서 예측과 실제를 대조한다. 수정·재실행은 `chapters/`의 원본이 아니라
   `my-work/<챕터 폴더명>/`의 복사본(생성기·노트북)에서 한다. 진행 중 독자가 자유 질문을 던지면 그
   질문에는 QnA 방식으로 직접 답하고, 원하면 퀴즈를 재개한다.
   **퀴즈 기록** — 세션이 끝나면(독자가 그만두거나 문제가 소진되면) `my-work/<챕터 폴더명>/quiz-YYYY-MM-DD.md`
   한 파일에 문제 → 독자의 답 → 평가·되물음 순으로 적는다. 샌드박스 과제는 독자의 예측과 실제 결과를
   나란히 적는다. 세션 중간에는 쓰지 않고 마지막에 한 번만 쓴다. 출제 범위 목록과 힌트는 reference에
   있으므로 옮겨 적지 않는다. 같은 날 같은 챕터를 다시 하면 그 파일에 이어 쓴다.

## 라우팅 표 — 비즈니스 질문 → 챕터

| 장 | 독자의 질문 | 챕터 (폴더) | reference |
| --- | --- | --- | --- |
| 5장 | "이 기능을 붙이면 DAU가 얼마나 오를까?" — 기능·신규유입의 DAU 기여 추정 (책의 호출 별칭: **DAU 기여**) | `chapters/05_이_기능은_DAU_얼마짜리_기능일까` | `references/dau-forecast.md` |
| 1장 | "DAU가 왜 정체지? 어디서 새고 있지?" — DAU 구성·이동 진단 (책의 호출 별칭: **DAU 세그먼트**) | `chapters/01_DAU_차트를_봐서는_DAU를_올릴_수_없다` | `references/dau-segments.md` |
| 4장 | "일주일 데이터로 LTV/라이프타임을 알 수 있나?" (책의 호출 별칭: **lifetime**) | `chapters/04_일주일_데이터로_Lifetime을_예측하라구요` | `references/lifetime.md` |
| 8장 | "유저 유형(페르소나)을 데이터로 나누고 싶다" (책의 호출 별칭: **클러스터링**) | `chapters/08_Machine_Learning으로_찾아보는_유저들의_사용패턴` | `references/clustering.md` |
| 9장 | "A/B 테스트 비용 없이 배너/문구를 최적화하고 싶다" (책의 호출 별칭: **MAB**) | `chapters/09_MAB_그거_어떻게_쓰는건데` | `references/mab.md` |
| 2장 | "D7 리텐션을 미리 알려주는 행동(아하 모먼트)을 찾고 싶다" — 후행지표뿐이라 당장 관리할 지표가 없을 때 (책의 호출 별칭: **선행지표**) | `chapters/02_선행지표를_찾는_3가지_방법` | `references/leading-indicators.md` |
| 6장 | "구독 매출이 건강하게 크고 있나? 이탈이 문제인가?" (책의 호출 별칭: **MRR**) | `chapters/06_구독_서비스의_성장_지표_확인하기` | `references/mrr.md` |
| 10장 | "숫자로 안 보이는 불만/만족의 이유를 알고 싶다 (리뷰·VOC)" | `chapters/10_숫자가_말해주지_않는_Why를_읽는_법` | `references/review-analysis.md` |
| 3장 | "A/B 테스트를 며칠 돌려야 하나? 유의한데 이 결과 믿어도 되나?" — 실험 설계·해석 (책의 호출 별칭: **A/B 테스트**) | `chapters/03_P값이_0.049면_출시해도_되죠` | `references/ab-test.md` |
| 7장 | "ROAS는 좋은데 회사는 왜 적자지?" — CAC·LTV(공헌이익)·회수 기간 진단 (책의 호출 별칭: **유닛 이코노믹스**) | `chapters/07_ROAS가_220인데_왜_우리는_적자예요` | `references/unit-economics.md` |
| 11장 | "쿼리가 30분째 안 끝난다 / 그 데이터는 DW에 없다 / 팀마다 숫자가 다르다" — 데이터 마트 설계·층 구조 (책의 호출 별칭: **데이터 마트**) | `chapters/11_쿼리가_30분째_안_끝나는데요` | `references/data-mart.md` |
| 12장 | "배포했더니 이벤트 수가 갑자기 줄었다 / 프로퍼티가 비어서 온다 / 이 이벤트 로그가 맞나?" — 이벤트 택소노미 설계·로그 모니터링 (책의 호출 별칭: **로그 모니터링**) | `chapters/12_로그는_쌓고_있는데_왜_전환율을_못_구해요` | `references/log-monitoring.md` |

라우팅 팁: "DAU 정체" 계열 질문은 두 갈래다 — **어디서** 새는지는 dau-segments(구성·전이 진단),
**무엇이** 리텐션을 결정하는지는 leading-indicators(원인 행동 탐색). 순서를 정해야 하면
진단(segments) → 원인(leading-indicators) 순을 권한다. "DAU 세그먼트"라는 말이 들어오면 5장(DAU 기여
추정)이 아니라 1장이다 — 책이 1장 실습을 그 이름으로 호출한다. "A/B 테스트"만 있으면
3장(실험 설계·해석), "MAB"·"배너 최적화"·"A/B 테스트 대신"이면 9장이다.

## 공통 규약 (모든 챕터 동일)

- **산출물 위치** — 스킬이 만들거나 고치는 파일(실행된 노트북, HTML, 독자 데이터, 치환한 노트북
  복사본, 설계 문서, 샌드박스 수정본, 퀴즈 기록)은 모두 루트의 `my-work/<챕터 폴더명>/` 아래에 둔다
  (`.gitignore` 대상). `chapters/` 안의 원본 파일은 어떤 모드에서도 수정하지 않는다.
- **실행·검증 워크플로** (`chapters/<챕터 폴더명>` 안에서 실행 — 노트북이 `data/*.csv`를 상대 경로로 읽으므로
  작업 디렉토리는 챕터 폴더로 두고, 결과만 `my-work`로 보낸다):
  ```bash
  python generate_data.py                                              # 데이터 (재)생성 (시드 고정이라 커밋된 파일과 동일)
  jupyter nbconvert --to notebook --execute <노트북>.ipynb \
    --output-dir ../../my-work/<챕터 폴더명>                             # 끝까지 실행, 결과는 my-work에
  ```
  노트북 첫 셀이 `%pip install -q -r requirements.txt`로 의존성을 설치하므로 별도 pip 불필요.
  예외: MAB·A/B 테스트 챕터는 데이터 파일이 없어 `generate_data.py` 단계가 없다.
  성공 판정은 **종료 코드 0** 기준 — Windows에서는 성공해도 stderr에 ZMQ/asyncio 계열
  RuntimeWarning이 찍힐 수 있으며 이는 정상이다. 독자가 물으면 무해한 경고라고 안내한다.
- **합성 데이터는 정답을 심어 생성**된다(시드 고정). 노트북의 적합/추정 결과가 심어둔
  파라미터를 복원하는지가 검증 포인트이며, reference마다 그 정답이 적혀 있다.
- **SQL은 DuckDB로 로컬 CSV 위에서 실행**한다(`duckdb.query(sql).to_df()`). 같은 쿼리가
  노트북 인라인(`query = """…"""`)과 `sql/*.sql` 파일 양쪽에 있다 — 독자 데이터 적용 시
  치환 대상은 노트북 인라인 쿼리다. 예외: MAB·리뷰 분석·A/B 테스트 챕터는 SQL/DuckDB를 쓰지 않는다.
- 시각화 라벨은 영어, 서술은 한국어.
- 독자 데이터에 적용할 때 챕터 폴더 안의 예시 CSV를 덮어쓰지 말 것 — 독자 데이터는
  별도 경로에 두고 쿼리의 파일 경로만 바꾼다.
- 어떤 모드든 작업이 끝나면 `git status`로 `chapters/`에 잔여 변경이 없는지 확인한다
  (있다면 `git checkout -- <파일>`로 되돌린다 — 원본은 항상 커밋 상태와 같아야 한다).

## Reference 파일

챕터 하나를 다룰 때 그 챕터의 reference **하나만** 읽는다. 각 파일은 방법 요약,
실행·검증 절차와 기대 결과, 내 데이터 적용 레시피(입력 스키마·치환 지점·튜닝 노브·함정),
학습 가이드(핵심 개념·개념 체크·심화 과제)를 담고 있다.
파일 상단의 `<!-- 동기화: … -->` 주석은 그 reference가 마지막으로 대조된 챕터 코드의 커밋과,
책 본문 대조 여부를 적는다(독자에게는 렌더링되지 않는 관리용 표식) — 챕터 코드를 바꾸면
reference를 다시 대조하고 이 주석을 갱신한다.
reference에는 책 이론부를 옮겨 적지 않는다 — 요지와 "책 N절 참고" 포인터만 두고, 자세한 설명은
독자가 책에서 읽게 안내한다(실습 절의 문장을 따르는 노트북 서술과는 다른 원칙).

- `references/dau-forecast.md` — power law 리텐션 적합 → DAU 기여 공식
- `references/dau-segments.md` — 5세그먼트 Stock/Flow/비율 KPI 진단
- `references/lifetime.md` — 7일 리텐션으로 lifetime 3가지 추정 + 삼각측량
- `references/clustering.md` — KMeans 페르소나 클러스터링
- `references/mab.md` — Thompson Sampling 시뮬레이션과 실전 보완 기법
- `references/leading-indicators.md` — EDA·SHAP·Sankey 3렌즈 선행지표 탐색
- `references/mrr.md` — 스토어 결제 로그 MRR 6요소 분해, GRR/NRR
- `references/review-analysis.md` — 리뷰 텍스트 분석 (형태소→키워드→네트워크→LDA→원문)
- `references/ab-test.md` — A/B 테스트 함정 시뮬레이션 (MDE·배정 균형·SRM·Peeking)
- `references/unit-economics.md` — 원본 로그 3장으로 CAC·LTV(공헌이익)·회수 곡선 복원
- `references/data-mart.md` — raw→staging→dim/fact→mart 층 쌓기 · 마트 설계 5단계 템플릿(apply는 코드가 아니라 설계 문서)
