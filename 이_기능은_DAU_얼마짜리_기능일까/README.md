# 이 기능은 DAU 얼마짜리 기능일까?

이 챕터의 실습 코드입니다.

- **실습 1.** 신규 유저의 리텐션 커브에 power law `y = a·x^b` 를 맞춰(`curve_fit`) 모양 계수 `b` 를 구합니다.
- **실습 2.** `x^b` 의 1년치 누적합을 하나의 상수로 단순화해, `DAU = 신규 유저 수 × D1 리텐션 × 상수` 공식을 완성합니다.

## 실행 방법

```bash
python generate_data.py            # 예시 데이터 생성 (data/active_daily.csv)
jupyter notebook dau_forecast.ipynb  # 노트북을 위에서 아래로 실행 (첫 셀이 의존성 설치)
```

## 파일 구성

| 파일 | 설명 |
| --- | --- |
| `generate_data.py` | 리텐션 분석용 합성 예시 데이터 생성기 (시드 고정) |
| `data/active_daily.csv` | 생성된 예시 데이터 (`date, user_id, platform, country_code, install_flag`) |
| `sql/retention_curve.sql` | 월별·플랫폼별 D1~D28 리텐션 커브를 구하는 DuckDB 쿼리 |
| `dau_forecast.ipynb` | 실습 1~2 노트북 |
