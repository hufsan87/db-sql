CREATE INDEX IDX_THRM191_CUSTOM ON THRM191 (ENTER_CD, ORD_YMD DESC, APPLY_SEQ DESC);
CREATE INDEX IDX_THRM191_WINDOW_OPT
ON THRM191 (
    ENTER_CD,
    SABUN,
    ORD_YMD DESC,
    APPLY_SEQ DESC
);
CREATE INDEX IDX_THRM191_WINDOW_OPT
ON THRM191 (
    ENTER_CD,
    SABUN,
    ORD_YMD DESC,
    APPLY_SEQ DESC
);
SELECT A.* FROM TABLE(PKG_REPORT_VIEWS.GET_EMP_REPORT_DATA('HX', '20251027', '','','test128')) A ORDER BY A.FLEX_YN,A.GNT_NM;
SELECT A.* FROM TABLE(PKG_REPORT_VIEWS.GET_EMP_REPORT_DATA('HX', '20251027', 'HX_SELSLU','','test128')) A ORDER BY A.FLEX_YN,A.GNT_NM;
SELECT A.* FROM TABLE(PKG_REPORT_VIEWS.GET_EMP_REPORT_DATA('HX', '20251027', 'HX_SELSLU','N','test128')) A ORDER BY A.FLEX_YN,A.GNT_NM;
SELECT A.* FROM TABLE(PKG_REPORT_VIEWS.GET_EMP_REPORT_DATA('HX', '20251027', 'HX_SELSLU','Y','test128')) A ORDER BY A.FLEX_YN,A.GNT_NM;

--HX_SELSLU
--HX_SELSLUE

create or replace PACKAGE BODY PKG_REPORT_VIEWS AS

    FUNCTION GET_EMP_REPORT_DATA (
        P_ENTER_CD IN VARCHAR2,
        P_BASE_YMD IN VARCHAR2, -- 예: '20250729'
        P_ORG_CD_2 IN VARCHAR2, -- 예: 'HX_SELSPBM'
        P_SUB_ORG_YN IN VARCHAR2,
        P_SEARCH_SABUN IN VARCHAR2
    ) RETURN TY_REPORT_VIEW_TABLE PIPELINED
    AS
        V_REC TY_REPORT_VIEW_REC;
    BEGIN
        FOR REC IN (
            WITH TMP AS (
                SELECT A.ENTER_CD, B.STATUS_CD
                     , A.SABUN
                     , F_COM_GET_NAMES(A.ENTER_CD, A.SABUN) AS NAME
                     , A.EMP_YMD
                     , B.ORG_CD
                     , F_COM_GET_GRCODE_NAME(B.ENTER_CD, 'H20010', B.JIKGUB_CD) AS JIKGUB_NM
                     , F_COM_GET_ORG_NM(B.ENTER_CD, B.ORG_CD, P_BASE_YMD) AS ORG_NM
                     , NVL(F_COM_GET_PRIOR_ORG_TYPE_NM(B.ENTER_CD, B.ORG_CD, 'B0400', P_BASE_YMD)
                                , F_COM_GET_ORG_NM(B.ENTER_CD, B.ORG_CD, P_BASE_YMD)) AS P_ORG_NM
                     , NVL(F_COM_GET_PRIOR_ORG_TYPE_CD(B.ENTER_CD, B.ORG_CD, 'B0400', P_BASE_YMD)
                                , B.ORG_CD) AS P_ORG_CD
                     , '01' AS "01"
                     , T191.ORD_E_YMD
                  FROM THRM100 A
                        JOIN THRM151 B ON A.ENTER_CD = B.ENTER_CD AND A.SABUN = B.SABUN
                        LEFT OUTER JOIN (
                                 SELECT
                                        ENTER_CD, SABUN, ORD_E_YMD,
                                        ROW_NUMBER() OVER (PARTITION BY ENTER_CD, SABUN ORDER BY ORD_YMD DESC, APPLY_SEQ DESC) as rn
                                 FROM THRM191
                                 WHERE ORD_YMD <= P_BASE_YMD
                                        AND (STATUS_CD != 'CA' OR (STATUS_CD = 'CA' AND ORD_E_YMD IS NOT NULL))
                        ) T191
                          ON A.ENTER_CD = T191.ENTER_CD
                          AND A.SABUN = T191.SABUN
                          AND T191.rn = 1
                  WHERE A.ENTER_CD = P_ENTER_CD
                   AND A.ENTER_CD = B.ENTER_CD
                   AND A.SABUN   = B.SABUN
                   AND A.SABUN IN (SELECT DISTINCT SABUN FROM THRM151_AUTH(P_ENTER_CD, 'A', P_SEARCH_SABUN, '10'))
                   AND P_BASE_YMD BETWEEN B.SDATE AND NVL(B.EDATE, '99991231')
                   AND B.STATUS_CD NOT LIKE 'RA%'
                   AND (A.RET_YMD IS NULL OR A.RET_YMD = P_BASE_YMD)
                   AND (
                        (P_ORG_CD_2 IS NULL OR P_ORG_CD_2 = '')
                        OR(
                        B.ORG_CD IN (
                         SELECT P_ORG_CD_2 AS ORG_CD FROM DUAL
                         UNION
                         SELECT
                             TORG.ORG_CD
                         FROM
                             TORG105 TORG,
                             (
                                 SELECT
                                     MAX(SDATE) AS MAX_SDATE
                                 FROM
                                     TORG103
                                 WHERE
                                     ENTER_CD = P_ENTER_CD
                                     AND SDATE <= P_BASE_YMD
                                 ) MAX_SDATE_CTE
                         WHERE
                             TORG.ENTER_CD = P_ENTER_CD
                             AND TORG.SDATE = MAX_SDATE_CTE.MAX_SDATE
                             AND P_SUB_ORG_YN = 'Y'
                         START WITH
                             TORG.PRIOR_ORG_CD = P_ORG_CD_2
                         CONNECT BY
                             PRIOR TORG.ENTER_CD = TORG.ENTER_CD
                             AND PRIOR TORG.SDATE = TORG.SDATE
                             AND PRIOR TORG.ORG_CD = TORG.PRIOR_ORG_CD
                         )
                       )
                     )
                 )
            )
             SELECT 0 AS DETAIL
                  , A.SEQ
                  , A.STATUS_CD
                  , A.ENTER_CD
                  , A.SABUN
                  , A.NAME
                  , A.EMP_YMD
                  , A.ORG_CD
                  , A.JIKGUB_NM
                  , A.ORG_NM
                  , A.P_ORG_NM
                  , A.P_ORG_CD
                  , '01' AS "HOUR_0_0"
                  , F_COM_GET_HOL_YN(A.ENTER_CD, P_BASE_YMD) HOL_YN
                  , F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, P_BASE_YMD) GNT_CD
                  , F_TIM_GET_DAY_GNT_NM(A.ENTER_CD, A.SABUN, P_BASE_YMD) GNT_NM
                  , A.ORD_E_YMD
                  , F_TIM_GET_DAY_WORK_CD(A.ENTER_CD, A.SABUN, P_BASE_YMD) WORK_CD
                  , F_TIM_AGILE_SCHEDULE_YN(A.ENTER_CD, A.SABUN, P_BASE_YMD, P_BASE_YMD) FLEX_YN
                  , T9.SDATE
                  , T9.EDATE
                  , T9.YMD
                  , T10.IN_HM
                  , T9.SHM
                  , T9.EHM
                  , NVL(T9.SHM, CASE WHEN F_COM_GET_HOL_YN(A.ENTER_CD, P_BASE_YMD)='Y' THEN '' ELSE '0830' END) AS BASE_SHM
                  , NVL(T9.EHM, CASE WHEN F_COM_GET_HOL_YN(A.ENTER_CD, P_BASE_YMD)='Y' THEN '' ELSE '1730' END) AS BASE_EHM
                  , (
                        SELECT
                            LISTAGG(SUBSTR(X.REAL_S_HM, 0, 2)|| ':' || SUBSTR(X.REAL_S_HM, 3, 2)
                                    || '~' || SUBSTR(X.REAL_E_HM,0 , 2)|| ':' || SUBSTR(X.REAL_E_HM, 3, 2), ',')
                            WITHIN GROUP ( ORDER BY X.REAL_S_HM)
                        FROM
                            TTIM615 X,
                            THRI103 Y
                        WHERE
                            X.ENTER_CD = A.ENTER_CD
                            AND X.ENTER_CD = Y.ENTER_CD
                            AND X.APPL_SEQ = Y.APPL_SEQ
                            AND Y.APPL_STATUS_CD  = '99'
                            AND X.SABUN = A.SABUN
                            AND X.YMD = T9.YMD
                    ) AS OVER_TIMES
              FROM (
                    SELECT Z.*
                         , F_COM_JIKJE_SORT(Z.ENTER_CD, Z.SABUN, P_BASE_YMD) AS SEQ
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
                    JOIN THRI103 Z 
                        ON Z.ENTER_CD = T2.ENTER_CD AND Z.APPL_SEQ = T2.APPL_SEQ
                        WHERE Z.APPL_STATUS_CD = '99'
                ) T3 ON T1.ENTER_CD = T3.ENTER_CD
                AND T1.SABUN = T3.SABUN
                AND T1.YMD BETWEEN T3.SDATE AND T3.EDATE
                AND T1.APPL_SEQ = T3.APPL_SEQ
                AND T3.rn = 1
                WHERE T1.ENTER_CD = T3.ENTER_CD
                AND T1.SABUN = T3.SABUN
                AND T1.YMD = P_BASE_YMD
            ) T9
            ON A.ENTER_CD = T9.ENTER_CD
            AND A.SABUN = T9.SABUN
            LEFT OUTER JOIN (
                SELECT MPT.ENTER_CD,MPT.SABUN,MAX(MPT.IN_HM) IN_HM
                FROM (
                SELECT MT.ENTER_CD,MT.SABUN,MT.YMD,MT.HM AS IN_HM
                FROM TTIM720 MT
                WHERE MT.ENTER_CD=P_ENTER_CD AND MT.YMD = P_BASE_YMD AND MT.HM IS NOT NULL
                UNION ALL 
                SELECT PT.ENTER_CD,PT.SABUN,PT.YMD,PT.IN_HM
                FROM TTIM331 PT
                WHERE PT.ENTER_CD=P_ENTER_CD AND PT.YMD = P_BASE_YMD AND PT.IN_HM IS NOT NULL
                UNION ALL 
                SELECT TT.ENTER_CD,TT.SABUN,TT.YMD,TT.IN_HM
                FROM TTIM335 TT
                WHERE TT.ENTER_CD=P_ENTER_CD AND TT.YMD = P_BASE_YMD AND TT.IN_HM IS NOT NULL
                ) MPT
                GROUP BY MPT.ENTER_CD, MPT.SABUN
            ) T10
            ON A.ENTER_CD = T10.ENTER_CD
            AND A.SABUN = T10.SABUN
            ORDER BY A.SEQ
        ) LOOP
            V_REC.DETAIL       := REC.DETAIL;
            V_REC.SEQ          := REC.SEQ;
            V_REC.STATUS_CD    := REC.STATUS_CD;
            V_REC.ENTER_CD     := REC.ENTER_CD;
            V_REC.SABUN        := REC.SABUN;
            V_REC.NAME         := REC.NAME;
            V_REC.EMP_YMD      := REC.EMP_YMD;
            V_REC.ORG_CD       := REC.ORG_CD;
            V_REC.JIKGUB_NM    := REC.JIKGUB_NM;
            V_REC.ORG_NM       := REC.ORG_NM;
            V_REC.P_ORG_NM     := REC.P_ORG_NM;
            V_REC.P_ORG_CD     := REC.P_ORG_CD;
            V_REC.HOUR_0_0     := REC.HOUR_0_0;
            V_REC.HOL_YN       := REC.HOL_YN;
            V_REC.GNT_CD       := REC.GNT_CD;
            V_REC.GNT_NM       := REC.GNT_NM;
            V_REC.ORD_E_YMD    := REC.ORD_E_YMD;
            V_REC.WORK_CD      := REC.WORK_CD;
            V_REC.FLEX_YN      := REC.FLEX_YN;
            V_REC.SDATE        := REC.SDATE;
            V_REC.EDATE        := REC.EDATE;
            V_REC.YMD          := REC.YMD;
            V_REC.IN_HM        := REC.IN_HM;
            V_REC.SHM          := REC.SHM;
            V_REC.EHM          := REC.EHM;
            V_REC.BASE_SHM     := REC.BASE_SHM;
            V_REC.BASE_EHM     := REC.BASE_EHM;
            V_REC.OVER_TIMES   := REC.OVER_TIMES; -- New column assignment

            PIPE ROW(V_REC);
        END LOOP;
        RETURN;
    END GET_EMP_REPORT_DATA;

END PKG_REPORT_VIEWS;
/
