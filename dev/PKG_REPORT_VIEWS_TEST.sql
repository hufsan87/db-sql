--HX_SELSLU
--HX_SELSLUE

SELECT A.* FROM TABLE(PKG_REPORT_VIEWS.GET_EMP_REPORT_DATA('HX', '20250804', '','','test128')) A ORDER BY A.FLEX_YN,A.GNT_NM;
SELECT A.* FROM TABLE(PKG_REPORT_VIEWS.GET_EMP_REPORT_DATA('HX', '20250804', 'HX_SELSLU','','test128')) A ORDER BY A.FLEX_YN,A.GNT_NM;
SELECT A.* FROM TABLE(PKG_REPORT_VIEWS.GET_EMP_REPORT_DATA('HX', '20250804', 'HX_SELSLU','N','test128')) A ORDER BY A.FLEX_YN,A.GNT_NM;
SELECT A.* FROM TABLE(PKG_REPORT_VIEWS.GET_EMP_REPORT_DATA('HX', '20250804', 'HX_SELSLU','Y','test128')) A ORDER BY A.FLEX_YN,A.GNT_NM;

--SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
--EXPLAIN PLAN  FOR
WITH TMP AS (
                SELECT A.ENTER_CD, B.STATUS_CD
                     , A.SABUN
                     , F_COM_GET_NAMES(A.ENTER_CD, A.SABUN) AS NAME
                     , A.EMP_YMD
                     , B.ORG_CD
                     , F_COM_GET_GRCODE_NAME(B.ENTER_CD, 'H20010', B.JIKGUB_CD) AS JIKGUB_NM
                     , F_COM_GET_ORG_NM(B.ENTER_CD, B.ORG_CD, '20250801') AS ORG_NM
                     , NVL(F_COM_GET_PRIOR_ORG_TYPE_NM(B.ENTER_CD, B.ORG_CD, 'B0400', '20250801')
                           , F_COM_GET_ORG_NM(B.ENTER_CD, B.ORG_CD, '20250801')) AS P_ORG_NM
                     , NVL(F_COM_GET_PRIOR_ORG_TYPE_CD(B.ENTER_CD, B.ORG_CD, 'B0400', '20250801')
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
								  WHERE ORD_YMD <= '20250801'
                                    AND (STATUS_CD != 'CA' OR (STATUS_CD = 'CA' AND ORD_E_YMD IS NOT NULL)) -- 조건 추가
						) T191
						  ON A.ENTER_CD = T191.ENTER_CD
						  AND A.SABUN = T191.SABUN
						  AND T191.rn = 1
                  WHERE A.ENTER_CD = 'HX'
                   AND A.ENTER_CD = B.ENTER_CD
                   AND A.SABUN    = B.SABUN
                   AND A.SABUN IN (SELECT DISTINCT SABUN FROM THRM151_AUTH('HX', 'A', 'test128', '10')) --SEARCH_TYPE 조회구분(자신만조회:P, 권한범위적용:O, 전사:A), AUTH_GRP 권한그룹 10 관리자
                   AND '20250801' BETWEEN B.SDATE AND NVL(B.EDATE, '99991231')
                   AND B.STATUS_CD NOT LIKE 'RA%' -- 퇴직자 제외(RAA?)
                   AND (A.RET_YMD IS NULL OR A.RET_YMD = '20250801') --당일 퇴직자만 표출
                   --AND B.ORG_CD = NVL('', B.ORG_CD) --조직, 없으면 전체
                   AND (('HX_SELSLU' IS NULL OR 'HX_SELSLU' = '')
                   OR
                   (B.ORG_CD IN (
                    -- WITH 절을 서브쿼리로 변경
                    SELECT 'HX_SELSLU' AS ORG_CD FROM DUAL
                    UNION
                    SELECT
                        TORG.ORG_CD
                    FROM
                        TORG105 TORG,
                        (
                            SELECT
                                MAX(SDATE) AS max_sdate
                            FROM
                                TORG103
                            WHERE
                                ENTER_CD = 'HX'
                                AND SDATE <= '20250801'
                        ) max_sdate_cte
                    WHERE
                        TORG.ENTER_CD = 'HX'
                        AND TORG.SDATE = max_sdate_cte.max_sdate
                    START WITH
                        TORG.PRIOR_ORG_CD = 'HX_SELSLU'
                    CONNECT BY
                        PRIOR TORG.ENTER_CD = TORG.ENTER_CD
                        AND PRIOR TORG.SDATE = TORG.SDATE
                        AND PRIOR TORG.ORG_CD = TORG.PRIOR_ORG_CD
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
                 , '01' AS "HOUR_0_0" -- 컬럼명으로 적합하도록 변경
                 , F_COM_GET_HOL_YN(A.ENTER_CD, '20250801') HOL_YN
                 , F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, '20250801') GNT_CD
                 , F_TIM_GET_DAY_GNT_NM(A.ENTER_CD, A.SABUN, '20250801') GNT_NM
                 , A.ORD_E_YMD
                 , F_TIM_GET_DAY_WORK_CD(A.ENTER_CD, A.SABUN, '20250801') WORK_CD
                 , F_TIM_AGILE_SCHEDULE_YN(A.ENTER_CD, A.SABUN, '20250801', '20250801') FLEX_YN
                 , T9.SDATE
                 , T9.EDATE
                 , T9.YMD
                 , T10.IN_HM
                 , T9.SHM
                 , T9.EHM
                 , NVL(T9.SHM, CASE WHEN F_COM_GET_HOL_YN(A.ENTER_CD, '20250801')='Y' THEN '' ELSE '0830' END) AS BASE_SHM
                 , NVL(T9.EHM, CASE WHEN F_COM_GET_HOL_YN(A.ENTER_CD, '20250801')='Y' THEN '' ELSE '1730' END) AS BASE_EHM
              FROM (
                    SELECT Z.*
                         , F_COM_JIKJE_SORT(Z.ENTER_CD, Z.SABUN, '20250801') AS SEQ
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
                    --WHERE 1 = (SELECT 1 FROM THRI103 Z WHERE Z.ENTER_CD=T2.ENTER_CD AND Z.APPL_SEQ=T2.APPL_SEQ AND Z.APPL_STATUS_CD='99')
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
                AND T1.YMD = '20250801'
            ) T9
            ON A.ENTER_CD = T9.ENTER_CD
            AND A.SABUN = T9.SABUN
            LEFT OUTER JOIN (
                SELECT MPT.ENTER_CD,MPT.SABUN,MAX(MPT.IN_HM) IN_HM
                FROM (
                SELECT MT.ENTER_CD,MT.SABUN,MT.YMD,MT.HM AS IN_HM
                FROM TTIM720 MT
                WHERE MT.ENTER_CD='HX' AND MT.YMD = '20250801' AND MT.HM IS NOT NULL
                UNION ALL 
                SELECT PT.ENTER_CD,PT.SABUN,PT.YMD,PT.IN_HM
                FROM TTIM331 PT
                WHERE PT.ENTER_CD='HX' AND PT.YMD = '20250801' AND PT.IN_HM IS NOT NULL
                UNION ALL 
                SELECT TT.ENTER_CD,TT.SABUN,TT.YMD,TT.IN_HM
                FROM TTIM335 TT
                WHERE TT.ENTER_CD='HX' AND TT.YMD = '20250801' AND TT.IN_HM IS NOT NULL
                ) MPT
                GROUP BY MPT.ENTER_CD, MPT.SABUN
            ) T10
            ON A.ENTER_CD = T10.ENTER_CD
            AND A.SABUN = T10.SABUN
            ORDER BY A.SEQ;