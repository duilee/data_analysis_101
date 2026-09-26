-- 일별 세그먼트 분포 (Stock)
-- build_mart.sql 로 mart_user_segment 를 먼저 만들어 두어야 한다.
-- (세그먼트 정렬은 노트북에서 pandas reindex 가 담당한다)

SELECT user_seg, count(*) AS users
FROM mart_user_segment
WHERE target_date = DATE '2026-05-20'
GROUP BY user_seg;
