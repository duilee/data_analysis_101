"""부록: 택소노미 문서 규칙 검사 + 문서 vs 로그 대조 (본문 6.1절). extra/ 폴더 안에서 실행: python taxonomy_check.py"""
import re, json, pandas as pd, duckdb
pd.set_option("display.width", 200); pd.set_option("display.max_colwidth", 60)
events = pd.read_csv("../data/taxonomy_events.csv").fillna("")
props  = pd.read_csv("../data/taxonomy_properties.csv").fillna("")
log    = pd.read_csv("../data/event_log.csv")
def show(title, df): print(f"\n### {title}\n"); print(df.to_markdown(index=False))

show("0. taxonomy_events (head)", events.head(6))
show("0. taxonomy_properties (head)", props.head(5)[["property_name","scope","data_type","allowed_values","description"]])
show("0. event_log (head)", log.head(4))

# ---------- 1. 이름·타입 규칙 검사 ----------
PREFIXES = ("page_view_", "tap_", "view_", "system_")
PAST_TENSE = re.compile(r"_(started|renewed|cancelled|granted|sent|completed|failed)$")
def event_issues(r):
    n = r.event_name; out = []
    if not (n.startswith(PREFIXES) or PAST_TENSE.search(n)): out.append("접두어 없음")
    if n != n.lower() or not re.fullmatch(r"[a-z0-9_]+", n): out.append("snake_case 아님")
    if r.description.strip() == "": out.append("설명 없음")
    return out
ev_v = events.assign(issues=events.apply(event_issues, axis=1)).query("issues.str.len() > 0")
ev_v = ev_v.assign(issues=ev_v.issues.str.join(", "))[["event_name","event_type","platform","issues"]]
show("1a. 이벤트 이름 규칙 위반", ev_v)

def prop_issues(r):
    out = []
    if r.data_type == "enum" and r.allowed_values == "": out.append("enum인데 허용값 없음")
    n_ev = len([e for e in r.events.split("|") if e])
    if r.scope == "event" and n_ev >= 0.8 * len(events): out.append(f"이벤트 {n_ev}개에 붙음 → 유저 프로퍼티 후보")
    return out
pr_v = props.assign(issues=props.apply(prop_issues, axis=1)).query("issues.str.len() > 0")
pr_v = pr_v.assign(issues=pr_v.issues.str.join(", "))[["property_name","scope","data_type","issues"]]
show("1b. 프로퍼티 규칙 위반", pr_v)

def event_kind(n):
    for p, k in zip(PREFIXES, ("화면 진입","탭·클릭","노출","시스템")):
        if n.startswith(p): return k
    return "시스템" if PAST_TENSE.search(n) else "분류 불가"
kinds = events.assign(kind=events.event_name.map(event_kind)).groupby("kind").size().rename("events").reset_index()
show("1c. 접두어로 추론한 유형별 이벤트 수", kinds.sort_values("events", ascending=False))

# ---------- 2. 질문 커버리지 검사 ----------
NEEDS = {
  "온보딩 4단계 전환율": [("system_first_launch", None), ("page_view_onboarding_step", "step"), ("system_permission_granted", "permission")],
  "홈 배너 클릭률":       [("view_main_banner", "banner_id"), ("tap_main_banner", "banner_id")],
  "콘텐츠 카드 클릭률":   [("view_content_card", "position"), ("tap_content_card", "position")],
  "결제 화면 진입 경로별 전환": [("page_view_paywall", "source"), ("tap_purchase_button", "plan"), ("subscription_started", "plan")],
}
live = set(events.query("status == 'Live'").event_name)
prop_of = {r.property_name: set(r.events.split("|")) for r in props.itertuples()}
rows = []
for q, needs in NEEDS.items():
    for ev, pr in needs:
        ok_ev = ev in live; ok_pr = (pr is None) or (ev in prop_of.get(pr, set()))
        rows.append((q, ev, pr or "—", "O" if ok_ev else "X", "O" if ok_pr else "X"))
cov = pd.DataFrame(rows, columns=["질문","이벤트","프로퍼티","이벤트 있음","프로퍼티 붙어 있음"])
show("2. 질문 커버리지", cov)
verdict = cov.groupby("질문").apply(lambda g: "답 가능" if (g["이벤트 있음"].eq("O") & g["프로퍼티 붙어 있음"].eq("O")).all() else "답 불가").rename("판정").reset_index()
show("2b. 질문별 판정", verdict)

# ---------- 3. 문서 vs 로그 대조 (DuckDB) ----------
con = duckdb.connect()
con.execute("CREATE TABLE taxonomy_events AS SELECT * FROM read_csv_auto('../data/taxonomy_events.csv')")
con.execute("CREATE TABLE taxonomy_properties AS SELECT * FROM read_csv_auto('../data/taxonomy_properties.csv', all_varchar=true)")
con.execute("CREATE TABLE event_log AS SELECT * FROM read_csv_auto('../data/event_log.csv')")
con.execute("UPDATE taxonomy_properties SET allowed_values = coalesce(allowed_values, ''), events = coalesce(events, '')")
results = {}
for name in ["undocumented_events", "dead_events", "enum_drift", "platform_asymmetry"]:
    results[name] = con.execute(open(f"sql/{name}.sql").read()).df()
    show(f"3. {name}", results[name])

# ---------- 4. 변경 요청서 초안 ----------
req = []
for r in ev_v.itertuples():
    req.append(("Modify", r.event_name, f"이름 규칙: {r.issues}"))
for r in pr_v.itertuples():
    req.append(("Modify", r.property_name, r.issues))
for r in cov.query("`이벤트 있음` == 'X'").itertuples():
    req.append(("Add", r.이벤트, f"'{r.질문}'에 필요한 이벤트 없음"))
for r in results["undocumented_events"].itertuples():
    req.append(("Add", r.event_name, f"로그에만 존재 ({r.events:,}건) — 문서 등록 또는 제거"))
for r in results["dead_events"].itertuples():
    req.append(("Deprecate", r.event_name, "문서는 Live, 로그 0건"))
for r in results["enum_drift"].itertuples():
    req.append(("Modify", f"{r.property_name}={r.value}", f"허용값 밖 값 ({r.platform} {r.app_version}, {r.events:,}건)"))
for r in results["platform_asymmetry"].itertuples():
    req.append(("Modify", r.event_name, f"플랫폼 비대칭 (iOS {r.ios_users}, Android {r.android_users})"))
request = pd.DataFrame(req, columns=["변화 타입","대상","이유"]).drop_duplicates("대상")
show("4. 변경 요청서 초안", request)
print("\n요청서 행 수:", len(request), "| 타입별:", request["변화 타입"].value_counts().to_dict())
