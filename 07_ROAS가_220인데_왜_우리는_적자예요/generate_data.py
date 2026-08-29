"""ROAS가 220%인데 왜 우리는 적자예요? — 유닛 이코노믹스 실습용 예시 데이터 생성기.

가공 전 원본 로그 세 장을 만든다. 본문에서 완성된 표들을 이 로그에서
직접 계산해 복원하는 것이 실습이다.

  - marketing_costs : 월 × 채널 마케팅 비용 (매체비 / 기타 비용 분리)
  - users           : 유입 유저 명부 (채널, 유입일 — 결제 안 한 유저 포함)
  - payments        : 결제 건별 로그 (유저, 결제일, 금액 = 매출)

미리 심어 둔 정답 (실습에서 복원 대상, 모두 본문 표의 값):
  - 2025-04 유료 유입 2,500명 — 검색 40% / 디스플레이 20% / 리타겟팅 10% / 브랜드 30%
  - 채널별 fully-loaded CAC: 11,500 / 5,700 / 3,600 / 28,000원
    → 유료 전체 CAC: 매체비 기준 12,000원 → fully-loaded 14,500원
  - 채널별 LTV(공헌이익, 36개월 실측): 33,000 / 5,900 / 24,000 / 24,000원
    (오가닉 26,000원) → 유료 전체 LTR 약 37,000원, LTV 약 24,000원
  - 2025-04 검색 코호트 회수 곡선: 0.35 / 0.62 / 0.80 / 0.90 / 0.97 / 1.03
    (월별 공헌이익 403 / 310 / 207 / 110 / 85 / 70만원 → Payback 6개월째 회수)

공헌이익률 65%(변동비 35%)는 본문 2.1의 가정이며, 노트북에서 상수로 사용한다.
로그의 금액은 전부 '매출'이고, 공헌이익 변환은 실습에서 직접 한다.

시드를 고정했으므로 누가 실행하든 항상 같은 데이터가 만들어진다.
"""

from __future__ import annotations

import os
import sys

import numpy as np
import pandas as pd

# 출력이 파이프로 캡처될 때 cp949로 인코딩돼 한글이 깨지는 것을 방지
sys.stdout.reconfigure(encoding="utf-8")

SEED = 42
BASE = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(SEED)

CM_RATIO = 0.65        # 공헌이익률 (본문 2.1: 변동비 35%)
HORIZON = 36           # LTV 실측 기간(개월) — 성숙 코호트가 이 기간을 채운다
DATA_END = pd.Period("2026-06", "M")   # 결제 로그 마지막 달

# ---------------------------------------------------------------------------
# 1) 채널별 '유저당 월별 공헌이익' 스케줄 (원, 획득 후 0~35개월)
#    — 36개월 합계가 본문 채널 표의 LTV(공헌이익)가 되도록 역설계한 감쇠 곡선
# ---------------------------------------------------------------------------

def _tail(total: float, months: int, start: float, end: float) -> list[float]:
    """합이 total이 되는 완만한 선형 감쇠 꼬리를 만든다."""
    raw = np.linspace(start, end, months)
    return list(raw * (total / raw.sum()))

SCHEDULES: dict[str, list[float]] = {
    # 검색: 초반 6개월은 본문 회수 곡선 표의 값 그대로, 이후 긴 꼬리 (합 33,000)
    "search": [4030, 3100, 2070, 1100, 850, 700] + _tail(21150, 30, 740, 670),
    # 디스플레이: 얕고 짧은 꼬리 (합 5,900 — CAC 5,700을 겨우 넘는 구조)
    "display": [399, 342, 342, 285, 285, 228, 228, 228, 228, 171, 171, 171, 171]
               + _tail(5900 - 3249, 23, 155, 90),
    # 리타겟팅: 강하게 앞쪽에 몰림 (라스트 클릭 어트리뷰션의 과대평가 서사, 합 24,000)
    "retargeting": [6000, 4200, 2900, 2000, 1500, 1100] + _tail(6300, 30, 400, 20),
    # 브랜드·기타: 완만하게 오래 가는 곡선 (합 24,000 — CAC 28,000에 못 미침)
    "brand": [1500, 1400, 1300, 1200, 1100, 1000] + _tail(16500, 30, 700, 400),
    # 오가닉: 기준선 (합 26,000)
    "organic": [3300, 2500, 1900, 1300, 1000, 900] + _tail(15100, 30, 640, 367),
}
for ch, sched in SCHEDULES.items():
    assert len(sched) == HORIZON, ch

# ---------------------------------------------------------------------------
# 2) 월별 유입 규모 (명) — 2025년 3~4월에 마케팅을 크게 늘린 시나리오
#    비중 40/20/10/30은 2025-04에 정확히 성립 (검색 1,000명 = 본문 회수 곡선 표)
# ---------------------------------------------------------------------------

PAID = ["search", "display", "retargeting", "brand"]

def _mix(total_paid: int) -> dict[str, int]:
    """유료 유입을 40/20/10/30 비중으로 나눈다."""
    return {
        "search": int(total_paid * 0.4),
        "display": int(total_paid * 0.2),
        "retargeting": int(total_paid * 0.1),
        "brand": int(total_paid * 0.3),
    }

COHORTS: dict[pd.Period, dict[str, int]] = {}
# 성숙 구간 + 연결 구간 (2022-07 ~ 2024-12): 매달 유료 300 + 오가닉 120
for m in pd.period_range("2022-07", "2024-12", freq="M"):
    COHORTS[m] = {**_mix(300), "organic": 120}
# 2025년: 3~4월 성수기 증액
for m, paid, org in [("2025-01", 900, 315), ("2025-02", 1000, 350),
                     ("2025-03", 2175, 700), ("2025-04", 2500, 800),
                     ("2025-05", 1300, 450), ("2025-06", 1200, 420)]:
    COHORTS[pd.Period(m, "M")] = {**_mix(paid), "organic": org}

# ---------------------------------------------------------------------------
# 3) 마케팅 비용 (marketing_costs.csv)
#    fully-loaded CAC 목표치 × 유입 수 = 총비용. 매체비/기타 비용으로 분해.
# ---------------------------------------------------------------------------

CAC_TARGET = {"search": 11500, "display": 5700, "retargeting": 3600, "brand": 28000}
MEDIA_SHARE = {"search": 0.86, "display": 0.88, "retargeting": 0.90, "brand": 0.80}

# 코호트 질 배율 — 2025-03 코호트는 4월보다 약간 약하다
# (같은 채널이라도 코호트에 따라 회수 속도가 달라지는 것을 보여주는 장치:
#  검색 기준 3월 코호트는 7개월째, 4월 코호트는 6개월째 본전)
QUALITY = {pd.Period("2025-03", "M"): 0.93}

cost_rows = []
for month, sizes in COHORTS.items():
    focal = month in (pd.Period("2025-04", "M"), pd.Period("2025-03", "M"))
    total_paid = sum(sizes[c] for c in PAID)
    for ch in PAID:
        n = sizes[ch]
        # 정답 달(2025-04)은 목표 CAC 그대로, 나머지 달은 ±3% 노이즈
        cac = CAC_TARGET[ch] if focal else CAC_TARGET[ch] * rng.normal(1, 0.03)
        fully = cac * n
        if focal and month == pd.Period("2025-04", "M") and ch == "brand":
            # 2025-04는 유료 전체 매체비 CAC가 정확히 12,000원이 되도록
            # 브랜드 매체비를 잔여분으로 맞춘다 (기타 채널 매체비를 뺀 나머지)
            media_others = sum(CAC_TARGET[c] * sizes[c] * MEDIA_SHARE[c] for c in PAID[:-1])
            media = 12000 * total_paid - media_others
        else:
            media = fully * MEDIA_SHARE[ch]
        focal = month == pd.Period("2025-04", "M")   # 반올림 정밀도는 4월만 원 단위
        cost_rows.append({
            "month": month.to_timestamp().date(),
            "channel": ch,
            "media_cost_krw": int(round(media, -3)) if not focal else int(round(media)),
            "other_cost_krw": int(round(fully - media)) if focal else int(round(fully - media, -3)),
        })
costs = pd.DataFrame(cost_rows)

# ---------------------------------------------------------------------------
# 4) 유저 명부 (users.csv) + 결제 로그 (payments.csv)
#    코호트(채널×유입월)×경과월 단위로 '유저당 평균 공헌이익 스케줄'을 매출로
#    환산해 총액을 정하고, 결제 건들을 그 총액에 맞춰 뽑는다.
# ---------------------------------------------------------------------------

# 채널별 결제 참여 확률(경과월별)과 평균 주문액 배율 — 결제 건수를 통제한다
PART = {  # (초반 6개월 참여 확률, 꼬리 참여 확률)
    "search": ([0.90, 0.55, 0.40, 0.25, 0.20, 0.17], 0.12),
    "display": ([0.30, 0.20, 0.18, 0.14, 0.13, 0.10], 0.05),
    "retargeting": ([0.95, 0.70, 0.55, 0.40, 0.32, 0.25], 0.10),
    "brand": ([0.45, 0.35, 0.30, 0.26, 0.23, 0.20], 0.13),
    "organic": ([0.80, 0.50, 0.38, 0.24, 0.20, 0.17], 0.11),
}

user_rows, pay_rows = [], []
uid = 0
month_days = {}  # 결제일 분산용

for month, sizes in sorted(COHORTS.items()):
    for ch, n in sizes.items():
        if n == 0:
            continue
        ids = np.arange(uid, uid + n)
        uid += n
        # 유입일: 해당 월 안에서 균등 분산
        days = rng.integers(0, month.days_in_month, n)
        signup = month.to_timestamp() + pd.to_timedelta(days, unit="D")
        for i, s in zip(ids, signup):
            user_rows.append({"user_id": f"u{i:06d}", "channel": ch,
                              "signup_date": s.date()})
        # 경과월별 결제 생성 (관측 종료 이후는 만들지 않음)
        head, tail_p = PART[ch]
        for k in range(HORIZON):
            pay_month = month + k
            if pay_month > DATA_END:
                break
            q = QUALITY.get(month, 1.0)
            target_rev = SCHEDULES[ch][k] * q / CM_RATIO * n   # 이 코호트가 이 달에 만드는 매출 총액
            target_rev *= rng.normal(1, 0.004)             # 아주 약한 노이즈
            p = head[k] if k < 6 else tail_p
            payers = ids[rng.random(n) < p]
            if len(payers) == 0:
                payers = rng.choice(ids, 1)
            # 주문액: 로그정규로 뽑은 뒤 총액에 정확히 맞춰 스케일
            amounts = rng.lognormal(0, 0.35, len(payers))
            amounts = amounts / amounts.sum() * target_rev
            pdays = rng.integers(0, pay_month.days_in_month, len(payers))
            base_ts = pay_month.to_timestamp()
            for u, a, d in zip(payers, amounts, pdays):
                pay_rows.append({
                    "user_id": f"u{int(u):06d}",
                    "payment_date": (base_ts + pd.Timedelta(days=int(d))).date(),
                    "amount_krw": max(500, int(round(a, -2))),
                })

users = pd.DataFrame(user_rows)
payments = pd.DataFrame(pay_rows).sort_values(["payment_date", "user_id"]).reset_index(drop=True)

# ---------------------------------------------------------------------------
# 5) 저장 + 요약 출력
# ---------------------------------------------------------------------------

out = os.path.join(BASE, "data")
os.makedirs(out, exist_ok=True)
costs.to_csv(os.path.join(out, "marketing_costs.csv"), index=False)
users.to_csv(os.path.join(out, "users.csv"), index=False)
payments.to_csv(os.path.join(out, "payments.csv"), index=False)

print(f"marketing_costs : {len(costs):>9,} 행 (월×채널 비용)")
print(f"users           : {len(users):>9,} 행 (유입 유저)")
print(f"payments        : {len(payments):>9,} 행 (결제 건)")
apr = costs[costs.month.astype(str) == "2025-04-01"]
n_apr = sum(COHORTS[pd.Period('2025-04', 'M')][c] for c in PAID)
print(f"2025-04 유료 유입 {n_apr:,}명 / fully-loaded 비용 "
      f"{(apr.media_cost_krw + apr.other_cost_krw).sum():,}원 "
      f"(CAC {round((apr.media_cost_krw + apr.other_cost_krw).sum() / n_apr):,}원)")
