-- 신규 유저 리텐션 커브 (실습 1 입력용)
--
-- 예시 CSV(data/active_daily.csv)를 DuckDB 로 읽어 리텐션 커브를 구한다.
-- 핵심 패턴: 설치 코호트(installs)와 전체 활동(base)을 같은 user_id 로
-- self-join 하여 day_diff(설치 후 경과일) 별 잔존율을 구한다.
--
-- 단독 실행: 앞의 두 CREATE VIEW(base·installs)를 먼저 실행한 뒤 본 쿼리를 실행한다
-- (노트북 실습 1의 두 셀과 동일).

CREATE VIEW base AS
  SELECT date AS event_date, user_id, platform, install_flag
  FROM read_csv_auto('data/active_daily.csv');

-- 설치(=신규 유입) 이벤트만 추린다. basis_month 는 월별 코호트 버킷
CREATE VIEW installs AS
  SELECT event_date AS install_date, user_id, platform,
         DATE_TRUNC('month', event_date) AS basis_month
  FROM base
  WHERE install_flag = TRUE;

-- 설치 유저(i)와 그 유저의 이후 방문(b)을 self-join -> 설치 후 day_diff 별 재방문 수
WITH daily_stat AS (
  SELECT i.basis_month, i.platform, i.install_date,
         DATE_DIFF('day', i.install_date, b.event_date) AS day_diff,
         COUNT(*) AS retained_users
  FROM installs AS i
  JOIN base AS b
    ON i.user_id = b.user_id AND b.event_date > i.install_date
  WHERE DATE_DIFF('day', i.install_date, b.event_date) BETWEEN 1 AND 28
  GROUP BY 1, 2, 3, 4
),
-- 코호트(설치일·플랫폼) 별 모수: 설치 유저 수
population AS (
  SELECT basis_month, platform, install_date, COUNT(DISTINCT user_id) AS total_user
  FROM installs
  GROUP BY 1, 2, 3
)
-- 코호트별 (잔존 수 / 모수)를 day_diff·플랫폼 기준으로 평균내어 리텐션 커브를 만든다
SELECT d.basis_month, d.platform, d.day_diff,
       AVG(d.retained_users / p.total_user) AS avg_retention
FROM daily_stat AS d
JOIN population AS p USING (basis_month, platform, install_date)
GROUP BY 1, 2, 3
ORDER BY 2, 1, 3;
