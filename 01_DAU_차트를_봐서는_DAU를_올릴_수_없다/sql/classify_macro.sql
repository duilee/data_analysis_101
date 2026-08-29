-- 세그먼트 분류 매크로 (실습 2 준비)
--
-- 실습 1의 분류 CASE를 기준일(ref_date)을 인자로 받는 매크로로 정의한다.
-- build_mart.sql 이 오늘/어제 두 시점에 이 매크로를 재사용한다.
-- 임계값(heavy 컷·경계일)을 바꿀 때는 실습 1의 분류 CASE(classify_segment.sql)와
-- 이 매크로 두 곳을 똑같이 고친다.

CREATE OR REPLACE MACRO classify_seg(is_newbie, d0_active, cnt, last_active, ref_date) AS
  CASE
    WHEN is_newbie                             THEN 'new'
    WHEN d0_active     AND cnt >= 5            THEN 'heavy_active'
    WHEN d0_active     AND cnt BETWEEN 1 AND 4 THEN 'light_active'
    WHEN NOT d0_active AND cnt >= 5            THEN 'heavy_inactive'
    WHEN NOT d0_active AND cnt BETWEEN 1 AND 4 THEN 'light_inactive'
    -- cnt = 0 이면 최근 7일 접속이 없으므로 risk/dormant 는 마지막 활동일로만 가른다.
    WHEN last_active >= ref_date - INTERVAL 30 DAY THEN 'risk'
    ELSE 'dormant'
  END;
