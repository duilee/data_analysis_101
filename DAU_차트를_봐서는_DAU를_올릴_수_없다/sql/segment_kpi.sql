-- 세그먼트 전이 기반 비율 지표 5종
--   HURR        : heavy(활성+비활성)를 유지하는 비율
--   CURR        : heavy+light(핵심 활동 유저층)를 유지하는 비율
--   Heavy Loss  : heavy 유저가 light 로 떨어진 비율
--   Light Loss  : light 유저가 위험 구간(risk)으로 이탈한 비율
--   Reactivation: 위험(risk) 유저가 다시 light 로 돌아온 비율
--
-- heavy = {heavy_active, heavy_inactive}, light = {light_active, light_inactive}
-- 0 으로 나누는 것을 막기 위해 분모를 nullif(..., 0) 으로 감싼다.

SELECT
  round(count_if(user_seg_from IN ('heavy_active', 'heavy_inactive')
                 AND user_seg  IN ('heavy_active', 'heavy_inactive'))
        / nullif(count_if(user_seg_from IN ('heavy_active', 'heavy_inactive')), 0) * 100, 1) AS hurr_pct,

  round(count_if(user_seg_from IN ('heavy_active', 'heavy_inactive', 'light_active', 'light_inactive')
                 AND user_seg  IN ('heavy_active', 'heavy_inactive', 'light_active', 'light_inactive'))
        / nullif(count_if(user_seg_from IN ('heavy_active', 'heavy_inactive', 'light_active', 'light_inactive')), 0) * 100, 1) AS curr_pct,

  round(count_if(user_seg_from IN ('heavy_active', 'heavy_inactive')
                 AND user_seg  IN ('light_active', 'light_inactive'))
        / nullif(count_if(user_seg_from IN ('heavy_active', 'heavy_inactive')), 0) * 100, 1) AS heavy_loss_pct,

  round(count_if(user_seg_from IN ('light_active', 'light_inactive') AND user_seg = 'risk')
        / nullif(count_if(user_seg_from IN ('light_active', 'light_inactive')), 0) * 100, 1) AS light_loss_pct,

  round(count_if(user_seg_from = 'risk' AND user_seg IN ('light_active', 'light_inactive'))
        / nullif(count_if(user_seg_from = 'risk'), 0) * 100, 1) AS reactivation_pct
FROM mart_user_segment
WHERE target_date = DATE '2026-05-20';
