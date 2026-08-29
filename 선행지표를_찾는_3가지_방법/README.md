# 2장. 선행지표를 찾는 3가지 방법

후행지표(D7 잔존)를 끌어올릴 **선행지표**를, 같은 신규 유저 이벤트 로그 한 벌에서 세 가지
방법으로 찾는 실습 코드입니다. *같은 데이터·같은 타깃, 세 가지 렌즈.*

- **실습 1. EDA 비교.** D7 잔존/비잔존으로 라벨링하고 D0~D1 행동의 발생 비중·평균 횟수를 비교해 후보를 추립니다.
- **실습 2. SHAP Value.** D7 잔존을 예측하는 LGBM 모델을 (Optuna로 튜닝까지) 학습하고, SHAP summary·dependence plot으로 각 행동의 기여도와 임계점(아하 모먼트)을 정량화합니다.
- **실습 3. Sankey Diagram.** 설치 직후 행동 흐름을 그리고 전이별 D7 잔존율로 색칠해, 어느 갈림길에서 잔존이 갈리는지 찾습니다.
- 마지막에 세 방법이 공통으로 가리킨 선행지표를 삼각측량으로 정리합니다.

## 실행 방법

```bash
python generate_data.py                          # 예시 데이터 생성 (data/event_log.csv)
jupyter notebook leading_indicators.ipynb        # 노트북을 위에서 아래로 실행 (첫 셀이 의존성 설치)
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `generate_data.py` | 신규 유저 이벤트 로그 생성기 (시드 고정, 잠재 품질·경로 의존 잔존 심기) |
| `data/event_log.csv` | 타임스탬프 단위 raw 이벤트 로그 (세 실습 공통 입력) |
| `sql/eda_leading_indicator.sql` | 실습 1 — D7 잔존 코호트별 D0~D1 행동 비교 |
| `sql/feature_matrix.sql` | 실습 2 — 유저별 D0 행동 피처 행렬 + D7 잔존 라벨 |
| `sql/sankey_transitions.sql` | 실습 3 — 설치 세션 스텝 전이 + 전이별 D7 잔존율 |
| `leading_indicators.ipynb` | 실습 1·2·3 + 요약 노트북 |
