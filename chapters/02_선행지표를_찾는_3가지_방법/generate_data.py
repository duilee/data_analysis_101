"""선행지표 탐색 실습용 예시 데이터 생성기.

신규 유저 한 명 한 명의 설치(D0) 직후 세션을 *순서가 있는 이벤트 흐름*으로 시뮬레이션해
하나의 raw 이벤트 로그 data/event_log.csv 로 떨어뜨린다. 이 로그 한 벌이 세 실습 모두의 입력이다.

  - 2.5.2 (EDA)   : D7 잔존/비잔존으로 라벨링 후 D0~D1 행동의 발생 비중·평균 횟수 비교
  - 2.5.3 (SHAP)  : 유저별 행동 피처로 D7 잔존을 예측하고 기여도를 분해
  - 2.5.4 (Sankey): 설치 세션 이벤트 시퀀스를 흐름으로 그리고 전이별 D7 잔존율로 색칠

핵심은 "심어둔 진실"이다. 유저마다 잠재 품질값 q 를 부여하고, q 가 (a) 어떤 행동을 하는지와
(b) D7에 잔존하는지를 함께 좌우하게 만든다. 더해서 잔존 확률(logit)을 *행동 피처와 흐름 분기의
함수*로 직접 구성하기 때문에, 세 가지 방법이 모두 같은 선행지표(튜토리얼 완료·콘텐츠 조회·좋아요
등)를 각자의 방식으로 복원하게 된다. 합성이지만 결과가 진실을 되짚어 주는 것이 실습의 핵심이다.

심어둔 관계 (세 실습에서 일관되게 드러나야 함):
  - tap_tutorial_complete / system_push_permission_granted : 잔존 유저에서 수행 비중이 크게 높음
  - page_view_content_detail 횟수              : 많을수록 잔존↑ (단조 증가)
  - tap_like_button                   : 3회 이상에서 잔존이 한 번 더 꺾여 올라감 (임계/아하 모먼트)
  - session_duration_sec           : 약 150초 이상에서 잔존이 꺾여 올라감 (임계/아하 모먼트)
  - tap_search_button                    : 수행 비중은 낮지만, 하는 유저는 여러 번 함 (평균 횟수↑)
  - view_error_popup                    : 많을수록 잔존↓ (음의 기여)
  - 흐름 분기                       : 튜토리얼 스킵 / 홈→내정보·설정 이탈은 잔존↓,
                                      홈→콘텐츠 조회→좋아요는 잔존↑
"""

import os
import sys

import numpy as np
import pandas as pd

# 출력이 파이프로 캡처될 때 cp949로 인코딩돼 한글이 깨지는 것을 방지 (콘솔 직접 출력에는 영향 없음)
sys.stdout.reconfigure(encoding="utf-8")

SEED = 314
N_USERS = 12_000
INSTALL_DAYS = 7                       # 설치일을 이 기간에 고르게 분포 (D7이 관측되도록)
BASE_DATE = pd.Timestamp("2026-01-01")  # 첫 설치 가능일

# 이벤트 메타데이터: event_name -> (screen_name, description)
EVENT_META = {
    "system_app_install":        ("app",            "앱 설치"),
    "page_view_onboarding_step":  ("onboarding",     "온보딩 단계 조회"),
    "tap_tutorial_complete":          ("onboarding",     "튜토리얼 완료"),
    "system_push_permission_granted":                 ("permission",     "푸시 알림 허용"),
    "page_view_home":             ("home",           "메인 홈 조회"),
    "page_view_content_detail":               ("content_detail", "메인 콘텐츠 상세 조회"),
    "tap_like_button":               ("content_detail", "콘텐츠 좋아요"),
    "tap_share_button":              ("content_detail", "콘텐츠 공유"),
    "tap_search_button":                ("search",         "검색 사용"),
    "page_view_profile":          ("profile",        "내 정보 조회"),
    "page_view_settings":              ("settings",       "설정 열기"),
    "view_error_popup":                ("error",          "에러 팝업 노출"),
}


def sigmoid(x):
    return 1.0 / (1.0 + np.exp(-x))


def simulate_user(uid, q, install_dt, rng, rows):
    """유저 한 명의 설치 세션(D0)을 순서대로 시뮬레이션하고 rows 에 이벤트를 추가한다.

    반환: (d7_retained, d1_retained, session_duration_sec) — 잔존 활동을 추가로 찍기 위함.
    """
    # 세션 안에서 흐르는 상대 시각(초). 이벤트마다 몇 초~수십 초씩 머문다.
    clock = {"t": 0}

    def emit(event_name, dt_base, count=1, gap=(3, 40)):
        clock["t"] += int(rng.integers(gap[0], gap[1] + 1))
        ts = dt_base + pd.Timedelta(seconds=clock["t"])
        screen, desc = EVENT_META[event_name]
        rows.append((ts, ts.date(), uid, event_name, screen, count, desc))

    # --- D0 설치 세션: 분기되는 흐름 ---------------------------------------
    emit("system_app_install", install_dt, gap=(0, 1))
    emit("page_view_onboarding_step", install_dt, gap=(2, 8))

    # 분기 1) 튜토리얼 완료 vs 스킵 (q 가 높을수록 완료)
    tutorial = rng.random() < sigmoid(0.9 * q + 0.4)
    if tutorial:
        emit("tap_tutorial_complete", install_dt, gap=(5, 30))

    # 푸시 권한 허용
    push = rng.random() < sigmoid(0.7 * q + 0.0)
    if push:
        emit("system_push_permission_granted", install_dt, gap=(2, 10))

    emit("page_view_home", install_dt, gap=(3, 15))

    # 분기 2) 홈에서 콘텐츠 조회 vs 내정보/설정으로 이탈
    went_content = rng.random() < sigmoid(1.0 * q + 0.3 + (0.4 if tutorial else 0.0))
    content_cnt = like_cnt = search_cnt = share_cnt = profile_cnt = settings_cnt = 0

    if went_content:
        n_content = 1 + int(rng.poisson(max(0.2, np.exp(0.2 + 0.5 * q))))
        n_content = min(n_content, 8)
        for _ in range(n_content):
            emit("page_view_content_detail", install_dt, count=int(rng.integers(1, 4)), gap=(8, 60))
            content_cnt += 1
            # 분기 3) 콘텐츠를 보고 좋아요 (q 높을수록)
            if rng.random() < sigmoid(0.8 * q + 0.0):
                emit("tap_like_button", install_dt, gap=(2, 8))
                like_cnt += 1
            if rng.random() < sigmoid(-1.2 + 0.4 * q):
                emit("tap_share_button", install_dt, gap=(3, 12))
                share_cnt += 1

        # 검색: 수행 비중은 낮지만(드물게), 한번 쓰는 유저는 여러 번 쓴다 → 평균 횟수↑
        if rng.random() < sigmoid(-1.4 + 0.8 * q):
            n_search = min(1 + int(rng.poisson(max(0.1, np.exp(0.3 + 0.7 * q)))), 6)
            for _ in range(n_search):
                emit("tap_search_button", install_dt, count=int(rng.integers(1, 3)), gap=(5, 30))
                search_cnt += 1
    else:
        if rng.random() < 0.5:
            emit("page_view_profile", install_dt, gap=(3, 15))
            profile_cnt += 1
        else:
            emit("page_view_settings", install_dt, gap=(3, 15))
            settings_cnt += 1

    # 에러 팝업: q 낮을수록 자주
    n_err = min(int(rng.poisson(max(0.02, np.exp(-0.5 - 0.7 * q)))), 3)
    for _ in range(n_err):
        emit("view_error_popup", install_dt, gap=(5, 40))

    session_duration = clock["t"]  # 첫 이벤트가 t>0 부터 시작하므로 사실상 세션 길이

    # --- 잔존 확률: 행동 피처·흐름 분기의 함수로 직접 구성 (심어둔 진실) ----
    detoured = (profile_cnt + settings_cnt) > 0
    logit = (
        -1.7
        + 0.6 * q
        + 0.9 * tutorial
        + 0.5 * push
        + 0.18 * min(content_cnt, 8)
        + 0.6 * (session_duration >= 150)     # 임계 효과
        + 0.5 * (like_cnt >= 3)               # 임계 효과
        + 0.35 * went_content
        - 0.45 * detoured
        - 0.5 * n_err
        + 0.15 * search_cnt
    )
    p7 = sigmoid(logit)
    d7_retained = rng.random() < p7
    # D1 잔존은 D7보다 너그럽게 (D7에 남았다면 D1에도 남았다고 둠)
    d1_retained = bool(d7_retained or (rng.random() < sigmoid(logit + 1.2)))

    # --- 복귀 활동 찍기 (2.5.2의 D7 라벨링이 활동으로 잔존을 탐지) ---------
    if d1_retained:
        d1_dt = pd.Timestamp(install_dt.date()) + pd.Timedelta(days=1, hours=int(rng.integers(8, 22)))
        clock["t"] = 0
        emit("page_view_home", d1_dt, gap=(2, 10))
        for _ in range(1 + int(rng.poisson(0.8))):
            emit("page_view_content_detail", d1_dt, count=int(rng.integers(1, 4)), gap=(8, 50))

    if d7_retained:
        d7_dt = pd.Timestamp(install_dt.date()) + pd.Timedelta(days=7, hours=int(rng.integers(8, 22)))
        clock["t"] = 0
        emit("page_view_home", d7_dt, gap=(2, 10))
        emit("page_view_content_detail", d7_dt, count=int(rng.integers(1, 4)), gap=(8, 50))

    return d7_retained, d1_retained, session_duration


def main():
    rng = np.random.default_rng(SEED)

    # 유저별 잠재 품질값과 설치 시각
    qs = rng.normal(0.0, 1.0, size=N_USERS)
    install_day_offsets = rng.integers(0, INSTALL_DAYS, size=N_USERS)

    rows = []
    n_d7 = 0
    for uid in range(N_USERS):
        install_dt = (
            BASE_DATE
            + pd.Timedelta(days=int(install_day_offsets[uid]))
            + pd.Timedelta(seconds=int(rng.integers(0, 6 * 3600)))  # 설치 시각(아침~한낮)
        )
        d7, _d1, _dur = simulate_user(f"u{uid:06d}", qs[uid], install_dt, rng, rows)
        n_d7 += int(d7)

    df = pd.DataFrame(
        rows,
        columns=[
            "event_timestamp",
            "event_date",
            "user_id",
            "event_name",
            "screen_name",
            "event_count",
            "description",
        ],
    )
    df = df.sort_values(["user_id", "event_timestamp"]).reset_index(drop=True)

    out_dir = os.path.join(os.path.dirname(__file__), "data")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "event_log.csv")
    df.to_csv(out_path, index=False)

    print(f"생성 완료: {out_path}")
    print(f"  유저 수      = {N_USERS:,}")
    print(f"  이벤트 행 수 = {len(df):,}")
    print(f"  D7 잔존율    = {n_d7 / N_USERS:.1%}")


if __name__ == "__main__":
    main()
