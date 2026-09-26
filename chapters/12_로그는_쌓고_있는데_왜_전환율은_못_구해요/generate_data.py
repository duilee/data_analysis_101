"""로그는 쌓고 있는데 왜 전환율은 못 구해요? — 예시 데이터 생성기.

가상 콘텐츠 앱(온보딩 4단계 → 홈 → 콘텐츠 상세 → 홈 배너 → 결제)의
택소노미 문서 2개(taxonomy_events.csv, taxonomy_properties.csv)와
30일치 이벤트 로그(event_log.csv, 2026-08-01 ~ 08-30)를 만든다. 시드 고정.

2026-08-25에 앱 3.5.0이 배포되면서 로그가 조용히 깨지는 사고 5종을 심어 둔다. 다섯 모두 표준 문턱(±60%, 최소 50건)으로 잡힌다.
  1 iOS   tap_content_card          이벤트 수 -65%  (탭 핸들러 버그로 이벤트 누락)      → 감지됨 (급감)
  2 Android view_content_card       이벤트 수 2배   (노출 이벤트 중복 발화)              → 감지됨 (급증)
  3 iOS   page_view_content_detail  content_id 채움률 100% → 30% (프로퍼티 누락)       → 감지됨 (null 비율)
  4 Android page_view_home          이벤트 수 -70%  (홈 진입 이벤트 누락)               → 감지됨 (급감)
  5 subscription_renewed (서버)     이벤트 수 -100% (갱신 배치 중단)                  → 감지됨 (급감, 0건)
"""
import json, os
import numpy as np
import pandas as pd

SEED = 11
rng = np.random.default_rng(SEED)
HERE = os.path.dirname(os.path.abspath(__file__))
START = pd.Timestamp("2026-08-01")
DAYS = 30
RELEASE_DAY = 24                  # 2026-08-25 부터 3.5.0
N_USERS = 3000

# ---------- 1. 택소노미 문서: 이벤트 ----------
E = []
def ev(name, etype, screen, desc, source="Client", platform="iOS|Android", status="Live", lifetime="Permanent", ver="3.0.0"):
    E.append((name, etype, source, platform, screen, desc, status, lifetime, ver))
ev("system_first_launch", "System", "app", "설치 후 첫 실행. 모든 퍼널의 기준 이벤트")
ev("page_view_onboarding_step", "Page View", "onboarding", "온보딩 각 단계 화면 진입. step 프로퍼티로 단계 구분")
ev("tap_onboarding_next", "Tap/Click", "onboarding", "온보딩 다음 버튼 탭")
ev("tap_onboarding_skip", "Tap/Click", "onboarding", "온보딩 건너뛰기 탭")
ev("system_permission_granted", "System", "onboarding", "권한 허용 결과. permission 프로퍼티로 종류 구분")
ev("page_view_home", "Page View", "home", "홈 화면 진입")
ev("view_main_banner", "View", "home", "홈 상단 배너 노출")
ev("tap_main_banner", "Tap/Click", "home", "홈 상단 배너 탭")
ev("view_content_card", "View", "home", "홈 피드의 콘텐츠 카드 노출")
ev("tap_content_card", "Tap/Click", "home", "홈 피드의 콘텐츠 카드 탭")
ev("page_view_content_detail", "Page View", "content_detail", "콘텐츠 상세 화면 진입")
ev("tap_like_button", "Tap/Click", "content_detail", "콘텐츠 좋아요 탭")
ev("tap_share_button", "Tap/Click", "content_detail", "콘텐츠 공유 버튼 탭")
ev("page_view_search", "Page View", "search", "검색 화면 진입")
ev("tap_search_result", "Tap/Click", "search", "검색 결과 탭")
ev("page_view_paywall", "Page View", "paywall", "결제 화면 진입. source 프로퍼티로 진입 경로 구분")
ev("tap_purchase_button", "Tap/Click", "paywall", "구매 버튼 탭")
ev("subscription_started", "System", "server", "구독 시작 (서버)", source="Server")
ev("subscription_renewed", "System", "server", "구독 갱신 (서버 일 배치)", source="Server")
ev("page_view_settings", "Page View", "settings", "설정 화면 진입")
ev("tap_theme_toggle", "Tap/Click", "settings", "테마 전환 토글 탭")
ev("system_push_sent", "System", "server", "푸시 발송 (서버)", source="Server")
ev("tap_push_notification", "Tap/Click", "app", "푸시 알림 탭")
ev("page_view_profile", "Page View", "profile", "프로필 화면 진입")
events = pd.DataFrame(E, columns=["event_name","event_type","source","platform","screen_name","description","status","lifetime","version_added"])

# ---------- 2. 택소노미 문서: 프로퍼티 ----------
P = [
 ("step","event","enum","1|2|3|4","온보딩 단계 번호","page_view_onboarding_step|tap_onboarding_next|tap_onboarding_skip"),
 ("permission","event","enum","notification|camera|location","허용된 권한 종류","system_permission_granted"),
 ("banner_id","event","string","","배너 식별자","view_main_banner|tap_main_banner"),
 ("content_id","event","string","","콘텐츠 식별자","view_content_card|tap_content_card|page_view_content_detail|tap_like_button|tap_share_button"),
 ("content_type","event","enum","article|video","콘텐츠 종류","view_content_card|tap_content_card|page_view_content_detail"),
 ("position","event","int","","피드 안에서의 순서(0부터)","view_content_card|tap_content_card|tap_search_result"),
 ("channel","event","enum","kakao|instagram|link","공유 채널","tap_share_button"),
 ("source","event","enum","home|content_detail|settings|push","결제 화면 진입 경로","page_view_paywall"),
 ("plan","event","enum","monthly|yearly","구독 플랜","tap_purchase_button|subscription_started|subscription_renewed"),
 ("theme","event","enum","dark|light","전환된 테마","tap_theme_toggle"),
 ("push_type","event","enum","daily|content|promo","푸시 종류","system_push_sent|tap_push_notification"),
 ("subscription_status","user","enum","free|trial|paid|churned","구독 상태",""),
 ("signup_date","user","date","","가입일",""),
]
props = pd.DataFrame(P, columns=["property_name","scope","data_type","allowed_values","description","events"])

# ---------- 3. 이벤트 로그 ----------
rows = []
def log(t, uid, plat, ver, name, screen, **pr):
    rows.append((t.strftime("%Y-%m-%d %H:%M:%S"), uid, plat, ver, name, screen, json.dumps(pr, ensure_ascii=False)))

def version_for(day):      # 3.5.0 은 배포일부터 빠르게 퍼진다고 가정
    if day < RELEASE_DAY: return rng.choice(["3.4.0","3.4.1"], p=[0.3,0.7])
    return rng.choice(["3.4.1","3.5.0"], p=[0.15,0.85])

for i in range(N_USERS):
    uid = f"u{i:05d}"
    plat = "iOS" if rng.random() < 0.55 else "Android"
    d0 = int(rng.integers(-20, DAYS))            # 설치일(일부는 관측 시작 전)
    sub = bool(rng.random() < 0.30)
    if d0 >= 0:                                  # 관측 기간 안에 설치한 유저의 온보딩
        t = START + pd.Timedelta(days=d0, minutes=int(rng.integers(0, 24*60)))
        ver = version_for(d0)
        log(t, uid, plat, ver, "system_first_launch", "app")
        for step in (1,2,3,4):
            t += pd.Timedelta(seconds=int(rng.integers(5, 60)))
            log(t, uid, plat, ver, "page_view_onboarding_step", "onboarding", step=step)
            if rng.random() < 0.06: log(t, uid, plat, ver, "tap_onboarding_skip", "onboarding", step=step); break
            if rng.random() < 0.10: break
            log(t, uid, plat, ver, "tap_onboarding_next", "onboarding", step=step)
        else:
            if rng.random() < 0.7: log(t, uid, plat, ver, "system_permission_granted", "onboarding", permission="notification")
    for day in range(max(d0, 0), DAYS):
        age = day - d0
        if rng.random() > 0.55 * 0.93 ** age + 0.10: continue
        t = START + pd.Timedelta(days=day, minutes=int(rng.integers(0, 24*60)))
        ver = version_for(day)
        broken = day >= RELEASE_DAY and ver == "3.5.0"
        if not (broken and plat == "Android" and rng.random() < 0.85):                                           # 사고 4
            log(t, uid, plat, ver, "page_view_home", "home")
        if rng.random() < 0.6:
            bid = f"b{int(rng.integers(1,6))}"
            log(t, uid, plat, ver, "view_main_banner", "home", banner_id=bid)
            if rng.random() < 0.08: log(t, uid, plat, ver, "tap_main_banner", "home", banner_id=bid)
        for pos in range(int(rng.integers(2, 6))):
            cid = f"c{int(rng.integers(1, 400)):03d}"; ctype = rng.choice(["article","video"])
            log(t, uid, plat, ver, "view_content_card", "home", content_id=cid, content_type=ctype, position=pos)
            if broken and plat == "Android":                                                                     # 사고 2
                log(t, uid, plat, ver, "view_content_card", "home", content_id=cid, content_type=ctype, position=pos)
            if rng.random() < 0.25:
                if not (broken and plat == "iOS" and rng.random() < 0.85):                                        # 사고 1
                    log(t, uid, plat, ver, "tap_content_card", "home", content_id=cid, content_type=ctype, position=pos)
                detail = dict(content_id=cid, content_type=ctype)
                if broken and plat == "iOS" and rng.random() < 0.85: detail["content_id"] = None                  # 사고 3
                log(t, uid, plat, ver, "page_view_content_detail", "content_detail", **detail)
                if rng.random() < 0.3: log(t, uid, plat, ver, "tap_like_button", "content_detail", content_id=cid)
                if rng.random() < 0.08: log(t, uid, plat, ver, "tap_share_button", "content_detail", content_id=cid, channel=rng.choice(["kakao","instagram","link"]))
        if rng.random() < 0.15:
            log(t, uid, plat, ver, "page_view_search", "search")
            if rng.random() < 0.5: log(t, uid, plat, ver, "tap_search_result", "search", position=int(rng.integers(0,5)))
        if rng.random() < 0.08:
            log(t, uid, plat, ver, "page_view_settings", "settings")
            if rng.random() < 0.3: log(t, uid, plat, ver, "tap_theme_toggle", "settings", theme=rng.choice(["dark","light"]))
        if not sub and rng.random() < 0.10:
            log(t, uid, plat, ver, "page_view_paywall", "paywall", source=rng.choice(["home","content_detail","settings"]))
            if rng.random() < 0.15:
                plan = rng.choice(["monthly","yearly"], p=[0.7,0.3])
                log(t, uid, plat, ver, "tap_purchase_button", "paywall", plan=plan)
                log(t, uid, plat, ver, "subscription_started", "server", plan=plan); sub = True
        if rng.random() < 0.04: log(t, uid, plat, ver, "page_view_profile", "profile")
    # 서버 이벤트: 구독 갱신 일 배치(사고 5: 배포 뒤 중단), 푸시
    if sub:
        for day in range(DAYS):
            if day >= RELEASE_DAY: break                                                                          # 사고 5
            if rng.random() < 0.15: log(START + pd.Timedelta(days=day, hours=3), uid, plat, "server", "subscription_renewed", "server", plan="monthly")
    for day in range(max(d0, 0), DAYS):
        if rng.random() < 0.06:
            t = START + pd.Timedelta(days=day, hours=9)
            log(t, uid, plat, "server", "system_push_sent", "server", push_type="daily")
            if rng.random() < 0.2: log(t + pd.Timedelta(minutes=3), uid, plat, version_for(day), "tap_push_notification", "app", push_type="daily")

logdf = pd.DataFrame(rows, columns=["event_time","user_id","platform","app_version","event_name","screen_name","properties"]).sort_values("event_time")
os.makedirs(os.path.join(HERE, "data"), exist_ok=True)
events.to_csv(os.path.join(HERE, "data", "taxonomy_events.csv"), index=False)
props.to_csv(os.path.join(HERE, "data", "taxonomy_properties.csv"), index=False)
logdf.to_csv(os.path.join(HERE, "data", "event_log.csv"), index=False)
print(f"events {len(events)} / properties {len(props)} / log rows {len(logdf):,} / users {logdf.user_id.nunique():,} / days {logdf.event_time.str[:10].nunique()}")
