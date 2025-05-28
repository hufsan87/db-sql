create or replace PROCEDURE             P_BEN_WATER_POINT_CREATE(
	                        p_sqlcode           OUT VARCHAR2,     -- Error Code
                          p_sqlerrm           OUT VARCHAR2,     -- Error Messages
                          p_enter_cd          IN  VARCHAR2,     -- 회사코드
                          p_search_ym         IN  VARCHAR2,     -- 해당년월
                          p_sabun         	IN  VARCHAR2      -- 입력자
)
IS
/********************************************************************************/
/*                                                                              */
/*                    (c) Copyright ISU System Inc. 2004                        */
/*                           All Rights Reserved                                */
/*                                                                              */
/********************************************************************************/
/*  PROCEDURE NAME : P_BEN_WATER_POINT_CREATE                                   */
/*                   포인트생성                                             				 */
/********************************************************************************/
/*  [ 참조 TABLE ]                                                               */
/*    TBEN591 : BEF_POINT(이월포인트),  NEW_POINT(생성포인트)  												*/
/********************************************************************************/
/*  [ PRC 개요 ]                                                                 */
/*        해당월 생수포인트 생성 Procedure Call                             					*/
/********************************************************************************/
/*  [ PRC 호출 ]                                                                 */
/*                                                                              */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/*------------------------------------------------------------------------------*/
/* 2023-05-16  J.J.H           Initial Release                                  */
/********************************************************************************/

-- Local Variables
   LV_BIZ_CD             TSYS903.BIZ_CD%TYPE := 'BEN';
   LV_OBJECT_NM          TSYS903.OBJECT_NM%TYPE := 'P_BEN_WATER_POINT_CREATE';
BEGIN
   p_sqlcode  := NULL;
   p_sqlerrm  := NULL;

	 -- 기존 대상자 정보 삭제
   BEGIN
		 DELETE TBEN591 A
		 WHERE 1=1
		   AND A.ENTER_CD = p_enter_cd
		   AND A.BAS_YM   = p_search_ym;

	   -- 포인트 대상자 머지
		 MERGE INTO TBEN591 A
				USING (
					SELECT
						A.ENTER_CD
						,C.SABUN
						, p_search_ym AS BAS_YM
						-- 누적여부 Y일때만
                        -- 한진관광, 이월 없음 2024.12.30 hslee
                        -- 한국공항, 20포인트 생성 예외자 사번 추가 2025.03.05
						,DECODE(A.ENTER_CD,'HT',0,(SELECT NVL(max(X.BEF_POINT),0)
									 + NVL(max( CASE WHEN X.ENTER_CD = 'HG' AND F_COM_GET_JIKCHAK_CD(X.ENTER_CD,X.SABUN,p_search_ym||'01') = 'JCG_DUT_17'
									 				 THEN 40 
                                                     WHEN X.ENTER_CD = 'KS' AND X.SABUN IN ('2300815','2200320','2302727')
                                                     THEN 20
                                                     ELSE X.NEW_POINT 
                                                     END),
                                        0)
									 - NVL(sum(Y.USE_POINT),0)
							FROM TBEN591 X, TBEN592 Y, TBEN590 Z
						  WHERE 1=1
							-- X
							AND X.ENTER_CD  = p_enter_cd
							AND X.BAS_YM = TO_CHAR(TO_DATE(p_search_ym, 'YYYYMM') -1, 'YYYYMM')
							-- Y
							AND X.ENTER_CD  = Y.ENTER_CD(+)
							AND X.SABUN  	= Y.SABUN(+)
							AND X.BAS_YM  	= Y.BAS_YM(+)
							AND X.SABUN     = C.SABUN
							-- Z
							AND X.ENTER_CD  = Z.ENTER_CD
							AND X.BAS_YM||'01'    BETWEEN Z.USE_SDATE  AND Z.USE_EDATE
							AND Z.GB_CD  	= A.GB_CD
							AND Z.TG_CD     = A.TG_CD
							AND Z.LT_CD     = A.LT_CD
							AND Z.ACC_YN    = 'Y'		-- 누적여부 Y일때만
							)) AS	BEF_POINT
						--, NVL(A.WTR_PNT,0) AS NEW_POINT
                        -- 한진칼 요청사항 팀장은 40포인트 고정
                        -- 한국공항, 20포인트 생성 예외자 사번 추가 2025.03.05
						, NVL(CASE WHEN C.ENTER_CD = 'HG' AND C.JIKCHAK_CD = 'JCG_DUT_17'
			 					   THEN 40 
                                   WHEN C.ENTER_CD = 'KS' AND C.SABUN IN ('2300815','2200320','2302727')
                                   THEN 20
                                   ELSE A.WTR_PNT 
                                   END,
                                   0) AS NEW_POINT
						, SYSDATE AS CHKDATE
						, p_sabun AS CHKID
						-- 지원금액 (대상자의 생성포인트/1.5L 공제포인트)*1.5L Box단가
                        -- 한진칼 요청사항 팀장은 40포인트 고정
                        -- 한국공항, 20포인트 생성 예외자 사번 추가 2025.03.05
						, (SELECT (
										NVL(CASE WHEN C.ENTER_CD = 'HG' AND C.JIKCHAK_CD = 'JCG_DUT_17'
			 								 THEN 40 
                                             WHEN C.ENTER_CD = 'KS' AND C.SABUN IN ('2300815','2200320','2302727')
                                             THEN 20
                                             ELSE A.WTR_PNT 
                                             END,0)
						 						/WTR_PNT) * BOX_AMT FROM TBEN590
						    WHERE ENTER_CD = A.ENTER_CD
						    	AND p_search_ym||'01' BETWEEN USE_SDATE  AND USE_EDATE
						    	AND GB_CD = '02'
						    	AND LT_CD = '03'
						    	) AS USE_AMT
					FROM TBEN590 A, TSYS005 B, THRM151 C
					WHERE 1=1
						AND A.ENTER_CD = p_enter_cd
						AND p_search_ym||'01' BETWEEN A.USE_SDATE  AND A.USE_EDATE
						AND A.GB_CD  = '01' -- 지급
						AND A.LT_CD  = 'pay' -- 지급
						-- B
						AND A.ENTER_CD  = B.ENTER_CD
						AND A.TG_CD     = B.CODE
						AND B.GRCODE_CD = 'B59030'
						-- C
						AND A.ENTER_CD  = C.ENTER_CD
						AND p_search_ym||'01' BETWEEN C.SDATE AND C.EDATE
						AND C.STATUS_CD NOT LIKE('RA%')
						AND EXISTS (SELECT AA.CODE AS JIKGUB_CD
												  FROM TSYS006 AA
												 WHERE 1=1
												   AND AA.ENTER_CD = p_enter_cd
												   AND  AA.GUBUN ='B01'
												   AND  AA.CODE_VAL = B.CODE
												   AND  AA.CODE = C.JIKGUB_CD
												   AND  p_search_ym||'01' BETWEEN AA.SDATE AND NVL(AA.EDATE,'99991231')
												   )
					  /* 복리후생 예외자 추가 2023-09-15*/
            /* 시작 종료년월 체크 추가 2025-04-08 */
					  AND NOT EXISTS (SELECT SABUN FROM TBEN900 WHERE ENTER_CD = P_ENTER_CD AND BENEFIT_BIZ_CD = '59' AND SABUN = C.SABUN AND p_search_ym BETWEEN USE_S_YM AND USE_E_YM)
					  AND 1 = CASE WHEN C.ENTER_CD = 'HG' AND C.SABUN IN ('0001902','0002001') THEN 0
					  						 WHEN C.ENTER_CD = 'HG' AND C.MANAGE_CD IN ('CWT_01','CWT_02','CWT_03') THEN 0
					  						 WHEN C.ENTER_CD = 'KS' 
					  						  AND C.MANAGE_CD = 'ETS_08' --인턴직 3개월
					  							AND F_COM_GET_CAREER_CNT_BAS_YMD(C.ENTER_CD, C.SABUN, p_search_ym||'01', 'W', 'MM', '0',NULL,'') < 3 THEN 0
					  							-- 한국공항 추가요청 23.12.04 : 인턴직이면서 3개월 미만인 사원 생성 X, 정직원 포함, KS 25.05.28
					  ELSE 1 END -- 한진칼에서 추가요청 23.11.23
		           ) B
					ON (     A.ENTER_CD     = B.ENTER_CD
					    AND  A.SABUN        = B.SABUN
					    AND  A.BAS_YM 			= B.BAS_YM
					    )
           WHEN MATCHED THEN
              UPDATE SET A.BEF_POINT   = B.BEF_POINT
	                     , A.NEW_POINT   = B.NEW_POINT
	                     , A.CHKDATE     = B.CHKDATE
	                     , A.CHKID    	 = B.CHKID
		       WHEN NOT MATCHED THEN
		           INSERT (
                ENTER_CD
								,SABUN
								,BAS_YM
								,BEF_POINT
								,NEW_POINT
								,USE_AMT
								,CHKDATE
								,CHKID
		           )
		           VALUES (
		             B.ENTER_CD
								,B.SABUN
								,p_search_ym
								,B.BEF_POINT
								,B.NEW_POINT
								,CEIL(B.USE_AMT)
								,SYSDATE
								,p_sabun
		           );

	 --------------------------------------
	 /* 오라클 스케줄러에서도 호출하기 때문에 명시해줌 */
	 COMMIT;
	 --------------------------------------
   EXCEPTION
     WHEN OTHERS THEN
        ROLLBACK;
        p_sqlcode := TO_CHAR(sqlcode);
        p_sqlerrm := 'TBEN591삭제 OR 머지 에러 -> ' || sqlerrm;
        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
        RETURN;
   END;
END P_BEN_WATER_POINT_CREATE;