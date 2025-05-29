create or replace PROCEDURE P_BEN_CRE_CHILD_CARE_TAR (
         P_SQLCODE               OUT VARCHAR2, -- Error Code
         P_SQLERRM               OUT VARCHAR2, -- Error Messages
         P_ENTER_CD              IN  VARCHAR2, -- 회사코드
         P_TAR_YM    						 IN  VARCHAR2, -- 대상년월
         P_CHKID                 IN  VARCHAR2  -- 수정자
)
IS
   /* Local Variables */
   lv_biz_cd                  TSYS903.BIZ_CD%TYPE    := 'BEN';
   lv_object_nm               TSYS903.OBJECT_NM%TYPE := 'P_BEN_CHILD_CARE_CREATE';
   lv_last_ymd								VARCHAR(8);
   lv_prev_month							VARCHAR(6);
   
   --for HX, HG 2025.02.19 (cursor로 전환)
    CURSOR c_tben552 IS
          SELECT X.ENTER_CD,
                 X.APPL_SEQ,
                 X.SABUN,
                 X.PAY_YM,
                 X.PAY_AMT,
                 X.PAY_ST_CNT,
                 X.SPOUSE_APPL_SEQ,
                 X.CHKDATE,
                 X.CHKID,
                 X.NOTE1
          FROM (
             SELECT
                A.ENTER_CD,
                A.APPL_SEQ,
                A.SABUN,
                P_TAR_YM AS PAY_YM,
                C.PAY_AMT,
                A.PAY_ST_CNT,
                (SELECT AB.APPL_SEQ 
                   FROM TBEN551 AB
                  WHERE A.ENTER_CD = AB.ENTER_CD
                    AND AB.SABUN = F_BEN_GET_SPOUSE_SABUN(A.ENTER_CD, A.SABUN)
                    AND A.CHD_BIRTH = AB.CHD_BIRTH
                    AND A.CHD_NAME = AB.CHD_NAME) AS SPOUSE_APPL_SEQ,
                SYSDATE AS CHKDATE,
                P_CHKID AS CHKID,
                (SELECT CASE 
                          WHEN SUBSTR(A.CHD_BIRTH,1,6) BETWEEN AA.CHD_YY_SYM AND AA.CHD_YY_EYM 
                          THEN '' 
                          ELSE '0세 기준을 만족하지 않습니다.' 
                       END
                   FROM TBEN550 AA
                  WHERE AA.ENTER_CD = A.ENTER_CD
                    AND AA.CHD_YY_CNT = 0
                    AND AA.ENTER_CD = 'KS' -- 한국공항일 때만
                    AND A.PAY_GB = '01'    -- 직원일 때만
                    AND TO_CHAR(TO_DATE(P_TAR_YM,'YYYYMM'),'YYYYMMDD') BETWEEN AA.SDATE AND AA.EDATE) AS NOTE1
             FROM TBEN551 A, THRI103 B, TBEN550 C
             WHERE A.ENTER_CD = P_ENTER_CD
               AND A.ENTER_CD = B.ENTER_CD
               AND A.APPL_SEQ = B.APPL_SEQ
               AND B.APPL_STATUS_CD = '99'
               AND (A.USE_S_YM <= P_TAR_YM AND P_TAR_YM < NVL(A.USE_E_YM,'99991231'))
               AND (A.PAY_STS = 'P' OR 
                    (A.PAY_STS = 'S' AND (
                        -- 변경 '25.05.29
--                                        NVL(A.USE_MS_YM, A.USE_S_YM) <= P_TAR_YM AND 
--                                        P_TAR_YM < NVL(A.USE_E_YM, A.USE_M_YM)
                                          P_TAR_YM BETWEEN A.USE_S_YM AND A.USE_E_YM
                                          AND (A.USE_M_YM IS NULL 
                                               OR (
                                                 A.USE_M_YM>P_TAR_YM
                                                 OR
                                                 A.USE_MS_YM<=P_TAR_YM
                                               )
                                          )
                                        )
                    ))

               AND A.ENTER_CD = C.ENTER_CD
               AND TO_CHAR(TO_DATE(P_TAR_YM,'YYYYMM'),'YYYYMMDD') BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
               AND (
                   ( 1 = CASE 
                            WHEN P_ENTER_CD IN ('HX','HG','TP') THEN 
                               CASE 
                                  WHEN (C.CHD_YY_CNT = TRUNC(MONTHS_BETWEEN(SYSDATE, TO_DATE(A.CHD_BIRTH,'YYYYMMDD'))/12)) THEN 1
                                  --자녀 나이는 72개월 이상으로 대상이 아니나, 지원차수가 72회 미만인 대상 추가 2025.02.19
                                  WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, TO_DATE(A.CHD_BIRTH,'YYYYMMDD'))/12) > (SELECT MAX(CHD_YY_CNT)
                                                                                                            FROM TBEN550 
                                                                                                            WHERE ENTER_CD = A.ENTER_CD AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN SDATE AND NVL(EDATE,'99991231'))
                                       AND ( C.CHD_YY_CNT = TRUNC((F_BEN_CHD_PAY_CNT(A.ENTER_CD,
                                                                                 A.SABUN,
                                                                                 A.PART_SABUN,
                                                                                 A.APPL_SEQ,
                                                                                 A.CHD_NAME,
                                                                                 A.CHD_BIRTH
                                                                                ) + NVL(A.PAY_ST_CNT,0))/12)) THEN 1
                                  ELSE 0 
                               END
                            ELSE 
                               CASE WHEN SUBSTR(A.CHD_BIRTH,1,6) BETWEEN C.CHD_YY_SYM AND C.CHD_YY_EYM THEN 1 ELSE 0 END
                         END
                   AND ('N' = NVL((SELECT YY.STOP_YN 
                                    FROM TBEN552 YY
                                    WHERE YY.ENTER_CD = A.ENTER_CD
                                      AND YY.APPL_SEQ = A.APPL_SEQ
                                      AND YY.PAY_YM = (SELECT MAX(PAY_YM) 
                                                        FROM TBEN552 YY2
                                                        WHERE YY.ENTER_CD = YY2.ENTER_CD
                                                          AND YY.APPL_SEQ = YY2.APPL_SEQ)
                                   ), 'N')))
                OR EXISTS(SELECT 1 
                           FROM TBEN552 
                          WHERE ENTER_CD = A.ENTER_CD 
                            AND APPL_SEQ = A.APPL_SEQ 
                            AND STOP_PAY_YM = P_TAR_YM)
               )
          ) X;
BEGIN
	/* A-1 기본적으로 DELETE INERST */
	BEGIN
 		DELETE TBEN552 WHERE ENTER_CD = P_ENTER_CD AND PAY_YM = P_TAR_YM;
  EXCEPTION
      WHEN OTHERS THEN
          P_SQLCODE := TO_CHAR(SQLCODE);
          P_SQLERRM := P_TAR_YM||' : 자녀보육비 생성내역 삭제시 Error =>' || SQLERRM;
          P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'A-1',P_SQLERRM, P_CHKID);
          RETURN;
  END;

	/* A-2
		=> 작업기준 년월 전월 1/2이상 근무자는 정상 지급대상.
			중단년월=익월로 세팅, 지급상태="중지"로  TBEN551에 Upda, TBEN777에 등록 */
	BEGIN
		UPDATE TBEN551 A
		   SET A.USE_M_YM = TO_CHAR(ADD_MONTHS(TO_DATE(P_TAR_YM||'01', 'YYYYMMDD'), 1), 'YYYYMM')
		     , A.USE_MS_YM = NULL
		   	 , A.PAY_STS = 'S'
		   	 , A.CHKDATE = SYSDATE
		   	 , A.CHKID  = 'PRC_CHD_TAR'
		   	WHERE EXISTS (
		   	SELECT 1
				FROM THRI103 B
				 WHERE 1=1
				  -- 필수사항, 종료 아닐때만
				   AND A.PAY_STS <> 'F'
					 AND A.ENTER_CD = P_ENTER_CD
					-- B
					 AND A.ENTER_CD = B.ENTER_CD
					 AND A.APPL_SEQ = B.APPL_SEQ
					 AND B.APPL_STATUS_CD = '99'
					-- C
					-- 재직상태가 작업기준일 기준 휴직/정직(CA/EA)인데 중단년월이 없는 경우
					 AND (EXISTS( SELECT 1 FROM THRM151
					 							WHERE ENTER_CD = A.ENTER_CD
					 								AND SABUN = A.SABUN
					 								AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN SDATE AND NVL(EDATE,'99991231')
					 								AND STATUS_CD IN ('CA')) -- ,'EA'정직은 따로관리함
					 		OR EXISTS( SELECT 1 FROM THRM129 X, TSYS005 Y
													WHERE 1=1
													AND X.ENTER_CD = A.ENTER_CD
													AND X.SABUN    = A.SABUN
													AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN X.SDATE AND NVL(X.EDATE,'99991231')
													--
													AND X.ENTER_CD = Y.ENTER_CD
													AND X.PUNISH_CD = Y.CODE
													AND Y.GRCODE_CD = 'H20270'
													AND Y.NOTE1 = 'Y')
							)
				   AND ((A.USE_M_YM IS NULL  OR A.USE_M_YM = '')
				   			-- 중단년월이 있는데 복구년월이 있고 지급상태="지급"인 경우(재 휴직)
				   			OR ((A.USE_M_YM IS NOT NULL AND A.USE_M_YM <> '') AND (A.USE_MS_YM IS NOT NULL AND A.USE_MS_YM <> '')AND A.PAY_STS = 'P'))
				   AND (F_CPN_WKP_CNT( A.ENTER_CD, A.SABUN, TO_CHAR(TRUNC(TO_DATE(P_TAR_YM, 'YYYYMM'), 'MM') - 1,'YYYYMMDD') -- 해당월의 첫날
																								  , TO_CHAR(LAST_DAY(TO_DATE(P_TAR_YM,'YYYYMM') - 1), 'YYYYMMDD'))			-- 해당월의 마지막날
								/ TO_CHAR(LAST_DAY(TO_DATE(P_TAR_YM,'YYYYMM') - 1), 'DD')) >= 0.5
						);
	EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		P_SQLCODE := TO_CHAR(SQLCODE);
		P_SQLERRM := '자녀보육비내역생성_TBEN551 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
		P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'A-2',P_SQLERRM, P_CHKID);
	END;

	/* A-3
		=> 작업기준 전월 1/2미만 근무자는중단년월에
			해당 급여년월, 복구년월=null, 지급상태 "중지"로 TBEN551에 Update, TBEN777에 미등록 */
	BEGIN
		UPDATE TBEN551 A
		   SET A.USE_M_YM = TO_CHAR(ADD_MONTHS(TO_DATE(P_TAR_YM||'01', 'YYYYMMDD'), 1), 'YYYYMM')
		   	 , A.USE_MS_YM = NULL
		   	 , A.PAY_STS = 'S'
		   	 , A.CHKDATE = SYSDATE
		   	 , A.CHKID  = 'PRC_CHD_TAR'
		   	WHERE EXISTS (
		   	SELECT 1
				FROM THRI103 B
				 WHERE 1=1
				  -- 필수사항, 종료 아닐때만
				   AND A.PAY_STS <> 'F'
					 AND A.ENTER_CD = P_ENTER_CD
					-- B
					 AND A.ENTER_CD = B.ENTER_CD
					 AND A.APPL_SEQ = B.APPL_SEQ
					 AND B.APPL_STATUS_CD = '99'
					-- C
					-- 재직상태가 작업기준일 기준 휴직/정직(CA/EA)인데 중단년월이 없는 경우
					 AND (EXISTS( SELECT 1 FROM THRM151
					 							WHERE ENTER_CD = A.ENTER_CD
					 								AND SABUN = A.SABUN
					 								AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN SDATE AND NVL(EDATE,'99991231')
					 								AND STATUS_CD IN ('CA')) -- ,'EA'정직은 따로관리함
					 		OR EXISTS( SELECT 1 FROM THRM129 X, TSYS005 Y
													WHERE 1=1
													AND X.ENTER_CD = A.ENTER_CD
													AND X.SABUN    = A.SABUN
													AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN X.SDATE AND NVL(X.EDATE,'99991231')
													--
													AND X.ENTER_CD = Y.ENTER_CD
													AND X.PUNISH_CD = Y.CODE
													AND Y.GRCODE_CD = 'H20270'
													AND Y.NOTE1 = 'Y')
							)
				   AND ((A.USE_M_YM IS NULL OR A.USE_M_YM = '')
				   		-- 중단년월이 있는데 복구년월이 있고 지급상태="지급"인 경우(재 휴직)
				   		OR ((A.USE_M_YM IS NOT NULL AND A.USE_M_YM <> '') AND (A.USE_MS_YM IS NOT NULL AND A.USE_MS_YM <> '') AND A.PAY_STS = 'P'))
				   AND (F_CPN_WKP_CNT( A.ENTER_CD, A.SABUN, TO_CHAR(TRUNC(TO_DATE(P_TAR_YM||'01', 'YYYYMMDD'), 'MM') - 1,'YYYYMMDD') -- 해당월의 첫날
                                                , TO_CHAR(LAST_DAY(TO_DATE(P_TAR_YM||'01','YYYYMMDD') - 1), 'YYYYMMDD'))			-- 해당월의 마지막날
								/ TO_CHAR(LAST_DAY(TO_DATE(P_TAR_YM||'01','YYYYMMDD') - 1), 'DD')) < 0.5
						);
	EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		P_SQLCODE := TO_CHAR(SQLCODE);
		P_SQLERRM := '자녀보육비내역생성_TBEN551 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
		P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'A-3',P_SQLERRM, P_CHKID);
	END;

	/* A-4
		=> 대상자의 재직상태가 작업기준일 기준 재직인데 중단년월이 있고, 복구년월이 Null인 경우
			해당 급여년월을 복구년월, 지급상태 "지급"으로 TBEN551에 Update, TBEN777에 등록 */
	BEGIN
		UPDATE TBEN551 A
		   SET A.USE_MS_YM = P_TAR_YM
		   	 , A.PAY_STS = 'P'
		   	 , A.CHKDATE = SYSDATE
		   	 , A.CHKID  = 'PRC_CHD_TAR'
		   	WHERE EXISTS (
		   	SELECT 1
				FROM THRI103 B, THRM151 C
				 WHERE 1=1
				  -- 필수사항, 종료 아닐때만
				   AND A.PAY_STS <> 'F'
					 AND A.ENTER_CD = P_ENTER_CD
					-- B
					 AND A.ENTER_CD = B.ENTER_CD
					 AND A.APPL_SEQ = B.APPL_SEQ
					 AND B.APPL_STATUS_CD = '99'
					-- C
					 AND A.ENTER_CD = C.ENTER_CD
					 AND A.SABUN    = C.SABUN
					 AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
					 -- 대상자의 재직상태가 작업기준일 기준 재직인데 중단년월이 있고,
					 AND C.STATUS_CD = 'AA'
					 -- 복구년월이 Null인 경우
					 AND ((A.USE_M_YM IS NOT NULL AND A.USE_M_YM <> '') AND (A.USE_MS_YM IS NULL OR A.USE_MS_YM = ''))
					 );
	EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		P_SQLCODE := TO_CHAR(SQLCODE);
		P_SQLERRM := '자녀보육비내역생성_TBEN551 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
		P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'A-4',P_SQLERRM, P_CHKID);
	END;


	/* A-5
		=> 대상자의 재직상태가 작업기준일 기준 퇴직인데 종료년월이 Null인 경우
		 종료년월에 해당 급여년월, 지급상태 "종료"로 TBEN551에 Update, TBEN777에 등록
         지급상태="종료"이면 Skip*/
	BEGIN
		UPDATE TBEN551 A
		SET A.USE_E_YM = TO_CHAR(ADD_MONTHS(TO_DATE(P_TAR_YM, 'YYYYMM'), 1), 'YYYYMM')
			 , A.PAY_STS = 'F'
			 , A.CHKDATE = SYSDATE
			 , A.CHKID  = 'PRC_CHD_TAR'
		WHERE EXISTS (
				SELECT 1
				  FROM THRI103 B, THRM151 C
				WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				-- B
				 AND A.ENTER_CD = B.ENTER_CD
				 AND A.APPL_SEQ = B.APPL_SEQ
				 AND B.APPL_STATUS_CD = '99'
				-- C
				 AND A.ENTER_CD = C.ENTER_CD
				 AND A.SABUN    = C.SABUN
				 AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
				 AND C.STATUS_CD = 'RA'
				 AND ((A.USE_E_YM IS NULL OR A.USE_E_YM = ''))
		 )
		 -- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
	   AND A.PAY_STS <> 'F'
		 ;
	EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		P_SQLCODE := TO_CHAR(SQLCODE);
		P_SQLERRM := '자녀보육비내역생성_TBEN551 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
		P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'A-5',P_SQLERRM, P_CHKID);
	END;

	/* A-6
		=> 직원이면서 0세 미만 수정  */
	BEGIN
	UPDATE TBEN551 A
		SET A.USE_E_YM = TO_CHAR(ADD_MONTHS(TO_DATE(P_TAR_YM, 'YYYYMM'), 1), 'YYYYMM')
			 , A.PAY_STS = 'F'
			 , A.CHKDATE = SYSDATE
			 , A.CHKID  = 'PRC_CHD_TAR'
		WHERE EXISTS (
				SELECT 1
				  FROM THRI103 B, TBEN550 C
				WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				-- B
				 AND A.ENTER_CD = B.ENTER_CD
				 AND A.APPL_SEQ = B.APPL_SEQ
				 AND B.APPL_STATUS_CD = '99'
				-- C
				 AND A.ENTER_CD = C.ENTER_CD
				 --AND C.CHD_YY_CNT = 0
                 AND MONTHS_BETWEEN(TO_DATE(P_TAR_YM||'01','YYYYMMDD'), TO_DATE(A.CHD_BIRTH,'YYYYMMDD')) > 12
				 AND C.ENTER_CD = 'KS' -- 한국공항일 때만
				 AND A.PAY_GB = '01'   -- 직원일 떄만
				 AND TO_CHAR((TO_DATE(P_TAR_YM||'01','YYYYMMDD')), 'YYYYMMDD') BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
		 )
		 -- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
	   AND A.PAY_STS <> 'F'
		 ;
	EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		P_SQLCODE := TO_CHAR(SQLCODE);
		P_SQLERRM := '자녀보육비내역생성_TBEN551 A-6 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
		P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'A-6',P_SQLERRM, P_CHKID);
	END;	
	/* B-1
		TBEN551 (보육비 신청/승인) 시작년월~종료년월 사이에 해당되고 지급상태="지급"인 대상자의 사번, 신청서번호, 급여년월, 지급금액, 비과세금액, 지급횟수를
		TBEN552에 등록(Insert, Update)
		> 지급횟수 = (대상자 사번의 동일 신청서순번 TBEN552 지급횟수 + TBEN551의 배우자 사번, 동일 대상자에 대한 신청서번호의 TBEN552 지급횟수)+1

		<작업취소> TBEN552의 급여년월= 금번 급여년월인 데이터 삭제
		=======> 과세, 비과세 항목이 2개라 2번 작업이 이루어지는데 이때 pay_ym컬럼 뿐이라 작업취소시 삭제하는 것이 아니라 작업시 delete,insert 수행
	*/
    IF P_ENTER_CD = 'KS' THEN
        BEGIN
            INSERT INTO TBEN552
            SELECT Y.ENTER_CD, Y.APPL_SEQ, Y.SABUN, Y.PAY_YM
                 , Y.PAY_AMT
                 , Y.PAY_CNT
                 , Y.CHKDATE, Y.CHKID, 'N', NULL, Y.NOTE1
            FROM
            (SELECT X.ENTER_CD, X.APPL_SEQ, X.SABUN, X.PAY_YM, X.APP_GB, X.PAY_STS
                 , CASE WHEN F_COM_GET_STATUS_CD(X.ENTER_CD, X.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'CA'  AND F_BEN_GET_IS_CA_YN(X.ENTER_CD, X.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'N' THEN 0
                        WHEN F_COM_GET_STATUS_CD(X.ENTER_CD, X.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'CA'  AND F_BEN_GET_IS_CA_YN(X.ENTER_CD, X.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'Y' THEN X.PAY_AMT
                        WHEN F_COM_GET_STATUS_CD(X.ENTER_CD, X.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'AA' THEN X.PAY_AMT
                        ELSE 0 END AS PAY_AMT
                 , NVL(X.PAY_ST_CNT,0) + (SELECT COUNT(1) FROM TBEN552 WHERE ENTER_CD = X.ENTER_CD AND APPL_SEQ = X.SPOUSE_APPL_SEQ)
                                       + (SELECT COUNT(1) FROM TBEN552 WHERE ENTER_CD = X.ENTER_CD AND APPL_SEQ = X.APPL_SEQ)
                                       + 1 AS PAY_CNT
                 , X.CHKDATE, X.CHKID, 'N', NULL, X.NOTE1
            FROM (SELECT A.ENTER_CD
                        ,A.APPL_SEQ
                        ,A.SABUN,A.CHD_NAME,A.CHD_BIRTH
                        ,A.APP_GB
                        ,A.PAY_STS
                        ,P_TAR_YM AS PAY_YM
                        , (SELECT PAY_AMT FROM TBEN550
                            WHERE ENTER_CD = 'KS'
                            --AND A.CHD_BIRTH BETWEEN CHD_YY_SYM AND CHD_YY_EYM
                            AND SUBSTR(A.CHD_BIRTH,1,6) BETWEEN CHD_YY_SYM AND CHD_YY_EYM
                            AND P_TAR_YM||'01' BETWEEN SDATE AND EDATE) AS PAY_AMT
                        ,A.PAY_ST_CNT
                        , (SELECT AB.APPL_SEQ FROM TBEN551 AB
                            WHERE A.ENTER_CD = AB.ENTER_CD   AND AB.SABUN = F_BEN_GET_SPOUSE_SABUN(A.ENTER_CD, A.SABUN)
                              AND A.CHD_BIRTH = AB.CHD_BIRTH AND A.CHD_NAME = AB.CHD_NAME) AS SPOUSE_APPL_SEQ
                        , SYSDATE AS CHKDATE
                        , P_CHKID AS CHKID
                        , (SELECT CASE WHEN SUBSTR(A.CHD_BIRTH,1,6) BETWEEN AA.CHD_YY_SYM AND AA.CHD_YY_EYM THEN '' ELSE '0세 기준을 만족하지 않습니다.' END
                             FROM TBEN550 AA
                            WHERE AA.ENTER_CD = A.ENTER_CD AND AA.CHD_YY_CNT = 0
                              AND AA.ENTER_CD = 'KS' -- 한국공항일 때만
                              AND A.PAY_GB = '01'   -- 직원일 떄만
                              AND TO_DATE(P_TAR_YM||01,'YYYYMMDD') BETWEEN TO_DATE(AA.SDATE,'YYYYMMDD') AND TO_DATE(AA.EDATE,'YYYYMMDD')) AS NOTE1
                        --, RANK() OVER(PARTITION BY A.ENTER_CD, A.SABUN, A.CHD_NAME, A.CHD_BIRTH ORDER BY A.SABUN, A.CHD_NAME, A.CHD_BIRTH, A.APP_GB DESC, A.APPL_SEQ DESC) AS RANK_SN --신규와 변경건에 따른 순서 지정
                        , RANK() OVER(PARTITION BY A.ENTER_CD, A.SABUN, A.CHD_NAME, A.CHD_BIRTH ORDER BY A.SABUN, A.CHD_NAME, A.CHD_BIRTH, A.APPL_SEQ DESC) AS RANK_SN --신규와 변경건에 따른 순서 지정
                    FROM TBEN551 A, THRI103 B
                    WHERE 1=1
                        AND A.ENTER_CD = P_ENTER_CD
                        -- B
                        AND A.ENTER_CD = B.ENTER_CD
                        AND A.APPL_SEQ = B.APPL_SEQ
                        AND B.APPL_STATUS_CD = '99'
                        --AND (A.USE_S_YM <= P_TAR_YM AND P_TAR_YM < NVL(A.USE_E_YM,'99991231'))
                        --AND (A.PAY_STS = 'P' OR ( A.PAY_STS = 'S' AND ( NVL(A.USE_MS_YM, A.USE_S_YM) <= P_TAR_YM AND P_TAR_YM < NVL(A.USE_E_YM,A.USE_M_YM))))
                        -- 추가 '25.05.29
                        AND P_TAR_YM BETWEEN A.USE_S_YM AND A.USE_E_YM
                        AND (A.USE_M_YM IS NULL 
                             OR (
                               A.USE_M_YM>P_TAR_YM
                               OR
                               A.USE_MS_YM<=P_TAR_YM
                             )
                        )
                       /*
                        AND (A.CHD_SDATE <= TO_CHAR(LAST_DAY(TO_DATE(P_TAR_YM||'01', 'YYYYMMDD'))+1,'YYYYMMDD')
                            AND A.CHD_EDATE >= P_TAR_YM||'01'
                            OR TRUNC(MONTHS_BETWEEN(LAST_DAY(TO_DATE(P_TAR_YM||'01', 'YYYYMMDD')), TO_DATE(A.CHD_BIRTH,'YYYYMMDD')) /12) = 0 )
                        */
                         AND (
                             --어린이집은 계약일자 기준 
                             ( PAY_GB = '02' 
--                              AND  A.CHD_SDATE <= TO_CHAR(LAST_DAY(TO_DATE(P_TAR_YM||'01', 'YYYYMMDD'))+1,'YYYYMMDD')
--                              AND A.CHD_EDATE >= P_TAR_YM||'01')
--                                AND P_TAR_YM||'01' BETWEEN A.CHD_SDATE AND A.CHD_EDATE
                                AND
                                (
                                    (P_TAR_YM||'01' BETWEEN A.CHD_SDATE AND A.CHD_EDATE) OR
                                    (A.APP_GB='3' AND (A.CHD_SDATE IS NULL OR A.CHD_EDATE IS NULL))
                                )
                             )
                             OR 
                              --직원은 지급년월 1일 기준으로 11개월 까지 
                              --직원은 12번 지급, 어린이 생년월일+1개월부터
                             (PAY_GB = '01'
                              --AND MOD(TRUNC(MONTHS_BETWEEN(TRUNC(TO_DATE(P_TAR_YM||'01','YYYYMMDD')), A.CHD_BIRTH)),12) < 12 )
                             AND MONTHS_BETWEEN(TO_DATE(P_TAR_YM||'01','YYYYMMDD'), TO_DATE(A.CHD_BIRTH,'YYYYMMDD')) <= 12)
                             )
                         AND A.APPL_SEQ IN (SELECT MAX(Z.APPL_SEQ) 
                                            FROM TBEN551 Z
                                            WHERE Z.ENTER_CD = A.ENTER_CD
                                                AND Z.DEPT_CHK_YN ='Y'
                                            GROUP BY Z.ENTER_CD, Z.SABUN, Z.CHD_NAME, Z.CHD_BIRTH)
                         ) X
                  WHERE 1=1
                    AND X.RANK_SN = 1 --변경건이 최신으로 처리되도록 추가
                    --지급상태 제거 2025.05.29
                    --AND NOT(X.APP_GB='3' AND X.PAY_STS='F') -- 지급중단 제외
                    AND NOT EXISTS ( -- 퇴직자 제외
                        SELECT 1 FROM THRM151 W
                        WHERE W.ENTER_CD = X.ENTER_CD
                            AND W.SABUN = X.SABUN
                            AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN W.SDATE AND NVL(W.EDATE,'99991231')
                            AND W.STATUS_CD IN ('RA')
						  )
                ) Y;
        EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            P_SQLCODE := TO_CHAR(SQLCODE);
            P_SQLERRM := '자녀보육비 내역 INSERT ERROR! => ' || NVL(P_SQLERRM,SQLERRM);
            P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'B-0',P_SQLERRM, P_CHKID);
        END;
    ELSE 
        BEGIN
--            INSERT INTO TBEN552
--            SELECT X.ENTER_CD, X.APPL_SEQ, X.SABUN, X.PAY_YM
--            --, X.PAY_AMT
--            , CASE WHEN F_COM_GET_STATUS_CD(X.ENTER_CD, X.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'CA' 
--                              AND F_BEN_GET_IS_CA_YN(X.ENTER_CD, X.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'N' THEN 0
--                         WHEN F_COM_GET_STATUS_CD(X.ENTER_CD, X.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'CA' 
--                             AND F_BEN_GET_IS_CA_YN(X.ENTER_CD, X.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'Y' THEN X.PAY_AMT
--                         WHEN F_COM_GET_STATUS_CD(X.ENTER_CD, X.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'AA' THEN X.PAY_AMT
--                 ELSE 0 END AS PAY_AMT
--                    --, X.CNT + NVL((SELECT MAX(PAY_CNT) FROM TBEN552 WHERE ENTER_CD = X.ENTER_CD AND APPL_SEQ = X.SPOUSE_APPL_SEQ),0) + 1 AS PAY_CNT
--                    , NVL(X.PAY_ST_CNT,0) + (SELECT COUNT(1) FROM TBEN552 WHERE ENTER_CD = X.ENTER_CD AND APPL_SEQ = X.SPOUSE_APPL_SEQ)
--                    + (SELECT COUNT(1) FROM TBEN552 WHERE ENTER_CD = X.ENTER_CD AND APPL_SEQ = X.APPL_SEQ)
--                    + 1 AS PAY_CNT
--                    , X.CHKDATE, X.CHKID,'N',NULL, X.NOTE1
--            FROM (SELECT
--                        A.ENTER_CD
--                        ,A.APPL_SEQ
--                        ,A.SABUN
--                        ,P_TAR_YM AS PAY_YM
--                        ,C.PAY_AMT
--                        ,A.PAY_ST_CNT
--                        --, A.PAY_ST_CNT +  NVL((SELECT MAX(AA.PAY_CNT) FROM TBEN552 AA WHERE 1=1 AND A.ENTER_CD = AA.ENTER_CD AND A.APPL_SEQ = AA.APPL_SEQ),0) AS CNT
--                        , (SELECT AB.APPL_SEQ FROM TBEN551 AB
--                           WHERE A.ENTER_CD = AB.ENTER_CD   AND AB.SABUN = F_BEN_GET_SPOUSE_SABUN(A.ENTER_CD, A.SABUN)
--                             AND A.CHD_BIRTH = AB.CHD_BIRTH AND A.CHD_NAME = AB.CHD_NAME) AS SPOUSE_APPL_SEQ
--                        , SYSDATE AS CHKDATE
--                        , P_CHKID AS CHKID
--                        , (SELECT CASE WHEN SUBSTR(A.CHD_BIRTH,1,6) BETWEEN AA.CHD_YY_SYM AND AA.CHD_YY_EYM THEN '' ELSE '0세 기준을 만족하지 않습니다.' END
--                            FROM TBEN550 AA
--                            WHERE AA.ENTER_CD = A.ENTER_CD AND AA.CHD_YY_CNT = 0
--                                AND AA.ENTER_CD = 'KS' -- 한국공항일 때만
--                                AND A.PAY_GB = '01'   -- 직원일 떄만
--                              AND TO_CHAR((TO_DATE(P_TAR_YM,'YYYYMM')), 'YYYYMMDD') BETWEEN AA.SDATE AND AA.EDATE) AS NOTE1
--                    FROM TBEN551 A, THRI103 B, TBEN550 C
--                    WHERE 1=1
--                        AND A.ENTER_CD = P_ENTER_CD
--                        -- B
--                        AND A.ENTER_CD = B.ENTER_CD
--                        AND A.APPL_SEQ = B.APPL_SEQ
--                        AND B.APPL_STATUS_CD = '99'
--                        AND (A.USE_S_YM <= P_TAR_YM AND P_TAR_YM < NVL(A.USE_E_YM,'99991231'))
--                        AND (A.PAY_STS = 'P' OR ( A.PAY_STS = 'S' AND ( NVL(A.USE_MS_YM, A.USE_S_YM) <= P_TAR_YM AND P_TAR_YM < NVL(A.USE_E_YM,A.USE_M_YM))))
--                        -- C
--                        AND A.ENTER_CD = C.ENTER_CD
--                        AND TO_CHAR((TO_DATE(P_TAR_YM,'YYYYMM')), 'YYYYMMDD') BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
--                AND ((1 = CASE WHEN P_ENTER_CD IN( 'HX','HG')
--                                                    --THEN CASE WHEN C.CHD_YY_CNT = TRUNC(MONTHS_BETWEEN(SYSDATE, TO_DATE(A.CHD_BIRTH,'YYYYMMDD')) /12) THEN 1 ELSE 0 END
--                                                    THEN CASE 
--                                                        WHEN 
--                                                        (C.CHD_YY_CNT = TRUNC(MONTHS_BETWEEN(SYSDATE, TO_DATE(A.CHD_BIRTH,'YYYYMMDD')) /12)) 
--                                                        THEN 1
--                                                        WHEN 
--                                                        TRUNC(MONTHS_BETWEEN(SYSDATE, TO_DATE(A.CHD_BIRTH,'YYYYMMDD')) /12) > 5 AND
--                                                        (
--                                                        C.CHD_YY_CNT = 
--                                                        TRUNC((F_BEN_CHD_PAY_CNT(
--                                                        A.ENTER_CD,
--                                                        A.SABUN,
--                                                        A.PART_SABUN,
--                                                        A.APPL_SEQ,
--                                                        A.CHD_NAME,
--                                                        A.CHD_BIRTH
--                                                        ) + NVL(A.PAY_ST_CNT,0)) / 12)
--                                                        )
--                                                        THEN 1 
--                                                        ELSE 0 END
--                                                    ELSE CASE WHEN SUBSTR(A.CHD_BIRTH,1,6) BETWEEN C.CHD_YY_SYM AND C.CHD_YY_EYM THEN 1 ELSE 0 END
--                                         END
--                                        AND ('N' = NVL((SELECT YY.STOP_YN FROM TBEN552 YY
--                                                                WHERE YY.ENTER_CD = A.ENTER_CD
--                                                                    AND YY.APPL_SEQ = A.APPL_SEQ
--                                                                    AND YY.PAY_YM = (SELECT MAX(PAY_YM) FROM TBEN552 YY2
--                                                                                                        WHERE YY.ENTER_CD = YY2.ENTER_CD
--                                                                                                            AND YY.APPL_SEQ = YY2.APPL_SEQ
--                                                                    )
--                                                                ),'N'))
--                                                OR ( EXISTS(SELECT 1 FROM TBEN552 WHERE ENTER_CD = A.ENTER_CD AND APPL_SEQ = A.APPL_SEQ AND STOP_PAY_YM = P_TAR_YM))
--                                    )
--                                )
--                        ) X;


    FOR rec IN c_tben552 LOOP
      INSERT INTO TBEN552 (
         ENTER_CD,
         APPL_SEQ,
         SABUN,
         PAY_YM,
         PAY_AMT,
         PAY_CNT,
         CHKDATE,
         CHKID,
         STOP_YN,
         STOP_PAY_YM,
         NOTE1
      )
      VALUES (
         rec.ENTER_CD,
         rec.APPL_SEQ,
         rec.SABUN,
         rec.PAY_YM,
         CASE 
            WHEN F_COM_GET_STATUS_CD(rec.ENTER_CD, rec.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'CA'
                 AND F_BEN_GET_IS_CA_YN(rec.ENTER_CD, rec.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'N'
            THEN 0
            WHEN F_COM_GET_STATUS_CD(rec.ENTER_CD, rec.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'CA'
                 AND F_BEN_GET_IS_CA_YN(rec.ENTER_CD, rec.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'Y'
            THEN rec.PAY_AMT
            WHEN F_COM_GET_STATUS_CD(rec.ENTER_CD, rec.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'AA'
            THEN rec.PAY_AMT
            ELSE 0
         END,
         NVL(rec.PAY_ST_CNT, 0) +
         (SELECT COUNT(1) FROM TBEN552 WHERE ENTER_CD = rec.ENTER_CD AND APPL_SEQ = rec.SPOUSE_APPL_SEQ) +
         (SELECT COUNT(1) FROM TBEN552 WHERE ENTER_CD = rec.ENTER_CD AND APPL_SEQ = rec.APPL_SEQ) + 1,
         rec.CHKDATE,
         rec.CHKID,
         'N',
         NULL,
         rec.NOTE1
      );
   END LOOP;
   
   
        EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            P_SQLCODE := TO_CHAR(SQLCODE);
            P_SQLERRM := '자녀보육비 내역 INSERT ERROR!! => ' || NVL(P_SQLERRM,SQLERRM);
            P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'B-1',P_SQLERRM, P_CHKID);
        END;
    END IF;

	/* B-2
		- 작업 했으니까 종료로 변경*/
	BEGIN
		UPDATE TBEN551 A1
		SET A1.USE_E_YM = TO_CHAR(ADD_MONTHS(TO_DATE(P_TAR_YM, 'YYYYMM'), 1), 'YYYYMM') -- 중단년월
			, A1.PAY_STS = 'F'
		WHERE EXISTS(
						SELECT 1
						FROM (SELECT A1.ENTER_CD
									 		 , A1.SABUN
									 		 , A1.CHD_NAME
									 		 , A1.CHD_BIRTH
									 		 , A2.APPL_YMD
									 		 , NVL((SELECT MAX(PAY_CNT) FROM TBEN552 WHERE ENTER_CD = A1.ENTER_CD AND APPL_SEQ = A1.APPL_SEQ),0) AS PAY_CNT
									FROM THRI103 A2, TBEN552 A3
									WHERE 1=1
										AND A1.ENTER_CD = P_ENTER_CD
										AND P_TAR_YM BETWEEN NVL(A1.USE_MS_YM, A1.USE_S_YM) AND NVL(A1.USE_E_YM,'99991231')
									-- A2
										AND A1.ENTER_CD = A2.ENTER_CD
										AND A1.APPL_SEQ = A2.APPL_SEQ
										AND A2.APPL_STATUS_CD = '99'
									-- A3
										AND A1.ENTER_CD = A3.ENTER_CD
										AND A1.APPL_SEQ = A3.APPL_SEQ
										AND A3.PAY_YM   = P_TAR_YM
										AND A3.SABUN    = A1.SABUN
										AND (A3.PAY_CNT >(SELECT (MAX(X.CHD_YY_CNT) + 1) * 12
																	 		 FROM TBEN550 X
																			WHERE X.ENTER_CD = P_ENTER_CD
																	  		AND A2.APPL_YMD BETWEEN X.SDATE AND X.EDATE)
													OR (TRUNC(MONTHS_BETWEEN(SYSDATE, TO_DATE(A1.CHD_BIRTH,'YYYYMMDD')) /12) = 72)
													)
										) B1
						)
		 -- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
	   AND A1.PAY_STS <> 'F'
										;

										/*
										, TBEN550 B2
									WHERE 1=1
										AND B1.ENTER_CD = B2.ENTER_CD
										AND B1.APPL_YMD BETWEEN B2.SDATE AND B2.EDATE
											AND (((SELECT MAX(BB2.CHD_YY_CNT)
													 FROM TBEN550 BB2
													WHERE BB2.ENTER_CD = B2.ENTER_CD
														AND BB2.SDATE    = B2.SDATE
														AND BB2.CHD_YY_CNT = B2.CHD_YY_CNT
														AND BB2.CHD_YY_SYM = B2.CHD_YY_SYM) < B1.CHD_YY_CNT) -- 기준에 없거나
													OR ((B2.CHD_YY_CNT + 1) * 12  < PAY_CNT))*/

	EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		P_SQLCODE := TO_CHAR(SQLCODE);
		P_SQLERRM := '자녀보육비 후처리 중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
		P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'B-2',P_SQLERRM, P_CHKID);
	END;

EXCEPTION
WHEN OTHERS THEN
   P_SQLCODE := TO_CHAR(SQLCODE);
   P_SQLERRM := '자녀보육비 내역 생성오류' || SQLERRM;
   P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm, 'A-0', P_SQLERRM, P_CHKID);
	 --ROLLBACK;
END P_BEN_CRE_CHILD_CARE_TAR;