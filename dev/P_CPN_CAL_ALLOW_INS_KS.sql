create or replace PROCEDURE             "P_CPN_CAL_ALLOW_INS_KS" (
         P_SQLCODE            OUT VARCHAR2,  -- Error Code
         P_SQLERRM            OUT VARCHAR2,  -- Error Messages
         P_ENTER_CD           IN  VARCHAR2,  -- 회사코드
         P_PAY_ACTION_CD      IN  VARCHAR2,  -- 급여계산코드
         P_BUSINESS_PLACE_CD  IN  VARCHAR2,  -- 급여사업장코드
         P_CPN201             IN  TCPN201%ROWTYPE, -- 급여계산일자정보
         P_SABUN              IN  VARCHAR2,  -- 대상자 사원번호
         P_CHKID              IN  VARCHAR2   -- 수정자
         )
IS
/********************************************************************************/
/*                    (c) Copyright ISU System Inc. 2004                        */
/*                           All Rights Reserved                                */
/********************************************************************************/
/*  PROCEDURE NAME : P_CPN_CAL_ALLOW_INS_KS                                     */
/*                   [한국공항]수당발령자료 기초자료 생성                           */
/********************************************************************************/
/*  [ 참조 TABLE ]                                                              */
/*              개인별수당관리(한국공항) ( TCPN429 )                               */
/********************************************************************************/
/*  [ 생성 TABLE ]                                                              */
/*               개인별_급여수당관리(한국공항) ( TCPN431 ) 생성                     */
/********************************************************************************/
/*  [ 삭제 TABLE ]                                                              */
/*               개인별_급여수당관리(한국공항) ( TCPN431 )                         */
/********************************************************************************/
/*  [ PRC 개요 ]                                                                */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 호출 ]                                                                */
/*       [ P_CPN_CAL_PAY_MAIN ]                                                */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/*------------------------------------------------------------------------------*/
/* 2023-05-03  C.Y.G           Initial Release                                  */
/********************************************************************************/
   --------- Local 변수 선언 -------------
   lv_cpn051       TCPN051%ROWTYPE;
   lv_sdate        VARCHAR2(08); -- 해당월 시작일
   lv_edate        VARCHAR2(08); -- 해당월 말일
   ln_tot_cnt      NUMBER; -- 해당월 총일수

   lv_biz_cd       TSYS903.BIZ_CD%TYPE := 'CPN';
   lv_object_nm    TSYS903.OBJECT_NM%TYPE := 'P_CPN_CAL_ALLOW_INS_KS';

   /* 계산 대상자 가져오기
   */
   CURSOR CSR_EMP IS
      SELECT A.*
        FROM TCPN203 A
       WHERE A.ENTER_CD      = P_ENTER_CD
         AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
         AND A.PAY_PEOPLE_STATUS IN ('P','M','PM') -- 급여대상자상태(C00125)-> 'P':작업대상,'M':Mark For Retry
         AND DECODE(P_SABUN,NULL,'%',A.SABUN) = DECODE(P_SABUN,NULL,'%',P_SABUN)
         AND DECODE(P_BUSINESS_PLACE_CD,NULL,'%',A.BUSINESS_PLACE_CD) =
              DECODE(P_BUSINESS_PLACE_CD,NULL,'%',P_BUSINESS_PLACE_CD);
BEGIN
     P_SQLCODE  := NULL;
     P_SQLERRM  := NULL;
     
     /*lv_sdate := P_CPN201.PAY_YM || '01';
     lv_edate := TO_CHAR(LAST_DAY(TO_DATE(P_CPN201.PAY_YM, 'YYYYMM')), 'YYYYMMDD');*/
     lv_sdate := P_CPN201.ORD_SYMD;
     lv_edate := P_CPN201.ORD_EYMD;
     ln_tot_cnt := TO_NUMBER(SUBSTR(lv_edate,7,2));

     /* 급여코드 정보 가져오기 */
     BEGIN
        SELECT *
          INTO lv_cpn051
          FROM TCPN051
         WHERE ENTER_CD = P_ENTER_CD
           AND PAY_CD   = P_CPN201.PAY_CD;
     EXCEPTION
         WHEN OTHERS THEN
            P_SQLCODE := SQLCODE;
            P_SQLERRM := '급여유형 Select Error => 급여코드: '||P_CPN201.PAY_CD||'  ' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'01',P_SQLERRM, P_CHKID);
     END;
     
     
     /* 기존 자료 삭제 */
     BEGIN
        DELETE FROM TCPN431 A
         WHERE A.ENTER_CD = P_ENTER_CD
           AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
           AND EXISTS (SELECT X.SABUN
                         FROM TCPN203 X
                        WHERE X.ENTER_CD      = A.ENTER_CD
                          AND X.PAY_ACTION_CD = A.PAY_ACTION_CD
                          AND X.SABUN         = A.SABUN
                          AND X.PAY_PEOPLE_STATUS IN ('P','M','PM') -- 급여대상자상태(C00125)-> 'P':작업대상,'M':Mark For Retry
                          AND DECODE(P_SABUN,NULL,'%',X.SABUN) = DECODE(P_SABUN,NULL,'%',P_SABUN)
                          AND DECODE(P_BUSINESS_PLACE_CD,NULL,'%',X.BUSINESS_PLACE_CD) =
                               DECODE(P_BUSINESS_PLACE_CD,NULL,'%',P_BUSINESS_PLACE_CD)
                     )
            ;
     EXCEPTION
        WHEN OTHERS THEN
           ROLLBACK;
           P_SQLCODE := SQLCODE;
           P_SQLERRM := '[급여일자 :' || P_PAY_ACTION_CD || '] 개인별수당자료 자료 삭제시 Error' || SQLERRM;
           P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'30',P_SQLERRM, P_CHKID);
     END;


     ---------------------------------------------
     -- 급여구분이 00001(급여) 일 경우 일할계산 등록
     ---------------------------------------------
     IF lv_cpn051.RUN_TYPE = '00001' THEN
        /* 개인별수당자료 등록 */
        BEGIN
            INSERT INTO TCPN431
            (
             ENTER_CD, PAY_ACTION_CD, SABUN,
             SUB_ELE_CD, SDATE, EDATE, ELEMENT_CD,
             BASIC_MON, RESULT_MON, CHKDATE, CHKID
            )
            (
              SELECT ENTER_CD
                    ,P_PAY_ACTION_CD AS PAY_ACTION_CD
                    ,SABUN
                    ,SUB_ELE_CD
                    --,SDATE
                    --,EDATE
                    ,lv_sdate AS SDATE
                    ,lv_edate AS EDATE
                    ,ELEMENT_CD
                    --,BASIC_MON
                    /*,(CASE WHEN SDATE <> lv_sdate OR EDATE <> lv_edate THEN NVL(BASIC_MON,0) * ( (TO_DATE(EDATE,'YYYYMMDD') - TO_DATE(SDATE,'YYYYMMDD') + 1) / ln_tot_cnt )
                           ELSE BASIC_MON END) AS BASIC_MON*/
                    --20240318. 신규입사자 처리(입사일자가 급여계산 시작일자보다 큰경우만 기준금액을 일할처리한다.)
                    ,(CASE WHEN (SDATE <> lv_sdate OR EDATE <> lv_edate) AND EMP_YMD <= lv_sdate THEN NVL(BASIC_MON,0) * ( (TO_DATE(EDATE,'YYYYMMDD') - TO_DATE(SDATE,'YYYYMMDD') + 1) / ln_tot_cnt )
                           ELSE BASIC_MON END) AS BASIC_MON
                    /* 실근무일수 기준 일할 로직 */
                    ,(CASE WHEN SDATE <> lv_sdate OR EDATE <> lv_edate THEN NVL(BASIC_MON,0) * ( (TO_DATE(EDATE,'YYYYMMDD') - TO_DATE(SDATE,'YYYYMMDD') + 1) / ln_tot_cnt )
                           ELSE BASIC_MON END) AS RESULT_MON
                    ,SYSDATE AS CHKDATE
                    ,P_CHKID AS CHKID
                FROM (
                      SELECT A.ENTER_CD
                            ,A.SABUN
                            ,D.EMP_YMD
                            ,A.SUB_ELE_CD
                            ,(CASE WHEN A.SDATE <= lv_sdate THEN lv_sdate ELSE A.SDATE END) AS SDATE
                            ,(CASE WHEN NVL(A.EDATE, '99991231') >= lv_edate THEN lv_edate ELSE A.EDATE END) AS EDATE
                            ,B.ELEMENT_CD
                            ,B.MON AS BASIC_MON
                        FROM TCPN429 A
                            ,(SELECT X.ENTER_CD
                                    ,X.SUB_ELE_CD
                                    ,X.ELEMENT_CD -- 지급항목코드
                                    ,NVL(X.BON_YN, 'N') AS BON_YN -- 상여포함여부
                                    ,X.BASIC_MON AS MON -- 수당액
                                FROM TCPN428 X
                               WHERE X.ENTER_CD  = P_ENTER_CD
                                 AND X.S_YM = (SELECT MAX(Y.S_YM) FROM TCPN428 Y WHERE Y.ENTER_CD = X.ENTER_CD AND Y.SUB_ELE_CD = X.SUB_ELE_CD AND SUBSTR(lv_edate,1,6) BETWEEN Y.S_YM AND NVL(Y.E_YM, '999912'))
                                 AND X.ELEMENT_CD IS NOT NULL -- 지급항목코드가 맵핑된 자료
                                 AND NVL(X.BASIC_MON,0) > 0 -- 수당액이 있는 자료
                             ) B
                            ,TCPN072 C -- 항목그룹Detail (DateTrack Table)
                            ,(SELECT X.ENTER_CD
                                   , X.PAY_ACTION_CD
                                   , X.SABUN
                                   , X.ORD_SYMD
                                   , X.ORD_EYMD
                                   , X.EMP_YMD
                                   , X.GEMP_YMD
                                FROM TCPN203 X
                               WHERE X.ENTER_CD      = P_ENTER_CD
                                 AND X.PAY_ACTION_CD = P_PAY_ACTION_CD
                                 AND X.PAY_PEOPLE_STATUS IN ('P','M','PM') -- 급여대상자상태(C00125)-> 'P':작업대상,'M':Mark For Retry
                                 AND DECODE(P_SABUN,NULL,'%',X.SABUN) = DECODE(P_SABUN,NULL,'%',P_SABUN)
                                 AND DECODE(P_BUSINESS_PLACE_CD,NULL,'%',X.BUSINESS_PLACE_CD) =
                                      DECODE(P_BUSINESS_PLACE_CD,NULL,'%',P_BUSINESS_PLACE_CD)
                             ) D
                       WHERE A.ENTER_CD = B.ENTER_CD
                         AND A.SUB_ELE_CD = B.SUB_ELE_CD
                         AND B.ENTER_CD = C.ENTER_CD
                         AND B.ELEMENT_CD = C.ELEMENT_CD
                         AND A.ENTER_CD = P_ENTER_CD
                         AND A.SDATE   <= lv_edate
                         AND NVL(A.EDATE, '99991231') >= lv_sdate
                         AND C.ELEMENT_SET_CD = lv_cpn051.ELEMENT_SET_CD -- 급여계산 대상 항목그룹코드
                         AND C.SDATE = (SELECT MAX(E.SDATE) FROM TCPN072 E
                                               WHERE E.ENTER_CD   = C.ENTER_CD
                                                 AND E.ELEMENT_CD = C.ELEMENT_CD
                                                 AND E.ELEMENT_SET_CD = C.ELEMENT_SET_CD
                                                 AND lv_edate BETWEEN E.SDATE AND NVL(E.EDATE,'99991231'))
                         AND A.ENTER_CD = D.ENTER_CD
                         AND A.SABUN = D.SABUN
                         /*AND A.SABUN IN ( SELECT X.SABUN
                                            FROM TCPN203 X
                                           WHERE X.ENTER_CD      = P_ENTER_CD
                                             AND X.PAY_ACTION_CD = P_PAY_ACTION_CD
                                             AND X.PAY_PEOPLE_STATUS IN ('P','M','PM') -- 급여대상자상태(C00125)-> 'P':작업대상,'M':Mark For Retry
                                             AND DECODE(P_SABUN,NULL,'%',X.SABUN) = DECODE(P_SABUN,NULL,'%',P_SABUN)
                                             AND DECODE(P_BUSINESS_PLACE_CD,NULL,'%',X.BUSINESS_PLACE_CD) =
                                                  DECODE(P_BUSINESS_PLACE_CD,NULL,'%',P_BUSINESS_PLACE_CD)
                                       )*/
                  )
            );
        EXCEPTION
           WHEN OTHERS THEN
              ROLLBACK;
              P_SQLCODE := SQLCODE;
              P_SQLERRM := '[급여일자 :' || P_PAY_ACTION_CD || '] 개인별수당자료 자료 등록시 Error' || SQLERRM;
              P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'50',P_SQLERRM, P_CHKID);
        END;
    
     ----------------------------------------------------
     -- 급여구분이 00001(급여)가 아닐 경우 지급일자 기준 등록
     ----------------------------------------------------
     ELSE
        /* 개인별수당자료 등록 */
        BEGIN
            INSERT INTO TCPN431
            (
             ENTER_CD, PAY_ACTION_CD, SABUN,
             SUB_ELE_CD, SDATE, EDATE, ELEMENT_CD,
             BASIC_MON, RESULT_MON, CHKDATE, CHKID
            )
            (
              SELECT ENTER_CD
                    ,P_PAY_ACTION_CD AS PAY_ACTION_CD
                    ,SABUN
                    ,SUB_ELE_CD
                    ,SDATE
                    ,EDATE
                    ,ELEMENT_CD
                    ,BASIC_MON
                    ,BASIC_MON AS RESULT_MON
                    ,SYSDATE AS CHKDATE
                    ,P_CHKID AS CHKID
                FROM (
                      SELECT A.ENTER_CD
                            ,A.SABUN
                            ,A.SUB_ELE_CD
                            ,(CASE WHEN A.SDATE <= lv_sdate THEN lv_sdate ELSE A.SDATE END) AS SDATE
                            ,(CASE WHEN NVL(A.EDATE, '99991231') >= lv_edate THEN lv_edate ELSE A.EDATE END) AS EDATE
                            ,B.ELEMENT_CD
                            ,B.MON AS BASIC_MON
                        FROM TCPN429 A
                            ,(SELECT X.ENTER_CD
                                    ,X.SUB_ELE_CD
                                    ,X.ELEMENT_CD -- 지급항목코드
                                    ,NVL(X.BON_YN, 'N') AS BON_YN -- 상여포함여부
                                    ,X.BASIC_MON AS MON -- 수당액
                                FROM TCPN428 X
                               WHERE X.ENTER_CD  = P_ENTER_CD
                                 AND X.S_YM = (SELECT MAX(Y.S_YM) FROM TCPN428 Y WHERE Y.ENTER_CD = X.ENTER_CD AND Y.SUB_ELE_CD = X.SUB_ELE_CD AND SUBSTR(lv_edate,1,6) BETWEEN Y.S_YM AND NVL(Y.E_YM, '999912'))
                                 AND NVL(X.BON_YN, 'N') = 'Y' -- 상여포함여부
                                 AND X.ELEMENT_CD IS NOT NULL -- 지급항목코드가 맵핑된 자료
                                 AND NVL(X.BASIC_MON,0) > 0 -- 수당액이 있는 자료
                             ) B
                            ,TCPN072 C -- 항목그룹Detail (DateTrack Table)
                       WHERE A.ENTER_CD = B.ENTER_CD
                         AND A.SUB_ELE_CD = B.SUB_ELE_CD
                         AND B.ENTER_CD = C.ENTER_CD
                         AND B.ELEMENT_CD = C.ELEMENT_CD
                         AND A.ENTER_CD = P_ENTER_CD
                         AND P_CPN201.PAYMENT_YMD BETWEEN A.SDATE AND NVL(A.EDATE, '99991231') -- [지급일자] 기준 등록
                         AND C.ELEMENT_SET_CD = lv_cpn051.ELEMENT_SET_CD -- 급여계산 대상 항목그룹코드
                         AND C.SDATE = (SELECT MAX(E.SDATE) FROM TCPN072 E
                                               WHERE E.ENTER_CD   = C.ENTER_CD
                                                 AND E.ELEMENT_CD = C.ELEMENT_CD
                                                 AND E.ELEMENT_SET_CD = C.ELEMENT_SET_CD
                                                 AND lv_edate BETWEEN E.SDATE AND NVL(E.EDATE,'99991231'))
                         AND A.SABUN IN ( SELECT X.SABUN
                                            FROM TCPN203 X
                                           WHERE X.ENTER_CD      = P_ENTER_CD
                                             AND X.PAY_ACTION_CD = P_PAY_ACTION_CD
                                             AND X.PAY_PEOPLE_STATUS IN ('P','M','PM') -- 급여대상자상태(C00125)-> 'P':작업대상,'M':Mark For Retry
                                             AND DECODE(P_SABUN,NULL,'%',X.SABUN) = DECODE(P_SABUN,NULL,'%',P_SABUN)
                                             AND DECODE(P_BUSINESS_PLACE_CD,NULL,'%',X.BUSINESS_PLACE_CD) =
                                                  DECODE(P_BUSINESS_PLACE_CD,NULL,'%',P_BUSINESS_PLACE_CD)
                                       )
                  )
            );
        EXCEPTION
           WHEN OTHERS THEN
              ROLLBACK;
              P_SQLCODE := SQLCODE;
              P_SQLERRM := '[급여일자 :' || P_PAY_ACTION_CD || '] 개인별수당자료 자료 등록시 Error' || SQLERRM;
              P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'70',P_SQLERRM, P_CHKID);
        END;
        --
     END IF;

     COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      P_SQLCODE := P_SQLCODE;
      P_SQLERRM := NVL(P_SQLERRM, SQLERRM);
      P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'100',P_SQLERRM, P_CHKID);
END P_CPN_CAL_ALLOW_INS_KS;