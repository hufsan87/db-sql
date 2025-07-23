/*
F_TIM_GET_TIME_WORK_CD
P_TIM_WORK_HOUR_CHG
F_TIM_GET_DAY_GNT_NM
F_TIM_GET_DAY_GNT_CD
F_TIM_GET_OT_WORK_TIME
TTIM120_V
*/

SELECT * 
FROM TTIM337 
WHERE ENTER_CD='HX'
    AND YMD>='20250101'
    AND WORK_CD='0090'
ORDER BY YMD DESC;

SELECT * FROM TTIM120_V WHERE SABUN='20220010' AND YMD='20250709';
SELECT * FROM TTIM120_V WHERE SABUN='09700062' AND YMD='20250718';



SELECT /*+ RESULT_CACHE */
                A.*
                    , B.REASON
                    , A.TEMP_DAY_NM AS DAY_NM
                    , A.WORK_YN AS HOL_YN
                    , (CASE
                            WHEN GNT_CD = '88'
                            THEN SUBSTR(A.WORK_SHM,0,2) || ':' || SUBSTR(A.WORK_SHM,3,2) || ' ~ ' || SUBSTR(A.WORK_EHM,0,2) || ':' || SUBSTR(A.WORK_EHM,3,2)
                            WHEN (A.ENTER_CD <> 'HX') AND A.TIME_CD IS NULL
                            THEN '-'
                            WHEN A.REQUEST_USE_TYPE = 'D' OR GNT_CD = '800' OR F_TIM_GET_STATUS_CD(A.ENTER_CD,A.SABUN,A.YMD) IN ('CA', 'EA')
                            THEN CASE
                                    WHEN (A.ENTER_CD = 'HX' AND A.SHM IS NOT NULL AND A.EHM IS NOT NULL)
                                    THEN SUBSTR(A.SHM,0,2) || ':' ||
                                         SUBSTR(A.SHM,3,2) || ' ~ ' ||
                                         SUBSTR(A.EHM,0,2) || ':' ||
                                         SUBSTR(A.EHM,3,2)
                                    ELSE '-'
                                 END
                            WHEN A.WORK_YN = 'N' THEN
                            (CASE WHEN A.REQUEST_USE_TYPE = 'AM' AND A.ENTER_CD <> 'TP' THEN TO_CHAR(TO_DATE(A.HALF_HOLIDAY1,'HH24:MI'), 'HH24:MI')
                                  WHEN A.REQUEST_USE_TYPE = 'AM' AND A.ENTER_CD = 'TP' THEN TO_CHAR(TO_DATE(NVL(A.WORK_SHM, A.HALF_HOLIDAY1),'HH24:MI'), 'HH24:MI') --토파스는 오전반차면 시차출퇴근 대상자면 계획시작시간으로 조회 20250710
                                  WHEN A.ENTER_CD = 'HX' AND A.GNT_CD IS NOT NULL AND A.SHM IS NULL AND A.EHM IS NULL THEN TO_CHAR(TO_DATE(F_TIM_GET_DAY_WORK_TIME(A.ENTER_CD, A.SABUN, A.YMD, A.GNT_CD, 'S', A.WORK_SHM),'HH24:MI'), 'HH24:MI')
                             ELSE TO_CHAR(TO_DATE(A.WORK_SHM,'HH24:MI'), 'HH24:MI') END) --시작시간
                            ||'~'||
                            (CASE WHEN A.REQUEST_USE_TYPE = 'PM' AND A.ENTER_CD <> 'TP' THEN TO_CHAR(TO_DATE(NVL(A.HALF_HOLIDAY1, A.WORK_EHM),'HH24:MI'), 'HH24:MI')
                                  WHEN A.REQUEST_USE_TYPE = 'PM' AND A.ENTER_CD = 'TP' THEN TO_CHAR(TO_DATE(NVL(A.WORK_EHM, A.HALF_HOLIDAY1),'HH24:MI'), 'HH24:MI') --토파스는 오후반차면 시차출퇴근 대상자면 계획종료시간으로 조회 20250710
                                  WHEN A.REQUEST_USE_TYPE = 'AM' THEN TO_CHAR(TO_DATE(A.WORK_EHM,'HH24:MI'), 'HH24:MI')
                                  WHEN A.ENTER_CD = 'HX' AND A.GNT_CD IS NOT NULL AND A.SHM IS NULL AND A.EHM IS NULL THEN TO_CHAR(TO_DATE(F_TIM_GET_DAY_WORK_TIME(A.ENTER_CD, A.SABUN, A.YMD, A.GNT_CD, 'E', A.WORK_EHM),'HH24:MI'), 'HH24:MI')
                             ELSE TO_CHAR(TO_DATE(A.WORK_EHM,'HH24:MI'), 'HH24:MI') END) --종료시간
                            WHEN A.WORK_YN = 'Y' AND A.SHM IS NOT NULL AND A.EHM IS NOT NULL
                            THEN SUBSTR(A.SHM,0,2) || ':' ||
                                 SUBSTR(A.SHM,3,2) || ' ~ ' ||
                                 SUBSTR(A.EHM,0,2) || ':' ||
                                 SUBSTR(A.EHM,3,2)
                        ELSE '-'
                        END) AS PLAN_TIME
                    , NVL((CASE WHEN HOLIDAY_NM IS NULL AND A.WORK_YN = 'Y' THEN '휴일' ELSE HOLIDAY_NM END),'평일') AS DAY_DIV
                    , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS DAY_NM_FONT_COLOR
                    , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS DAY_DIV_FONT_COLOR
                    , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS YMD_FONT_COLOR
                    , DECODE( A.CLOSE_YN, 'Y', 0, 1 ) AS ROW_EDIT
                    , '1' AS CLOSE_YN_EDIT
                    , DECODE(END_YN, 'Y', 0, 1 ) AS END_YN -- 월근태집계마감여부
                    , NVL(A.REASON_GUBUN, B.REASON_GUBUN) AS REASON_GUBUN
                    , NVL(A.REASON_CD, B.REASON_CD) AS REASON_CD
                    , NVL(A.NO_CHEK_CD, B.NO_CHEK_CD) AS NO_CHEK_CD
                    , A.WORK_ORG_CD
                   , A.TIME_CARD_FLAG
         FROM (
                SELECT
                                        --RANK() OVER (ORDER BY  A.SABUN, A.YMD) AS RK
                    --RANK() OVER (ORDER BY F_COM_JIKJE_SORT(A.ENTER_CD, A.SABUN, A.YMD), A.YMD) AS RK
                     A.ENTER_CD
                   , F_COM_GET_ORG_NM(A.ENTER_CD,A.ORG_CD, A.YMD, '') AS ORG_NM
                   , A.SABUN
                   , F_COM_GET_NAMES(A.ENTER_CD,A.SABUN,'') AS NAME
                   , F_COM_GET_NAMES(A.ENTER_CD,A.SABUN,'ALIAS') AS ALIAS
                   , A.JIKGUB_NM
                   , A.JIKWEE_NM
                   , A.JIKCHAK_NM
                   , A.MANAGE_NM
                   , A.WORK_TYPE
                   , A.WORK_TYPE_NM
                   , A.PAY_TYPE_NM
                   , A.PAY_TYPE
                   , A.YMD
                   , A.LOCATION_CD
                   , F.END_YN -- 월근태집계마감여부
                   , CASE WHEN (F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD) IS NOT NULL
                       AND (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X WHERE X.ENTER_CD = A.ENTER_CD AND X.GNT_CD = F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD)) NOT IN ('AM','PM')
                       ) OR F_TIM_GET_STATUS_CD(A.ENTER_CD,A.SABUN,A.YMD) IN ('CA', 'EA') THEN  '' ELSE NVL(C.STIME_CD, C.TIME_CD) END AS TIME_CD
                   , CASE WHEN (F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD) IS NOT NULL
                       AND (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X WHERE X.ENTER_CD = A.ENTER_CD AND X.GNT_CD = F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD)) NOT IN ('AM','PM')
                       ) OR F_TIM_GET_STATUS_CD(A.ENTER_CD,A.SABUN,A.YMD) IN ('CA', 'EA') THEN  '' ELSE NVL(C.STIME_CD, C.TIME_CD) END AS BF_TIME_CD
                   , C.WORK_ORG_CD
                   , (CASE
                       WHEN F_TIM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, A.YMD) IN ('CA', 'EA') OR F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD) NOT IN ('15','16') THEN '0'
                       WHEN D.WORK_YN = 'N' AND B.IN_HM IS NULL AND B.OUT_HM IS NULL THEN '1'
                       ELSE '0' END) TIME_CARD_FLAG
                   , C.WORK_YN
                   , C.SHM
                   , C.EHM
                   , F_TIM_GET_DAY_GNT_NM(A.ENTER_CD, A.SABUN, A.YMD) AS GNT_NM
                   , F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD) AS GNT_CD
                   --, (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X WHERE X.ENTER_CD = A.ENTER_CD AND X.GNT_CD = F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD)) AS REQUEST_USE_TYPE
                    ,CASE
						  WHEN INSTR(F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD), ',') > 0
						       AND (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X
						            WHERE X.ENTER_CD = A.ENTER_CD
						              AND X.GNT_CD = (SUBSTR(F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD), 1, INSTR(F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD), ',') - 1))) IN ('AM','PM')
						       AND  (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X
						            WHERE X.ENTER_CD = A.ENTER_CD
						              AND X.GNT_CD = (LTRIM(SUBSTR(F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD), INSTR(F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD), ',') + 1)))) IN ('AM','PM')
						  THEN 'D'
						  ELSE (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X WHERE X.ENTER_CD = A.ENTER_CD AND X.GNT_CD = F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD))
					   END AS REQUEST_USE_TYPE
                   , B.APPL_YN
                   , B.IN_HM
                   , B.OUT_HM
                   -- , F_TIM_SECOM_TIME_HM(B.ENTER_CD,TO_CHAR(TO_DATE(B.YMD,'YYYYMMDD')-1,'YYYYMMDD'),B.SABUN,2) AS PREV_OUT_HM
                   , CASE WHEN F_TIM_SECOM_TIME_HM(B.ENTER_CD,TO_CHAR(TO_DATE(B.YMD,'YYYYMMDD')-1,'YYYYMMDD'),B.SABUN,2) = '2400' THEN '0000' END AS PREV_OUT_HM
                   , (SELECT X.GNT_GUBUN_CD
                        FROM TTIM014 X
                       WHERE X.ENTER_CD = B.ENTER_CD
                         AND X.GNT_CD   = F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD)) AS GNT_GUBUN_CD
                   , (SELECT IN_HM FROM  TTIM330 WHERE ENTER_CD = A.ENTER_CD AND YMD = A.YMD AND SABUN = A.SABUN ) AS TC_IN_HM
                   , (SELECT OUT_HM FROM TTIM330 WHERE ENTER_CD = A.ENTER_CD AND YMD = A.YMD AND SABUN = A.SABUN ) AS TC_OUT_HM
                   --, (SELECT IN_HM FROM  TTIM730 WHERE ENTER_CD = A.ENTER_CD AND YMD = A.YMD AND SABUN = A.SABUN ) AS EHR_IN_HM
                   --, (SELECT OUT_HM FROM TTIM730 WHERE ENTER_CD = A.ENTER_CD AND YMD = A.YMD AND SABUN = A.SABUN ) AS EHR_OUT_HM
                   , B.MEMO
                   , B.MEMO2
                   , TO_CHAR(B.CHKDATE,'YYYY-MM-DD HH24:MI') AS CHKDATE
                   , B.CHKID
                   , F_COM_GET_NAMES(B.ENTER_CD,B.CHKID,'',TO_CHAR(SYSDATE, 'YYYYMMDD')) CHKNM
                   , (CASE WHEN B.IN_HM IS NOT NULL AND B.OUT_HM IS NOT NULL THEN F_TIM_GET_WORK_TERM_TIME(A.ENTER_CD,A.SABUN,A.YMD,B.IN_HM,B.OUT_HM) ELSE NULL END) AS WORK_TIME
                   , F_TIM_WORK_HM_TEXT(A.ENTER_CD,A.SABUN,A.YMD) AS REAL_WORK_TIME
                   --, (CASE WHEN B.IN_HM IS NOT NULL AND B.OUT_HM IS NOT NULL THEN F_TIM_WORK_HM_TEXT(A.ENTER_CD,A.SABUN,A.YMD) ELSE NULL END) AS REAL_WORK_TIME
                   , D.WORKDAY_STD
                   , D.HALF_HOLIDAY1
                   , D.HALF_HOLIDAY2
                   , CASE WHEN E.ENTER_CD IS NOT NULL
                            THEN TO_CHAR(TO_DATE(D.WORK_SHM2, 'HH24MI') + NVL(E.DECRE_SM, 0) / 24 / 60, 'HH24MI')
                          ELSE NVL(C.SHM, D.WORK_SHM2)
                       END AS WORK_SHM
                   , CASE WHEN E.ENTER_CD IS NOT NULL
                            THEN TO_CHAR(TO_DATE(D.WORK_EHM2, 'HH24MI') - NVL(E.DECRE_EM, 0) / 24 / 60, 'HH24MI')
                          ELSE NVL(C.EHM, D.WORK_EHM2)
                       END AS WORK_EHM
                   , C.BUSINESS_PLACE_CD
                   , ( SELECT HOLIDAY_NM FROM TTIM001 WHERE ENTER_CD = A.ENTER_CD AND YY || MM || DD = A.YMD AND BUSINESS_PLACE_CD = C.BUSINESS_PLACE_CD) AS HOLIDAY_NM
                   , A.DAY_NM AS TEMP_DAY_NM
                   , CASE WHEN D.WORKDAY_STD = '-1' THEN TO_CHAR(TO_DATE(A.YMD, 'YYYYMMDD')-1, 'YYYYMMDD') ELSE  A.YMD END AS CHK_YMD
                   , B.REASON_GUBUN
                   , B.REASON_CD
                   , B.NO_CHEK_CD
                   /*
                   , (SELECT CASE WHEN NVL(Z.IN_HM,'0') = NVL(B.IN_HM,'0') AND NVL(Z.OUT_HM,'0') = NVL(B.OUT_HM,'0') THEN '0'
                                  ELSE '1' END
                        FROM TTIM330 Z
                       WHERE Z.ENTER_CD = A.ENTER_CD AND Z.YMD = A.YMD AND Z.SABUN = A.SABUN) SECOM_MODI_FLAG
                       */
                    , B.UPDATE_YN
                    , B.CLOSE_YN
                    /*
                    , (SELECT X.APPL_SEQ
                         FROM TTIM611 X, THRI103 Y
                        WHERE X.ENTER_CD = A.ENTER_CD
                          AND X.APPL_SEQ = Y.APPL_SEQ
                          AND Y.APPL_STATUS_CD  = '99' -- 결재완료 건 만 조회
                          AND X.SABUN = A.SABUN
                          AND X.YMD = A.YMD
                          AND X.CANCLE_YN <> 'Y'
                        ) AS APPL_SEQ
                       */
                    , B.IC_ISLAND_YN
                    , (
                        SELECT LISTAGG(SUBSTR(X.REAL_S_HM, 0, 2)|| ':' || SUBSTR(X.REAL_S_HM, 3, 2)
                                || '~' || SUBSTR(X.REAL_E_HM,0 , 2)|| ':' || SUBSTR(X.REAL_E_HM, 3, 2), ',') WITHIN GROUP ( ORDER BY X.REAL_S_HM) AS TEST
                        FROM TTIM615 X, THRI103 Y
                        WHERE X.ENTER_CD = A.ENTER_CD
                        AND X.ENTER_CD = Y.ENTER_CD
                        AND X.APPL_SEQ = Y.APPL_SEQ
                        AND Y.APPL_STATUS_CD  = '99' -- 결재완료 건 만 조회
                        AND X.SABUN = A.SABUN
                        AND X.YMD = A.YMD
                    ) AS OVER_TIMES -- 연장근무시각 시작, 종료 xx:xx, xx:xx
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0020')
				         FROM DUAL) AS "WORK_CD_1"
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0040')
				         FROM DUAL) AS "WORK_CD_2"
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0045')
				         FROM DUAL) AS "WORK_CD_3"
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0070')
				         FROM DUAL) AS "WORK_CD_4"
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0090')
				         FROM DUAL) AS "WORK_CD_5"
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0110')
				         FROM DUAL) AS "WORK_CD_6"
                                   FROM (SELECT A1.ENTER_CD
                             , A1.SABUN
                             , A1.NAME
                             , A2.SUN_DATE AS YMD
                             , A2.DAY_NM
                             , B.STATUS_CD
                             , B.JIKGUB_NM
                             , B.JIKWEE_NM
                             , B.JIKCHAK_NM
                             , B.MANAGE_NM
                             , B.SDATE
                             , B.ORG_CD
                             , B.WORK_TYPE
                             , B.WORK_TYPE_NM
                             , B.PAY_TYPE_NM
                             , B.PAY_TYPE
                             , B.LOCATION_CD
                          FROM THRM100 A1, THRM151 B, TSYS007 A2
                             , TTIM111_V C
                         WHERE 1 = 1
                           AND A1.ENTER_CD = C.ENTER_CD (+)
                           AND A1.SABUN    = C.SABUN (+)
                           AND A2.SUN_DATE BETWEEN REPLACE('2025-06-17','-','') AND REPLACE('2025-06-17','-','')
                           AND A1.ENTER_CD = TRIM( 'HX' )
                           AND A1.ENTER_CD = B.ENTER_CD
                           AND (A1.SABUN LIKE '%' || TRIM( '09700062' )|| '%' OR A1.NAME LIKE '%'||TRIM( '09700062' )||'%')
                           AND A1.SABUN    = B.SABUN
                           AND B.SDATE     = ( SELECT MAX(BB.SDATE)
                                                 FROM THRM151 BB
                                                WHERE BB.ENTER_CD = B.ENTER_CD
                                                  AND BB.SABUN    = B.SABUN
                                                  AND A2.SUN_DATE BETWEEN BB.SDATE AND NVL(BB.EDATE, '99991231')
                                              ) -- INDEX 태울려고..
                           AND NOT EXISTS (  --임원들은 연차를 생성하지 않는다.
                SELECT *
                  FROM TSYS006 S
                 WHERE 1 = 1
                   AND S.ENTER_CD  = B.ENTER_CD
                   AND S.CODE      = B.JIKGUB_CD
                   AND S.GUBUN     = 'A01'
                   AND S.GRCODE_CD = 'H20010'
                   AND REPLACE('2025-06-17','-','') BETWEEN S.SDATE AND NVL(S.EDATE, '99991231')
            )
                         ) A
                     , (SELECT
                         S2.ENTER_CD
                       , S1.WORKDAY_STD
                       , S1.WORK_YN
                       , S2.TIME_CD
                       , S2.STIME_CD
                       , S2.WORK_SHM AS WORK_SHM2
                       , S2.WORK_EHM AS WORK_EHM2
                       , S2.HALF_HOLIDAY1
                       , S2.HALF_HOLIDAY2
                    FROM TTIM017 S1
                       , TTIM051 S2
                   WHERE 1 = 1
                     AND S1.ENTER_CD      = S2.ENTER_CD(+)
                     AND S1.TIME_CD       = S2.TIME_CD(+)
                     --AND S2.DEFAULT_YN(+) = 'Y'
                   ) D
                     , V_TTIM821 E
                     , TTIM335 B
                     , TTIM120_V C
                     , TTIM999 F
                 WHERE 1 = 1
                   AND C.ENTER_CD  = TRIM( 'HX' )
                   AND C.YMD BETWEEN REPLACE('2025-06-17','-','') AND REPLACE('2025-06-17','-','')
                   AND C.YMD       = A.YMD
                   AND A.ENTER_CD  = C.ENTER_CD
                   AND A.YMD       = C.YMD
                   AND A.SABUN     = C.SABUN
                   AND C.ENTER_CD  = D.ENTER_CD(+)
                   AND C.TIME_CD   = D.TIME_CD(+)
                   AND C.STIME_CD  = D.STIME_CD(+)
                   AND A.ENTER_CD  = B.ENTER_CD(+)
                   AND A.SABUN     = B.SABUN(+)
                   AND A.YMD       = B.YMD(+)
                   AND A.ENTER_CD  = E.ENTER_CD(+)
                   AND A.SABUN     = E.SABUN(+)
                   AND A.YMD       = E.YMD(+)
                   AND A.ENTER_CD  = F.ENTER_CD(+)
                   AND A.YMD BETWEEN F.YM(+)||'01' AND TO_CHAR(LAST_DAY(TO_DATE(F.YM(+)||'01','YYYYMMDD')), 'YYYYMMDD')
                   AND F.BUSINESS_PLACE_CD(+) = NVL(NULL, 'ALL')

                    ) A,
                   (
                    SELECT A.ENTER_CD
                         , A.SABUN
                         , A.YMD
                         , MAX(A.REASON_GUBUN) KEEP ( DENSE_RANK FIRST ORDER BY A.APPL_SEQ) AS REASON_GUBUN
                         , MAX(A.REASON_CD) KEEP ( DENSE_RANK FIRST ORDER BY A.APPL_SEQ)    AS REASON_CD
                         , MAX(A.NO_CHEK_CD) KEEP ( DENSE_RANK FIRST ORDER BY A.APPL_SEQ)   AS NO_CHEK_CD
                         , MAX(A.REASON) KEEP ( DENSE_RANK FIRST ORDER BY A.APPL_SEQ)   AS REASON
                    FROM TTIM345 A, THRI103 B
                    WHERE  A.ENTER_CD   = B.ENTER_CD
                       AND A.APPL_SEQ   = B.APPL_SEQ
                       AND B.APPL_STATUS_CD IN ('99')
                  GROUP BY A.ENTER_CD
                         , A.SABUN
                         , A.YMD
                    --     , A.REASON
                   ) B
                   WHERE  1=1
                     AND A.ENTER_CD = B.ENTER_CD (+)
                     AND A.SABUN    = B.SABUN (+)
                     AND A.YMD      = B.YMD (+)
                  ORDER BY A.YMD, F_COM_JIKJE_SORT(A.ENTER_CD, A.SABUN, A.YMD);


--------------------------
select DISTINCT CD_TYPE,ENTER_CD from ttim015 ORDER BY ENTER_CD;
--T10030
SELECT * FROM TSYS005 WHERE GRCODE_CD='T10030';

--근태코드 (F_TIM_GET_DAY_GNT_NM)
       SELECT RANK() OVER (ORDER BY A.GNT_CD, A.YMD) AS NUM
            , A.GNT_CD
            , C.GNT_NM
         FROM TTIM405 A , THRI103 B, TTIM014 C
        WHERE 1 = 1
          AND A.ENTER_CD = B.ENTER_CD
          AND A.APPL_SEQ = B.APPL_SEQ
          AND A.ENTER_CD = C.ENTER_CD
          AND A.GNT_CD   = C.GNT_CD
          AND A.UPDATE_YN <> 'Y'
          AND B.APPL_STATUS_CD = '99'
          AND A.ENTER_CD = 'HX'
          --AND A.SABUN    = P_SABUN
          AND A.YMD     >='20250601'  ;
          
SELECT DISTINCT C.GNT_NM,A.GNT_CD
         FROM TTIM405 A , THRI103 B, TTIM014 C
        WHERE 1 = 1
          AND A.ENTER_CD = B.ENTER_CD
          AND A.APPL_SEQ = B.APPL_SEQ
          AND A.ENTER_CD = C.ENTER_CD
          AND A.GNT_CD   = C.GNT_CD
          AND A.UPDATE_YN <> 'Y'
          AND B.APPL_STATUS_CD = '99'
          AND A.ENTER_CD = 'HX'
          --AND A.SABUN    = P_SABUN
          AND A.YMD     >='20240101'  
          ORDER BY 1;
          
SELECT F_TIM_GET_TIME_WORK_CD('HX', '09700062', '20250616', '0020') FROM DUAL; --0800 소정근로

SELECT DISTINCT WORK_CD FROM TTIM337 WHERE ENTER_CD='HX'
AND YMD>='20250101'
;

SELECT * 
FROM TTIM337 
WHERE ENTER_CD='HX'
    AND YMD>='20250101'
    AND WORK_CD='0090'
ORDER BY YMD DESC;

SELECT & fROM TTIM120_V WHERE SAUBN;


--------------------------------
--       SELECT RANK() OVER (ORDER BY A.GNT_CD, A.YMD) AS NUM
--            , A.GNT_CD
--            , C.GNT_NM
SELECT A.SABUN,A.GNT_CD,C.GNT_NM,A.YMD
         FROM TTIM405 A , THRI103 B, TTIM014 C
        WHERE 1 = 1
          AND A.ENTER_CD = B.ENTER_CD
          AND A.APPL_SEQ = B.APPL_SEQ
          AND A.ENTER_CD = C.ENTER_CD
          AND A.GNT_CD   = C.GNT_CD
          AND A.UPDATE_YN <> 'Y'
          AND B.APPL_STATUS_CD = '99'
          AND A.ENTER_CD = 'HX'
          --AND A.SABUN    = '09700062'
          AND A.YMD      >= '20250701'  
          AND C.GNT_NM LIKE '%반차%'
          ORDER BY 1,3 DESC;
          
SELECT F_TIM_GET_DAY_GNT_NM2_MONTH('HX','09700062','20250618') FROM DUAL;


--일근무관리 , 근무코드관련
SELECT /*+ RESULT_CACHE */
                A.*
                    , B.REASON
                    , A.TEMP_DAY_NM AS DAY_NM
                    , A.WORK_YN AS HOL_YN
                    , (CASE
                            WHEN GNT_CD = '88'
                            THEN SUBSTR(A.WORK_SHM,0,2) || ':' || SUBSTR(A.WORK_SHM,3,2) || ' ~ ' || SUBSTR(A.WORK_EHM,0,2) || ':' || SUBSTR(A.WORK_EHM,3,2)
                            WHEN (A.ENTER_CD <> 'HX') AND A.TIME_CD IS NULL
                            THEN '-'
                            WHEN A.REQUEST_USE_TYPE = 'D' OR GNT_CD = '800' OR F_TIM_GET_STATUS_CD(A.ENTER_CD,A.SABUN,A.YMD) IN ('CA', 'EA')
                            THEN CASE
                                    WHEN (A.ENTER_CD = 'HX' AND A.SHM IS NOT NULL AND A.EHM IS NOT NULL)
                                    THEN SUBSTR(A.SHM,0,2) || ':' ||
                                         SUBSTR(A.SHM,3,2) || ' ~ ' ||
                                         SUBSTR(A.EHM,0,2) || ':' ||
                                         SUBSTR(A.EHM,3,2)
                                    ELSE '-'
                                 END
                            WHEN A.WORK_YN = 'N' THEN
                            (CASE WHEN A.REQUEST_USE_TYPE = 'AM' AND A.ENTER_CD <> 'TP' THEN TO_CHAR(TO_DATE(A.HALF_HOLIDAY1,'HH24:MI'), 'HH24:MI')
                                  WHEN A.REQUEST_USE_TYPE = 'AM' AND A.ENTER_CD = 'TP' THEN TO_CHAR(TO_DATE(NVL(A.WORK_SHM, A.HALF_HOLIDAY1),'HH24:MI'), 'HH24:MI') --토파스는 오전반차면 시차출퇴근 대상자면 계획시작시간으로 조회 20250710
                                  WHEN A.ENTER_CD = 'HX' AND A.GNT_CD IS NOT NULL AND A.SHM IS NULL AND A.EHM IS NULL THEN TO_CHAR(TO_DATE(F_TIM_GET_DAY_WORK_TIME(A.ENTER_CD, A.SABUN, A.YMD, A.GNT_CD, 'S', A.WORK_SHM),'HH24:MI'), 'HH24:MI')
                             ELSE TO_CHAR(TO_DATE(A.WORK_SHM,'HH24:MI'), 'HH24:MI') END) --시작시간
                            ||'~'||
                            (CASE WHEN A.REQUEST_USE_TYPE = 'PM' AND A.ENTER_CD <> 'TP' THEN TO_CHAR(TO_DATE(NVL(A.HALF_HOLIDAY1, A.WORK_EHM),'HH24:MI'), 'HH24:MI')
                                  WHEN A.REQUEST_USE_TYPE = 'PM' AND A.ENTER_CD = 'TP' THEN TO_CHAR(TO_DATE(NVL(A.WORK_EHM, A.HALF_HOLIDAY1),'HH24:MI'), 'HH24:MI') --토파스는 오후반차면 시차출퇴근 대상자면 계획종료시간으로 조회 20250710
                                  WHEN A.REQUEST_USE_TYPE = 'AM' THEN TO_CHAR(TO_DATE(A.WORK_EHM,'HH24:MI'), 'HH24:MI')
                                  WHEN A.ENTER_CD = 'HX' AND A.GNT_CD IS NOT NULL AND A.SHM IS NULL AND A.EHM IS NULL THEN TO_CHAR(TO_DATE(F_TIM_GET_DAY_WORK_TIME(A.ENTER_CD, A.SABUN, A.YMD, A.GNT_CD, 'E', A.WORK_EHM),'HH24:MI'), 'HH24:MI')
                             ELSE TO_CHAR(TO_DATE(A.WORK_EHM,'HH24:MI'), 'HH24:MI') END) --종료시간
                            WHEN A.WORK_YN = 'Y' AND A.SHM IS NOT NULL AND A.EHM IS NOT NULL
                            THEN SUBSTR(A.SHM,0,2) || ':' ||
                                 SUBSTR(A.SHM,3,2) || ' ~ ' ||
                                 SUBSTR(A.EHM,0,2) || ':' ||
                                 SUBSTR(A.EHM,3,2)
                        ELSE '-'
                        END) AS PLAN_TIME
                    , NVL((CASE WHEN HOLIDAY_NM IS NULL AND A.WORK_YN = 'Y' THEN '휴일' ELSE HOLIDAY_NM END),'평일') AS DAY_DIV
                    , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS DAY_NM_FONT_COLOR
                    , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS DAY_DIV_FONT_COLOR
                    , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS YMD_FONT_COLOR
                    , DECODE( A.CLOSE_YN, 'Y', 0, 1 ) AS ROW_EDIT
                    , '1' AS CLOSE_YN_EDIT
                    , DECODE(END_YN, 'Y', 0, 1 ) AS END_YN -- 월근태집계마감여부
                    , NVL(A.REASON_GUBUN, B.REASON_GUBUN) AS REASON_GUBUN
                    , NVL(A.REASON_CD, B.REASON_CD) AS REASON_CD
                    , NVL(A.NO_CHEK_CD, B.NO_CHEK_CD) AS NO_CHEK_CD
                    , A.WORK_ORG_CD
                   , A.TIME_CARD_FLAG
         FROM (
                SELECT
                                        --RANK() OVER (ORDER BY  A.SABUN, A.YMD) AS RK
                    --RANK() OVER (ORDER BY F_COM_JIKJE_SORT(A.ENTER_CD, A.SABUN, A.YMD), A.YMD) AS RK
                     A.ENTER_CD
                   , F_COM_GET_ORG_NM(A.ENTER_CD,A.ORG_CD, A.YMD, '') AS ORG_NM
                   , A.SABUN
                   , F_COM_GET_NAMES(A.ENTER_CD,A.SABUN,'') AS NAME
                   , F_COM_GET_NAMES(A.ENTER_CD,A.SABUN,'ALIAS') AS ALIAS
                   , A.JIKGUB_NM
                   , A.JIKWEE_NM
                   , A.JIKCHAK_NM
                   , A.MANAGE_NM
                   , A.WORK_TYPE
                   , A.WORK_TYPE_NM
                   , A.PAY_TYPE_NM
                   , A.PAY_TYPE
                   , A.YMD
                   , A.LOCATION_CD
                   , F.END_YN -- 월근태집계마감여부
                   , CASE WHEN (F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD) IS NOT NULL
                       AND (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X WHERE X.ENTER_CD = A.ENTER_CD AND X.GNT_CD = F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD)) NOT IN ('AM','PM')
                       ) OR F_TIM_GET_STATUS_CD(A.ENTER_CD,A.SABUN,A.YMD) IN ('CA', 'EA') THEN  '' ELSE NVL(C.STIME_CD, C.TIME_CD) END AS TIME_CD
                   , CASE WHEN (F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD) IS NOT NULL
                       AND (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X WHERE X.ENTER_CD = A.ENTER_CD AND X.GNT_CD = F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD)) NOT IN ('AM','PM')
                       ) OR F_TIM_GET_STATUS_CD(A.ENTER_CD,A.SABUN,A.YMD) IN ('CA', 'EA') THEN  '' ELSE NVL(C.STIME_CD, C.TIME_CD) END AS BF_TIME_CD
                   , C.WORK_ORG_CD
                   , (CASE
                       WHEN F_TIM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, A.YMD) IN ('CA', 'EA') OR F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD) NOT IN ('15','16') THEN '0'
                       WHEN D.WORK_YN = 'N' AND B.IN_HM IS NULL AND B.OUT_HM IS NULL THEN '1'
                       ELSE '0' END) TIME_CARD_FLAG
                   , C.WORK_YN
                   , C.SHM
                   , C.EHM
                   , F_TIM_GET_DAY_GNT_NM(A.ENTER_CD, A.SABUN, A.YMD) AS GNT_NM
                   , F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD) AS GNT_CD
                   --, (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X WHERE X.ENTER_CD = A.ENTER_CD AND X.GNT_CD = F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD)) AS REQUEST_USE_TYPE
                    ,CASE
						  WHEN INSTR(F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD), ',') > 0
						       AND (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X
						            WHERE X.ENTER_CD = A.ENTER_CD
						              AND X.GNT_CD = (SUBSTR(F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD), 1, INSTR(F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD), ',') - 1))) IN ('AM','PM')
						       AND  (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X
						            WHERE X.ENTER_CD = A.ENTER_CD
						              AND X.GNT_CD = (LTRIM(SUBSTR(F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD), INSTR(F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD), ',') + 1)))) IN ('AM','PM')
						  THEN 'D'
						  ELSE (SELECT X.REQUEST_USE_TYPE FROM TTIM014 X WHERE X.ENTER_CD = A.ENTER_CD AND X.GNT_CD = F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD))
					   END AS REQUEST_USE_TYPE
                   , B.APPL_YN
                   , B.IN_HM
                   , B.OUT_HM
                   -- , F_TIM_SECOM_TIME_HM(B.ENTER_CD,TO_CHAR(TO_DATE(B.YMD,'YYYYMMDD')-1,'YYYYMMDD'),B.SABUN,2) AS PREV_OUT_HM
                   , CASE WHEN F_TIM_SECOM_TIME_HM(B.ENTER_CD,TO_CHAR(TO_DATE(B.YMD,'YYYYMMDD')-1,'YYYYMMDD'),B.SABUN,2) = '2400' THEN '0000' END AS PREV_OUT_HM
                   , (SELECT X.GNT_GUBUN_CD
                        FROM TTIM014 X
                       WHERE X.ENTER_CD = B.ENTER_CD
                         AND X.GNT_CD   = F_TIM_GET_DAY_GNT_CD(A.ENTER_CD, A.SABUN, A.YMD)) AS GNT_GUBUN_CD
                   , (SELECT IN_HM FROM  TTIM330 WHERE ENTER_CD = A.ENTER_CD AND YMD = A.YMD AND SABUN = A.SABUN ) AS TC_IN_HM
                   , (SELECT OUT_HM FROM TTIM330 WHERE ENTER_CD = A.ENTER_CD AND YMD = A.YMD AND SABUN = A.SABUN ) AS TC_OUT_HM
                   --, (SELECT IN_HM FROM  TTIM730 WHERE ENTER_CD = A.ENTER_CD AND YMD = A.YMD AND SABUN = A.SABUN ) AS EHR_IN_HM
                   --, (SELECT OUT_HM FROM TTIM730 WHERE ENTER_CD = A.ENTER_CD AND YMD = A.YMD AND SABUN = A.SABUN ) AS EHR_OUT_HM
                   , B.MEMO
                   , B.MEMO2
                   , TO_CHAR(B.CHKDATE,'YYYY-MM-DD HH24:MI') AS CHKDATE
                   , B.CHKID
                   , F_COM_GET_NAMES(B.ENTER_CD,B.CHKID,'',TO_CHAR(SYSDATE, 'YYYYMMDD')) CHKNM
                   , (CASE WHEN B.IN_HM IS NOT NULL AND B.OUT_HM IS NOT NULL THEN F_TIM_GET_WORK_TERM_TIME(A.ENTER_CD,A.SABUN,A.YMD,B.IN_HM,B.OUT_HM) ELSE NULL END) AS WORK_TIME
                   , F_TIM_WORK_HM_TEXT(A.ENTER_CD,A.SABUN,A.YMD) AS REAL_WORK_TIME
                   --, (CASE WHEN B.IN_HM IS NOT NULL AND B.OUT_HM IS NOT NULL THEN F_TIM_WORK_HM_TEXT(A.ENTER_CD,A.SABUN,A.YMD) ELSE NULL END) AS REAL_WORK_TIME
                   , D.WORKDAY_STD
                   , D.HALF_HOLIDAY1
                   , D.HALF_HOLIDAY2
                   , CASE WHEN E.ENTER_CD IS NOT NULL
                            THEN TO_CHAR(TO_DATE(D.WORK_SHM2, 'HH24MI') + NVL(E.DECRE_SM, 0) / 24 / 60, 'HH24MI')
                          ELSE NVL(C.SHM, D.WORK_SHM2)
                       END AS WORK_SHM
                   , CASE WHEN E.ENTER_CD IS NOT NULL
                            THEN TO_CHAR(TO_DATE(D.WORK_EHM2, 'HH24MI') - NVL(E.DECRE_EM, 0) / 24 / 60, 'HH24MI')
                          ELSE NVL(C.EHM, D.WORK_EHM2)
                       END AS WORK_EHM
                   , C.BUSINESS_PLACE_CD
                   , ( SELECT HOLIDAY_NM FROM TTIM001 WHERE ENTER_CD = A.ENTER_CD AND YY || MM || DD = A.YMD AND BUSINESS_PLACE_CD = C.BUSINESS_PLACE_CD) AS HOLIDAY_NM
                   , A.DAY_NM AS TEMP_DAY_NM
                   , CASE WHEN D.WORKDAY_STD = '-1' THEN TO_CHAR(TO_DATE(A.YMD, 'YYYYMMDD')-1, 'YYYYMMDD') ELSE  A.YMD END AS CHK_YMD
                   , B.REASON_GUBUN
                   , B.REASON_CD
                   , B.NO_CHEK_CD
                   /*
                   , (SELECT CASE WHEN NVL(Z.IN_HM,'0') = NVL(B.IN_HM,'0') AND NVL(Z.OUT_HM,'0') = NVL(B.OUT_HM,'0') THEN '0'
                                  ELSE '1' END
                        FROM TTIM330 Z
                       WHERE Z.ENTER_CD = A.ENTER_CD AND Z.YMD = A.YMD AND Z.SABUN = A.SABUN) SECOM_MODI_FLAG
                       */
                    , B.UPDATE_YN
                    , B.CLOSE_YN
                    /*
                    , (SELECT X.APPL_SEQ
                         FROM TTIM611 X, THRI103 Y
                        WHERE X.ENTER_CD = A.ENTER_CD
                          AND X.APPL_SEQ = Y.APPL_SEQ
                          AND Y.APPL_STATUS_CD  = '99' -- 결재완료 건 만 조회
                          AND X.SABUN = A.SABUN
                          AND X.YMD = A.YMD
                          AND X.CANCLE_YN <> 'Y'
                        ) AS APPL_SEQ
                       */
                    , B.IC_ISLAND_YN
                    , (
                        SELECT LISTAGG(SUBSTR(X.REAL_S_HM, 0, 2)|| ':' || SUBSTR(X.REAL_S_HM, 3, 2)
                                || '~' || SUBSTR(X.REAL_E_HM,0 , 2)|| ':' || SUBSTR(X.REAL_E_HM, 3, 2), ',') WITHIN GROUP ( ORDER BY X.REAL_S_HM) AS TEST
                        FROM TTIM615 X, THRI103 Y
                        WHERE X.ENTER_CD = A.ENTER_CD
                        AND X.ENTER_CD = Y.ENTER_CD
                        AND X.APPL_SEQ = Y.APPL_SEQ
                        AND Y.APPL_STATUS_CD  = '99' -- 결재완료 건 만 조회
                        AND X.SABUN = A.SABUN
                        AND X.YMD = A.YMD
                    ) AS OVER_TIMES -- 연장근무시각 시작, 종료 xx:xx, xx:xx
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0020')
				         FROM DUAL) AS "WORK_CD_1"
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0040')
				         FROM DUAL) AS "WORK_CD_2"
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0045')
				         FROM DUAL) AS "WORK_CD_3"
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0070')
				         FROM DUAL) AS "WORK_CD_4"
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0090')
				         FROM DUAL) AS "WORK_CD_5"
                                     , (SELECT F_TIM_GET_TIME_WORK_CD(B.ENTER_CD, B.SABUN, B.YMD, '0110')
				         FROM DUAL) AS "WORK_CD_6"
                                   FROM (SELECT A1.ENTER_CD
                             , A1.SABUN
                             , A1.NAME
                             , A2.SUN_DATE AS YMD
                             , A2.DAY_NM
                             , B.STATUS_CD
                             , B.JIKGUB_NM
                             , B.JIKWEE_NM
                             , B.JIKCHAK_NM
                             , B.MANAGE_NM
                             , B.SDATE
                             , B.ORG_CD
                             , B.WORK_TYPE
                             , B.WORK_TYPE_NM
                             , B.PAY_TYPE_NM
                             , B.PAY_TYPE
                             , B.LOCATION_CD
                          FROM THRM100 A1, THRM151 B, TSYS007 A2
                             , TTIM111_V C
                         WHERE 1 = 1
                           AND A1.ENTER_CD = C.ENTER_CD (+)
                           AND A1.SABUN    = C.SABUN (+)
                           AND A2.SUN_DATE BETWEEN REPLACE('2025-06-17','-','') AND REPLACE('2025-06-17','-','')
                           AND A1.ENTER_CD = TRIM( 'HX' )
                           AND A1.ENTER_CD = B.ENTER_CD
                           AND (A1.SABUN LIKE '%' || TRIM( '09700062' )|| '%' OR A1.NAME LIKE '%'||TRIM( '09700062' )||'%')
                           AND A1.SABUN    = B.SABUN
                           AND B.SDATE     = ( SELECT MAX(BB.SDATE)
                                                 FROM THRM151 BB
                                                WHERE BB.ENTER_CD = B.ENTER_CD
                                                  AND BB.SABUN    = B.SABUN
                                                  AND A2.SUN_DATE BETWEEN BB.SDATE AND NVL(BB.EDATE, '99991231')
                                              ) -- INDEX 태울려고..
                           AND NOT EXISTS (  --임원들은 연차를 생성하지 않는다.
                SELECT *
                  FROM TSYS006 S
                 WHERE 1 = 1
                   AND S.ENTER_CD  = B.ENTER_CD
                   AND S.CODE      = B.JIKGUB_CD
                   AND S.GUBUN     = 'A01'
                   AND S.GRCODE_CD = 'H20010'
                   AND REPLACE('2025-06-17','-','') BETWEEN S.SDATE AND NVL(S.EDATE, '99991231')
            )
                         ) A
                     , (SELECT
                         S2.ENTER_CD
                       , S1.WORKDAY_STD
                       , S1.WORK_YN
                       , S2.TIME_CD
                       , S2.STIME_CD
                       , S2.WORK_SHM AS WORK_SHM2
                       , S2.WORK_EHM AS WORK_EHM2
                       , S2.HALF_HOLIDAY1
                       , S2.HALF_HOLIDAY2
                    FROM TTIM017 S1
                       , TTIM051 S2
                   WHERE 1 = 1
                     AND S1.ENTER_CD      = S2.ENTER_CD(+)
                     AND S1.TIME_CD       = S2.TIME_CD(+)
                     --AND S2.DEFAULT_YN(+) = 'Y'
                   ) D
                     , V_TTIM821 E
                     , TTIM335 B
                     , TTIM120_V C
                     , TTIM999 F
                 WHERE 1 = 1
                   AND C.ENTER_CD  = TRIM( 'HX' )
                   AND C.YMD BETWEEN REPLACE('2025-06-17','-','') AND REPLACE('2025-06-17','-','')
                   AND C.YMD       = A.YMD
                   AND A.ENTER_CD  = C.ENTER_CD
                   AND A.YMD       = C.YMD
                   AND A.SABUN     = C.SABUN
                   AND C.ENTER_CD  = D.ENTER_CD(+)
                   AND C.TIME_CD   = D.TIME_CD(+)
                   AND C.STIME_CD  = D.STIME_CD(+)
                   AND A.ENTER_CD  = B.ENTER_CD(+)
                   AND A.SABUN     = B.SABUN(+)
                   AND A.YMD       = B.YMD(+)
                   AND A.ENTER_CD  = E.ENTER_CD(+)
                   AND A.SABUN     = E.SABUN(+)
                   AND A.YMD       = E.YMD(+)
                   AND A.ENTER_CD  = F.ENTER_CD(+)
                   AND A.YMD BETWEEN F.YM(+)||'01' AND TO_CHAR(LAST_DAY(TO_DATE(F.YM(+)||'01','YYYYMMDD')), 'YYYYMMDD')
                   AND F.BUSINESS_PLACE_CD(+) = NVL(NULL, 'ALL')

                    ) A,
                   (
                    SELECT A.ENTER_CD
                         , A.SABUN
                         , A.YMD
                         , MAX(A.REASON_GUBUN) KEEP ( DENSE_RANK FIRST ORDER BY A.APPL_SEQ) AS REASON_GUBUN
                         , MAX(A.REASON_CD) KEEP ( DENSE_RANK FIRST ORDER BY A.APPL_SEQ)    AS REASON_CD
                         , MAX(A.NO_CHEK_CD) KEEP ( DENSE_RANK FIRST ORDER BY A.APPL_SEQ)   AS NO_CHEK_CD
                         , MAX(A.REASON) KEEP ( DENSE_RANK FIRST ORDER BY A.APPL_SEQ)   AS REASON
                    FROM TTIM345 A, THRI103 B
                    WHERE  A.ENTER_CD   = B.ENTER_CD
                       AND A.APPL_SEQ   = B.APPL_SEQ
                       AND B.APPL_STATUS_CD IN ('99')
                  GROUP BY A.ENTER_CD
                         , A.SABUN
                         , A.YMD
                    --     , A.REASON
                   ) B
                   WHERE  1=1
                     AND A.ENTER_CD = B.ENTER_CD (+)
                     AND A.SABUN    = B.SABUN (+)
                     AND A.YMD      = B.YMD (+)
                  ORDER BY A.YMD, F_COM_JIKJE_SORT(A.ENTER_CD, A.SABUN, A.YMD);
----------------------------------------------------------------------------------------
--휴일 : NOTHING
--근무날
    --1차백그라운드
    --반차 : 2차 백그라운드
    --연장근무 : 3차 백그라운드
    --출장

--비근날(연차/연차R 14/14R), 휴일
    --연차 : 1차 백그라운드
    --휴일 : nothing
    --  2차 백그라운드 skip
    --연장근무 : 3차 백그라운드



--------------------------------------------------------------
--공휴일 (토/일/공휴)
SELECT F_COM_GET_HOL_YN('HX','20250815') HOL_YN FROM DUAL;
--연장근무 신청 REQ_S_HM, REQ_E_HM - APPL_SEQ,SABUN,YMD (참고 : BASE_SDATE/EDATE(해당 주, 12시간 방지 체크 용))
SELECT * FROM TTIM611 WHERE ENTER_CD='HX'
AND YMD>='20250701'
; 
--연장근무 결과보고
SELECT * FROM TTIM615 
WHERE ENTER_CD='HX'
    AND SABUN ='20239006'
ORDER BY CHKDATE DESC;

SELECT APPL_SEQ, APPL_STATUS_CD FROM THRI103 WHERE APPL_SEQ='20250714000007';
SELECT APPL_SEQ, APPL_STATUS_CD FROM THRI103 WHERE APPL_SEQ='20250714000006';


--연장근무
                SELECT CASE WHEN COUNT(*) > 0 THEN 'Y' ELSE 'N' END LV_OT_EXIST_YN
                     , MIN(B.REAL_S_HM) AS REAL_S_HM
                     , MAX(B.REAL_E_HM) AS REAL_E_HM
--                  INTO LV_OT_EXIST_YN,
--                       LV_OT_SHM, 
--                       LV_OT_EHM
                  FROM TTIM611 A, TTIM615 B, THRI103 C
                 WHERE A.ENTER_CD = B.ENTER_CD 
                   AND A.APPL_SEQ  = B.PLAN_APPL_SEQ  
                   AND A.ENTER_CD = C.ENTER_CD 
                   AND A.APPL_SEQ = C.APPL_SEQ 
                   AND A.ENTER_CD = 'HX'
                   AND A.SABUN = CSR_SC.SABUN
                   AND A.YMD = CSR_SC.YMD
                   AND C.APPL_STATUS_CD = '99'
                   ;

--근무 있는 날(F_TIM_GET_DAY_GNT_CD('HX','20170016','20250617') IS  NULL)
SELECT F_TIM_GET_DAY_GNT_NM('HX','20170016','20250713') GNT_CD FROM DUAL;
SELECT F_TIM_GET_DAY_GNT_NM('HX','20229026','20250706') GNT_CD FROM DUAL;
SELECT * FROM TTIM120_V WHERE ENTER_CD='HX' AND SABUN='20170016' AND YMD='20250617'; --TIME_CD

--근무 없는 날(F_TIM_GET_DAY_GNT_CD('HX','09700062','20250617') IS NOT NULL)
SELECT F_TIM_GET_DAY_GNT_NM('HX','20170016','20250714') GNT_CD FROM DUAL;
select * from ttim132 where enter_cd='HX' and sabun='20170016' and ymd= '20250618'; --유연 only, 유효레코드 : 99중(ttim131)에 마지막 seq
select * from ttim017 where enter_cd='HX';--유연 이외 표준 근무시간


--[3] wrok_shm
select * From TTIM017 where enter_cd='HX'; --정상(TTIM120_V의 TIME_CD이용)

--지각
select * from TTIM335 where enter_cd='HX' and sabun='09700062' and ymd= '20250617'; --IN_HM, OUT_HM, TIME_CD

SELECT *
FROM THRM100 WHERE ENTER_CD='HX' AND RET_YMD IS NULL
AND SABUN NOT IN (SELECT SABUN FROM TTIM132 WHERE ENTER_CD='HX');


-------------------------------
--연장근무, 기본 : 신청 이용
--연장근무, 과거일자조회 : 결과보고 이용

SELECT * FROM TTIM120_V WHERE ENTER_CD='HX' AND SABUN='20170016' AND YMD='20250701'; --기본, 정상근무, SHM, EHM 없음, TIME_CD 이용
SELECT * FROM TTIM120_V WHERE ENTER_CD='HX' AND SABUN='20170016' AND YMD='20250714'; --기본, 정상근무, SHM, EHM 없음, TIME_CD 이용
SELECT * FROM TTIM120_V WHERE ENTER_CD='HX' AND SABUN='09700062' AND YMD='20250617'; --유연, 정상근무, SHM, EHM 있음
SELECT * FROM TTIM120_V WHERE ENTER_CD='HX' AND SABUN='09700062' AND YMD='20250618'; --유연, 근태(연차), SHM, EHM 없음, TIME_CD 이용


SELECT DISTINCT C.GNT_NM, A.GNT_CD,A.SABUN,A.YMD
         FROM TTIM405 A , THRI103 B, TTIM014 C
        WHERE 1 = 1
          AND A.ENTER_CD = B.ENTER_CD
          AND A.APPL_SEQ = B.APPL_SEQ
          AND A.ENTER_CD = C.ENTER_CD
          AND A.GNT_CD   = C.GNT_CD
          AND A.UPDATE_YN <> 'Y'
          AND B.APPL_STATUS_CD = '99'
          AND A.ENTER_CD = 'HX'
          --AND A.SABUN    = P_SABUN
          AND A.YMD     >='20250601'  ;
          --20220030
SELECT F_TIM_GET_DAY_GNT_CD('HX','20220030','20250708') GNT FROM DUAL;

SELECT * FROM TTIM120_V WHERE ENTER_CD='HX' AND SABUN='20220030' AND YMD='20250708';

--------------------------------------
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
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250701') AS "day01"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250702') AS "day02"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250703') AS "day03"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250704') AS "day04"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250705') AS "day05"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250706') AS "day06"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250707') AS "day07"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250708') AS "day08"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250709') AS "day09"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250710') AS "day10"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250711') AS "day11"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250712') AS "day12"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250713') AS "day13"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250714') AS "day14"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250715') AS "day15"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250716') AS "day16"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250717') AS "day17"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250718') AS "day18"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250719') AS "day19"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250720') AS "day20"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250721') AS "day21"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250722') AS "day22"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250723') AS "day23"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250724') AS "day24"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250725') AS "day25"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250726') AS "day26"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250727') AS "day27"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250728') AS "day28"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250729') AS "day29"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250730') AS "day30"
                                    , F_TIM_GET_DAY_GNT_NM2_MONTH(A.ENTER_CD, A.SABUN, '20250731') AS "day31"
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
                                   AND NOT EXISTS (  --임원들은 근무스케줄을 생성하지 않는다.
                                            SELECT *
                                              FROM TSYS006 S
                                             WHERE 1 = 1
                                               AND S.ENTER_CD  = B.ENTER_CD
                                               AND S.CODE      = B.JIKGUB_CD
                                               AND S.GUBUN     = 'A01'
                                               AND S.GRCODE_CD = 'H20010'
                                               AND SUBSTR(REPLACE('2025-07','-',''),1,6)||'01' BETWEEN S.SDATE AND NVL(S.EDATE, '99991231')
                                        )
                                   AND NVL(A.RET_YMD, '99991231' ) >  REPLACE(TRIM('2025-07'), '-', '')||'01'

                                   AND B.ORG_CD = TRIM( 'HX_SELSAM' )
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
                     , NVL(B."'LAT_UPL_KOR09'", 0) AS LAT_1
                     , NVL(B."'LAT_UPL_KOR10'", 0) AS LAT_2
                     , NVL(B."'LAT_UPL_KOR48'", 0) AS LAT_3
                     , NVL(B."'LAT_UPL_KOR49'", 0) AS LAT_4
                     , NVL(B."'STOP'"  , 0)        AS LAT_5
                     , NVL(B."'OTHERS'", 0)        AS LAT_6
                     , NVL(C.CNT5, 0)              AS CNT5
                     , NVL(C.CNT6, 0)              AS CNT6
                     , CASE WHEN A."day01" = 'CA' THEN '휴직'
                            WHEN A."day01" = 'RA' THEN '퇴직'
                            WHEN A."day01" = 'SAT' THEN '土'
                            WHEN A."day01" = 'SUN' THEN '日'
                            WHEN A."day01" = 'GH' THEN '공휴'
                            WHEN A."day01" = 'WO' THEN '당직'
                            WHEN A."day01" = 'Y' THEN 'O'
                            WHEN A."day01" = 'N' THEN '△'
                            WHEN A."day01" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day01", 2 )
                            END AS "day01"
                     , CASE WHEN A."day02" = 'CA' THEN '휴직'
                            WHEN A."day02" = 'RA' THEN '퇴직'
                            WHEN A."day02" = 'SAT' THEN '土'
                            WHEN A."day02" = 'SUN' THEN '日'
                            WHEN A."day02" = 'GH' THEN '공휴'
                            WHEN A."day02" = 'WO' THEN '당직'
                            WHEN A."day02" = 'Y' THEN 'O'
                            WHEN A."day02" = 'N' THEN '△'
                            WHEN A."day02" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day02", 2 )
                            END AS "day02"
                     , CASE WHEN A."day03" = 'CA' THEN '휴직'
                            WHEN A."day03" = 'RA' THEN '퇴직'
                            WHEN A."day03" = 'SAT' THEN '土'
                            WHEN A."day03" = 'SUN' THEN '日'
                            WHEN A."day03" = 'GH' THEN '공휴'
                            WHEN A."day03" = 'WO' THEN '당직'
                            WHEN A."day03" = 'Y' THEN 'O'
                            WHEN A."day03" = 'N' THEN '△'
                            WHEN A."day03" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day03", 2 )
                            END AS "day03"
                     , CASE WHEN A."day04" = 'CA' THEN '휴직'
                            WHEN A."day04" = 'RA' THEN '퇴직'
                            WHEN A."day04" = 'SAT' THEN '土'
                            WHEN A."day04" = 'SUN' THEN '日'
                            WHEN A."day04" = 'GH' THEN '공휴'
                            WHEN A."day04" = 'WO' THEN '당직'
                            WHEN A."day04" = 'Y' THEN 'O'
                            WHEN A."day04" = 'N' THEN '△'
                            WHEN A."day04" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day04", 2 )
                            END AS "day04"
                     , CASE WHEN A."day05" = 'CA' THEN '휴직'
                            WHEN A."day05" = 'RA' THEN '퇴직'
                            WHEN A."day05" = 'SAT' THEN '土'
                            WHEN A."day05" = 'SUN' THEN '日'
                            WHEN A."day05" = 'GH' THEN '공휴'
                            WHEN A."day05" = 'WO' THEN '당직'
                            WHEN A."day05" = 'Y' THEN 'O'
                            WHEN A."day05" = 'N' THEN '△'
                            WHEN A."day05" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day05", 2 )
                            END AS "day05"
                     , CASE WHEN A."day06" = 'CA' THEN '휴직'
                            WHEN A."day06" = 'RA' THEN '퇴직'
                            WHEN A."day06" = 'SAT' THEN '土'
                            WHEN A."day06" = 'SUN' THEN '日'
                            WHEN A."day06" = 'GH' THEN '공휴'
                            WHEN A."day06" = 'WO' THEN '당직'
                            WHEN A."day06" = 'Y' THEN 'O'
                            WHEN A."day06" = 'N' THEN '△'
                            WHEN A."day06" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day06", 2 )
                            END AS "day06"
                     , CASE WHEN A."day07" = 'CA' THEN '휴직'
                            WHEN A."day07" = 'RA' THEN '퇴직'
                            WHEN A."day07" = 'SAT' THEN '土'
                            WHEN A."day07" = 'SUN' THEN '日'
                            WHEN A."day07" = 'GH' THEN '공휴'
                            WHEN A."day07" = 'WO' THEN '당직'
                            WHEN A."day07" = 'Y' THEN 'O'
                            WHEN A."day07" = 'N' THEN '△'
                            WHEN A."day07" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day07", 2 )
                            END AS "day07"
                     , CASE WHEN A."day08" = 'CA' THEN '휴직'
                            WHEN A."day08" = 'RA' THEN '퇴직'
                            WHEN A."day08" = 'SAT' THEN '土'
                            WHEN A."day08" = 'SUN' THEN '日'
                            WHEN A."day08" = 'GH' THEN '공휴'
                            WHEN A."day08" = 'WO' THEN '당직'
                            WHEN A."day08" = 'Y' THEN 'O'
                            WHEN A."day08" = 'N' THEN '△'
                            WHEN A."day08" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day08", 2 )
                            END AS "day08"
                     , CASE WHEN A."day09" = 'CA' THEN '휴직'
                            WHEN A."day09" = 'RA' THEN '퇴직'
                            WHEN A."day09" = 'SAT' THEN '土'
                            WHEN A."day09" = 'SUN' THEN '日'
                            WHEN A."day09" = 'GH' THEN '공휴'
                            WHEN A."day09" = 'WO' THEN '당직'
                            WHEN A."day09" = 'Y' THEN 'O'
                            WHEN A."day09" = 'N' THEN '△'
                            WHEN A."day09" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day09", 2 )
                            END AS "day09"
                     , CASE WHEN A."day10" = 'CA' THEN '휴직'
                            WHEN A."day10" = 'RA' THEN '퇴직'
                            WHEN A."day10" = 'SAT' THEN '土'
                            WHEN A."day10" = 'SUN' THEN '日'
                            WHEN A."day10" = 'GH' THEN '공휴'
                            WHEN A."day10" = 'WO' THEN '당직'
                            WHEN A."day10" = 'Y' THEN 'O'
                            WHEN A."day10" = 'N' THEN '△'
                            WHEN A."day10" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day10", 2 )
                            END AS "day10"
                     , CASE WHEN A."day11" = 'CA' THEN '휴직'
                            WHEN A."day11" = 'RA' THEN '퇴직'
                            WHEN A."day11" = 'SAT' THEN '土'
                            WHEN A."day11" = 'SUN' THEN '日'
                            WHEN A."day11" = 'GH' THEN '공휴'
                            WHEN A."day11" = 'WO' THEN '당직'
                            WHEN A."day11" = 'Y' THEN 'O'
                            WHEN A."day11" = 'N' THEN '△'
                            WHEN A."day11" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day11", 2 )
                            END AS "day11"
                     , CASE WHEN A."day12" = 'CA' THEN '휴직'
                            WHEN A."day12" = 'RA' THEN '퇴직'
                            WHEN A."day12" = 'SAT' THEN '土'
                            WHEN A."day12" = 'SUN' THEN '日'
                            WHEN A."day12" = 'GH' THEN '공휴'
                            WHEN A."day12" = 'WO' THEN '당직'
                            WHEN A."day12" = 'Y' THEN 'O'
                            WHEN A."day12" = 'N' THEN '△'
                            WHEN A."day12" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day12", 2 )
                            END AS "day12"
                     , CASE WHEN A."day13" = 'CA' THEN '휴직'
                            WHEN A."day13" = 'RA' THEN '퇴직'
                            WHEN A."day13" = 'SAT' THEN '土'
                            WHEN A."day13" = 'SUN' THEN '日'
                            WHEN A."day13" = 'GH' THEN '공휴'
                            WHEN A."day13" = 'WO' THEN '당직'
                            WHEN A."day13" = 'Y' THEN 'O'
                            WHEN A."day13" = 'N' THEN '△'
                            WHEN A."day13" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day13", 2 )
                            END AS "day13"
                     , CASE WHEN A."day14" = 'CA' THEN '휴직'
                            WHEN A."day14" = 'RA' THEN '퇴직'
                            WHEN A."day14" = 'SAT' THEN '土'
                            WHEN A."day14" = 'SUN' THEN '日'
                            WHEN A."day14" = 'GH' THEN '공휴'
                            WHEN A."day14" = 'WO' THEN '당직'
                            WHEN A."day14" = 'Y' THEN 'O'
                            WHEN A."day14" = 'N' THEN '△'
                            WHEN A."day14" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day14", 2 )
                            END AS "day14"
                     , CASE WHEN A."day15" = 'CA' THEN '휴직'
                            WHEN A."day15" = 'RA' THEN '퇴직'
                            WHEN A."day15" = 'SAT' THEN '土'
                            WHEN A."day15" = 'SUN' THEN '日'
                            WHEN A."day15" = 'GH' THEN '공휴'
                            WHEN A."day15" = 'WO' THEN '당직'
                            WHEN A."day15" = 'Y' THEN 'O'
                            WHEN A."day15" = 'N' THEN '△'
                            WHEN A."day15" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day15", 2 )
                            END AS "day15"
                     , CASE WHEN A."day16" = 'CA' THEN '휴직'
                            WHEN A."day16" = 'RA' THEN '퇴직'
                            WHEN A."day16" = 'SAT' THEN '土'
                            WHEN A."day16" = 'SUN' THEN '日'
                            WHEN A."day16" = 'GH' THEN '공휴'
                            WHEN A."day16" = 'WO' THEN '당직'
                            WHEN A."day16" = 'Y' THEN 'O'
                            WHEN A."day16" = 'N' THEN '△'
                            WHEN A."day16" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day16", 2 )
                            END AS "day16"
                     , CASE WHEN A."day17" = 'CA' THEN '휴직'
                            WHEN A."day17" = 'RA' THEN '퇴직'
                            WHEN A."day17" = 'SAT' THEN '土'
                            WHEN A."day17" = 'SUN' THEN '日'
                            WHEN A."day17" = 'GH' THEN '공휴'
                            WHEN A."day17" = 'WO' THEN '당직'
                            WHEN A."day17" = 'Y' THEN 'O'
                            WHEN A."day17" = 'N' THEN '△'
                            WHEN A."day17" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day17", 2 )
                            END AS "day17"
                     , CASE WHEN A."day18" = 'CA' THEN '휴직'
                            WHEN A."day18" = 'RA' THEN '퇴직'
                            WHEN A."day18" = 'SAT' THEN '土'
                            WHEN A."day18" = 'SUN' THEN '日'
                            WHEN A."day18" = 'GH' THEN '공휴'
                            WHEN A."day18" = 'WO' THEN '당직'
                            WHEN A."day18" = 'Y' THEN 'O'
                            WHEN A."day18" = 'N' THEN '△'
                            WHEN A."day18" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day18", 2 )
                            END AS "day18"
                     , CASE WHEN A."day19" = 'CA' THEN '휴직'
                            WHEN A."day19" = 'RA' THEN '퇴직'
                            WHEN A."day19" = 'SAT' THEN '土'
                            WHEN A."day19" = 'SUN' THEN '日'
                            WHEN A."day19" = 'GH' THEN '공휴'
                            WHEN A."day19" = 'WO' THEN '당직'
                            WHEN A."day19" = 'Y' THEN 'O'
                            WHEN A."day19" = 'N' THEN '△'
                            WHEN A."day19" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day19", 2 )
                            END AS "day19"
                     , CASE WHEN A."day20" = 'CA' THEN '휴직'
                            WHEN A."day20" = 'RA' THEN '퇴직'
                            WHEN A."day20" = 'SAT' THEN '土'
                            WHEN A."day20" = 'SUN' THEN '日'
                            WHEN A."day20" = 'GH' THEN '공휴'
                            WHEN A."day20" = 'WO' THEN '당직'
                            WHEN A."day20" = 'Y' THEN 'O'
                            WHEN A."day20" = 'N' THEN '△'
                            WHEN A."day20" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day20", 2 )
                            END AS "day20"
                     , CASE WHEN A."day21" = 'CA' THEN '휴직'
                            WHEN A."day21" = 'RA' THEN '퇴직'
                            WHEN A."day21" = 'SAT' THEN '土'
                            WHEN A."day21" = 'SUN' THEN '日'
                            WHEN A."day21" = 'GH' THEN '공휴'
                            WHEN A."day21" = 'WO' THEN '당직'
                            WHEN A."day21" = 'Y' THEN 'O'
                            WHEN A."day21" = 'N' THEN '△'
                            WHEN A."day21" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day21", 2 )
                            END AS "day21"
                     , CASE WHEN A."day22" = 'CA' THEN '휴직'
                            WHEN A."day22" = 'RA' THEN '퇴직'
                            WHEN A."day22" = 'SAT' THEN '土'
                            WHEN A."day22" = 'SUN' THEN '日'
                            WHEN A."day22" = 'GH' THEN '공휴'
                            WHEN A."day22" = 'WO' THEN '당직'
                            WHEN A."day22" = 'Y' THEN 'O'
                            WHEN A."day22" = 'N' THEN '△'
                            WHEN A."day22" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day22", 2 )
                            END AS "day22"
                     , CASE WHEN A."day23" = 'CA' THEN '휴직'
                            WHEN A."day23" = 'RA' THEN '퇴직'
                            WHEN A."day23" = 'SAT' THEN '土'
                            WHEN A."day23" = 'SUN' THEN '日'
                            WHEN A."day23" = 'GH' THEN '공휴'
                            WHEN A."day23" = 'WO' THEN '당직'
                            WHEN A."day23" = 'Y' THEN 'O'
                            WHEN A."day23" = 'N' THEN '△'
                            WHEN A."day23" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day23", 2 )
                            END AS "day23"
                     , CASE WHEN A."day24" = 'CA' THEN '휴직'
                            WHEN A."day24" = 'RA' THEN '퇴직'
                            WHEN A."day24" = 'SAT' THEN '土'
                            WHEN A."day24" = 'SUN' THEN '日'
                            WHEN A."day24" = 'GH' THEN '공휴'
                            WHEN A."day24" = 'WO' THEN '당직'
                            WHEN A."day24" = 'Y' THEN 'O'
                            WHEN A."day24" = 'N' THEN '△'
                            WHEN A."day24" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day24", 2 )
                            END AS "day24"
                     , CASE WHEN A."day25" = 'CA' THEN '휴직'
                            WHEN A."day25" = 'RA' THEN '퇴직'
                            WHEN A."day25" = 'SAT' THEN '土'
                            WHEN A."day25" = 'SUN' THEN '日'
                            WHEN A."day25" = 'GH' THEN '공휴'
                            WHEN A."day25" = 'WO' THEN '당직'
                            WHEN A."day25" = 'Y' THEN 'O'
                            WHEN A."day25" = 'N' THEN '△'
                            WHEN A."day25" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day25", 2 )
                            END AS "day25"
                     , CASE WHEN A."day26" = 'CA' THEN '휴직'
                            WHEN A."day26" = 'RA' THEN '퇴직'
                            WHEN A."day26" = 'SAT' THEN '土'
                            WHEN A."day26" = 'SUN' THEN '日'
                            WHEN A."day26" = 'GH' THEN '공휴'
                            WHEN A."day26" = 'WO' THEN '당직'
                            WHEN A."day26" = 'Y' THEN 'O'
                            WHEN A."day26" = 'N' THEN '△'
                            WHEN A."day26" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day26", 2 )
                            END AS "day26"
                     , CASE WHEN A."day27" = 'CA' THEN '휴직'
                            WHEN A."day27" = 'RA' THEN '퇴직'
                            WHEN A."day27" = 'SAT' THEN '土'
                            WHEN A."day27" = 'SUN' THEN '日'
                            WHEN A."day27" = 'GH' THEN '공휴'
                            WHEN A."day27" = 'WO' THEN '당직'
                            WHEN A."day27" = 'Y' THEN 'O'
                            WHEN A."day27" = 'N' THEN '△'
                            WHEN A."day27" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day27", 2 )
                            END AS "day27"
                     , CASE WHEN A."day28" = 'CA' THEN '휴직'
                            WHEN A."day28" = 'RA' THEN '퇴직'
                            WHEN A."day28" = 'SAT' THEN '土'
                            WHEN A."day28" = 'SUN' THEN '日'
                            WHEN A."day28" = 'GH' THEN '공휴'
                            WHEN A."day28" = 'WO' THEN '당직'
                            WHEN A."day28" = 'Y' THEN 'O'
                            WHEN A."day28" = 'N' THEN '△'
                            WHEN A."day28" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day28", 2 )
                            END AS "day28"
                     , CASE WHEN A."day29" = 'CA' THEN '휴직'
                            WHEN A."day29" = 'RA' THEN '퇴직'
                            WHEN A."day29" = 'SAT' THEN '土'
                            WHEN A."day29" = 'SUN' THEN '日'
                            WHEN A."day29" = 'GH' THEN '공휴'
                            WHEN A."day29" = 'WO' THEN '당직'
                            WHEN A."day29" = 'Y' THEN 'O'
                            WHEN A."day29" = 'N' THEN '△'
                            WHEN A."day29" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day29", 2 )
                            END AS "day29"
                     , CASE WHEN A."day30" = 'CA' THEN '휴직'
                            WHEN A."day30" = 'RA' THEN '퇴직'
                            WHEN A."day30" = 'SAT' THEN '土'
                            WHEN A."day30" = 'SUN' THEN '日'
                            WHEN A."day30" = 'GH' THEN '공휴'
                            WHEN A."day30" = 'WO' THEN '당직'
                            WHEN A."day30" = 'Y' THEN 'O'
                            WHEN A."day30" = 'N' THEN '△'
                            WHEN A."day30" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day30", 2 )
                            END AS "day30"
                     , CASE WHEN A."day31" = 'CA' THEN '휴직'
                            WHEN A."day31" = 'RA' THEN '퇴직'
                            WHEN A."day31" = 'SAT' THEN '土'
                            WHEN A."day31" = 'SUN' THEN '日'
                            WHEN A."day31" = 'GH' THEN '공휴'
                            WHEN A."day31" = 'WO' THEN '당직'
                            WHEN A."day31" = 'Y' THEN 'O'
                            WHEN A."day31" = 'N' THEN '△'
                            WHEN A."day31" IS NULL THEN ''
                      		ELSE F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10003', A."day31", 2 )
                            END AS "day31"
                  FROM               
                       (                      
                          SELECT A.*
                               , F_COM_JIKJE_SORT(A.ENTER_CD, A.SABUN, TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07'), '-', ''),'YYYYMM')),'YYYYMMDD')) AS SEQ
                            FROM TMP A 
                       ) A
                  LEFT OUTER JOIN
                  (
					SELECT *
					FROM (SELECT A.ENTER_CD
					           , A.SABUN
       						   , CASE WHEN A.STATUS_CD = 'CA' AND A.ORD_DETAIL_CD IN ('LAT_UPL_KOR09', 'LAT_UPL_KOR48', 'LAT_UPL_KOR49','LAT_UPL_KOR10', 'LAT_UPL_KOR50', 'LAT_UPL_KOR30', 'LAT_UPL_KOR29', 'LAT_UPL_KOR51') THEN (CASE WHEN A.ORD_DETAIL_CD IN ('LAT_UPL_KOR30', 'LAT_UPL_KOR29') THEN 'LAT_UPL_KOR48'
																																					                             				                                        WHEN A.ORD_DETAIL_CD IN ('LAT_UPL_KOR51') THEN 'LAT_UPL_KOR49' 
																																					                             				                                        WHEN A.ORD_DETAIL_CD IN ('LAT_UPL_KOR50') THEN 'LAT_UPL_KOR09' 
																																											                                                       ELSE A.ORD_DETAIL_CD END)
					                  WHEN A.STATUS_CD = 'EA' THEN 'STOP'
					                  ELSE 'OTHERS' END AS ORD_DETAIL_CD
					           , A.STATUS_CD
					           , SUM(TO_DATE(NVL(A.EDATE,'99991231'), 'YYYYMMDD') - TO_DATE(A.SDATE, 'YYYYMMDD') + 1) AS DAY_CNT
					      FROM (					            
					            SELECT A.ENTER_CD
					                 , A.SABUN
					                 , A.STATUS_CD
					                 , MIN(A.SDATE) SDATE
					                 , MAX(A.EDATE) EDATE
					                 , DECODE(A.ORD_DETAIL_CD, 'LAT_UPL_KOR51', 'LAT_UPL_KOR49', A.ORD_DETAIL_CD) ORD_DETAIL_CD
					            FROM 
					            (SELECT A.ENTER_CD
					                 , A.SABUN
					                 , A.STATUS_CD
					                 , GREATEST(A.SDATE,REPLACE(TRIM( '2025-07' ),'-','')||'01') AS SDATE --2024.07.29 수정: 휴직의 경우 발령이 중복될 경우(ex 의병,의병연장.. 일수가 중복되어 집계되던 오류수정)
					                 , LEAST(NVL(A.EDATE, '99991231'), TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07'),'-',''), 'YYYYMM')), 'YYYYMMDD'))                                              AS EDATE
					                 , F_TIM_GET_CA_DETAIL_CD(A.ENTER_CD, A.SABUN,
					                                          LEAST(NVL(A.EDATE, '99991231'), TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07'),'-',''), 'YYYYMM')), 'YYYYMMDD')))                      AS ORD_DETAIL_CD -- 휴직발령상세코드가져오기
					            FROM THRM151 A
					            WHERE 1 = 1
					              AND A.ENTER_CD = TRIM( 'HX' )
					              AND REPLACE(TRIM( '2025-07' ),'-','')||'01' <= NVL(A.EDATE, '99991231')
					              AND TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07'),'-',''), 'YYYYMM')), 'YYYYMMDD') >= A.SDATE
					              AND A.STATUS_CD IN ('CA','EA')
					             UNION ALL
					              SELECT B.ENTER_CD
					                  ,  B.SABUN
					                  ,  'CA' STATUS_CD
					                  ,  MIN(B.YMD) SDATE
					                  ,  MAX(B.YMD) EDATE
					                  ,  'LAT_UPL_KOR49' ORD_DETAIL_CD
					               FROM TTIM405 B
					               WHERE B.ENTER_CD = TRIM( 'HX' )
					               AND B.GNT_CD = '223'
					               AND B.YMD LIKE REPLACE(TRIM( '2025-07' ),'-','')||'%'
					               GROUP BY B.ENTER_CD   
					                      , B.SABUN  
					             UNION ALL
					              SELECT A.ENTER_CD
					                  ,  A.SABUN
					                  , 'EA' STATUS_CD
					                  ,  GREATEST(A.SDATE,REPLACE(TRIM( '2025-07'  ),'-','')||'01') AS SDATE
					                  ,  LEAST(NVL(A.EDATE, '99991231'), TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07' ),'-',''), 'YYYYMM')), 'YYYYMMDD')) AS EDATE
					                  ,  'STOP'
					               FROM THRM129 A
					              WHERE 1 = 1
					                AND A.ENTER_CD = TRIM( 'HX' )
					                AND REPLACE(TRIM( '2025-07'  ),'-','')||'01' <= NVL(A.EDATE, '99991231')
					                AND TO_CHAR(LAST_DAY(TO_DATE(REPLACE(TRIM('2025-07' ),'-',''), 'YYYYMM')), 'YYYYMMDD') >= A.SDATE
					                AND A.PUNISH_CD IN ('rRI_010'
					                                   ,'rRI_011'
					                                   ,'rRI_012'
					                                   ,'rRI_013')
                                  ) A
		                           GROUP BY A.ENTER_CD
					                      , A.SABUN
					                      , A.STATUS_CD
					                      , DECODE(A.ORD_DETAIL_CD, 'LAT_UPL_KOR51', 'LAT_UPL_KOR49', A.ORD_DETAIL_CD)					              
					              ) A
					      GROUP BY A.ENTER_CD
					             , A.SABUN
					             , A.ORD_DETAIL_CD
					             , A.STATUS_CD) A PIVOT ( SUM(A.DAY_CNT) FOR ORD_DETAIL_CD
					         IN ('LAT_UPL_KOR09'
					           , 'LAT_UPL_KOR10'
					           , 'LAT_UPL_KOR48'
					           , 'LAT_UPL_KOR49'
					           , 'LAT_UPL_KOR50'
					           , 'LAT_UPL_KOR30'
					           , 'LAT_UPL_KOR29'
					           , 'LAT_UPL_KOR51'
					           , 'STOP'
					           , 'OTHERS'
                  )) T1) B
                  ON A.ENTER_CD = B.ENTER_CD
                  AND A.SABUN    = B.SABUN
                  LEFT OUTER JOIN (
                            SELECT SABUN   -- T10003 (근태종류)
                                 , SUM( CASE WHEN TXT IN ( 'CA', '23' ) THEN 1 ELSE 0 END )                                         AS CNT1  --휴직/병가
                                 , SUM( CASE WHEN TXT IN ( '25', '27' ) THEN 1 ELSE 0 END )                                         AS CNT2  --지각/조퇴
                                 , SUM( CASE WHEN TXT IN ( 'WO' ) THEN 1 ELSE 0 END )                                               AS CNT3  --당직
                                 , SUM( CASE WHEN TXT IN ( '3','7','9','13','17','32','33','34'  ) THEN 1 ELSE 0 END )              AS CNT4  --건강/휴가
                                 , SUM( CASE WHEN TXT = '1' THEN 1 WHEN TXT = '15' THEN 0.5 WHEN TXT = '16' THEN 0.25 ELSE 0 END )  AS CNT5  --년/월차
                                 , SUM( CASE WHEN TXT = '11' THEN 1 WHEN TXT = '41' THEN 0.5 WHEN TXT = '42' THEN 0.25 ELSE 0 END ) AS CNT6  --대체휴가
                            FROM (
                                      SELECT SABUN, "day01" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day02" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day03" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day04" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day05" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day06" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day07" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day08" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day09" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day10" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day11" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day12" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day13" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day14" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day15" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day16" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day17" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day18" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day19" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day20" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day21" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day22" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day23" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day24" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day25" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day26" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day27" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day28" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day29" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day30" AS TXT FROM TMP  UNION ALL                                       SELECT SABUN, "day31" AS TXT FROM TMP                                   )
                             WHERE TXT IS NOT NULL
                            GROUP BY SABUN
                  ) C
                  ON A.SABUN = C.SABUN
        ORDER BY A.SEQ;


-------------------------------------
--근태코드 : 근무/연차/반차...
--근무/연차/반차 : 시작시간~종료시간 (09:00~16:00, 08:30~17:30, ...)
    --연차일경우, 원래 근무시작시간~근무종료시간?
    
--[1]
SELECT F_TIM_GET_DAY_GNT_CD('HX','20240040','20250717') GNT_CD FROM DUAL;
SELECT F_TIM_GET_DAY_GNT_NM('HX','09700062','20250617') GNT_NM FROM DUAL;
--[2]



SELECT * FROM TTIM131 WHERE ENTER_CD='HX' AND SABUN='09700062' ORDER BY APPL_sEQ DESC;
--HX	20250709000329	09700062	20250710	20250809	T010	25/07/09	09700062	99	
--FLEXIBLE_TYPE=T010, APPL_STATUS_CD='99'

SELECT * fROM TSYS005 WHERE GRCODE_CD='T20020' AND ENTER_CD='HX';

select * from TSYS920
where n_title like '%노무%';

SELECT F_TIM_GET_DAY_GNT_CD('HX','20240040','20250717') GNT_CD FROM DUAL;

--[1]근태코드
SELECT F_TIM_GET_DAY_GNT_CD('HX','09700062','20250717') GNT_CD FROM DUAL;
 
 --[2]in_hm, out_hm (지각 정보 체크해주자)
select * From TTIM335;
select * from TTIM335 where enter_cd='HX' and sabun='09700062' and ymd= '20250621';
--[3] wrok_shm
select * From TTIM017 where enter_cd='HX'; 
select * From TTIM017 where enter_cd='KS'; 
select * from TTIM120_V where enter_cd='HX' and sabun='09700062' and ymd= '20250618';
select * from TTIM120;



select * from ttim131 where enter_cd='HX' and sabun='09700062'  order by chkdate desc; --유연근무신청 : sdate,edate
select * from ttim132 where enter_cd='HX' and sabun='09700062' and ymd= '20250618'; --유연 only, 유효레코드 : 99중(ttim131)에 마지막 seq
select * from ttim017 where enter_cd='HX';--유연 이외 표준 근무시간
--ttim120_v : ks : 스케줄쪽 보고,HX : 유연+기본 보는거고

select * from ttim132 where enter_cd='HX' and sabun='09700062' and ymd= '20250616'; --유연 only, 유효레코드 : 99중(ttim131)에 마지막 seq

SELECT * FROM TTIM111_V WHERE ENTER_CD='HX';





--TTIM121 A   -- 개인별근무스케쥴
select * from ttim121 where enter_cd='HX' and sabun='09700062' and ymd= '20250616';
select distinct time_cd from ttim121 where enter_cd='KS';



SELECT * FROM TTIM301;--SABUN,S_YMD~E_YMD,GNT_CD
SELECT * FROM TTIM301 where enter_cd='HX' and sabun='09700062' and s_ymd>='20250601';--SABUN,S_YMD~E_YMD,GNT_CD



--[1]
       SELECT RANK() OVER (ORDER BY A.GNT_CD, A.YMD) AS NUM
            , A.GNT_CD
            , (SELECT GNT_NM FROM TTIM014 WHERE ENTER_CD = A.ENTER_CD AND GNT_CD = A.GNT_CD) AS GNT_NM
         FROM TTIM405 A , THRI103 B, TTIM301 C
        WHERE A.ENTER_CD = B.ENTER_CD
          AND A.APPL_SEQ = B.APPL_SEQ
          AND A.ENTER_CD = C.ENTER_CD
          AND A.APPL_SEQ = C.APPL_SEQ
          AND NVL(A.UPDATE_YN,'N') = 'N'
          AND B.APPL_STATUS_CD = '99'
          AND A.ENTER_CD = 'HX'
          AND A.SABUN    = '20240040'
          AND A.YMD      = '20250717'  ;
          
select A.* From TTIM335 A
WHERE 1=1
          AND A.ENTER_CD = 'HX'
          AND A.SABUN    = '20240040'
    AND A.YMD='20250717'
; --[2]in_hm, out_hm
select A.* From TTIM017 A 
WHERE 1=1
          AND A.ENTER_CD = 'HX'
          AND A.TIME_CD    = '10000'
    ; --[3] wrok_shm

------------------------------------------------
--F_TIME_WORK_INFO_OT
--F_TIM_GET_WORK_HOUR

SELECT F_TIM_GET_TIME_WORK_CD('HX','09700062','20250613','I') FROM DUAL; --연장근무시간

        SELECT A.CD_TYPE
          INTO LV_WORK_CD_TYPE
          FROM TTIM015 A
         WHERE 1 =1
           AND A.ENTER_CD = P_ENTER_CD
           AND A.WORK_CD  = P_WORK_CD
           
SELECT * FROM TTIM015 WHERE ENTER_CD='HX' ORDER BY WORK_CD;


set serveroutput on;

declare
    LV_WORK_CD_TYPE     TTIM015.CD_TYPE%TYPE;
    BEGIN
        SELECT A.CD_TYPE
          INTO LV_WORK_CD_TYPE
          FROM TTIM015 A
         WHERE 1 =1
           AND A.ENTER_CD = 'HX'
           AND A.WORK_CD  = 'W'
        ;
            dbms_output.put_line( 'result : '||LV_WORK_CD_TYPE);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line( 'T10');
    END;


-----------------------------------------------          
SELECT * FROM TTIM405 
WHERE 1=1
AND ENTER_CD='HX' 
AND SABUN='20240040'
ORDER BY CHKDATE DESC
;--SABUN,YM,GNT_CD



SELECT * FROM TTIM301;--SABUN,S_YMD~E_YMD,GNT_CD

SELECT ENTER_CD,GNT_CD FROM TTIM014 WHERE GNT_NM LIKE '%반차';


          
          

SELECT
                    X.CODE
                    ,CASE WHEN LENGTH(X.CODE_NM) > 2 THEN SUBSTR(CODE_NM,0,2)||CHR(13)||CHR(10)||SUBSTR(CODE_NM,3) ELSE X.CODE_NM END AS CODE_NM
                    ,X.SAVE_NAME
                    ,X.SAVE_NAME_DISP
                    ,X.CD_TYPE
                    ,X.TYPE
                    ,X.FORMAT
                FROM(
                    SELECT A.WORK_CD AS CODE
                         , B.WORK_NM AS CODE_NM
                         , 'WORK_CD_' || ROW_NUMBER() over (ORDER BY A.SEQ) AS SAVE_NAME
                         , 'workCd' || ROW_NUMBER() over (ORDER BY A.SEQ) AS SAVE_NAME_DISP
                         , B.CD_TYPE
                         , F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10030', B.CD_TYPE, 1) AS TYPE
                         , F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10030', B.CD_TYPE, 2) AS FORMAT
                    FROM TTIM355 A, TTIM015 B
                    WHERE 1 = 1
                      AND A.ENTER_CD = B.ENTER_CD
                      AND A.WORK_CD = B.WORK_CD
                      AND B.ENTER_CD = 'HX'
                      AND A.WORK_GUBUN_CD = 'A'
                ) X;
                
				SELECT A.TIME_CD AS CODE
				     , A.SHORT_TERM AS CODE_NM
				  FROM TTIM017 A
				 WHERE 1 = 1
				   AND A.ENTER_CD = 'HX'
				 ORDER BY SEQ;
                 
SELECT
                    X.CODE
                    ,CASE WHEN LENGTH(X.CODE_NM) > 2 THEN SUBSTR(CODE_NM,0,2)||CHR(13)||CHR(10)||SUBSTR(CODE_NM,3) ELSE X.CODE_NM END AS CODE_NM
                    ,X.SAVE_NAME
                    ,X.SAVE_NAME_DISP
                    ,X.CD_TYPE
                    ,X.TYPE
                    ,X.FORMAT
                FROM(
                    SELECT A.WORK_CD AS CODE
                         , B.WORK_NM AS CODE_NM
                         , 'WORK_CD_' || ROW_NUMBER() over (ORDER BY A.SEQ) AS SAVE_NAME
                         , 'workCd' || ROW_NUMBER() over (ORDER BY A.SEQ) AS SAVE_NAME_DISP
                         , B.CD_TYPE
                         , F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10030', B.CD_TYPE, 1) AS TYPE
                         , F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10030', B.CD_TYPE, 2) AS FORMAT
                    FROM TTIM355 A, TTIM015 B
                    WHERE 1 = 1
                      AND A.ENTER_CD = B.ENTER_CD
                      AND A.WORK_CD = B.WORK_CD
                      AND B.ENTER_CD = 'HX'
                      AND A.WORK_GUBUN_CD = 'A'
                ) X;
                
SELECT A.*

                      , NVL((CASE WHEN HOLIDAY_NM IS NOT NULL THEN HOLIDAY_NM WHEN A.WORK_YN = 'Y' THEN '휴일' ELSE HOLIDAY_NM END), '평일') AS DAY_DIV

                      , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS DAY_NM_FONT_COLOR
                      , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS DAY_DIV_FONT_COLOR
                      , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS YMD_FONT_COLOR

                      , (CASE WHEN HOLIDAY_NM IS NULL AND A.WORK_YN = 'N' THEN 'N' ELSE 'Y' END) AS HOLIDAY_DIV

                      , (CASE WHEN TO_CHAR(SYSDATE,'YYYYMMDD') > A.YMD THEN (CASE WHEN A.WORK_YN = 'N' AND (A.IN_HM IS NULL OR A.OUT_HM IS NULL) 
                                                                                  THEN (CASE WHEN A.GNT_CD = '결근' THEN 'X'
                                                                                             WHEN A.GNT_CD IS NOT NULL THEN 'O' 
                                                                                             ELSE 'X' END
                                                                                        ) 
                                                                                   ELSE 'O' END
                                                                             )
                              ELSE NULL END) AS WORK_FLAG
                  FROM (
			                SELECT TO_CHAR(TO_DATE(A.YMD, 'YYYYMMDD'), 'YYYY-MM-DD') || ' (' || A.DAY_NM  || ')' AS V_YMD
			                     , A.YMD
			                     , C.TIME_CD
			                     , C.WORK_ORG_CD
			                     , C.WORK_YN
			                     , F_TIM_GET_DAY_GNT_NM(A.ENTER_CD, A.SABUN, A.YMD) AS GNT_CD
			                     , B.IN_HM
			                     , B.OUT_HM

								 , (CASE WHEN B.IN_HM IS NOT NULL AND B.OUT_HM IS NOT NULL THEN F_TIM_GET_WORK_TERM_TIME(A.ENTER_CD,A.SABUN,A.YMD,B.IN_HM,B.OUT_HM) ELSE NULL END) AS WORK_TIME
				                 , F_TIM_WORK_HM_TEXT(A.ENTER_CD, A.SABUN, A.YMD) AS REAL_WORK_TIME

			                     , D.WORKDAY_STD
			                     , NVL(C.SHM, CASE WHEN C.WORK_YN = 'N' THEN D.WORK_SHM ELSE '' END) AS WORK_SHM
			                     , NVL(C.EHM, CASE WHEN C.WORK_YN = 'N' THEN D.WORK_EHM ELSE '' END) AS WORK_EHM
			                     --, E.BUSINESS_PLACE_CD
			                     --, ( SELECT HOLIDAY_NM FROM TTIM001 WHERE ENTER_CD = A.ENTER_CD AND YY || MM || DD = A.YMD AND BUSINESS_PLACE_CD = E.BUSINESS_PLACE_CD) AS HOLIDAY_NM
			                     , F_COM_GET_BP_CD(C.ENTER_CD, C.SABUN, C.YMD) AS BUSINESS_PLACE_CD
			                     , ( SELECT HOLIDAY_NM FROM TTIM001 WHERE ENTER_CD = A.ENTER_CD AND YY || MM || DD = A.YMD AND BUSINESS_PLACE_CD = F_COM_GET_BP_CD(C.ENTER_CD, C.SABUN, C.YMD)) AS HOLIDAY_NM
			                     , A.DAY_NM AS TEMP_DAY_NM

			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0020') AS "WORK_CD_1"
			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0040') AS "WORK_CD_2"
			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0045') AS "WORK_CD_3"
			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0070') AS "WORK_CD_4"
			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0090') AS "WORK_CD_5"
			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0110') AS "WORK_CD_6"
			                FROM (
			                		SELECT A1.ENTER_CD
			                             , A1.SABUN
			                             , A1.NAME
			                             , A2.SUN_DATE AS YMD
			                             , A2.DAY_NM
			                             , B.STATUS_CD
			                             , B.JIKGUB_NM
			                             , B.JIKWEE_NM
			                             , B.JIKCHAK_NM
			                             , B.MANAGE_NM
			                             , B.SDATE
			                             , B.ORG_CD
			                             , B.WORK_TYPE_NM
			                             , B.PAY_TYPE_NM
			                          FROM THRM100 A1, THRM151 B, TSYS007 A2
			                         WHERE A2.SUN_DATE BETWEEN REPLACE('20250615','-','') AND REPLACE('20250622','-','')
			                           AND A1.ENTER_CD = TRIM( 'HX' )
			                           AND A1.SABUN    = TRIM( '09700062' )
			                           AND A1.ENTER_CD = B.ENTER_CD
			                           AND A1.SABUN    = B.SABUN
			                           AND A2.SUN_DATE BETWEEN B.SDATE AND NVL(B.EDATE, '99991231')

			                     ) A
			                     , TTIM335 B, TTIM120_V C, TTIM017 D
			                     --, BP_V E
			                 WHERE A.ENTER_CD = B.ENTER_CD(+)
			                   AND A.SABUN    = B.SABUN(+)
			                   AND A.YMD      = B.YMD(+)
			                   AND A.ENTER_CD = C.ENTER_CD(+)
			                   AND A.YMD      = C.YMD(+)
			                   AND A.SABUN    = C.SABUN(+)
			                   AND C.ENTER_CD = D.ENTER_CD
			                   AND C.TIME_CD  = D.TIME_CD


			                  -- AND A.ENTER_CD = E.ENTER_CD (+)
			                  -- AND A.SABUN    = E.SABUN    (+)
			                  -- AND A.YMD BETWEEN E.SDATE(+) AND NVL(E.EDATE(+), '99991231')
                   ) A
				ORDER BY A.YMD;


WITH TMP AS (
							SELECT A.ENTER_CD, A.YMD, A.SABUN, A.WORK_GRP_CD, A.WORK_ORG_CD
							     , NVL(B.WORK_HH_A, 0) AS WORK_HH_A
							     , NVL(B.WORK_HH_B, 0) AS WORK_HH_B
							     , NVL(B.WORK_MM_A, 0) AS WORK_MM_A
							     , NVL(B.WORK_MM_B, 0) AS WORK_MM_B
							     , ROW_NUMBER() OVER(ORDER BY A.YMD) AS RN
                                 , D.WEEK_START
                                 , D.WEEK_END
                                 , D.WEEK_CNT
                                 , D.RNUM
                                 , A.PLAN_WORK_YN
							FROM TTIM120_V A
							   , ( SELECT X.ENTER_CD, X.YMD, X.SABUN
							           , NVL(SUM(DECODE( Y.DAY_TYPE, '101', X.WORK_HH, 0)),0) AS WORK_HH_A
							           , NVL(SUM(DECODE( Y.DAY_TYPE, '101', 0, X.WORK_HH)),0) AS WORK_HH_B
							           , NVL(SUM(DECODE( Y.DAY_TYPE, '101', X.WORK_MM, 0)),0) AS WORK_MM_A
							           , NVL(SUM(DECODE( Y.DAY_TYPE, '101', 0, X.WORK_MM)),0) AS WORK_MM_B
							         FROM TTIM337 X, TTIM015 Y
							        WHERE X.ENTER_CD = TRIM('HX')
							          AND X.SABUN    = TRIM( '20120026' )
							          AND X.YMD BETWEEN TO_CHAR(TO_DATE(REPLACE('20250713','-',''),'YYYYMMDD')-7,'YYYYMMDD') AND TO_CHAR(TO_DATE(REPLACE('20250719','-',''),'YYYYMMDD')+7,'YYYYMMDD')
							          AND X.ENTER_CD = Y.ENTER_CD
							          AND X.WORK_CD  = Y.WORK_CD
							          AND Y.DAY_TYPE IN ('101', '105' ) --  정규근무(101),야간근무(103),연장근무(105)--휴일근무(201),휴일야간근무(203),휴일연장근무(205)
							        GROUP BY X.ENTER_CD, X.YMD, X.SABUN
							     ) B      
                                , (
                                      SELECT TO_CHAR(WEEK_START, 'YYYYMMDD') WEEK_START
                                           , TO_CHAR(WEEK_END, 'YYYYMMDD') WEEK_END
                                           , ROW_NUMBER()OVER(ORDER BY WEEK_START) AS RNUM
                                           , SUM( CASE WHEN TO_CHAR(WEEK_START, 'YYYYMMDD') BETWEEN REPLACE('20250713','-','') AND REPLACE('20250719','-','')
                                                        AND TO_CHAR(WEEK_END, 'YYYYMMDD') BETWEEN REPLACE('20250713','-','') AND REPLACE('20250719','-','') THEN 1 ELSE 0 END) OVER() AS WEEK_CNT
                                        FROM (
                                               SELECT START_DT AS WEEK_START
                                                    , END_DT AS WEEK_END
                                                 FROM ( SELECT F_TIM_GET_WEEK_START('HX',REPLACE('20250713','-','')) AS START_DT
                                                             , TO_DATE(TRIM(REPLACE('20250719','-','')), 'YYYYMMDD') END_DT
                                                          FROM DUAL  
                                                       )
                                               CONNECT BY LEVEL < END_DT - START_DT
                                              )
                                       WHERE 1=1
                                       GROUP BY WEEK_START, WEEK_END

                                   ) D          
							WHERE A.ENTER_CD  = TRIM('HX')
							  AND A.SABUN 	  = TRIM( '20120026' )
							  AND A.YMD BETWEEN D.WEEK_START AND D.WEEK_END
							  --AND A.YMD BETWEEN REPLACE(:searchSymd,'-','') AND REPLACE(:searchEymd,'-','')
							  AND A.ENTER_CD    = B.ENTER_CD(+)
							  AND A.SABUN       = B.SABUN(+) 
							  AND A.YMD         = B.YMD(+)

				)
				SELECT GUBUN, SDATE, EDATE
                     , F_TIM_FMT_TIME(TRUNC(WORK_HOUR), TRUNC(( WORK_HOUR - TRUNC(WORK_HOUR)) * 60)) AS  WORK_HOUR
                     , F_TIM_FMT_TIME(TRUNC(OT_HOUR), TRUNC(( OT_HOUR - TRUNC(OT_HOUR)) * 60)) AS  OT_HOUR
   					 , '#fdf0f5' AS WORK_HOUR_BACK_COLOR
   					 , '#fdf0f5' AS OT_HOUR_BACK_COLOR
				FROM (						
						SELECT GUBUN, SDATE, EDATE
						     , CASE WHEN INSTR(GUBUN, '일 평균') > 0 THEN NVL( (WORK_HH_A + (WORK_MM_A/60)) / DECODE(WORK_CNT, 0, NULL, WORK_CNT), 0 )
                                    WHEN INSTR(GUBUN, '주 평균') > 0 THEN NVL( (WORK_HH_A + (WORK_MM_A/60)) / DECODE(WEEK_CNT, 0, NULL, WEEK_CNT), 0 )
                                    ELSE (WORK_HH_A + (WORK_MM_A/60)) END AS WORK_HOUR

						     , CASE WHEN INSTR(GUBUN, '일 평균') > 0  THEN NVL( (WORK_HH_B + (WORK_MM_B/60)) / DECODE(WORK_ALL_CNT, 0, NULL, WORK_ALL_CNT), 0 )
                                    WHEN INSTR(GUBUN, '주 평균') > 0  THEN NVL( (WORK_HH_B + (WORK_MM_B/60)) / DECODE(WEEK_CNT, 0, NULL, WEEK_CNT), 0 )
                                    ELSE (WORK_HH_B + (WORK_MM_B/60)) END AS OT_HOUR

						  FROM (
								    SELECT ROW_NUMBER() OVER(ORDER BY MIN(YMD)) || '주차' AS GUBUN
								         , MIN(WEEK_START) AS SDATE
								         , MAX(WEEK_END) AS EDATE
								         , SUM(WORK_HH_A) AS WORK_HH_A
								         , SUM(WORK_HH_B) AS WORK_HH_B
								         , SUM(WORK_MM_A) AS WORK_MM_A
								         , SUM(WORK_MM_B) AS WORK_MM_B
                                         , SUM( DECODE(PLAN_WORK_YN, 'N', 1, 0) ) AS WORK_CNT
                                         , SUM( 1 ) AS WORK_ALL_CNT
                                         , MAX(WEEK_CNT) AS WEEK_CNT
								      FROM TMP
								     GROUP BY RNUM
								     UNION ALL
								    SELECT '단위기간' AS GUBUN
								         , MIN(WEEK_START) AS SDATE
								         , MAX(WEEK_END) AS EDATE
								         , SUM(WORK_HH_A) AS WORK_HH_A
								         , SUM(WORK_HH_B) AS WORK_HH_B
								         , SUM(WORK_MM_A) AS WORK_MM_A
								         , SUM(WORK_MM_B) AS WORK_MM_B
                                         , SUM( DECODE(PLAN_WORK_YN, 'N', 1, 0) ) AS WORK_CNT
                                         , SUM( 1 ) AS WORK_ALL_CNT
                                         , MAX(WEEK_CNT) AS WEEK_CNT
								     FROM TMP
							        WHERE YMD BETWEEN REPLACE('20250713','-','') AND REPLACE('20250719','-','')
                                    UNION ALL 
								    SELECT '일 평균' AS GUBUN
								         , MIN(WEEK_START) AS SDATE
								         , MAX(WEEK_END) AS EDATE
								         , SUM(WORK_HH_A) AS WORK_HH_A
								         , SUM(WORK_HH_B) AS WORK_HH_B
								         , SUM(WORK_MM_A) AS WORK_MM_A
								         , SUM(WORK_MM_B) AS WORK_MM_B
                                         , SUM( DECODE(PLAN_WORK_YN, 'N', 1, 0) ) AS WORK_CNT
                                         , SUM( 1 ) AS WORK_ALL_CNT
                                         , MAX(WEEK_CNT) AS WEEK_CNT
								     FROM TMP
							        WHERE YMD BETWEEN REPLACE('20250713','-','') AND REPLACE('20250719','-','')

                                    UNION ALL 
								    SELECT '주 평균' AS GUBUN
								         , MIN(WEEK_START) AS SDATE
								         , MAX(WEEK_END) AS EDATE
								         , SUM(WORK_HH_A) AS WORK_HH_A
								         , SUM(WORK_HH_B) AS WORK_HH_B
								         , SUM(WORK_MM_A) AS WORK_MM_A
								         , SUM(WORK_MM_B) AS WORK_MM_B
                                         , SUM( DECODE(PLAN_WORK_YN, 'N', 1, 0) ) AS WORK_CNT
                                         , SUM( 1 ) AS WORK_ALL_CNT
                                         , MAX(WEEK_CNT) AS WEEK_CNT
								     FROM TMP
							        WHERE YMD BETWEEN REPLACE('20250713','-','') AND REPLACE('20250719','-','')
							  )	     
					  )
;



----------------------------------------------
SELECT ENTER_CD,COUNT(*) CNT fROM TMSYS_06
GROUP BY ENTER_CD;

SELECT * FROM TMSYS_06 WHERE SABUN='09700062';

--근태코드 : 근무/연차/반차...
--근무/연차/반차 : 시작시간~종료시간 (09:00~16:00, 08:30~17:30, ...)
    --연차일경우, 원래 근무시작시간~근무종료시간?


select a.table_name,a.comments,b.column_name,b.comments
from USER_TAB_COMMENTS a,USER_col_comments b
WHERE a.table_name=b.table_name
and a.table_name NOT like 'SYS%'
 and (a.comments like '%유연근무%' or b.comments like '%유연근무%');

SELECT * FROM TTIM131 WHERE ENTER_CD='HX' AND SABUN='09700062' ORDER BY APPL_sEQ DESC;
--HX	20250709000329	09700062	20250710	20250809	T010	25/07/09	09700062	99	
--FLEXIBLE_TYPE=T010, APPL_STATUS_CD='99'

SELECT * fROM TSYS005 WHERE GRCODE_CD='T20020' AND ENTER_CD='HX';

select * from TSYS920
where n_title like '%노무%';

SELECT F_TIM_GET_DAY_GNT_CD('HX','20240040','20250717') GNT_CD FROM DUAL;

--[1]근태코드
SELECT F_TIM_GET_DAY_GNT_CD('HX','09700062','20250717') GNT_CD FROM DUAL;
 
 --[2]in_hm, out_hm
select * From TTIM335;
select * from TTIM335 where enter_cd='HX' and sabun='09700062' and ymd= '20250621';
--[3] wrok_shm
select * From TTIM017 where enter_cd='HX'; 
select * from TTIM120_V where enter_cd='HX' and sabun='09700062' and ymd= '20250617';
select * from TTIM120;

SELECT * FROM TTIM301;--SABUN,S_YMD~E_YMD,GNT_CD
SELECT * FROM TTIM301 where enter_cd='HX' and sabun='09700062' and s_ymd>='20250601';--SABUN,S_YMD~E_YMD,GNT_CD



--[1]
       SELECT RANK() OVER (ORDER BY A.GNT_CD, A.YMD) AS NUM
            , A.GNT_CD
            , (SELECT GNT_NM FROM TTIM014 WHERE ENTER_CD = A.ENTER_CD AND GNT_CD = A.GNT_CD) AS GNT_NM
         FROM TTIM405 A , THRI103 B, TTIM301 C
        WHERE A.ENTER_CD = B.ENTER_CD
          AND A.APPL_SEQ = B.APPL_SEQ
          AND A.ENTER_CD = C.ENTER_CD
          AND A.APPL_SEQ = C.APPL_SEQ
          AND NVL(A.UPDATE_YN,'N') = 'N'
          AND B.APPL_STATUS_CD = '99'
          AND A.ENTER_CD = 'HX'
          AND A.SABUN    = '20240040'
          AND A.YMD      = '20250717'  ;
          
select A.* From TTIM335 A
WHERE 1=1
          AND A.ENTER_CD = 'HX'
          AND A.SABUN    = '20240040'
    AND A.YMD='20250717'
; --[2]in_hm, out_hm
select A.* From TTIM017 A 
WHERE 1=1
          AND A.ENTER_CD = 'HX'
          AND A.TIME_CD    = '10000'
    ; --[3] wrok_shm




          
SELECT * FROM TTIM405 
WHERE 1=1
AND ENTER_CD='HX' 
AND SABUN='20240040'
ORDER BY CHKDATE DESC
;--SABUN,YM,GNT_CD



SELECT * FROM TTIM301;--SABUN,S_YMD~E_YMD,GNT_CD

SELECT ENTER_CD,GNT_CD FROM TTIM014 WHERE GNT_NM LIKE '%반차';


          
          

SELECT
                    X.CODE
                    ,CASE WHEN LENGTH(X.CODE_NM) > 2 THEN SUBSTR(CODE_NM,0,2)||CHR(13)||CHR(10)||SUBSTR(CODE_NM,3) ELSE X.CODE_NM END AS CODE_NM
                    ,X.SAVE_NAME
                    ,X.SAVE_NAME_DISP
                    ,X.CD_TYPE
                    ,X.TYPE
                    ,X.FORMAT
                FROM(
                    SELECT A.WORK_CD AS CODE
                         , B.WORK_NM AS CODE_NM
                         , 'WORK_CD_' || ROW_NUMBER() over (ORDER BY A.SEQ) AS SAVE_NAME
                         , 'workCd' || ROW_NUMBER() over (ORDER BY A.SEQ) AS SAVE_NAME_DISP
                         , B.CD_TYPE
                         , F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10030', B.CD_TYPE, 1) AS TYPE
                         , F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10030', B.CD_TYPE, 2) AS FORMAT
                    FROM TTIM355 A, TTIM015 B
                    WHERE 1 = 1
                      AND A.ENTER_CD = B.ENTER_CD
                      AND A.WORK_CD = B.WORK_CD
                      AND B.ENTER_CD = 'HX'
                      AND A.WORK_GUBUN_CD = 'A'
                ) X;
                
				SELECT A.TIME_CD AS CODE
				     , A.SHORT_TERM AS CODE_NM
				  FROM TTIM017 A
				 WHERE 1 = 1
				   AND A.ENTER_CD = 'HX'
				 ORDER BY SEQ;
                 
SELECT
                    X.CODE
                    ,CASE WHEN LENGTH(X.CODE_NM) > 2 THEN SUBSTR(CODE_NM,0,2)||CHR(13)||CHR(10)||SUBSTR(CODE_NM,3) ELSE X.CODE_NM END AS CODE_NM
                    ,X.SAVE_NAME
                    ,X.SAVE_NAME_DISP
                    ,X.CD_TYPE
                    ,X.TYPE
                    ,X.FORMAT
                FROM(
                    SELECT A.WORK_CD AS CODE
                         , B.WORK_NM AS CODE_NM
                         , 'WORK_CD_' || ROW_NUMBER() over (ORDER BY A.SEQ) AS SAVE_NAME
                         , 'workCd' || ROW_NUMBER() over (ORDER BY A.SEQ) AS SAVE_NAME_DISP
                         , B.CD_TYPE
                         , F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10030', B.CD_TYPE, 1) AS TYPE
                         , F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'T10030', B.CD_TYPE, 2) AS FORMAT
                    FROM TTIM355 A, TTIM015 B
                    WHERE 1 = 1
                      AND A.ENTER_CD = B.ENTER_CD
                      AND A.WORK_CD = B.WORK_CD
                      AND B.ENTER_CD = 'HX'
                      AND A.WORK_GUBUN_CD = 'A'
                ) X;
                
SELECT A.*

                      , NVL((CASE WHEN HOLIDAY_NM IS NOT NULL THEN HOLIDAY_NM WHEN A.WORK_YN = 'Y' THEN '휴일' ELSE HOLIDAY_NM END), '평일') AS DAY_DIV

                      , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS DAY_NM_FONT_COLOR
                      , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS DAY_DIV_FONT_COLOR
                      , (CASE WHEN HOLIDAY_NM IS NOT NULL OR A.WORK_YN = 'Y' THEN '#ef519c' ELSE '' END) AS YMD_FONT_COLOR

                      , (CASE WHEN HOLIDAY_NM IS NULL AND A.WORK_YN = 'N' THEN 'N' ELSE 'Y' END) AS HOLIDAY_DIV

                      , (CASE WHEN TO_CHAR(SYSDATE,'YYYYMMDD') > A.YMD THEN (CASE WHEN A.WORK_YN = 'N' AND (A.IN_HM IS NULL OR A.OUT_HM IS NULL) 
                                                                                  THEN (CASE WHEN A.GNT_CD = '결근' THEN 'X'
                                                                                             WHEN A.GNT_CD IS NOT NULL THEN 'O' 
                                                                                             ELSE 'X' END
                                                                                        ) 
                                                                                   ELSE 'O' END
                                                                             )
                              ELSE NULL END) AS WORK_FLAG
                  FROM (
			                SELECT TO_CHAR(TO_DATE(A.YMD, 'YYYYMMDD'), 'YYYY-MM-DD') || ' (' || A.DAY_NM  || ')' AS V_YMD
			                     , A.YMD
			                     , C.TIME_CD
			                     , C.WORK_ORG_CD
			                     , C.WORK_YN
			                     , F_TIM_GET_DAY_GNT_NM(A.ENTER_CD, A.SABUN, A.YMD) AS GNT_CD
			                     , B.IN_HM
			                     , B.OUT_HM

								 , (CASE WHEN B.IN_HM IS NOT NULL AND B.OUT_HM IS NOT NULL THEN F_TIM_GET_WORK_TERM_TIME(A.ENTER_CD,A.SABUN,A.YMD,B.IN_HM,B.OUT_HM) ELSE NULL END) AS WORK_TIME
				                 , F_TIM_WORK_HM_TEXT(A.ENTER_CD, A.SABUN, A.YMD) AS REAL_WORK_TIME

			                     , D.WORKDAY_STD
			                     , NVL(C.SHM, CASE WHEN C.WORK_YN = 'N' THEN D.WORK_SHM ELSE '' END) AS WORK_SHM
			                     , NVL(C.EHM, CASE WHEN C.WORK_YN = 'N' THEN D.WORK_EHM ELSE '' END) AS WORK_EHM
			                     --, E.BUSINESS_PLACE_CD
			                     --, ( SELECT HOLIDAY_NM FROM TTIM001 WHERE ENTER_CD = A.ENTER_CD AND YY || MM || DD = A.YMD AND BUSINESS_PLACE_CD = E.BUSINESS_PLACE_CD) AS HOLIDAY_NM
			                     , F_COM_GET_BP_CD(C.ENTER_CD, C.SABUN, C.YMD) AS BUSINESS_PLACE_CD
			                     , ( SELECT HOLIDAY_NM FROM TTIM001 WHERE ENTER_CD = A.ENTER_CD AND YY || MM || DD = A.YMD AND BUSINESS_PLACE_CD = F_COM_GET_BP_CD(C.ENTER_CD, C.SABUN, C.YMD)) AS HOLIDAY_NM
			                     , A.DAY_NM AS TEMP_DAY_NM

			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0020') AS "WORK_CD_1"
			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0040') AS "WORK_CD_2"
			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0045') AS "WORK_CD_3"
			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0070') AS "WORK_CD_4"
			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0090') AS "WORK_CD_5"
			                     , (SELECT LPAD(NVL(X.WORK_HH,0),2,0)||':'||LPAD(NVL(X.WORK_MM,0),2,0) 
			                          FROM TTIM337 X 
			                         WHERE X.ENTER_CD = B.ENTER_CD 
			                           AND X.YMD      = B.YMD 
			                           AND X.SABUN    = B.SABUN 
			                           AND ( NVL(X.WORK_HH,0)> 0 OR NVL(X.WORK_MM,0)> 0 ) 
			                           AND X.WORK_CD  = '0110') AS "WORK_CD_6"
			                FROM (
			                		SELECT A1.ENTER_CD
			                             , A1.SABUN
			                             , A1.NAME
			                             , A2.SUN_DATE AS YMD
			                             , A2.DAY_NM
			                             , B.STATUS_CD
			                             , B.JIKGUB_NM
			                             , B.JIKWEE_NM
			                             , B.JIKCHAK_NM
			                             , B.MANAGE_NM
			                             , B.SDATE
			                             , B.ORG_CD
			                             , B.WORK_TYPE_NM
			                             , B.PAY_TYPE_NM
			                          FROM THRM100 A1, THRM151 B, TSYS007 A2
			                         WHERE A2.SUN_DATE BETWEEN REPLACE('20250615','-','') AND REPLACE('20250622','-','')
			                           AND A1.ENTER_CD = TRIM( 'HX' )
			                           AND A1.SABUN    = TRIM( '09700062' )
			                           AND A1.ENTER_CD = B.ENTER_CD
			                           AND A1.SABUN    = B.SABUN
			                           AND A2.SUN_DATE BETWEEN B.SDATE AND NVL(B.EDATE, '99991231')

			                     ) A
			                     , TTIM335 B, TTIM120_V C, TTIM017 D
			                     --, BP_V E
			                 WHERE A.ENTER_CD = B.ENTER_CD(+)
			                   AND A.SABUN    = B.SABUN(+)
			                   AND A.YMD      = B.YMD(+)
			                   AND A.ENTER_CD = C.ENTER_CD(+)
			                   AND A.YMD      = C.YMD(+)
			                   AND A.SABUN    = C.SABUN(+)
			                   AND C.ENTER_CD = D.ENTER_CD
			                   AND C.TIME_CD  = D.TIME_CD


			                  -- AND A.ENTER_CD = E.ENTER_CD (+)
			                  -- AND A.SABUN    = E.SABUN    (+)
			                  -- AND A.YMD BETWEEN E.SDATE(+) AND NVL(E.EDATE(+), '99991231')
                   ) A
				ORDER BY A.YMD;


WITH TMP AS (
							SELECT A.ENTER_CD, A.YMD, A.SABUN, A.WORK_GRP_CD, A.WORK_ORG_CD
							     , NVL(B.WORK_HH_A, 0) AS WORK_HH_A
							     , NVL(B.WORK_HH_B, 0) AS WORK_HH_B
							     , NVL(B.WORK_MM_A, 0) AS WORK_MM_A
							     , NVL(B.WORK_MM_B, 0) AS WORK_MM_B
							     , ROW_NUMBER() OVER(ORDER BY A.YMD) AS RN
                                 , D.WEEK_START
                                 , D.WEEK_END
                                 , D.WEEK_CNT
                                 , D.RNUM
                                 , A.PLAN_WORK_YN
							FROM TTIM120_V A
							   , ( SELECT X.ENTER_CD, X.YMD, X.SABUN
							           , NVL(SUM(DECODE( Y.DAY_TYPE, '101', X.WORK_HH, 0)),0) AS WORK_HH_A
							           , NVL(SUM(DECODE( Y.DAY_TYPE, '101', 0, X.WORK_HH)),0) AS WORK_HH_B
							           , NVL(SUM(DECODE( Y.DAY_TYPE, '101', X.WORK_MM, 0)),0) AS WORK_MM_A
							           , NVL(SUM(DECODE( Y.DAY_TYPE, '101', 0, X.WORK_MM)),0) AS WORK_MM_B
							         FROM TTIM337 X, TTIM015 Y
							        WHERE X.ENTER_CD = TRIM('HX')
							          AND X.SABUN    = TRIM( '20120026' )
							          AND X.YMD BETWEEN TO_CHAR(TO_DATE(REPLACE('20250713','-',''),'YYYYMMDD')-7,'YYYYMMDD') AND TO_CHAR(TO_DATE(REPLACE('20250719','-',''),'YYYYMMDD')+7,'YYYYMMDD')
							          AND X.ENTER_CD = Y.ENTER_CD
							          AND X.WORK_CD  = Y.WORK_CD
							          AND Y.DAY_TYPE IN ('101', '105' ) --  정규근무(101),야간근무(103),연장근무(105)--휴일근무(201),휴일야간근무(203),휴일연장근무(205)
							        GROUP BY X.ENTER_CD, X.YMD, X.SABUN
							     ) B      
                                , (
                                      SELECT TO_CHAR(WEEK_START, 'YYYYMMDD') WEEK_START
                                           , TO_CHAR(WEEK_END, 'YYYYMMDD') WEEK_END
                                           , ROW_NUMBER()OVER(ORDER BY WEEK_START) AS RNUM
                                           , SUM( CASE WHEN TO_CHAR(WEEK_START, 'YYYYMMDD') BETWEEN REPLACE('20250713','-','') AND REPLACE('20250719','-','')
                                                        AND TO_CHAR(WEEK_END, 'YYYYMMDD') BETWEEN REPLACE('20250713','-','') AND REPLACE('20250719','-','') THEN 1 ELSE 0 END) OVER() AS WEEK_CNT
                                        FROM (
                                               SELECT START_DT AS WEEK_START
                                                    , END_DT AS WEEK_END
                                                 FROM ( SELECT F_TIM_GET_WEEK_START('HX',REPLACE('20250713','-','')) AS START_DT
                                                             , TO_DATE(TRIM(REPLACE('20250719','-','')), 'YYYYMMDD') END_DT
                                                          FROM DUAL  
                                                       )
                                               CONNECT BY LEVEL < END_DT - START_DT
                                              )
                                       WHERE 1=1
                                       GROUP BY WEEK_START, WEEK_END

                                   ) D          
							WHERE A.ENTER_CD  = TRIM('HX')
							  AND A.SABUN 	  = TRIM( '20120026' )
							  AND A.YMD BETWEEN D.WEEK_START AND D.WEEK_END
							  --AND A.YMD BETWEEN REPLACE(:searchSymd,'-','') AND REPLACE(:searchEymd,'-','')
							  AND A.ENTER_CD    = B.ENTER_CD(+)
							  AND A.SABUN       = B.SABUN(+) 
							  AND A.YMD         = B.YMD(+)

				)
				SELECT GUBUN, SDATE, EDATE
                     , F_TIM_FMT_TIME(TRUNC(WORK_HOUR), TRUNC(( WORK_HOUR - TRUNC(WORK_HOUR)) * 60)) AS  WORK_HOUR
                     , F_TIM_FMT_TIME(TRUNC(OT_HOUR), TRUNC(( OT_HOUR - TRUNC(OT_HOUR)) * 60)) AS  OT_HOUR
   					 , '#fdf0f5' AS WORK_HOUR_BACK_COLOR
   					 , '#fdf0f5' AS OT_HOUR_BACK_COLOR
				FROM (						
						SELECT GUBUN, SDATE, EDATE
						     , CASE WHEN INSTR(GUBUN, '일 평균') > 0 THEN NVL( (WORK_HH_A + (WORK_MM_A/60)) / DECODE(WORK_CNT, 0, NULL, WORK_CNT), 0 )
                                    WHEN INSTR(GUBUN, '주 평균') > 0 THEN NVL( (WORK_HH_A + (WORK_MM_A/60)) / DECODE(WEEK_CNT, 0, NULL, WEEK_CNT), 0 )
                                    ELSE (WORK_HH_A + (WORK_MM_A/60)) END AS WORK_HOUR

						     , CASE WHEN INSTR(GUBUN, '일 평균') > 0  THEN NVL( (WORK_HH_B + (WORK_MM_B/60)) / DECODE(WORK_ALL_CNT, 0, NULL, WORK_ALL_CNT), 0 )
                                    WHEN INSTR(GUBUN, '주 평균') > 0  THEN NVL( (WORK_HH_B + (WORK_MM_B/60)) / DECODE(WEEK_CNT, 0, NULL, WEEK_CNT), 0 )
                                    ELSE (WORK_HH_B + (WORK_MM_B/60)) END AS OT_HOUR

						  FROM (
								    SELECT ROW_NUMBER() OVER(ORDER BY MIN(YMD)) || '주차' AS GUBUN
								         , MIN(WEEK_START) AS SDATE
								         , MAX(WEEK_END) AS EDATE
								         , SUM(WORK_HH_A) AS WORK_HH_A
								         , SUM(WORK_HH_B) AS WORK_HH_B
								         , SUM(WORK_MM_A) AS WORK_MM_A
								         , SUM(WORK_MM_B) AS WORK_MM_B
                                         , SUM( DECODE(PLAN_WORK_YN, 'N', 1, 0) ) AS WORK_CNT
                                         , SUM( 1 ) AS WORK_ALL_CNT
                                         , MAX(WEEK_CNT) AS WEEK_CNT
								      FROM TMP
								     GROUP BY RNUM
								     UNION ALL
								    SELECT '단위기간' AS GUBUN
								         , MIN(WEEK_START) AS SDATE
								         , MAX(WEEK_END) AS EDATE
								         , SUM(WORK_HH_A) AS WORK_HH_A
								         , SUM(WORK_HH_B) AS WORK_HH_B
								         , SUM(WORK_MM_A) AS WORK_MM_A
								         , SUM(WORK_MM_B) AS WORK_MM_B
                                         , SUM( DECODE(PLAN_WORK_YN, 'N', 1, 0) ) AS WORK_CNT
                                         , SUM( 1 ) AS WORK_ALL_CNT
                                         , MAX(WEEK_CNT) AS WEEK_CNT
								     FROM TMP
							        WHERE YMD BETWEEN REPLACE('20250713','-','') AND REPLACE('20250719','-','')
                                    UNION ALL 
								    SELECT '일 평균' AS GUBUN
								         , MIN(WEEK_START) AS SDATE
								         , MAX(WEEK_END) AS EDATE
								         , SUM(WORK_HH_A) AS WORK_HH_A
								         , SUM(WORK_HH_B) AS WORK_HH_B
								         , SUM(WORK_MM_A) AS WORK_MM_A
								         , SUM(WORK_MM_B) AS WORK_MM_B
                                         , SUM( DECODE(PLAN_WORK_YN, 'N', 1, 0) ) AS WORK_CNT
                                         , SUM( 1 ) AS WORK_ALL_CNT
                                         , MAX(WEEK_CNT) AS WEEK_CNT
								     FROM TMP
							        WHERE YMD BETWEEN REPLACE('20250713','-','') AND REPLACE('20250719','-','')

                                    UNION ALL 
								    SELECT '주 평균' AS GUBUN
								         , MIN(WEEK_START) AS SDATE
								         , MAX(WEEK_END) AS EDATE
								         , SUM(WORK_HH_A) AS WORK_HH_A
								         , SUM(WORK_HH_B) AS WORK_HH_B
								         , SUM(WORK_MM_A) AS WORK_MM_A
								         , SUM(WORK_MM_B) AS WORK_MM_B
                                         , SUM( DECODE(PLAN_WORK_YN, 'N', 1, 0) ) AS WORK_CNT
                                         , SUM( 1 ) AS WORK_ALL_CNT
                                         , MAX(WEEK_CNT) AS WEEK_CNT
								     FROM TMP
							        WHERE YMD BETWEEN REPLACE('20250713','-','') AND REPLACE('20250719','-','')
							  )	     
					  )
;