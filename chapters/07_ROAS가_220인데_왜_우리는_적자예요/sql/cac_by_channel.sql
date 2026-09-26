-- 채널별 CAC: 매체비 기준 vs fully-loaded (2025-04)
-- 오가닉은 비용 행이 없어 조인에서 자연스럽게 빠진다 (paid 기준 계산)
SELECT c.channel
     , u.new_users
     , ROUND(c.media_cost_krw / u.new_users) AS cac_media
     , ROUND((c.media_cost_krw + c.other_cost_krw)
             / u.new_users) AS cac_fully_loaded
FROM marketing_costs c
JOIN (
    SELECT channel, COUNT(*) AS new_users
    FROM users
    WHERE date_trunc('month', signup_date) = DATE '2025-04-01'
    GROUP BY channel
) u USING (channel)
WHERE c.month = DATE '2025-04-01'
ORDER BY u.new_users DESC;
