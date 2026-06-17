-- N일 후 세그먼트 변화 추적: 30일 전 heavy_active 였던 유저가 오늘은 어디에 있는가
--
-- 1일 단위 전이는 변화 폭이 작아 패턴이 잘 안 보이지만, 시간 축을 길게 잡으면
-- 누적된 이동이 또렷하게 드러난다. mart_user_segment 가 여러 날짜에 걸쳐
-- 적재돼 있다는 전제 하에, 두 시점(과거·오늘)을 user_id 로 self-join 한다.
-- (past.user_seg 를 'new' 로 바꾸면 신규 유저의 N일 안착 패턴을 볼 수 있다.)

SELECT
  past.user_seg AS seg_30days_ago,
  curr.user_seg AS seg_today,
  count(*) AS users,
  round(count(*) / sum(count(*)) OVER () * 100, 1) AS pct
FROM mart_user_segment AS past
LEFT JOIN mart_user_segment AS curr
  ON past.user_id = curr.user_id
 AND curr.target_date = DATE '2026-05-20'
WHERE past.target_date = DATE '2026-05-20' - INTERVAL 30 DAY
  AND past.user_seg = 'heavy_active'
GROUP BY 1, 2
ORDER BY users DESC;
