-- 세그먼트 전이 기반 비율 지표 5종 (HURR / CURR / Heavy Loss / Light Loss / Reactivation)
-- 노트북에서는 core = ('heavy', 'light') 를 파이썬 문자열 상수로 끼워 넣는다.
-- 분모가 0이 되는 경우를 막기 위해 nullif(..., 0) 으로 감싼다.

SELECT
  round(count_if(user_seg_from = 'heavy' AND user_seg = 'heavy')
    / nullif(count_if(user_seg_from = 'heavy'), 0) * 100, 1) AS hurr_pct,
  round(count_if(user_seg_from IN ('heavy', 'light') AND user_seg IN ('heavy', 'light'))
    / nullif(count_if(user_seg_from IN ('heavy', 'light')), 0) * 100, 1) AS curr_pct,
  round(count_if(user_seg_from = 'heavy' AND user_seg = 'light')
    / nullif(count_if(user_seg_from = 'heavy'), 0) * 100, 1) AS heavy_loss_pct,
  round(count_if(user_seg_from = 'light' AND user_seg = 'risk')
    / nullif(count_if(user_seg_from = 'light'), 0) * 100, 1) AS light_loss_pct,
  round(count_if(user_seg_from = 'risk' AND user_seg = 'light')
    / nullif(count_if(user_seg_from = 'risk'), 0) * 100, 1) AS reactivation_pct
FROM mart_user_segment
WHERE target_date = DATE '2026-05-20';
