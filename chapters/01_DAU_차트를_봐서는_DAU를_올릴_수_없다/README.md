# 1장. DAU 차트를 봐서는 DAU를 올릴 수 없다

유저 세그먼트 분석 실습 코드입니다. 가상의 습관 트래커 앱 ‘루틴로그’의 DAU를 5개 유저 세그먼트로 쪼개고,
세그먼트 사이의 이동(Flow)과 비율 지표로 서비스의 건강도를 입체적으로 진단합니다.

- **1.3.2.** 두 원천 테이블(`user_master`, `user_activity`)에서 3개 파생지표를 만들고(`user_metrics`), 그 지표를 정해진 기준에 따라 5개 세그먼트(new / heavy / light / risk / dormant)로 분류합니다. 세그먼트에 오늘 기록 여부를 교차해 DAU 구성도 확인합니다.
- **1.3.3.** 날짜 × 유저 단위의 세그먼트 스냅샷을 한 달치 쌓고, 어제 세그먼트를 `lag` 로 나란히 붙여 세그먼트 변화를 추적할 수 있는 마트를 만듭니다.
- **1.3.4.** 그 마트를 분포(Stock)·전이 행렬(Flow)·비율 지표(HURR/CURR/Heavy Loss/Light Loss/Reactivation) 세 각도로 분석합니다.
- **1.3.5.** 한 달치 마트를 셀프 조인해, 30일 전 heavy 유저와 new 유저가 오늘 어디로 흩어졌는지 N일 변화를 추적합니다.

## 실행 방법

```bash
pip install -r requirements.txt       # 의존성 설치
python generate_data.py               # 예시 데이터 생성 (data/user_master.csv, user_activity.csv)
jupyter notebook dau_segment.ipynb    # 노트북을 위에서 아래로 실행
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `generate_data.py` | 세그먼트 실습용 합성 예시 데이터 생성기 (시드 고정) |
| `data/user_master.csv` | 유저별 가입 정보 (`user_id, first_active_date`) |
| `data/user_activity.csv` | 유저가 습관 체크를 남긴 날의 로그 (`user_id, event_date`) |
| `sql/build_metrics.sql` | 3개 파생지표(+DAU 교차용 d0_active) 계산 → `user_metrics` 테이블 (오늘 시점) |
| `sql/classify_segment.sql` | `user_metrics` 의 3개 지표를 5개 세그먼트로 분류 |
| `sql/build_metrics_daily.sql` | 달력(31일) × 유저 단위로 3개 파생지표 계산 → `user_metrics_daily` 테이블 |
| `sql/build_mart.sql` | 날짜별 세그먼트 분류 + `lag` 로 어제 세그먼트를 붙인 마트 생성 (한 달치) |
| `sql/stock_distribution.sql` | 일별 세그먼트 분포 (Stock) |
| `sql/transition_matrix.sql` | 세그먼트 전이 행렬 (Flow) |
| `sql/segment_kpi.sql` | 전이 기반 비율 지표 5종 |
| `sql/nday_tracking.sql` | N일 후 세그먼트 변화 추적 |
| `dau_segment.ipynb` | 1.3 실습 노트북 (1.3.1~1.3.5) |
