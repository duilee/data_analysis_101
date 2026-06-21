-- 유저별 주중 사용 피처 추출 (실습 0 입력용)
--
-- 일별 알람 로그(alarm_daily)를 유저 단위로 집계한다. 도메인 특성이 그대로 녹아 있다:
--   · 주중(월~금)만 사용 (주중/주말 패턴이 극명히 다르므로)
--   · 기간 평균을 써서 하루치 노이즈를 누른다
--   · 알람 개수·인터벌·기상 시간·미션 등 한 단계 더 내려간 피처
--   · 클러스터 입력용으로 극단값을 클리핑한 _cluster 버전을 따로 둔다
-- (알람 시각은 분(0~1439) 정수로 표현)

WITH daily_stat AS (
  SELECT local_date, user_id, scheduled_cnt,
         (last_scheduled_min - first_scheduled_min) / NULLIF(scheduled_cnt - 1, 0) AS avg_interval,
         snooze_alarm_cnt      / scheduled_cnt AS avg_snooze,
         mission_used_cnt      / scheduled_cnt AS used_mission_per_alarm,
         mission_attempt_cnt   / scheduled_cnt AS mission_attempt_per_alarm,
         total_time_to_dismiss / scheduled_cnt AS avg_time_to_dismiss,
         first_ring_to_last_dismiss
  FROM read_csv_auto('data/alarm_daily.csv')
  WHERE isodow(CAST(local_date AS DATE)) BETWEEN 1 AND 5   -- 주중(월~금); DuckDB isodow Mon=1
    AND scheduled_cnt > 0
    AND first_ring_to_last_dismiss > 0
),

user_features AS (
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
       -- 클러스터 입력용: 극단값 클리핑 버전
       CASE WHEN scheduled_cnt > 10 THEN 11 ELSE scheduled_cnt END                  AS scheduled_cnt_cluster,
       CASE WHEN avg_interval > 60 THEN 65 ELSE avg_interval END                    AS avg_interval_cluster,
       CASE WHEN avg_snooze > 10 THEN 11 ELSE avg_snooze END                        AS avg_snooze_cluster,
       CASE WHEN used_mission_per_alarm > 10 THEN 11 ELSE used_mission_per_alarm END         AS used_mission_cluster,
       CASE WHEN mission_attempt_per_alarm > 10 THEN 11 ELSE mission_attempt_per_alarm END   AS mission_attempt_cluster,
       CASE WHEN avg_time_to_dismiss > 120 THEN 125 ELSE avg_time_to_dismiss END    AS avg_time_to_dismiss_cluster,
       CASE WHEN first_ring_to_last_dismiss > 120 THEN 125
            ELSE first_ring_to_last_dismiss END                                     AS first_ring_to_last_dismiss_cluster
FROM user_features AS u
LEFT JOIN read_csv_auto('data/user_master.csv') AS m USING (user_id)
ORDER BY user_id;
