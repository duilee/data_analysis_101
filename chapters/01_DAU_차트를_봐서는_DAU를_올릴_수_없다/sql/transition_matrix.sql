-- 세그먼트 전이 (Flow): 어제(user_seg_from) -> 오늘(user_seg)
-- build_mart.sql 로 mart_user_segment 를 먼저 만들어 두어야 한다.

SELECT user_seg_from, user_seg, count(*) AS users
FROM mart_user_segment
WHERE target_date = DATE '2026-05-20'
  AND user_seg_from IS NOT NULL   -- 오늘 처음 가입한 유저(어제 NULL)는 제외
GROUP BY user_seg_from, user_seg;
