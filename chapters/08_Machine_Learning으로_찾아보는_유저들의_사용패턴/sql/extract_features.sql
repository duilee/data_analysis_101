-- 유저별 주중 사용 피처 추출 (실습 0 입력용)
--
-- 일별 알람 로그(alarm_daily)를 유저 단위로 집계한다. 도메인 특성이 그대로 녹아 있다:
--   · 주중(월~금)만 사용 (주중/주말 패턴이 극명히 다르므로)
--   · 기간 평균을 써서 하루치 노이즈를 누른다
--   · 알람 개수·인터벌·기상 시간·미션 등 한 단계 더 내려간 피처
--   · 클러스터 입력용으로 극단값을 클리핑한 _cluster 버전을 따로 둔다 (clip 매크로)
-- (알람 시각은 분(0~1439) 정수로 표현)
--
-- 단독 실행: 앞의 CREATE MACRO·CREATE VIEW 를 먼저 실행한 뒤 본 쿼리를 실행한다
-- (노트북 실습 0의 두 셀과 동일).

CREATE OR REPLACE MACRO clip(x, lim, cap) AS CASE WHEN x > lim THEN cap ELSE x END;  -- 극단값 클리핑

-- 일별 알람 로그 → 하루 단위 파생 지표. 주중(월~금)만 쓴다 (주중/주말 패턴이 극명히 다르므로)
CREATE OR REPLACE VIEW daily_stat AS
  SELECT local_date, user_id, scheduled_cnt,
         (last_scheduled_min - first_scheduled_min) / NULLIF(scheduled_cnt - 1, 0) AS avg_interval,
         snooze_alarm_cnt      / scheduled_cnt AS avg_snooze,
         mission_used_cnt      / scheduled_cnt AS used_mission_per_alarm,
         mission_attempt_cnt   / scheduled_cnt AS mission_attempt_per_alarm,
         total_time_to_dismiss / scheduled_cnt AS avg_time_to_dismiss,
         first_ring_to_last_dismiss
  FROM read_csv_auto('data/alarm_daily.csv')
  WHERE isodow(CAST(local_date AS DATE)) BETWEEN 1 AND 5   -- DuckDB isodow: Mon=1
    AND scheduled_cnt > 0
    AND first_ring_to_last_dismiss > 0;

WITH user_features AS (   -- 기간 평균으로 하루치 노이즈를 누른다
  SELECT user_id,
         AVG(scheduled_cnt)                AS scheduled_cnt,
         AVG(COALESCE(avg_interval, 0))    AS avg_interval,
         AVG(avg_snooze)                   AS avg_snooze,
         AVG(used_mission_per_alarm)       AS used_mission_per_alarm,
         AVG(mission_attempt_per_alarm)    AS mission_attempt_per_alarm,
         AVG(avg_time_to_dismiss)          AS avg_time_to_dismiss,
         AVG(first_ring_to_last_dismiss)   AS first_ring_to_last_dismiss
  FROM daily_stat
  GROUP BY user_id
)
SELECT m.new_flag, m.retained_d7, u.*,
       -- 클러스터 입력용: 극단값 클리핑 버전 — clip(값, 상한, 대체값)
       clip(scheduled_cnt, 10, 11)                AS scheduled_cnt_cluster,
       clip(avg_interval, 60, 65)                 AS avg_interval_cluster,
       clip(avg_snooze, 10, 11)                   AS avg_snooze_cluster,
       clip(used_mission_per_alarm, 10, 11)       AS used_mission_cluster,
       clip(mission_attempt_per_alarm, 10, 11)    AS mission_attempt_cluster,
       clip(avg_time_to_dismiss, 120, 125)        AS avg_time_to_dismiss_cluster,
       clip(first_ring_to_last_dismiss, 120, 125) AS first_ring_to_last_dismiss_cluster
FROM user_features AS u
LEFT JOIN read_csv_auto('data/user_master.csv') AS m USING (user_id)
ORDER BY user_id;
