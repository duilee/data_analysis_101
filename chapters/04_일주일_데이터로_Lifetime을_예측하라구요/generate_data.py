"""lifetime 추정 실습용 예시 데이터 생성기.

신규 코호트의 7일간 관측 리텐션(D0~D7)을 data/cohort_retention.csv 로 떨어뜨린다.
실제 운영 환경이라면 raw 이벤트 로그에서 매일 집계해 만드는 코호트 리텐션 마트의
한 코호트 분량에 해당한다. 여기서는 실습 재현성을 위해 7일 전 가입한 가상 코호트의
관측값을 고정 상수로 둔다.

- D0 = 1.0 (가입 당일은 정의상 전원 활동)
- D1~D7 = 첫날의 절벽과 이후 완만한 감속을 가진 현실적인 한 곡선

이 값들은 멱함수 카탈로그 격자 위의 한 점에 정확히 올라앉아 있지 않다(일부러 그렇게 두었다).
Case 2(카탈로그 매칭)에서 SSE가 0이 아니라 작은 값으로 나오는 이유가 여기에 있다.
"""

import os
import sys

import pandas as pd

# 출력이 파이프로 캡처될 때 cp949로 인코딩돼 한글이 깨지는 것을 방지 (콘솔 직접 출력에는 영향 없음)
sys.stdout.reconfigure(encoding="utf-8")

# 신규 코호트의 7일 관측 리텐션 (day, retention)
COHORT_RETENTION = [
    (0, 1.000),
    (1, 0.341),
    (2, 0.295),
    (3, 0.273),
    (4, 0.260),
    (5, 0.252),
    (6, 0.247),
    (7, 0.244),
]


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "data")
    os.makedirs(out_dir, exist_ok=True)

    df = pd.DataFrame(COHORT_RETENTION, columns=["day", "retention"])
    out_path = os.path.join(out_dir, "cohort_retention.csv")
    df.to_csv(out_path, index=False)

    print(f"생성 완료: {out_path} ({len(df)}행)")
    print(f"  D1~D7 면적 = {df.loc[df['day'].between(1, 7), 'retention'].sum():.3f}")


if __name__ == "__main__":
    main()
