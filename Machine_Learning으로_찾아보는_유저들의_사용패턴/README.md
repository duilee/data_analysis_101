# Machine Learning으로 찾아보는 유저들의 사용패턴

이 챕터의 실습 코드입니다. KMeans 클러스터링으로 알람 앱 유저의 사용 패턴(페르소나)을
비지도로 나누고, 중심점으로 해석·네이밍한 뒤 리텐션 지표와 연결해 액션까지 이어 봅니다.

- **실습 0.** 도메인 특성을 담은 피처 엔지니어링 SQL로 유저 피처 추출
- **실습 1.** 피처 분포로 유저 간 변별력 확인
- **실습 2.** 피처 스케일링(StandardScaler) + 클러스터 개수 정하기 (Elbow · Silhouette)
- **실습 3.** 클러스터링 & 중심점(원단위 복원)으로 특성 읽기 → 페르소나 네이밍
- **실습 4.** PCA로 클러스터 시각화
- **실습 5.** 신규/기존 유저로 나눠 클러스터링 비교
- **실습 6.** 클러스터별 리텐션 KPI → 액션 연결
- **실습 7.** 라벨 적재(로컬 CSV) & 모델 저장/로드(pickle)

## 실행 방법

```bash
python generate_data.py                 # 예시 데이터 생성 (data/*.csv)
jupyter notebook user_segmentation.ipynb  # 노트북을 위에서 아래로 실행 (첫 셀이 의존성 설치)
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `generate_data.py` | 4개 페르소나를 심은 합성 알람 사용 데이터 생성기 (시드 고정) |
| `data/alarm_daily.csv` | 일별 알람 피처 (피처 추출 SQL의 입력) |
| `data/user_master.csv` | `user_id, new_flag, retained_d7` |
| `sql/extract_features.sql` | 일별 → 유저 피처 추출 DuckDB 쿼리 (주중 필터·기간 평균·클리핑) |
| `user_segmentation.ipynb` | 실습 0~7 노트북 |

> 예시 데이터는 4개 페르소나를 '심어' 만들었으므로, KMeans가 그 페르소나를 거의 그대로
> 복원하는지 확인하며 따라갈 수 있습니다. 시각화 라벨은 영어, 서술은 한국어입니다.
> (알람 시각은 분 단위 정수(0~1439)로 표현합니다.)
> 노트북 실행 시 `output/`(라벨 CSV)과 `models/`(.pkl)가 생성되며, 이들은 gitignore 됩니다.
