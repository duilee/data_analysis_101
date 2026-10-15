"""Machine Learning으로 찾아보는 유저들의 사용패턴 — 예시 데이터 생성기.

알람 앱 유저의 일별 사용 로그를 본뜬 합성 데이터를 만든다.
4개 페르소나(사용 유형)를 '심어' 두고 각 유저를 2주치 일별 행으로 펼치므로,
실습의 KMeans 가 이 페르소나들을 (거의) 그대로 복원하는 것을 확인할 수 있다.

- data/alarm_daily.csv : 일별 알람 피처 (피처 엔지니어링 SQL의 입력)
- data/user_master.csv : user_id, new_flag(신규/기존), retained_d7(D7 잔존; KPI용)

알람 시각은 분(0~1439) 정수로 표현한다.
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
import pandas as pd

# 출력이 파이프로 캡처될 때 cp949로 인코딩돼 한글이 깨지는 것을 방지 (콘솔 직접 출력에는 영향 없음)
sys.stdout.reconfigure(encoding="utf-8")

SEED = 42
START = pd.Timestamp("2024-09-02")  # 월요일
N_DAYS = 14                          # 2주 (주중 10일 + 주말 4일)

# 페르소나별 '진짜' 중심값 (실제 서비스 클러스터 결과에 맞춰 심음).
#   alarms          : 알람 개수(일평균)
#   snooze/used/attempt : 알람 1개당 값 (SQL에서 ..._cnt / scheduled_cnt 로 환산)
#   ttd             : 알람 해제까지 시간(분, 알람 1개당)
#   wake            : 첫 알람부터 해제까지 시간(분)
#   interval        : 알람 사이 인터벌(분) — 단일 알람일은 0으로 집계되는 점을 반영한 목표 평균
#   count           : 해당 페르소나 유저 수 (비중 4.12/57.86/13.00/25.02% 를 N=2400 에 맞춤)
PERSONAS = [
    dict(name="weak_minimalist", count=99,  retention=0.30, new_prob=0.30,
         alarms=1.42, interval=8.73, snooze=0.91, used=0.91, attempt=1.27, ttd=68.42, wake=75.18),
    dict(name="minimalist",      count=1389, retention=0.58, new_prob=0.25,
         alarms=1.19, interval=3.08, snooze=0.52, used=0.95, attempt=1.31, ttd=6.14,  wake=8.0),
    dict(name="weak_maximalist", count=312, retention=0.40, new_prob=0.60,
         alarms=2.81, interval=47.92, snooze=0.38, used=0.78, attempt=0.91, ttd=8.36, wake=84.27),
    dict(name="trying_maximalist", count=600, retention=0.55, new_prob=0.55,
         alarms=2.17, interval=18.44, snooze=0.55, used=0.83, attempt=1.18, ttd=12.07, wake=41.33),
]

BASE = os.path.dirname(os.path.abspath(__file__))


def _noisy(rng, mean, rel=0.08, lo=0.0):
    """평균 mean 에 상대 노이즈(rel)를 준 양수 값."""
    return max(lo, rng.normal(mean, abs(mean) * rel + 1e-9))


def _stoch_round(rng, x):
    """확률적 반올림: 평균은 x 그대로 유지하면서 분산을 ±1 로 최소화.
    (round(x) 는 작은 값에서 평균이 치우치고, Poisson 은 분산이 커 군집을 흩뜨림)"""
    f = math.floor(x)
    return int(f + (1 if rng.random() < (x - f) else 0))


def main() -> None:
    rng = np.random.default_rng(SEED)

    daily_rows = []
    master_rows = []
    dates = [START + pd.Timedelta(days=d) for d in range(N_DAYS)]

    uid = 0
    for p in PERSONAS:
        mu = p["alarms"]
        lam = max(mu - 1.0, 0.0)                 # 일별 알람수 = 1 + Poisson(mu-1)
        q = 1.0 - math.exp(-lam) if lam > 0 else 0.0   # P(알람>1)
        # 단일알람일(인터벌 0)을 COALESCE 평균하면 q*gap 이 되므로, 목표 인터벌 / q 로 역산
        gap = p["interval"] / q if q > 0 else 0.0

        for _ in range(p["count"]):
            uid += 1
            user_id = f"u{uid:05d}"
            new_flag = bool(rng.random() < p["new_prob"])
            retained = bool(rng.random() < p["retention"])
            master_rows.append((user_id, new_flag, retained))

            for dt in dates:
                cnt = 1 + int(rng.poisson(lam))

                first_min = int(rng.normal(390, 25))                 # 기상 알람 시작(분)
                if cnt > 1:
                    g = max(1.0, rng.normal(gap, gap * 0.15 + 1e-9))
                    last_min = first_min + int(round(g * (cnt - 1)))
                else:
                    last_min = first_min                             # 단일 알람 → 인터벌 없음

                # 카운트형 피처는 확률적 반올림으로 (평균 유지 + 분산 최소 → 군집이 흩어지지 않음)
                snooze_cnt = _stoch_round(rng, p["snooze"] * cnt)
                mission_used = _stoch_round(rng, p["used"] * cnt)
                mission_attempt = mission_used + _stoch_round(rng, max(0.0, p["attempt"] - p["used"]) * cnt)
                total_ttd = round(_noisy(rng, p["ttd"]) * cnt, 1)    # 해제까지 시간(알람당) × cnt
                wake = round(_noisy(rng, p["wake"]), 1)              # 첫 알람~해제(분)

                daily_rows.append((
                    dt.strftime("%Y-%m-%d"), user_id, cnt, first_min, last_min,
                    snooze_cnt, mission_used, mission_attempt, total_ttd, wake,
                ))

    daily = pd.DataFrame(daily_rows, columns=[
        "local_date", "user_id", "scheduled_cnt", "first_scheduled_min", "last_scheduled_min",
        "snooze_alarm_cnt", "mission_used_cnt", "mission_attempt_cnt",
        "total_time_to_dismiss", "first_ring_to_last_dismiss",
    ])
    master = pd.DataFrame(master_rows, columns=["user_id", "new_flag", "retained_d7"])
    # DuckDB 가 BOOLEAN 으로 추론하도록 소문자 true/false
    for col in ["new_flag", "retained_d7"]:
        master[col] = master[col].map({True: "true", False: "false"})

    out_dir = os.path.join(BASE, "data")
    os.makedirs(out_dir, exist_ok=True)
    daily.to_csv(os.path.join(out_dir, "alarm_daily.csv"), index=False)
    master.to_csv(os.path.join(out_dir, "user_master.csv"), index=False)

    n_users = sum(p["count"] for p in PERSONAS)
    print(f"alarm_daily.csv : {len(daily):,} rows ({n_users:,} users x {N_DAYS} days)")
    print(f"user_master.csv : {len(master):,} rows")
    print("persona mix     :", {p["name"]: p["count"] for p in PERSONAS})


if __name__ == "__main__":
    main()
