-- 세그먼트 분류 매크로 (실습 2 준비)
--
-- 실습 1의 분류 CASE를 기준일(ref_date)을 인자로 받는 매크로로 정의한다.
-- build_mart.sql 이 오늘/어제 두 시점에 이 매크로를 재사용한다.
-- 기준일보다 뒤에 가입한 유저(days < 0)는 그 시점에 존재하지 않았으므로 NULL.
-- 임계값(new 윈도·heavy 컷·경계일)을 바꿀 때는 실습 1의 분류 CASE(classify_segment.sql)와
-- 이 매크로 두 곳을 똑같이 고친다.

CREATE OR REPLACE MACRO classify_seg(days, cnt, last_active, ref_date) AS
  CASE
    WHEN days < 0                          THEN NULL
    WHEN days < 7                          THEN 'new'
    WHEN cnt >= 5                          THEN 'heavy'
    WHEN cnt BETWEEN 1 AND 4               THEN 'light'
    -- cnt = 0 이면 최근 7일 기록이 없으므로 risk/dormant 는 마지막 기록일로만 가른다.
    WHEN last_active >= ref_date - INTERVAL 30 DAY THEN 'risk'
    ELSE 'dormant'
  END;
