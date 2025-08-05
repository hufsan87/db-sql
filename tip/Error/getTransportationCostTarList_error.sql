SELECT e.*
FROM TTIM110 E
WHERE E.ENTER_CD = 'KS'
AND E.ORG_CD = 'KS_ICNOMEA'
AND E.WORK_ORG_CD = '257'
AND '20250802' BETWEEN E.SDATE AND NVL(E.EDATE, '99991231')
ORDER BY
    -- SDATE와 기준일자('20250802')의 날짜 차이 절댓값을 기준으로 오름차순 정렬
    ABS(TO_DATE(E.SDATE, 'YYYYMMDD') - TO_DATE('20250802', 'YYYYMMDD')) ASC
FETCH FIRST 1 ROW ONLY
;

SELECT 
          *
          FROM 
                    (SELECT
                        A.WORK_YM
                        , A.SABUN AS SABUN_ORD_HD
                        , F_COM_GET_NAMES(A.ENTER_CD, A.SABUN, '') AS NAME -- 성명
                        , F_COM_GET_ORG_NM(C.ENTER_CD, C.ORG_CD, NVL(B.WORK_YMD,REPLACE( '2025-07' ,'-' ,'') || '01')) AS ORG_NM -- 부서명
                        , F_COM_GET_JIKGUB_NM (A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD'), '') AS JIKGUB_NM  -- 직급
                        , A.SABUN
                        , F_COM_GET_STATUS_NM(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) AS STATUS_NM
                        , F_TIM_GET_DAY_GNT_NM(A.ENTER_CD, A.SABUN, B.WORK_YMD) AS GNT_CD -- 근태
                        , A.PAY_AMT                -- 지급금액
                        , A.APP_AMT AS BEN812_APP_AMT
                        , B.DEPT_CHK_YN     -- 부서확인
                        , A.PAY_YM                -- 급여년월
                        , B.WORK_YMD            -- 근무일자
                        , B.WORK_AREA            -- 근무지
                        , B.WORK_ORG_CD
                        , (SELECT E.WORK_ORG_NM
                             FROM TTIM110 E
                            WHERE E.ENTER_CD = C.ENTER_CD
                              AND E.ORG_CD = C.ORG_CD
                              AND E.WORK_ORG_CD = C.WORK_ORG_CD
                              AND C.SDATE BETWEEN E.SDATE AND NVL(E.EDATE, '99991231')
                           ) AS WORK_ORG_NM
                        , B.SCH_S_TM            -- 근무스케줄-출근시간
                        , B.SCH_E_TM            -- 근무스케줄-퇴근시간
                        , B.TIME_CARD_S_TM-- 타각시간-출근
                        , B.TIME_CARD_E_TM-- 타각시간-퇴근
                        , B.NIT_EXT_TM        -- 연장퇴근시간
                        , B.POST_NO                -- 우편번호
                        , B.ADDR_NM                -- 주소
                        , B.BAS_AMT                -- 교통비기준금액
                        , B.APP_AMT                -- 대상금액
                        , B.MOR_AMT                -- 출근교통비
                        , B.NIT_AMT                -- 퇴근(연장)교통비
                        , B.EXT_AMT                -- 할증액
                        , B.ETC_AMT1            -- 유류비
                        , B.ETC_AMT2            -- 톨비
                        , B.ETC_AMT3            -- 기타금액
                        , B.NOTE                    -- 비고
                        , D.IN_HM
                        , D.OUT_HM
                    FROM TBEN812 A, TBEN813 B, TTIM111_V C, TTIM335 D
                    WHERE 1=1
                      -- A
                        AND A.ENTER_CD = 'KS'
                        -- B
                AND A.ENTER_CD = B.ENTER_CD(+)
                AND A.SABUN    = B.SABUN(+)
                AND A.WORK_YM  = B.WORK_YM(+)
                                    AND A.WORK_YM = REPLACE( '2025-07' ,'-' ,'')
                                                                                                AND B.WORK_YMD(+) BETWEEN NVL( REPLACE('','-',''),'19000101') AND  NVL( REPLACE('','-',''),'99991231')
                -- C
                AND A.ENTER_CD = C.ENTER_CD
                AND A.SABUN = C.SABUN
                    --20240306 근무일기준으로 부서명이 조회되도록 변경(한국공항)
                AND NVL(B.WORK_YMD,REPLACE( '2025-07' ,'-' ,'') || '01') BETWEEN C.SDATE AND NVL(C.EDATE, '99991231')

                -- D
                AND B.ENTER_CD = D.ENTER_CD(+)
                AND B.SABUN = D.SABUN(+)
                AND B.WORK_YMD = D.YMD(+)
                -- 지각 제외 2024.0419, 다시 포함 2024.04.29(기준수립 후 재요청 예정)
                --AND NVL(D.REASON_GUBUN,' ') != 'T0100'
                ) X
                WHERE 1=1
                ORDER BY WORK_YMD, ORG_NM, WORK_ORG_NM, SABUN ASC;
                