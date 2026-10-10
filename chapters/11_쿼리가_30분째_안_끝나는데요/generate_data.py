"""쿼리가 30분째 안 끝나는데요? — 예시 데이터 생성기.

데이터 마트 층 쌓기 실습용 합성 데이터를 만든다. 가상의 구독형 모바일 앱에서
'소스가 여러 개인' 상황을 재현하기 위해 파일 다섯 개를 만들고, 실무의 raw 가 보통
그렇듯 아래 잡음을 일부러 심는다 (11.6.3의 staging 이 정리하는 대상):
  · 이벤트 재전송 중복(같은 event_id 가 두 번), system_* · heartbeat 시스템 이벤트,
    user_id 가 비어 있는 로그, 대소문자가 섞인 국가 코드
  · received_time(도착 시각)이 event_time(일어난 시각)보다 최대 3일 늦는 행
    — 앱 이벤트 당일 70% / D+1 20% / D+2 8% / D+3 2%, 구독 이벤트는 스토어 서버 통지라
      더 늦게 55% / 25% / 12% / 8% (11.6.7의 재적재 창)
  · 구독 이벤트에도 재전송 중복이 있고, 환불 금액은 음수

파일과 컬럼:
  data/events.csv              event_id, user_id, event_name, session_id, event_time, received_time, properties
  data/subscription_events.csv sub_event_id, user_id, event_type(purchase/renewal/cancel/refund), sku_id,
                               is_trial, event_time, received_time, price_local, currency
  data/user_snapshots.csv      snapshot_date, user_id, platform, country, app_version, install_date
  data/sku.csv                 sku_id, duration_days, trial_days, base_price_usd
  data/exchange_rates.csv      date, currency, rate_to_usd
"""

from __future__ import annotations

import json
import os
import sys

import numpy as np
import pandas as pd

# 출력이 파이프로 캡처될 때 cp949로 인코딩돼 한글이 깨지는 것을 방지 (콘솔 직접 출력에는 영향 없음)
sys.stdout.reconfigure(encoding="utf-8")

SEED = 42
N_USERS = 3000
START_DATE = pd.Timestamp("2026-04-01")
N_DAYS = 90                                  # 2026-04-01 ~ 2026-06-29
END_DATE = START_DATE + pd.Timedelta(days=N_DAYS - 1)

PLATFORMS = {"ios": 0.45, "android": 0.55}
COUNTRIES = {"KR": 0.40, "US": 0.25, "JP": 0.15, "DE": 0.10, "BR": 0.10}
CURRENCY_OF = {"KR": "KRW", "US": "USD", "JP": "JPY", "DE": "EUR", "BR": "BRL"}
APP_VERSIONS = ["3.4.0", "3.5.0", "3.6.0"]

SKUS = pd.DataFrame([
    {"sku_id": "monthly_basic", "duration_days": 30,  "trial_days": 7, "base_price_usd": 4.99},
    {"sku_id": "monthly_plus",  "duration_days": 30,  "trial_days": 7, "base_price_usd": 7.99},
    {"sku_id": "yearly_basic",  "duration_days": 365, "trial_days": 7, "base_price_usd": 29.99},
    {"sku_id": "yearly_plus",   "duration_days": 365, "trial_days": 7, "base_price_usd": 49.99},
])
SKU_WEIGHTS = {"monthly_basic": 0.45, "monthly_plus": 0.25, "yearly_basic": 0.20, "yearly_plus": 0.10}
# 통화별 스토어 표시 가격 (USD 환산은 환율 테이블로 — 11.6.4의 환율 조인)
LOCAL_PRICE = {
    "monthly_basic": {"KRW": 6900,  "USD": 4.99,  "JPY": 750,  "EUR": 4.49,  "BRL": 24.90},
    "monthly_plus":  {"KRW": 10900, "USD": 7.99,  "JPY": 1200, "EUR": 7.49,  "BRL": 39.90},
    "yearly_basic":  {"KRW": 39000, "USD": 29.99, "JPY": 4500, "EUR": 27.99, "BRL": 149.90},
    "yearly_plus":   {"KRW": 65000, "USD": 49.99, "JPY": 7500, "EUR": 46.99, "BRL": 249.90},
}
BASE_RATE_TO_USD = {"KRW": 0.00072, "USD": 1.0, "JPY": 0.0066, "EUR": 1.08, "BRL": 0.19}

EVENT_NAMES = {"app_open": 0.30, "view_home": 0.25, "complete_task": 0.18, "view_paywall": 0.10,
               "settings_open": 0.07, "share": 0.05, "push_open": 0.05}
SYSTEM_EVENTS = ["system_session_start", "system_token_refresh", "heartbeat"]

# 심은 정답 — 구독 행동
TRIAL_START_RATE = 0.35       # 설치 유저 중 체험 시작 비율
TRIAL_CONVERT_RATE = 0.40     # 체험 후 유료 전환 비율
RENEW_RATE = 0.85             # 기간 만료 시 갱신 확률 (월간)
CANCEL_RATE_PER_PERIOD = 0.10 # 기간 중 해지 확률
REFUND_RATE = 0.03            # 결제 후 3일 내 환불 확률
# 심은 잡음
DUP_RATE = 0.02               # 재전송 중복 비율
SYSTEM_RATE = 0.08            # 시스템 이벤트 비율
NULL_USER_RATE = 0.005        # user_id 누락 비율
ARRIVAL_LAG = {0: 0.70, 1: 0.20, 2: 0.08, 3: 0.02}          # 앱 이벤트
SUB_ARRIVAL_LAG = {0: 0.55, 1: 0.25, 2: 0.12, 3: 0.08}      # 구독 이벤트(스토어 서버 통지라 더 늦다)

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")


def pick(rng: np.random.Generator, weights: dict, size: int) -> np.ndarray:
    keys = list(weights)
    p = np.array([weights[k] for k in keys], dtype=float)
    return rng.choice(keys, size=size, p=p / p.sum())


def received(rng: np.random.Generator, event_time: pd.Series, lag_dist: dict = ARRIVAL_LAG) -> pd.Series:
    """도착 시각 = 일어난 시각 + (0~3일 지연) + 수 초~수 분."""
    lag = pick(rng, lag_dist, len(event_time)).astype(int)
    secs = rng.integers(2, 600, size=len(event_time))
    return event_time + pd.to_timedelta(lag, unit="D") + pd.to_timedelta(secs, unit="s")


def generate_users(rng: np.random.Generator) -> pd.DataFrame:
    install_day = rng.integers(0, N_DAYS, size=N_USERS)
    users = pd.DataFrame({
        "user_id": [f"u_{i:05d}" for i in range(1, N_USERS + 1)],
        "platform": pick(rng, PLATFORMS, N_USERS),
        "country": pick(rng, COUNTRIES, N_USERS),
        "install_date": START_DATE + pd.to_timedelta(install_day, unit="D"),
    })
    # 활동성(잠재 변수): 활동 확률과 구독 성향에 함께 영향
    users["engagement"] = rng.beta(2, 4, size=N_USERS)
    return users


def generate_snapshots(rng: np.random.Generator, users: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for u in users.itertuples(index=False):
        days = (END_DATE - u.install_date).days + 1
        dates = pd.date_range(u.install_date, periods=days, freq="D")
        # 앱 버전: 설치 시점 버전에서 시작해 이후 무작위 시점에 올라간다
        v0 = rng.integers(0, 2)
        upgrade_at = rng.integers(5, 40) if v0 < 2 else 10**6
        version = np.where(np.arange(days) >= upgrade_at, APP_VERSIONS[min(v0 + 1, 2)], APP_VERSIONS[v0])
        # 국가: 10% 유저는 중간에 한 번 바뀐다 (여행·이주) — SCD 스냅샷이 필요한 이유
        country = np.full(days, u.country, dtype=object)
        if rng.random() < 0.10 and days > 20:
            at = rng.integers(10, days)
            country[at:] = rng.choice([c for c in COUNTRIES if c != u.country])
        rows.append(pd.DataFrame({
            "snapshot_date": dates, "user_id": u.user_id, "platform": u.platform,
            "country": country, "app_version": version, "install_date": u.install_date,
        }))
    snap = pd.concat(rows, ignore_index=True)
    # 잡음: 일부 국가 코드가 소문자로 들어온다 (소스 SDK 버전 차이)
    lower = rng.random(len(snap)) < 0.15
    snap.loc[lower, "country"] = snap.loc[lower, "country"].str.lower()
    return snap


def generate_events(rng: np.random.Generator, users: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for u in users.itertuples(index=False):
        days = (END_DATE - u.install_date).days + 1
        d = np.arange(days)
        # 활동 확률: 설치일 1.0 에서 멱함수로 감소, engagement 가 높을수록 천천히
        p_active = np.clip(0.15 + 0.85 * np.power(d + 1, -(0.9 - 0.6 * u.engagement)), 0, 1)
        active = rng.random(days) < p_active
        for day in d[active]:
            n = rng.poisson(1.2) + 1
            day_start = u.install_date + pd.Timedelta(days=int(day))
            t = day_start + pd.to_timedelta(rng.integers(6 * 3600, 23 * 3600, size=n), unit="s")
            rows.append(pd.DataFrame({
                "user_id": u.user_id, "event_name": pick(rng, EVENT_NAMES, n),
                "session_id": f"s_{u.user_id[2:]}_{int(day):03d}", "event_time": t,
            }))
    ev = pd.concat(rows, ignore_index=True).sort_values("event_time").reset_index(drop=True)
    # 시스템 이벤트 섞기
    n_sys = int(len(ev) * SYSTEM_RATE)
    sys_idx = rng.choice(len(ev), size=n_sys, replace=False)
    sys_rows = ev.iloc[sys_idx].copy()
    sys_rows["event_name"] = rng.choice(SYSTEM_EVENTS, size=n_sys)
    ev = pd.concat([ev, sys_rows], ignore_index=True).sort_values("event_time").reset_index(drop=True)
    ev["event_id"] = [f"e_{i:07d}" for i in range(1, len(ev) + 1)]
    ev["properties"] = [json.dumps({"screen": s}) for s in pick(rng, {"home": 0.5, "task": 0.3, "paywall": 0.2}, len(ev))]
    ev["received_time"] = received(rng, ev["event_time"])
    # user_id 누락
    ev.loc[rng.random(len(ev)) < NULL_USER_RATE, "user_id"] = None
    # 재전송 중복: 같은 event_id 가 조금 뒤에 한 번 더 도착
    dup = ev.sample(frac=DUP_RATE, random_state=int(rng.integers(1 << 30))).copy()
    dup["received_time"] = dup["received_time"] + pd.to_timedelta(rng.integers(30, 3600, size=len(dup)), unit="s")
    ev = pd.concat([ev, dup], ignore_index=True).sort_values(["received_time", "event_id"]).reset_index(drop=True)
    return ev[["event_id", "user_id", "event_name", "session_id", "event_time", "received_time", "properties"]]


def generate_subscriptions(rng: np.random.Generator, users: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    """구독 이벤트(잡음 포함)와, 정답 확인용 '진짜' 일별 활성 구독자 수를 함께 반환."""
    sku_dur = dict(zip(SKUS.sku_id, SKUS.duration_days))
    rows = []
    for u in users.itertuples(index=False):
        if rng.random() > TRIAL_START_RATE * (0.6 + u.engagement):
            continue
        sku = pick(rng, SKU_WEIGHTS, 1)[0]
        cur = CURRENCY_OF[u.country]
        t = u.install_date + pd.Timedelta(days=int(rng.integers(0, 3)), hours=int(rng.integers(7, 23)),
                                      minutes=int(rng.integers(0, 60)), seconds=int(rng.integers(0, 60)))
        if t > END_DATE + pd.Timedelta(days=1):
            continue
        rows.append((u.user_id, "purchase", sku, True, t, 0.0, cur))        # 체험 시작
        t = t + pd.Timedelta(days=7)
        if t > END_DATE + pd.Timedelta(days=1) or rng.random() > TRIAL_CONVERT_RATE * (0.7 + u.engagement):
            continue
        rows.append((u.user_id, "purchase", sku, False, t, LOCAL_PRICE[sku][cur], cur))
        if rng.random() < REFUND_RATE:
            rows.append((u.user_id, "refund", sku, False, t + pd.Timedelta(days=int(rng.integers(1, 4))), -LOCAL_PRICE[sku][cur], cur))
            continue
        while True:
            if rng.random() < CANCEL_RATE_PER_PERIOD:
                rows.append((u.user_id, "cancel", sku, False, t + pd.Timedelta(days=int(rng.integers(3, sku_dur[sku]))), 0.0, cur))
                break
            t = t + pd.Timedelta(days=sku_dur[sku])
            if t > END_DATE + pd.Timedelta(days=1) or rng.random() > RENEW_RATE:
                break
            rows.append((u.user_id, "renewal", sku, False, t, LOCAL_PRICE[sku][cur], cur))
    sub = pd.DataFrame(rows, columns=["user_id", "event_type", "sku_id", "is_trial", "event_time", "price_local", "currency"])
    sub = sub[sub["event_time"] <= END_DATE + pd.Timedelta(days=1)].sort_values("event_time").reset_index(drop=True)
    sub["sub_event_id"] = [f"se_{i:06d}" for i in range(1, len(sub) + 1)]
    sub["received_time"] = received(rng, sub["event_time"], SUB_ARRIVAL_LAG)

    # 정답: 진짜 일별 활성 구독자(유료·체험 포함) — 구매·갱신 기간 안이고 해지·환불 전
    truth = _true_active(sub, sku_dur)

    dup = sub.sample(frac=0.01, random_state=int(rng.integers(1 << 30))).copy()
    dup["received_time"] = dup["received_time"] + pd.to_timedelta(rng.integers(30, 3600, size=len(dup)), unit="s")
    sub = pd.concat([sub, dup], ignore_index=True).sort_values(["received_time", "sub_event_id"]).reset_index(drop=True)
    # 잡음: 이벤트 유형 일부 대문자
    upper = rng.random(len(sub)) < 0.1
    sub.loc[upper, "event_type"] = sub.loc[upper, "event_type"].str.upper()
    return sub[["sub_event_id", "user_id", "event_type", "sku_id", "is_trial", "event_time", "received_time", "price_local", "currency"]], truth


def _true_active(sub: pd.DataFrame, sku_dur: dict) -> pd.Series:
    days = pd.date_range(START_DATE, END_DATE, freq="D")
    active = pd.Series(0, index=days)
    ends = sub[sub.event_type.isin(["cancel", "refund"])].groupby("user_id")["event_time"].min().dt.normalize()
    per_user_days = {}
    for r in sub[sub.event_type.isin(["purchase", "renewal"])].itertuples(index=False):
        s = r.event_time.normalize()
        e = s + pd.Timedelta(days=sku_dur[r.sku_id] - 1)
        if r.user_id in ends.index:
            e = min(e, ends[r.user_id] - pd.Timedelta(days=1))
        if e < s:
            continue
        per_user_days.setdefault(r.user_id, set()).update(pd.date_range(s, min(e, END_DATE), freq="D"))
    for dset in per_user_days.values():
        for d in dset:
            active[d] += 1
    return active


def generate_rates(rng: np.random.Generator) -> pd.DataFrame:
    days = pd.date_range(START_DATE, END_DATE, freq="D")
    rows = []
    for cur, base in BASE_RATE_TO_USD.items():
        if cur == "USD":
            rate = np.ones(len(days))
        else:
            walk = np.cumsum(rng.normal(0, 0.003, size=len(days)))
            rate = base * (1 + walk)
        rows.append(pd.DataFrame({"date": days, "currency": cur, "rate_to_usd": np.round(rate, 6)}))
    return pd.concat(rows, ignore_index=True)


def main() -> None:
    rng = np.random.default_rng(SEED)
    os.makedirs(DATA_DIR, exist_ok=True)
    users = generate_users(rng)
    snap = generate_snapshots(rng, users)
    ev = generate_events(rng, users)
    sub, truth = generate_subscriptions(rng, users)
    rates = generate_rates(rng)

    fmt = "%Y-%m-%d %H:%M:%S"
    ev_out = ev.copy()
    ev_out["event_time"] = ev_out["event_time"].dt.strftime(fmt)
    ev_out["received_time"] = ev_out["received_time"].dt.strftime(fmt)
    ev_out.to_csv(os.path.join(DATA_DIR, "events.csv"), index=False)

    sub_out = sub.copy()
    sub_out["event_time"] = sub_out["event_time"].dt.strftime(fmt)
    sub_out["received_time"] = sub_out["received_time"].dt.strftime(fmt)
    sub_out["is_trial"] = sub_out["is_trial"].map({True: "true", False: "false"})   # DuckDB 가 BOOLEAN 으로 추론
    sub_out.to_csv(os.path.join(DATA_DIR, "subscription_events.csv"), index=False)

    snap_out = snap.copy()
    snap_out["snapshot_date"] = snap_out["snapshot_date"].dt.strftime("%Y-%m-%d")
    snap_out["install_date"] = snap_out["install_date"].dt.strftime("%Y-%m-%d")
    snap_out.to_csv(os.path.join(DATA_DIR, "user_snapshots.csv"), index=False)

    SKUS.to_csv(os.path.join(DATA_DIR, "sku.csv"), index=False)
    rates_out = rates.copy()
    rates_out["date"] = rates_out["date"].dt.strftime("%Y-%m-%d")
    rates_out.to_csv(os.path.join(DATA_DIR, "exchange_rates.csv"), index=False)

    june = truth[truth.index >= "2026-06-01"]
    paid = sub[sub.event_type.isin(["purchase", "renewal", "refund"]) & ~sub.sub_event_id.duplicated()]
    rate_map = rates.set_index([rates["date"].dt.normalize(), "currency"])["rate_to_usd"]
    usd = sum(r.price_local * rate_map[(r.event_time.normalize(), r.currency)] for r in paid.itertuples(index=False))
    print(f"wrote -> {DATA_DIR}")
    print(f"  events.csv              : {len(ev):,} rows (중복 {int(len(ev) - ev.event_id.nunique()):,} · 시스템 이벤트 포함)")
    print(f"  subscription_events.csv : {len(sub):,} rows (유저 {sub.user_id.nunique():,}명)")
    print(f"  user_snapshots.csv      : {len(snap):,} rows (유저 {N_USERS:,}명 × 설치 이후 매일)")
    print(f"  date range              : {START_DATE.date()} ~ {END_DATE.date()}")
    print(f"  심은 정답: 6월 일평균 활성 구독자 {june.mean():,.0f}명 (체험 포함) · 기간 매출 합계 ${usd:,.0f} (환불 반영)")
    print(f"            도착 지연 분포 — 앱 이벤트 당일 {ARRIVAL_LAG[0]:.0%} / D+1 {ARRIVAL_LAG[1]:.0%} / D+2 {ARRIVAL_LAG[2]:.0%} / D+3 {ARRIVAL_LAG[3]:.0%}"
          f" · 구독 이벤트 {SUB_ARRIVAL_LAG[0]:.0%} / {SUB_ARRIVAL_LAG[1]:.0%} / {SUB_ARRIVAL_LAG[2]:.0%} / {SUB_ARRIVAL_LAG[3]:.0%}")


if __name__ == "__main__":
    main()
