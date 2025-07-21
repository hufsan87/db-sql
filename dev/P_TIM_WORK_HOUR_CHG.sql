create or replace PROCEDURE             P_TIM_WORK_HOUR_CHG (
         P_SQLCODE             OUT VARCHAR2,
         P_SQLERRNM            OUT VARCHAR2,
         P_ENTER_CD             IN VARCHAR2,
         P_S_YMD                IN VARCHAR2,
         P_E_YMD                IN VARCHAR2,
         P_SABUN                IN VARCHAR2, /*NULL이면 전체*/
         P_BUSINESS_PLACE_CD    IN VARCHAR2, /*NULL이면 전체*/
         P_CHKID                IN VARCHAR2
)
IS
/********************************************************************************/
/*                                                                              */
/*                    (c) Copyright ISU System Inc. 2004                        */
/*                           All Rights Reserved                                */
/*                                                                              */
/********************************************************************************/
/*  PROCEDURE NAME : P_TIM_WORK_HOUR_CHG_OSSTEM                                 */
/*                                                                              */
/*                  세콤에서 취합한 데이타를 토대로 근무시간 생성                        */
/********************************************************************************/
/*  [ 참조 TABLE ]                                                                */
/*                                                                              */
/********************************************************************************/
/*  [ 생성 TABLE ]                                                               */
/*                                                                              */
/*     TTIM335 : 근무시간변경이력                                                   */
/*     TTIM337 : 근무시간세부내역_임시                                               */
/********************************************************************************/
/*  [ 삭제 TABLE ]                                                              */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 개요 ]                                                                */
/*                                                                              */
/*
               1. 세콤근무데이타로 부터 근무시간변경이력(TTIM335)으로 데이타 이관
                 : 근태, 근무일, 출근시간, 퇴근시간 등을 등록
               2. 근무시간변경이력에서는 근무일의 근태처리에 대해서 1차적으로 체크함
                 Case1.  출퇴근 데이타가 없을때 TTIM301상의 근태데이타 유무 확인하여 등록
                 Case2. 출퇴근 데이타가 없고 TTIM301상의 데이타도 없으면 무단결근 처리
                 Case3.  근태종류가 반차,  출장,   교육등은 출퇴근기록이 있더라도 등록한다.
               3. 근무시간변경이력에 대해서 근무시간세부내역에 대해서 산출한다.
                 : 일근무상세(TTIM120_V)상에 설정된 근무시간코드를 기준으로 일일근무일정에
                   대한 근무시간을 산출함.(각 근무코드별로 데이타 산출)                                                   */
/********************************************************************************/
/*  [ PRC 호출 ]                                                                */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/*------------------------------------------------------------------------------*/
/* 2014-11-19  Ko.sh          Initial Release                                   */
/* 2023-04-05  JWS            Modify                                            */
/********************************************************************************/

   /* Local Variables */
    LV_BIZ_CD               TSYS903.BIZ_CD%TYPE := 'TIM';
    LV_OBJECT_NM            TSYS903.OBJECT_NM%TYPE := 'P_TIM_WORK_HOUR_CHG';

    /*기본근무(고정값)*/
    LV_WORK_CD              TTIM015.WORK_CD%TYPE := 'S1';

    LV_OUT_WORK_EXIST_YN    VARCHAR(10) := 'N'; /*외근존재여부*/
    LV_OUT_WORK_SHM         VARCHAR(4);  /*외근시작시간*/
    LV_OUT_WORK_EHM         VARCHAR(4);  /*외근종료시간*/

    LV_EX_EMP_YN            VARCHAR2(1) :='N';  /*일근무제외자 여부 (TTIM309)*/
    LV_CHG_WORK_YN          VARCHAR2(1) :='N';  /*출퇴근시간변경 여부 (TTIM345)*/
    LV_IC_ISLAND_YN         TTIM345.IC_ISLAND_YN%TYPE :='N';  /*영종도여부 여부 (TTIM345)*/

    LV_FIX_ST_TIME_YN       VARCHAR2(1) :='N';  /*출근시간고정 여부 (TTIM115)*/
    LV_FIX_ED_TIME_YN       VARCHAR2(1) :='N';  /*퇴근시간고정 여부 (TTIM115)*/
    LV_LOG                  VARCHAR2(4000);

    LV_GNT_CD               TTIM014.GNT_CD%TYPE;
    LV_GNT_WORK_TIME_YN     VARCHAR2(1) := 'N';
    LV_REQUEST_USE_TYPE     TTIM014.REQUEST_USE_TYPE%TYPE;
    LV_HALF_STD_HM          VARCHAR(4);
    LV_HALF_END_HM          VARCHAR(4);

    LV_SUB_REMAIN_TIME      NUMBER;
    LV_TIME_TMP             NUMBER;

    LV_OT_EXIST_YN          VARCHAR2(1) := 'N';
    LV_OT_SHM               VARCHAR(4);
    LV_OT_EHM               VARCHAR(4);
    LN_WEEK_WORK_TIME       NUMBER := 0;

    LV_WEEK_START_YMD       VARCHAR2(8);
    LV_WEEK_END_YMD         VARCHAR2(8);
    
    LV_GNT_WORK_SHM         VARCHAR(4);
    LV_GNT_WORK_EHM         VARCHAR(4);
    
    ------------------------------------------------------------------------------------------------------------------------------
    -- 일근무데이타
    ------------------------------------------------------------------------------------------------------------------------------
   CURSOR CSR_TIMECARD IS
        SELECT /*+ LEADING(Y) */
               X.YMD
             , X.SABUN
             , X.WORK_ORG_CD
             , X.WORK_GRP_CD
             , X.IN_HM
             , X.OUT_HM
             , X.CLOSE_YN
             , Z.TIME_CD, Z.WORK_YN, Z.ABSENCE_CD
             , Z.WORK_YN AS HOL_YN -- 휴일여부
             , NVL(X.SHM, Z.WORK_SHM) AS WORK_SHM -- 근무시작시간
             , NVL(X.EHM, Z.WORK_EHM) AS WORK_EHM -- 근무종료시간
             , TO_CHAR(TO_DATE(X.YMD, 'YYYYMMDD'), 'D') AS DAY
             , X.IN_HM   AS R_IN_HM
             , X.OUT_HM  AS R_OUT_HM
             , X.STIME_CD
             , X.IC_ISLAND_YN
             , X.SHM AS HX_SHM -- 유연근무시작시간(한진정보통신)
             , X.EHM AS HX_EHM -- 유연근무종료시간(한진정보통신)
             --, F_COM_GET_WORKTYPE(Y.ENTER_CD, Y.SABUN, X.YMD) AS WORK_TYPE  -- 직군(A:사무직, B:생산직)
          FROM (
                    SELECT A.ENTER_CD, A.YMD, A.SABUN, A.WORK_ORG_CD, A.WORK_GRP_CD
                         , CASE WHEN NVL(D.UPDATE_YN,'N') = 'Y' AND D.IN_HM IS NOT NULL THEN D.IN_HM  -- [일근무관리에서 인정근무시간을 수정 했으면 해당 인정시간으로.. ]
                                WHEN B.IN_HM IS NOT NULL THEN B.IN_HM
                                ELSE D.IN_HM END  AS IN_HM
                         , CASE WHEN NVL(D.UPDATE_YN,'N') = 'Y' AND D.OUT_HM IS NOT NULL THEN D.OUT_HM  -- [일근무관리에서 인정근무시간을 수정 했으면 해당 인정시간으로.. ]
                                WHEN B.OUT_HM IS NOT NULL THEN B.OUT_HM
                                ELSE D.OUT_HM END  AS OUT_HM
                         , A.TIME_CD
                         , A.BUSINESS_PLACE_CD
                         , NVL(D.CLOSE_YN, 'N') AS CLOSE_YN
                         , A.SHM
                         , A.EHM
                         , A.STIME_CD
                         , B.IC_ISLAND_YN
                         --, B.IN_HM AS TIMECARD_IN_HM
                         --, B.OUT_HM AS TIMECARD_OUT_HM
                      FROM TTIM120_V A, TTIM330 B
                         , TTIM335 D
                     WHERE A.ENTER_CD = P_ENTER_CD
                       AND A.YMD BETWEEN P_S_YMD AND P_E_YMD
                       -- 세콤 출퇴근 기록
                       AND A.ENTER_CD = B.ENTER_CD(+)
                       AND A.YMD      = B.YMD(+)
                       AND A.SABUN    = B.SABUN(+)
                       -- 인정 출퇴근 기록
                       AND A.ENTER_CD = D.ENTER_CD(+)
                       AND A.YMD      = D.YMD(+)
                       AND A.SABUN    = D.SABUN(+)
                       -- 파람 조건
                       AND A.SABUN = NVL(P_SABUN, A.SABUN)
                       AND A.BUSINESS_PLACE_CD = NVL(P_BUSINESS_PLACE_CD, A.BUSINESS_PLACE_CD)
               ) X
             , THRM100 Y
             , (SELECT S.ENTER_CD
                     , S.TIME_CD
                     , S2.STIME_CD
                     , S2.WORK_SHM
                     , S2.WORK_EHM
                     , S.WORK_YN
                     , S.ABSENCE_CD
                  FROM TTIM017 S
                     , TTIM051 S2
                 WHERE 1 =1
                   AND S.ENTER_CD = S2.ENTER_CD
                   AND S.TIME_CD  = S2.TIME_CD
                 ) Z
         WHERE X.ENTER_CD = Y.ENTER_CD
           AND X.SABUN    = Y.SABUN
           AND X.ENTER_CD = Z.ENTER_CD
           AND X.TIME_CD  = Z.TIME_CD
           AND X.STIME_CD = Z.STIME_CD
           AND NVL(X.CLOSE_YN,'N') = 'N'  -- 일근무 마감 상태이면 갱신하지 않음.
           AND NOT EXISTS (
               SELECT 1
                 FROM THRM151 S
                WHERE 1 = 1
                  AND S.ENTER_CD = X.ENTER_CD
                  AND S.SABUN    = X.SABUN
                  AND S.STATUS_CD IN ('RA', 'CA')
                  AND X.YMD BETWEEN S.SDATE AND NVL(S.EDATE, '99991231')
             )
          --AND X.SABUN = '0020182'
      ORDER BY X.YMD
      ;


    ------------------------------------------------------------------------------------------------------------------------------
    -- 일근무 상세
    ------------------------------------------------------------------------------------------------------------------------------
     CURSOR CSR_WORK_DTL (C_YMD VARCHAR2, C_SABUN VARCHAR2, C_SHM VARCHAR2, C_EHM VARCHAR2, C_TIME_CD VARCHAR2) IS
     SELECT WORK_CD
          , DECODE(CD_TYPE
                     , 'T10'/*시간*/, ROUND(F_TIM_WORK_INFO_TEMP_NEW(P_ENTER_CD, C_SABUN, C_YMD, C_SHM, C_EHM, WORK_CD))
                     , 'T20'/*횟수*/, F_TIM_WORK_INFO_CNT_TEMP(P_ENTER_CD, C_SABUN, C_YMD, C_SHM, C_EHM, WORK_CD)
              )  AS HHMM
         , CD_TYPE
     FROM
            (SELECT *
               FROM (
                SELECT A.ENTER_CD
                     , A.WORK_CD
                     , A.CD_TYPE
                     , A.SEQ
                  FROM TTIM015 A
                 WHERE 1 = 1
                   AND A.ENTER_CD = P_ENTER_CD
                   AND (EXISTS (
                       SELECT 1
                         FROM TTIM355 S
                        WHERE 1 = 1
                          AND S.ENTER_CD = A.ENTER_CD
                          AND S.WORK_CD  = A.WORK_CD
                       )
                       OR (P_ENTER_CD = 'KS'
                           AND A.WORK_CD IN ('0077'))
                       /* 예외적으로 추가할 근무코드 추가 */
                       OR A.WORK_CD IN ('T0014')        --휴가시간
                       )
                 ) A
              ORDER BY A.SEQ
        ) WHERE 1 = 1
              /*AND WORK_CD IN (SELECT DISTINCT WORK_CD FROM TTIM018 WHERE ENTER_CD = P_ENTER_CD AND TIME_CD = C_TIME_CD
                              UNION
                              SELECT 'Z1' FROM DUAL
                              )*/
     ;



BEGIN
    -- 근무시간변경 이력 삭제
    BEGIN
        DELETE
          FROM TTIM335 A
         WHERE 1 = 1
           AND A.ENTER_CD = P_ENTER_CD
           AND A.YMD BETWEEN P_S_YMD AND P_E_YMD
           AND A.SABUN = NVL(P_SABUN, A.SABUN)
           AND NVL(UPDATE_YN,'N') = 'N' -- [일근무관리] 에서 수정했으면 삭제 안함.
           AND NVL(CLOSE_YN, 'N') = 'N'
           AND CASE WHEN P_BUSINESS_PLACE_CD IS NULL
                 THEN 1
                 ELSE (
                     CASE WHEN P_BUSINESS_PLACE_CD = F_COM_GET_BP_CD(A.ENTER_CD, A.SABUN, A.YMD)
                       THEN 1
                       ELSE 0 END) END = 1
        ;
        /*UPDATE TTIM335 A
           SET A.IN_HM = NULL
             , A.OUT_HM = NULL
         WHERE 1 = 1
           AND A.ENTER_CD = P_ENTER_CD
           AND A.YMD BETWEEN P_S_YMD AND P_E_YMD
           AND A.SABUN = NVL(P_SABUN, A.SABUN)
           AND NVL(UPDATE_YN,'N') = 'N' -- [일근무관리] 에서 수정했으면 삭제 안함.
           AND NVL(CLOSE_YN, 'N') = 'N'
           AND CASE WHEN P_BUSINESS_PLACE_CD IS NULL
                 THEN 1
                 ELSE (
                     CASE WHEN P_BUSINESS_PLACE_CD = F_COM_GET_BP_CD(A.ENTER_CD, A.SABUN, A.YMD)
                       THEN 1
                       ELSE 0 END) END = 1
        ;*/

        DELETE
          FROM TTIM337 A
         WHERE 1 = 1
           AND A.ENTER_CD = P_ENTER_CD
           AND YMD BETWEEN P_S_YMD AND P_E_YMD
           AND A.SABUN = NVL(P_SABUN, A.SABUN)
           AND NOT EXISTS (
               SELECT 1
                 FROM TTIM335 S
                WHERE 1 = 1
                  AND S.ENTER_CD = A.ENTER_CD
                  AND S.SABUN    = A.SABUN
                  AND S.YMD      = A.YMD
                  AND NVL(S.CLOSE_YN, 'N') = 'Y'
             )
           AND CASE WHEN P_BUSINESS_PLACE_CD IS NULL
                 THEN 1
                 ELSE (
                     CASE WHEN P_BUSINESS_PLACE_CD = F_COM_GET_BP_CD(A.ENTER_CD, A.SABUN, A.YMD)
                       THEN 1
                       ELSE 0 END) END = 1
        ;
        DELETE
          FROM TTIM338 A
         WHERE 1 = 1
           AND A.ENTER_CD = P_ENTER_CD
           AND YMD BETWEEN P_S_YMD AND P_E_YMD
           AND A.SABUN = NVL(P_SABUN, A.SABUN)
           AND NOT EXISTS (
               SELECT 1
                 FROM TTIM335 S
                WHERE 1 = 1
                  AND S.ENTER_CD = A.ENTER_CD
                  AND S.SABUN    = A.SABUN
                  AND S.YMD      = A.YMD
                  AND NVL(S.CLOSE_YN, 'N') = 'Y'
             )
           AND CASE WHEN P_BUSINESS_PLACE_CD IS NULL
                 THEN 1
                 ELSE (
                     CASE WHEN P_BUSINESS_PLACE_CD = F_COM_GET_BP_CD(A.ENTER_CD, A.SABUN, A.YMD)
                       THEN 1
                       ELSE 0 END) END = 1
        ;
        -- 24.04.30 추가
        IF P_CHKID <> 'IF_GW' THEN
            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
                P_SQLCODE := TO_CHAR(sqlcode);
                P_SQLERRNM := '데이터삭제시 에러 - ' || sqlerrm;
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'INIT',P_SQLERRNM, P_SABUN);
    END;

    ------------------------------------------------------------------------------------------------------------------------------
    -- 세콤근무기록을 기반으로 근무시간변경이력에 저장
    ------------------------------------------------------------------------------------------------------------------------------
    FOR CSR_SC IN CSR_TIMECARD LOOP

        EXIT WHEN CSR_SC.YMD > TO_CHAR(SYSDATE, 'YYYYMMDD');    -- 오늘일자보다 큰 일자는 일근무 시간을 생성할 필요가 없다.

/*        -- 한진정보통신에서는 일주일 단위 연장시간 산정을 다시해주기 위해 일주일의 기간을 다시 구한다.
          -- 해당 로직 삭제 요청으로 주석처리함.
        IF P_ENTER_CD = 'HX'
            AND NVL(CSR_SC.HOL_YN, 'N') = 'Y' THEN

            LV_WEEK_START_YMD := TO_CHAR(F_TIM_GET_WEEK_START(P_ENTER_CD, CSR_SC.YMD), 'YYYYMMDD');
            LV_WEEK_END_YMD   := TO_CHAR(TO_DATE(LV_WEEK_START_YMD, 'YYYYMMDD') + 6, 'YYYYMMDD');

        END IF;*/

--         LV_LOG := 'S_YMD:' || P_S_YMD || ', E_YMD:' || P_E_YMD || ', SABUN:' || P_SABUN || ', SABUN:' || P_SABUN;
--         LV_LOG := LV_LOG || ', CLOSE_YN:' || CSR_SC.CLOSE_YN;
        --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'log-1',LV_LOG, P_SABUN);
--         DBMS_OUTPUT.PUT_LINE(LV_LOG);

              P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'337',CSR_SC.OUT_HM, P_SABUN);
        ------------------------------------------------------------------------------------------------------------------------------
        -- 한진정보통신 유연근무자의 경우 근무시간을 계획시간(연장근무시간포함) 으로 반영
        ------------------------------------------------------------------------------------------------------------------------------
        IF P_ENTER_CD IN ('HX','TP') THEN
           -- 연장근무조회
           LV_OT_EXIST_YN := 'N';
           BEGIN
                SELECT CASE WHEN COUNT(*) > 0 THEN 'Y' ELSE 'N' END
                     , MIN(B.REAL_S_HM) AS REAL_S_HM
                     , MAX(B.REAL_E_HM) AS REAL_E_HM
                  INTO LV_OT_EXIST_YN,
                       LV_OT_SHM, 
                       LV_OT_EHM
                  FROM TTIM611 A, TTIM615 B, THRI103 C
                 WHERE A.ENTER_CD = B.ENTER_CD 
                   AND A.APPL_SEQ  = B.PLAN_APPL_SEQ  
                   AND A.ENTER_CD = C.ENTER_CD 
                   AND A.APPL_SEQ = C.APPL_SEQ 
                   AND A.ENTER_CD = P_ENTER_CD
                   AND A.SABUN = CSR_SC.SABUN
                   AND A.YMD = CSR_SC.YMD
                   AND C.APPL_STATUS_CD = '99'
                   ;
           EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    LV_OT_EXIST_YN := 'N';
                    LV_OT_EHM      := NULL;
                WHEN OTHERS THEN
                    LV_OT_EXIST_YN := 'N';
                    LV_OT_EHM      := NULL;
           END;   
           
--           IF (CSR_SC.HX_SHM IS NOT NULL AND CSR_SC.HX_EHM IS NOT NULL) THEN --기존 유연근무가 있을 때 진행되는 로직
--                -- (휴일) 실제타각시간이 없으면 유연근무 계획시작~종료시간(연장근무포함)으로 
--                -- 2024.09.30 추가 : 한진정보통신 휴일 근무읠 경우, 타각데이터 무시
--                IF NVL(CSR_SC.HOL_YN, 'N') = 'Y' THEN
--                    CSR_SC.IN_HM  := CSR_SC.HX_SHM;  
--                    CSR_SC.OUT_HM := NVL(LV_OT_EHM, CSR_SC.HX_EHM); 
--                END IF;
--           END IF;
         P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'378',CSR_SC.OUT_HM, P_SABUN);
         --한진정보통신 2024.11.05 수정 합니다.
            --조건 1 : 유연근무 있을 때 + 휴일일 경우 타각데이터 무시 , 조건 2: 유연근무 있을 때 밤 10시 ~ 오전6시 사이인 경우 타각 무시, 조건3 : 그냥 휴일 근무일 경우 타각데이터 무시
	           IF (CSR_SC.HX_SHM IS NOT NULL AND CSR_SC.HX_EHM IS NOT NULL) AND P_ENTER_CD !='TP' THEN --기존 유연근무가 있을 때 진행되는 로직 (조건1)
			                -- (휴일) 실제타각시간이 없으면 유연근무 계획시작~종료시간(연장근무포함)으로 
			                -- 2024.09.30 추가 : 한진정보통신 휴일 근무읠 경우, 타각데이터 무시
			            IF NVL(CSR_SC.HOL_YN, 'N') = 'Y' THEN --유연근무인데 휴일일 경우 체크 합니다.
				                    CSR_SC.IN_HM  := CSR_SC.HX_SHM;  
				                    CSR_SC.OUT_HM := NVL(LV_OT_EHM, CSR_SC.HX_EHM);
			            ELSE --유연근무인데 휴일이 아닐 경우 체크 입니다. (조건2)
			            --유연근무 + 밤 10시 익일 오전 6시인 경우에는 휴일과 상관없이 출퇴근 인정되게 갑니다. 
			             --IF (CSR_SC.HX_SHM >= '2200') AND (CSR_SC.HX_EHM <= '0600' OR CSR_SC.HX_EHM >='2200') THEN
			                    IF (CSR_SC.HX_SHM >= '2200' OR CSR_SC.HX_SHM <= '0600') THEN --20250312 수정
			                        CSR_SC.IN_HM  := CSR_SC.HX_SHM;  
			                        CSR_SC.OUT_HM := NVL(LV_OT_EHM, CSR_SC.HX_EHM);
			                    ELSE CSR_SC.OUT_HM := NVL(LV_OT_EHM, CSR_SC.HX_EHM);
			                    END IF;
	            		END IF;                
	           --2024.11.05 추가 기존 로직 보존하고, 위는 유연근무가 있을 때 + 휴일일 경우     
	           ELSIF NVL(CSR_SC.HOL_YN, 'N') = 'Y' THEN --휴일일 경우 (조건3)
	                CSR_SC.IN_HM  := NVL(CSR_SC.HX_SHM, LV_OT_SHM); --근무시작 시간이 없으면 연장근무 시작시간을 봅니다.
	                CSR_SC.OUT_HM := NVL(LV_OT_EHM, CSR_SC.HX_EHM); --연장근무 종료시각이 없으면 근무시간을 봅니다. 
	           END IF;
	           
           END IF;  -- 한진정보통신 유연근무자의 경우 근무시간을 계획시간(연장근무시간포함) 으로 반영
           
         P_COM_SET_LOG(P_ENTER_CD, P_S_YMD, P_E_YMD,'403',CSR_SC.OUT_HM, P_SABUN);
        ------------------------------------------------------------------------------------------------------------------------------
        -- 외근(직출, 직퇴) 시 출퇴근 시간 변경
        ------------------------------------------------------------------------------------------------------------------------------
        --시간단위 근태 존재여부 (외근)
        LV_OUT_WORK_EXIST_YN := 'N'; --외근존재 여부
        LV_OUT_WORK_SHM := '';
        LV_OUT_WORK_EHM := '';

        --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'log-21','SABUN:' || CSR_SC.SABUN || ', YMD:' || CSR_SC.YMD, P_SABUN);
        BEGIN
            SELECT A.GNT_CD
                 , CASE WHEN A.GNT_CD = '210' AND A.REQ_S_HM IS NOT NULL THEN A.REQ_S_HM ELSE NULL END AS OUT_WORK_SHM --직출 ( 근태 신청 시 필수입력값이라 Null일리가 없음 )
                 , CASE WHEN A.GNT_CD = '220' AND A.REQ_E_HM IS NOT NULL THEN A.REQ_E_HM ELSE NULL END AS OUT_WORK_EHM  --직퇴 ( 근태 신청 시 필수입력값이라 Null일리가 없음 )
              INTO LV_OUT_WORK_EXIST_YN, LV_OUT_WORK_SHM, LV_OUT_WORK_EHM
              FROM TTIM301 A
             WHERE A.ENTER_CD = P_ENTER_CD
               AND A.SABUN    = CSR_SC.SABUN
               AND A.S_YMD    = CSR_SC.YMD
               AND NVL(A.UPDATE_YN, 'N') = 'N' -- 취소신청여부
               AND A.GNT_CD   IN ('210', '220')  -- 직출, 직퇴
               AND EXISTS ( SELECT 1
                              FROM THRI103 X
                             WHERE X.ENTER_CD = A.ENTER_CD
                               AND X.APPL_SEQ = A.APPL_SEQ
                               AND X.APPL_STATUS_CD = '99' )
               AND NOT EXISTS ( SELECT 1
                              FROM TTIM405 X
                             WHERE X.ENTER_CD = A.ENTER_CD
                               AND X.APPL_SEQ = A.APPL_SEQ
                               AND X.UPDATE_YN = 'Y' ); --20250428 JJH 최소된 내역 빼고 확인
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                LV_OUT_WORK_EXIST_YN := 'N';
                LV_OUT_WORK_SHM := '';
                LV_OUT_WORK_EHM := '';
            WHEN OTHERS THEN
                LV_OUT_WORK_EXIST_YN := 'N';
                LV_OUT_WORK_SHM := '';
                LV_OUT_WORK_EHM := '';

                P_SQLCODE := TO_CHAR(sqlcode);
                P_SQLERRNM := sqlerrm;
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'123-2',P_SQLERRNM, P_SABUN);
        END;

        --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'log-22','LV_OUT_WORK_EXIST_YN:' || LV_OUT_WORK_EXIST_YN || ', LV_OUT_WORK_EHM:' || LV_OUT_WORK_EHM, P_SABUN);

        --외근여부가 존재하면 출,퇴근시간을 변경하여 반영한다.
        IF LV_OUT_WORK_EXIST_YN = '210' THEN --직출
            CSR_SC.IN_HM := NVL(LV_OUT_WORK_SHM, CSR_SC.WORK_SHM); --기본출근시간 ( 근태 신청 시 필수입력값이라 Null일리가 없음 )
        END IF;
        IF LV_OUT_WORK_EXIST_YN = '220' THEN --직퇴
            CSR_SC.OUT_HM := NVL(LV_OUT_WORK_EHM, CSR_SC.WORK_EHM); --기본퇴근시간 ( 근태 신청 시 필수입력값이라 Null일리가 없음 )
        END IF;


        LV_FIX_ST_TIME_YN := 'N'; -- 출근시간 고정 여부
        LV_FIX_ED_TIME_YN := 'N'; -- 퇴근시간 고정 여부
        BEGIN
            SELECT FIX_ST_TIME_YN, FIX_ED_TIME_YN
              INTO LV_FIX_ST_TIME_YN, LV_FIX_ED_TIME_YN
              FROM TTIM115 A
             WHERE A.ENTER_CD     = P_ENTER_CD
               AND A.WORK_GRP_CD  = CSR_SC.WORK_GRP_CD ;
        EXCEPTION
            WHEN OTHERS THEN
                LV_FIX_ST_TIME_YN := 'N'; -- 출근시간 고정 여부
                LV_FIX_ED_TIME_YN := 'N'; -- 퇴근시간 고정 여부
        END;
        IF NVL( CSR_SC.HOL_YN, 'N') = 'N' THEN  -- 휴일 제외
            
           
            IF LV_FIX_ST_TIME_YN = 'Y' THEN  -- 출근시간 고정
                CSR_SC.IN_HM  := NVL(LV_OUT_WORK_SHM, CSR_SC.WORK_SHM);
            END IF;
        
            IF LV_FIX_ED_TIME_YN = 'Y' AND CSR_SC.IN_HM IS NOT NULL THEN -- 퇴근시간 고정
          --  IF LV_FIX_ED_TIME_YN = 'Y' AND CSR_SC.IN_HM IS NOT NULL AND LV_OT_EXIST_YN = 'N' THEN -- 퇴근시간 고정
                CSR_SC.OUT_HM := NVL(LV_OUT_WORK_EHM, NVL(LV_OT_EHM, CSR_SC.WORK_EHM));
            END IF;

            LV_EX_EMP_YN := 'N'; -- 일근무제외자 여부
            LV_OUT_WORK_SHM := '';
            LV_OUT_WORK_EHM := '';
            BEGIN
                SELECT 'Y'
                     , CASE WHEN A.FIX_ST_TIME_YN = 'Y'
                            THEN NVL(A.IN_HM, CSR_SC.WORK_SHM) END
                     , CASE WHEN A.FIX_ED_TIME_YN = 'Y'
                            THEN NVL(A.OUT_HM, CSR_SC.WORK_EHM) END
                  INTO LV_EX_EMP_YN, LV_OUT_WORK_SHM, LV_OUT_WORK_EHM
                  FROM TTIM309 A
                 WHERE A.ENTER_CD = P_ENTER_CD
                   AND A.SABUN    = CSR_SC.SABUN
                   AND CSR_SC.STIME_CD NOT IN ('G01', 'G02', 'G03', 'V01')  --20240106 JWS 공휴 주휴 등등 근무가 아닐경우 시간을 가져오지 않도록
--                    AND A.WORK_CD  = LV_WORK_CD -- 기본근무
                   AND CSR_SC.YMD BETWEEN A.SDATE AND NVL(A.EDATE, '29991231') ;
            EXCEPTION
                WHEN OTHERS THEN
                    LV_EX_EMP_YN := 'N';
            END;
            IF LV_EX_EMP_YN = 'Y' THEN
                CSR_SC.IN_HM := NVL(LV_OUT_WORK_SHM, CSR_SC.IN_HM);
                CSR_SC.OUT_HM := NVL(LV_OUT_WORK_EHM, CSR_SC.OUT_HM);
            END IF;
     P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'509',CSR_SC.OUT_HM, P_SABUN);
            ------------------------------------------------------------------------------------------------------------------------------
            -- 출퇴근시간 고정이더라도 근태가 있을경우 출퇴근시간을 변경처리함
            ------------------------------------------------------------------------------------------------------------------------------
--             IF LV_FIX_ED_TIME_YN = 'Y' AND CSR_SC.IN_HM IS NOT NULL THEN
            --추가 : 출퇴근시간 고정일때(간주근로제) 근태발생시 출퇴근시간 변경하기 위한 구문 추가
            LV_GNT_CD := '';
            LV_GNT_WORK_TIME_YN := 'N';
            BEGIN
                SELECT A.GNT_CD
                     , C.REQUEST_USE_TYPE
                     , (SELECT HALF_HOLIDAY1 FROM TTIM017 WHERE ENTER_CD = P_ENTER_CD AND TIME_CD = CSR_SC.TIME_CD ) AS HALF_STD_HM -- 오전근태일때 출근시간
                     , (SELECT HALF_HOLIDAY2 FROM TTIM017 WHERE ENTER_CD = P_ENTER_CD AND TIME_CD = CSR_SC.TIME_CD ) AS HALF_END_HM  -- 오후근태일때 퇴근시간
                     , CASE WHEN NVL(C.STD_APPLY_HOUR, 0) > 0 AND C.WORK_CD IS NOT NULL THEN 'Y' ELSE 'N' END AS GNT_WORK_TIME_YN
                  INTO LV_GNT_CD, LV_REQUEST_USE_TYPE, LV_HALF_STD_HM, LV_HALF_END_HM
                     , LV_GNT_WORK_TIME_YN
                FROM TTIM405 A
                   , TTIM014 C
                WHERE 1 = 1
                  AND A.ENTER_CD = C.ENTER_CD
                  AND A.GNT_CD   = C.GNT_CD
                  AND A.ENTER_CD = P_ENTER_CD
                  AND A.SABUN    = CSR_SC.SABUN
                  AND A.YMD      = CSR_SC.YMD
                  AND NVL(A.UPDATE_YN, 'N') = 'N' -- 취소신청여부
                  AND EXISTS ( SELECT 1
                                  FROM THRI103 X
                                 WHERE X.ENTER_CD = A.ENTER_CD
                                   AND X.APPL_SEQ = A.APPL_SEQ
                                   AND X.APPL_STATUS_CD = '99' ) ;
            EXCEPTION
                WHEN OTHERS THEN
                  LV_GNT_CD := '';
            END
            ;

            IF LV_GNT_CD IS NOT NULL THEN
                IF LV_REQUEST_USE_TYPE = 'D' THEN
                -- 실제 출퇴근 시간을 조절할 필요는 없어보임 2023-09-15
/*                    ELSIF LV_REQUEST_USE_TYPE = 'AM' THEN
                    CSR_SC.IN_HM := NVL(LV_HALF_END_HM, CSR_SC.IN_HM);
                ELSIF LV_REQUEST_USE_TYPE = 'PM' THEN
                    CSR_SC.OUT_HM := NVL(LV_HALF_STD_HM, CSR_SC.OUT_HM);*/
            
                     --한진정보통신은 종일근태(연차,외근 등) + 유연근무계획시간이 있으면 근무시간 보여줍니다 20250708
                     IF P_ENTER_CD = 'HX' AND CSR_SC.HX_SHM IS NOT NULL AND CSR_SC.HX_EHM IS NOT NULL THEN
                        CSR_SC.IN_HM := CSR_SC.HX_SHM;
                        CSR_SC.OUT_HM := CSR_SC.HX_EHM;
                     ELSE
                        CSR_SC.IN_HM := '';
                        CSR_SC.OUT_HM := '';
                     END IF;
                
                END IF
                ;
            END IF
            ;
            ------------------------------------------------------------------------------------------------------------------------------
            -- 재량근무자있을 경우
            ------------------------------------------------------------------------------------------------------------------------------
            BEGIN
                SELECT MAX(CSR_SC.WORK_SHM)
                     , MAX(CSR_SC.WORK_EHM)
                  INTO LV_OUT_WORK_SHM, LV_OUT_WORK_EHM
                  FROM TTIM131 A
                 WHERE A.ENTER_CD   = P_ENTER_CD
                   AND CSR_SC.YMD BETWEEN A.SDATE AND NVL(A.EDATE, '99991231')
                   AND A.SABUN      = CSR_SC.SABUN
                   AND A.FLEXIBLE_TYPE = 'T030'
                   AND EXISTS ( SELECT 1
                                  FROM THRI103 X
                                 WHERE X.ENTER_CD = A.ENTER_CD
                                   AND X.APPL_SEQ = A.APPL_SEQ
                                   AND X.APPL_STATUS_CD = '99' )
                ;
                CSR_SC.IN_HM := NVL(LV_OUT_WORK_SHM, CSR_SC.IN_HM);
                CSR_SC.OUT_HM := NVL(LV_OUT_WORK_EHM, CSR_SC.OUT_HM);
            EXCEPTION
                WHEN OTHERS THEN
                    LV_CHG_WORK_YN := 'N';
            END;
--             END IF;
        END IF;

        ------------------------------------------------------------------------------------------------------------------------------
        -- 출퇴근시간변경 이력
        ------------------------------------------------------------------------------------------------------------------------------
        LV_CHG_WORK_YN := 'N'; -- 일근무제외자 여부
        LV_OUT_WORK_SHM := '';
        LV_OUT_WORK_EHM := '';
        BEGIN
            SELECT MAX('Y')
                 , MAX(A.AF_SHM) KEEP(DENSE_RANK FIRST ORDER BY A.APPL_SEQ DESC)
                 , MAX(A.AF_EHM) KEEP(DENSE_RANK FIRST ORDER BY A.APPL_SEQ DESC)
                 , MAX(A.IC_ISLAND_YN)
              INTO LV_CHG_WORK_YN, LV_OUT_WORK_SHM, LV_OUT_WORK_EHM, LV_IC_ISLAND_YN
              FROM TTIM345 A
             WHERE A.ENTER_CD   = P_ENTER_CD
               AND A.YMD        = CSR_SC.YMD
               AND A.SABUN      = CSR_SC.SABUN
               --AND A.ENTER_CD <> 'KS' --한국공항은 출퇴근시간변경신청 로직 제외 합니다. 이후 일근무관리 화면에서 출퇴근신청자 표시 해줍니다. 2024.06.05
               AND EXISTS ( SELECT 1
                              FROM THRI103 X
                             WHERE X.ENTER_CD = A.ENTER_CD
                               AND X.APPL_SEQ = A.APPL_SEQ
                               AND X.APPL_STATUS_CD = '99' ) ;
        IF LV_IC_ISLAND_YN IS NULL THEN
            LV_IC_ISLAND_YN := CSR_SC.IC_ISLAND_YN;
        END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                LV_IC_ISLAND_YN := CSR_SC.IC_ISLAND_YN;
            WHEN OTHERS THEN
                LV_IC_ISLAND_YN := CSR_SC.IC_ISLAND_YN;
        END;
        --한국공항 출퇴근시간변경신청 로직을 제외하는데 영종도 체크여부는 제외하지 않습니다. 
        --따라서 위에 있는 ENTER_CD <> 'KS' 다시 주석 처리해서 값은 다 받아오고 IN OUT TIME만 넣지 않습니다. 2024.07.03
        IF NVL(LV_CHG_WORK_YN, 'N') = 'Y' AND P_ENTER_CD <> 'KS' THEN
            CSR_SC.IN_HM := NVL(LV_OUT_WORK_SHM, CSR_SC.IN_HM);
            CSR_SC.OUT_HM := NVL(LV_OUT_WORK_EHM, CSR_SC.OUT_HM);
        END IF;
        
             P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'623',CSR_SC.OUT_HM, P_SABUN);


        /*
         * 한진정보통신의 경우
         * 종일 근태가 있어도 연장근무가 있을수 있음 연장근무가 들어오면 인정을 해줘야 함.
         * 종일 근태가 있어도.... 유연근무가 있을수 있다하는데 이부분의 로직이 필요하면 수정이 필요함.
         * ---------------------------------------------
         * 2023-12-04   JWS
         */
        BEGIN
            LV_OT_EXIST_YN := 'N';

            SELECT CASE WHEN P_ENTER_CD = 'HX'
                         AND EXISTS (
                                    SELECT 1
                                      FROM TTIM611 A
                                     WHERE 1 = 1
                                       AND A.ENTER_CD = P_ENTER_CD
                                       AND A.YMD      = CSR_SC.YMD
                                       AND A.SABUN    = CSR_SC.SABUN
                                       AND EXISTS (
                                           SELECT 1
                                             FROM THRI103 S
                                            WHERE 1 = 1
                                              AND S.ENTER_CD = A.ENTER_CD
                                              AND S.APPL_SEQ = A.APPL_SEQ
                                              AND S.APPL_STATUS_CD = '99'
                                         ))
                        THEN 'Y'
                        ELSE 'N' END
              INTO LV_OT_EXIST_YN
              FROM DUAL
            ;
        EXCEPTION
            WHEN OTHERS THEN
            LV_OT_EXIST_YN := 'N';
        END;

        /*
         * 출퇴근시간이 없을 경우 근무 이력을 저장할 필요가 없다.
         * ------------------------------------------------------------
         * 2023-09-14   JWS
         */
        --CONTINUE WHEN CSR_SC.IN_HM IS NULL AND CSR_SC.OUT_HM IS NULL AND LV_GNT_WORK_TIME_YN = 'N' AND LV_OT_EXIST_YN = 'N';
        -- 24.05.10
        IF CSR_SC.IN_HM IS NULL AND CSR_SC.OUT_HM IS NULL AND LV_GNT_WORK_TIME_YN = 'N' AND LV_OT_EXIST_YN = 'N' THEN
            IF P_CHKID <> 'IF_GW' THEN
                COMMIT;
            END IF;
            CONTINUE;
        END IF;
        
        /*IF P_ENTER_CD = 'HX' --2024.09.30 추가 : 한진정보통신 휴일 근무읠 경우, 타각데이터 무시
            AND NVL(CSR_SC.HOL_YN, 'N') = 'Y' AND (CSR_SC.TIMECARD_IN_HM IS NOT NULL AND CSR_SC.TIMECARD_OUT_HM IS NOT NULL) THEN
            CSR_SC.IN_HM := NULL;
            CSR_SC.OUT_HM := NULL;

        END IF;
        */
       
        --25.1.21 추가 : 토파스 법인은 퇴근시간 NULL처리
        
        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'686',CSR_SC.OUT_HM, P_SABUN);
        
--        IF P_ENTER_CD = 'TP' THEN
--            CSR_SC.OUT_HM := NULL;
--        END IF;
        

        ------------------------------------------------------------------------------------------------------------------------------
        -- 근무시간변경이력 저장 (TTIM335)
        ------------------------------------------------------------------------------------------------------------------------------
        BEGIN
            MERGE INTO TTIM335 A
            USING (
                   SELECT P_ENTER_CD AS ENTER_CD
                        , CSR_SC.YMD AS YMD
                        , CSR_SC.SABUN AS SABUN
                        , '' AS GNT_CD
                        , CSR_SC.IN_HM AS IN_HM
                        , CSR_SC.OUT_HM AS OUT_HM
                        , '' AS MEMO
                        , CSR_SC.HOL_YN AS HOL_YN
                        , SYSDATE AS CHKDATE
                        , P_CHKID AS CHKID
                        , CSR_SC.TIME_CD AS TIME_CD  --2020.06.24 TIME_CD 추가함.
                        , LV_IC_ISLAND_YN AS IC_ISLAND_YN
                     FROM DUAL

                  ) B
            ON (        A.ENTER_CD = B.ENTER_CD
                    AND A.YMD      = B.YMD
                    AND A.SABUN    = B.SABUN
                )
            WHEN NOT MATCHED THEN
                INSERT ( A.ENTER_CD, A.YMD, A.SABUN, A.IN_HM, A.OUT_HM, A.MEMO, A.HOL_YN, A.CHKDATE, A.CHKID, A.TIME_CD, A.IC_ISLAND_YN)
                VALUES ( B.ENTER_CD, B.YMD, B.SABUN, B.IN_HM, B.OUT_HM, B.MEMO, B.HOL_YN, B.CHKDATE, B.CHKID, B.TIME_CD, B.IC_ISLAND_YN)
            WHEN MATCHED THEN
                UPDATE SET A.IN_HM        = B.IN_HM
                         , A.OUT_HM       = B.OUT_HM
                         , A.HOL_YN       = B.HOL_YN
                         , A.TIME_CD      = B.TIME_CD
                        -- , A.IC_ISLAND_YN = B.IC_ISLAND_YN  -- 24.10.11 주석해제(출퇴근정정신청 영종도 여부 처리하기 위해)   
            ;
        EXCEPTION
              WHEN OTHERS THEN
                P_SQLCODE := TO_CHAR(sqlcode);
                P_SQLERRNM := '근무시간변경이력 등록시 Error : '||sqlerrm||' / 사번 : '||CSR_SC.SABUN||' / 근무일자 : '||CSR_SC.YMD||' / '||CSR_SC.IN_HM||' / '||CSR_SC.OUT_HM ;
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'20', P_SQLERRNM||'==>'|| SQLERRM, P_CHKID);
        END;

        /*
         * 출근 또는 퇴근 이력이 없을 경우 일일근무 정보를 생성이 불가능하므로 생성 자체를 하지 않음
         * ------------------------------------------------------------
         * 2023-09-14   JWS
         */
        --CONTINUE WHEN (CSR_SC.IN_HM IS NULL OR CSR_SC.OUT_HM IS NULL) AND LV_GNT_WORK_TIME_YN = 'N' AND LV_OT_EXIST_YN = 'N';
        -- 24.05.10
        IF (CSR_SC.IN_HM IS NULL OR CSR_SC.OUT_HM IS NULL) AND LV_GNT_WORK_TIME_YN = 'N' AND LV_OT_EXIST_YN = 'N' THEN
            IF P_CHKID <> 'IF_GW' THEN
                COMMIT;
            END IF;
            CONTINUE;
        END IF;
        
        --IF CSR_SC.SABUN = '0020182' THEN
           DBMS_OUTPUT.PUT_LINE('CSR_SC.SABUN: '||CSR_SC.SABUN);
        --END IF;
        ------------------------------------------------------------------------------------------------------------------------------
        -- 근무시간변경이력 상세 저장 (TTIM337)
        ------------------------------------------------------------------------------------------------------------------------------
        FOR C_DTL IN CSR_WORK_DTL (C_YMD => CSR_SC.YMD , C_SABUN => CSR_SC.SABUN, C_SHM => CSR_SC.IN_HM, C_EHM => CSR_SC.OUT_HM, C_TIME_CD => CSR_SC.TIME_CD)
        LOOP
            CONTINUE WHEN NVL(C_DTL.HHMM, 0) = 0 AND C_DTL.WORK_CD != '0051';

            IF C_DTL.HHMM IS NOT NULL AND C_DTL.CD_TYPE = 'T10' THEN    -- 근무코드 타입 T10 시간
                BEGIN

                    /*
                     * 휴일근무신청일 경우 휴일근무로 시간이 들어오나 해당 근무는 집계상 필요없고
                     * 8시간 까지는 휴일기본근무
                     * 8시간 이외의 시간은 휴일연장시간으로 근무시간 추가한다.
                     * TTIM016 테이블을 추가해 분리시간을 관리할 수 있도록 수정  2021-12-03 JWS
                     * ----------------------------------------------------------
                     * 2021-11-08   JWS
                     */
                    LV_SUB_REMAIN_TIME := C_DTL.HHMM;

                    IF P_ENTER_CD = 'KS' AND C_DTL.WORK_CD = '0051' THEN
                        LV_SUB_REMAIN_TIME := ROUND(F_TIM_WORK_INFO_TEMP_NEW(P_ENTER_CD, CSR_SC.SABUN, CSR_SC.YMD, CSR_SC.IN_HM, CSR_SC.OUT_HM, C_DTL.WORK_CD));
                    END IF;

                    FOR L_TMP IN (SELECT NVL(B.SUB_WORK_CD, A.WORK_CD) AS WORK_CD
                                       , B.LIMITE_TIME
                                       , B.LIMITE_TIME AS INIT_TIME
                                       , B.SUB_WORK_TYPE
                                    FROM TTIM015 A
                                       , TTIM016 B
                                   WHERE 1 = 1
                                     AND A.ENTER_CD = P_ENTER_CD
                                     AND A.ENTER_CD = B.ENTER_CD(+)
                                     AND A.WORK_CD  = B.WORK_CD(+)
                                     AND A.WORK_CD  = C_DTL.WORK_CD
                                ORDER BY DECODE(B.SUB_WORK_TYPE, 'T010', 99, 1)
                                       , B.SEQ
                                 ) LOOP

                        IF L_TMP.SUB_WORK_TYPE = 'T010' THEN
                            L_TMP.INIT_TIME := LEAST(LV_SUB_REMAIN_TIME, NVL(L_TMP.LIMITE_TIME, 99999));
                        ELSIF L_TMP.SUB_WORK_TYPE = 'T050' THEN --한도
                            L_TMP.INIT_TIME := LEAST(C_DTL.HHMM, NVL(L_TMP.LIMITE_TIME, 99999));
                        ELSIF L_TMP.SUB_WORK_TYPE = 'T060' THEN --초과
                            L_TMP.INIT_TIME := GREATEST(C_DTL.HHMM - L_TMP.LIMITE_TIME, 0);
                        ELSIF L_TMP.SUB_WORK_TYPE = 'T999' THEN --예외
                            L_TMP.INIT_TIME := L_TMP.LIMITE_TIME;
                        ELSE
                            L_TMP.INIT_TIME := LV_SUB_REMAIN_TIME;
                        END IF;
                         
                        BEGIN
                            MERGE INTO TTIM337 A
                            USING ( SELECT P_ENTER_CD                  AS ENTER_CD
                                         , CSR_SC.YMD                  AS YMD
                                         , CSR_SC.SABUN                AS SABUN
                                         , L_TMP.WORK_CD               AS WORK_CD
                                         , TRUNC(L_TMP.INIT_TIME / 60) AS WORK_HH
                                         , MOD(L_TMP.INIT_TIME, 60)    AS WORK_MM

                                    FROM DUAL
                                  ) B
                               ON (    A.ENTER_CD = B.ENTER_CD
                                   AND A.YMD = B.YMD
                                   AND A.SABUN = B.SABUN
                                   AND A.WORK_CD = B.WORK_CD
                                  )
                            WHEN NOT MATCHED THEN
                                INSERT (ENTER_CD, YMD, SABUN, WORK_CD, WORK_HH, WORK_MM, CHKDATE, CHKID)
                                VALUES ( P_ENTER_CD, B.YMD, B.SABUN, B.WORK_CD, B.WORK_HH, B.WORK_MM, SYSDATE, P_CHKID)
                            WHEN MATCHED THEN
                                UPDATE SET WORK_HH = B.WORK_HH, WORK_MM = B.WORK_MM, CHKDATE = sysdate, CHKID= P_CHKID;
                        EXCEPTION
                            WHEN OTHERS THEN
                                P_SQLCODE := TO_CHAR(sqlcode);
                                P_SQLERRNM := '근무시간변경이력 등록시 Error : '||sqlerrm||' / 사번 : '||CSR_SC.SABUN||' / 근무일자 : '||CSR_SC.YMD ;
                                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'30-1', P_SQLERRNM, P_CHKID);
                        END;

                        IF L_TMP.SUB_WORK_TYPE = 'T010' THEN
                            LV_TIME_TMP := LV_SUB_REMAIN_TIME - L_TMP.INIT_TIME;

                            IF LV_TIME_TMP = 0 THEN
                                EXIT;
                            ELSE
                                LV_SUB_REMAIN_TIME := LV_TIME_TMP;
                            END IF;
                        END IF;

                    END LOOP;

                EXCEPTION
                     WHEN OTHERS THEN
                        --ROLLBACK;
                        P_SQLCODE := TO_CHAR(sqlcode);
                        P_SQLERRNM := '근무시간변경이력 등록시 Error : '||sqlerrm||' / 사번 : '||CSR_SC.SABUN||' / 근무일자 : '||CSR_SC.YMD ;
                        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'30', P_SQLERRNM, P_CHKID);
                END;

                /*
                 * 한진정보통신의 경우
                 * 연장근무를 신청하였는데 한 주의 소정근로가 40시간이 되지 않았을 경우
                 * 40시간까지 연장근무를 발생하지 않고 차액분만 연장근무로 발생시긴다.
                 * --------------------------------------------------------------------
                 * 2023-09-11   JWS
                 */
                /* 해당 로직 보류
                IF P_ENTER_CD = 'HX'
--                        AND NVL(CSR_SC.HOL_YN, 'N') = 'Y'
                       AND CSR_SC.DAY IN ('1', '7')
                       AND C_DTL.WORK_CD = '0040'
                       AND C_DTL.HHMM > 0 THEN
                    BEGIN
                        SELECT NVL(SUM(A.WORK_MIN), 0)
                          INTO LN_WEEK_WORK_TIME
                          FROM TTIM337 A
                         WHERE 1 = 1
                           AND A.ENTER_CD = P_ENTER_CD
                           AND A.SABUN    = CSR_SC.SABUN
                           AND A.YMD BETWEEN LV_WEEK_START_YMD
                                          AND LV_WEEK_END_YMD
                           AND EXISTS (
                               SELECT 1
                                 FROM TTIM015 S
                                WHERE 1 =1
                                  AND S.ENTER_CD = A.ENTER_CD
                                  AND S.WORK_CD  = A.WORK_CD
                                  AND S.WORK_CD_TYPE = '1'
                             )
                        ;

                        IF LN_WEEK_WORK_TIME < 40 * 60 THEN
                            UPDATE TTIM337 A
                               SET A.WORK_HH = TRUNC(LEAST((40 * 60 - LN_WEEK_WORK_TIME), C_DTL.HHMM) / 60)
                                 , A.WORK_MM =   MOD(LEAST((40 * 60 - LN_WEEK_WORK_TIME), C_DTL.HHMM), 60)
                             WHERE 1 = 1
                               AND A.ENTER_CD = P_ENTER_CD
                               AND A.SABUN    = CSR_SC.SABUN
                               AND A.YMD      = CSR_SC.YMD
                               AND A.WORK_CD  = '0020'
                            ;

                            MERGE INTO TTIM337 A
                            USING (
                                SELECT P_ENTER_CD   AS ENTER_CD
                                     , CSR_SC.SABUN AS SABUN
                                     , CSR_SC.YMD   AS YMD
                                     , '0020'       AS WORK_CD
                                     , TRUNC(LEAST((40 * 60 - LN_WEEK_WORK_TIME), C_DTL.HHMM) / 60) AS WORK_HH
                                     , MOD(LEAST((40 * 60 - LN_WEEK_WORK_TIME), C_DTL.HHMM), 60)    AS WORK_MM
                                  FROM DUAL
                            ) S
                            ON (    A.ENTER_CD = S.ENTER_CD
                                AND A.SABUN    = S.SABUN
                                AND A.YMD      = S.YMD
                                AND A.WORK_CD  = S.WORK_CD)
                            WHEN NOT MATCHED THEN
                            INSERT (A.ENTER_CD
                                  , A.YMD
                                  , A.SABUN
                                  , A.WORK_CD
                                  , A.WORK_HH
                                  , A.WORK_MM
                                  , A.CHKDATE
                                  , A.CHKID)
                            VALUES (S.ENTER_CD
                                  , S.YMD
                                  , S.SABUN
                                  , S.WORK_CD
                                  , S.WORK_HH
                                  , S.WORK_MM
                                  , SYSDATE
                                  , P_CHKID)
                            WHEN MATCHED THEN
                            UPDATE SET A.WORK_HH = S.WORK_HH
                                     , A.WORK_MM = S.WORK_MM
                                     , A.CHKDATE = SYSDATE
                                     , A.CHKID   = P_CHKID
                            ;



                            UPDATE TTIM337 A
                               SET A.WORK_HH = TRUNC((LEAST((40 * 60 - LN_WEEK_WORK_TIME), C_DTL.HHMM) - A.WORK_MIN)/ 60)
                                 , A.WORK_MM = MOD((LEAST((40 * 60 - LN_WEEK_WORK_TIME), C_DTL.HHMM) - A.WORK_MIN), 60)
                             WHERE 1 = 1
                               AND A.ENTER_CD = P_ENTER_CD
                               AND A.SABUN    = CSR_SC.SABUN
                               AND A.YMD      = CSR_SC.YMD
                               AND A.WORK_CD  = '0040'
                            ;
                        END IF;
                    EXCEPTION
                      WHEN OTHERS THEN
                        LN_WEEK_WORK_TIME := 0;
                    END;
                END IF;
*/
            ELSIF C_DTL.HHMM IS NOT NULL AND C_DTL.CD_TYPE = 'T20' THEN    -- 근무코드 타입 T20 횟수
                BEGIN
                    MERGE INTO TTIM338 A
                    USING ( SELECT P_ENTER_CD AS ENTER_CD
                                 , CSR_SC.YMD AS YMD
                                 , CSR_SC.SABUN AS SABUN
                                 , C_DTL.WORK_CD AS WORK_CD
                                 , C_DTL.HHMM AS CNT
                             FROM DUAL
                          ) B
                    ON (     A.ENTER_CD = B.ENTER_CD
                         AND A.YMD = B.YMD
                         AND A.SABUN = B.SABUN
                         AND A.WORK_CD = B.WORK_CD
                        )
                    WHEN NOT MATCHED THEN
                        INSERT (ENTER_CD, YMD, SABUN, WORK_CD, CNT, CHKDATE, CHKID)
                        VALUES ( P_ENTER_CD, B.YMD, B.SABUN, B.WORK_CD, B.CNT, SYSDATE, P_CHKID)
                    WHEN MATCHED THEN
                        UPDATE SET A.CNT = B.CNT, CHKDATE = sysdate, CHKID= P_CHKID;
                EXCEPTION
                     WHEN OTHERS THEN
                        --ROLLBACK;
                        P_SQLCODE := TO_CHAR(sqlcode);
                        P_SQLERRNM := '근무일집계내역 등록시 Error : '||sqlerrm||' / 사번 : '||CSR_SC.SABUN||' / 근무일자 : '||CSR_SC.YMD ;
                        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'31', P_SQLERRNM||'==>'|| SQLERRM, P_CHKID);
                END;
            END IF;
        END LOOP;
    -- 24.04.30 위치 변경
    IF P_CHKID <> 'IF_GW' THEN
        COMMIT;
    END IF;

    END LOOP;

    -- 2024.04.30 확인중...
--     IF P_CHKID <> 'IF_GW' THEN
--         COMMIT;
--     END IF;

EXCEPTION
    WHEN OTHERS THEN
        --ROLLBACK;
        P_SQLCODE := TO_CHAR(sqlcode);
        P_SQLERRNM := sqlerrm;
        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'100', P_SQLERRNM, P_CHKID);
END;