create or replace PROCEDURE "P_BEN_PAY_DATA_CREATE" (
         P_SQLCODE           OUT VARCHAR2, -- ERROR CODE
         P_SQLERRM           OUT VARCHAR2, -- ERROR MESSAGES
         P_CNT               OUT VARCHAR2, -- 복사DATA수
         P_ENTER_CD          IN  VARCHAR2, -- 회사코드
         P_BENEFIT_BIZ_CD    IN  VARCHAR2, -- 복리후생업무구분코드(B10230)
         P_PAY_ACTION_CD     IN  VARCHAR2, -- 급여일자 구분코드
         P_BUSINESS_PLACE_CD IN  VARCHAR2, -- 사업장 구분코드
         P_CHKID             IN  VARCHAR2  -- 수정자
         )
is
/********************************************************************************/
/*                                                                              */
/*                    (c) Copyright ISU System Inc. 2004                        */
/*                           All Rights Reserved                                */
/*                                                                              */
/********************************************************************************/
/*  PROCEDURE NAME : P_BEN_PAY_DATA_CREATE                              */
/*                                                                              */
/*           마감코드별 복리후생 이력생성                                       */
/*           10005    : 국민연금 공제자료 생성                                  */
/*           10007    : 건강보험 공제자료 생성                                  */
/********************************************************************************/
/*  [ 참조 TABLE ]                                                              */
/*      TCPN201 : 급여계산관리(급여일자관리). 급여지급일자(PAYMENT_YMD) 추출    */
/*      TCPN203 : 급여대상자관리. 급여대상관리자의 SABUN 추출                   */
/*      TBEN203 : 건강보험변동이력. 급여대상관리자의 건강보험 등급(GRADE) 추출  */
/*      TBEN001 : 등급별 본인부담액(SELF_MON), 회사부담액(COMP_MON) 추출        */
/*      TBEN009 : 등급별 추가 및 환급 부담액 추출                               */
/********************************************************************************/
/*  [ 생성 TABLE ]                                                              */
/*                                                                              */
/*    TBEN205 : 건강보험공제이력                                                */
/*    TBEN105 : 국민연금공제이력                                                */
/*        TCPN983 : 급여관련사항마감관리                                        */
/********************************************************************************/
/*  [ 삭제 TABLE ]                                                              */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 개요 ]                                                                */
/*        < 10007    : 건강보험 공제자료 생성 >                                 */
/*       건강보험공제자료 생성 조건에 해당하는 기존 자료 DELETE                 */
/*                                                                              */
/*       건강보험공제자료 생성 대상 사원 Query                                  */
/*                해당 사원의 건강보험 등급 Query                               */
/*          해당 등급의 본인부담액, 회사부담액 Query                            */
/*          해당 사원의 추가본인부담액, 추가회사부담액 Query                    */
/*          추가본인부담액에 따른 사회보험공제코드 지정                         */
/*          건강보험공제이력에 데이터 추가                                      */
/*       END;                                                                   */
/*                                                                              */
/*        < 10005    : 국민연금 공제자료 생성 >                                 */
/*       국민연금공제자료 생성 조건에 해당하는 기존 자료 DELETE                 */
/*                                                                              */
/*       국민연금공제자료 생성 대상 사원 Query                                  */
/*                해당 사원의 국민연금 등급 Query                               */
/*          해당 등급의 본인부담액, 회사부담액 Query                            */
/*          해당 사원의 추가본인부담액, 추가회사부담액 Query                    */
/*          추가본인부담액에 따른 사회보험공제코드 지정                         */
/*          국민연금공제이력에 데이터 추가                                      */
/*       END;                                                                   */
/*                                                                              */
/*       급여관련사항마감관리 자료의 처리상태 코드를 작업으로 지정              */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 호출 ]                                                                */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/*------------------------------------------------------------------------------*/
/* 2008-07-22  C.Y.G           Initial Release                                  */
/********************************************************************************/

   /* Local Variables */
   lv_cpn201          TCPN201%ROWTYPE;
   ln_rcnt            NUMBER := 0;
   lv_sdate           VARCHAR2(08);
   ln_max_seq         NUMBER := 0;
   ln_reward_tot_mon  TBEN203.REWARD_TOT_MON%TYPE; -- 보수월액
   ln_reduction_rate  NUMBER := 0;    -- 건강보험 감면율
   ln_reduction_rate2 NUMBER := 0;    -- 노인장기요양 감면율

   ln_benefit_biz_cd   VARCHAR2(10); --복리후생업무구분코드(B10230)
   lv_ben_cal_type     TCPN081.GLOBAL_VALUE%TYPE; -- 국민/건강보험 급여공제방식(A:보수월액, C:공단자료연계)

   ln_add_self_mon    NUMBER := 0;
   ln_add_comp_mon    NUMBER := 0;
   ln_return_self_mon NUMBER := 0;
   ln_return_comp_mon NUMBER := 0;
   ln_add_self_mon2   NUMBER := 0; -- 노인장기요양_본인_추가/환급
   ln_add_comp_mon2   NUMBER := 0; -- 노인장기요양_회사_추가/환급

   ln_mon1            NUMBER := NULL;--건강보험_정산
   ln_mon2            NUMBER := NULL;--요양보험_정산
   ln_mon3            NUMBER := NULL;--건강보험_환급이자
   ln_mon4            NUMBER := NULL;--요양보험_환급이자

   ln_mon5            NUMBER := NULL;
   ln_mon6            NUMBER := NULL;
   ln_mon7            NUMBER := NULL;
   ln_mon9            NUMBER := NULL; --월정급여에 추가적으로 더해질 고용보험분(정산분과 별개)

   lr_ben205            TBEN205%ROWTYPE;  -- 건강보험공제이력
   lr_ben105            TBEN105%ROWTYPE;  -- 국민연금공제이력
   lr_ben305            TBEN305%ROWTYPE;  -- 고용보험공제이력

   lv_ded_yn          VARCHAR2(01); -- 국민/건보 대상여부(휴직자 체크용)
   lv_ded_60_yn       VARCHAR2(01); -- 국민연금 대상여부(60세이상 체크용)

   ln_loan_cnt        NUMBER := 0;          --대출이력생성수
   ln_jikwee_cnt      NUMBER;               --대상자 여부
   ln_invest_seq      NUMBER;               --대상자 납입횟수
   ln_jikwee_cd       VARCHAR2(10) := NULL; --대상자 직위
   ln_manage_cd       VARCHAR2(10) := NULL; --대상자 사원구분
   ln_jikwee_mon      NUMBER;               --직위별 출자금액
   lv_payment_ymd     VARCHAR2(8) := NULL;
   lv_pay_action_cd   VARCHAR2(50);
   ln_invest_cnt      NUMBER;

   LV_CLOSE_CD        TCPN983.CLOSE_CD%TYPE; -- 마감코드(S90001)
   LV_CLOSE_ST        TCPN983.CLOSE_ST%TYPE; -- 마감상태(S90003)

   lv_updown_type     VARCHAR2(10) := NULL; -- 이자를 계산할 때 끝자리 처리 방법(절상/절사/반올림 중 하나)
   ln_updown_unit     NUMBER := 0;   -- 이자를 계산할 때의 끝자리 단위 (1/10/100/...)
   ln_pay_except_gubun VARCHAR(01) :=NULL;  --지급공제구분

   LV_PAY_CLOSE_YN  VARCHAR2(1); --급여마감상태
   LN_BIGO          VARCHAR2(4000);

   LV_BIZ_CD          TSYS903.BIZ_CD%TYPE := 'BEN';
   LV_OBJECT_NM       TSYS903.OBJECT_NM%TYPE := 'P_BEN_PAY_DATA_CREATE';

   -- 급여기준사업장별 작업
   CURSOR CSR_MAP IS
      SELECT X.MAP_CD AS BUSINESS_PLACE_CD
        FROM TORG109 X
       WHERE X.ENTER_CD = P_ENTER_CD
         AND X.MAP_TYPE_CD = '100' -- 급여기준사업장
         --AND X.MAP_CD='1'
         AND X.MAP_CD LIKE P_BUSINESS_PLACE_CD || '%';

   -- 작업대상자 가져오기
   --CURSOR CSR_CPN203 (C_BP_CD IN VARCHAR2) IS
   CURSOR CSR_CPN203 IS
     SELECT A.SABUN AS SABUN
           ,A.ORD_EYMD AS PAYMENT_YMD
           ,A.BUSINESS_PLACE_CD
           ,A.EMP_YMD
           ,A.RET_YMD
       FROM TCPN203 A, TCPN201 B
      WHERE A.ENTER_CD          = P_ENTER_CD
        AND A.PAY_ACTION_CD     = P_PAY_ACTION_CD
        AND A.ENTER_CD          = B.ENTER_CD
        AND A.PAY_ACTION_CD     = B.PAY_ACTION_CD;
        --AND (A.BUSINESS_PLACE_CD = C_BP_CD OR A.BUSINESS_PLACE_CD IS NULL);
BEGIN
   P_SQLCODE  := NULL;
   P_SQLERRM  := NULL;
   P_CNT      := '0';

    --급여마감여부 확인하기
    BEGIN
      SELECT CLOSE_YN
        INTO LV_PAY_CLOSE_YN
        FROM TCPN981
       WHERE ENTER_CD      = P_ENTER_CD
         AND PAY_ACTION_CD = P_PAY_ACTION_CD
         ;
    EXCEPTION
       WHEN NO_DATA_FOUND THEN
          LV_PAY_CLOSE_YN := 'N';
       WHEN OTHERS        THEN
          ROLLBACK;
          P_SQLCODE := TO_CHAR(SQLCODE);
          P_SQLERRM := '급여일자코드 : '     || P_PAY_ACTION_CD
                    || ' 의 급여마감(TCPN981)여부 검색시 Error =>' || SQLERRM;
         P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'10',P_SQLERRM, P_CHKID);
    END;


    --급여가 마감된 경우, 복리후생 마감업무 처리를 할 수 없음.
    IF LV_PAY_CLOSE_YN = 'Y' THEN
       P_SQLCODE  := '999';
       P_SQLERRM  := '해당 급여가 이미 마감되었습니다. 마감된 급여에 대한 마감은 진행할 수 없습니다. 급여 담당자와 해당 급여의 마감여부를 확인해보시기 바랍니다.';
       RETURN;
    END IF;

   /* P_BENEFIT_BIZ_CD (복리후생업무구분코드(B10230))
      10:국민연금,  15:건강보험, 20:고용보험, 120:귀성여비, 130:주거보조금, 135:이자보조금, 140:자녀학자금, 150:자녀학자금(대학), 180:대출금 */

   -- 급여계산일자 정보가져오기
   lv_cpn201 := F_CPN_GET_201_INFO(P_ENTER_CD, P_PAY_ACTION_CD);

   /* 급여사업장 별 작업 */
--   FOR C_MAP IN CSR_MAP LOOP

      BEGIN
        DELETE FROM TBEN777
              WHERE ENTER_CD      = P_ENTER_CD
                AND PAY_ACTION_CD = P_PAY_ACTION_CD
                AND BEN_GUBUN     = P_BENEFIT_BIZ_CD
                AND SABUN IN (SELECT X.SABUN
                                FROM TCPN203 X
                               WHERE X.ENTER_CD = P_ENTER_CD
                                 AND X.PAY_ACTION_CD = P_PAY_ACTION_CD);
                                 --AND X.BUSINESS_PLACE_CD = C_MAP.BUSINESS_PLACE_CD);
      EXCEPTION
        WHEN OTHERS THEN
             ROLLBACK;
             P_SQLCODE := TO_CHAR(SQLCODE);
             P_SQLERRM := '급여일자코드 : ' || P_PAY_ACTION_CD || ' 복리후생공제이력 테이블(TBEN777) DELETE Error=>' || SQLERRM;
             P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'15',P_SQLERRM, P_CHKID);
             RETURN;
      END;

       ln_benefit_biz_cd := P_BENEFIT_BIZ_CD;

        --수당지급신청과 기타지급신청의 경우 신규생성되는 모든 코드를 나열하기 힘드니 급여마감항목관리에서 'Y'로 관리되는 항목은 모두 동일 로직 적용
        BEGIN
          SELECT MAX('ETC_PAY')
            INTO ln_benefit_biz_cd
            FROM TCPN980
           WHERE ENTER_CD      = P_ENTER_CD
             AND (NVL(ETC_PAY_YN, 'N') = 'Y' OR NVL(DEPT_PART_PAY_YN, 'N') ='Y')
             AND BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
             ;
        EXCEPTION
           WHEN NO_DATA_FOUND THEN
              ln_benefit_biz_cd := P_BENEFIT_BIZ_CD;
        END;

        IF ln_benefit_biz_cd IS NULL THEN
           ln_benefit_biz_cd := P_BENEFIT_BIZ_CD;
        END IF;

      CASE ln_benefit_biz_cd

         --------------------
         -- 건강보험
         --------------------
         WHEN '15' THEN
            -- 국민/건강보험 급여공제방식(A:보수월액, C:공단자료연계)
            lv_ben_cal_type := NVL(F_CPN_GET_GLOVAL_VALUE(P_ENTER_CD, 'BEN_CAL_TYPE', lv_cpn201.PAYMENT_YMD), 'A');
            /* -- 건강보험 급여공제방식(C:공단자료연계) */
            IF lv_ben_cal_type = 'C' THEN
               BEGIN
                IF P_ENTER_CD = 'HX' THEN -- 한진정보통신, 공단자료(사번) 업로드 이용
                  INSERT INTO TBEN777
                  (
                          ENTER_CD --회사구분(TORG900)
                         ,PAY_ACTION_CD --급여계산코드(TCPN201)
                         ,SABUN --사원번호
                         ,BEN_GUBUN --기타복리후생이력생성구분(B10230)
                         ,SEQ --순번
                         ,BUSINESS_PLACE_CD --사업장코드(TCPN121)
                         ,MON1 -- 건강보험료
                         ,MON3 -- 요양보험료
                         ,MON5  -- 건강보험정산금(정산금액+연말정산)
                         ,MON7 -- 요양보험정산금(정산금액+연말정산)
                         ,CHKDATE --최종수정시간
                         ,CHKID --최종수정자
                   )
                   (
                    SELECT ENTER_CD
                          ,PAY_ACTION_CD
                          ,SABUN
                          ,BEN_GUBUN
                          ,(SELECT NVL(MAX(TO_NUMBER(X.SEQ)),0)+ RNUM
                              FROM TBEN777 X
                             WHERE X.ENTER_CD = ENTER_CD
                           ) AS BEN_GUBUN
                          ,BUSINESS_PLACE_CD
                          ,MON1  -- 건강보험료
                          ,MON3  -- 요양보험료
                          ,MON5  -- 건강보험정산금(정산금액+연말정산)
                          ,MON7 -- 요양보험정산금(정산금액+연말정산)
                          ,SYSDATE AS CHKDATE
                          ,P_CHKID AS CHKID
                     FROM (
                            SELECT NVL(T1.ENTER_CD, T2.ENTER_CD) AS ENTER_CD
                                  ,NVL(T1.PAY_ACTION_CD, T2.PAY_ACTION_CD) AS PAY_ACTION_CD
                                  ,NVL(T1.SABUN, T2.SABUN) AS SABUN
                                  ,NVL(T1.BEN_GUBUN, T2.BEN_GUBUN) AS BEN_GUBUN
                                  ,ROW_NUMBER() OVER (ORDER BY NVL(T1.SABUN, T2.SABUN)) AS RNUM
                                  ,NVL(T1.BUSINESS_PLACE_CD, T2.BUSINESS_PLACE_CD) AS BUSINESS_PLACE_CD
                                  ,T1.MON1 -- 건강보험료
                                  ,T1.MON3 -- 요양보험료
                                  ,NVL(T1.MON5,0)+NVL(T2.MON5,0) AS MON5    -- 건강보험정산금(정산금액+연말정산)
                                  ,NVL(T1.MON7,0)+NVL(T2.MON7,0) AS MON7 -- 요양보험정산금(정산금액+연말정산)
                              FROM ( /* 건강보험 공단자료 */
                                    SELECT A.ENTER_CD
                                          ,A.PAY_ACTION_CD
                                          ,A.SABUN
                                          ,ln_benefit_biz_cd AS BEN_GUBUN
                                          ,ROW_NUMBER() OVER (ORDER BY A.SABUN) AS RNUM
                                          ,A.BUSINESS_PLACE_CD
                                          ,C.MON1 AS MON1 -- 건강보험료(산출보험료)
                                          ,NVL(C.MON2,0)+NVL(C.MON4,0)+NVL(C.MON5,0) AS MON5 -- 건강보험정산금(정산금액+연말정산+환급이자)
                                          ,C.MON6 AS MON3 -- 요양보험료(산출보험료)
                                          ,NVL(C.MON7,0)+NVL(C.MON9,0)+NVL(C.MON10,0) AS MON7 -- 요양보험정산금(정산금액+연말정산+환급이자)
                                      FROM TCPN203 A
                                          ,TCPN201 B
                                          ,TBEN212 C
                                     WHERE A.ENTER_CD      = P_ENTER_CD
                                       AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
                                       AND A.ENTER_CD      = B.ENTER_CD
                                       AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
                                       AND A.ENTER_CD      = C.ENTER_CD
                                       AND A.SABUN         = C.SABUN
                                       AND B.PAY_YM        = C.YM
                                  ) T1 FULL OUTER JOIN
                                  ( /* 건강보험 추가/환급액관리 */
                                    SELECT ENTER_CD
                                          ,PAY_ACTION_CD
                                          ,SABUN
                                          ,BEN_GUBUN
                                          ,ROW_NUMBER() OVER (ORDER BY SABUN) AS RNUM
                                          ,BUSINESS_PLACE_CD
                                          ,MON5 -- 건강보험정산금
                                          ,MON7 -- 요양보험정산금
                                      FROM (
                                             SELECT A.ENTER_CD
                                                   ,A.PAY_ACTION_CD
                                                   ,A.SABUN
                                                   ,ln_benefit_biz_cd AS BEN_GUBUN
                                                   ,A.BUSINESS_PLACE_CD
                                                   ,SUM(NVL(C.ADD_SELF_MON,0)+NVL(C.MON1,0)+NVL(C.MON3,0)) AS MON5 -- 건강보험정산금
                                                   ,SUM(NVL(C.ADD_SELF_MON2,0)+NVL(C.MON2,0)+NVL(C.MON4,0)) AS MON7 -- 요양보험정산금
                                               FROM TCPN203 A
                                                   ,TCPN201 B
                                                   ,TBEN009 C
                                              WHERE A.ENTER_CD      = P_ENTER_CD
                                                AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
                                                AND A.ENTER_CD      = B.ENTER_CD
                                                AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
                                                AND A.ENTER_CD      = C.ENTER_CD
                                                AND A.PAY_ACTION_CD = C.PAY_ACTION_CD
                                                AND A.SABUN         = C.SABUN
                                                AND C.BENEFIT_BIZ_CD = ln_benefit_biz_cd
                                             GROUP BY A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BUSINESS_PLACE_CD
                                          )
                                  ) T2 ON T1.ENTER_CD = T2.ENTER_CD AND T1.PAY_ACTION_CD = T2.PAY_ACTION_CD AND T1.SABUN = T2.SABUN
                         )
                    );
                ELSE
                  INSERT INTO TBEN777
                  (
                          ENTER_CD --회사구분(TORG900)
                         ,PAY_ACTION_CD --급여계산코드(TCPN201)
                         ,SABUN --사원번호
                         ,BEN_GUBUN --기타복리후생이력생성구분(B10230)
                         ,SEQ --순번
                         ,BUSINESS_PLACE_CD --사업장코드(TCPN121)
                         ,MON1 -- 건강보험료
                         ,MON3 -- 요양보험료
                         ,MON5  -- 건강보험정산금(정산금액+연말정산)
                         ,MON7 -- 요양보험정산금(정산금액+연말정산)
                         ,CHKDATE --최종수정시간
                         ,CHKID --최종수정자
                   )
                   (
                    SELECT ENTER_CD
                          ,PAY_ACTION_CD
                          ,SABUN
                          ,BEN_GUBUN
                          ,(SELECT NVL(MAX(TO_NUMBER(X.SEQ)),0)+ RNUM
                              FROM TBEN777 X
                             WHERE X.ENTER_CD = ENTER_CD
                           ) AS BEN_GUBUN
                          ,BUSINESS_PLACE_CD
                          ,MON1  -- 건강보험료
                          ,MON3  -- 요양보험료
                          ,MON5  -- 건강보험정산금(정산금액+연말정산)
                          ,MON7 -- 요양보험정산금(정산금액+연말정산)
                          ,SYSDATE AS CHKDATE
                          ,P_CHKID AS CHKID
                     FROM (
                            SELECT NVL(T1.ENTER_CD, T2.ENTER_CD) AS ENTER_CD
                                  ,NVL(T1.PAY_ACTION_CD, T2.PAY_ACTION_CD) AS PAY_ACTION_CD
                                  ,NVL(T1.SABUN, T2.SABUN) AS SABUN
                                  ,NVL(T1.BEN_GUBUN, T2.BEN_GUBUN) AS BEN_GUBUN
                                  ,ROW_NUMBER() OVER (ORDER BY NVL(T1.SABUN, T2.SABUN)) AS RNUM
                                  ,NVL(T1.BUSINESS_PLACE_CD, T2.BUSINESS_PLACE_CD) AS BUSINESS_PLACE_CD
                                  ,T1.MON1 -- 건강보험료
                                  ,T1.MON3 -- 요양보험료
                                  ,NVL(T1.MON5,0)+NVL(T2.MON5,0) AS MON5    -- 건강보험정산금(정산금액+연말정산)
                                  ,NVL(T1.MON7,0)+NVL(T2.MON7,0) AS MON7 -- 요양보험정산금(정산금액+연말정산)
                              FROM ( /* 건강보험 공단자료 */
--                                    SELECT A.ENTER_CD
--                                          ,A.PAY_ACTION_CD
--                                          ,A.SABUN
--                                          ,ln_benefit_biz_cd AS BEN_GUBUN
--                                          ,ROW_NUMBER() OVER (ORDER BY A.SABUN) AS RNUM
--                                          ,A.BUSINESS_PLACE_CD
--                                          ,C.MON1 AS MON1 -- 건강보험료(산출보험료)
--                                          ,NVL(C.MON2,0)+NVL(C.MON4,0)+NVL(C.MON5,0) AS MON5 -- 건강보험정산금(정산금액+연말정산+환급이자)
--                                          ,C.MON6 AS MON3 -- 요양보험료(산출보험료)
--                                          ,NVL(C.MON7,0)+NVL(C.MON9,0)+NVL(C.MON10,0) AS MON7 -- 요양보험정산금(정산금액+연말정산+환급이자)
--                                      FROM TCPN203 A
--                                          ,TCPN201 B
--                                          ,TBEN212 C
--                                     WHERE A.ENTER_CD      = P_ENTER_CD
--                                       AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
--                                       AND A.ENTER_CD      = B.ENTER_CD
--                                       AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
--                                       AND A.ENTER_CD      = C.ENTER_CD
--                                       AND A.SABUN         = C.SABUN
--                                       AND B.PAY_YM        = C.YM
                                        /* 건강보험 등급변경자료 */
                                        SELECT A.ENTER_CD,
                                              A.PAY_ACTION_CD,
                                              A.SABUN,
                                              ln_benefit_biz_cd AS BEN_GUBUN,
                                              ROW_NUMBER() OVER (ORDER BY A.SABUN) AS RNUM,
                                              A.BUSINESS_PLACE_CD,
                                              C.MON3 AS MON1, --건강보혐료 (산출보험료)
                                              C.MON4 AS MON3, --요양보험료(산출보험료)
                                              0 AS MON5, --건강보험정산금(정산금액+연말정산+환급이자)
                                              0 AS MON7  --요양보험정산금(정산금액+연말정산+환급이자)
                                        FROM TCPN203 A
                                        JOIN TCPN201 B
                                          ON A.ENTER_CD = B.ENTER_CD
                                         AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
                                        JOIN (
                                                SELECT T0.ENTER_CD,
                                                         F_COM_GET_SABUN3(T0.ENTER_CD, T0.RES_NO) AS SABUN,
                                                         T0.MON3,
                                                         T0.MON4
                                                 FROM TBEN011 T0
                                                 WHERE T0.ENTER_CD = P_ENTER_CD
                                                     AND T0.BENEFIT_BIZ_CD = ln_benefit_biz_cd
                                                     AND T0.SDATE = (
                                                      SELECT T2.SDATE
                                                         FROM TBEN011 T2
                                                        WHERE T2.ENTER_CD = T0.ENTER_CD
                                                          AND T2.BENEFIT_BIZ_CD = T0.BENEFIT_BIZ_CD
                                                          AND T2.RES_NO = T0.RES_NO
                                                        ORDER BY T2.SDATE DESC
                                                        FETCH FIRST 1 ROWS ONLY
                                                     )
                                              ) C
                                          ON A.ENTER_CD = C.ENTER_CD
                                         AND A.SABUN = C.SABUN
                                        WHERE A.ENTER_CD = P_ENTER_CD
                                         AND A.PAY_ACTION_CD = P_PAY_ACTION_CD

                                  ) T1 FULL OUTER JOIN
                                  ( /* 건강보험 추가/환급액관리 */
                                    SELECT ENTER_CD
                                          ,PAY_ACTION_CD
                                          ,SABUN
                                          ,BEN_GUBUN
                                          ,ROW_NUMBER() OVER (ORDER BY SABUN) AS RNUM
                                          ,BUSINESS_PLACE_CD
                                          ,MON5 -- 건강보험정산금
                                          ,MON7 -- 요양보험정산금
                                      FROM (
                                             SELECT A.ENTER_CD
                                                   ,A.PAY_ACTION_CD
                                                   ,A.SABUN
                                                   ,ln_benefit_biz_cd AS BEN_GUBUN
                                                   ,A.BUSINESS_PLACE_CD
                                                   ,SUM(NVL(C.ADD_SELF_MON,0)+NVL(C.MON1,0)+NVL(C.MON3,0)) AS MON5 -- 건강보험정산금
                                                   ,SUM(NVL(C.ADD_SELF_MON2,0)+NVL(C.MON2,0)+NVL(C.MON4,0)) AS MON7 -- 요양보험정산금
                                               FROM TCPN203 A
                                                   ,TCPN201 B
                                                   ,TBEN009 C
                                              WHERE A.ENTER_CD      = P_ENTER_CD
                                                AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
                                                AND A.ENTER_CD      = B.ENTER_CD
                                                AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
                                                AND A.ENTER_CD      = C.ENTER_CD
                                                AND A.PAY_ACTION_CD = C.PAY_ACTION_CD
                                                AND A.SABUN         = C.SABUN
                                                AND C.BENEFIT_BIZ_CD = ln_benefit_biz_cd
                                             GROUP BY A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BUSINESS_PLACE_CD
                                          )
                                  ) T2 ON T1.ENTER_CD = T2.ENTER_CD AND T1.PAY_ACTION_CD = T2.PAY_ACTION_CD AND T1.SABUN = T2.SABUN
                         )
                    );
                END IF;
               EXCEPTION
                  WHEN OTHERS THEN
                     ROLLBACK;
                     p_sqlcode := TO_CHAR(SQLCODE);
                     p_sqlerrm := '[급여일자코드 : ' || P_PAY_ACTION_CD || '] 건강보험공단자료 공제금액  INSERT Error =>' || SQLERRM;
                     P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'15-1',P_SQLERRM, P_CHKID);
                     RETURN;
               END;
            /* -- 건강보험 급여공제방식(A:보수월액) */
            ELSE
               -- 건강보험 공제자료 생성
               --FOR c_cpn203 IN csr_cpn203 (C_BP_CD => c_map.BUSINESS_PLACE_CD) LOOP
               FOR c_cpn203 IN csr_cpn203 LOOP
                   BEGIN
                      lr_ben205         := NULL;
                      ln_max_seq        := 0;
                      ln_reward_tot_mon := 0;
                      ln_add_self_mon   := 0;
                      ln_add_comp_mon   := 0;
                      ln_return_self_mon:= 0;
                      ln_return_comp_mon:= 0;
                      ln_mon1           := 0;
                      ln_mon2           := 0;
                      LN_MON3           := 0;
                      LN_MON4           := 0;
                      LN_BIGO           := '';
                      lv_ded_yn         := 'Y'; -- 국민/건보 대상여부(휴직자 체크용) ([한국공항]용)

                      /* 사번 및 지급일자를 기준으로 Date Track을 적용
                         이 중에서 MAX(SEQ)인 자료 중에서
                         건강보험불입상태(soc_state_cd)가 정상공제('A10')인 건강보험변동이력의 등급(grade)을 읽어온다.
                         TBEN203 : 건강보험 변동 이력
                         등급,보수월액 추출 */
                      BEGIN
                         SELECT MAX(SEQ),MAX(SDATE)
                           INTO ln_max_seq, lv_sdate
                           FROM TBEN203
                          WHERE enter_cd = p_enter_cd
                            AND sabun    = c_cpn203.sabun
                            AND sdate    = (SELECT MAX(sdate)
                                              FROM TBEN203
                                             WHERE enter_cd = p_enter_cd
                                               --AND lv_cpn201.PAY_YM||'01' BETWEEN sdate AND NVL(edate, '99991231')
                                               AND lv_cpn201.ORD_EYMD BETWEEN SDATE AND NVL(EDATE, '99991231')
                                               AND sabun = c_cpn203.sabun
                                            )
                           --AND TRIM(NVL(soc_state_cd, 'A10')) IN ('A10', 'C40');    -- 정상공제일 경우
                           AND TRIM(NVL(soc_state_cd, 'A10'))  NOT IN ('D10', 'C90', 'B25');  -- 기초수급대상,공제제외,휴직가 아닐 경우

                         -- 1일자 입사가 아닐경우 건강보험료를 생성하지 않는다. (전월퇴사자는 제외)
                         IF (lv_cpn201.pay_ym || '01' < c_cpn203.EMP_YMD) OR (c_cpn203.RET_YMD < lv_cpn201.pay_ym || '01') THEN
                            ln_max_seq := NULL;
                         END IF;

                         --------------------------------------------------------------------
                         -- [한국공항] 1~15일 휴직자, 16일~말일 복직자 국민/건보 공제 대상에서 제외
                         --------------------------------------------------------------------
                         IF P_ENTER_CD = 'KS' THEN
                            BEGIN
                                 SELECT 'N'
                                   INTO lv_ded_yn
                                   FROM (
                                          SELECT ENTER_CD, SABUN, GREATEST(SDATE,lv_cpn201.PAY_YM || '01') AS SDATE, LEAST(EDATE, TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD')) AS EDATE
                                            FROM (
                                                   SELECT ENTER_CD, SABUN, ORD_DETAIL_CD, MIN(SDATE) AS SDATE, MAX(EDATE) AS EDATE
                                                     FROM (
                                                           SELECT X.ENTER_CD, X.SABUN, X.SDATE, X.EDATE,
                                                                  (SELECT Z.ORD_DETAIL_CD FROM THRM191 Z
                                                                    WHERE Z.ENTER_CD = X.ENTER_CD
                                                                      AND Z.SABUN = X.SABUN
                                                                      AND Z.ORD_TYPE_CD = 'LAT_UPL_KOR' -- 발령종류 (LAT_UPL_KOR : 휴직)
                                                                      AND (Z.ORD_YMD || Z.APPLY_SEQ) = (
                                                                                        SELECT MAX(Y.ORD_YMD || Y.APPLY_SEQ) FROM THRM191 Y
                                                                                         WHERE Y.ENTER_CD = Z.ENTER_CD
                                                                                           AND Y.SABUN = Z.SABUN
                                                                                           AND Y.ORD_YMD <= X.SDATE
                                                                                           AND Y.ORD_TYPE_CD = 'LAT_UPL_KOR' -- 발령종류 (LAT_UPL_KOR : 휴직)
                                                                                           -- 휴직연장 발령코드 제외 (의병연장, 병가연장, 휴직연장, 육아휴직연장, 산재연장)
                                                                                           AND Y.ORD_DETAIL_CD NOT IN ('LAT_UPL_KOR52'
                                                                                                                     , 'LAT_UPL_KOR30'
                                                                                                                     , 'LAT_UPL_KOR31'
                                                                                                                     , 'LAT_UPL_KOR50'
                                                                                                                     , 'LAT_UPL_KOR51')
                                                                                           -- 20240319. 한국공항 휴직(산재) 발령코드 제외
                                                                                           --AND (Y.ENTER_CD, Y.ORD_DETAIL_CD) NOT IN (('KS', 'LAT_UPL_KOR49'))
                                                                                      )
                                                                  ) AS ORD_DETAIL_CD,
                                                                  SUM(NVL(TO_DATE(X.SDATE,'YYYYMMDD')-TO_DATE(X.LAG_EDATE,'YYYYMMDD')-1,0)) OVER (PARTITION BY X.ENTER_CD, X.SABUN ORDER BY X.ENTER_CD, X.SABUN, X.SDATE) AS DIFF_DAYS
                                                             FROM (
                                                                   SELECT A.ENTER_CD, A.SABUN, A.SDATE, A.EDATE,
                                                                          LAG(A.EDATE) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.ENTER_CD, A.SABUN, A.SDATE) AS LAG_EDATE
                                                                     FROM THRM151 A
                                                                    WHERE A.ENTER_CD = P_ENTER_CD
                                                                      AND A.SABUN    = c_cpn203.sabun
                                                                      AND A.STATUS_CD = 'CA' -- 재직상태 휴직 체크
                                                                      AND EXISTS (SELECT C.SABUN FROM THRM151 C
                                                                                   WHERE C.ENTER_CD = A.ENTER_CD
                                                                                     AND C.SABUN    = A.SABUN
                                                                                     AND C.SDATE   <= TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD')
                                                                                     AND C.EDATE   >= lv_cpn201.PAY_YM || '01'
                                                                                     AND C.STATUS_CD IN ('CA') -- 재직상태 CA(휴직)
                                                                                  )
                                                                  ) X
                                                          )
                                                   GROUP BY DIFF_DAYS, ENTER_CD, SABUN, ORD_DETAIL_CD
                                                 ) T1
                                           WHERE T1.SDATE   <= TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD')
                                             AND T1.EDATE   >= lv_cpn201.PAY_YM || '01'
                                             AND T1.ORD_DETAIL_CD NOT IN ('LAT_UPL_KOR48', 'LAT_UPL_KOR49') /* LAT_UPL_KOR48(병가), LAT_UPL_KOR49(산재)는 제외 */
                                        UNION ALL
                                        SELECT A.ENTER_CD
                                              ,A.SABUN
                                              ,(CASE WHEN A.SDATE <= lv_cpn201.PAY_YM || '01' THEN lv_cpn201.PAY_YM || '01' ELSE A.SDATE END) AS SDATE
                                              ,(CASE WHEN NVL(A.EDATE, '99991231') >= TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD') THEN TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD') ELSE A.EDATE END) AS EDATE
                                          FROM THRM129 A, TSYS005 B
                                         WHERE A.ENTER_CD = P_ENTER_CD
                                           AND A.SABUN    = c_cpn203.sabun
                                           AND A.ENTER_CD = B.ENTER_CD
                                           AND A.PUNISH_CD = B.CODE
                                           AND B.GRCODE_CD = 'H20270' -- 징계코드
                                           AND B.NOTE1     = 'Y'      -- 비고1 (정직 징계코드여부)
                                           AND A.SDATE   <= TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD')
                                           AND NVL(A.EDATE, '99991231') >= lv_cpn201.PAY_YM || '01'
                                        ) T
                                  WHERE (
                                         (T.SDATE <= lv_cpn201.PAY_YM || '15' AND (TO_DATE(T.EDATE,'YYYYMMDD') - TO_DATE(T.SDATE,'YYYYMMDD') + 1) >= 15) -- 1~15일 휴직자 체크
                                     OR  (T.SDATE <= lv_cpn201.PAY_YM || '01' AND T.EDATE >= lv_cpn201.PAY_YM || '16' AND (TO_DATE(T.EDATE,'YYYYMMDD') - TO_DATE(T.SDATE,'YYYYMMDD') + 1) >= 15) -- 16~말일자 복직자 체크
                                        );
                            EXCEPTION
                               WHEN NO_DATA_FOUND THEN
                                  lv_ded_yn := 'Y';
                               WHEN OTHERS THEN
                                  lv_ded_yn := 'Y';
                            END;

                            IF lv_ded_yn = 'N' THEN
                               ln_max_seq := NULL;
                            END IF;
                         END IF;

                         -- 등급, 보수월액, 감면율 정보 구하기
                         SELECT GRADE, NVL(REWARD_TOT_MON,0), NVL(REDUCTION_RATE, 0), NVL(REDUCTION_RATE2,0), MON4, MON5
                           INTO lr_ben205.grade, ln_reward_tot_mon, ln_reduction_rate, ln_reduction_rate2, lr_ben205.SELF_MON, lr_ben205.SELF_MON2
                           FROM TBEN203
                          WHERE ENTER_CD = P_ENTER_CD
                            AND SABUN    = c_cpn203.SABUN
                            AND SEQ      = ln_max_seq
                            AND SDATE    = lv_sdate;
                      EXCEPTION
                         WHEN OTHERS THEN
                            lr_ben205.grade := '';
                            ln_reward_tot_mon := 0;
                            ln_reduction_rate := 0;
                      END;

                      /* 본인부담액(self_mon) 산출
                         2007.01.01 부로 등급이 아닌 보수월액 * 건강보험요율 산정방식으로 변경 */
                      IF lv_cpn201.ORD_EYMD < '20070101' THEN
                         -- 본인부담액(self_mon), 회사부담액(comp_mon) 추출
                         lr_ben205.self_mon := 0;
                         lr_ben205.comp_mon := 0;
                      ELSE
                         lr_ben205.GRADE := NULL;
                         /*변동이력상에 건강보험 공제금액이 없을경우*/
                         --IF lr_ben205.SELF_MON = 0 OR lr_ben205.SELF_MON IS NULL THEN
                             lr_ben205.SELF_MON := F_BEN_HI_SELF_MON(
                                                            P_ENTER_CD
                                                           ,lv_cpn201.ORD_EYMD
                                                           ,ln_reward_tot_mon);
                             -- 건강보험 감면율 적용(10단위 절사)
                             IF NVL(ln_reduction_rate,0) <> 0 THEN
                                lr_ben205.SELF_MON := TRUNC(lr_ben205.SELF_MON * (1 - (ln_reduction_rate / 100)),-1);
                             END IF;

                         --END IF;
                         lr_ben205.COMP_MON := lr_ben205.SELF_MON;
                      END IF;

                     /* 2008.07.01 부터 시행되는 노인장기요양보험에 대한 Logic 추가  cck */
                      IF lv_cpn201.ORD_EYMD >= '20080701' THEN

                         lr_ben205.COMP_MON2 := 0;

                         /* 산출된 개인보험료에 요율을 적용하여 노인장기요양보험 산출
                            변동이력상에 장기요양보험 공제금액이 없을경우*/
                         --IF lr_ben205.SELF_MON2 = 0 OR lr_ben205.SELF_MON2 IS NULL THEN
                             lr_ben205.SELF_MON2 := NVL(F_BEN_HI_LONGTERMCARE_MON(
                                                            lv_cpn201.ENTER_CD
                                                           ,lv_cpn201.ORD_EYMD
                                                           ,F_BEN_HI_SELF_MON(P_ENTER_CD
                                                                             ,lv_cpn201.ORD_EYMD
                                                                             ,ln_reward_tot_mon)
                                                           ),0);
                             -- 노인장기요양보험 감면율 적용(10단위 절사)
                             IF NVL(ln_reduction_rate2,0) <> 0 THEN
                                lr_ben205.SELF_MON2 := TRUNC(lr_ben205.SELF_MON2 * (1 - (ln_reduction_rate2 / 100)),-1);
                             END IF;

                         --END IF;

                         -- 노인장기요양보험 감면율 적용(화면에 로직 적용되여 주석처리)
                         --lr_ben205.SELF_MON2 := lr_ben205.SELF_MON2 - ceil((lr_ben205.SELF_MON2 * (nvl(ln_reduction_rate2,0)/100))/10)*10;
                         lr_ben205.COMP_MON2 := lr_ben205.SELF_MON2;

                         -- 건강보험 감면율 적용(10단위 절사)
                         /*--화면에 로직 적용되어 주석처리
                         IF NVL(ln_reduction_rate,0) <> 0 THEN
                            lr_ben205.SELF_MON := TRUNC(lr_ben205.SELF_MON * (1 - (ln_reduction_rate / 100)),-1);
                         END IF;
                         */
                         lr_ben205.SELF_MON1 := lr_ben205.SELF_MON;
                         lr_ben205.COMP_MON1 := lr_ben205.COMP_MON;

                         lr_ben205.SELF_MON := lr_ben205.SELF_MON1 + lr_ben205.SELF_MON2;
                         lr_ben205.COMP_MON := lr_ben205.COMP_MON1 + lr_ben205.COMP_MON2;
                      END IF;

                      -- 추가본인부담액, 추가회사부담액, 환급본인부담액, 환금회사부담액 추출
                      BEGIN

                        SELECT SUM(NVL(MON5,0)), SUM(NVL(MON6,0)) --건강보험료_월보험료, 요양보험료_월보험료
                              ,SUM(NVL(MON1,0)), SUM(NVL(MON2,0)), SUM(NVL(MON3,0)), SUM(NVL(MON4,0))
                              ,SUM(NVL(ADD_SELF_MON,0)), SUM(NVL(ADD_COMP_MON,0))
                              ,SUM(NVL(RETURN_SELF_MON,0)), SUM(NVL(RETURN_COMP_MON,0))
                              ,SUM(NVL(ADD_SELF_MON2,0)), SUM(NVL(ADD_COMP_MON2,0))
                          INTO ln_mon5, ln_mon6
                              ,ln_mon1, ln_mon2, ln_mon3, ln_mon4
                              ,ln_add_self_mon, ln_add_comp_mon
                              ,ln_return_self_mon, ln_return_comp_mon
                              ,ln_add_self_mon2, ln_add_comp_mon2
                          FROM TBEN009
                         WHERE ENTER_CD = P_ENTER_CD
                           AND BENEFIT_BIZ_CD = '15'
                           AND PAY_ACTION_CD = P_PAY_ACTION_CD
                           AND SABUN = C_CPN203.SABUN;

                       EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                             ln_add_self_mon := 0; ln_add_comp_mon := 0;
                             ln_return_self_mon := 0; ln_return_comp_mon := 0;
                             ln_add_self_mon2 := 0; ln_add_comp_mon2 := 0;
                          WHEN OTHERS THEN
                             ln_add_self_mon := 0; ln_add_comp_mon := 0;
                             ln_return_self_mon := 0; ln_return_comp_mon := 0;
                             ln_add_self_mon2 := 0; ln_add_comp_mon2 := 0;
                      END;

                      /*메뉴가 건강보험 추가/환급관리인데 추가/환급액만 따로 업로드하고 싶어도 월보험료칸에 다시 한번 금액을 확인해서 업로드해야하는 불편함이 있음.
                        그래서 월보험료는 계산되지 않게 주석처리 함. vong 20180620
                      --건강보험료_월보험료
                      IF ln_mon5 IS NOT NULL THEN
                       lr_ben205.SELF_MON1 := ln_mon5;
                      END IF;

                      --요양보험료_월보험료
                      IF ln_mon6 IS NOT NULL THEN
                       lr_ben205.SELF_MON2 := ln_mon6;
                      END IF;
                      */
                      -- 건강보험료_정산금
                      IF ln_mon1 IS NOT NULL AND NVL(ln_mon1,0) <> 0 THEN
                       lr_ben205.MON1 := ln_mon1;
                      END IF;
                      -- 요양보험료_정산금
                      IF ln_mon2 IS NOT NULL AND NVL(ln_mon2,0) <> 0  THEN
                       lr_ben205.MON2 := ln_mon2;
                      END IF;
                      -- 건강보험료_환급이자
                      IF ln_mon3 IS NOT NULL AND NVL(ln_mon3,0) <> 0 THEN
                       --lr_ben205.MON3 := ln_mon3;
                       lr_ben205.MON1 := NVL(lr_ben205.MON1,0) + ln_mon3; -- 정산금에 합산처리
                      END IF;
                      -- 요양보험료_환급이자
                      IF ln_mon4 IS NOT NULL AND NVL(ln_mon4,0) <> 0 THEN
                       --lr_ben205.MON4 := ln_mon4;
                       lr_ben205.MON2 := NVL(lr_ben205.MON2,0) + ln_mon4; -- 정산금에 합산처리
                      END IF;

                      -- 본인 추가/환급부담액 총액
                      lr_ben205.add_self_mon := ln_add_self_mon + ln_add_self_mon2;

                      -- 본인 추가/환급부담액
                      lr_ben205.ADD_SELF_MON1 := ln_add_self_mon;

                      -- 본인 노인장기요양보험 추가/환급부담액
                      lr_ben205.ADD_SELF_MON2 := ln_add_self_mon2;

                      -- 회사 추가/환급부담액 총액
                      lr_ben205.add_comp_mon := ln_add_comp_mon + ln_add_comp_mon2;

                      -- 회사 추가/환급부담액
                      lr_ben205.ADD_COMP_MON1 := ln_add_comp_mon;

                      -- 회사 노인장기요양보험 추가/환급부담액
                      lr_ben205.ADD_COMP_MON2 := ln_add_comp_mon2;

                      -- 최종 추가본인부담액이 0일 경우 사회보험공제처리코드값을 '10'(일반공제)로 한다.
                      IF (lr_ben205.add_self_mon = 0) THEN
                        lr_ben205.soc_deduct_cd := '10';
                      -- 최종 추가본인부담액이 0보다 클 경우 사회보험공제처리코드값을 '25'(환급금발생)로 한다.
                      ELSIF (lr_ben205.add_self_mon < 0) THEN
                        lr_ben205.soc_deduct_cd := '25';
                      -- 최종 추가본인부담액이 0보다 작을 경우 사회보험공제처리코드값을 '20'(추가공제발생)로 한다.
                      ELSIF (lr_ben205.add_self_mon > 0) THEN
                        lr_ben205.soc_deduct_cd := '20';
                      END IF;
                       -- 정리된 자료를 건강보험공제이력 테이블에 INSERT한다.
                      BEGIN

                        IF NOT (lr_ben205.self_mon1 = 0 AND lr_ben205.self_mon2 = 0 AND lr_ben205.ADD_SELF_MON1 = 0 AND lr_ben205.ADD_SELF_MON2 = 0
                                AND lr_ben205.MON1 = 0 AND LR_BEN205.MON2 = 0 AND lr_ben205.MON3 = 0 AND LR_BEN205.MON4 = 0) THEN
                            INSERT INTO TBEN777 (
                                 ENTER_CD --회사구분(TORG900)
                               , PAY_ACTION_CD --급여계산코드(TCPN201)
                               , SABUN --사원번호
                               , BEN_GUBUN --기타복리후생이력생성구분(B10230)
                               , SEQ --순번
                               , BUSINESS_PLACE_CD --사업장코드(TCPN121)
                               , MON1 --금액1
                               , MON2 --금액2
                               , MON3 --금액3
                               , MON4 --금액4
                               , MON5 --금액5
                               , MON6 --금액6
                               , MON7 --금액7
                               , MON8 --금액8
                               , MON9 --금액9
                               , MON10 --금액10
                               , MON11 --금액11
                               , MON12 --금액12
                               , MEMO
                               , CHKDATE --최종수정시간
                               , CHKID --최종수정자
                            )VALUES(
                               p_enter_cd
                              ,p_pay_action_cd
                              ,c_cpn203.sabun
                              ,ln_benefit_biz_cd
                              ,(SELECT NVL(MAX(TO_NUMBER(SEQ)),0)+1 AS SEQ FROM TBEN777 WHERE ENTER_CD =P_ENTER_CD)
                              --,C_MAP.business_place_cd
                              ,c_cpn203.business_place_cd
                              ,lr_ben205.self_mon1 -- 1 건강보험료본인
                              ,lr_ben205.comp_mon1 -- 2 건강보험료회사
                              ,lr_ben205.self_mon2 -- 3 노인장기요양보험본인
                              ,lr_ben205.comp_mon2 -- 4 노인장기요양보험회사
                              ,lr_ben205.ADD_SELF_MON1 -- 5 건강보험_본인_추가/환급
                              ,lr_ben205.ADD_COMP_MON1 -- 6 건강보험_회사_추가/환급
                              ,lr_ben205.ADD_SELF_MON2 -- 7 노인장기요양_본인_추가/환급
                              ,lr_ben205.ADD_COMP_MON2 -- 8 노인장기요양_회사_추가/환급
                              ,lr_ben205.MON1 --9 건강보험_정산
                              ,lr_ben205.MON2 --10 요양보험_정산
                              ,lr_ben205.MON3 --11 건강보험_환급이자
                              ,lr_ben205.MON4 --12 요양보험_환급이자
                              ,LN_BIGO
                              ,SYSDATE
                              ,p_chkid
                              );

                           ln_rcnt := ln_rcnt + 1;
                       END IF;

                     EXCEPTION
                        WHEN OTHERS THEN
                           ROLLBACK;
                           P_SQLCODE := TO_CHAR(SQLCODE);
                           P_SQLERRM := '사번=> ' || c_cpn203.sabun || ' 건강보험공제이력 테이블(TBEN205) INSERT Error ..' || chr(10) || SQLERRM;
                           P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'15-2',P_SQLERRM, P_CHKID);
                           RETURN;
                     END;
                 END;
              END LOOP  ; -- 건강보험공제이력 END
              --
           END IF;
         --------------------
         --  국민연금
         --------------------
         WHEN '10' THEN
            -- 국민/건강보험 급여공제방식(A:보수월액, C:공단자료연계)
            lv_ben_cal_type := NVL(F_CPN_GET_GLOVAL_VALUE(P_ENTER_CD, 'BEN_CAL_TYPE', lv_cpn201.PAYMENT_YMD), 'A');
            /* -- 국민연금 급여공제방식(C:공단자료연계) */
            IF lv_ben_cal_type = 'C' THEN
               BEGIN
                IF P_ENTER_CD = 'HX' THEN -- 한진정보통신, 공단자료(사번) 업로드 이용
                  INSERT INTO TBEN777
                  (
                          ENTER_CD --회사구분(TORG900)
                         ,PAY_ACTION_CD --급여계산코드(TCPN201)
                         ,SABUN --사원번호
                         ,BEN_GUBUN --기타복리후생이력생성구분(B10230)
                         ,SEQ --순번
                         ,BUSINESS_PLACE_CD --사업장코드(TCPN121)
                         ,MON1 -- 국민연금본인부담금
                         ,MON3 -- 국민연금정산분
                         ,CHKDATE --최종수정시간
                         ,CHKID --최종수정자
                   )
                   (
                    SELECT ENTER_CD
                          ,PAY_ACTION_CD
                          ,SABUN
                          ,BEN_GUBUN
                          ,(SELECT NVL(MAX(TO_NUMBER(X.SEQ)),0)+ RNUM
                              FROM TBEN777 X
                             WHERE X.ENTER_CD = ENTER_CD
                           ) AS BEN_GUBUN
                          ,BUSINESS_PLACE_CD
                          ,MON1
                          ,MON3
                          ,SYSDATE AS CHKDATE
                          ,P_CHKID AS CHKID
                     FROM (
                            SELECT NVL(T1.ENTER_CD, T2.ENTER_CD) AS ENTER_CD
                                  ,NVL(T1.PAY_ACTION_CD, T2.PAY_ACTION_CD) AS PAY_ACTION_CD
                                  ,NVL(T1.SABUN, T2.SABUN) AS SABUN
                                  ,NVL(T1.BEN_GUBUN, T2.BEN_GUBUN) AS BEN_GUBUN
                                  ,ROW_NUMBER() OVER (ORDER BY NVL(T1.SABUN, T2.SABUN)) AS RNUM
                                  ,NVL(T1.BUSINESS_PLACE_CD, T2.BUSINESS_PLACE_CD) AS BUSINESS_PLACE_CD
                                  ,T1.MON1 -- 본인부담금
                                  ,T2.MON3 -- 정산금
                              FROM ( /* 국민연금 공단자료 */
                                    SELECT A.ENTER_CD
                                          ,A.PAY_ACTION_CD
                                          ,A.SABUN
                                          ,ln_benefit_biz_cd AS BEN_GUBUN
                                          ,ROW_NUMBER() OVER (ORDER BY A.SABUN) AS RNUM
                                          ,A.BUSINESS_PLACE_CD
                                          ,C.MON4 AS MON1
                                      FROM TCPN203 A
                                          ,TCPN201 B
                                          ,TBEN112 C
                                     WHERE A.ENTER_CD      = P_ENTER_CD
                                       AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
                                       AND A.ENTER_CD      = B.ENTER_CD
                                       AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
                                       AND A.ENTER_CD      = C.ENTER_CD
                                       AND A.SABUN         = C.SABUN
                                       AND B.PAY_YM        = C.YM
                                  ) T1 FULL OUTER JOIN
                                  ( /* 국민연금 추가/환급액관리 */
                                    SELECT ENTER_CD
                                          ,PAY_ACTION_CD
                                          ,SABUN
                                          ,BEN_GUBUN
                                          ,ROW_NUMBER() OVER (ORDER BY SABUN) AS RNUM
                                          ,BUSINESS_PLACE_CD
                                          ,MON3
                                      FROM (
                                             SELECT A.ENTER_CD
                                                   ,A.PAY_ACTION_CD
                                                   ,A.SABUN
                                                   ,ln_benefit_biz_cd AS BEN_GUBUN
                                                   ,ROW_NUMBER() OVER (ORDER BY A.SABUN) AS RNUM
                                                   ,A.BUSINESS_PLACE_CD
                                                   ,SUM(NVL(C.ADD_SELF_MON,0)) AS MON3
                                               FROM TCPN203 A
                                                   ,TCPN201 B
                                                   ,TBEN009 C
                                              WHERE A.ENTER_CD      = P_ENTER_CD
                                                AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
                                                AND A.ENTER_CD      = B.ENTER_CD
                                                AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
                                                AND A.ENTER_CD      = C.ENTER_CD
                                                AND A.PAY_ACTION_CD = C.PAY_ACTION_CD
                                                AND A.SABUN         = C.SABUN
                                                AND C.BENEFIT_BIZ_CD = ln_benefit_biz_cd
                                             GROUP BY A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BUSINESS_PLACE_CD
                                          )
                                  ) T2 ON T1.ENTER_CD = T2.ENTER_CD AND T1.PAY_ACTION_CD = T2.PAY_ACTION_CD AND T1.SABUN = T2.SABUN
                         )
                    );
                
                ELSE
                  INSERT INTO TBEN777
                  (
                          ENTER_CD --회사구분(TORG900)
                         ,PAY_ACTION_CD --급여계산코드(TCPN201)
                         ,SABUN --사원번호
                         ,BEN_GUBUN --기타복리후생이력생성구분(B10230)
                         ,SEQ --순번
                         ,BUSINESS_PLACE_CD --사업장코드(TCPN121)
                         ,MON1 -- 국민연금본인부담금
                         ,MON3 -- 국민연금정산분
                         ,CHKDATE --최종수정시간
                         ,CHKID --최종수정자
                   )
                   (
                    SELECT ENTER_CD
                          ,PAY_ACTION_CD
                          ,SABUN
                          ,BEN_GUBUN
                          ,(SELECT NVL(MAX(TO_NUMBER(X.SEQ)),0)+ RNUM
                              FROM TBEN777 X
                             WHERE X.ENTER_CD = ENTER_CD
                           ) AS BEN_GUBUN
                          ,BUSINESS_PLACE_CD
                          ,MON1
                          ,MON3
                          ,SYSDATE AS CHKDATE
                          ,P_CHKID AS CHKID
                     FROM (
                            SELECT NVL(T1.ENTER_CD, T2.ENTER_CD) AS ENTER_CD
                                  ,NVL(T1.PAY_ACTION_CD, T2.PAY_ACTION_CD) AS PAY_ACTION_CD
                                  ,NVL(T1.SABUN, T2.SABUN) AS SABUN
                                  ,NVL(T1.BEN_GUBUN, T2.BEN_GUBUN) AS BEN_GUBUN
                                  ,ROW_NUMBER() OVER (ORDER BY NVL(T1.SABUN, T2.SABUN)) AS RNUM
                                  ,NVL(T1.BUSINESS_PLACE_CD, T2.BUSINESS_PLACE_CD) AS BUSINESS_PLACE_CD
                                  ,T1.MON1 -- 본인부담금
                                  ,T2.MON3 -- 정산금
                              FROM ( /* 국민연금 공단자료 */
--                                    SELECT A.ENTER_CD
--                                          ,A.PAY_ACTION_CD
--                                          ,A.SABUN
--                                          ,ln_benefit_biz_cd AS BEN_GUBUN
--                                          ,ROW_NUMBER() OVER (ORDER BY A.SABUN) AS RNUM
--                                          ,A.BUSINESS_PLACE_CD
--                                          ,C.MON4 AS MON1
--                                      FROM TCPN203 A
--                                          ,TCPN201 B
--                                          ,TBEN112 C
--                                     WHERE A.ENTER_CD      = P_ENTER_CD
--                                       AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
--                                       AND A.ENTER_CD      = B.ENTER_CD
--                                       AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
--                                       AND A.ENTER_CD      = C.ENTER_CD
--                                       AND A.SABUN         = C.SABUN
--                                       AND B.PAY_YM        = C.YM
                                    /* 국민연금 등급변경관리 자료 2025.01.14 한진관광, 토파스 국민연금 급여연계*/
                                        SELECT A.ENTER_CD,
                                               A.PAY_ACTION_CD,
                                               A.SABUN,
                                               ln_benefit_biz_cd AS BEN_GUBUN,
                                               ROW_NUMBER() OVER (ORDER BY A.SABUN) AS RNUM,
                                               A.BUSINESS_PLACE_CD,
                                               C.MON2 AS MON1
                                        FROM TCPN203 A
                                        JOIN TCPN201 B
                                            ON A.ENTER_CD = B.ENTER_CD
                                           AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
                                        JOIN (
                                                SELECT T0.ENTER_CD,
                                                       F_COM_GET_SABUN3(T0.ENTER_CD, T0.RES_NO) AS SABUN,
                                                       T0.MON2
                                                 FROM TBEN011 T0
                                                 WHERE T0.ENTER_CD = P_ENTER_CD
                                                    AND T0.BENEFIT_BIZ_CD = ln_benefit_biz_cd
                                                    AND T0.SDATE = (
                                                     SELECT T2.SDATE
                                                       FROM TBEN011 T2
                                                      WHERE T2.ENTER_CD = T0.ENTER_CD
                                                        AND T2.BENEFIT_BIZ_CD = T0.BENEFIT_BIZ_CD
                                                        AND T2.RES_NO = T0.RES_NO
                                                      ORDER BY T2.SDATE DESC
                                                      FETCH FIRST 1 ROWS ONLY
                                                    )
                                               ) C
                                            ON A.ENTER_CD = C.ENTER_CD
                                           AND A.SABUN = C.SABUN
                                        WHERE A.ENTER_CD = P_ENTER_CD
                                           AND A.PAY_ACTION_CD = P_PAY_ACTION_CD


                                  ) T1 FULL OUTER JOIN
                                  ( /* 국민연금 추가/환급액관리 */
                                    SELECT ENTER_CD
                                          ,PAY_ACTION_CD
                                          ,SABUN
                                          ,BEN_GUBUN
                                          ,ROW_NUMBER() OVER (ORDER BY SABUN) AS RNUM
                                          ,BUSINESS_PLACE_CD
                                          ,MON3
                                      FROM (
                                             SELECT A.ENTER_CD
                                                   ,A.PAY_ACTION_CD
                                                   ,A.SABUN
                                                   ,ln_benefit_biz_cd AS BEN_GUBUN
                                                   ,ROW_NUMBER() OVER (ORDER BY A.SABUN) AS RNUM
                                                   ,A.BUSINESS_PLACE_CD
                                                   ,SUM(NVL(C.ADD_SELF_MON,0)) AS MON3
                                               FROM TCPN203 A
                                                   ,TCPN201 B
                                                   ,TBEN009 C
                                              WHERE A.ENTER_CD      = P_ENTER_CD
                                                AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
                                                AND A.ENTER_CD      = B.ENTER_CD
                                                AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
                                                AND A.ENTER_CD      = C.ENTER_CD
                                                AND A.PAY_ACTION_CD = C.PAY_ACTION_CD
                                                AND A.SABUN         = C.SABUN
                                                AND C.BENEFIT_BIZ_CD = ln_benefit_biz_cd
                                             GROUP BY A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BUSINESS_PLACE_CD
                                          )
                                  ) T2 ON T1.ENTER_CD = T2.ENTER_CD AND T1.PAY_ACTION_CD = T2.PAY_ACTION_CD AND T1.SABUN = T2.SABUN
                         )
                    );
                END IF;
               EXCEPTION
                  WHEN OTHERS THEN
                     ROLLBACK;
                     p_sqlcode := TO_CHAR(SQLCODE);
                     p_sqlerrm := '[급여일자코드 : ' || P_PAY_ACTION_CD || '] 국민연금공단자료 공제금액 INSERT Error =>' || SQLERRM;
                     P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'10-1',P_SQLERRM, P_CHKID);
                     RETURN;
               END;

            /* -- 국민연금 급여공제방식(A:보수월액) */
            ELSE
               -- 국민연금 공제자료 생성
               --FOR c_cpn203 IN csr_cpn203 (C_BP_CD => C_MAP.BUSINESS_PLACE_CD) LOOP
               FOR c_cpn203 IN csr_cpn203 LOOP
                  BEGIN
                     lr_ben105         := NULL;
                     ln_reward_tot_mon := 0;
                     ln_add_self_mon   := 0;
                     ln_add_comp_mon   := 0;
                     ln_return_self_mon := 0;
                     ln_return_comp_mon := 0;
                     LN_BIGO := '';
                     lv_ded_yn         := 'Y'; -- 국민/건보 대상여부(휴직자 체크용) ([한국공항]용)

                     /* 사번 및 지급일자를 기준으로 Date Track을 적용하여 국민연금불입상태(soc_state_cd)가 정상공제('A10')인 국민연금변동이력의 등급(grade)을 읽어온다.
                         TBEN103 : 국민연금 변동 이력 */
                     --등급 추출
                     BEGIN
                        SELECT MAX(SEQ),MAX(SDATE)
                          INTO ln_max_seq, lv_sdate
                          FROM TBEN103
                         WHERE ENTER_CD = P_ENTER_CD
                           AND SABUN    = c_cpn203.SABUN
                           AND SDATE    = ( SELECT MAX(SDATE)
                                              FROM TBEN103
                                             WHERE ENTER_CD = P_ENTER_CD
                                               --AND lv_cpn201.PAY_YM||'01' BETWEEN SDATE AND NVL(EDATE, '99991231')
                                               AND lv_cpn201.ORD_EYMD BETWEEN SDATE AND NVL(EDATE, '99991231')
                                               AND SABUN = c_cpn203.SABUN
                                  )
                          AND NVL(SOC_STATE_CD, 'A10') = 'A10';  -- 정상공제일 경우

                         -- 1일자 입사가 아닐경우 국민연금를 생성하지 않는다. (전월퇴사자는 제외)
                         IF (lv_cpn201.pay_ym || '01' < c_cpn203.EMP_YMD) OR (c_cpn203.RET_YMD < lv_cpn201.pay_ym || '01') THEN
                            ln_max_seq := NULL;
                         END IF;

                         -- 급여월 1일자 기준 60세 이상 대상자 국민연금 공제 제외
                         lv_ded_60_yn := 'N';
                         BEGIN
                            SELECT 'Y'
                              INTO lv_ded_60_yn
                              FROM (
                                     SELECT F_COM_GET_AGE(A.ENTER_CD,'',A.RES_NO,lv_cpn201.PAY_YM || '01') AS AGE
                                       FROM THRM100 A
                                      WHERE A.ENTER_CD = P_ENTER_CD
                                        AND A.SABUN    = c_cpn203.SABUN
                                   ) X
                             WHERE X.AGE >= 60
                            ;
                         EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                               lv_ded_60_yn := 'N';
                            WHEN OTHERS THEN
                               lv_ded_60_yn := 'N';
                         END;
                         -- 급여월 1일자 기준 60세 이상 대상자 국민연금 공제 제외
                         IF lv_ded_60_yn = 'Y' THEN
                            ln_max_seq := NULL;
                         END IF;

                         --------------------------------------------------------------------
                         -- [한국공항] 1~15일 휴직자, 16일~말일 복직자 국민/건보 공제 대상에서 제외
                         --------------------------------------------------------------------
                         IF P_ENTER_CD = 'KS' THEN
                            BEGIN
                                 SELECT 'N'
                                   INTO lv_ded_yn
                                   FROM (
                                          SELECT ENTER_CD, SABUN, GREATEST(SDATE,lv_cpn201.PAY_YM || '01') AS SDATE, LEAST(EDATE, TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD')) AS EDATE
                                            FROM (
                                                   SELECT ENTER_CD, SABUN, ORD_DETAIL_CD, MIN(SDATE) AS SDATE, MAX(EDATE) AS EDATE
                                                     FROM (
                                                           SELECT X.ENTER_CD, X.SABUN, X.SDATE, X.EDATE,
                                                                  (SELECT Z.ORD_DETAIL_CD FROM THRM191 Z
                                                                    WHERE Z.ENTER_CD = X.ENTER_CD
                                                                      AND Z.SABUN = X.SABUN
                                                                      AND Z.ORD_TYPE_CD = 'LAT_UPL_KOR' -- 발령종류 (LAT_UPL_KOR : 휴직)
                                                                      AND (Z.ORD_YMD || Z.APPLY_SEQ) = (
                                                                                        SELECT MAX(Y.ORD_YMD || Y.APPLY_SEQ) FROM THRM191 Y
                                                                                         WHERE Y.ENTER_CD = Z.ENTER_CD
                                                                                           AND Y.SABUN = Z.SABUN
                                                                                           AND Y.ORD_YMD <= X.SDATE
                                                                                           AND Y.ORD_TYPE_CD = 'LAT_UPL_KOR' -- 발령종류 (LAT_UPL_KOR : 휴직)
                                                                                           -- 휴직연장 발령코드 제외 (의병연장, 병가연장, 휴직연장, 육아휴직연장, 산재연장)
                                                                                           AND Y.ORD_DETAIL_CD NOT IN ('LAT_UPL_KOR52'
                                                                                                                     , 'LAT_UPL_KOR30'
                                                                                                                     , 'LAT_UPL_KOR31'
                                                                                                                     , 'LAT_UPL_KOR50'
                                                                                                                     , 'LAT_UPL_KOR51')
                                                                                      )
                                                                  ) AS ORD_DETAIL_CD,
                                                                  SUM(NVL(TO_DATE(X.SDATE,'YYYYMMDD')-TO_DATE(X.LAG_EDATE,'YYYYMMDD')-1,0)) OVER (PARTITION BY X.ENTER_CD, X.SABUN ORDER BY X.ENTER_CD, X.SABUN, X.SDATE) AS DIFF_DAYS
                                                             FROM (
                                                                   SELECT A.ENTER_CD, A.SABUN, A.SDATE, A.EDATE,
                                                                          LAG(A.EDATE) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.ENTER_CD, A.SABUN, A.SDATE) AS LAG_EDATE
                                                                     FROM THRM151 A
                                                                    WHERE A.ENTER_CD = P_ENTER_CD
                                                                      AND A.SABUN    = c_cpn203.sabun
                                                                      AND A.STATUS_CD = 'CA' -- 재직상태 휴직 체크
                                                                      AND EXISTS (SELECT C.SABUN FROM THRM151 C
                                                                                   WHERE C.ENTER_CD = A.ENTER_CD
                                                                                     AND C.SABUN    = A.SABUN
                                                                                     AND C.SDATE   <= TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD')
                                                                                     AND C.EDATE   >= lv_cpn201.PAY_YM || '01'
                                                                                     AND C.STATUS_CD IN ('CA') -- 재직상태 CA(휴직)
                                                                                  )
                                                                  ) X
                                                          )
                                                   GROUP BY DIFF_DAYS, ENTER_CD, SABUN, ORD_DETAIL_CD
                                                 ) T1
                                           WHERE T1.SDATE   <= TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD')
                                             AND T1.EDATE   >= lv_cpn201.PAY_YM || '01'
                                             AND T1.ORD_DETAIL_CD NOT IN ('LAT_UPL_KOR48', 'LAT_UPL_KOR49') /* LAT_UPL_KOR48(병가), LAT_UPL_KOR49(산재)는 제외 24.04.17 */
                                            -- AND T1.ORD_DETAIL_CD NOT IN ('LAT_UPL_KOR48', 'LAT_UPL_KOR49') /* LAT_UPL_KOR48(병가)는 제외 */
                                        UNION ALL
                                        SELECT A.ENTER_CD
                                              ,A.SABUN
                                              ,(CASE WHEN A.SDATE <= lv_cpn201.PAY_YM || '01' THEN lv_cpn201.PAY_YM || '01' ELSE A.SDATE END) AS SDATE
                                              ,(CASE WHEN NVL(A.EDATE, '99991231') >= TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD') THEN TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD') ELSE A.EDATE END) AS EDATE
                                          FROM THRM129 A, TSYS005 B
                                         WHERE A.ENTER_CD = P_ENTER_CD
                                           AND A.SABUN    = c_cpn203.sabun
                                           AND A.ENTER_CD = B.ENTER_CD
                                           AND A.PUNISH_CD = B.CODE
                                           AND B.GRCODE_CD = 'H20270' -- 징계코드
                                           AND B.NOTE1     = 'Y'      -- 비고1 (정직 징계코드여부)
                                           AND A.SDATE   <= TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM,'YYYYMM')),'YYYYMMDD')
                                           AND NVL(A.EDATE, '99991231') >= lv_cpn201.PAY_YM || '01'
                                        ) T
                                  WHERE (
                                         (T.SDATE <= lv_cpn201.PAY_YM || '15' AND (TO_DATE(T.EDATE,'YYYYMMDD') - TO_DATE(T.SDATE,'YYYYMMDD') + 1) >= 15) -- 1~15일 휴직자 체크
                                     OR  (T.SDATE <= lv_cpn201.PAY_YM || '01' AND T.EDATE >= lv_cpn201.PAY_YM || '16' AND (TO_DATE(T.EDATE,'YYYYMMDD') - TO_DATE(T.SDATE,'YYYYMMDD') + 1) >= 15) -- 16~말일자 복직자 체크
                                        );
                            EXCEPTION
                               WHEN NO_DATA_FOUND THEN
                                  lv_ded_yn := 'Y';
                               WHEN OTHERS THEN
                                  lv_ded_yn := 'Y';
                            END;

                            IF lv_ded_yn = 'N' THEN
                               ln_max_seq := NULL;
                            END IF;
                         END IF;

                        SELECT GRADE, NVL(REWARD_TOT_MON,0), NVL(MON1,F_BEN_NP_SELF_MON(ENTER_CD,lv_cpn201.ORD_EYMD,REWARD_TOT_MON))
                          INTO lr_ben105.GRADE, ln_reward_tot_mon, lr_ben105.SELF_MON
                          FROM TBEN103
                         WHERE ENTER_CD = P_ENTER_CD
                           AND SABUN    = c_cpn203.SABUN
                           AND SEQ      = ln_max_seq
                           AND SDATE    = lv_sdate;

                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                           lr_ben105.GRADE := '';
                           ln_reward_tot_mon := 0;
                           lr_ben105.SELF_MON := 0;
                        WHEN OTHERS THEN
                           lr_ben105.GRADE := '';
                           ln_reward_tot_mon := 0;
                           lr_ben105.SELF_MON := 0;
                     END;

                     /* 본인부담액(self_mon) 산출, 회사부담액(comp_mon) 추출
                        2008.01.01 부로 등급이 아닌 기준소득월액 * 국민연금요율 산정방식으로 변경 */
                     IF lv_sdate < '20080101' THEN
                       lr_ben105.self_mon := 0;
                       lr_ben105.comp_mon := 0;

                     ELSE
                        lr_ben105.GRADE := NULL;
                        lr_ben105.SELF_MON := lr_ben105.SELF_MON;
                        lr_ben105.COMP_MON := lr_ben105.SELF_MON;
                     END IF;
                     -- 추가본인부담액, 추가회사부담액, 환급본인부담액, 환금회사부담액 추출
                     BEGIN

                       SELECT MON7, ADD_SELF_MON, ADD_COMP_MON, RETURN_SELF_MON, RETURN_COMP_MON, BIGO
                         INTO ln_mon7, ln_add_self_mon, ln_add_comp_mon, ln_return_self_mon, ln_return_comp_mon, LN_BIGO
                         FROM TBEN009
                        WHERE ENTER_CD       = P_ENTER_CD
                          AND BENEFIT_BIZ_CD = '10'
                          AND PAY_ACTION_CD  = P_PAY_ACTION_CD
                          AND SABUN          = c_cpn203.SABUN;
                     EXCEPTION
                        WHEN OTHERS THEN
                           ln_add_self_mon := 0;
                           ln_add_comp_mon := 0;
                           ln_return_self_mon := 0;
                           ln_return_comp_mon := 0;
                     END;

                     -- 본인부담액 예외처리(ln_mon7)이 NULL이 아닌경우 예외처리
                      /*메뉴가 국민연금 추가/환급관리인데 추가/환급액만 따로 업로드하고 싶어도 월보험료칸에 다시 한번 금액을 확인해서 업로드해야하는 불편함이 있음.
                        그래서 월보험료는 계산되지 않게 주석처리 함. 입력시에도 Null이 아닌 '0'이 default이기 때문에 빈 값으로 넣는 것도 불편함.
                      --국민연금_월보험료
                     IF ln_mon7 IS NOT NULL THEN
                       lr_ben105.SELF_MON := ln_mon7;
                     END IF;
                     */

   /*                  -- 추가본인부담액에서 환급본인부담액을 뺀 결과값을 최종 추가본인부담액(add_self_mon)으로 한다.
                     lr_ben105.ADD_SELF_MON := ln_add_self_mon - ln_return_self_mon;

                     -- 추가회사부담액에서 환급회사부담액을 뺀 결과값을 최종 추가회사부담액(add_comp_mon)으로 한다.
                     lr_ben105.ADD_COMP_MON := ln_add_comp_mon - ln_return_comp_mon;

                     -- 최종 추가본인부담액이 0일 경우 사회보험공제처리코드값을 '10'(일반공제)로 한다.
                     IF (lr_ben105.ADD_SELF_MON = 0) THEN
                       lr_ben105.SOC_DEDUCT_CD := '10';
                     -- 최종 추가본인부담액이 0보다 클 경우 사회보험공제처리코드값을 '25'(환급금발생)로 한다.
                     ELSIF (lr_ben105.ADD_SELF_MON < 0) THEN
                       lr_ben105.SOC_DEDUCT_CD := '25';
                     -- 최종 추가본인부담액이 0보다 작을 경우 사회보험공제처리코드값을 '20'(추가공제발생)로 한다.
                     ELSIF (lr_ben105.ADD_SELF_MON > 0) THEN
                       lr_ben105.SOC_DEDUCT_CD := '20';
                     END IF;*/

                     -- 정리된 자료를 국민연금공제이력 테이블에 INSERT한다.
                     BEGIN
                       IF NOT (lr_ben105.SELF_MON = 0 AND lr_ben105.COMP_MON = 0 AND ln_add_self_mon = 0) THEN
                            INSERT INTO TBEN777 (
                                 ENTER_CD --회사구분(TORG900)
                               , PAY_ACTION_CD --급여계산코드(TCPN201)
                               , SABUN --사원번호
                               , BEN_GUBUN --기타복리후생이력생성구분(B10230)
                               , SEQ --순번
                               , BUSINESS_PLACE_CD --사업장코드(TCPN121)
                               , MON1 --금액1
                               , MON2 --금액2
                               , MON3 --금액3
                               --, MON4 --금액4
                               , MEMO
                               , CHKDATE --최종수정시간
                               , CHKID --최종수정자
                            )
                           VALUES
                           (
                               P_ENTER_CD
                             , P_PAY_ACTION_CD
                             , c_cpn203.SABUN
                             , ln_benefit_biz_cd
                             ,(SELECT NVL(MAX(TO_NUMBER(SEQ)),0)+1 AS SEQ FROM TBEN777 WHERE ENTER_CD =P_ENTER_CD)
                             --, C_MAP.BUSINESS_PLACE_CD
                             ,c_cpn203.business_place_cd
                             , LR_BEN105.SELF_MON -- 1. 국민연금 개인부담금
                             , LR_BEN105.COMP_MON -- 2. 국민연금 회사부담금
                             , ln_add_self_mon --3.국민연금 정산 개인부담금
                             --, LR_BEN105.ADD_COMP_MON --4.국민연금 정산 회사부담금
                             , LN_BIGO
                             , SYSDATE
                             , p_chkid
                           );

                           ln_rcnt := ln_rcnt + 1;
                      END IF;

                         EXCEPTION
                            WHEN OTHERS THEN
                              ROLLBACK;
                              p_sqlcode := TO_CHAR(SQLCODE);
                              p_sqlerrm := '급여일자코드 : ' || P_PAY_ACTION_CD || ' 사번=> ' || c_cpn203.SABUN || ' 국민연금공제이력 테이블(TBEN105) INSERT Error =>' || SQLERRM;
                              P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'10-2',P_SQLERRM, P_CHKID);
                              RETURN;
                    END;
                END;
              END LOOP  ; -- 국민연금공제이력 END
              --
            END IF;

         --------------------
         -- 고용보험
         --------------------
         WHEN '20' THEN
            -- 고용보험 급여공제방식(A:보수월액, C:공단자료연계)
            lv_ben_cal_type := NVL(F_CPN_GET_GLOVAL_VALUE(P_ENTER_CD, 'BEN_CAL_TYPE', lv_cpn201.PAYMENT_YMD), 'A');
            /* -- 고용보험 급여공제방식(C:공단자료연계) */
            IF lv_ben_cal_type = 'C' THEN
               BEGIN
                  INSERT INTO TBEN777
                  (
                          ENTER_CD --회사구분(TORG900)
                         ,PAY_ACTION_CD --급여계산코드(TCPN201)
                         ,SABUN --사원번호
                         ,BEN_GUBUN --기타복리후생이력생성구분(B10230)
                         ,SEQ --순번
                         ,BUSINESS_PLACE_CD --사업장코드(TCPN121)
                         ,MON1 -- 고용보험본인부담금
                         ,CHKDATE --최종수정시간
                         ,CHKID --최종수정자
                   )
                   (
                    SELECT ENTER_CD
                          ,PAY_ACTION_CD
                          ,SABUN
                          ,BEN_GUBUN
                          ,(SELECT NVL(MAX(TO_NUMBER(X.SEQ)),0)+ RNUM
                              FROM TBEN777 X
                             WHERE X.ENTER_CD = ENTER_CD
                           ) AS BEN_GUBUN
                          ,BUSINESS_PLACE_CD
                          ,MON1
                          ,SYSDATE AS CHKDATE
                          ,P_CHKID AS CHKID
                     FROM (
                            SELECT T1.ENTER_CD AS ENTER_CD
                                  ,T1.PAY_ACTION_CD AS PAY_ACTION_CD
                                  ,T1.SABUN AS SABUN
                                  ,T1.BEN_GUBUN AS BEN_GUBUN
                                  ,ROW_NUMBER() OVER (ORDER BY T1.SABUN) AS RNUM
                                  ,T1.BUSINESS_PLACE_CD AS BUSINESS_PLACE_CD
                                  ,T1.MON1 -- 고용보험,본인부담금
                              FROM ( /* 고용보험 공단자료 */
                                    /* 고용보험 등급변경관리 자료 2025.01.14 한진관광, 토파스 고용보험 급여연계*/
                                        SELECT A.ENTER_CD,
                                               A.PAY_ACTION_CD,
                                               A.SABUN,
                                               ln_benefit_biz_cd AS BEN_GUBUN,
                                               ROW_NUMBER() OVER (ORDER BY A.SABUN) AS RNUM,
                                               A.BUSINESS_PLACE_CD,
                                               C.MON6 AS MON1
                                        FROM TCPN203 A
                                        JOIN TCPN201 B
                                            ON A.ENTER_CD = B.ENTER_CD
                                           AND A.PAY_ACTION_CD = B.PAY_ACTION_CD
                                        JOIN (
                                                SELECT T0.ENTER_CD,
                                                       F_COM_GET_SABUN3(T0.ENTER_CD, T0.RES_NO) AS SABUN,
                                                       T0.MON6
                                                 FROM TBEN011 T0
                                                 WHERE T0.ENTER_CD = P_ENTER_CD
                                                    AND T0.BENEFIT_BIZ_CD = ln_benefit_biz_cd
                                                    AND T0.SDATE = (
                                                     SELECT T2.SDATE
                                                       FROM TBEN011 T2
                                                      WHERE T2.ENTER_CD = T0.ENTER_CD
                                                        AND T2.BENEFIT_BIZ_CD = T0.BENEFIT_BIZ_CD
                                                        AND T2.RES_NO = T0.RES_NO
                                                      ORDER BY T2.SDATE DESC
                                                      FETCH FIRST 1 ROWS ONLY
                                                    )
                                               ) C
                                            ON A.ENTER_CD = C.ENTER_CD
                                           AND A.SABUN = C.SABUN
                                        WHERE A.ENTER_CD = P_ENTER_CD
                                           AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
                                  ) T1 
                         )
                    );
               EXCEPTION
                  WHEN OTHERS THEN
                     ROLLBACK;
                     p_sqlcode := TO_CHAR(SQLCODE);
                     p_sqlerrm := '[급여일자코드 : ' || P_PAY_ACTION_CD || '] 고용보험공단자료 공제금액 INSERT Error =>' || SQLERRM;
                     P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'10-1',P_SQLERRM, P_CHKID);
                     RETURN;
               END;
            /* -- 고용보험 급여공제방식(A:보수월액) */
            ELSE
                -- 고용보험 공제자료 생성
                --FOR c_cpn203 IN csr_cpn203 (C_BP_CD => c_map.BUSINESS_PLACE_CD) LOOP
                FOR c_cpn203 IN csr_cpn203 LOOP
                    BEGIN
                       lr_ben305         := NULL;
                       ln_max_seq        := 0;
                       ln_reward_tot_mon := 0;
                       ln_add_self_mon   := 0;
                       ln_add_comp_mon   := 0;
                       ln_return_self_mon:= 0;
                       ln_return_comp_mon:= 0;
                       ln_mon1           := 0;
                       ln_mon9           := 0; --월급여에 고용보험료 외에 추가적으로더 납부 또는 공제해야할 것(연말정산분과 별개의 것)
                       LN_BIGO           := '';
    
                       /* 사번 및 지급일자를 기준으로 Date Track을 적용
                          이 중에서 MAX(SEQ)인 자료 중에서
                          고용보험불입상태(soc_state_cd)가 정상공제('A10')인 고용보험변동이력의 등급(grade)을 읽어온다.
                          TBEN303 : 고용보험 변동 이력
                          등급,보수월액 추출 */
                       BEGIN
                          SELECT MAX(SEQ),MAX(SDATE)
                            INTO ln_max_seq, lv_sdate
                            FROM TBEN303
                          WHERE enter_cd = p_enter_cd
                            AND sabun    = c_cpn203.sabun
                            AND sdate    = (SELECT MAX(sdate)
                                              FROM TBEN303
                                             WHERE enter_cd = p_enter_cd
                                               AND lv_cpn201.PAY_YM||TO_CHAR(LAST_DAY(TO_DATE(lv_cpn201.PAY_YM||'01', 'YYYYMMDD')), 'DD') BETWEEN sdate AND NVL(edate, '99991231')
                                               AND sabun = c_cpn203.sabun
                                                 )
                            AND TRIM(NVL(soc_state_cd, 'A10'))  NOT IN ('A15','B90')  -- 대표(사외)이사, 공제제외가 아닐 경우
                              ;
                       EXCEPTION
                          WHEN OTHERS THEN
                             ln_reward_tot_mon := 0;
                             ln_mon1 := 0;
                       END;
    
                       BEGIN
                          -- 기준소득월액, 본인부담금 정보 구하기
                          SELECT NVL(REWARD_TOT_MON,0), NVL(MON1, 0)
                            INTO  ln_reward_tot_mon, ln_mon1
                            FROM TBEN303
                          WHERE ENTER_CD = P_ENTER_CD
                            AND SABUN    = c_cpn203.SABUN
                            AND SEQ      = ln_max_seq
                            AND SDATE    = lv_sdate
                              ;
                       EXCEPTION
                          WHEN OTHERS THEN
                             ln_reward_tot_mon := 0;
                             ln_mon1 := 0;
                       END;
    
                       --lr_ben305.SELF_MON := ln_mon1;
    
                      /*변동이력상에 고용보험 공제금액이 없을경우*/
                      --IF lr_ben305.SELF_MON = 0 OR lr_ben305.SELF_MON IS NULL THEN
                          lr_ben305.SELF_MON := F_BEN_EI_SELF_MON(P_ENTER_CD
                                                                ,lv_cpn201.ORD_EYMD
                                                                ,ln_reward_tot_mon);
                      --END IF;
    
                       -- 정산분(환급/추징) 추출
                       BEGIN
    
                         SELECT ADD_SELF_MON, BIGO, MON9
                           INTO ln_add_self_mon, LN_BIGO, ln_mon9
                           FROM TBEN009
                          WHERE ENTER_CD       = P_ENTER_CD
                            AND BENEFIT_BIZ_CD = '20'
                            AND PAY_ACTION_CD  = P_PAY_ACTION_CD
                            AND SABUN          = C_CPN203.SABUN;
                        EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                              ln_add_self_mon := 0; ln_mon9 := 0;
                           WHEN OTHERS THEN
                              ln_add_self_mon := 0; ln_mon9 := 0;
                       END;
    
                       lr_ben305.ADD_SELF_MON := ln_add_self_mon;
    
                        -- 정리된 자료를 고용보험공제이력 테이블에 INSERT한다.
                       BEGIN
    
                         IF NOT (lr_ben305.SELF_MON = 0 AND lr_ben305.ADD_SELF_MON = 0 AND ln_mon9 = 0) THEN
                             INSERT INTO TBEN777 (
                                  ENTER_CD --회사구분(TORG900)
                                , PAY_ACTION_CD --급여계산코드(TCPN201)
                                , SABUN --사원번호
                                , BEN_GUBUN --기타복리후생이력생성구분(B10230)
                                , SEQ --순번
                                , BUSINESS_PLACE_CD --사업장코드(TCPN121)
                                , MON1 --금액1
                                , MON2 --금액2
                                , MEMO
                                , CHKDATE --최종수정시간
                                , CHKID --최종수정자
                             )VALUES(
                                p_enter_cd
                               ,p_pay_action_cd
                               ,c_cpn203.sabun
                               ,ln_benefit_biz_cd
                               ,(SELECT NVL(MAX(TO_NUMBER(SEQ)),0)+1 AS SEQ FROM TBEN777 WHERE ENTER_CD =P_ENTER_CD)
                               --,C_MAP.business_place_cd
                               ,c_cpn203.business_place_cd
                               ,DECODE(NVL(ln_mon9, 0), 0, NVL(lr_ben305.SELF_MON, 0), NVL(ln_mon9, 0)) -- 1 고용보험료 (예외항목에 있으면 예외항목만 반영)
                               ,lr_ben305.ADD_SELF_MON -- 2 고용보험정산/환급(추가분)
                               ,LN_BIGO
                               ,SYSDATE
                               ,p_chkid
                               );
    
                            ln_rcnt := ln_rcnt + 1;
                        END IF;
    
                      EXCEPTION
                         WHEN OTHERS THEN
                            ROLLBACK;
                            P_SQLCODE := TO_CHAR(SQLCODE);
                            P_SQLERRM := '사번=> ' || c_cpn203.sabun || ' 고용보험공제이력 테이블(TBEN205) INSERT Error ..' || chr(10) || SQLERRM;
                            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'20',P_SQLERRM, P_CHKID);
                            RETURN;
                      END;
                  END;
               END LOOP;
            END IF;-- 고용보험공제이력 END
        WHEN '51' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '52' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '53' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '54' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '55' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '56' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '57' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '58' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '59' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '62' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '63' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '65' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '66' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '67' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '68' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '69' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '70' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '71' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '72' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '73' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '74' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '75' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '76' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '77' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '85' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
		WHEN '86' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        WHEN '88' THEN
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);	
        WHEN '97' THEN --안전건강지원금
        	P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);    
        END CASE;
        /* 에러남 원인 불명
        CASE
         --복리후생 일괄처리
        	WHEN ln_benefit_biz_cd IN('51','52','53','54','55','56','57','58','59','85','62','63','65','66','67','68','69','70','71','72','73','74','75','76','77')
        	THEN P_BEN_PAY_DATA_CRE_LIST(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_cpn201, P_BENEFIT_BIZ_CD, P_BUSINESS_PLACE_CD, P_CHKID);
        END CASE;
        */

         /* 급여관련사항마감관리(TCPN983)의 마감상태(S90003)('10001':작업전, '10003':작업, '10005':마감)를 '10003'(작업)으로 한다. */
         LV_CLOSE_ST := '10003';

         BEGIN
            MERGE INTO TBEN991 A
            USING ( SELECT  P_ENTER_CD       AS ENTER_CD,
                            P_PAY_ACTION_CD  AS PAY_ACTION_CD,
                            P_BENEFIT_BIZ_CD AS BENEFIT_BIZ_CD,
                            --C_MAP.BUSINESS_PLACE_CD AS BUSINESS_PLACE_CD,
                            '1' AS BUSINESS_PLACE_CD,
                            TO_CHAR(SYSDATE, 'YYYYMMDD') AS WORK_SYMD,
                            SYSDATE          AS CHKDATE,
                            P_CHKID          AS CHKID
                      FROM  DUAL    ) B
               ON (     A.ENTER_CD          = B.ENTER_CD
                   AND  A.PAY_ACTION_CD     = B.PAY_ACTION_CD
                   AND  A.BENEFIT_BIZ_CD    = B.BENEFIT_BIZ_CD
                   AND  A.BUSINESS_PLACE_CD = B.BUSINESS_PLACE_CD
                   )
            WHEN MATCHED THEN
                UPDATE SET  A.CLOSE_ST = LV_CLOSE_ST, -- 마감상태(S90003)('10001':작업전, '10003':작업, '10005':마감
                            A.CHKDATE  = SYSDATE,
                            A.CHKID    = P_CHKID
            WHEN NOT MATCHED THEN
                INSERT
                (
                 ENTER_CD, PAY_ACTION_CD, BUSINESS_PLACE_CD, BENEFIT_BIZ_CD, CLOSE_ST, CHKDATE, CHKID
                )
                VALUES
                (
                 B.ENTER_CD, B.PAY_ACTION_CD, B.BUSINESS_PLACE_CD, B.BENEFIT_BIZ_CD, LV_CLOSE_ST, B.CHKDATE, B.CHKID
                );

         EXCEPTION
             WHEN NO_DATA_FOUND THEN
                  NULL;
             WHEN OTHERS THEN
                 ROLLBACK;
                 P_SQLCODE := TO_CHAR(SQLCODE);
                 P_SQLERRM := '[급여일자코드 : ' || P_PAY_ACTION_CD || '],[복리후생구분코드 : ' || ln_benefit_biz_cd || '] 의 급여관련사항마감(TBEN991) 작업시 Error =>' || SQLERRM;
                 P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'90',P_SQLERRM, P_CHKID);
         END;

--    END LOOP; -- 급여사업장 별 작업 END

   P_SQLCODE := 'OK' ;
   P_SQLERRM := '작업이 완료되었습니다.';
   COMMIT;

  P_cnt := ln_rcnt;

EXCEPTION
  WHEN OTHERS THEN
     ROLLBACK;
     P_SQLCODE := TO_CHAR(SQLCODE);
     P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
     P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'100',P_SQLERRM, P_CHKID);
END P_BEN_PAY_DATA_CREATE;