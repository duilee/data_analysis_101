"""DAU 차트를 봐서는 DAU를 올릴 수 없다 — 유저 세그먼트 실습용 예시 데이터 생성기.

유저 세그먼트 분석 실습을 위해 두 개의 합성 테이블을 만든다.

  - user_master   : 유저별 가입(첫 접속) 정보   (user_id, first_active_date)
  - user_activity : 유저별 일별 접속 로그        (user_id, event_date)

각 유저에게 '평소 접속 확률(activity_rate)'과 '이탈 시점(churn_date)'을
미리 정해 두고, 가입일부터 기준일까지 하루씩 베르누이 시행으로 접속 여부를
정한다. 이렇게 하면 기준일(target) 시점에 7개 세그먼트가 모두 등장할 뿐 아니라,
유저별 이탈 시점이 고정돼 있어 '며칠 전'을 기준으로 잘라 봐도 세그먼트가
시간에 따라 자연스럽게 이동(Flow)하는 것을 확인할 수 있다.

시드를 고정했으므로 누가 실행하든 항상 같은 데이터가 만들어진다.
"""

from __future__ import annotations

import os
from datetime import date, timedelta

import numpy as np
import pandas as pd

SEED = 42
TARGET_DATE = date(2026, 5, 20)   # 분석 기준일(오늘)
N_USERS = 200
HISTORY_DAYS = 120                # 활동 로그를 만들 최대 기간 (target - 120 ~ target)

BASE = os.path.dirname(os.path.abspath(__file__))
MASTER_PATH = os.path.join(BASE, "data", "user_master.csv")
ACTIVITY_PATH = os.path.join(BASE, "data", "user_activity.csv")

# 활동 강도 군집: (이름, 하루 접속 확률, 비중). heavy 일수록 자주 접속한다.
ACTIVITY_TIERS = [
    ("heavy", 0.85, 0.26),
    ("mid",   0.55, 0.30),
    ("light", 0.28, 0.27),
    ("rare",  0.12, 0.17),
]

# 이탈 유형: (이름, 비중). churn_date 이후에는 접속 기록을 남기지 않는다.
#   none   : 이탈 없이 기준일까지 꾸준히 활동
#   recent : 최근 1~7일 사이에 이탈 (오늘 미접속 → inactive)
#   mid    : 8~30일 전에 이탈 (최근 7일 활동 0 → risk)
#   deep   : 31~60일 전에 이탈 (오래 미접속 → dormant)
CHURN_TYPES = [
    ("none",   0.62),
    ("recent", 0.14),
    ("mid",    0.14),
    ("deep",   0.10),
]


def _pick(rng: np.random.Generator, items):
    """(값, 확률) 목록에서 확률에 비례해 하나를 고른다."""
    labels = [it[0] for it in items]
    probs = np.array([it[-1] for it in items], dtype=float)
    probs /= probs.sum()
    return labels[rng.choice(len(labels), p=probs)]


def build():
    rng = np.random.default_rng(SEED)
    tier_rate = {name: rate for name, rate, _ in ACTIVITY_TIERS}

    master_rows = []
    activity_rows = []

    for i in range(1, N_USERS + 1):
        user_id = f"user_{i:03d}"

        # 가입일: id 1~10은 오늘 가입(신규), 11~16은 최근 1~6일 내 가입, 나머지는 7~115일 전 분산.
        if i <= 10:
            age = 0
        elif i <= 16:
            age = int(rng.integers(1, 7))
        else:
            age = int(rng.integers(7, HISTORY_DAYS - 5))
        first_active = TARGET_DATE - timedelta(days=age)
        master_rows.append((user_id, first_active))

        tier = _pick(rng, ACTIVITY_TIERS)
        rate = tier_rate[tier]
        churn = _pick(rng, CHURN_TYPES)

        # 이탈 시점(churn_date): 이날 이후로는 접속하지 않는다.
        if churn == "none":
            churn_date = None
        elif churn == "recent":
            churn_date = TARGET_DATE - timedelta(days=int(rng.integers(1, 8)))
        elif churn == "mid":
            churn_date = TARGET_DATE - timedelta(days=int(rng.integers(8, 31)))
        else:  # deep
            churn_date = TARGET_DATE - timedelta(days=int(rng.integers(31, 61)))

        # 가입일부터 기준일까지 하루씩 접속 여부를 시뮬레이션.
        day = first_active
        while day <= TARGET_DATE:
            if churn_date is not None and day >= churn_date:
                break  # 이탈 이후에는 접속 기록 없음
            if rng.random() < rate:
                activity_rows.append((user_id, day))
            day += timedelta(days=1)

        # 신규 가입 유저는 가입 당일 활동을 보장한다(가입=첫 접속).
        if first_active == TARGET_DATE:
            activity_rows.append((user_id, TARGET_DATE))

    master = pd.DataFrame(master_rows, columns=["user_id", "first_active_date"])
    activity = pd.DataFrame(activity_rows, columns=["user_id", "event_date"])
    # 중복 제거(가입 당일 보장과 시뮬레이션이 겹칠 수 있음) 후 정렬
    activity = (activity.drop_duplicates()
                        .sort_values(["event_date", "user_id"])
                        .reset_index(drop=True))
    return master, activity


def main():
    master, activity = build()
    os.makedirs(os.path.dirname(MASTER_PATH), exist_ok=True)

    master_out = master.copy()
    master_out["first_active_date"] = master_out["first_active_date"].map(lambda d: d.isoformat())
    master_out.to_csv(MASTER_PATH, index=False)

    activity_out = activity.copy()
    activity_out["event_date"] = activity_out["event_date"].map(lambda d: d.isoformat())
    activity_out.to_csv(ACTIVITY_PATH, index=False)

    print(f"wrote {len(master):,} rows -> {MASTER_PATH}")
    print(f"wrote {len(activity):,} rows -> {ACTIVITY_PATH}")
    print(f"  target_date : {TARGET_DATE.isoformat()}")
    print(f"  users       : {len(master):,}")
    print(f"  date range  : {activity_out['event_date'].min()} ~ {activity_out['event_date'].max()}")


if __name__ == "__main__":
    main()
