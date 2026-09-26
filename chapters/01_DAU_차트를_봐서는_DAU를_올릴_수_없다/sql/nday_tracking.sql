-- N일 후 세그먼트 변화 추적: 30일 전 heavy 였던 유저가 오늘은 어디에 있는가
-- mart_user_segment 가 여러 날짜에 걸쳐 적재돼 있어야 한다 (노트북 실습 4의 적재 루프 참고).
-- (past.user_seg = 'new' 로 바꾸면 30일 전 가입 첫 주를 보내던 유저의 안착 패턴을 볼 수 있다)

SELECT
  past.user_seg AS seg_30days_ago,
  curr.user_seg AS seg_today,
  count(*) AS users,
  round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM mart_user_segment AS past
LEFT JOIN mart_user_segment AS curr
  ON past.user_id = curr.user_id
 AND curr.target_date = DATE '2026-05-20'
WHERE past.target_date = DATE '2026-05-20' - INTERVAL 30 DAY
  AND past.user_seg = 'heavy'
GROUP BY past.user_seg, curr.user_seg
ORDER BY users DESC;
