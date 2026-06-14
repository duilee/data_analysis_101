"""이 기능은 DAU 얼마짜리 기능일까? — 예시 데이터 생성기.

리텐션 분석 실습용 합성 데이터를 만든다. 일자별 활성 유저 로그를 본떠
유저 한 명의 설치일과 이후 재방문일을 행으로 기록한다.
각 플랫폼의 리텐션이 '알려진' power law (y = a * d^b) 를 따르도록 생성하므로,
실습 노트북의 curve_fit 이 b 를 (거의) 그대로 복원하는 것을 확인할 수 있다.

컬럼: date, user_id, platform, country_code, install_flag
"""

from __future__ import annotations

import os

import numpy as np
import pandas as pd

SEED = 42
START_DATE = pd.Timestamp("2026-01-01")
N_COHORT_DAYS = 90        # 약 3개월치 일자별 코호트 -> basis_month 3개
NEW_USERS_PER_DAY = 100   # 플랫폼별 하루 신규 유저 수(포아송 변동)
MAX_DAY_DIFF = 28         # 쿼리가 day_diff 1~28 만 쓰므로 28일까지만 시뮬레이션

# 플랫폼별 '진짜' 리텐션 커브 파라미터: y(d) = a * d^b
# a 는 곡선의 시작점(≈ D1 리텐션), b 는 곡선의 모양(음수일수록 빨리 감소).
PLATFORM_PARAMS = {
    "ios":     {"a": 0.42, "b": -0.45},
    "android": {"a": 0.35, "b": -0.50},
}
COUNTRIES = ["KR", "US", "JP", "IN"]

OUT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "active_daily.csv")


def true_retention(day: np.ndarray, a: float, b: float) -> np.ndarray:
    """power law 리텐션 확률 y(d) = a * d^b 를 0~1 로 클립해 반환."""
    return np.clip(a * np.power(day, b), 0.0, 1.0)


def generate() -> pd.DataFrame:
    rng = np.random.default_rng(SEED)
    days = np.arange(1, MAX_DAY_DIFF + 1)

    rows = []
    uid = 0
    for platform, params in PLATFORM_PARAMS.items():
        base_ret = true_retention(days, params["a"], params["b"])  # day 1~28 잔존 확률

        for d in range(N_COHORT_DAYS):
            install_date = START_DATE + pd.Timedelta(days=d)
            n_users = rng.poisson(NEW_USERS_PER_DAY)  # 하루 신규 유저 수에 약간의 변동

            for _ in range(n_users):
                uid += 1
                user_id = f"u{uid:07d}"
                country = COUNTRIES[rng.integers(len(COUNTRIES))]

                # 설치일: 활성 + install_flag=True
                rows.append((install_date, user_id, platform, country, True))

                # 이후 day_diff 1~28 각각에 대해 잔존 확률만큼 재방문 (코호트별 노이즈 가미)
                noise = rng.uniform(0.85, 1.15, size=MAX_DAY_DIFF)
                probs = np.clip(base_ret * noise, 0.0, 1.0)
                returned = rng.random(MAX_DAY_DIFF) < probs
                for offset in days[returned]:
                    visit_date = install_date + pd.Timedelta(days=int(offset))
                    rows.append((visit_date, user_id, platform, country, False))

    df = pd.DataFrame(
        rows, columns=["date", "user_id", "platform", "country_code", "install_flag"]
    )
    df = df.sort_values(["date", "platform", "user_id"]).reset_index(drop=True)
    return df


def main() -> None:
    df = generate()
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)

    n_install = int(df["install_flag"].sum())

    out = df.copy()
    out["date"] = out["date"].dt.strftime("%Y-%m-%d")
    # DuckDB 가 BOOLEAN 으로 자동 추론하도록 소문자 true/false 로 기록
    out["install_flag"] = out["install_flag"].map({True: "true", False: "false"})
    out.to_csv(OUT_PATH, index=False)

    print(f"wrote {len(df):,} rows -> {OUT_PATH}")
    print(f"  installs   : {n_install:,}")
    print(f"  platforms  : {sorted(df['platform'].unique())}")
    print(f"  date range : {out['date'].min()} ~ {out['date'].max()}")


if __name__ == "__main__":
    main()
