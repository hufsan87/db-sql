create or replace PROCEDURE             P_TIM_TIMECARD_SCHEDULER AS
/******************************************************************************/
/*                                                                            */
/*                  (c) Copyright ISU System Inc. 2004                        */
/*                         All Rights Reserved                                */
/*                                                                            */
/******************************************************************************/
/* [생성 Table]                                                               */
/*         Timecard내역정보 TTIM330                                           */
/*                                                                            */
/******************************************************************************/
/* Date        In Charge       Description                                    */
/*----------------------------------------------------------------------------*/
/* 2023-11-07  JWS            Initial Release                                 */
/******************************************************************************/
    LV_SQLCODE   VARCHAR2(4000);
    LV_SQLERRNM  VARCHAR2(4000);
    LV_CHKID     VARCHAR2(10) := 'SCHEDULER';

    LV_BIZ_CD       TSYS903.BIZ_CD%TYPE := 'TIM';
    LV_OBJECT_NM    TSYS903.OBJECT_NM%TYPE := 'P_TIM_TIMECARD_SELECT_HX';

    LV_START_DATE   DATE := SYSDATE;

    LV_BF_DAY   NUMBER := 3;    --타각 데이터 정리할 이전일자 + 2일 (EX 3이면 어제꺼부터 타임카드 작업

CURSOR CUR_TIMECARD IS
    SELECT A.ENTER_CD
         , A.SABUN
      FROM TTIM720 A
     WHERE 1 = 1
      -- AND A.CHK_TIME >= LV_START_DATE - 8/24/60 --8 분 이전 데이터만
       AND A.CHK_TIME >= LV_START_DATE - 11/24/60 --11 분 이전 데이터만
--        AND A.CHK_TIME >= LV_START_DATE - 4/24 -- 4시간 이전 데이터부터
     UNION
    SELECT A.ENTER_CD
         , A.SABUN
      FROM TTIM331 A
     WHERE 1 = 1
       AND TO_DATE(A.YMD||NVL(A.IN_HM, '0000'), 'YYYYMMDDHH24MI') >= LV_START_DATE - 1
    ;
BEGIN
    P_COM_SET_LOG('BATCH_TIM', LV_BIZ_CD, LV_OBJECT_NM, 'Start', 'TimecardScheduler Start TIME = '|| TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI'), LV_CHKID);
    FOR C_YMD IN (SELECT TO_CHAR(LV_START_DATE - (LV_BF_DAY - LEVEL) + 1, 'YYYYMMDD') AS YMD
                    FROM DUAL
                   WHERE 1 = 1
              CONNECT BY LEVEL < LV_BF_DAY) LOOP
        FOR C_USER IN CUR_TIMECARD LOOP
            IF C_USER.ENTER_CD = 'HX' OR  C_USER.ENTER_CD = 'HT' OR  C_USER.ENTER_CD = 'TP'  THEN --HG는 현재 수기 업로드 하고있음
                BEGIN
                    P_TIM_TIMECARD_SELECT_HX(LV_SQLCODE, LV_SQLERRNM, C_USER.ENTER_CD, C_YMD.YMD, C_USER.SABUN, LV_CHKID);
                EXCEPTION
                    WHEN OTHERS THEN
                        P_COM_SET_LOG('BATCH_TIM', LV_BIZ_CD, LV_OBJECT_NM, 'HX_IN', C_USER.ENTER_CD||' '|| C_YMD.YMD|| ' ' ||C_USER.SABUN|| '--> '||LV_SQLERRNM, LV_CHKID);
                END;
            ELSIF C_USER.ENTER_CD = 'KS' THEN
                BEGIN
                    P_TIM_TIMECARD_SELECT_KS(LV_SQLCODE, LV_SQLERRNM, C_USER.ENTER_CD, C_YMD.YMD, C_USER.SABUN, LV_CHKID);
                EXCEPTION
                    WHEN OTHERS THEN
                        P_COM_SET_LOG('BATCH_TIM', LV_BIZ_CD, LV_OBJECT_NM, 'KS_IN', C_USER.ENTER_CD||' '|| C_YMD.YMD|| ' ' ||C_USER.SABUN|| '--> '||LV_SQLERRNM, LV_CHKID);
                END;
            END IF;
        END LOOP;
    END LOOP;
    COMMIT;
   
   
   FOR C_TIME IN (SELECT *
                     FROM TTIM330 A
                    WHERE 1 = 1
                      AND A.CHKDATE >= LV_START_DATE
                      AND A.CHKID = LV_CHKID
        ) LOOP

        BEGIN
            P_TIM_WORK_HOUR_CHG (
             LV_SQLCODE
                , LV_SQLERRNM
                , C_TIME.ENTER_CD
                , C_TIME.YMD
                , C_TIME.YMD
                , C_TIME.SABUN
                , ''
                , LV_CHKID
            );
        EXCEPTION
            WHEN OTHERS THEN
                LV_SQLERRNM := C_TIME.ENTER_CD||', '||C_TIME.SABUN||', '|| C_TIME.YMD|| ' --->' ||LV_SQLERRNM;
                P_COM_SET_LOG('BATCH_TIM', LV_BIZ_CD, LV_OBJECT_NM,'100', LV_SQLERRNM, LV_CHKID);
        END;
    END LOOP;

  --  P_COM_SET_LOG('BATCH_TIM', LV_BIZ_CD, LV_OBJECT_NM, 'End', 'TimecardScheduler End TIME = '|| TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI'), LV_CHKID);
    

EXCEPTION
    WHEN OTHERS THEN
    P_COM_SET_LOG('BATCH_TIM', LV_BIZ_CD, LV_OBJECT_NM, 'End', SQLERRM, LV_CHKID);
END;