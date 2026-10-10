-- 2.5.2) EDA로 선행지표 후보 찾기
-- 신규 설치(D0) 유저를 D7 잔존/비잔존으로 라벨링하고, D0~D1 구간 행동의
-- 발생 비중(share)과 평균 횟수(avg_event_count)를 코호트별로 비교한다.
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

WITH log_data AS (   -- raw 로그를 (유저, 이벤트, 화면, 일자) 단위 발생 횟수로 집계
    SELECT event_date, event_name, screen_name, user_id,
           SUM(event_count) AS event_count, MAX(description) AS description
    FROM event_log
    GROUP BY 1, 2, 3, 4
),
event_stat AS (      -- 코호트(잔존/비잔존)별 D0~D1 구간 행동: 한 유저 수와 평균 횟수
    SELECT r.d7_retention_flag, l.event_name, l.screen_name,
           COUNT(DISTINCT r.user_id) AS user_cnt, AVG(l.event_count) AS avg_event_count
    FROM d7_label AS r
    LEFT JOIN log_data AS l
      ON r.user_id = l.user_id AND l.event_date >= r.install_date
     AND date_diff('day', r.install_date, l.event_date) <= 1
    GROUP BY 1, 2, 3
),
population AS (SELECT d7_retention_flag, COUNT(*) AS total_user_cnt FROM d7_label GROUP BY 1),
cohort_info AS (     -- 코호트 안에서 그 행동을 한 유저 비중(%)
    SELECT e.*, (e.user_cnt * 1.0 / p.total_user_cnt) * 100 AS share
    FROM event_stat AS e LEFT JOIN population AS p USING (d7_retention_flag)
)
SELECT event_name, screen_name,
       MAX(CASE WHEN d7_retention_flag = 0 THEN share           END) AS d7_ret0_share,
       MAX(CASE WHEN d7_retention_flag = 0 THEN avg_event_count END) AS d7_ret0_avg_cnt,
       MAX(CASE WHEN d7_retention_flag = 1 THEN share           END) AS d7_ret1_share,
       MAX(CASE WHEN d7_retention_flag = 1 THEN avg_event_count END) AS d7_ret1_avg_cnt,
       d7_ret1_share - d7_ret0_share     AS share_diff,
       d7_ret1_avg_cnt - d7_ret0_avg_cnt AS event_cnt_diff
FROM cohort_info
WHERE event_name IS NOT NULL
GROUP BY 1, 2
HAVING d7_ret1_share >= 10 OR d7_ret0_share >= 10
ORDER BY share_diff DESC;
