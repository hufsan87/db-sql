--[사번별 발령사항 조회 (발령 기간 LAG처리)]
SELECT *
FROM (
  SELECT 
    A.ENTER_CD,
    A.SABUN,
    A.SDATE,
    
    -- 다음 상태 시작일 -1 → 현재 상태의 종료일로 간주
    NVL(TO_CHAR(
      TO_DATE((
        SELECT MIN(B.SDATE)
        FROM THRM151 B
        WHERE B.ENTER_CD = A.ENTER_CD
          AND B.SABUN = A.SABUN
          AND B.SDATE > A.SDATE
          AND B.STATUS_CD != A.STATUS_CD
      ), 'YYYYMMDD') - 1, 'YYYYMMDD'
    ), '99991231') AS EDATE2,

    A.EDATE,
    A.STATUS_CD,

    LAG(A.STATUS_CD) OVER (
      PARTITION BY A.ENTER_CD, A.SABUN 
      ORDER BY A.SDATE
    ) AS PREV_STATUS_CD

  FROM THRM151 A
  WHERE A.ENTER_CD = 'HX'
    AND A.SABUN = '20120026'
)
WHERE STATUS_CD != PREV_STATUS_CD OR PREV_STATUS_CD IS NULL
ORDER BY EDATE DESC;


--[HX, 신협 상태변경 배치 프로시저 생성]
CREATE OR REPLACE PROCEDURE P_BEN_MTH_SHFUND_BATCH IS
  -- OUT 파라미터를 받을 변수들
  v_sqlcode           VARCHAR2(10);
  v_sqlerrm           VARCHAR2(4000);
  v_cnt               VARCHAR2(10);
  -- PAY_ACTION_CD 를 조회할 변수
  v_pay_action_cd     TCPN201.PAY_ACTION_CD%TYPE;
BEGIN
  -- 1) PAY_ACTION_CD
  SELECT MIN(pay_action_cd)
    INTO v_pay_action_cd
    FROM tcpn201
   WHERE enter_cd       = 'HX'
     AND pay_cd          = 'A1'
     AND cal_tax_method  = 'B'
     AND pay_ym          = TO_CHAR(SYSDATE, 'YYYYMM');

  -- 2) P_BEN_PAY_DATA_CREATE 호출
  P_BEN_PAY_DATA_CREATE(
    P_SQLCODE           => v_sqlcode,
    P_SQLERRM           => v_sqlerrm,
    P_CNT               => v_cnt,
    P_ENTER_CD          => 'HX',
    P_BENEFIT_BIZ_CD    => '75',
    P_PAY_ACTION_CD     => v_pay_action_cd,
    P_BUSINESS_PLACE_CD => '1',
    P_CHKID             => 'BATCH'
  );

  -- 3) 결과 출력
  DBMS_OUTPUT.PUT_LINE(
    'P_BEN_PAY_DATA_CREATE completed. '
    || 'CODE=' || v_sqlcode
    || ', MSG='   || v_sqlerrm
    || ', CNT='   || v_cnt
  );
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(
      'Error in P_BEN_MTH_SHFUND_BATCH: ' || SQLERRM
    );
    RAISE;
END;
/


--[HX, 신협 상태변경 배치 등록]
--(JOB 등록)
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'BEN_MTH_SHFUND_BATCH',
    job_type        => 'STORED_PROCEDURE',
    job_action      => 'P_BEN_MTH_SHFUND_BATCH',
    -- 최초 실행 시점을 지정합니다. 
    -- (오늘이 4/25 이므로, 다음 5/21 17:10에 첫 실행)
    start_date      => TO_TIMESTAMP('2025-05-21 17:10:00', 'YYYY-MM-DD HH24:MI:SS'),
    -- 매월 21일 08:00에 반복
    repeat_interval => 'FREQ=MONTHLY;BYMONTHDAY=21;BYHOUR=8;BYMINUTE=0;BYSECOND=0',
    enabled         => TRUE,
    comments        => '월간 복리후생 배치: P_BEN_MTH_SHFUND_BATCH'
  );
END;
/

-- 5) 즉시 한 번 실행해 보고 싶으면
BEGIN
  DBMS_SCHEDULER.RUN_JOB(
    job_name            => 'BEN_MTH_SHFUND_BATCH',
    use_current_session => FALSE
  );
END;
/




--[배치 시작시간 변경 등]
BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'BEN_MTH_SHFUND_BATCH',
    attribute => 'start_date',
    value     => TO_TIMESTAMP('2025-04-28 15:00:00', 'YYYY-MM-DD HH24:MI:SS')
  );
END;
/

BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'BEN_MTH_SHFUND_BATCH',
    job_type        => 'STORED_PROCEDURE',
    job_action      => 'P_BEN_MTH_SHFUND_BATCH',
    -- 최초 실행 시점을 지정합니다. 
    -- (오늘이 4/25 이므로, 다음 5/21 08:00에 첫 실행)
    start_date      => TO_TIMESTAMP('2025-04-28 13:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    -- 매월 21일 08:00에 반복
    repeat_interval => 'FREQ=MONTHLY;BYMONTHDAY=21;BYHOUR=8;BYMINUTE=0;BYSECOND=0',
    enabled         => TRUE,
    comments        => '월간 복리후생 배치: P_BEN_MTH_SHFUND_BATCH'
  );
END;
/

-- 1) 먼저 잡을 일시적으로 비활성화
BEGIN
  DBMS_SCHEDULER.DISABLE(
    name => 'BEN_MTH_SHFUND_BATCH'
  );
END;
/

-- 2) 테스트할 새로운 START_DATE로 속성 변경
BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'BEN_MTH_SHFUND_BATCH',
    attribute => 'start_date',
    value     => TO_TIMESTAMP('2025-04-25 17:22:00', 'YYYY-MM-DD HH24:MI:SS')
  );
  -- (원한다면 repeat_interval도 짧은 간격으로 바꿔서 빠르게 여러 번 돌려볼 수 있습니다)
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'BEN_MTH_SHFUND_BATCH',
    attribute => 'repeat_interval',
    --value     => 'FREQ=MINUTELY;INTERVAL=5'
    value => 'FREQ=MONTHLY;BYMONTHDAY=21;BYHOUR=8;BYMINUTE=0;BYSECOND=0'
  );
END;
/

-- 3) 잡을 다시 활성화
BEGIN
  DBMS_SCHEDULER.ENABLE(
    name => 'BEN_MTH_SHFUND_BATCH'
  );
END;
/

-- 4) 다음 실행 시간 확인
SELECT job_name, next_run_date
  FROM user_scheduler_jobs
 WHERE job_name = 'BEN_MTH_SHFUND_BATCH';

-- 5) 즉시 한 번 실행해 보고 싶으면
BEGIN
  DBMS_SCHEDULER.RUN_JOB(
    job_name            => 'BEN_MTH_SHFUND_BATCH',
    use_current_session => FALSE
  );
END;
/


--[급여반영자, 지급상태 P가 아닌 사번 조회]
SELECT A.ENTER_CD,count(distinct A.sabun) cnt
FROM TBEN632 A
WHERE 1=1
AND A.PAY_YM=(
  SELECT SUBSTR(MIN(pay_action_cd),1,6)
    FROM tcpn201
   WHERE enter_cd       = A.ENTER_CD
     AND pay_cd          = 'A1'
     AND cal_tax_method  = 'B'
     AND pay_ym          = TO_CHAR(SYSDATE, 'YYYYMM')
)
AND (A.COM_AMT IS NOT NULL OR A.COM_AMT = 0)
AND A.SABUN not IN (SELECT B.SABUN FROM TBEN631 B
            WHERE B.PAY_STS='P'
            AND B.ENTER_CD=A.ENTER_CD)
GROUP BY A.ENTER_CD;