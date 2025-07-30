SELECT * FROM TABLE(PKG_REPORT_VIEWS.GET_EMP_REPORT_DATA('HX','2025-07', '20250729', 'HX_SELSPBM','test128'));

create or replace PACKAGE PKG_REPORT_VIEWS AS
    -- 뷰의 결과 타입을 정의합니다. (실제 컬럼과 일치하도록 정의해야 함)
    TYPE TY_REPORT_VIEW_REC IS RECORD (
        DETAIL          NUMBER,
        SEQ             NUMBER,
        STATUS_CD       VARCHAR2(10), -- 실제 데이터 타입에 맞게 조정
        ENTER_CD        VARCHAR2(10),
        SABUN           VARCHAR2(20),
        NAME            VARCHAR2(100), -- F_COM_GET_NAMES 반환값 크기
        EMP_YMD         VARCHAR2(8),
        ORG_CD          VARCHAR2(20),
        WORK_ORG_CD     VARCHAR2(20),
        JIKGUB_NM       VARCHAR2(100), -- F_COM_GET_GRCODE_NAME 반환값 크기
        ORG_NM          VARCHAR2(100), -- F_COM_GET_ORG_NM 반환값 크기
        P_ORG_NM        VARCHAR2(100), -- F_COM_GET_PRIOR_ORG_TYPE_NM 반환값 크기
        P_ORG_CD        VARCHAR2(20),
        HOUR_0_0        VARCHAR2(2), -- '01'
        HOL_YN          VARCHAR2(1),
        GNT_CD          VARCHAR2(10),
        GNT_NM          VARCHAR2(100),
        WORK_CD         VARCHAR2(10),
        FLEX_YN         VARCHAR2(1),
        SDATE           VARCHAR2(8), -- TTIM131.SDATE
        EDATE           VARCHAR2(8), -- TTIM131.EDATE
        YMD             VARCHAR2(8), -- TTIM132.YMD
        SHM             VARCHAR2(4), -- TTIM132.SHM
        EHM             VARCHAR2(4), -- TTIM132.EHM
        BASE_SHM        VARCHAR2(4),
        BASE_EHM        VARCHAR2(4)
    );

    TYPE TY_REPORT_VIEW_TABLE IS TABLE OF TY_REPORT_VIEW_REC;

    FUNCTION GET_EMP_REPORT_DATA (
        P_ENTER_CD IN VARCHAR2,
        P_BASE_MONTH_YYYYMM IN VARCHAR2, -- 예: '202507'
        P_BASE_DATE_YYYYMMDD IN VARCHAR2, -- 예: '20250729'
        P_ORG_CD IN VARCHAR2, -- 예: 'HX_SELSPBM'
        P_SEARCH_SABUN IN VARCHAR2
    ) RETURN TY_REPORT_VIEW_TABLE PIPELINED;

END PKG_REPORT_VIEWS;
/

create or replace PACKAGE BODY PKG_REPORT_VIEWS AS

    FUNCTION GET_EMP_REPORT_DATA (
        P_ENTER_CD IN VARCHAR2,
        P_BASE_MONTH_YYYYMM IN VARCHAR2, -- 예: '202507'
        P_BASE_DATE_YYYYMMDD IN VARCHAR2, -- 예: '20250729'
        P_ORG_CD IN VARCHAR2, -- 예: 'HX_SELSPBM'
        P_SEARCH_SABUN IN VARCHAR2
    ) RETURN TY_REPORT_VIEW_TABLE PIPELINED
    AS
        V_REC TY_REPORT_VIEW_REC;
        -- 변환된 날짜 문자열 미리 계산
        V_BASE_MONTH_TO_DATE_STR VARCHAR2(8) := TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM(P_BASE_MONTH_YYYYMM), '-', ''), 'YYYYMM')), 'YYYYMMDD');
    BEGIN
        FOR REC IN (
            WITH TMP AS (
                SELECT A.ENTER_CD, B.STATUS_CD
                     , A.SABUN
                     , F_COM_GET_NAMES(A.ENTER_CD, A.SABUN) AS NAME
                     , A.EMP_YMD
                     , NVL(C.ORG_CD, B.ORG_CD) AS ORG_CD
                     , C.WORK_ORG_CD
                     , F_COM_GET_GRCODE_NAME(B.ENTER_CD, 'H20010', B.JIKGUB_CD) AS JIKGUB_NM
                     , F_COM_GET_ORG_NM(B.ENTER_CD, NVL(C.ORG_CD, B.ORG_CD), V_BASE_MONTH_TO_DATE_STR) AS ORG_NM
                     , NVL(F_COM_GET_PRIOR_ORG_TYPE_NM(B.ENTER_CD, NVL(C.ORG_CD, B.ORG_CD), 'B0400', V_BASE_MONTH_TO_DATE_STR)
                           , F_COM_GET_ORG_NM(B.ENTER_CD, NVL(C.ORG_CD, B.ORG_CD), V_BASE_MONTH_TO_DATE_STR)) AS P_ORG_NM
                     , NVL(F_COM_GET_PRIOR_ORG_TYPE_CD(B.ENTER_CD, NVL(C.ORG_CD, B.ORG_CD), 'B0400', V_BASE_MONTH_TO_DATE_STR)
                           , B.ORG_CD) AS P_ORG_CD
                     , '01' AS "01"
                  FROM THRM100 A, THRM151 B, TTIM111_V C
                 WHERE A.ENTER_CD = P_ENTER_CD
                   AND A.ENTER_CD = B.ENTER_CD
                   AND A.SABUN    = B.SABUN
                   AND A.SABUN IN (SELECT DISTINCT SABUN FROM THRM151_AUTH(P_ENTER_CD, 'A', P_SEARCH_SABUN, '10')) --SEARCH_TYPE 조회구분(자신만조회:P, 권한범위적용:O, 전사:A), AUTH_GRP 권한그룹 10 관리자
                   AND P_BASE_DATE_YYYYMMDD BETWEEN B.SDATE AND NVL(B.EDATE, '99991231')
                   AND A.ENTER_CD = C.ENTER_CD(+)
                   AND A.SABUN    = C.SABUN(+)
                   AND REPLACE(TRIM(P_BASE_MONTH_YYYYMM), '-', '')||'01' BETWEEN C.SDATE(+) AND NVL(C.EDATE(+), '99991231')
                   AND B.STATUS_CD NOT LIKE 'RA%' -- 퇴직자 제외(RAA?)
                   AND (A.RET_YMD IS NULL OR A.RET_YMD = P_BASE_DATE_YYYYMMDD) --당일 퇴직자만 표출
                   AND B.ORG_CD = TRIM(P_ORG_CD) --조직, 없으면 전체
            )
            SELECT 0 AS DETAIL
                 , A.SEQ
                 , A.STATUS_CD
                 , A.ENTER_CD
                 , A.SABUN
                 , A.NAME
                 , A.EMP_YMD
                 , A.ORG_CD
                 , A.WORK_ORG_CD
                 , A.JIKGUB_NM
                 , A.ORG_NM
                 , A.P_ORG_NM
                 , A.P_ORG_CD
                 , '01' AS "HOUR_0_0" -- 컬럼명으로 적합하도록 변경
                 , F_COM_GET_HOL_YN(A.ENTER_CD, P_BASE_DATE_YYYYMMDD) HOL_YN
                 , F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, P_BASE_DATE_YYYYMMDD) GNT_CD
                 , F_TIM_GET_DAY_GNT_NM(A.ENTER_CD, A.SABUN, P_BASE_DATE_YYYYMMDD) GNT_NM
                 , F_TIM_GET_DAY_WORK_CD(A.ENTER_CD, A.SABUN, P_BASE_DATE_YYYYMMDD) WORK_CD
                 , F_TIM_AGILE_SCHEDULE_YN(A.ENTER_CD, A.SABUN, P_BASE_DATE_YYYYMMDD, P_BASE_DATE_YYYYMMDD) FLEX_YN
                 , T9.SDATE
                 , T9.EDATE
                 , T9.YMD
                 , T9.SHM
                 , T9.EHM
                 , NVL(T9.SHM, CASE WHEN F_COM_GET_HOL_YN(A.ENTER_CD, P_BASE_DATE_YYYYMMDD)='Y' THEN '' ELSE '0830' END) AS BASE_SHM
                 , NVL(T9.EHM, CASE WHEN F_COM_GET_HOL_YN(A.ENTER_CD, P_BASE_DATE_YYYYMMDD)='Y' THEN '' ELSE '1730' END) AS BASE_EHM
              FROM (
                    SELECT Z.*
                         , F_COM_JIKJE_SORT(Z.ENTER_CD, Z.SABUN, V_BASE_MONTH_TO_DATE_STR) AS SEQ
                      FROM TMP Z
                   ) A
            LEFT OUTER JOIN (
                SELECT T1.*, T3.ENTER_CD AS T3_ENTER_CD, T3.SABUN AS T3_SABUN, T3.APPL_SEQ AS T3_APPL_SEQ, T3.SDATE, T3.EDATE
                FROM TTIM132 T1
                JOIN (
                    SELECT
                        T2.ENTER_CD,
                        T2.SABUN,
                        T2.APPL_SEQ,
                        T2.SDATE,
                        T2.EDATE,
                        ROW_NUMBER() OVER (PARTITION BY T2.ENTER_CD, T2.SABUN, T2.SDATE, T2.EDATE ORDER BY T2.APPL_SEQ DESC) as rn
                    FROM TTIM131 T2
                    WHERE 1 = (SELECT 1 FROM THRI103 Z WHERE Z.ENTER_CD=T2.ENTER_CD AND Z.APPL_SEQ=T2.APPL_SEQ AND Z.APPL_STATUS_CD='99')
                ) T3 ON T1.ENTER_CD = T3.ENTER_CD
                AND T1.SABUN = T3.SABUN
                AND T1.YMD BETWEEN T3.SDATE AND T3.EDATE
                AND T1.APPL_SEQ = T3.APPL_SEQ
                AND T3.rn = 1
                WHERE T1.ENTER_CD = T3.ENTER_CD
                AND T1.SABUN = T3.SABUN
                AND T1.YMD = P_BASE_DATE_YYYYMMDD
            ) T9
            ON A.ENTER_CD = T9.ENTER_CD
            AND A.SABUN = T9.SABUN
            ORDER BY A.SEQ
        ) LOOP
            V_REC.DETAIL         := REC.DETAIL;
            V_REC.SEQ            := REC.SEQ;
            V_REC.STATUS_CD      := REC.STATUS_CD;
            V_REC.ENTER_CD       := REC.ENTER_CD;
            V_REC.SABUN          := REC.SABUN;
            V_REC.NAME           := REC.NAME;
            V_REC.EMP_YMD        := REC.EMP_YMD;
            V_REC.ORG_CD         := REC.ORG_CD;
            V_REC.WORK_ORG_CD    := REC.WORK_ORG_CD;
            V_REC.JIKGUB_NM      := REC.JIKGUB_NM;
            V_REC.ORG_NM         := REC.ORG_NM;
            V_REC.P_ORG_NM       := REC.P_ORG_NM;
            V_REC.P_ORG_CD       := REC.P_ORG_CD;
            V_REC.HOUR_0_0       := REC.HOUR_0_0;
            V_REC.HOL_YN         := REC.HOL_YN;
            V_REC.GNT_CD         := REC.GNT_CD;
            V_REC.GNT_NM         := REC.GNT_NM;
            V_REC.WORK_CD        := REC.WORK_CD;
            V_REC.FLEX_YN        := REC.FLEX_YN;
            V_REC.SDATE          := REC.SDATE;
            V_REC.EDATE          := REC.EDATE;
            V_REC.YMD            := REC.YMD;
            V_REC.SHM            := REC.SHM;
            V_REC.EHM            := REC.EHM;
            V_REC.BASE_SHM       := REC.BASE_SHM;
            V_REC.BASE_EHM       := REC.BASE_EHM;

            PIPE ROW(V_REC);
        END LOOP;
        RETURN;
    END GET_EMP_REPORT_DATA;

END PKG_REPORT_VIEWS;
/