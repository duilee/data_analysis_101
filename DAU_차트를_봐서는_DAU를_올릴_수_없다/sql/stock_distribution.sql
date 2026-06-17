-- 일별 세그먼트 분포 (Stock)
-- build_mart.sql 로 mart_user_segment 를 먼저 만들어 두어야 한다.

SELECT
  user_seg,
  count(*) AS users
FROM mart_user_segment
WHERE target_date = DATE '2026-05-20'
GROUP BY user_seg
ORDER BY array_position(
  ['new', 'heavy_active', 'light_active', 'heavy_inactive', 'light_inactive', 'risk', 'dormant'],
  user_seg);
