CREATE OR REPLACE PROCEDURE P_TIM_TIMECARD_SELECT_HX (
    P_SQLCODE           OUT VARCHAR2,
    P_SQLERRM           OUT VARCHAR2,
    P_ENTER_CD          IN VARCHAR2,
    P_YMD               IN VARCHAR2 DEFAULT TO_CHAR(SYSDATE, 'YYYYMMDD'),
    P_SABUN             IN VARCHAR2 DEFAULT NULL,
    P_CHKID             IN VARCHAR2 DEFAULT 'TIMECARD'
)
IS
/******************************************************************************/
/* */
/* (c) Copyright ISU System Inc. 2004                         */
/* All Rights Reserved                               */
/* */
/******************************************************************************/
/* [생성 Table]                                                               */
/* Timecard내역정보 TTIM330                                        */
/* */
/******************************************************************************/
/* Date        In Charge        Description                                   */
/*----------------------------------------------------------------------------*/
/* 2023-10-20  JWS              Initial Release                               */
/* 2025-07-29  AI Assistant     성능 최적화 (스칼라 서브쿼리 제거, PL/SQL 루프 최소화) */
/******************************************************************************/

    --------- Local 변수 선언 -------------
    LV_BIZ_CD           TSYS903.BIZ_CD%TYPE := 'TIM';
    LV_OBJECT_NM        TSYS903.OBJECT_NM%TYPE := 'P_TIM_TIMECARD_SELECT_HX';

    LN_NULL_YD_EHM      NUMBER := 10;   -- 전날 근무계획이 없을 경우 출근시점 기준으로 인정시켜줄 시간 (10시간 전 근무까지 인정)
    LN_NULL_ND_SHM      NUMBER := 10;   -- 다음날 근무계획이 없을 경우 퇴근시점 기준으로 인정시켜줄 시간 (10시간 전 근무까지 인정)

    -- 날짜 변환 오버헤드를 줄이기 위해 미리 변환
    V_P_YMD_DATE        DATE := TO_DATE(P_YMD, 'YYYYMMDD');
    V_P_YMD_MINUS_1     VARCHAR2(8) := TO_CHAR(V_P_YMD_DATE - 1, 'YYYYMMDD');
    V_P_YMD_PLUS_1      VARCHAR2(8) := TO_CHAR(V_P_YMD_DATE + 1, 'YYYYMMDD');

    -- CUR_SCH 커서의 결과를 저장할 레코드 타입 및 테이블 타입 정의
    -- 이 컬렉션은 MERGE INTO TTIM330의 USING 절에서 사용될 것입니다.
    TYPE r_timecard_data IS RECORD (
        ENTER_CD    VARCHAR2(10),
        SABUN       VARCHAR2(20),
        YD_YMD      VARCHAR2(8),
        YD_SHM      DATE,
        YD_EHM      DATE,
        TD_YMD      VARCHAR2(8),
        TD_SHM      DATE,
        TD_EHM      DATE,
        ND_YMD      VARCHAR2(8),
        ND_SHM      DATE,
        ND_EHM      DATE,
        LV_IN_TIME  DATE, -- 새로 계산된 출근 시간
        LV_OUT_TIME DATE  -- 새로 계산된 퇴근 시간
    );
    TYPE t_timecard_data IS TABLE OF r_timecard_data;
    v_timecard_data t_timecard_data;

    -- TTIM331 및 TTIM720에서 IN/OUT 시간을 미리 집계할 컬렉션 타입 정의
    TYPE r_in_out_times IS RECORD (
        ENTER_CD    VARCHAR2(10),
        SABUN       VARCHAR2(20),
        YMD         VARCHAR2(8),
        MIN_IN_TIME DATE,
        MAX_OUT_TIME DATE
    );
    TYPE t_in_out_times IS TABLE OF r_in_out_times;
    v_in_out_times t_in_out_times;

BEGIN
    P_SQLCODE := '0';
    P_SQLERRM := NULL;

    -- Step 1: TTIM331과 TTIM720에서 필요한 IN/OUT 시간을 미리 집계합니다.
    -- 이 부분이 프로시저 내에서 반복되던 SELECT MIN/MAX INTO LV_IN_TIME/LV_OUT_TIME 쿼리를 대체합니다.
    BEGIN
        SELECT ENTER_CD, SABUN, YMD, MIN(IN_TIME) AS MIN_IN_TIME, MAX(OUT_TIME) AS MAX_OUT_TIME
        BULK COLLECT INTO v_in_out_times
        FROM (
            SELECT A.ENTER_CD, A.SABUN, A.YMD,
                   TO_DATE(NVL2(A.IN_HM, A.YMD || A.IN_HM, ''), 'YYYYMMDDHH24MI') AS IN_TIME,
                   NULL AS OUT_TIME -- IN_TIME만 해당
            FROM TTIM331 A
            WHERE A.ENTER_CD = P_ENTER_CD
              AND (P_SABUN IS NULL OR A.SABUN = P_SABUN)
              AND A.YMD BETWEEN V_P_YMD_MINUS_1 AND V_P_YMD_PLUS_1
            UNION ALL
            SELECT A.ENTER_CD, A.SABUN, A.YMD,
                   A.CHK_TIME AS IN_TIME,
                   NULL AS OUT_TIME -- IN_TIME만 해당
            FROM TTIM720 A
            WHERE A.ENTER_CD = P_ENTER_CD
              AND (P_SABUN IS NULL OR A.SABUN = P_SABUN)
              AND A.CONFIRM_YN = 'Y'
              AND A.GUBUN = 1 -- 출근
              AND A.YMD BETWEEN V_P_YMD_MINUS_1 AND V_P_YMD_PLUS_1
            UNION ALL
            SELECT A.ENTER_CD, A.SABUN, A.YMD,
                   NULL AS IN_TIME, -- OUT_TIME만 해당
                   TO_DATE(NVL2(A.OUT_HM, A.YMD || A.OUT_HM, ''), 'YYYYMMDDHH24MI') + DECODE(A.NEXT_DAY_CHK_YN, 'Y', 1, 0) AS OUT_TIME
            FROM TTIM331 A
            WHERE A.ENTER_CD IN (P_ENTER_CD, 'HT') -- 'HX', 'HT' 조건은 P_ENTER_CD로 대체
              AND (P_SABUN IS NULL OR A.SABUN = P_SABUN)
              AND A.YMD BETWEEN V_P_YMD_MINUS_1 AND V_P_YMD_PLUS_1
            UNION ALL
            SELECT A.ENTER_CD, A.SABUN, A.YMD,
                   NULL AS IN_TIME, -- OUT_TIME만 해당
                   A.CHK_TIME AS OUT_TIME
            FROM TTIM720 A
            WHERE A.ENTER_CD = P_ENTER_CD
              AND (P_SABUN IS NULL OR A.SABUN = P_SABUN)
              AND A.CONFIRM_YN = 'Y'
              AND A.GUBUN = 2 -- 퇴근
              AND A.YMD BETWEEN V_P_YMD_MINUS_1 AND V_P_YMD_PLUS_1
        )
        GROUP BY ENTER_CD, SABUN, YMD;

    EXCEPTION
        WHEN OTHERS THEN
            P_SQLCODE := SQLCODE;
            P_SQLERRM := '출퇴근 시간 집계 중 에러===>' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM, '05', P_SQLERRM, P_CHKID);
            RETURN; -- 에러 발생 시 프로시저 종료
    END;


    -- Step 2: CUR_SCH 커서의 쿼리를 최적화하여 한 번에 모든 데이터를 가져옵니다.
    -- 스칼라 서브쿼리를 LEFT JOIN으로 변경하고, TTIM331/TTIM720의 집계 결과를 조인합니다.
    BEGIN
        SELECT
            A.ENTER_CD,
            A.SABUN,
            A.YD_YMD,
            A.YD_SHM,
            NVL(A.YD_EHM, A.TD_SHM - LN_NULL_YD_EHM / 24) AS YD_EHM,
            A.TD_YMD,
            LEAST(A.TD_SHM, NVL(S_REQ.MIN_REQ_S_HM, TO_DATE(A.TD_YMD || '2359', 'YYYYMMDDHH24MI'))) AS TD_SHM,
            GREATEST(A.TD_EHM, NVL(S_REQ.MAX_REQ_E_HM, TO_DATE(A.TD_YMD || '0000', 'YYYYMMDDHH24MI'))) AS TD_EHM,
            A.ND_YMD,
            NVL(A.ND_SHM, A.TD_EHM + LN_NULL_ND_SHM / 24) AS ND_SHM,
            A.ND_EHM,
            -- 미리 집계된 IN/OUT 시간을 가져와서 조건에 맞춰 최종 LV_IN_TIME, LV_OUT_TIME 계산
            (SELECT MIN(iot.MIN_IN_TIME) FROM TABLE(v_in_out_times) iot
             WHERE iot.ENTER_CD = A.ENTER_CD AND iot.SABUN = A.SABUN AND iot.YMD = A.TD_YMD
               AND iot.MIN_IN_TIME BETWEEN A.YD_EHM AND A.TD_SHM) AS LV_IN_TIME,
            (SELECT MAX(iot.MAX_OUT_TIME) FROM TABLE(v_in_out_times) iot
             WHERE iot.ENTER_CD = A.ENTER_CD AND iot.SABUN = A.SABUN AND iot.YMD = A.TD_YMD
               AND iot.MAX_OUT_TIME BETWEEN A.TD_EHM AND A.ND_SHM) AS LV_OUT_TIME
        BULK COLLECT INTO v_timecard_data -- 모든 결과를 컬렉션에 한 번에 담습니다.
        FROM
            (
                SELECT /*+ MATERIALIZE */ -- 이 힌트를 통해 인라인 뷰 결과를 먼저 생성하여 반복 접근 효율화 (선택적)
                    A.ENTER_CD,
                    A.SABUN,
                    LAG(A.YMD) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) AS YD_YMD,
                    TO_DATE(LAG(A.YMD) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) || LAG(NVL(A.SHM, B.WORK_SHM)) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD), 'YYYYMMDDHH24MI') AS YD_SHM,
                    TO_DATE(LAG(A.YMD) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) || LAG(NVL(A.EHM, B.WORK_EHM)) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD), 'YYYYMMDDHH24MI')
                        + CASE WHEN LAG(NVL(A.SHM, B.WORK_SHM)) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) >= LAG(NVL(A.EHM, B.WORK_EHM)) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) THEN 1 ELSE 0 END AS YD_EHM,
                    A.YMD AS TD_YMD,
                    TO_DATE(A.YMD || NVL(A.SHM, B.WORK_SHM), 'YYYYMMDDHH24MI') AS TD_SHM,
                    TO_DATE(A.YMD || NVL(A.EHM, B.WORK_EHM), 'YYYYMMDDHH24MI')
                        + CASE WHEN NVL(A.SHM, B.WORK_SHM) >= NVL(A.EHM, B.WORK_EHM) THEN 1 ELSE 0 END AS TD_EHM,
                    LEAD(A.YMD) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) AS ND_YMD,
                    TO_DATE(LEAD(A.YMD) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) || LEAD(NVL(A.SHM, B.WORK_SHM)) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD), 'YYYYMMDDHH24MI') AS ND_SHM,
                    TO_DATE(LEAD(A.YMD) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) || LEAD(NVL(A.EHM, B.WORK_EHM)) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD), 'YYYYMMDDHH24MI')
                        + CASE WHEN LEAD(NVL(A.SHM, B.WORK_SHM)) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) >= LEAD(NVL(A.EHM, B.WORK_EHM)) OVER (PARTITION BY A.ENTER_CD, A.SABUN ORDER BY A.YMD) THEN 1 ELSE 0 END AS ND_EHM
                FROM
                    TTIM120_V A,
                    TTIM051 B
                WHERE
                    A.ENTER_CD = B.ENTER_CD
                    AND A.TIME_CD = B.TIME_CD
                    AND A.STIME_CD = B.STIME_CD
                    AND A.ENTER_CD = P_ENTER_CD
                    AND A.SABUN = NVL(P_SABUN, A.SABUN)
                    AND A.YMD BETWEEN V_P_YMD_MINUS_1 AND V_P_YMD_PLUS_1
            ) A
        LEFT JOIN (
            SELECT
                S.ENTER_CD,
                S.SABUN,
                S.YMD,
                MIN(TO_DATE(S.YMD || S.REQ_S_HM, 'YYYYMMDDHH24MI')) AS MIN_REQ_S_HM,
                MAX(TO_DATE(S.YMD || S.REQ_E_HM, 'YYYYMMDDHH24MI')) AS MAX_REQ_E_HM
            FROM
                TTIM611 S
            JOIN
                THRI103 S2 ON S.ENTER_CD = S2.ENTER_CD AND S.APPL_SEQ = S2.APPL_SEQ
            WHERE
                S2.APPL_STATUS_CD NOT IN ('ZZ', '23', '33', '11')
                AND S.ENTER_CD = P_ENTER_CD -- 필터링 조건 추가 (중요)
                AND (P_SABUN IS NULL OR S.SABUN = P_SABUN) -- 필터링 조건 추가 (중요)
                AND S.YMD BETWEEN V_P_YMD_MINUS_1 AND V_P_YMD_PLUS_1 -- 필터링 조건 추가 (중요)
            GROUP BY
                S.ENTER_CD, S.SABUN, S.YMD
        ) S_REQ ON A.ENTER_CD = S_REQ.ENTER_CD
                AND A.SABUN = S_REQ.SABUN
                AND A.TD_YMD = S_REQ.YMD
        WHERE A.TD_YMD = P_YMD;

    EXCEPTION
        WHEN OTHERS THEN
            P_SQLCODE := SQLCODE;
            P_SQLERRM := '메인 데이터 조회 중 에러===>' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM, '10', P_SQLERRM, P_CHKID);
            RETURN;
    END;

    -- Step 3: MERGE INTO TTIM330 문을 FORALL로 변경하여 배치 처리합니다.
    -- LV_IN_TIME, LV_OUT_TIME 계산 로직을 MERGE USING 절에 통합합니다.
    IF v_timecard_data.COUNT > 0 THEN
        BEGIN
            FORALL i IN 1..v_timecard_data.COUNT
                MERGE INTO TTIM330 T
                USING (
                    SELECT
                        v_timecard_data(i).ENTER_CD  AS ENTER_CD,
                        v_timecard_data(i).TD_YMD    AS YMD,
                        v_timecard_data(i).SABUN     AS SABUN,
                        TO_CHAR(v_timecard_data(i).LV_IN_TIME, 'YYYYMMDD') AS IN_YMD,
                        TO_CHAR(v_timecard_data(i).LV_IN_TIME, 'HH24MI')   AS IN_HM,
                        TO_CHAR(v_timecard_data(i).LV_OUT_TIME, 'YYYYMMDD') AS OUT_YMD,
                        TO_CHAR(v_timecard_data(i).LV_OUT_TIME, 'HH24MI')  AS OUT_HM,
                        SYSDATE AS CHKDATE,
                        P_CHKID AS CHKID
                    FROM DUAL
                ) S
                ON (T.ENTER_CD = S.ENTER_CD
                    AND T.YMD   = S.YMD
                    AND T.SABUN = S.SABUN
                )
                WHEN MATCHED THEN
                    UPDATE SET
                        T.IN_YMD  = S.IN_YMD,
                        T.IN_HM   = S.IN_HM,
                        T.OUT_YMD = S.OUT_YMD,
                        T.OUT_HM  = S.OUT_HM,
                        T.MEMO    = '타각자동',
                        T.CHKDATE = S.CHKDATE,
                        T.CHKID   = S.CHKID
                WHEN NOT MATCHED THEN
                    INSERT (T.ENTER_CD, T.YMD, T.SABUN, T.IN_YMD, T.IN_HM, T.OUT_YMD, T.OUT_HM, T.MEMO, T.CHKDATE, T.CHKID)
                    VALUES (S.ENTER_CD, S.YMD, S.SABUN, S.IN_YMD, S.IN_HM, S.OUT_YMD, S.OUT_HM, '타각자동', S.CHKDATE, S.CHKID);
            COMMIT; -- FORALL 이후 한 번만 커밋
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                P_SQLCODE := SQLCODE;
                P_SQLERRM := 'TTIM330 MERGE 중 에러===>' || SQLERRM;
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM, '30', P_SQLERRM, P_CHKID);
                RETURN;
        END;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        P_SQLCODE := SQLCODE;
        P_SQLERRM := '최종 프로시저 에러===>' || SQLERRM;
        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM, '100', P_SQLERRM, P_CHKID);
END P_TIM_TIMECARD_SELECT_HX;