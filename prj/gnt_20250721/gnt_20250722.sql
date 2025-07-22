--부서/조직정보

WITH TMP AS (
                               SELECT A.ENTER_CD
                                    , A.SABUN
                                    , F_COM_GET_NAMES(A.ENTER_CD, A.SABUN) AS NAME
                                    , A.EMP_YMD
                                    , NVL(C.ORG_CD,B.ORG_CD) AS ORG_CD
                                    , C.WORK_ORG_CD
                                    , F_COM_GET_GRCODE_NAME(B.ENTER_CD, 'H20010', B.JIKGUB_CD)    AS JIKGUB_NM
                                    , F_COM_GET_ORG_NM(B.ENTER_CD, NVL(C.ORG_CD,B.ORG_CD), TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07'), '-', ''),'YYYYMM')),'YYYYMMDD') ) AS ORG_NM
                                    , NVL(F_COM_GET_PRIOR_ORG_TYPE_NM(B.ENTER_CD, NVL(C.ORG_CD,B.ORG_CD), 'B0400', TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07'), '-', ''),'YYYYMM')),'YYYYMMDD') )
                                        ,  F_COM_GET_ORG_NM(B.ENTER_CD, NVL(C.ORG_CD,B.ORG_CD), TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07'), '-', ''),'YYYYMM')),'YYYYMMDD') ))  AS P_ORG_NM
                                    , NVL(F_COM_GET_PRIOR_ORG_TYPE_CD(B.ENTER_CD, NVL(C.ORG_CD,B.ORG_CD), 'B0400', TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07'), '-', ''),'YYYYMM')),'YYYYMMDD') )
                                        ,  B.ORG_CD )  AS P_ORG_CD
, '01' as "01"
, '02' as "02"
, '03' as "03"
, '04' as "04"
, '05' as "05"
, '06' as "06"
, '07' as "07"
, '08' as "08"
, '09' as "09"
, '10' as "10"
, '11' as "11"
, '12' as "12"
, '13' as "13"
, '14' as "14"
, '15' as "15"
, '16' as "16"
, '17' as "17"
, '18' as "18"
, '19' as "19"
, '20' as "20"
, '21' as "21"
, '22' as "22"
, '23' as "23"
, '24' as "24"
                                    
                                  FROM THRM100 A, THRM151 B, TTIM111_V C
                                 WHERE A.ENTER_CD = TRIM('HX')
                                   AND A.ENTER_CD = B.ENTER_CD
                                   AND A.SABUN    = B.SABUN
                                   AND A.SABUN IN (SELECT SABUN from  THRM151_AUTH(TRIM('HX')
                                                        , TRIM('A')
                                                        , TRIM('test128')
                                                        , NVL(TRIM(NULL), TRIM('10'))
                                                        ))
                                   AND TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07'), '-', ''),'YYYYMM')),'YYYYMMDD') BETWEEN B.SDATE AND NVL(B.EDATE,'99991231')
                                   AND A.ENTER_CD = C.ENTER_CD(+)
                                   AND A.SABUN    = C.SABUN(+)
                                   AND REPLACE(TRIM('2025-07'), '-', '')||'01' BETWEEN C.SDATE(+) AND NVL(C.EDATE(+),'99991231')
                                   AND B.STATUS_CD <> 'RAA' -- 관리자 ID 제거
--                                   AND NOT EXISTS (  --임원들은 근무스케줄을 생성하지 않는다.
--                                            SELECT *
--                                              FROM TSYS006 S
--                                             WHERE 1 = 1
--                                               AND S.ENTER_CD  = B.ENTER_CD
--                                               AND S.CODE      = B.JIKGUB_CD
--                                               AND S.GUBUN     = 'A01'
--                                               AND S.GRCODE_CD = 'H20010'
--                                               AND SUBSTR(REPLACE('2025-07','-',''),1,6)||'01' BETWEEN S.SDATE AND NVL(S.EDATE, '99991231')
--                                        )
                                   AND NVL(A.RET_YMD, '99991231' ) >  REPLACE(TRIM('2025-07'), '-', '')||'01'

                                   AND B.ORG_CD = TRIM( 'HX_SELSLUE' )
                )
                SELECT 0 AS DETAIL
                	 , A.SEQ
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
                    , '01' as "Hour_0_0"
                  FROM               
                       (                      
                          SELECT Z.*
                               , F_COM_JIKJE_SORT(Z.ENTER_CD, Z.SABUN, TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07'), '-', ''),'YYYYMM')),'YYYYMMDD')) AS SEQ
                            FROM TMP Z 
                       ) A
order by A.SEQ
;