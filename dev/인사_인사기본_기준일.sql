
  CREATE OR REPLACE FORCE EDITIONABLE VIEW "PAWS_HG_PRD"."인사_인사기본_기준일" ("회사구분", "회사명", "사번", "성명", "주민번호", "성별", "한자성명", "영문성명", "영문약자", "그룹입사일", "소속입사일", "근속기간", "근속기간경력포함", "인정경력년", "인정경력개월", "퇴사일", "면수습일", "급여사업장코드", "급여사업장명", "LOCATION코드", "LOCATION명", "코스트센터코드", "코스트센터명", "본부명", "부서코드", "부서명", "부서발령일", "재직상태코드", "재직상태명", "사원구분코드", "사원구분명", "직급코드", "직급명", "직위코드", "직위명", "직책코드", "직책명", "직군코드", "직군명", "직종코드", "직종명", "직무코드", "직무명", "채용구분코드", "채용구분명", "급여유형코드", "급여유형코드명", "계약시작일", "계약종료일", "외국인여부", "국적코드", "국적명", "양음력구분", "생년월일", "나이", "결혼여부", "결혼일자", "혈액형", "종교코드", "종교코드명", "취미", "퇴직연금유형코드", "퇴직연금유형", "사내전화번호", "집전화번호", "핸드폰번호", "메일주소", "최종학력", "학교명1", "전공1", "졸업구분1", "입학월1", "졸업월1", "학교명2", "전공2", "졸업구분2", "입학월2", "졸업월2", "병역전역구분코드", "병역전역구분", "군별코드", "군별", "계급코드", "계급", "병과코드", "병과", "군번", "입대일", "제대일", "면제사유", "주소", "회계구분코드", "회계구분", "직무", "최종직장명", "입사구분", "현직급승진일", "현직위승진일", "현직책승진일", "부서근속기간", "그룹근속기간", "ENTER_CD", "SABUN", "STATUS_CD", "SAJIN2", "최종퇴직금기산일", "호봉") AS 
  SELECT K.ENTER_CD
                 AS "회사구분",
             F_COM_GET_ENTER_NM (K.ENTER_CD,
                                 DECODE ('@ssnLocaleCd@', 'en_US', '2', '1'))
                 AS "회사명",
             K.SABUN
                 "사번",
             F_COM_GET_NAMES (K.ENTER_CD, K.SABUN)
                 AS "성명",
             CRYPTIT.DECRYPT (K.RES_NO, K.ENTER_CD)
                 AS "주민번호",
             F_COM_GET_GRCODE_NAME (C.ENTER_CD,
                                    'H00010',
                                    K.SEX_TYPE,
                                    '@ssnLocaleCd@')
                 AS "성별",
             F_COM_GET_NAMES (K.ENTER_CD, K.SABUN, 'zh_CN')
                 AS "한자성명",
             F_COM_GET_NAMES (K.ENTER_CD, K.SABUN, 'en_US')
                 AS "영문성명",
             F_COM_GET_NAMES (K.ENTER_CD, K.SABUN, 'ALIAS')
                 AS "영문약자",
             --TO_CHAR (TO_DATE (K.GEMP_YMD, 'YYYYMMDD'), 'YYYY-MM-DD')
             --   AS "최초입사일",
             TO_CHAR (TO_DATE (K.GEMP_YMD, 'YYYYMMDD'), 'YYYY-MM-DD')
                 AS "그룹입사일",
             --TO_CHAR (TO_DATE (K.EMP_YMD, 'YYYYMMDD'), 'YYYY-MM-DD')
             --    AS "소속입사일",
             CASE
             WHEN K.ENTER_CD='KS'
             THEN (
                SELECT  TO_CHAR(TO_DATE(NVL(ZZ.YEAR_YMD, ZZ.GEMP_YMD),'YYYYMMDD'), 'YYYY-MM-DD') FROM THRM100 ZZ WHERE ZZ.ENTER_CD='KS' AND ZZ.SABUN=K.SABUN
                )                
             ELSE
                TO_CHAR (TO_DATE (K.EMP_YMD, 'YYYYMMDD'), 'YYYY-MM-DD')
             END AS "소속입사일",
             F_COM_GET_CAREER_CNT (K.ENTER_CD,
                                   K.SABUN,
                                   'W',
                                   'YYMM',
                                   '1',
                                   NULL,
                                   '@ssnLocaleCd@')
                 AS "근속기간",
             F_COM_GET_CAREER_CNT (K.ENTER_CD,
                                   K.SABUN,
                                   'Y',
                                   'YYMM',
                                   '1',
                                   NULL,
                                   '@ssnLocaleCd@')
                 AS "근속기간경력포함",
             K.CAREER_YY_CNT
                 AS "인정경력년",
             K.CAREER_MM_CNT
                 AS "인정경력개월",
             TO_CHAR (TO_DATE (K.RET_YMD, 'YYYYMMDD'), 'YYYY-MM-DD')
                 AS "퇴사일",
             --TO_CHAR (TO_DATE (K.TRA_YMD, 'YYYYMMDD'), 'YYYY-MM-DD')
             --   AS "면수습일",
             K.TRA_YMD
                 AS "면수습일",
             F_COM_GET_MAP_CD (
                 K.ENTER_CD,
                 '100',
                 K.SABUN,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')),
                 '@ssnLocaleCd@')
                 AS "급여사업장코드",
             F_COM_GET_MAP_NM (
                 K.ENTER_CD,
                 '100',
                 K.SABUN,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')),
                 '@ssnLocaleCd@')
                 AS "급여사업장명",
             --C.LOCATION_CD AS "LOCATION코드",

             F_COM_GET_MAP_CD (
                 K.ENTER_CD,
                 '600',
                 K.SABUN,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')),
                 '@ssnLocaleCd@')
                 AS "LOCATION코드",
             --F_COM_GET_LOCATION_NM (K.ENTER_CD, C.LOCATION_CD, '@ssnLocaleCd@') AS LOCATION명,
             F_COM_GET_MAP_NM (
                 K.ENTER_CD,
                 '600',
                 K.SABUN,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')),
                 '@ssnLocaleCd@')
                 AS "LOCATION명",
             (SELECT F_COM_GET_COST_CC_CD(K.ENTER_CD,K.SABUN,NVL (REPLACE ('@viewSearchDate@', '-', ''),TO_CHAR (SYSDATE, 'YYYYMMDD'))) FROM DUAL) AS "코스트센터코드",
             (SELECT F_COM_GET_MAP_NM2(K.ENTER_CD, '300',
                      F_COM_GET_COST_CC_CD(K.ENTER_CD,K.SABUN,NVL (REPLACE ('@viewSearchDate@', '-', ''),TO_CHAR (SYSDATE, 'YYYYMMDD'))), NVL(REPLACE ('@viewSearchDate@', '-', ''),TO_CHAR (SYSDATE, 'YYYYMMDD')), 'NM','@ssnLocaleCd@') FROM DUAL) AS "코스트센터명",
             /*F_COM_GET_MAP_NM (
                 K.ENTER_CD,
                 '300',
                 K.SABUN,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')),
                 '@ssnLocaleCd@')
                 AS "코스트센터명",*/
             NVL (
                 F_COM_GET_HQ_ORG_NM (
                     K.ENTER_CD,
                     C.ORG_CD,
                     NVL (REPLACE ('@viewSearchDate@', '-', ''),
                          TO_CHAR (SYSDATE, 'YYYYMMDD')),
                     'B0400'),
                 F_COM_GET_HQ_ORG_NM (
                     K.ENTER_CD,
                     C.ORG_CD,
                     NVL (REPLACE ('@viewSearchDate@', '-', ''),
                          TO_CHAR (SYSDATE, 'YYYYMMDD')),
                     'B0300'))
                 AS "본부명",
             C.ORG_CD
                 AS "부서코드",
             F_COM_GET_ORG_NM (
                 C.ENTER_CD,
                 C.ORG_CD,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')),
                 '@ssnLocaleCd@')
                 AS "부서명",
             TO_CHAR (
                 TO_DATE (
                     F_COM_GET_CURR_ORG_YMD (
                         K.ENTER_CD,
                         K.SABUN,
                         NVL (REPLACE ('@viewSearchDate@', '-', ''),
                              TO_CHAR (SYSDATE, 'YYYYMMDD'))),
                     'YYYYMMDD'),
                 'YYYY-MM-DD')
                 AS "부서발령일",
             F_COM_GET_STATUS_CD(K.ENTER_CD,K.SABUN,NVL(REPLACE('@viewSearchDate@', '-', ''),TO_CHAR(SYSDATE, 'YYYYMMDD')))
                 AS "재직상태코드",
             F_COM_GET_STATUS_NM(K.ENTER_CD,K.SABUN,NVL(REPLACE('@viewSearchDate@', '-', ''),TO_CHAR(SYSDATE, 'YYYYMMDD')))
                 AS "재직상태명",
             C.MANAGE_CD
                 AS "사원구분코드",
             F_COM_GET_GRCODE_NAME (C.ENTER_CD,
                                    'H10030',
                                    C.MANAGE_CD,
                                    '@ssnLocaleCd@')
                 AS "사원구분명",
             C.JIKGUB_CD
                 AS "직급코드",
             F_COM_GET_GRCODE_NAME (C.ENTER_CD,
                                    'H20010',
                                    C.JIKGUB_CD,
                                    '@ssnLocaleCd@')
                 AS "직급명",
             C.JIKWEE_CD
                 AS "직위코드",
             F_COM_GET_GRCODE_NAME (C.ENTER_CD,
                                    'H20030',
                                    C.JIKWEE_CD,
                                    '@ssnLocaleCd@')
                 AS "직위명",
             C.JIKCHAK_CD
                 AS "직책코드",
             F_COM_GET_GRCODE_NAME (C.ENTER_CD,
                                    'H20020',
                                    C.JIKCHAK_CD,
                                    '@ssnLocaleCd@')
                 AS "직책명",
             C.BASE1_CD
                 AS "직군코드",
             F_COM_GET_GRCODE_NAME (C.ENTER_CD,
                                    'H10020',
                                    C.BASE1_CD,
                                    '@ssnLocaleCd@')
                 AS "직군명",
             C.WORK_TYPE
                 AS "직종코드",
             F_COM_GET_GRCODE_NAME (C.ENTER_CD,
                                    'H10050',
                                    C.WORK_TYPE,
                                    '@ssnLocaleCd@')
                 AS "직종명",
             C.JOB_CD
                 AS "직무코드",
             F_COM_GET_GRCODE_NAME (C.ENTER_CD,
                                    'H10060',
                                    C.JOB_CD,
                                    '@ssnLocaleCd@')
                 AS "직무명",

             K.STF_TYPE
                 AS "채용구분코드",
             F_COM_GET_GRCODE_NAME (K.ENTER_CD,
                                    'F10001',
                                    K.STF_TYPE,
                                    '@ssnLocaleCd@')
                 AS "채용구분명",
             C.PAY_TYPE
                 AS "급여유형코드",
             F_COM_GET_GRCODE_NAME (C.ENTER_CD,
                                    'H10110',
                                    C.PAY_TYPE,
                                    '@ssnLocaleCd@')
                 AS "급여유형코드명",
             TO_CHAR (TO_DATE (C.CONTRACT_SYMD, 'YYYYMMDD'), 'YYYY-MM-DD')
                 AS "계약시작일",
             TO_CHAR (TO_DATE (C.CONTRACT_EYMD, 'YYYYMMDD'), 'YYYY-MM-DD')
                 AS "계약종료일",
             K.FOREIGN_YN
                 AS "외국인여부",
             K.NATIONAL_CD
                 AS "국적코드",
             F_COM_GET_GRCODE_NAME (K.ENTER_CD,
                                    'H20290',
                                    K.NATIONAL_CD,
                                    '@ssnLocaleCd@')
                 AS "국적명",
             DECODE (K.LUN_TYPE,  '1', '양',  '2', '음',  NULL)
                 AS "양음력구분",
             TO_CHAR (TO_DATE (K.BIR_YMD, 'YYYYMMDD'), 'YYYY-MM-DD')
                 AS "생년월일",
             F_COM_GET_AGE (
                 K.ENTER_CD,
                 K.BIR_YMD,
                 K.RES_NO,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')))
                 AS "나이",
             K.WED_YN
                 AS "결혼여부",
             K.WED_YMD
                 AS "결혼일자",
             K.BLOOD_CD
                 AS "혈액형",
             K.REL_CD
                 AS "종교코드",
             NVL (K.REL_NM,
                  F_COM_GET_GRCODE_NAME (K.ENTER_CD,
                                         'H20350',
                                         K.REL_CD,
                                         '@ssnLocaleCd@'))
                 AS "종교코드명",
             K.HOBBY
                 AS "취미",
             TCPN710.RET_PENTION_TYPE
                 AS "퇴직연금유형코드",
             F_COM_GET_GRCODE_NAME (K.ENTER_CD,
                                    'H10170',
                                    TCPN710.RET_PENTION_TYPE,
                                    '@ssnLocaleCd@')
                 AS "퇴직연금유형",
             F_COM_GET_CONT_ADDRESS (K.ENTER_CD, K.SABUN, 'OT')
                 AS "사내전화번호",
             F_COM_GET_CONT_ADDRESS (K.ENTER_CD, K.SABUN, 'HT')
                 AS "집전화번호",
             F_COM_GET_CONT_ADDRESS (K.ENTER_CD, K.SABUN, 'HP')
                 AS "핸드폰번호",
             F_COM_GET_CONT_ADDRESS (K.ENTER_CD, K.SABUN, 'IM')
                 AS "메일주소",
             X.ACA_NM
                 AS "최종학력",
             X.ACA_SCH_NM
                 AS "학교명1",
             X.ACAMAJ_NM
                 AS "전공1",
             X.ACA_YN_NM
                 AS "졸업구분1",
             X.ACA_S_YM
                 AS "입학월1",
             X.ACA_E_YM
                 AS "졸업월1",
             H.ACA_SCH_NM
                 AS "학교명2",
             H.ACAMAJ_NM
                 AS "전공2",
             H.ACA_YN_NM
                 AS "졸업구분2",
             H.ACA_S_YM
                 AS "입학월2",
             H.ACA_E_YM
                 AS "졸업월2",
             THRM121.TRANSFER_CD
                 AS "병역전역구분코드",
             F_COM_GET_GRCODE_NAME (THRM121.ENTER_CD,
                                    'H20200',
                                    THRM121.TRANSFER_CD,
                                    '@ssnLocaleCd@')
                 AS "병역전역구분",
             THRM121.ARMY_CD
                 AS "군별코드",
             F_COM_GET_GRCODE_NAME (THRM121.ENTER_CD,
                                    'H20230',
                                    THRM121.ARMY_CD,
                                    '@ssnLocaleCd@')
                 AS "군별",
             THRM121.ARMY_GRADE_CD
                 AS "계급코드",
             F_COM_GET_GRCODE_NAME (THRM121.ENTER_CD,
                                    'H20220',
                                    THRM121.ARMY_GRADE_CD,
                                    '@ssnLocaleCd@')
                 AS "계급",
             THRM121.ARMY_D_CD
                 AS "병과코드",
             F_COM_GET_GRCODE_NAME (THRM121.ENTER_CD,
                                    'H20210',
                                    THRM121.ARMY_D_CD,
                                    '@ssnLocaleCd@')
                 AS "병과",
             THRM121.ARMY_NO
                 AS "군번",
             THRM121.ARMY_S_YMD
                 AS "입대일",
             THRM121.ARMY_E_YMD
                 AS "제대일",
             THRM121.ARMY_MEMO
                 AS "면제사유",
             THRM123.ADDR1 || ' ' || THRM123.ADDR2
                 AS "주소",
             F_COM_GET_MAP_CD (
                 K.ENTER_CD,
                 '700',
                 K.SABUN,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')))
                 AS "회계구분코드",
             F_COM_GET_MAP_NM (
                 K.ENTER_CD,
                 '700',
                 K.SABUN,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')),
                 '@ssnLocaleCd@')
                 AS "회계구분",
             F_COM_GET_JOB_NM_141 (
                 K.ENTER_CD,
                 K.SABUN,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')),
                 '@ssnLocaleCd@')
                 AS "직무",
             THRM117.CMP_NM
                 AS "최종직장명",
             K.EMP_TYPE_NM
                 AS "입사구분",
             TO_CHAR (
                 TO_DATE (
                     F_COM_GET_CURR_JIKGUB_YMD (K.ENTER_CD,
                                                K.SABUN,
                                                TO_CHAR (SYSDATE, 'YYYYMMDD')),
                     'YYYYMMDD'),
                 'YYYY-MM-DD')
                 AS "현직급승진일",
                F_COM_GET_GRCODE_NAME (C.ENTER_CD, 'H20030', C.JIKWEE_CD)
             || '/'
             || TO_CHAR (
                    TO_DATE (
                        F_COM_GET_CURR_JIKWEE_YMD (
                            K.ENTER_CD,
                            K.SABUN,
                            TO_CHAR (SYSDATE, 'YYYYMMDD')),
                        'YYYYMMDD'),
                    'YYYY-MM-DD')
                 AS "현직위승진일",
             TO_CHAR (
                 TO_DATE (
                     F_COM_GET_CURR_JIKCHAK_YMD (K.ENTER_CD,
                                                 K.SABUN,
                                                 TO_CHAR (SYSDATE, 'YYYYMMDD')),
                     'YYYYMMDD'),
                 'YYYY-MM-DD')
                 AS "현직책승진일",
             F_COM_GET_WORKTERM_YMD (
                 K.ENTER_CD,
                 F_COM_GET_CURR_ORG_YMD (
                     K.ENTER_CD,
                     K.SABUN,
                     NVL (REPLACE ('@viewSearchDate@', '-', ''),
                          TO_CHAR (SYSDATE, 'YYYYMMDD'))),
                 TO_CHAR (SYSDATE, 'YYYYMMDD'),
                 'YYMM',
                 '1',
                 '@ssnLocaleCd@')
                 AS "부서근속기간",
             F_COM_GET_CAREER_CNT (K.ENTER_CD,
                                   K.SABUN,
                                   'G',
                                   'YYMM',
                                   '1',
                                   NULL,
                                   '@ssnLocaleCd@')
                 AS "그룹근속기간",
             K.ENTER_CD,
             K.SABUN,
             C.STATUS_CD,
             THRM911.SAJIN2 AS SAJIN2,
             (SELECT F_CPN_GET_SEP_SYMD(K.ENTER_CD,K.SABUN,TO_CHAR (SYSDATE, 'YYYYMMDD')) FROM DUAL) AS "최종퇴직금기산일",
             C.SAL_CLASS_NM AS "호봉"
        FROM THRM100 K
             INNER JOIN
             (SELECT X.*
                FROM THRM151 X,
                     (  SELECT Z.ENTER_CD, Z.SABUN, MAX (Z.SDATE) AS SDATE
                          FROM THRM151 Z
                         -- 선발령 시 현시점 조회, 채용 선발령인 경우 채용시점 데이터 조회, 2021.09.30
                         WHERE     (CASE
                                        WHEN (SELECT A.EMP_YMD
                                                FROM THRM100 A
                                               WHERE     A.ENTER_CD = Z.ENTER_CD
                                                     AND A.SABUN = Z.SABUN) >
                                             TO_CHAR (SYSDATE, 'YYYYMMDD')
                                        THEN
                                            (SELECT A.EMP_YMD
                                               FROM THRM100 A
                                              WHERE     A.ENTER_CD = Z.ENTER_CD
                                                    AND A.SABUN = Z.SABUN)
                                        ELSE
                                           -- TO_CHAR (SYSDATE, 'YYYYMMDD')
                                        NVL(REPLACE ('@viewSearchDate@', '-', ''), TO_CHAR (SYSDATE, 'YYYYMMDD')) -- 기준일자에 해당되는 발령으로 조회 2025.04.28
                                    END) BETWEEN Z.SDATE
                                             AND NVL (Z.EDATE, '99991231')
                               /*
                                                       WHERE     NVL (REPLACE ('@viewSearchDate@', '-', ''),
                                                                      TO_CHAR (SYSDATE, 'YYYYMMDD')) BETWEEN SDATE
                                                                                                         AND NVL (
                                                                                                                EDATE,
                                                                                                                '99999999')
                               */
                               AND (Z.ENTER_CD, Z.STATUS_CD) NOT IN
                                       (    SELECT DISTINCT ENTER_CD,
                                                            REGEXP_SUBSTR (A.PARAM,
                                                                           '[^,]+',
                                                                           1,
                                                                           LEVEL)
                                              FROM (SELECT ENTER_CD,
                                                           NVL (
                                                               F_COM_GET_STD_CD_VALUE (
                                                                   ENTER_CD,
                                                                   'HRM_STATUS_CD_NO'),
                                                               'RAA')    AS PARAM
                                                      FROM TORG900) A
                                        CONNECT BY LEVEL <=
                                                     LENGTH (
                                                         REGEXP_REPLACE (A.PARAM,
                                                                         '[^,]+',
                                                                         ''))
                                                   + 1)
                      GROUP BY Z.ENTER_CD, Z.SABUN) Y
               WHERE     X.ENTER_CD = Y.ENTER_CD
                     AND X.SABUN = Y.SABUN
                     AND X.SDATE = Y.SDATE) C
                 ON C.ENTER_CD = K.ENTER_CD AND C.SABUN = K.SABUN
             LEFT OUTER JOIN THRM163
                 ON THRM163.ENTER_CD = K.ENTER_CD AND THRM163.SABUN = K.SABUN
             LEFT OUTER JOIN THRM121
                 ON THRM121.ENTER_CD = K.ENTER_CD AND THRM121.SABUN = K.SABUN
             LEFT OUTER JOIN THRM911
                 ON THRM911.ENTER_CD = K.ENTER_CD AND THRM911.SABUN = K.SABUN AND THRM911.IMAGE_TYPE = '1'
             LEFT OUTER JOIN THRM123
                 ON     THRM123.ENTER_CD = K.ENTER_CD
                    AND THRM123.SABUN = K.SABUN
                    AND THRM123.ADD_TYPE = '2'
             LEFT OUTER JOIN
             (SELECT X.ENTER_CD, X.SABUN, X.RET_PENTION_TYPE
                FROM TCPN710 X
               WHERE X.SDATE =
                     (SELECT MAX (Y.SDATE)
                        FROM TCPN710 Y
                       WHERE     Y.ENTER_CD = X.ENTER_CD
                             AND Y.SABUN = X.SABUN
                             AND NVL (REPLACE ('@viewSearchDate@', '-', ''),
                                      TO_CHAR (SYSDATE, 'YYYYMMDD')) BETWEEN Y.SDATE
                                                                         AND NVL (
                                                                                 Y.EDATE,
                                                                                 '99999999')))
             TCPN710
                 ON TCPN710.ENTER_CD = K.ENTER_CD AND TCPN710.SABUN = K.SABUN
             LEFT OUTER JOIN
             (SELECT ENTER_CD,
                     SABUN,
                     ACA_CD,
                     F_COM_GET_GRCODE_NAME (ENTER_CD,
                                            'H20130',
                                            ACA_CD)             ACA_NM,
                     ACA_S_YM,
                     ACA_SCH_NM,
                     ACA_E_YM,
                     ACAMAJ_NM,
                     F_COM_GET_GRCODE_NAME (ENTER_CD,
                                            'H20140',
                                            ACA_YN,
                                            '@ssnLocaleCd@')    ACA_YN_NM
                FROM THRM115 A
               WHERE A.SEQ =
                     (SELECT C.SEQ
                        FROM (SELECT B.ENTER_CD,
                                     B.SABUN,
                                     B.SEQ,
                                     ROW_NUMBER ()
                                         OVER (
                                             PARTITION BY B.ENTER_CD, B.SABUN
                                             ORDER BY B.ACA_E_YM DESC, SEQ DESC)    RN
                                FROM THRM115 B
                               WHERE B.ACA_CD IN ('3',
                                                  '4',
                                                  '5',
                                                  '6')) C
                       WHERE     C.RN = 1
                             AND C.ENTER_CD = A.ENTER_CD
                             AND C.SABUN = A.SABUN)) X                 -- 최종학력
                 ON X.ENTER_CD = K.ENTER_CD AND X.SABUN = K.SABUN
             LEFT OUTER JOIN
             (SELECT ENTER_CD,
                     SABUN,
                     ACA_S_YM,
                     ACA_SCH_NM,
                     ACA_E_YM,
                     ACAMAJ_NM,
                     F_COM_GET_GRCODE_NAME (ENTER_CD,
                                            'H20140',
                                            ACA_YN,
                                            '@ssnLocaleCd@')    ACA_YN_NM
                FROM THRM115 A
               WHERE A.SEQ =
                     (SELECT C.SEQ
                        FROM (SELECT B.ENTER_CD,
                                     B.SABUN,
                                     B.SEQ,
                                     ROW_NUMBER ()
                                         OVER (
                                             PARTITION BY B.ENTER_CD, B.SABUN
                                             ORDER BY B.ACA_E_YM DESC, SEQ DESC)    RN
                                FROM THRM115 B
                               WHERE B.ACA_CD IN ('3',
                                                  '4',
                                                  '5',
                                                  '6')) C
                       WHERE     C.RN = 2
                             AND C.ENTER_CD = A.ENTER_CD
                             AND C.SABUN = A.SABUN)) H               -- 2순위 학교
                 ON H.ENTER_CD = K.ENTER_CD AND H.SABUN = K.SABUN
             LEFT OUTER JOIN
             (SELECT X.ENTER_CD, X.SABUN, X.CMP_NM
                FROM THRM117 X
               WHERE X.SEQ =
                     (SELECT MAX (Y.SEQ)
                        FROM THRM117 Y
                       WHERE Y.ENTER_CD = X.ENTER_CD AND Y.SABUN = X.SABUN))
             THRM117
                 ON THRM117.ENTER_CD = K.ENTER_CD AND THRM117.SABUN = K.SABUN
    ORDER BY F_COM_JIKJE_SORT (
                 K.ENTER_CD,
                 K.SABUN,
                 NVL (REPLACE ('@viewSearchDate@', '-', ''),
                      TO_CHAR (SYSDATE, 'YYYYMMDD')));

