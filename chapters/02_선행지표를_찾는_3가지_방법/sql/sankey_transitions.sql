-- 2.5.4) 설치 세션 스텝 전이 + 전이별 D7 잔존율 (Sankey 입력)
-- 노트북의 CONFIG 상수는 값으로 전개: MAX_STEPS=10, TOP_K=6, MIN_USERS=20
--
-- 전제: event_log 테이블이 등록돼 있어야 한다 (노트북 준비 셀과 동일):
--   CREATE OR REPLACE TABLE event_log AS SELECT * FROM read_csv_auto('data/event_log.csv');
-- 아래 공용 뷰(installs·d7_label)는 2.5.2~2.5.4 sql 파일마다 같은 정의를 반복해 두어 어느 파일이든 단독 실행된다.

-- 설치(D0) 시점: 유저별 첫 system_app_install
CREATE OR REPLACE VIEW installs AS
  SELECT user_id, MIN(event_timestamp) AS install_ts, MIN(event_date) AS install_date
  FROM event_log WHERE event_name = 'system_app_install' GROUP BY 1;

-- D7 잔존 라벨: 설치 7일째에 활동이 있으면 1. 2.5.2~2.5.4가 모두 이 뷰를 쓴다
CREATE OR REPLACE VIEW d7_label AS
  SELECT i.user_id, i.install_ts, i.install_date,
         MAX(CASE WHEN date_diff('day', i.install_date, e.event_date) = 7 THEN 1 ELSE 0 END) AS d7_retention_flag
  FROM installs AS i LEFT JOIN event_log AS e ON i.user_id = e.user_id
  GROUP BY 1, 2, 3;

-- 설치 후 1시간 안의 이벤트를 순서대로 (연속 중복 제거) → 유저별 스텝 번호
CREATE OR REPLACE VIEW user_steps AS
  WITH session_events AS (
    SELECT i.user_id, e.event_name, e.event_timestamp,
           LAG(e.event_name) OVER (PARTITION BY i.user_id ORDER BY e.event_timestamp) AS prev_event
    FROM installs AS i
    JOIN event_log AS e
      ON i.user_id = e.user_id
     AND e.event_timestamp >= i.install_ts
     AND e.event_timestamp <= i.install_ts + INTERVAL 1 HOUR
  )
  SELECT user_id, event_name, event_timestamp,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_timestamp) AS step_num
  FROM session_events
  WHERE prev_event IS NULL OR event_name != prev_event
  QUALIFY step_num <= 10;

WITH event_volume AS (   -- 스텝별 이벤트 빈도 순위
    SELECT step_num, event_name, COUNT(DISTINCT user_id) AS user_cnt,
           ROW_NUMBER() OVER (PARTITION BY step_num ORDER BY COUNT(DISTINCT user_id) DESC) AS rnk
    FROM user_steps
    GROUP BY 1, 2
),
steps_resolved AS (     -- 상위 K 밖 이벤트는 ETC 로 묶기
    SELECT s.user_id, s.step_num,
           CASE WHEN v.rnk <= 6 THEN s.event_name ELSE 'ETC' END AS event_name
    FROM user_steps AS s JOIN event_volume AS v USING (step_num, event_name)
),
transitions AS (        -- 스텝 N -> N+1 전이
    SELECT a.user_id, a.step_num AS from_step,
           CAST(a.step_num AS VARCHAR) || '-' || a.event_name AS source,
           CAST(b.step_num AS VARCHAR) || '-' || b.event_name AS target
    FROM steps_resolved AS a
    JOIN steps_resolved AS b ON a.user_id = b.user_id AND b.step_num = a.step_num + 1
)
SELECT t.from_step, t.source, t.target,
       COUNT(DISTINCT t.user_id) AS user_count,
       COUNT(DISTINCT CASE WHEN r.d7_retention_flag = 1 THEN t.user_id END) * 100.0
         / NULLIF(COUNT(DISTINCT t.user_id), 0) AS d7_retention
FROM transitions AS t LEFT JOIN d7_label AS r USING (user_id)
GROUP BY 1, 2, 3
HAVING COUNT(DISTINCT t.user_id) >= 20
ORDER BY from_step, user_count DESC;
