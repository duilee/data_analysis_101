# DAU 차트를 봐서는 DAU를 올릴 수 없다

유저 세그먼트 분석 실습 코드입니다. DAU를 7개 유저 세그먼트로 쪼개고,
세그먼트 사이의 이동(Flow)과 비율 지표로 서비스의 건강도를 입체적으로 진단합니다.

- **실습 1.** 두 원천 테이블(`user_master`, `user_activity`)에서 4개 파생지표를 만들고(`user_metrics`), 그 지표를 정해진 기준에 따라 7개 세그먼트로 분류합니다.
- **실습 2.** 어제·오늘 두 시점의 세그먼트를 한 행에 담아, 세그먼트 변화를 추적할 수 있는 마트를 만듭니다.
- **실습 3.** 그 마트를 분포(Stock)·전이 행렬(Flow)·비율 지표(HURR/CURR/Heavy Loss/Light Loss/Reactivation) 세 각도로 분석합니다.
- **실습 4.** 마트를 여러 날 적재해, 30일 전 heavy 유저가 오늘 어디로 흩어졌는지 N일 변화를 추적합니다.

## 실행 방법

```bash
python generate_data.py               # 예시 데이터 생성 (data/user_master.csv, user_activity.csv)
jupyter notebook dau_segment.ipynb    # 노트북을 위에서 아래로 실행 (첫 셀이 의존성 설치)
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `generate_data.py` | 세그먼트 실습용 합성 예시 데이터 생성기 (시드 고정) |
| `data/user_master.csv` | 유저별 가입 정보 (`user_id, first_active_date`) |
| `data/user_activity.csv` | 유저별 일별 접속 로그 (`user_id, event_date`) |
| `sql/build_metrics.sql` | 4개 파생지표 계산 → `user_metrics` 테이블 (오늘 시점) |
| `sql/classify_segment.sql` | `user_metrics` 의 4개 지표를 7개 세그먼트로 분류 |
| `sql/build_mart.sql` | 어제·오늘 두 시점을 담은 세그먼트 마트 생성 |
| `sql/stock_distribution.sql` | 일별 세그먼트 분포 (Stock) |
| `sql/transition_matrix.sql` | 세그먼트 전이 행렬 (Flow) |
| `sql/segment_kpi.sql` | 전이 기반 비율 지표 5종 |
| `sql/nday_tracking.sql` | N일 후 세그먼트 변화 추적 |
| `dau_segment.ipynb` | 실습 1~4 노트북 |
