"""구독 서비스의 성장 지표 확인하기 — MRR 분석 실습용 예시 데이터 생성기.

Google Play Sales Report와 비슷한 형태의 '결제 로그' 테이블 하나를 만든다.

  - subscription_sales : 결제 건별 로그 (order_number, order_charged_date,
                         product_id, sales_amount_krw)

핵심 설계: 유저 ID 컬럼을 일부러 제공하지 않는다. 실제 스토어 리포트처럼
order_number의 prefix(동일 유저)와 suffix(갱신 회차)를 파싱해서 유저를
식별하는 것부터가 실습이다. 첫 결제는 suffix가 없고, 갱신 결제부터
"..1", "..2" 형태의 suffix가 붙는다(실제 구글 리포트의 동작 방식).

미리 심어 둔 정답 (실습 마지막에 복원 대상):
  - 월 이탈률(CHURN_RATE) 5% → 실습에서 계산한 churn rate가 이 값 근처로 수렴
  - 이탈률의 역수로 어림한 기대 구독 유지 기간 ≈ 20개월 (본문 '정리하며'의 LTV 어림식)
  - 플랜 업/다운그레이드를 소량 심어 GRR과 NRR 사이에 갭이 생기게 함

시드를 고정했으므로 누가 실행하든 항상 같은 데이터가 만들어진다.
"""

from __future__ import annotations

import os
import sys
from datetime import date

import numpy as np
import pandas as pd

# 출력이 파이프로 캡처될 때 cp949로 인코딩돼 한글이 깨지는 것을 방지 (콘솔 직접 출력에는 영향 없음)
sys.stdout.reconfigure(encoding="utf-8")

SEED = 42
START = (2025, 1)          # 첫 코호트 가입 월
END = (2026, 6)            # 마지막 결제 월 (이 달까지 데이터 생성)
BASE_NEW_USERS = 60        # 첫 달 신규 유료 구독자 수
NEW_USER_GROWTH = 1.05     # 신규 유료 구독자 월 성장률

PLANS = {"monthly_basic": 4900, "monthly_plus": 9900}
P_START_PLUS = 0.25        # 첫 구독 시 plus 플랜을 고를 확률

CHURN_RATE = 0.05          # ★ 심는 정답: 월 이탈률 5%
P_UPGRADE = 0.015          # 갱신 시 basic → plus 확률 (expansion MRR의 원천)
P_DOWNGRADE = 0.010        # 갱신 시 plus → basic 확률 (contraction MRR의 원천)
P_REACTIVATE = 0.015       # 이탈 유저가 어느 달에 다시 구독을 시작할 확률

BASE = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(SEED)


def month_seq(start: tuple[int, int], end: tuple[int, int]) -> list[tuple[int, int]]:
    """(연, 월) 시퀀스. start ~ end 포함."""
    out, (y, m) = [], start
    while (y, m) <= end:
        out.append((y, m))
        m += 1
        if m == 13:
            y, m = y + 1, 1
    return out


def make_order_number(prefix: str, k: int) -> str:
    """구글 스타일 주문번호. 첫 결제(k=0)는 suffix 없음, 갱신부터 '..k'."""
    return prefix if k == 0 else f"{prefix}..{k}"


MONTHS = month_seq(START, END)
rows = []
uid = 0

for i, (cy, cm) in enumerate(MONTHS):
    # 이 달에 유입되는 신규 유료 구독자 수 (완만한 성장 + 노이즈)
    n_new = int(BASE_NEW_USERS * NEW_USER_GROWTH ** i + rng.integers(-5, 6))
    for _ in range(n_new):
        uid += 1
        # 실제 구글 주문번호와 비슷한 모양의 유저 고유 prefix
        prefix = "GPA.{:04d}-{:04d}-{:04d}-{:05d}".format(
            rng.integers(1000, 9999), rng.integers(1000, 9999),
            rng.integers(1000, 9999), 10000 + uid)
        plan = "monthly_plus" if rng.random() < P_START_PLUS else "monthly_basic"
        anniversary = int(rng.integers(1, 29))    # 결제일(1~28일, 월별 존재 보장)

        # 가입 월부터 END까지 한 달씩 진행하며 결제/이탈/복귀를 시뮬레이션
        k = 0                  # 누적 결제 회차 (order_number suffix)
        active = True
        inactive_months = 0    # 이탈 후 경과 월수 (재구독은 한 달 이상 공백 후에만)
        for (y, m) in month_seq((cy, cm), END):
            if active:
                rows.append({
                    "order_number": make_order_number(prefix, k),
                    "order_charged_date": date(y, m, anniversary),
                    "product_id": plan,
                    "sales_amount_krw": PLANS[plan],
                })
                k += 1
                # 다음 달 갱신 여부 결정 (★ 심는 정답: 5% 이탈)
                if rng.random() < CHURN_RATE:
                    active = False
                    inactive_months = 0
                else:
                    r = rng.random()
                    if plan == "monthly_basic" and r < P_UPGRADE:
                        plan = "monthly_plus"          # expansion
                    elif plan == "monthly_plus" and r < P_DOWNGRADE:
                        plan = "monthly_basic"         # contraction
            else:
                # 이탈 상태 → 최소 한 달의 공백 후, 낮은 확률로 재구독.
                # (이탈 직후 달에 바로 복귀하면 renew와 구분이 안 되므로 공백을 보장)
                inactive_months += 1
                if inactive_months >= 2 and rng.random() < P_REACTIVATE:
                    active = True
                    anniversary = int(rng.integers(3, 29))
                    rows.append({
                        "order_number": make_order_number(prefix, k),
                        "order_charged_date": date(y, m, anniversary),
                        "product_id": plan,
                        "sales_amount_krw": PLANS[plan],
                    })
                    k += 1
                    if rng.random() < CHURN_RATE:
                        active = False
                        inactive_months = 0

sales = pd.DataFrame(rows).sort_values(["order_charged_date", "order_number"])

os.makedirs(os.path.join(BASE, "data"), exist_ok=True)
out = os.path.join(BASE, "data", "subscription_sales.csv")
sales.to_csv(out, index=False)

print(f"생성 완료: {out}")
print(f"  결제 건수 {len(sales):,}건 / 유저 수 {uid:,}명 / 기간 {MONTHS[0]} ~ {MONTHS[-1]}")
print(f"  심은 정답: 월 이탈률 {CHURN_RATE:.0%} (기대 유지 기간 ≈ {1/CHURN_RATE:.0f}개월)")
