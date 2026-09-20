# 12장. 로그는 다 쌓고 있는데요?

택소노미 문서가 맞아도 배포 뒤에 로그는 조용히 깨집니다 — 이벤트가 안 오거나, 두 번 오거나, 오긴 오는데 값이
비어 있거나. 가상의 콘텐츠 앱 로그 30일치(8월 25일 3.5.0 배포에 사고 5종을 심어 둠 — 다섯 모두 표준 문턱으로 잡힘)를 놓고, 일별 마트를 만들고
일주일 전과 비교해 이상을 잡아 슬랙에 보낼 리포트 한 장을 만드는 실습 코드입니다.

- **실습 1. 일별 마트 만들기.** 원본 로그에서 이벤트 마트(날짜·플랫폼·이벤트별 건수)와 프로퍼티 채움률 마트를 DuckDB로 만듭니다.
- **실습 2. 이벤트 수 이상 감지.** 기준일(D-2)과 일주일 전(D-9)을 비교해 ±60%·최소 50건 문턱을 넘는 이벤트를 찾고 30일 추세를 그립니다.
- **실습 3. 프로퍼티 채움률 이상 감지.** (이벤트, 프로퍼티)별 not-null 비율이 60% 넘게 떨어진 것을 찾습니다.
- **실습 4. 리포트 만들기.** 결과를 슬랙 메시지 형식 텍스트로 조립합니다 (전송은 주석 한 줄).

## 실행 방법

```bash
python generate_data.py              # 예시 데이터 생성 (data/*.csv 3개, 시드 고정)
jupyter notebook log_monitoring.ipynb  # 노트북을 위에서 아래로 실행 (첫 셀이 의존성 설치)
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `generate_data.py` | 30일치 합성 로그 + 택소노미 문서 2개 생성기. 8/25 배포 사고 5종을 심어 둠 (상단 주석 — 다섯 모두 잡힘) |
| `data/event_log.csv` | `event_time, user_id, platform, app_version, event_name, screen_name, properties(JSON)` — 약 17만 행 |
| `data/taxonomy_events.csv` | 이벤트 문서 (이름·유형·발생 주체·플랫폼·화면·설명·상태·수명·적용 시작 버전) |
| `data/taxonomy_properties.csv` | 프로퍼티 문서 (이름·범위 event/user·타입·허용값·설명·붙는 이벤트) |
| `sql/mart_event_daily.sql` | 일별 이벤트 마트 (노트북 인라인과 동일) |
| `sql/mart_event_param_daily.sql` | 일별 프로퍼티 채움률 마트 |
| `sql/event_count_anomaly.sql` | 이벤트 수 D-2 vs D-9 이상 감지 (`params` CTE에 기준일·문턱·최소 건수) |
| `sql/param_null_anomaly.sql` | 프로퍼티 채움률 이상 감지 |
| `img/` | 노트북이 저장하는 추세 그림 2개 (본문 삽입용) |
| `extra/taxonomy_check.py`, `extra/sql/` | 부록: 택소노미 문서 규칙 검사 + 문서 vs 로그 대조 (본문 5.1절). `extra/` 안에서 실행 |
| `log_monitoring.ipynb` | 실습 1~4 노트북 |
