create or replace PROCEDURE             P_TIM_TIMECARD_SELECT_HX (
    P_SQLCODE        OUT VARCHAR2,
    P_SQLERRM        OUT VARCHAR2,
    P_ENTER_CD        IN VARCHAR2,
    P_YMD             IN VARCHAR2 DEFAULT TO_CHAR(SYSDATE, 'YYYYMMDD'),
    P_SABUN           IN VARCHAR2 DEFAULT NULL,
    P_CHKID           IN VARCHAR2 DEFAULT 'TIMECARD'
)
IS
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
/* 2023-10-20  JWS            Initial Release                                 */
/******************************************************************************/
--------- Local 변수 선언 -------------
    LV_BIZ_CD       TSYS903.BIZ_CD%TYPE := 'TIM';
    LV_OBJECT_NM    TSYS903.OBJECT_NM%TYPE := 'P_TIM_TIMECARD_SELECT_HX';

    LN_NULL_YD_EHM  NUMBER := 10;   --전날 근무계획이 없을 경우 출근시점 기준으로 인정시켜줄 시간 DEFAULT 10시간 전 근무까지 인정해주게 하기 위해
    LN_NULL_ND_SHM  NUMBER := 10;   --다음날 근무계획이 없을 경우 퇴근시점 기준으로 인정시켜줄 시간 DEFAULT 10시간 전 근무까지 인정해주게 하기 위해
    LV_IN_TIME      DATE;
    LV_WORK_LOC_SEQ NUMBER;
    LV_IC_ISLAND_YN VARCHAR2(1) DEFAULT 'N';
    LV_OUT_TIME     DATE;

    CURSOR CUR_SCH IS
        SELECT A.ENTER_CD
             , A.SABUN
             , A.YD_YMD
             , A.YD_SHM
             , NVL(A.YD_EHM, A.TD_SHM - LN_NULL_YD_EHM /24) AS YD_EHM
             , A.TD_YMD
             , LEAST(A.TD_SHM
                 , (SELECT TO_DATE(A.TD_YMD||NVL(MIN(S.REQ_S_HM), '2359'), 'YYYYMMDDHH24MI')
                      FROM TTIM611 S
                         , THRI103 S2
                     WHERE 1 = 1
                       AND S.ENTER_CD = S2.ENTER_CD
                       AND S.APPL_SEQ = S2.APPL_SEQ
                       AND S.ENTER_CD = A.ENTER_CD
                       AND S.SABUN    = A.SABUN
                       AND S.YMD      = A.TD_YMD
                       AND S2.APPL_STATUS_CD NOT IN ('ZZ', '23', '33', '11')
                  )) AS TD_SHM
             , GREATEST(A.TD_EHM
                 , (SELECT TO_DATE(A.TD_YMD||NVL(MAX(S.REQ_E_HM), '0000'), 'YYYYMMDDHH24MI')
                      FROM TTIM611 S
                         , THRI103 S2
                     WHERE 1 = 1
                       AND S.ENTER_CD = S2.ENTER_CD
                       AND S.APPL_SEQ = S2.APPL_SEQ
                       AND S.ENTER_CD = A.ENTER_CD
                       AND S.SABUN    = A.SABUN
                       AND S.YMD      = A.TD_YMD
                       AND S2.APPL_STATUS_CD NOT IN ('ZZ', '23', '33', '11')
                  )) AS TD_EHM
             , A.ND_YMD
             , NVL(A.ND_SHM, A.TD_EHM + LN_NULL_ND_SHM / 24) AS ND_SHM
             , A.ND_EHM
          FROM (SELECT A.ENTER_CD
                     , A.SABUN
                     , LAG(A.YMD) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD)                   AS YD_YMD  --전날 퇴근시간
                     , TO_DATE(LAG(A.YMD) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD)
                                   ||LAG(NVL(A.SHM, B.WORK_SHM)) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD), 'YYYYMMDDHH24MI')  AS YD_SHM  --전날 출근시간
                     , TO_DATE(LAG(A.YMD) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD)
                                   ||LAG(NVL(A.EHM, B.WORK_EHM)) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD), 'YYYYMMDDHH24MI')
                         + CASE WHEN LAG(NVL(A.SHM, B.WORK_SHM)) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) >= LAG(NVL(A.EHM, B.WORK_EHM)) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD)
                                THEN 1
                                ELSE 0 END AS YD_EHM  --전날 퇴근시간
                     , A.YMD                                                                                AS TD_YMD
                     , TO_DATE(A.YMD||NVL(A.SHM, B.WORK_SHM), 'YYYYMMDDHH24MI')                                                               AS TD_SHM
                     , TO_DATE(A.YMD||NVL(A.EHM, B.WORK_EHM), 'YYYYMMDDHH24MI')
                         + CASE WHEN NVL(A.SHM, B.WORK_SHM) >= NVL(A.EHM, B.WORK_EHM)
                                THEN 1 ELSE 0 END AS TD_EHM
                     , LEAD(A.YMD) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD)                  AS ND_YMD  --다음날 출근시간
                     , TO_DATE(LEAD(A.YMD) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD)
                                   ||LEAD(NVL(A.SHM, B.WORK_SHM)) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD), 'YYYYMMDDHH24MI') AS ND_SHM  --다음날 출근시간
                     , TO_DATE(LEAD(A.YMD) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD)
                                   ||LEAD(NVL(A.EHM, B.WORK_EHM)) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD), 'YYYYMMDDHH24MI')
                         + CASE WHEN LEAD(NVL(A.SHM, B.WORK_SHM)) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) >= LEAD(NVL(A.EHM, B.WORK_EHM)) OVER ( PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD)
                                THEN 1 ELSE 0 END AS ND_EHM  --다음날 출근시간
                  FROM TTIM120_V A
                     , TTIM051   B
                 WHERE 1 = 1
                   AND A.ENTER_CD = B.ENTER_CD
                   AND A.TIME_CD  = B.TIME_CD
                   AND A.STIME_CD = B.STIME_CD
                   AND A.ENTER_CD = P_ENTER_CD
                   AND A.SABUN    = NVL(P_SABUN, A.SABUN)
                   AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')) A
         WHERE 1 = 1
           AND A.TD_YMD = P_YMD
    ;
BEGIN
    FOR CSC IN CUR_SCH
    LOOP
        LV_IN_TIME  := NULL;
        LV_OUT_TIME := NULL;
        LV_WORK_LOC_SEQ := NULL;
        LV_IC_ISLAND_YN := 'N';
        /*
         * 정상 출근시간 구하기
         */
        BEGIN
            SELECT MIN(A.IN_TIME)
              INTO LV_IN_TIME
              FROM (SELECT A.ENTER_CD
                         , A.YMD
                         , A.SABUN
                         , TO_DATE(NVL2(A.IN_HM , A.YMD||A.IN_HM , ''), 'YYYYMMDDHH24MI') AS IN_TIME
                      FROM TTIM331 A
                     WHERE 1 = 1
                       AND A.ENTER_CD = P_ENTER_CD
                       AND A.SABUN    = CSC.SABUN
                       AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                     UNION
                    SELECT A.ENTER_CD
                         , A.SABUN
                         , A.YMD
                         , A.CHK_TIME AS IN_TIME
                      FROM TTIM720 A
                     WHERE 1  =1
                       AND A.ENTER_CD = P_ENTER_CD
                       AND A.SABUN    = CSC.SABUN
                       AND A.CONFIRM_YN = 'Y'
                       AND A.GUBUN    = 1
                       AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                     ) A
             WHERE 1 = 1
               AND A.IN_TIME BETWEEN CSC.YD_EHM AND CSC.TD_SHM
          ;
            IF LV_IN_TIME IS NULL THEN
                --데이터가 없을 경우 지각이다.
                SELECT MIN(A.IN_TIME)
                  INTO LV_IN_TIME
                  FROM (SELECT A.ENTER_CD
                             , A.YMD
                             , A.SABUN
                             , TO_DATE(NVL2(A.IN_HM , A.YMD||A.IN_HM , ''), 'YYYYMMDDHH24MI') AS IN_TIME
                          FROM TTIM331 A
                         WHERE 1 = 1
--                       AND A.ENTER_CD ='HX'
                           AND A.ENTER_CD IN ('HX', 'HT')
                           AND A.ENTER_CD = P_ENTER_CD
                           AND A.SABUN    = CSC.SABUN
                           AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                         UNION
                        SELECT A.ENTER_CD
                             , A.YMD
                             , A.SABUN
                             , A.CHK_TIME AS IN_TIME
                          FROM TTIM720 A
                         WHERE 1  =1
                           AND A.ENTER_CD = P_ENTER_CD
                           AND A.SABUN    = CSC.SABUN
                           AND A.CONFIRM_YN = 'Y'
                           AND A.GUBUN    = 1
                           AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                         ) A
                 WHERE 1 = 1
                   AND A.IN_TIME BETWEEN CSC.TD_SHM AND CSC.TD_EHM
              ;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
            --데이터가 없을 경우 지각이다.
            SELECT MIN(A.IN_TIME)
              INTO LV_IN_TIME
              FROM (SELECT A.ENTER_CD
                         , A.YMD
                         , A.SABUN
                         , TO_DATE(NVL2(A.IN_HM , A.YMD||A.IN_HM , ''), 'YYYYMMDDHH24MI') AS IN_TIME
                      FROM TTIM331 A
                     WHERE 1 = 1
--                       AND A.ENTER_CD ='HX'
                       AND A.ENTER_CD IN ('HX', 'HT')
                       AND A.ENTER_CD = P_ENTER_CD
                       AND A.SABUN    = CSC.SABUN
                       AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                     UNION
                    SELECT A.ENTER_CD
                         , A.YMD
                         , A.SABUN
                         , A.CHK_TIME AS IN_TIME
                      FROM TTIM720 A
                     WHERE 1  =1
                       AND A.ENTER_CD = P_ENTER_CD
                       AND A.SABUN    = CSC.SABUN
                       AND A.CONFIRM_YN = 'Y'
                       AND A.GUBUN    = 1
                       AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                     ) A
             WHERE 1 = 1
               AND A.IN_TIME BETWEEN CSC.TD_SHM AND CSC.TD_EHM
          ;
        WHEN OTHERS THEN
            ROLLBACK;
            P_SQLCODE := P_SQLCODE;
            P_SQLERRM := '출근시간 구할때 에러===>'||sqlerrm;
            P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM, '10-1', P_SQLERRM, P_CHKID);
        END;


        /*
         * 정상 퇴근시간 구하기
         */
        BEGIN
            SELECT MAX(A.OUT_TIME) --20240920 MAX로 수정
              INTO LV_OUT_TIME
              FROM (SELECT A.ENTER_CD
                         , A.YMD
                         , A.SABUN
                         , TO_DATE(NVL2(A.OUT_HM, A.YMD||A.OUT_HM, ''), 'YYYYMMDDHH24MI') + DECODE(A.NEXT_DAY_CHK_YN, 'Y', 1, 0) AS OUT_TIME
                      FROM TTIM331 A
                     WHERE 1 = 1
--                       AND A.ENTER_CD ='HX'                     
                       AND A.ENTER_CD IN ('HX', 'HT')      
                       AND A.SABUN    = CSC.SABUN
                       AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                     UNION
                    SELECT A.ENTER_CD
                         , A.SABUN
                         , A.YMD
                         , A.CHK_TIME AS OUT_TIME
                      FROM TTIM720 A
                     WHERE 1  =1
                       AND A.ENTER_CD = P_ENTER_CD
                       AND A.SABUN    = CSC.SABUN
                       AND A.CONFIRM_YN = 'Y'
                       AND A.GUBUN    = 2
                       AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                     ) A
             WHERE 1 = 1
               AND A.OUT_TIME BETWEEN CSC.TD_EHM AND CSC.ND_SHM
          ;
            IF LV_OUT_TIME IS NULL THEN
                --데이터가 없을 경우 지각이다.
                SELECT MAX(A.IN_TIME)
                  INTO LV_OUT_TIME
                  FROM (SELECT A.ENTER_CD
                             , A.YMD
                             , A.SABUN
                             , TO_DATE(NVL2(A.OUT_HM , A.YMD||A.OUT_HM , ''), 'YYYYMMDDHH24MI') AS IN_TIME
                          FROM TTIM331 A
                         WHERE 1 = 1
                           AND A.ENTER_CD = P_ENTER_CD
                           AND A.SABUN    = CSC.SABUN
                           AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                         UNION
                        SELECT A.ENTER_CD
                             , A.SABUN
                             , A.YMD
                             , A.CHK_TIME AS IN_TIME
                          FROM TTIM720 A
                         WHERE 1  =1
                           AND A.ENTER_CD = P_ENTER_CD
                           AND A.SABUN    = CSC.SABUN
                           AND A.CONFIRM_YN = 'Y'
                           AND A.GUBUN    = 2
                           AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                         ) A
                 WHERE 1 = 1
                   AND A.IN_TIME BETWEEN CSC.TD_SHM AND CSC.TD_EHM
              ;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
            --데이터가 없을 경우 지각이다.
            SELECT MAX(A.IN_TIME)
              INTO LV_OUT_TIME
              FROM (SELECT A.ENTER_CD
                         , A.YMD
                         , A.SABUN
                         , TO_DATE(NVL2(A.OUT_HM , A.YMD||A.OUT_HM , ''), 'YYYYMMDDHH24MI') AS IN_TIME
                      FROM TTIM331 A
                     WHERE 1 = 1
                       AND A.ENTER_CD = P_ENTER_CD
                       AND A.SABUN    = CSC.SABUN
                       AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                     UNION
                    SELECT A.ENTER_CD
                         , A.SABUN
                         , A.YMD
                         , A.CHK_TIME AS IN_TIME
                      FROM TTIM720 A
                     WHERE 1  =1
                       AND A.ENTER_CD = P_ENTER_CD
                       AND A.SABUN    = CSC.SABUN
                       AND A.CONFIRM_YN = 'Y'
                       AND A.GUBUN    = 2
                       AND A.YMD BETWEEN TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') - 1 , 'YYYYMMDD') AND TO_CHAR(TO_DATE(P_YMD, 'YYYYMMDD') + 1 , 'YYYYMMDD')
                     ) A
             WHERE 1 = 1
               AND A.IN_TIME BETWEEN CSC.TD_SHM AND CSC.TD_EHM
          ;
        WHEN OTHERS THEN
            ROLLBACK;
            P_SQLCODE := P_SQLCODE;
            P_SQLERRM := '퇴근시간 구할때 에러===>'||sqlerrm;
            P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM, '20-1', P_SQLERRM, P_CHKID);
        END;

        BEGIN
            MERGE INTO TTIM330 T
            USING (
                SELECT P_ENTER_CD                       AS ENTER_CD
                     , P_YMD                            AS YMD
                     , CSC.SABUN                        AS SABUN
                     , TO_CHAR(LV_IN_TIME, 'YYYYMMDD')  AS IN_YMD
                     , TO_CHAR(LV_IN_TIME, 'HH24MI')    AS IN_HM
                     , TO_CHAR(LV_OUT_TIME, 'YYYYMMDD') AS OUT_YMD
                     , TO_CHAR(LV_OUT_TIME, 'HH24MI')   AS OUT_HM
                     , SYSDATE                          AS CHKDATE
                     , P_CHKID                          AS CHKID
                  FROM DUAL
            ) S
             ON (T.ENTER_CD  = S.ENTER_CD
                 AND T.YMD   = S.YMD
                 AND T.SABUN = S.SABUN
                 )
            WHEN MATCHED THEN
            UPDATE SET T.IN_YMD = S.IN_YMD
                       , T.IN_HM = S.IN_HM
                       , T.OUT_YMD = S.OUT_YMD
                       , T.OUT_HM = S.OUT_HM
                       , T.MEMO   = '타각자동'
                       , T.CHKDATE = S.CHKDATE
                       , T.CHKID = S.CHKID
            WHEN NOT MATCHED THEN
            INSERT (T.ENTER_CD
                  , T.YMD
                  , T.SABUN
                  , T.IN_YMD
                  , T.IN_HM
                  , T.OUT_YMD
                  , T.OUT_HM
                  , T.MEMO
                  , T.CHKDATE
                  , T.CHKID)
            VALUES (S.ENTER_CD
                  , S.YMD
                  , S.SABUN
                  , S.IN_YMD
                  , S.IN_HM
                  , S.OUT_YMD
                  , S.OUT_HM
                  , '타각자동'
                  , S.CHKDATE
                  , S.CHKID  )
                ;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                P_SQLCODE := P_SQLCODE;
                P_SQLERRM := '입력할때'||sqlerrm;
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM, '30', P_SQLERRM, P_CHKID);
        END;
    END LOOP;

    COMMIT;
EXCEPTION
     WHEN OTHERS THEN
          ROLLBACK;
          P_SQLCODE := P_SQLCODE;
          P_SQLERRM := sqlerrm;
          P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM, '100', P_SQLERRM, P_CHKID);
END P_TIM_TIMECARD_SELECT_HX;