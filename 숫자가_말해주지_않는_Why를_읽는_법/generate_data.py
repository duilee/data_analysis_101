"""커머스 상품 구매 리뷰 합성 데이터 생성기.

핵심 설계: 불만(1점)은 납작하고, 만족(5점)은 입체적이다.
- 1점은 '측면(배송·가격·디자인·색상·사이즈·재질·포장) + 부정 의견 + CS 불만'으로 구성된다.
  불만은 몇 개의 운영 이슈로 수렴하므로, 동시출현 네트워크가 소수의 '납작한' 덩어리로 갈린다.
- 5점은 여기에 더해 '사용 시나리오(쓰임새/고객군)'를 담는다. 단, 한 제품이 온갖 세그먼트를
  다 만족시키는 작위적 구조가 아니라, 현실적인 '발견(discovery)' 구조다.
  제품은 본래 '자취·원룸(좁은 공간)' 용도로 기획됐는데, 그 핵심 속성(작다·가볍다·청소 쉽다)이
  미처 상정하지 못한 맥락으로 번진다 — '차박·캠핑'(가벼워서 의외로 유용)이라는 use case,
  '반려동물 가구'(털 안 붙고 청소 쉬워 입소문)라는 customer segment.
  그래서 5점 동시출현 네트워크는 '입체적'으로 — 기획 의도 + 발견된 쓰임새/고객 덩어리로 — 가지를 친다.

이렇게 정답(1점=납작한 불만 덩어리, 5점=다채로운 쓰임새/고객 덩어리)을 심어 두면,
노트북의 동시출현 네트워크가 그 구조를 그대로 복원해 낸다. 재현을 위해 seed를 고정하고,
1점을 먼저 생성해 5점 설계 변경이 1점 데이터를 흔들지 않게 한다.
"""

import csv
import random
import datetime
from pathlib import Path

random.seed(42)

# === 리뷰 작성일(created_at) 설계 ===
# 텍스트/별점은 그대로 두고 '언제 쓰였는지'만 부여한다. 6장의 '발견' 서사를 시간축으로 살린다:
#   - 자취·원룸(기획 의도)은 초반에 몰리고,
#   - 차박·캠핑, 반려동물(발견된 쓰임새/고객)은 입소문을 타며 후반으로 갈수록 늘어난다.
#   - 1점 환불·배송 불만은 중반에 물류 이슈처럼 한 번 몰린다.
# → 토픽 시계열(area) 차트에서 '주제가 언제 떠오르고 가라앉는지'가 드러난다.
START_DATE = datetime.date(2024, 1, 1)
WEEKS = 26   # 약 6개월


def _clip_week(w):
    return int(min(WEEKS - 1, max(0, round(w))))


def assign_date(rating, text):
    """텍스트 내용으로 주제를 가늠해, 그 주제가 유행하는 시기에 작성일을 배정한다."""
    if rating == 5:
        if ("차박" in text) or ("캠핑" in text):          # 발견된 쓰임새 → 후반 상승
            w = random.triangular(WEEKS * 0.3, WEEKS - 1, WEEKS - 2)
        elif ("반려동물" in text) or ("강아지" in text):   # 발견된 고객군 → 중후반 상승
            w = random.triangular(WEEKS * 0.4, WEEKS - 1, WEEKS * 0.9)
        else:                                              # 자취·원룸(기획 의도) → 초반 집중
            w = random.triangular(0, WEEKS * 0.6, WEEKS * 0.15)
    elif rating == 1:
        if ("지연" in text) or ("하세월" in text) or ("환불" in text):   # 물류·CS 이슈 → 중반 급증
            w = random.triangular(WEEKS * 0.35, WEEKS * 0.8, WEEKS * 0.55)
        else:
            w = random.uniform(0, WEEKS - 1)
    else:
        w = random.uniform(0, WEEKS - 1)
    d = START_DATE + datetime.timedelta(weeks=_clip_week(w), days=random.randint(0, 6))
    return d.isoformat()

OUT = Path(__file__).parent / "data"
OUT.mkdir(exist_ok=True)

PRODUCTS = [f"P-{1000 + i}" for i in range(40)]

# 중립 측면(양쪽 공통) + 측면별 긍정/부정 의견 (연결어미 '-고'로 끝나 자연스럽게 이어짐)
ASPECTS = {
    "배송": {
        "pos": ["배송이 빠르고", "배송이 신속하고", "배송이 하루 만에 오고"],
        "neg": ["배송이 느리고", "배송이 일주일째 지연되고", "배송이 하세월이고"],
    },
    "가격": {
        "pos": ["가격이 합리적이고", "가격이 만족스럽고", "가성비가 훌륭하고"],
        "neg": ["가격이 아깝고", "가격이 비싼데 별로고", "가격값을 못 하고"],
    },
    "디자인": {
        "pos": ["디자인이 예쁘고", "디자인이 세련되고", "디자인이 고급스럽고"],
        "neg": ["디자인이 별로고", "디자인이 사진과 다르고", "디자인이 촌스럽고"],
    },
    "색상": {
        "pos": ["색상이 화면과 똑같고", "색상이 선명하고", "색상이 마음에 들고"],
        "neg": ["색상이 칙칙하고", "색상이 사진과 다르고", "색상이 이상하고"],
    },
    "사이즈": {
        "pos": ["사이즈가 딱 맞고", "사이즈가 정사이즈고", "사이즈가 넉넉하고"],
        "neg": ["사이즈가 작고", "사이즈가 안 맞고", "사이즈가 헐렁하고"],
    },
    "재질": {
        "pos": ["재질이 튼튼하고", "재질이 고급스럽고", "재질이 부드럽고"],
        "neg": ["재질이 부실하고", "재질이 싸구려 같고", "재질이 거칠고"],
    },
    "포장": {
        "pos": ["포장이 꼼꼼하고", "포장이 깔끔하고", "포장이 정성스럽고"],
        "neg": ["포장이 엉망이고", "포장이 부실해서 파손됐고", "포장이 허술하고"],
    },
}

# === 1점(불만) ===
NEG_CS = ["환불 요청에 연락이 안 되고", "환불이 계속 지연되고",
          "환불 취소 처리가 엉망이고", "환불 문의에 연락이 두절이고"]
NEG_CLOSER = ["완전 실망이에요", "두 번 다시 안 사요", "환불 받고 싶네요", "별점이 아까워요"]

# === 5점(만족)의 '사용 시나리오' — 한 제품의 핵심 속성(작다·가볍다·청소 쉽다)이
#     기획 의도(자취)를 넘어 의외의 쓰임새/고객으로 번지는 '발견' 구조 ===
SCENARIOS = {
    # 기획 의도: 좁은 공간을 위한 자취·원룸 용품 (앵커: 자취·원룸·공간)
    "자취·원룸": [
        "자취방 원룸이 좁아서 걱정했는데 공간을 차지하지 않아요",
        "원룸 자취 공간에 두기 딱 좋은 크기예요",
        "혼자 사는 원룸이라 공간 차지 안 하는 크기가 마음에 들어요",
        "자취 시작하면서 샀는데 좁은 원룸 공간에 잘 맞아요",
        "자취방이 좁은데 원룸 공간을 차지하지 않아 만족해요",
    ],
    # 발견된 use case: 가벼워서 의외로 캠핑·차박에서 유용 (앵커: 캠핑·차박·휴대·야외)
    # 차박·캠핑이 각자 독립적으로도 등장하게 분산(완전 공선성 방지) + 한 문장에서 함께 다리 역할
    "차박·캠핑": [
        "원래 집에서 쓰려고 샀는데 가벼워서 차박 갈 때 챙겨 가요",
        "캠핑 야외에서 쓰기 좋고 휴대가 편해요",
        "가볍고 휴대가 편해 차박 갈 때마다 챙겨요",
        "캠핑 다닐 때 배낭에 넣어도 가벼워 부담 없어요",
        "캠핑 차박 같은 야외에서 휴대가 편해 의외로 유용해요",
        "차박 야외에서 휴대가 편하고 가벼워 유용해요",
    ],
    # 발견된 customer segment: 털 안 붙고 청소 쉬워 반려인 사이 입소문 (앵커: 강아지·반려동물·털·청소)
    "반려동물": [
        "강아지 키우는데 털도 잘 안 붙고 청소가 쉬워요",
        "반려동물 강아지 있는 집인데 털 청소가 간편해 위생적이에요",
        "강아지 털이 안 붙어서 반려동물 키우는 분들께 추천해요",
        "반려동물 키우는 집이라 털 청소가 쉽고 위생적이라 좋아요",
        "강아지 털 청소가 쉬워서 반려동물 키우며 입소문 났어요",
    ],
}
POS_CLOSER = ["전체적으로 만족스러워요", "재구매 의사 있어요", "강력 추천합니다", "기대 이상이라 좋네요"]

NOISE = ["", "", "", "ㅋㅋ", "ㅠㅠ", "!!", "..."]


def make_neg():
    asp = random.sample(list(ASPECTS), k=random.randint(2, 3))
    parts = [random.choice(ASPECTS[a]["neg"]) for a in asp]
    if random.random() < 0.55:                                   # 절반 이상 CS 불만 포함
        parts.insert(random.randint(0, len(parts)), random.choice(NEG_CS))
    parts.append(random.choice(NEG_CLOSER))
    return " ".join(parts) + random.choice(NOISE)


def make_pos():
    parts = []
    # 1~2개 사용 시나리오(쓰임새/고객군) — 만족 리뷰를 '입체적'으로 만든다
    for s in random.sample(list(SCENARIOS), k=random.randint(1, 2)):
        parts.append(random.choice(SCENARIOS[s]))
    # 측면 만족 3개 — 중립 측면어(배송·가격·포장…)가 5점 빈도 상위를 함께 채우게 한다.
    # 이래야 단순 빈도 워드클라우드는 양쪽 다 측면어로 비슷·밋밋해지고, 유니크 필터로
    # 그 공통층을 걷어낸 뒤에야 5점만의 쓰임새/고객 단어(원룸·강아지·청소…)가 드러난다.
    for a in random.sample(list(ASPECTS), k=3):
        parts.append(random.choice(ASPECTS[a]["pos"]))
    parts.append(random.choice(POS_CLOSER))
    random.shuffle(parts)
    return " ".join(parts) + random.choice(NOISE)


def make_mid():
    # 2~4점: 한 측면은 만족, 다른 측면은 불만이 섞인 리뷰
    a1, a2 = random.sample(list(ASPECTS), 2)
    return f"{random.choice(ASPECTS[a1]['pos'])} {random.choice(ASPECTS[a2]['neg'])} 그냥 무난해요"


rows = []
for _ in range(450):                                  # 1점을 먼저 생성(이후 5점 변경에 영향 없게)
    rows.append((random.choice(PRODUCTS), 1, make_neg()))
for _ in range(450):
    rows.append((random.choice(PRODUCTS), 5, make_pos()))
for _ in range(120):
    rows.append((random.choice(PRODUCTS), random.choice([2, 3, 4]), make_mid()))

random.shuffle(rows)
# review_id 1..N 재부여 + 작성일(created_at) 부여 (텍스트 생성이 끝난 뒤라 본문/별점은 그대로)
rows = [(i + 1, p, r, t, assign_date(r, t)) for i, (p, r, t) in enumerate(rows)]

with open(OUT / "reviews.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["review_id", "product_id", "rating", "text", "created_at"])
    w.writerows(rows)

print(f"reviews.csv 생성 완료: {len(rows)}건 (1점 450 / 5점 450 / 2~4점 120), created_at 포함")
