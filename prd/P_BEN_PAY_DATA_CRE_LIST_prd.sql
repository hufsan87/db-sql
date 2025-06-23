create or replace PROCEDURE             P_BEN_PAY_DATA_CRE_LIST (
         P_SQLCODE               OUT VARCHAR2, -- Error Code
         P_SQLERRM               OUT VARCHAR2, -- Error Messages
         P_ENTER_CD              IN  VARCHAR2, -- 회사코드
				 P_CPN201 							 IN OUT TCPN201%ROWTYPE, -- 급여정보
				 P_BENEFIT_BIZ_CD				 IN  VARCHAR2, --복리후생업무구분코드(B10230)
				 P_BUSINESS_PLACE_CD 		 IN  VARCHAR2, -- 사업장 구분코드
         P_CHKID                 IN  VARCHAR2  -- 수정자
)
/********************************************************************************/
/*  PROCEDURE NAME : P_BEN_PAY_DATA_CRE_LIST                                    */
/*                   [복리후생 급여작업]              															 */
/********************************************************************************/
/*  [ PRC 개요 ]                                                                 */
/*    마감 요청사항에 따라 복리후생별 로직구현                                              */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/*------------------------------------------------------------------------------*/
/* 2023-11-02  J.J.H           Initial Release                                  */
/********************************************************************************/
is
   /* Local Variables */
   lv_biz_cd                  TSYS903.BIZ_CD%TYPE    := 'BEN';
   lv_object_nm               TSYS903.OBJECT_NM%TYPE := 'P_BEN_PAY_DATA_CRE_LIST';
   lv_pay_ym 									VARCHAR2(6) := P_CPN201.PAY_YM;
BEGIN
 P_SQLCODE  := NULL;
 P_SQLERRM  := NULL;

 IF P_CPN201.PAY_CD = 'A3' THEN -- 퇴직정산일때만 익월이기 때문에
 	lv_pay_ym := TO_CHAR(ADD_MONTHS(TO_DATE(P_CPN201.PAY_YM, 'YYYYMM'), 1), 'YYYYMM');
 END IF;

/* 복리후생(주의사항)
	- 복리후생 별도 관리테이블 TBEN997 존재
	- 따로 지급, 공제 맵핑관리를하는데 TBEN997은 지급 테이블이기때문에 지급만 넣어야 함
	- 때문에 복리후생 항목보고 판단필요

	한진정보(HX) : 퇴직정산(A3) 익월, [월급여(A1), 퇴직월급여(A2)] 당월
	한국공항(KS) : 월급여(A1)   당월, 퇴직정산(A3) 익월
	TBEN777 INSERT 시 밑에 금액과 항목 매핑 테이블과 및 대상자와테이블과 조인해놨기 때문에 PAY_YM만 조정해놓으면 맵핑안된 친구들은 안들어감

	TBEN997에는 지급만 따로 관리하는데 한번만 들어가면 되기때문에 A1일때만 INSERT, 어차피 급여 1번은 무조건 나가기 때문
*/

  CASE P_BENEFIT_BIZ_CD
   --------------------
   -- 51 : 학자금
   --------------------
	 WHEN '51' THEN
    	/*TBEN751(학자금신청/승인) 급여년월, 과세여부체크된 대상자의 지급금액 합
      	한국공항 : 대상자가 등기임원인 경우 과세여부 체크
			  한진정보 : 지급 급여항목코드 없음, 년합산과세로 TBEN997에서 향후 연말정산 소득으로 집계
			24.04.29*/
	    BEGIN
				INSERT INTO TBEN777
				SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
				     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
				     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
				FROM(SELECT X.ENTER_CD
						 		 , P_CPN201.PAY_ACTION_CD
						 		 , X.SABUN
						 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
						     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
						     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
						     , P_CPN201.PAYMENT_YMD AS PAY_YMD
						     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
						     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
						     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요 [예시] 과세, 비과세 등*/
						     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
						     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
						     /**/
						     , '' AS PAY_MEMO
						     --, ln_pay_except_gubun AS PAY_EXCEPT_GUBUN
						     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P:지급, E:공제
						     , '' AS MEMO
						     , SYSDATE AS CHKDATE
						     , P_CHKID AS CHKID
						FROM (
										SELECT A.ENTER_CD, A.SABUN, A.PAY_AMT
												 , B.MON1_YN, B.MON2_YN, B.MON3_YN, B.MON4_YN, B.MON5_YN, B.MON6_YN
												 , B.MON7_YN, B.MON8_YN, B.MON9_YN , B.MON10_YN, B.MON11_YN, B.MON12_YN
												 , C.ELEMENT_TYPE, C.ELEMENT_CD
											FROM (SELECT AA.ENTER_CD, AA.SABUN, SUM(AA.PAY_AMT) AS PAY_AMT
															FROM TBEN751 AA
														 WHERE 1=1
														 /*조건 1.급여년월이있고, 2.과세여부체크된값*/
															 AND AA.ENTER_CD = P_ENTER_CD
														 /* 모든 계열사 마감작업이 있음, 그 중 한진정보만 한진정보는 연합산과세만 진행 때문에 하드코딩필요(모든계열사가 작업하기 때문)
														 	 한진칼은 한국공항과 동일
														 */
                                                        
														AND AA.ENTER_CD <> 'HX'
														   AND AA.TAX_YN   = 'Y' -- 등기임원 판단불가 과세여부로 판단
															 AND AA.PAY_YM   = lv_pay_ym
														GROUP BY AA.ENTER_CD, AA.SABUN
														) A, TBEN005 B, TCPN011 C, TCPN203 D
											WHERE 1=1
											-- B
											  AND B.ENTER_CD = A.ENTER_CD
											  AND B.PAY_CD   = P_CPN201.PAY_CD
											  AND B.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD -- 학자금[51]
											-- C
												AND C.ENTER_CD   = B.ENTER_CD
											  AND C.ELEMENT_CD = B.ELEMENT_CD
											  AND P_CPN201.PAYMENT_YMD BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
											-- D
												AND A.ENTER_CD = D.ENTER_CD
												AND A.SABUN    = D.SABUN
												AND P_CPN201.PAY_ACTION_CD = D.PAY_ACTION_CD
						       ) X
						GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
				) A;
      EXCEPTION
      WHEN OTHERS THEN
      		ROLLBACK;
          P_SQLCODE := TO_CHAR(SQLCODE);
          P_SQLERRM := '학자금(51)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
          P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'51',P_SQLERRM, P_CHKID);
      END;

			/* TBEN997 : TBEN751(학자금신청/승인) 급여년월 대상자의 지급금액 합 TBEN997에 지급금액, 급여년월 등록*/
			BEGIN
			  INSERT INTO TBEN997
				SELECT A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN
						 , SUM(A.PAY_AMT) AS PAY_AMT, P_CPN201.PAY_YM, '10003', SYSDATE, P_CHKID
					FROM TBEN751 A
					WHERE 1=1
					/*조건 1.급여년월이있고*/
						AND A.ENTER_CD = P_ENTER_CD
						AND A.PAY_YM   = lv_pay_ym
						AND P_CPN201.PAY_CD = 'A1'
				GROUP BY A.ENTER_CD, A.SABUN
				;
			EXCEPTION
			WHEN OTHERS THEN
				ROLLBACK;
				P_SQLCODE := TO_CHAR(SQLCODE);
				P_SQLERRM := '학자금(51)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
				P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'51',P_SQLERRM, P_CHKID);
			END;

   --------------------
   -- 52 : 경조금, 회람
   --------------------
   WHEN '52' THEN
     	/*TEBN471(경조금신청/승인) 급여년월, 지급금액 합으로 TBEN997에 지급금액, 급여년월 등록*/
      BEGIN
				INSERT INTO TBEN997
				SELECT B.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, B.SABUN, SUM(B.PAY_AMT), A.PAY_YM, '10003', SYSDATE, P_CHKID
				FROM TCPN201 A, TBEN471 B, THRI103 C
				WHERE 1=1
					AND A.ENTER_CD 			= P_ENTER_CD
				  AND A.PAY_ACTION_CD = P_CPN201.PAY_ACTION_CD
				  -- B
				  AND A.ENTER_CD = B.ENTER_CD
				  AND A.PAY_YM   = SUBSTR(B.PAY_YMD,0,6) -- 경조는 개별지급, 때문에 급여년월 항목이 없음
				  -- C
				  AND B.ENTER_CD = C.ENTER_CD
				  AND B.APPL_SEQ = C.APPL_SEQ
				  AND C.APPL_STATUS_CD = '99'
				  -- 별도추가
					AND A.PAY_YM   = lv_pay_ym
					AND P_CPN201.PAY_CD = 'A1'
				GROUP BY B.ENTER_CD, B.SABUN, A.PAY_YM;
			EXCEPTION
			WHEN OTHERS THEN
				ROLLBACK;
				P_SQLCODE := TO_CHAR(SQLCODE);
				P_SQLERRM := '경조(52)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
				P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'52',P_SQLERRM, P_CHKID);
			END;

      	/*TBEN475 (경조회람) 급여년월 회람참여사번의
      				   > 참여금액 합 => 해당 급여항목코드의 금액항목에 등록
                 > 해당 대상자의 TBEN475 데이터의 PAY_YN(공제여부)="Y"로 Update*/
      	BEGIN
				INSERT INTO TBEN777
       	SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
				     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
				     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
				FROM(SELECT X.ENTER_CD
						 		 , P_CPN201.PAY_ACTION_CD
						 		 , X.SABUN
						 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
						     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
						     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
						     , P_CPN201.PAYMENT_YMD AS PAY_YMD
						     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
						     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
						     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요 [예시] 과세, 비과세 등*/
						     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
						     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
						     , '' AS PAY_MEMO
						     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P:지급, E:공제
						     , '' AS MEMO
						     , SYSDATE AS CHKDATE
						     , P_CHKID AS CHKID
						FROM (
										SELECT A.ENTER_CD, A.CIRC_SABUN AS SABUN, A.CIRC_AMT AS PAY_AMT
												 , B.MON1_YN, B.MON2_YN, B.MON3_YN, B.MON4_YN, B.MON5_YN, B.MON6_YN
												 , B.MON7_YN, B.MON8_YN, B.MON9_YN , B.MON10_YN, B.MON11_YN, B.MON12_YN
												 , C.ELEMENT_TYPE, C.ELEMENT_CD
											FROM TBEN475 A, TBEN005 B, TCPN011 C, THRI103 D, TCPN203 E
											WHERE 1=1
											/*조건 1.급여년월이있고, 2.과세여부체크된값*/
												AND A.ENTER_CD = P_ENTER_CD
												AND A.ENTER_CD = 'KS' -- 한국공항만 ==> 해당항목은 경조[51] 일 떄 회람도 같이 돌기 때문에 회람분기처리 필요
												AND A.PAY_YM   = lv_pay_ym
											-- B
											  AND B.ENTER_CD = A.ENTER_CD
											  AND B.PAY_CD   = P_CPN201.PAY_CD
											  AND B.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
											-- C
												AND C.ENTER_CD   = B.ENTER_CD
											  AND C.ELEMENT_CD = B.ELEMENT_CD
											  AND P_CPN201.PAYMENT_YMD BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
											-- D
												AND A.ENTER_CD = D.ENTER_CD
												AND A.APPL_SEQ = D.APPL_SEQ
												AND D.APPL_STATUS_CD = '99'
											-- E
												AND A.ENTER_CD 		= E.ENTER_CD
												AND A.CIRC_SABUN  = E.SABUN
												AND P_CPN201.PAY_ACTION_CD = E.PAY_ACTION_CD
						       ) X
						GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
					) A;
			EXCEPTION
			WHEN OTHERS THEN
				ROLLBACK;
				P_SQLCODE := TO_CHAR(SQLCODE);
				P_SQLERRM := '경조회람(52)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
				P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'52',P_SQLERRM, P_CHKID);
			END;

			BEGIN
				UPDATE TBEN475
					 SET PAY_YN = 'Y'
				 WHERE ENTER_CD = P_ENTER_CD
					 AND PAY_YM 	= lv_pay_ym--P_CPN201.PAY_YM
					 --AND P_CPN201.PAY_CD   <>'A3' -- 급여대상자 쿼리가 추가됬기 떄문에 주석처리
					 AND CIRC_SABUN IN (SELECT X.SABUN FROM TCPN203 X
					 										 WHERE X.ENTER_CD = ENTER_CD
					 										 	 AND X.PAY_ACTION_CD = P_CPN201.PAY_ACTION_CD)

					 ;
			EXCEPTION
			WHEN OTHERS THEN
				ROLLBACK;
				P_SQLCODE := TO_CHAR(SQLCODE);
				P_SQLERRM := '경조회람(53)_TBEN475 UPDATE 에러 => ' || NVL(P_SQLERRM,SQLERRM);
				P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'53',P_SQLERRM, P_CHKID);
			END;

   --------------------
   -- 53 : 항공권할인
   --------------------
   WHEN '53' THEN
   	/*TBEN481 (항공권할인 신청/승인) 급여년월, 대상자의 신청내역 과세여부=Y"인 경우 지급금액 합
    	 => 한진정보 : 해당 급여항목코드의 금액항목에 등록
    	 => 한국공항 : 대상자가 등기임원인 경우만 해당 급여항목코드의 금액항목에 등록( 등기임원여부 판단불가 -> 담당자가 과세체크 등록하고, 체크된 항목 등록 )*/
   	BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
			 		 , P_CPN201.PAY_ACTION_CD
			 		 , X.SABUN
			 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
			     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
			     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
			     , P_CPN201.PAYMENT_YMD AS PAY_YMD
			     , SUM(DECODE(X.MON1_YN,  'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
			     , SUM(DECODE(X.MON2_YN,  'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
			     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요 [예시] 과세, 비과세 등*/
			     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
			     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
			     , '' AS PAY_MEMO
			     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P:지급, E:공제
			     , '' AS MEMO
			     , SYSDATE AS CHKDATE
			     , P_CHKID AS CHKID
			FROM (
							SELECT A.ENTER_CD, A.SABUN, A.PAY_AMT
									 , B.MON1_YN, B.MON2_YN, B.MON3_YN, B.MON4_YN, B.MON5_YN, B.MON6_YN
									 , B.MON7_YN, B.MON8_YN, B.MON9_YN , B.MON10_YN, B.MON11_YN, B.MON12_YN
									 , C.ELEMENT_TYPE, C.ELEMENT_CD
								FROM TBEN481 A, TBEN005 B, TCPN011 C, THRI103 D, TCPN203 E
								WHERE 1=1
									AND A.ENTER_CD = P_ENTER_CD
								/*공통조건 급여년월 2023.10 요청사항에 의해서 변경 됨
										1.한진정보 : 지급유예년월 = 급여년월 OR 지급유예 N
										2.한국공항 : 과세여부체크*/
									AND 1 = CASE WHEN (P_ENTER_CD = 'HX' OR P_ENTER_CD = 'TP')
														THEN CASE WHEN ((A.STOP_YN = 'N' AND A.PAY_YM   = lv_pay_ym)
																			 		OR (A.STOP_PAY_YM = lv_pay_ym)) THEN 1 ELSE 0 END
 													  ELSE CASE WHEN A.TAX_YN   = 'Y' THEN 1 ELSE 0 END
													  END
								-- B
								  AND B.ENTER_CD = A.ENTER_CD
								  AND B.PAY_CD   = P_CPN201.PAY_CD
								  AND B.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
								-- C
									AND C.ENTER_CD   = B.ENTER_CD
								  AND C.ELEMENT_CD = B.ELEMENT_CD
								  AND P_CPN201.PAYMENT_YMD BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
								-- D
									AND A.ENTER_CD   = D.ENTER_CD
									AND A.APPL_SEQ	 = D.APPL_SEQ
									AND D.APPL_STATUS_CD = '99'
								-- E
									AND A.ENTER_CD = E.ENTER_CD
									AND A.SABUN    = E.SABUN
									AND P_CPN201.PAY_ACTION_CD = E.PAY_ACTION_CD
			       ) X
							GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '항공권(53)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'53',P_SQLERRM, P_CHKID);
		END;

	  BEGIN
	    		/* TBEN481 (항공권할인 신청/승인) 급여년월, 대상자의 지급금액 합=> TBEN997에 급여년월, 지급금액 등록 */
			INSERT INTO TBEN997
			SELECT B.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, B.SABUN, SUM(B.PAY_AMT), A.PAY_YM, '10003', SYSDATE, P_CHKID
			FROM TCPN201 A, TBEN481 B, THRI103 C, TBEN005 D
			WHERE 1=1
				AND A.ENTER_CD 			= P_ENTER_CD
			  AND A.PAY_ACTION_CD = P_CPN201.PAY_ACTION_CD
			  -- 어차피 항국공항에서는 지급유예숨길거기때문에 회사조건 필요없음
			  -- B
			  AND A.ENTER_CD = B.ENTER_CD
			  AND ((B.STOP_YN = 'N' AND A.PAY_YM = B.PAY_YM) OR (B.STOP_PAY_YM = P_CPN201.PAY_YM))
			  -- C
			  AND B.ENTER_CD = C.ENTER_CD
			  AND B.APPL_SEQ = C.APPL_SEQ
			  AND C.APPL_STATUS_CD = '99'
			  -- D
			  AND D.ENTER_CD = A.ENTER_CD
			  AND D.PAY_CD   = P_CPN201.PAY_CD
			  AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
			  AND F_CPN_GET_ELEMENT_TYPE(D.ENTER_CD, D.ELEMENT_CD, P_CPN201.PAYMENT_YMD) = 'A' -- 지급만
				-- 별도추가
				AND A.PAY_YM   = lv_pay_ym
				AND P_CPN201.PAY_CD = 'A1'
			GROUP BY B.ENTER_CD, B.SABUN, A.PAY_YM;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '항공권(53)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'53',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 54 : 자녀(위탁)보육비
  --------------------
  WHEN '54' THEN
	/* 1차 때는 마감시 상태값 조정을 다했지만
	   통테때 변경사항으로 복리후생쪽에서 내역생성 후 내역을 가져오는 방법으로 변경
			54-1
			TBEN552 (보육비 신청/승인) 시작년월~종료년월 사이에 해당되고 지급상태="지급"인  대상자의 지급금액 합) => TBEN997에 급여년월, 지급금액 등록
	*/
		BEGIN
			INSERT INTO TBEN997
			SELECT B.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, B.SABUN, SUM(B.PAY_AMT) AS PAY_AMT, B.PAY_YM, '10003', SYSDATE, P_CHKID
			FROM TCPN201 A, TBEN552 B
			WHERE 1=1
				AND A.ENTER_CD 			= P_ENTER_CD
			  AND A.PAY_ACTION_CD = P_CPN201.PAY_ACTION_CD
			-- B
			  AND A.ENTER_CD = B.ENTER_CD
				AND ((B.STOP_YN = 'N' AND A.PAY_YM = B.PAY_YM) OR (B.STOP_PAY_YM = lv_pay_ym))
				AND P_CPN201.PAY_CD = 'A1'
			GROUP BY B.ENTER_CD, B.PAY_YM, B.SABUN
			;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '자녀위탁비(54)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'54-1',P_SQLERRM, P_CHKID);
		END;

		/*<TBEN777에 등록인 경우>
      	<한국공항>
				TBEN552 (보육비 지급내역) 지급년월 = 해당 급여년월에 해당되는 신청자의 모든 대상자녀의 지급금액 합  - 비과세금액 => 과세 급여항목코드,비과세 급여항목코드의 금액항목에 등록,
				              (비과세금액=신청자의 첫번째 대상자자녀 만 나이에 해당되는 TBEN550의 비과세금액)
				<한진정보>
				TBEN552 (보육비 지급내역) 지급년월 or 지급유예 지급년월 = 해당 급여년월에 해당되는 신청자의 모든 대상자녀의 지급금액 합  - 비과세금액
				   => 과세 급여항목코드,비과세 급여항목코드의 금액항목에 등록 (비과세금액=신청자의 첫번째 대상자자녀 만 나이에 해당되는 TBEN550의 비과세금액)
		*/
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요 [예시] 과세, 비과세 등*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (SELECT A.ENTER_CD, A.SABUN
                           ,(CASE WHEN B.MON1_YN = 'Y' THEN (CASE WHEN NVL(A.NTAX_AMT,0) >= NVL(A.PAY_AMT,0) THEN NVL(A.PAY_AMT,0) ELSE NVL(A.NTAX_AMT,0) END)  --  비과세
                                  WHEN B.MON2_YN = 'Y' THEN (CASE WHEN NVL(A.PAY_AMT,0) > NVL(A.NTAX_AMT,0) THEN NVL(A.PAY_AMT,0) - NVL(A.NTAX_AMT,0) ELSE 0 END)  --  과세
                                  END) AS PAY_AMT
			 		 /*, CASE WHEN B.MON1_YN = 'Y' THEN NVL(A.NTAX_AMT,0) --  비과세
			 		 		    WHEN B.MON2_YN = 'Y' THEN CASE WHEN NVL(A.PAY_AMT,0) - NVL(A.NTAX_AMT,0) < 0 THEN 0 ELSE NVL(A.PAY_AMT,0) - NVL(A.NTAX_AMT,0) END -- 과세
			 		 	 END AS PAY_AMT*/
					 , B.MON1_YN, B.MON2_YN, B.MON3_YN, B.MON4_YN,  B.MON5_YN,  B.MON6_YN
					 , B.MON7_YN, B.MON8_YN, B.MON9_YN, B.MON10_YN, B.MON11_YN, B.MON12_YN
					 , C.ELEMENT_TYPE, C.ELEMENT_CD
			   FROM (SELECT ENTER_CD, SABUN, SUM(PAY_AMT) AS PAY_AMT
			   					-- 비과세금액은 동일하기 떄문에 MAX값으로 사용할 예정
			   						, (SELECT MAX(X.NTAX_AMT)
			   								 FROM TBEN550 X
			   								WHERE P_CPN201.PAYMENT_YMD BETWEEN X.SDATE AND NVL(X.EDATE,'99991231')
			   									AND X.ENTER_CD = P_ENTER_CD) AS NTAX_AMT
									FROM TBEN552
								 WHERE ENTER_CD = P_ENTER_CD
									 AND ((STOP_YN = 'N' AND PAY_YM = lv_pay_ym)
										OR (STOP_PAY_YM = lv_pay_ym))
						  GROUP BY ENTER_CD, SABUN
                    HAVING SUM(PAY_AMT) > 0) A, TBEN005 B, TCPN011 C, TCPN203 F
			 WHERE 1=1
				-- B
			   AND B.ENTER_CD = A.ENTER_CD
			   AND B.PAY_CD   = P_CPN201.PAY_CD
			   AND B.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
				-- C
				 AND C.ENTER_CD   = B.ENTER_CD
			   AND C.ELEMENT_CD = B.ELEMENT_CD
			   AND P_CPN201.PAYMENT_YMD BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
			-- F
				AND A.ENTER_CD = F.ENTER_CD
				AND A.SABUN    = F.SABUN
				AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
			  ) X GROUP BY X.ENTER_CD, X.SABUN
			) A
			;

		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '자녀위탁비(54)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'54-2',P_SQLERRM, P_CHKID);
		END;

  --------------------
  -- 55 : 자가(상해)보험
  --------------------
  WHEN '55' THEN
		/* 55-4
			<TBEN777에 등록인 경우>
			TBEN543 TBEN543 (자가/상해보험 가입납입내역) 해당 급여년월 본인부담금  => 공제항목코드의 공제금액항목에 등록
			TBEN545 (자가/상해보험 보험금지급내역-자가의료비) 급여년월, 과세대상 체크된 대상자의 회사부담금액 합 => 지급 급여항목코드의 금액항목에 등록 */
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요 [예시] 과세(02), 비과세(01)
					     																												  , 공제(02), 지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     --, ln_pay_except_gubun AS PAY_EXCEPT_GUBUN
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , CASE WHEN D.MON2_YN = 'Y' THEN NVL(A.PAY_AMT1,0) -- 공제  D.ELEMENT_CD IN ('D120', 'D115')
						 		 				WHEN D.MON1_YN = 'Y' THEN NVL(A.PAY_AMT2,0) -- 지급 D.ELEMENT_CD IN ('T340')
						 		 	 END AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM (SELECT ENTER_CD, SABUN, PAY_YM, SUM(OWN_AMT) AS PAY_AMT1 , 0 AS PAY_AMT2
											FROM TBEN543
											WHERE 1=1
												AND ENTER_CD = P_ENTER_CD
												AND PAY_YM   = lv_pay_ym
											GROUP BY ENTER_CD, SABUN, PAY_YM
											UNION ALL
											SELECT AA.ENTER_CD, AA.SABUN, AA.PAY_YM, 0 AS PAY_AMT1, SUM(AA.COM_AMT) AS PAY_AMT2
											FROM TBEN545 AA, THRI103 AB
											WHERE 1=1
												AND AA.ENTER_CD = P_ENTER_CD
												AND AA.TAX_YN   = 'Y'
												AND AA.PAY_YM   = lv_pay_ym
											-- AB
											  AND AA.ENTER_CD = AB.ENTER_CD
											  AND AA.APPL_SEQ = AB.APPL_SEQ
											  AND AB.APPL_STATUS_CD = '99'
											GROUP BY AA.ENTER_CD, AA.SABUN, AA.PAY_YM
												) A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 AND A.PAY_YM   = P_CPN201.PAY_YM
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
								AND A.ENTER_CD = F.ENTER_CD
								AND A.SABUN    = F.SABUN
								AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '자가(상해)보험(55)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'55-4',P_SQLERRM, P_CHKID);
		END;

		/* 55-5
			TBEN543 (자가/상해보험 납입내역) 해당 급여년월의 회사지원금 합 => TBEN997에 지급금액, 급여년월 등록
			TBEN545 (자가/상해보험 보험금지급내역) 급여년월, 과세대상 체크된 대상자의 회사부담금액 합 => TBEN997 급여년월의 지급금액에 합산하여 Update)*/
		BEGIN
			INSERT INTO TBEN997
			SELECT B.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, B.SABUN, SUM(B.COM_AMT), A.PAY_YM, '10003', SYSDATE, P_CHKID
			FROM TCPN201 A, (SELECT ENTER_CD, SABUN, PAY_YM, COM_AMT
												 FROM TBEN543
												WHERE 1=1
													AND ENTER_CD = P_ENTER_CD
													AND PAY_YM   = lv_pay_ym
												UNION ALL
												SELECT AA.ENTER_CD, AA.SABUN, AA.PAY_YM, AA.COM_AMT
												FROM TBEN545 AA, THRI103 AB
												WHERE 1=1
													AND AA.ENTER_CD = P_ENTER_CD
													AND AA.TAX_YN   = 'Y'
													AND AA.PAY_YM   = lv_pay_ym
												-- AB
												  AND AA.ENTER_CD = AB.ENTER_CD
												  AND AA.APPL_SEQ = AB.APPL_SEQ
												  AND AB.APPL_STATUS_CD = '99') B
			WHERE 1=1
				AND A.ENTER_CD 			= P_ENTER_CD
			  AND A.PAY_ACTION_CD = P_CPN201.PAY_ACTION_CD
			  -- B
			  AND A.ENTER_CD = B.ENTER_CD
			  AND A.PAY_YM   = B.PAY_YM
			  AND P_CPN201.PAY_CD = 'A1'
			GROUP BY B.ENTER_CD, B.SABUN, A.PAY_YM;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '자가(상해)보험(55)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'55-5',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 56 : 장기근속 여행비
  --------------------
  WHEN '56' THEN
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요 [예시] 과세(02), 비과세(01)
					     																												  , 공제(02), 지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     --, ln_pay_except_gubun AS PAY_EXCEPT_GUBUN
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
									SELECT A.ENTER_CD, A.SABUN
									     , CASE WHEN B.MON2_YN = 'Y' THEN NVL(A.PAY_AMT,0)
										 					WHEN B.MON1_YN = 'Y' THEN NVL(A.PAY_AMT,0) -- 지급 B.ELEMENT_CD IN ('T410')
										 		 END AS PAY_AMT
									 		 , B.MON1_YN, B.MON2_YN, B.MON3_YN, B.MON4_YN,  B.MON5_YN,  B.MON6_YN
									 		 , B.MON7_YN, B.MON8_YN, B.MON9_YN, B.MON10_YN, B.MON11_YN, B.MON12_YN
									 		 , C.ELEMENT_TYPE, C.ELEMENT_CD
									 FROM TBEN562 A, TBEN005 B, TCPN011 C, TCPN203 D
									WHERE A.ENTER_CD = P_ENTER_CD
                                    
										AND A.ENTER_CD <> 'HX'
										AND A.PAY_GB   = '01'
										AND A.PAY_YM   = lv_pay_ym
										AND A.EXP_YN = 'N'
									-- B
									  AND B.ENTER_CD = A.ENTER_CD
									  AND B.PAY_CD   = P_CPN201.PAY_CD
									  AND B.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
									-- C
									  AND C.ENTER_CD   = B.ENTER_CD
									  AND C.ELEMENT_CD = B.ELEMENT_CD
									  AND P_CPN201.PAYMENT_YMD BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
									-- D
										AND A.ENTER_CD = D.ENTER_CD
										AND A.SABUN    = D.SABUN
										AND P_CPN201.PAY_ACTION_CD = D.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
			EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '장기근속(여행비)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'56-1',P_SQLERRM, P_CHKID);
		END;

		BEGIN
			INSERT INTO TBEN997
			SELECT B.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, B.SABUN, SUM(B.PAY_AMT), A.PAY_YM, '10003', SYSDATE, P_CHKID
			FROM TCPN201 A, TBEN562 B
			WHERE 1=1
				AND A.ENTER_CD 			= P_ENTER_CD
			  AND A.PAY_ACTION_CD = P_CPN201.PAY_ACTION_CD
			  -- B
			  AND A.ENTER_CD = B.ENTER_CD
			  AND A.PAY_YM   = B.PAY_YM
			  AND B.PAY_GB   = '01' -- 여행비
			  AND B.EXP_YN = 'N'
				-- 별도추가
				AND A.PAY_YM   = lv_pay_ym
				AND P_CPN201.PAY_CD = 'A1'
			GROUP BY B.ENTER_CD, B.SABUN, A.PAY_YM;
			EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '장기근속(여행비)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'56-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 57 : 장기근속 포상비
  --------------------
  WHEN '57' THEN
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요 [예시] 과세(02), 비과세(01)
					     																												  , 공제(02), 지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     --, ln_pay_except_gubun AS PAY_EXCEPT_GUBUN
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
									SELECT A.ENTER_CD, A.SABUN
									     , CASE WHEN B.MON2_YN = 'Y' THEN NVL(A.PAY_AMT,0)
										 					WHEN B.MON1_YN = 'Y' THEN NVL(A.PAY_AMT,0) -- 지급 B.ELEMENT_CD IN ('T410')
										 		 END AS PAY_AMT
									 		 , B.MON1_YN, B.MON2_YN, B.MON3_YN, B.MON4_YN,  B.MON5_YN,  B.MON6_YN
									 		 , B.MON7_YN, B.MON8_YN, B.MON9_YN, B.MON10_YN, B.MON11_YN, B.MON12_YN
									 		 , C.ELEMENT_TYPE, C.ELEMENT_CD
									 FROM TBEN562 A, TBEN005 B, TCPN011 C, TCPN203 D
									WHERE A.ENTER_CD = P_ENTER_CD
                                    
										AND A.ENTER_CD <> 'HX'
										AND A.PAY_GB   = '02'
										AND A.PAY_YM   = lv_pay_ym
										AND A.EXP_YN = 'N'
									-- B
									  AND B.ENTER_CD = A.ENTER_CD
									  AND B.PAY_CD   = P_CPN201.PAY_CD
									  AND B.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
									-- C
									  AND C.ENTER_CD   = B.ENTER_CD
									  AND C.ELEMENT_CD = B.ELEMENT_CD
									  AND P_CPN201.PAYMENT_YMD BETWEEN C.SDATE AND NVL(C.EDATE,'99991231')
									-- D
										AND A.ENTER_CD = D.ENTER_CD
										AND A.SABUN    = D.SABUN
										AND P_CPN201.PAY_ACTION_CD = D.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
			EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '장기근속(포상비)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'57-1',P_SQLERRM, P_CHKID);
		END;

		BEGIN
			INSERT INTO TBEN997
			SELECT B.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, B.SABUN, SUM(B.PAY_AMT), A.PAY_YM, '10003', SYSDATE, P_CHKID
			FROM TCPN201 A, TBEN562 B
			WHERE 1=1
				AND A.ENTER_CD 			= P_ENTER_CD
			  AND A.PAY_ACTION_CD = P_CPN201.PAY_ACTION_CD
			  -- B
			  AND A.ENTER_CD = B.ENTER_CD
			  AND A.PAY_YM   = B.PAY_YM
			  AND B.PAY_GB   = '02' -- 포상비
			  AND B.EXP_YN = 'N'
				-- 별도추가
				AND A.PAY_YM   = lv_pay_ym
				AND P_CPN201.PAY_CD = 'A1'
			GROUP BY B.ENTER_CD, B.SABUN, A.PAY_YM;
			EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '장기근속(포상비)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'57-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 58 : 개인연금
  --------------------
  WHEN '58' THEN
		/* 58-1
		대상자의 재직상태가 작업기준일 기준 휴직/정직인데 중단년월이 없는 경우 or 중단년월이 있는데 복구년월이 있고 지급상태="지급"인 경우(재 휴직)
		 => 작업기준 년월 1/2이상 근무자는 정상 지급대상.
		 => 작업기준 년월 1/2미만 근무자는 중단년월에 해당 급여년월, 복구년월=null, 지급상태 "중지"로 TBEN652에 Update, TBEN777에 미등록
		*/
		BEGIN
			UPDATE TBEN652 A
			SET A.USE_M_YM = P_CPN201.PAY_YM
				, A.USE_MS_YM = NULL
				, A.PAY_STS = 'S'
				, A.CHKDATE = SYSDATE
				, A.CHKID  = 'BEN_PAY_PRC'
			WHERE (F_BEN_GET_IS_CA_YN(A.ENTER_CD, A.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'Y'-- ,'EA'정직은 따로관리함-- ,'EA'정직은 따로관리함
						 		OR EXISTS( SELECT 1 FROM THRM129 X, TSYS005 Y
														WHERE 1=1
														AND X.ENTER_CD = A.ENTER_CD
														AND X.SABUN    = A.SABUN
														AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN X.SDATE AND X.EDATE
														--
														AND X.ENTER_CD = Y.ENTER_CD
														AND X.PUNISH_CD = Y.CODE
														AND Y.GRCODE_CD = 'H20270'
														AND Y.NOTE1 = 'Y')
								)
					AND ((A.USE_M_YM IS NULL OR A.USE_M_YM = '')
						-- 중단년월이 있는데 복구년월이 있고 지급상태="지급"인 경우(재 휴직)
						OR ((A.USE_M_YM IS NOT NULL AND LENGTH(TRIM(A.USE_M_YM)) = 6) AND (A.USE_MS_YM IS NOT NULL AND LENGTH(TRIM(A.USE_MS_YM)) = 6) AND A.PAY_STS = 'P'))
					AND (F_CPN_WKP_CNT( A.ENTER_CD, A.SABUN
														, TO_CHAR(TRUNC(SYSDATE, 'MONTH'), 'YYYYMMDD') -- 해당월의 첫날
														, TO_CHAR(LAST_DAY(SYSDATE), 'YYYYMMDD'))			-- 해당월의 마지막날
														/ TO_CHAR(LAST_DAY(SYSDATE), 'DD')) < 0.5
				  AND P_CPN201.PAY_CD <> 'A3'
				  -- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
					AND A.PAY_STS <> 'F'
					;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '개인연금(58)_TBEN652 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'58-1',P_SQLERRM, P_CHKID);
		END;

		BEGIN
			/* 58-2
			"대상자의 재직상태가 작업기준일 기준 재직인데 중단년월이 있고, 복구년월이 Null인 경우
			 해당 급여년월을 복구년월, 지급상태 "지급"으로 TBEN652에 Update, TBEN777에 등록
			 중단년월이 있고, 복구년월도 있으며, 지급상태 "지급"인 경우 TBEN777에 등록"
			*/
			UPDATE TBEN652 A
			SET A.USE_MS_YM = P_CPN201.PAY_YM
				, A.PAY_STS = 'P'
				, A.CHKDATE = SYSDATE
				, A.CHKID  = 'BEN_PAY_PRC'
			WHERE EXISTS (
			SELECT 1
				FROM THRM151 C
				WHERE 1=1
					AND A.ENTER_CD = P_ENTER_CD
					-- C
					AND A.ENTER_CD = C.ENTER_CD
					AND A.SABUN    = C.SABUN
					AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN C.SDATE AND C.EDATE
					--대상자의 재직상태가 작업기준일 기준 재직, 중단년월이 있고, 복구년월이 Null인 경우
					AND C.STATUS_CD IN ('AA')
					AND ((A.USE_M_YM IS NOT NULL AND LENGTH(TRIM(A.USE_M_YM)) = 6) AND (A.USE_MS_YM IS NULL OR A.USE_MS_YM = ''))
                    AND F_CPN_WKP_CNT( A.ENTER_CD, A.SABUN, TO_CHAR(TRUNC(SYSDATE, 'MONTH'), 'YYYYMMDD'), TO_CHAR(LAST_DAY(SYSDATE), 'YYYYMMDD')) >= 15			--현재일 기준, 해당월 근무일수 15일 이상(예:휴직->복직 CASE), 2025.06.23
					AND P_CPN201.PAY_CD <> 'A3'
          -- 징계대상 제외 2025.04.15 <= 2025.06.23 작업으로 징계대상 체크 불요,징계 기간은 근무일수에서 제외 됨.
          /*AND A.SABUN NOT IN (
            SELECT SABUN FROM THRM129 
            WHERE 1=1
            AND ENTER_CD = A.ENTER_CD
            AND PUNISH_CD IN ('rRI_010','rRI_011','rRI_012','rRI_013') --징계코드(H20270)
            AND lv_pay_ym BETWEEN SUBSTR(SDATE,1,6) AND SUBSTR(EDATE,1,6)
            AND (TO_NUMBER(SUBSTR(SDATE, 7,2)) >= 15 OR TO_NUMBER(SUBSTR(EDATE,7,2)) < 15)
          )*/
			)
				  -- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
					AND A.PAY_STS <> 'F'
			;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '개인연금(58)_TBEN652 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'58-2',P_SQLERRM, P_CHKID);
		END;

		BEGIN
			/* 58-3
					"대상자의 재직상태가 작업기준일 기준 퇴직인데 종료년월이 Null인 경우
					종료년월에 해당 급여년월, 지급상태 "종료"로 TBEN652에 Update, TBEN777에 등록
					종료년월이 있고, 지급상태="종료"이면 Skip
					(단, 종료년월 =퇴사일자가 당월15일이후 인 경우는 당월 지원대상, 익월로 세팅하고 TBEN777에 등록, 1~14일까지는 당월로 세팅 후 TBEN777에 미등록 )"
			*/
			UPDATE TBEN652 A
			SET A.USE_E_YM = CASE WHEN SUBSTR(F_COM_GET_RET_YMD(A.ENTER_CD, A.SABUN),0,6) = P_CPN201.PAY_YM
															AND SUBSTR(F_COM_GET_RET_YMD(A.ENTER_CD, A.SABUN),7,2) > 15
											 THEN TO_CHAR(ADD_MONTHS(TO_DATE(P_CPN201.PAY_YM, 'YYYYMM'), 1), 'YYYYMM')
										   ELSE P_CPN201.PAY_YM END
				, A.PAY_STS = 'F'
				, A.CHKDATE = SYSDATE
				, A.CHKID  = 'BEN_PAY_PRC'
			WHERE EXISTS (
			SELECT 1
				FROM THRM151 C
				WHERE 1=1
					-- A
					AND A.ENTER_CD = P_ENTER_CD
					-- C
					AND A.ENTER_CD = C.ENTER_CD
					AND A.SABUN    = C.SABUN
					AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN C.SDATE AND C.EDATE
					-- 대상자의 재직상태가 작업기준일 기준 퇴직인데 종료년월이 Null인 경우
					AND C.STATUS_CD IN ('RA')
					AND (A.USE_E_YM IS NULL OR A.USE_E_YM <> '')
					AND P_CPN201.PAY_CD  <> 'A3'
			)
		-- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
		AND A.PAY_STS <> 'F'
			;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '개인연금(58)_TBEN652 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'58-3',P_SQLERRM, P_CHKID);
		END;

		/* 58-4-1
			대상 급여년월이 TBEN652 (개인연금대상자) 시작년월~종료년월 사이에 해당되고 지급상태="지급"인 대상자의
			지원금액 합 => 지급 급여항목코드의 금액항목에 등록,
         공제금액 합 => 공제항목코드의 공제금액항목에 등록
		*/
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요 [예시] 과세, 비과세 등*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5,  0 AS MON6,  0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , CASE WHEN D.MON1_YN = 'Y' THEN NVL(A.COMP_MON,0) -- 지급 D.ELEMENT_CD IN ('T305', 'T310')
						 		 				WHEN D.MON2_YN = 'Y' THEN NVL(A.DED_AMT,0)  -- 공제 D.ELEMENT_CD IN ('D115', 'D110')
						 		 	 END AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN652 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 AND A.USE_S_YM <= lv_pay_ym
							 AND lv_pay_ym < NVL(A.USE_E_YM, '999912')
							 AND A.PAY_STS = 'P'
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
								AND A.ENTER_CD = F.ENTER_CD
								AND A.SABUN    = F.SABUN
								AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A
			;

		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '개인연금(58)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'58-4-1',P_SQLERRM, P_CHKID);
		END;

		/* 58-4-2
			대상 급여년월이 TBEN652 (개인연금대상자) 시작년월~종료년월 사이에 해당되는 대상자의 지원금액 합 => TBEN997에 지급금액, 급여년월 등록
		*/
		BEGIN
			INSERT INTO TBEN997
			SELECT B.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, B.SABUN, SUM(B.COMP_MON), A.PAY_YM, '10003', SYSDATE, P_CHKID
			FROM TCPN201 A, TBEN652 B
			WHERE 1=1
				AND A.ENTER_CD 			= P_ENTER_CD
			  AND A.PAY_ACTION_CD = P_CPN201.PAY_ACTION_CD
			  -- B
			  AND A.ENTER_CD = B.ENTER_CD
			  --AND A.PAY_YM   BETWEEN B.USE_S_YM AND NVL(B.USE_E_YM, '999912')
				AND B.USE_S_YM <= lv_pay_ym
				AND lv_pay_ym < NVL(B.USE_E_YM, '999912')
			  AND B.PAY_STS = 'P'
			  AND P_CPN201.PAY_CD = 'A1'
			GROUP BY B.ENTER_CD, B.SABUN, A.PAY_YM;

		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '개인연금(58)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'58-4-2',P_SQLERRM, P_CHKID);
		END;

		/* 58-5 : TBEN653에 해당 급여년월로 지급, 공제내역 데이터 저장 (insert or update) */
		BEGIN
			INSERT INTO TBEN653
			SELECT A.ENTER_CD, A.SABUN, P_CPN201.PAY_YM, SUM(A.COMP_MON), SUM(A.DED_AMT), SUM(A.TAX_AMT), SYSDATE, P_CHKID, MAX(A.INS_PAY_AMT), '', MAX(A.PSNL_MON)
				FROM TBEN652 A, TCPN203 F
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND A.USE_S_YM <= P_CPN201.PAY_YM
				 AND P_CPN201.PAY_YM < NVL(A.USE_E_YM, '999912')
				 AND A.PAY_STS = 'P'
				 AND P_CPN201.PAY_CD <> 'A3'
				-- F
				 AND A.ENTER_CD = F.ENTER_CD
				 AND A.SABUN    = F.SABUN
				 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
			GROUP BY A.ENTER_CD, A.SABUN; -- 굳이 그룹핑 할 필요는 없는거 같은데 혹시 모르니 유지
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '개인연금(58)_TBEN653 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'58-5',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 59 : 생수
  --------------------
  WHEN '59' THEN
		/* 59-1
			TBEN591 (생수대상자) 대상년월의 대상자의 지원금액 => 지급 급여항목코드의 금액항목에 등록
			TBEN592 (생수인수내역) 급여년월=택배발송년월, 대상자의 택배비 합계 => 공제항목코드의 공제금액항목에 등록 (임원 제외 - 임원은 택배비 회사지원)
		*/
		BEGIN
	IF P_ENTER_CD = 'KS' THEN
			INSERT INTO TBEN777
				SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
				     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
				     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
				FROM(SELECT X.ENTER_CD
						 		 , P_CPN201.PAY_ACTION_CD
						 		 , X.SABUN
						 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
						     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
						     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
						     , P_CPN201.PAYMENT_YMD AS PAY_YMD
						     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
						     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
						     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
											[예시] 과세(02),  비과세(01)
											  	  공제(02),  지급(01)*/
						     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
						     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
						     , '' AS PAY_MEMO
						     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
						     , '' AS MEMO
						     , SYSDATE AS CHKDATE
						     , P_CHKID AS CHKID
						FROM (
							SELECT A.ENTER_CD, A.SABUN
							 		 , CASE WHEN D.MON1_YN = 'Y' THEN NVL(A.PAY_AMT1,0) -- 지급
							 		 				WHEN D.MON2_YN = 'Y' THEN NVL(A.PAY_AMT2,0) -- 공제
							 		 	 END AS PAY_AMT
									 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
									 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
									 , E.ELEMENT_TYPE, E.ELEMENT_CD
								/* 대상자 테으블은 과세금액, 택배내역은 공제금액 때문에 Union */
								FROM (SELECT A.ENTER_CD, A.SABUN
													 , A.USE_AMT AS PAY_AMT1
													 , 0 AS PAY_AMT2, lv_pay_ym AS PAY_YM --- A.BAS_YM AS PAY_YM
												FROM TBEN591 A
											 WHERE 1=1
											 	 AND A.ENTER_CD = P_ENTER_CD
											 	 AND A.BAS_YM = lv_pay_ym
											UNION ALL
												SELECT
												 A.ENTER_CD, A.SABUN
												 , 0 AS PAY_AMT1
												 , SUM(A.DELI_AMT) AS PAY_AMT2
 												 , lv_pay_ym AS PAY_YM
												FROM TBEN594 A, THRI103 B
												WHERE 1=1
													AND A.ENTER_CD = P_ENTER_CD
																AND ((A.RECV_GB   = 'L' 			-- 장기건
																			AND (
																						(A.USE_SDATE <= TO_CHAR( ADD_MONTHS(TO_DATE(lv_pay_ym,'YYYYMM'), 1),'YYYYMM')
																						AND TO_CHAR( ADD_MONTHS(TO_DATE(lv_pay_ym,'YYYYMM'), 1),'YYYYMM') < NVL(A.USE_EDATE,'29991231'))
																					)
																			)
																-- 단기
																	OR (A.RECV_GB = 'S' AND A.USE_SDATE = TO_CHAR( ADD_MONTHS(TO_DATE(lv_pay_ym,'YYYYMM'), 1),'YYYYMM'))
																)
													-- B
													AND A.ENTER_CD = B.ENTER_CD
													AND A.APPL_SEQ = B.APPL_SEQ
													AND B.APPL_STATUS_CD = '99'
												 AND NOT EXISTS (SELECT 1
																				  FROM TSYS006 AA
																				 WHERE 1=1
																				   AND AA.ENTER_CD = A.ENTER_CD
																				   AND AA.GUBUN ='B01'
																				   AND AA.CODE_VAL IN( '01','05') -- 임원제외
																				   AND AA.CODE = F_COM_GET_JIKGUB_CD (A.ENTER_CD, A.SABUN, P_CPN201.PAYMENT_YMD)
																				   AND P_CPN201.PAYMENT_YMD BETWEEN AA.SDATE AND NVL(AA.EDATE,'99991231')
																				   )													
												GROUP BY A.ENTER_CD, A.SABUN
								) A, TBEN005 D, TCPN011 E, TCPN203 F
							 WHERE 1=1
								 AND A.ENTER_CD = P_ENTER_CD
								 AND A.PAY_YM   = lv_pay_ym
								-- D
							   AND D.ENTER_CD = A.ENTER_CD
							   AND D.PAY_CD   = P_CPN201.PAY_CD
							   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
								-- E
								 AND E.ENTER_CD   = D.ENTER_CD
							   AND E.ELEMENT_CD = D.ELEMENT_CD
							   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
								-- F
									AND A.ENTER_CD = F.ENTER_CD
									AND A.SABUN    = F.SABUN
									AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
						) X
					GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
				) A;
			ELSE
				INSERT INTO TBEN777
				SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
				     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
				     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
				FROM(SELECT X.ENTER_CD
						 		 , P_CPN201.PAY_ACTION_CD
						 		 , X.SABUN
						 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
						     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
						     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
						     , P_CPN201.PAYMENT_YMD AS PAY_YMD
						     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
						     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
						     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
											[예시] 과세(02),  비과세(01)
											  	  공제(02),  지급(01)*/
						     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
						     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
						     , '' AS PAY_MEMO
						     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
						     , '' AS MEMO
						     , SYSDATE AS CHKDATE
						     , P_CHKID AS CHKID
						FROM (
							SELECT A.ENTER_CD, A.SABUN
							 		 , CASE WHEN D.MON1_YN = 'Y' THEN NVL(A.PAY_AMT1,0) -- 지급
							 		 				WHEN D.MON2_YN = 'Y' THEN NVL(A.PAY_AMT2,0) -- 공제
							 		 	 END AS PAY_AMT
									 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
									 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
									 , E.ELEMENT_TYPE, E.ELEMENT_CD
								/* 대상자 테으블은 과세금액, 택배내역은 공제금액 때문에 Union */
								FROM (SELECT A.ENTER_CD, A.SABUN
													 , A.USE_AMT
													/* + NVL((SELECT SUM(B.DELI_AMT)
																		FROM TBEN592 B
																	 WHERE 1=1
																		 AND B.ENTER_CD = P_ENTER_CD
																		 AND B.SABUN = A.SABUN
																		 AND B.DELI_YM  = lv_pay_ym
																		 AND EXISTS (SELECT 1
																								   FROM TSYS006 AA
																									WHERE 1=1
																									  AND AA.ENTER_CD IN( 'HX','HG')
																								    AND AA.ENTER_CD = B.ENTER_CD
																								    AND AA.GUBUN ='B01'
																								    AND AA.CODE_VAL = '01' -- 한진칼, 임원만 지원금 과제금액에 택배비 얹어달라고요청, 2023.12.06 이거랑 캡쳐해서 전달 드리면 될듯요 
																								    AND AA.CODE = F_COM_GET_JIKGUB_CD (B.ENTER_CD, B.SABUN, P_CPN201.PAYMENT_YMD)
																								    AND P_CPN201.PAYMENT_YMD BETWEEN AA.SDATE AND NVL(AA.EDATE,'99991231'))
																		GROUP BY B.ENTER_CD, B.SABUN
																	),0)*/  AS PAY_AMT1
													 , 0 AS PAY_AMT2, lv_pay_ym AS PAY_YM --- A.BAS_YM AS PAY_YM
												FROM TBEN591 A
											 WHERE 1=1
											 	 AND A.ENTER_CD = P_ENTER_CD
											 	 AND A.BAS_YM = lv_pay_ym
											UNION ALL
											SELECT B.ENTER_CD, B.SABUN, 0 AS PAY_AMT1, SUM(B.DELI_AMT) AS PAY_AMT2, lv_pay_ym AS PAY_YM
												FROM TBEN592 B
											 WHERE 1=1
												 AND B.ENTER_CD = P_ENTER_CD
												 AND B.DELI_YM  = lv_pay_ym
												 AND NOT EXISTS (SELECT 1
																				  FROM TSYS006 AA
																				 WHERE 1=1
																				   AND AA.ENTER_CD = B.ENTER_CD
																				   AND AA.GUBUN ='B01'
																				   AND AA.CODE_VAL IN( '01','05') -- 임원제외
																				   AND AA.ENTER_CD NOT IN ('HT','TP') -- 한진관광은 임원 포함 20250618 TP 포함
																				   AND AA.CODE = F_COM_GET_JIKGUB_CD (B.ENTER_CD, B.SABUN, P_CPN201.PAYMENT_YMD)
																				   AND P_CPN201.PAYMENT_YMD BETWEEN AA.SDATE AND NVL(AA.EDATE,'99991231')
																				   )
											GROUP BY B.ENTER_CD, B.SABUN
								) A, TBEN005 D, TCPN011 E, TCPN203 F
							 WHERE 1=1
								 AND A.ENTER_CD = P_ENTER_CD
								 AND A.PAY_YM   = lv_pay_ym
								-- D
							   AND D.ENTER_CD = A.ENTER_CD
							   AND D.PAY_CD   = P_CPN201.PAY_CD
							   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
								-- E
								 AND E.ENTER_CD   = D.ENTER_CD
							   AND E.ELEMENT_CD = D.ELEMENT_CD
							   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
								-- F
									AND A.ENTER_CD = F.ENTER_CD
									AND A.SABUN    = F.SABUN
									AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
						) X
					GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
				) A;
			END IF;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '생수(59)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'59-1',P_SQLERRM, P_CHKID);
		END;

		/* 59-2
			TBEN592 (생수인수내역) 사용년월, 대상자의 지원금액 합계 => TBEN997에 지급금액, 급여년월 등록
			임원 제외
		*/
		BEGIN
			IF P_ENTER_CD = 'KS' THEN
					INSERT INTO TBEN997
						SELECT *
						FROM
						(SELECT
							ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, SABUN
							,SUM(PAY_AMT1) +
																	(CASE WHEN  EXISTS(SELECT 1
																									   FROM TSYS006 AA
																									  WHERE 1=1
																									    AND AA.ENTER_CD = ENTER_CD
																									    AND AA.GUBUN ='B01'
																									    AND AA.CODE_VAL = '01' -- 임원제외
																									    AND AA.CODE = F_COM_GET_JIKGUB_CD(ENTER_CD, SABUN, P_CPN201.PAYMENT_YMD)
																									    AND P_CPN201.PAYMENT_YMD
																									    		BETWEEN AA.SDATE AND NVL(AA.EDATE,'99991231'))
																			THEN F_BEN_WATER_MON(enter_cd, sabun, P_CPN201.PAY_YM)
																			ELSE 0 END
																	)	 AS MON
							, P_CPN201.PAY_YM
							, '10003'
							, SYSDATE
							, P_CHKID
						FROM
							(SELECT
							 A.ENTER_CD, A.SABUN
							 , (SUM(USE_LT_CNT) * MAX(D.BOX_AMT)) AS PAY_AMT1
							FROM TBEN594 A, THRI103 B, TBEN595 C, TBEN590 D
							WHERE 1=1
								AND A.ENTER_CD = P_ENTER_CD
											AND ((A.RECV_GB   = 'L' 			-- 장기건
														AND (
																	(A.USE_SDATE <= TO_CHAR( ADD_MONTHS(TO_DATE(lv_pay_ym,'YYYYMM'), 1),'YYYYMM')
																	AND TO_CHAR( ADD_MONTHS(TO_DATE(lv_pay_ym,'YYYYMM'), 1),'YYYYMM') < NVL(A.USE_EDATE,'29991231'))
																)
														)
											-- 단기
												OR (A.RECV_GB = 'S' AND A.USE_SDATE = TO_CHAR( ADD_MONTHS(TO_DATE(lv_pay_ym,'YYYYMM'), 1),'YYYYMM'))
											)
								-- B
								AND A.ENTER_CD = B.ENTER_CD
								AND A.APPL_SEQ = B.APPL_SEQ
								AND B.APPL_STATUS_CD = '99'
								-- C
								AND A.ENTER_CD = C.ENTER_CD
								AND A.APPL_SEQ = C.APPL_SEQ
								AND A.SABUN    = C.SABUN
								-- D
								AND C.ENTER_CD = D.ENTER_CD
								AND C.USE_LT_CD = D.LT_CD
								AND D.GB_CD = '02'
								AND B.APPL_YMD  BETWEEN D.USE_SDATE AND D.USE_EDATE
								AND P_CPN201.PAY_CD = 'A1'
							GROUP BY A.ENTER_CD, A.SABUN, C.USE_LT_CD
							)	GROUP BY ENTER_CD, SABUN
						)	WHERE MON <> 0			;
			ELSE
				INSERT INTO TBEN997
				SELECT * FROM
				(SELECT A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN
							, SUM(NVL(A.USE_AMT,0))
							 + SUM(CASE WHEN EXISTS(SELECT 1
															   FROM TSYS006 AA
															  WHERE 1=1
															    AND AA.ENTER_CD = A.ENTER_CD
															    AND AA.GUBUN ='B01'
															    AND AA.CODE_VAL = '01' -- 임원제외
															    AND AA.ENTER_CD != 'HT' -- 한진관광은 임원 포함
															    AND AA.CODE = F_COM_GET_JIKGUB_CD(A.ENTER_CD, A.SABUN, P_CPN201.PAYMENT_YMD)
															    AND P_CPN201.PAYMENT_YMD
															    		BETWEEN AA.SDATE AND NVL(AA.EDATE,'99991231')) THEN A.DELI_AMT ELSE 0 END)
							AS MON
							, P_CPN201.PAY_YM
							, '10003'
							, SYSDATE
							, P_CHKID
					FROM TBEN592 A
				 WHERE 1=1
					 AND A.ENTER_CD = P_ENTER_CD
					 AND A.DELI_YM	 = lv_pay_ym
					 AND P_CPN201.PAY_CD = 'A1'
				GROUP BY A.ENTER_CD, A.SABUN)
				WHERE MON <> 0
				;
			END IF;

		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '생수(59)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'59-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 62 : 인천교통비
  --------------------
  WHEN '62' THEN
		/*62-1 :	BEN821(인천교통비내역) 급여년월=대상년월, 대상자의 과세금액 => 지급 급여항목코드의 금액항목에 등록 */
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01) ||공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , A.PAY_AMT AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN821 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 -- AND A.ENTER_CD = 'KS' -- 교통비(인천) : 항국공항만 항목넣으면 되기 때문에 필요없음
							 AND A.PAY_YM   = lv_pay_ym
							 AND A.PAY_YN  = 'Y'
							 AND (A.PAY_AMT IS NOT NULL AND A.PAY_AMT <> 0)
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
							 AND A.ENTER_CD = F.ENTER_CD
							 AND A.SABUN    = F.SABUN
							 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A
			;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '인천교통비(62)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'62-1',P_SQLERRM, P_CHKID);
		END;

		/* 62-2
			TBEN821(인천교통비내역) 급여년월=대상년월, 대상자의 과세금액 =>  TBEN997에 지급금액, 급여년월 등록
		*/
		BEGIN
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PAY_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN821 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 -- AND A.ENTER_CD = 'KS' -- 교통비(인천) : 항국공항만 항목넣으면 되기 때문에 필요없음
				 AND A.PAY_YM	 = lv_pay_ym
				 AND A.PAY_YN  = 'Y'
				 AND (A.PAY_AMT IS NOT NULL AND A.PAY_AMT <> 0)
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '교통비(63)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'63-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 63 : 교통비
  --------------------
  WHEN '63' THEN
		/*63-1 : TBEN812(교통비 신청/승인) 급여년월=대상년월, 대상자의 지급금액 => 지급 급여항목코드의 금액항목에 등록 */
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01) ||공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , A.PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN812 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 --AND A.ENTER_CD = 'KS' 교통비 : 항국공항만  : 항국공항만 항목넣으면 되기 때문에 필요없음
							 AND A.PAY_YM   = lv_pay_ym
							 AND (A.PAY_AMT IS NOT NULL AND A.PAY_AMT <> 0)
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
							 AND A.ENTER_CD = F.ENTER_CD
							 AND A.SABUN    = F.SABUN
							 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A
			;

		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '교통비(63)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'63-1',P_SQLERRM, P_CHKID);
		END;

		/* 63-2
			TBEN812(교통비 신청/승인) 급여년월=대상년월, 대상자의 지급금액 => TBEN997에 지급금액, 급여년월 등록
		*/
		BEGIN
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PAY_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN812 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND A.PAY_YM	 = lv_pay_ym
				 AND (A.PAY_AMT IS NOT NULL AND A.PAY_AMT <> 0)
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '교통비(63)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'63-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 65 : 지급품
  --------------------
  WHEN '65' THEN
		/* 65-1 : TBEN834(지급품신청/승인) 급여년월= 대상년월 , 지급금액 합 = TBEN997에 지급금액, 급여년월 등록*/
		-- 지급품 테이블이 변경되었는데 업무 파악 후 수정 필요
		BEGIN
		INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PROV_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN834 A, THRI103 B
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND SUBSTR(A.PROV_YMD,1,6)	= lv_pay_ym
				 -- B
				 AND A.ENTER_CD = B.ENTER_CD
				 AND A.APPL_SEQ = B.APPL_SEQ
				 AND B.APPL_STATUS_CD = '99'
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;

		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '지급품(65)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'65-1',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 66 : 취미반
  --------------------
	WHEN '66' THEN
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01) ||공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , B.CLUB_FEE AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN501 A, TBEN500 B, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 AND lv_pay_ym BETWEEN SUBSTR(A.SDATE,1,6) AND NVL(SUBSTR(A.EDATE,1,6),'999912')
							 AND A.ENTER_CD = 'KS' -- 한국공항만
                             AND (A.CLUB_SEQ, A.SDATE) NOT IN ( --2024.04.29 추가: 탈퇴한 취미반 금액이 들어가던 오류 수정
                                 SELECT AA.CLUB_SEQ, AA.SDATE FROM TBEN501 AA
                                                 WHERE AA.ENTER_CD = A.ENTER_CD
                                                 AND AA.SABUN = A.SABUN
                                                 AND AA.JOIN_TYPE = 'D'
                             )
							 -- B
							 AND A.ENTER_CD = B.ENTER_CD
							 AND A.CLUB_SEQ = B.CLUB_SEQ
							 --AND A.SDATE BETWEEN B.SDATE AND NVL(B.EDATE,'999912')
                             --20240313 종료일 수정
                             AND (A.SDATE BETWEEN B.SDATE AND NVL(B.EDATE,'99991231')
                               OR NVL(A.EDATE, '99991231') BETWEEN B.SDATE AND NVL(B.EDATE,'99991231'))
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
							 AND A.ENTER_CD = F.ENTER_CD
							 AND A.SABUN    = F.SABUN
							 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
               -- 사직자 제외 처리 25.04.15
               AND A.SABUN NOT IN (SELECT SABUN FROM THRM100 WHERE ENTER_CD=A.ENTER_CD AND RET_YMD IS NOT NULL)
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A
			;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '취미반(66)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'66-1',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 67 : 결혼여행보조금
  --------------------
  WHEN '67' THEN
		/* 67-1 : 현재 비과세처리 (기준 - 지급월 익월 과세)
			TBEN571의 급여년월=대상년월, 대상자의 과세여부=Y인 지급금액 =>  지급 급여항목코드의 금액항목에 등록*/
		BEGIN
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PAY_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN571 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND SUBSTR(A.PAY_YMD,0,6) = lv_pay_ym
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '지급품(67)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'67-1',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 68 : 주택이자보조금
  --------------------
  WHEN '68' THEN
		/* 68-1 : 대상자의 재직상태가 작업기준일 기준 휴직/정직인데 중단년월이 없는 경우 or 중단년월이 있는데 복구년월이 있고 지급상태="지급"인 경우(재 휴직)
				 => 중단년월에 해당 급여년월, 복구년월=null, 지급상태 "중지"로 TBEN452에 Update, TBEN777에 미등록 */
		BEGIN
			UPDATE TBEN452 A
			   SET A.USE_M_YM  = P_CPN201.PAY_YM
			   	 , A.USE_MS_YM = NULL
			   	 , A.PAY_STS = 'S'
			   	 , A.CHKDATE = SYSDATE
			   	 , A.CHKID  = 'BEN_PAY_PRC'
			   	WHERE (F_BEN_GET_IS_CA_YN(A.ENTER_CD, A.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'Y'-- ,'EA'정직은 따로관리함 -- ,'EA'정직은 따로관리함
						 		OR EXISTS( SELECT 1 FROM THRM129 X, TSYS005 Y
														WHERE 1=1
														AND X.ENTER_CD = A.ENTER_CD
														AND X.SABUN    = A.SABUN
														AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN X.SDATE AND X.EDATE
														--
														AND X.ENTER_CD = Y.ENTER_CD
														AND X.PUNISH_CD = Y.CODE
														AND Y.GRCODE_CD = 'H20270'
														AND Y.NOTE1 = 'Y')
								)
							 -- 중단년월이 없는 경우 or 중단년월이 있는데 복구년월이 있고 지급상태="지급"인 경우(재 휴직)
							 AND ((A.USE_M_YM IS NULL OR A.USE_M_YM = '')
								OR ((A.USE_M_YM IS NOT NULL AND LENGTH(TRIM(A.USE_M_YM)) = 6) AND (A.USE_MS_YM IS NOT NULL AND LENGTH(TRIM(A.USE_MS_YM)) = 6) AND A.PAY_STS = 'P'))
							AND P_CPN201.PAY_CD <> 'A3'
							-- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
							AND A.PAY_STS <> 'F'
					;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '주택이자보조금(68)_TBEN452 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'68-1',P_SQLERRM, P_CHKID);
		END;

		/* 68-2
			대상자의 재직상태가 작업기준일 기준 재직인데 중단년월이 있고, 복구년월이 Null인 경우
				=> 해당 급여년월을 복구년월, 지급상태 "지급"으로 TBEN452에 Update, TBEN777에 등록
         중단년월이 있고, 복구년월도 있으며, 지급상태 "지급"인
         	=> 경우 TBEN777에 등록 */
		BEGIN
			UPDATE TBEN452 A
			   SET A.USE_MS_YM = P_CPN201.PAY_YM
			   	 , A.PAY_STS = 'P'
			   	 , A.CHKDATE = SYSDATE
			   	 , A.CHKID  = 'BEN_PAY_PRC'
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
						 AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN C.SDATE AND C.EDATE
						 -- 대상자의 재직상태가 작업기준일 기준 재직인데 중단년월이 있고,
						 AND C.STATUS_CD = 'AA'
						 -- 복구년월이 Null인 경우
						 AND (((A.USE_M_YM IS NOT NULL AND LENGTH(TRIM(A.USE_M_YM)) = 6) AND (A.USE_MS_YM IS NULL OR A.USE_MS_YM = ''))
						  OR ((A.USE_M_YM IS NOT NULL AND LENGTH(TRIM(A.USE_M_YM)) = 6) AND (A.USE_MS_YM IS NOT NULL AND LENGTH(TRIM(A.USE_MS_YM)) = 6) AND A.PAY_STS = 'P'))
						  AND P_CPN201.PAY_CD <> 'A3'
					)
					-- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
					AND A.PAY_STS <> 'F'
					;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '주택보조비(68)_TBEN452 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'68-2',P_SQLERRM, P_CHKID);
		END;

		/* 68-3
			대상자의 재직상태가 작업기준일 기준 퇴직인데 종료년월이 Null인 경우
			종료년월에 해당 급여년월, 지급상태 "종료"로 TBEN452에 Update, TBEN777에 등록
         지급상태="종료"이면 Skip*/
		BEGIN
			UPDATE TBEN452 A
			SET A.USE_E_YM = P_CPN201.PAY_YM
				 , A.PAY_STS = 'F'
				 , A.CHKDATE = SYSDATE
				 , A.CHKID  = 'BEN_PAY_PRC'
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
					 AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN C.SDATE AND C.EDATE
					 AND C.STATUS_CD = 'RA'
					 AND ((A.USE_E_YM IS NULL OR A.USE_E_YM = ''))
					 AND P_CPN201.PAY_CD <> 'A3'
			 );
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '주택이자보조금(68)_TBEN452 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'68-3',P_SQLERRM, P_CHKID);
		END;

		/* 68-4
			TBEN452(주택자금이자보조비 신청/승인)의 시작년월~종료년월 사이에 해당되고 지급상태="지급"인  대상자의 TBEN452 PK값으로 TBEN453의 최종데이터를 찾고
			최종회차데이터 정보로 지급회차=최종회차+1, 근속기준,대출구분코드,대상금액, 지급년월=금번 급여지급년월,
			지급금액=TBEN451에서 근속기준년수,대출구분코드, 시작일자가 현재일자보다 작고 Max인 데이터의 회차=금번 지급회차인 데이터의 이자보조금으로 TBEN453에 등록(Insert, Update) */
		BEGIN
			INSERT INTO TBEN453 T
			SELECT A1.ENTER_CD, A1.APPL_SEQ, A1.SABUN, A1.PAY_SEQ + 1 AS PAY_SEQ
					 , A1.BAS_YY, A1.LOAN_GB, A1.BAS_AMT, P_CPN201.PAY_YM AS PAY_YM, A3.INT_AMT AS PAY_AMT
					 , SYSDATE AS CHKDATE, P_CHKID AS CHKID
			FROM TBEN453 A1, TBEN450 A2, TBEN451 A3, TCPN203 F
			WHERE 1=1
				AND A1.ENTER_CD = P_ENTER_CD
			  AND A1.APPL_SEQ IN (SELECT A.APPL_SEQ
														 FROM TBEN452 A,THRI103 B
														WHERE 1=1
															AND A.ENTER_CD = P_ENTER_CD
															AND P_CPN201.PAY_YM BETWEEN A.USE_S_YM AND NVL(A.USE_E_YM,'999912')
															AND A.PAY_STS = 'P'
															-- B
															AND A.ENTER_CD = B.ENTER_CD
															AND A.APPL_SEQ = B.APPL_SEQ
															AND B.APPL_STATUS_CD = '99'
															-- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
															AND A.PAY_STS <> 'F'
															)
				AND A1.PAY_SEQ  = (SELECT MAX(B1.PAY_SEQ)
														 FROM TBEN453 B1
														WHERE A1.ENTER_CD = B1.ENTER_CD
														  AND A1.APPL_SEQ = B1.APPL_SEQ
														  AND A1.SABUN = B1.SABUN)
				-- A2
				AND A1.ENTER_CD = A2.ENTER_CD
				AND A1.BAS_YY   = A2.BAS_YY
				AND A1.LOAN_GB  = A2.LOAN_GB
				AND P_CPN201.PAYMENT_YMD BETWEEN A2.USE_S_YMD AND A2.USE_E_YMD
				-- A3
				AND A2.ENTER_CD = A3.ENTER_CD
				AND A2.LOAN_GB  = A3.LOAN_GB
				AND A3.BAS_SEQ  = (A1.PAY_SEQ + 1)
				AND A2.USE_S_YMD = A3.USE_S_YMD
				AND P_CPN201.PAY_CD <> 'A3'
			  -- F
				AND A1.ENTER_CD = F.ENTER_CD
				AND A1.SABUN    = F.SABUN
				AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD

				;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '주택이자보조금(68)_TBEN453 INSERT 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'68-4',P_SQLERRM, P_CHKID);
		END;
        
        /*이자보조신청 후 최초등록시 2024.06.19 추가*/
        BEGIN
            INSERT INTO TBEN453 T
                SELECT A1.ENTER_CD, A1.APPL_SEQ, A1.SABUN, 1 AS PAY_SEQ, A1.BAS_YY, A1.LOAN_GB, A2.BAS_AMT, P_CPN201.PAY_YM AS PAY_YM, A3.INT_AMT AS PAY_AMT
                    , SYSDATE AS CHKDATE, P_CHKID AS CHKID
                   FROM TBEN452 A1, TBEN450 A2, TBEN451 A3, TCPN203 F
                WHERE 1=1
                 AND A1.ENTER_CD = P_ENTER_CD
                 AND A1.APPL_SEQ IN (SELECT A.APPL_SEQ
                                         FROM TBEN452 A,THRI103 B
                                        WHERE 1=1
                                            AND A.ENTER_CD = P_ENTER_CD
                                            AND P_CPN201.PAY_YM BETWEEN A.USE_S_YM AND NVL(A.USE_E_YM,'999912')
                                            AND A.PAY_STS = 'P'
                                            -- B
                                            AND A.ENTER_CD = B.ENTER_CD
                                            AND A.APPL_SEQ = B.APPL_SEQ
                                            AND A.USE_S_YM = P_CPN201.PAY_YM
                                            AND B.APPL_STATUS_CD = '99'
                                            -- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
                                            AND A.PAY_STS <> 'F'
                                            )
                AND A1.ENTER_CD = A2.ENTER_CD
                AND A1.BAS_YY = A2.BAS_YY
                AND A1.LOAN_GB = A2.LOAN_GB
                AND A1.ENTER_CD = A3.ENTER_CD
                AND A1.LOAN_GB = A3.LOAN_GB
                AND A3.BAS_SEQ = 1
                AND A1.ENTER_CD = F.ENTER_CD
                AND A1.SABUN    = F.SABUN
                AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
                AND P_CPN201.PAY_CD <> 'A3'
                ;
        EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '주택이자보조금(68)_TBEN777 INSERT 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'68-5',P_SQLERRM, P_CHKID);
		END;

		/*68-5 : 해당 이자보조금을 TBEN777에 금번 급여년월, 지급 급여항목코드의 금액항목에 등록
			<작업취소> TBEN453의 지급년월=금번 급여지급년월인 데이터 삭제*/
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01)||공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , A.PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN453 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 AND A.PAY_YM = lv_pay_ym
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
						  -- F
							 AND A.ENTER_CD = F.ENTER_CD
							 AND A.SABUN    = F.SABUN
							 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '주택이자보조금(68)_TBEN777 INSERT 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'68-5',P_SQLERRM, P_CHKID);
		END;

		/*68-6 : 해당 이자보조금을 TBEN997에 금번 급여년월=급여년월, 지급금액 등록*/
		BEGIN
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PAY_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN453 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND A.PAY_YM = lv_pay_ym
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '주택이자보조금(68)_TBEN997 INSERT 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'68-6',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 69 : 파견보조비
  --------------------
  WHEN '69' THEN
		/* 69-1 : TBEN461(파견보조비 대상자)의 급여년월=대상년월, 대상자의 과세여부 "Y"인 지급금액 => 지급 급여항목코드의 금액항목에 등록*/
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01)||공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , A.PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN462 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 AND A.PAY_YM = lv_pay_ym
							 AND A.TAX_YN = 'Y'
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
							 AND A.ENTER_CD = F.ENTER_CD
							 AND A.SABUN    = F.SABUN
							 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A
			;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '파견보조비(69)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'69-1',P_SQLERRM, P_CHKID);
		END;
    /* 69 - 2 : TBEN461(파견보조비 대상자)의 급여년월=대상년월, 대상자의 지급금액 => TBEN997에 금번 급여년월=급여년월, 지급금액 등록*/
    BEGIN
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PAY_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN462 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND A.PAY_YM = lv_pay_ym
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '파견보조비(69)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'69-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 70 : 의료비(HT > 임원숙박비) -- 20250313 HT가 쓰려고 주석 해제
  --------------------
  WHEN '70' THEN
    /* 70-1 : TBEN701(의료비(임원숙박비) 대상자)의 급여년월=대상년월, 대상자의 지급금액 합계 => TBEN997에 금번 급여년월=급여년월, 지급금액 등록 */
    --의료비 20240723 추가 한진관광에서만 진행하기로 하여서 기존 TBEN997 INSERT는 기존대로 두고, 한진정보통신일때에만 TBEN777추가 로직 진행 합니다.
    --요청으로 다시 주석 처리
        IF P_ENTER_CD = 'HT' THEN
            BEGIN
                INSERT INTO TBEN777
                SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
                     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
                     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
                FROM(
                       SELECT X.ENTER_CD
                             , P_CPN201.PAY_ACTION_CD
                             , X.SABUN
                             , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
                             , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
                             , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
                             , P_CPN201.PAYMENT_YMD AS PAY_YMD
                             , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 (인하대병원의료비)
                             , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용 (종합검진비)
                             /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
                                        [예시] 과세(02),  비과세(01) || 공제(02),  지급(01)*/
                             , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
                             , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
                             , '' AS PAY_MEMO
                             , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
                             , '' AS MEMO
                             , SYSDATE AS CHKDATE
                             , P_CHKID AS CHKID
                        FROM (
                            SELECT A.ENTER_CD, A.SABUN
                                     , A.TAX_AMT AS PAY_AMT
                                     , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
                                     , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
                                     , E.ELEMENT_TYPE, E.ELEMENT_CD
                                FROM TBEN701 A, TBEN005 D, TCPN011 E, TCPN203 F
                             WHERE 1=1
                                 AND A.ENTER_CD = P_ENTER_CD
                                 AND A.PAY_YM   = lv_pay_ym
                                -- D
                               AND D.ENTER_CD = A.ENTER_CD
                               AND D.PAY_CD   = P_CPN201.PAY_CD
                               AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD --의료비 70
                                -- E
                                 AND E.ENTER_CD   = D.ENTER_CD
                               AND E.ELEMENT_CD = D.ELEMENT_CD
                               AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
                                -- F
                                 AND A.ENTER_CD = F.ENTER_CD
                                 AND A.SABUN    = F.SABUN
                                 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
                                 --ADD
                                 AND CASE WHEN A.APPL_GB = '01' THEN 'H380' WHEN A.APPL_GB = '02' THEN 'H390' ELSE 'X' END = E.ELEMENT_CD
                        ) X
                    GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
                ) A ;
            EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                P_SQLCODE := TO_CHAR(SQLCODE);
                P_SQLERRM := '의료비(70)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'72-1',P_SQLERRM, P_CHKID);
            END;
        END IF;    
    
        BEGIN
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PAY_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN701 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND A.PAY_YM = lv_pay_ym
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '의료비(70)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'70-1',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 71 : 상조상품
  --------------------
  WHEN '71' THEN
		/* 71-1 : TBEN531(상조상품신청/승인)의 분납시작년월~분납종료년월에 급여년월이 해당되고 일시납부금액 없는 대상자의 분납금액 합 => 공제항목코드의 공제금액항목에 등록*/
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01)공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , A.DIV_AMT AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN531 A, THRI103 B, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 AND lv_pay_ym BETWEEN A.USE_S_YM AND NVL(A.USE_E_YM, '999912')
							 AND A.MUT_FIS_YMD IS NULL
							-- B
							 AND A.ENTER_CD = B.ENTER_CD
							 AND A.APPL_SEQ = B.APPL_SEQ
							 AND B.APPL_STATUS_CD = '99'
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
								AND A.ENTER_CD = F.ENTER_CD
								AND A.SABUN    = F.SABUN
								AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A
			;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '상조상품(71)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'71-1',P_SQLERRM, P_CHKID);
		END;

		BEGIN
			INSERT INTO TBEN532
			SELECT A.ENTER_CD, A.APPL_SEQ, A.SABUN
					 , A.MUT_CD, lv_pay_ym, A.DIV_AMT
			 		 , SYSDATE, P_CHKID
				FROM TBEN531 A, THRI103 B, TCPN203 F
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND lv_pay_ym BETWEEN A.USE_S_YM AND NVL(A.USE_E_YM, '999912')
				 AND A.MUT_FIS_YMD IS NULL
				-- B
				 AND A.ENTER_CD = B.ENTER_CD
				 AND A.APPL_SEQ = B.APPL_SEQ
				 AND B.APPL_STATUS_CD = '99'
				-- F
					AND A.ENTER_CD = F.ENTER_CD
					AND A.SABUN    = F.SABUN
					AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
				  AND P_CPN201.PAY_CD <> 'A3'
				 ;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '상조상품(71)TBEN532 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'71-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 72 : 사내강사료
  --------------------
  WHEN '72' THEN
		/* 72-1 : TBEN791(사내강사료)의 급여년월=대상년월, 대상자의 과세금액 합계 => 지급 급여항목코드의 금액항목에 등록*/
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01) || 공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , A.TAX_AMT AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN791 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 AND A.PAY_YM   = lv_pay_ym
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
							 AND A.ENTER_CD = F.ENTER_CD
							 AND A.SABUN    = F.SABUN
							 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '상조상품(72)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'72-1',P_SQLERRM, P_CHKID);
		END;

     	/* 72-2 : TBEN791(사내강사료)의 급여년월=대상년월, 대상자의 지급금액 합계 => TBEN997에 금번 급여년월=급여년월, 지급금액 등록 */
     	BEGIN
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PAY_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN791 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND A.PAY_YM = lv_pay_ym
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '사내강사료(72)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'72-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 73 : 자격취득지원
  --------------------
  WHEN '73' THEN
    /* 73-1 : TBEN421(자격취득지원)의 급여년월=대상년월, 대상자의 과세금액 합계 => 지급 급여항목코드의 금액항목에 등록 */
    BEGIN
  		INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01) || 공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , A.TAX_AMT AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN421 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 AND A.PAY_YM   = lv_pay_ym
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
							 AND A.ENTER_CD = F.ENTER_CD
							 AND A.SABUN    = F.SABUN
							 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '상조상품(73)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'73-1',P_SQLERRM, P_CHKID);
		END;

   	/* 73-2 : TBEN421(자격취득지원)의 급여년월=대상년월, 대상자의 지급금액 합계 => TBEN997에 금번 급여년월=급여년월, 지급금액 등록 */
   	BEGIN
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PAY_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN421 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND A.PAY_YM = lv_pay_ym
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '자격취득지원(73)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'73-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 74 : 근로복지기금
  --------------------
  WHEN '74' THEN
    BEGIN
		/*
			"TBEN625(대출금상환내역)의 해당 급여계산코드 데이터의 상환금액, 이자금액을 각각 공제 급여항목코드의 금액항목에 등록
			(상여상환 포함되는 경우 상여 급여계산코드에 등록)
			마감처리시 TBEN625에 해당 대상자 마감여부 Y로 Update"
		*/
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01) || 공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
								 , CASE WHEN D.MON1_YN = 'Y' THEN NVL(A.REP_MON,0) -- 원금
												WHEN D.MON2_YN = 'Y' THEN NVL(A.INT_MON,0) -- 이자
									 END AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN625 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
						 	-- A
						 	 AND A.ENTER_CD = P_ENTER_CD
						 	 AND A.PAY_ACTION_CD = P_CPN201.PAY_ACTION_CD
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
								AND A.ENTER_CD = F.ENTER_CD
								AND A.SABUN    = F.SABUN
								AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
			EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '근로복지기금(74)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'74-1',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 75 : 신협적립금
  --------------------
  WHEN '75' THEN
		/* 75-1
				대상자의 재직상태가 작업기준일 기준 휴직/정직인데 중단년월이 없는 경우 or 중단년월이 있는데 복구년월이 있고 지급상태=""지급""인 경우(재 휴직)
					 => 작업기준 년월 1/2이상 근무자는 정상 지급대상.
					 => 작업기준 년월 1/2미만 근무자는 중단년월에 해당 급여년월, 복구년월=null, 지급상태 ""중지""로 TBEN632에 Update*/
		BEGIN
			UPDATE TBEN631 A
			SET A.USE_M_YM = P_CPN201.PAY_YM
				, A.USE_MS_YM = NULL
				, A.PAY_STS = 'S'
				, A.CHKDATE = SYSDATE
				, A.CHKID  = 'BEN_PAY_PRC'
			WHERE 1=1
      AND A.ENTER_CD = P_ENTER_CD
      AND ( F_BEN_GET_IS_CA_YN(A.ENTER_CD, A.SABUN, TO_CHAR(SYSDATE,'YYYYMMDD')) = 'Y'-- ,'EA'정직은 따로관리함
						 		OR EXISTS( SELECT 1 FROM THRM129 X, TSYS005 Y
														WHERE 1=1
														AND X.ENTER_CD = A.ENTER_CD
														AND X.SABUN    = A.SABUN
														AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN X.SDATE AND X.EDATE
														--
														AND X.ENTER_CD = Y.ENTER_CD
														AND X.PUNISH_CD = Y.CODE
														AND Y.GRCODE_CD = 'H20270'
														AND Y.NOTE1 = 'Y')
								)
			AND ((A.USE_M_YM IS NULL OR A.USE_M_YM = '')
				-- 중단년월이 있는데 복구년월이 있고 지급상태="지급"인 경우(재 휴직)
				OR ((A.USE_M_YM IS NOT NULL AND LENGTH(TRIM(A.USE_M_YM)) = 6) AND (A.USE_MS_YM IS NOT NULL AND LENGTH(TRIM(A.USE_MS_YM)) = 6) AND A.PAY_STS = 'P'))
			AND (F_CPN_WKP_CNT( A.ENTER_CD, A.SABUN
												, TO_CHAR(TRUNC(SYSDATE, 'MONTH'), 'YYYYMMDD') -- 해당월의 첫날
												, TO_CHAR(LAST_DAY(SYSDATE), 'YYYYMMDD'))			-- 해당월의 마지막날
												/ TO_CHAR(LAST_DAY(SYSDATE), 'DD')) < 0.5
			AND P_CPN201.PAY_CD  <> 'A3'
			-- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
			AND A.PAY_STS <> 'F'
			;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '신협적립금(75)_TBEN631 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'75-1',P_SQLERRM, P_CHKID);
		END;

		/*75-2:대상자의 재직상태가 작업기준일 기준 재직인데 중단년월이 있고, 복구년월이 Null인 경우
				해당 급여년월을 복구년월, 지급상태 "지급"으로 TBEN632에 Update  */
		BEGIN
			 UPDATE TBEN631 A
       -- 복구년월을 급여년월로 설정 2025.04.24
		   --SET A.USE_MS_YM =  TO_CHAR(ADD_MONTHS(TO_DATE(P_CPN201.PAY_YM, 'YYYYMM') , 1), 'YYYYMM')
       SET A.USE_MS_YM = P_CPN201.PAY_YM
		   	 , A.PAY_STS = 'P'
		   	 , A.CHKDATE = SYSDATE
		   	 , A.CHKID  = 'BEN_PAY_PRC'
		   	WHERE 1=1
        AND A.ENTER_CD = P_ENTER_CD
        AND EXISTS (
			   	SELECT 1
					FROM THRM151 C
					WHERE 1=1
					 -- C
						AND A.ENTER_CD = C.ENTER_CD
						AND A.SABUN    = C.SABUN
						AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN C.SDATE AND C.EDATE
					 -- 대상자의 재직상태가 작업기준일 기준 재직인데 중단년월이 있고,
						AND C.STATUS_CD = 'AA'
					 -- 복구년월이 Null인 경우
						AND ((A.USE_M_YM IS NOT NULL AND LENGTH(TRIM(A.USE_M_YM)) = 6) AND (A.USE_MS_YM IS NULL OR A.USE_MS_YM = ''))
						AND P_CPN201.PAY_CD  <> 'A3'
            -- 근무일수 15일 이상 체크 추가 2025.04.024
            AND (F_CPN_WKP_CNT( A.ENTER_CD, A.SABUN
                              , TO_CHAR(TRUNC(SYSDATE, 'MONTH'), 'YYYYMMDD') -- 해당월의 첫날
                              , TO_CHAR(LAST_DAY(SYSDATE), 'YYYYMMDD'))			-- 해당월의 마지막날
                              / TO_CHAR(LAST_DAY(SYSDATE), 'DD')) >= 0.5
				)
				-- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
				AND A.PAY_STS <> 'F'
				;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '신협적립금(75)_TBEN631 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'75-2',P_SQLERRM, P_CHKID);
		END;

		/*75-3:대상자의 재직상태가 작업기준일 기준 퇴직인데 지급상태="지급", 종료년월이 Null인 경우
             퇴사일자가 15일미만 : 종료년월에 해당 급여년월, 지급상태 "종료"로 TBEN632에 Update,
             퇴사일자가 15일이상 : 종료년월에 해당 급여년월의 익월, 지급상태 "지급"으로  TBEN632에 Update
			지급상태 = "지급",  종료년월이 Null이 아니고 종료년월<=해당 지급년월인 경우 지급상태 = "종료"로 TBEN632에 Update
			지급상태 = "종료"이며 Skip  */
		BEGIN
			UPDATE TBEN631 A
			SET A.USE_E_YM = P_CPN201.PAY_YM
				 , A.PAY_STS = (SELECT CASE WHEN TO_NUMBER(SUBSTR(C.SDATE,7,2)) < 15 THEN 'F' ELSE 'P' END
												  FROM THRM151 C
												WHERE 1=1
												 AND A.ENTER_CD = P_ENTER_CD
												-- C
												 AND A.ENTER_CD = C.ENTER_CD
												 AND A.SABUN    = C.SABUN
												 AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN C.SDATE AND C.EDATE
												 AND C.STATUS_CD = 'RA')
				 , A.CHKDATE = SYSDATE
				 , A.CHKID  = 'BEN_PAY_PRC'
			WHERE 1=1
      AND A.ENTER_CD = P_ENTER_CD
      AND EXISTS (
					SELECT 1
					  FROM THRM151 C
					WHERE 1=1
					-- C
					 AND A.ENTER_CD = C.ENTER_CD
					 AND A.SABUN    = C.SABUN
					 AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN C.SDATE AND C.EDATE
					 AND C.STATUS_CD = 'RA'
			)
			AND (A.USE_E_YM IS NULL OR A.USE_E_YM = '')
			AND P_CPN201.PAY_CD  <> 'A3'
			-- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
			AND A.PAY_STS <> 'F'
			;

		 UPDATE TBEN631 A
	   SET  A.PAY_STS = 'F'
	   	 , A.CHKDATE = SYSDATE
	   	 , A.CHKID  = 'BEN_PAY_PRC'
	   	WHERE 1=1
      AND A.ENTER_CD = P_ENTER_CD
      AND EXISTS (
		   	SELECT 1
				FROM THRM151 C
				WHERE 1=1
				 -- C
					AND A.ENTER_CD = C.ENTER_CD
					AND A.SABUN    = C.SABUN
					AND A.PAY_STS = 'P'
					AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN C.SDATE AND C.EDATE
					AND C.STATUS_CD = 'RA'
				 -- 복구년월이 Null인 경우
					AND ((A.USE_M_YM IS NOT NULL AND LENGTH(TRIM(A.USE_M_YM)) = 6) AND (A.USE_M_YM <= P_CPN201.PAY_YM))
					AND P_CPN201.PAY_CD  <> 'A3'
			)
			-- 필수사항, 종료 아닐때만, 종료년월이 없더라도 담당자가 수정했을 경우가 있기 대문에
			AND A.PAY_STS <> 'F'
			;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '신협적립금(75)_TBEN631 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'75-3',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 76 : 신협대출
  --------------------
  WHEN '76' THEN
  	/*76-1 : TBEN639(대출금상환내역)의 해당 급여계산코드 데이터의 상환금액, 이자금액을 각각 공제 급여항목코드의 금액항목에 등록
		(상여상환 포함되는 경우 상여 급여계산코드에 등록)*/
   	BEGIN
     		IF P_ENTER_CD = 'HX' THEN -- 한진정보일때만 업로드되기 때문에 분기처리 필요
				INSERT INTO TBEN777
				SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
				     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
				     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
				FROM(SELECT X.ENTER_CD
						 		 , P_CPN201.PAY_ACTION_CD
						 		 , X.SABUN
						 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
						     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
						     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
						     , P_CPN201.PAYMENT_YMD AS PAY_YMD
						     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
						     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
						     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
										[예시] 과세(02),  비과세(01) || 공제(02),  지급(01)*/
						     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
						     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
						     , '' AS PAY_MEMO
						     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
						     , '' AS MEMO
						     , SYSDATE AS CHKDATE
						     , P_CHKID AS CHKID
						FROM (
							SELECT A.ENTER_CD, A.SABUN
									 , CASE WHEN D.MON1_YN = 'Y' THEN NVL(A.REP_MON,0) -- 상완금(원금)
													WHEN D.MON2_YN = 'Y' THEN NVL(A.INT_MON,0) -- 이자
										 END AS PAY_AMT
									 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
									 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
									 , E.ELEMENT_TYPE, E.ELEMENT_CD
								FROM TBEN640 A, TBEN005 D, TCPN011 E
							 WHERE 1=1
							 	-- A
							 	 AND A.ENTER_CD = P_ENTER_CD
							 	 AND A.PAY_YM = P_CPN201.PAY_YM
							 	 -- 00001 급여 : 10 || 00002 상여 : 11
							 	 AND A.REPAY_TYPE = (SELECT DECODE(RUN_TYPE, '00001','10','00002','11') FROM TCPN051 WHERE ENTER_CD = P_ENTER_CD AND PAY_CD = P_CPN201.PAY_CD)
								-- D
							   AND D.ENTER_CD = A.ENTER_CD
							   AND D.PAY_CD   = P_CPN201.PAY_CD
							   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
								-- E
								 AND E.ENTER_CD   = D.ENTER_CD
							   AND E.ELEMENT_CD = D.ELEMENT_CD
							   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
						) X
					GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
					) A;
			ELSE
				INSERT INTO TBEN777
				SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
				     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
				     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
				FROM(SELECT X.ENTER_CD
						 		 , P_CPN201.PAY_ACTION_CD
						 		 , X.SABUN
						 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
						     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
						     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
						     , P_CPN201.PAYMENT_YMD AS PAY_YMD
						     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
						     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
						     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
										[예시] 과세(02),  비과세(01) || 공제(02),  지급(01)*/
						     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
						     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
						     , '' AS PAY_MEMO
						     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
						     , '' AS MEMO
						     , SYSDATE AS CHKDATE
						     , P_CHKID AS CHKID
						FROM (
							SELECT A.ENTER_CD, A.SABUN
									 , CASE WHEN D.MON1_YN = 'Y' THEN NVL(A.REP_MON,0) -- 원금
													WHEN D.MON2_YN = 'Y' THEN NVL(A.INT_MON,0) -- 이자
										 END AS PAY_AMT
									 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
									 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
									 , E.ELEMENT_TYPE, E.ELEMENT_CD
								FROM TBEN639 A, TBEN005 D, TCPN011 E
							 WHERE 1=1
							 	-- A
							 	 AND A.ENTER_CD = P_ENTER_CD
							 	 AND A.PAY_ACTION_CD = P_CPN201.PAY_ACTION_CD
								-- D
							   AND D.ENTER_CD = A.ENTER_CD
							   AND D.PAY_CD   = P_CPN201.PAY_CD
							   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
								-- E
								 AND E.ENTER_CD   = D.ENTER_CD
							   AND E.ELEMENT_CD = D.ELEMENT_CD
							   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
						) X
					GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
				) A;
			END IF;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '신협대출(76)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'76-1',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 77 : PM수당
  --------------------
  WHEN '77' THEN
		/* 77-1 : "TBEN442(PM수당)의 급여년월=대상년월
						, 대상자의 PM수당구분=""01 PM수당""인 수당금액  => 지급 급여항목코드(A175 PM수당)의 금액항목에 등록
                 PM수당구분=""02 PM수당(평가)""인 수당금액  => 지급 급여항목코드(A177 PM수당(평가))의 금액항목에 등록"*/
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01) || 공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , A.PM_AMT AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
								 , A.PAY_ITEM
							FROM TBEN442 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND A.PAY_YM = P_CPN201.PAY_YM
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
						   AND DECODE(A.PAY_ITEM,'01','A175','02','A177') = D.ELEMENT_CD -- 같은 항목에 들어있어서 하드코딩 필요
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
							 AND A.ENTER_CD = F.ENTER_CD
							 AND A.SABUN    = F.SABUN
							 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := 'PM수당(77)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'77-1',P_SQLERRM, P_CHKID);
		END;

	 	/* 77-2 : TBEN442(PM수당)의 급여년월=대상년월, 대상자의 수당금액 합계 =>TBEN997에 금번 급여년월=급여년월, 지급금액 등록 */
	 	BEGIN
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PM_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN442 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND A.PAY_YM = lv_pay_ym
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := 'PM수당(77)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'77-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 85 : 식비(현금중식대)
  --------------------
  WHEN '85' THEN
		/* 85-1
			TBEN661(식비(현금중식대)) 급여년월=대상년월, 대상자의 과세금액 => 지급(과세) 급여항목코드의 금액항목에 등록,
			비과세금액 => 지급(비과세) 급여항목코드의 금액항목에 등록
		*/
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , CASE WHEN D.MON1_YN = 'Y' THEN NVL(A.NTAX_AMT,0) -- 비과세 IN ('A225', 'T350')
						 		 				WHEN D.MON2_YN = 'Y' THEN NVL(A.TAX_AMT,0) -- 과세 IN ('A227', 'T352')
						 		 	 END AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN661 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 AND A.PAY_YM   = lv_pay_ym
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
							 AND A.ENTER_CD = F.ENTER_CD
							 AND A.SABUN    = F.SABUN
							 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '식비(현금중식대_85)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'85-1',P_SQLERRM, P_CHKID);
		END;

		/* 85-2
			TBEN661(식비(현금중식대)) 급여년월=대상년월, 대상자의 지급금액 = TBEN997에 지급금액, 급여년월 등록
		*/
		BEGIN
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PAY_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN661 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND A.PAY_YM	 =  lv_pay_ym
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '식비(현금중식대_85)_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'85-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 88 : 이동전화보조비
  --------------------
  WHEN '88' THEN
  	/*TBEN446의 급여년월=해당 급여년월, 대상자의 지원금액 => 지급 급여항목코드의 금액항목에 등록 (한진정보 Only)*/
		BEGIN
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
						 		 , A.PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN446 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
							 AND A.ENTER_CD = P_ENTER_CD
							 AND A.PAY_YM   = lv_pay_ym
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
							 AND A.ENTER_CD = F.ENTER_CD
							 AND A.SABUN    = F.SABUN
							 AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '이동전화보조비_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'88-1',P_SQLERRM, P_CHKID);
		END;

  	BEGIN
  		/*TBEN446의 급여년월=해당 급여년월, 대상자의 지원금액 => TBEN997에 금번 급여년월=급여년월, 지급금액 등록*/
			INSERT INTO TBEN997
			SELECT  A.ENTER_CD, P_CPN201.PAY_ACTION_CD, P_BENEFIT_BIZ_CD, A.SABUN, SUM(A.PAY_AMT), lv_pay_ym, '10003', SYSDATE, P_CHKID
				FROM TBEN446 A
			 WHERE 1=1
				 AND A.ENTER_CD = P_ENTER_CD
				 AND A.PAY_YM	 =  lv_pay_ym
				 AND P_CPN201.PAY_CD = 'A1'
			GROUP BY A.ENTER_CD, A.SABUN;
		EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '이동전화보조비_TBEN997 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'88-2',P_SQLERRM, P_CHKID);
		END;
  --------------------
  -- 97 : 안전건강지원금
  --------------------      
  WHEN '97' THEN
    BEGIN
		/*
			TBEN841(안전조업지원금)  급여년월=대상년월 인 금액을 TBEN777에 넣습니다. 
		*/
			INSERT INTO TBEN777
			SELECT A.ENTER_CD, A.PAY_ACTION_CD, A.SABUN, A.BEN_GUBUN, A.SEQ + ROWNUM, A.BUSINESS_PLACE_CD, A.PAY_YMD, NULL
			     , A.MON1, A.MON2, A.MON3, A.MON4, A.MON5, A.MON6, A.MON7, A.MON8, A.MON9, A.MON10, A.MON11, A.MON12
			     , A.PAY_MEMO, A.PAY_EXCEPT_GUBUN, A.MEMO, A.CHKDATE, A.CHKID
			FROM(SELECT X.ENTER_CD
					 		 , P_CPN201.PAY_ACTION_CD
					 		 , X.SABUN
					 		 , P_BENEFIT_BIZ_CD    AS BEN_GUBUN
					     , (SELECT NVL(MAX(SEQ),0) AS SEQ FROM TBEN777 WHERE ENTER_CD = X.ENTER_CD) SEQ
					     , P_BUSINESS_PLACE_CD  AS BUSINESS_PLACE_CD
					     , P_CPN201.PAYMENT_YMD AS PAY_YMD
					     , SUM(DECODE(X.MON1_YN, 'Y', X.PAY_AMT, 0))AS MON1 	-- 1번 금액 사용 하드코딩
					     , SUM(DECODE(X.MON2_YN, 'Y', X.PAY_AMT, 0))AS MON2 	-- 2번 금액 사용
					     /* 금액 종류는 1,2번만 구분해서 사용함, 전사 싱크가 맞아있는지 체크필요
									[예시] 과세(02),  비과세(01) || 공제(02),  지급(01)*/
					     , 0 AS MON3, 0 AS MON4, 0 AS MON5, 0 AS MON6, 0 AS MON7
					     , 0 AS MON8, 0 AS MON9, 0 AS MON10, 0 AS MON11, 0 AS MON12
					     , '' AS PAY_MEMO
					     , DECODE(MAX(X.ELEMENT_TYPE),'A','P','D','E') AS PAY_EXCEPT_GUBUN --P지급, E공제
					     , '' AS MEMO
					     , SYSDATE AS CHKDATE
					     , P_CHKID AS CHKID
					FROM (
						SELECT A.ENTER_CD, A.SABUN
								 , A.PAY_MON AS PAY_AMT
								 , D.MON1_YN, D.MON2_YN, D.MON3_YN, D.MON4_YN,  D.MON5_YN,  D.MON6_YN
								 , D.MON7_YN, D.MON8_YN, D.MON9_YN, D.MON10_YN, D.MON11_YN, D.MON12_YN
								 , E.ELEMENT_TYPE, E.ELEMENT_CD
							FROM TBEN841 A, TBEN005 D, TCPN011 E, TCPN203 F
						 WHERE 1=1
						 	-- A
						 	 AND A.ENTER_CD = P_ENTER_CD
						 	 AND A.PAY_YM = lv_pay_ym 
                             AND A.CHECK_YN = 'Y'
							-- D
						   AND D.ENTER_CD = A.ENTER_CD
						   AND D.PAY_CD   = P_CPN201.PAY_CD
						   AND D.BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
							-- E
							 AND E.ENTER_CD   = D.ENTER_CD
						   AND E.ELEMENT_CD = D.ELEMENT_CD
						   AND P_CPN201.PAYMENT_YMD BETWEEN E.SDATE AND NVL(E.EDATE,'99991231')
							-- F
								AND A.ENTER_CD = F.ENTER_CD
								AND A.SABUN    = F.SABUN
								AND P_CPN201.PAY_ACTION_CD = F.PAY_ACTION_CD
					) X
				GROUP BY X.ENTER_CD, X.SABUN, X.ELEMENT_CD
			) A;
			EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			P_SQLCODE := TO_CHAR(SQLCODE);
			P_SQLERRM := '안전조업지원금(97)_TBEN777 작업중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
			P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'97-1',P_SQLERRM, P_CHKID);
		END;
  END CASE;
EXCEPTION
WHEN OTHERS THEN
   P_SQLCODE := TO_CHAR(SQLCODE);
   P_SQLERRM := '복리후생 급여작업 시 오류' || SQLERRM;
   P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm, 'BEN_BIZ_CD_PAY_DATA', P_SQLERRM, P_CHKID);
	 --ROLLBACK;
END P_BEN_PAY_DATA_CRE_LIST;