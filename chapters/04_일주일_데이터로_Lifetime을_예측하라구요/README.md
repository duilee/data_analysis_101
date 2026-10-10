# 4장. 일주일 데이터로 Lifetime을 예측하라고요?

Lifetime 추정 실습 코드입니다. 유저의 Lifetime(가입 후 이탈 전까지 평균 활동일수)을
초기 7일치 리텐션 데이터만으로 추정하는 세 가지 방법을, 같은 신규 코호트에 적용해
비교합니다.

- **4.6.2. 이탈률 휴리스틱 (Case 1).** D1~D7 면적에 D7 이후의 등비급수 꼬리를 더해 추정합니다.
- **4.6.3. 리텐션 카탈로그 매칭 (Case 2).** 멱함수 곡선 3,456장을 만들어 두고, 신규 코호트의 (D1, D3, D7)과 가장 닮은 곡선의 lifetime을 가져옵니다.
- **4.6.4. 장기 코호트 직접 측정 (Case 3).** 1년 전 코호트의 실측 lifetime을 신규 코호트의 7일 면적 비율로 보정합니다.
- **4.6.5. 세 방법 결과 비교.** 세 방법의 결과를 한 표·막대그래프로 비교합니다(삼각측량).

## 실행 방법

```bash
pip install -r requirements.txt              # 의존성 설치
python generate_data.py                      # 예시 데이터 생성 (data/cohort_retention.csv)
jupyter notebook lifetime_estimation.ipynb   # 노트북을 위에서 아래로 실행
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `generate_data.py` | 신규 코호트 7일 관측 리텐션 예시 데이터 생성기 |
| `data/cohort_retention.csv` | 신규 코호트의 일별 리텐션 (`day, retention`, D0~D7 8행) |
| `sql/heuristic.sql` | 4.6.2 (Case 1) — 이탈률 휴리스틱 (등비급수 외삽) |
| `sql/catalog_match.sql` | 4.6.3 (Case 2) — 카탈로그에서 SSE 최소 곡선 매칭 |
| `sql/mature_cohort.sql` | 4.6.4 (Case 3) — 장기 코호트 실측 lifetime의 7일 면적 비례 보정 |
| `sql/compare_methods.sql` | 4.6.5 — 세 방법 결과를 한 표로 비교 |
| `lifetime_estimation.ipynb` | 4.6 실습 노트북 (4.6.1~4.6.6, Case 1~3 + 비교; 멱함수 카탈로그는 노트북에서 생성) |

> 카탈로그(3,456행)는 노트북 안에서 멱함수 격자로 즉석 생성해 DuckDB에 등록하므로 별도 CSV로
> 두지 않습니다. `sql/catalog_match.sql`·`sql/compare_methods.sql`은 그 `lifetime_catalog`
> 테이블이 등록돼 있다고 가정합니다.
