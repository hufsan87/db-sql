--[HX, 신협 상태변경 배치 프로시저 생성]
CREATE OR REPLACE PROCEDURE P_BEN_MTH_SHFUND_BATCH IS
  -- OUT 파라미터를 받을 변수들
  v_sqlcode           VARCHAR2(10);
  v_sqlerrm           VARCHAR2(4000);
  v_cnt               VARCHAR2(10);
  -- PAY_ACTION_CD 를 조회할 변수
  v_pay_action_cd     TCPN201.PAY_ACTION_CD%TYPE;
BEGIN
  --test
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