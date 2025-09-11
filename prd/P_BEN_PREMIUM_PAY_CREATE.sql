create or replace PROCEDURE             P_BEN_PREMIUM_PAY_CREATE(
	                        p_sqlcode           OUT VARCHAR2,     -- Error Code
                          p_sqlerrm           OUT VARCHAR2,     -- Error Messages
                          p_enter_cd          IN  VARCHAR2,     -- 회사코드
                          p_pay_ym         IN  VARCHAR2,     -- 급여년월
                          p_sabun         	IN  VARCHAR2      -- 입력자
)
IS
/********************************************************************************/
/*                                                                              */
/*                    (c) Copyright ISU System Inc. 2004                        */
/*                           All Rights Reserved                                */
/*                                                                              */
/********************************************************************************/
/*  PROCEDURE NAME : P_BEN_PREMIUM_PAY_CREATE                                   */
/*                   보험료납입내역생성                                             				 */
/********************************************************************************/
/*  [ 참조 TABLE ]                                                               */
/*    TBEN540, TBEN542, TBEN543							*/
/********************************************************************************/
/*  [ PRC 개요 ]                                                                 */
/*        해당 급여년월 보험료 납입내역 생성 Procedure Call                             					*/
/********************************************************************************/
/*  [ PRC 호출 ]                                                                 */
/*                                                                              */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/*------------------------------------------------------------------------------*/
/* 2023-10-06  C.H.N           Initial Release                                  */
/********************************************************************************/

-- Local Variables
   LV_BIZ_CD             TSYS903.BIZ_CD%TYPE    := 'BEN';
   LV_OBJECT_NM          TSYS903.OBJECT_NM%TYPE := 'P_BEN_PREMIUM_PAY_CREATE';
   LV_BENEFIT_BIZ_CD     VARCHAR2(1000) DEFAULT '55'; -- 자가보험
BEGIN
   p_sqlcode  := NULL;
   p_sqlerrm  := NULL;

  BEGIN
	  DELETE FROM TBEN543 A
	  WHERE A.ENTER_CD = p_enter_cd
	         AND A.PAY_YM 		= p_pay_ym;
EXCEPTION
    WHEN OTHERS THEN
       p_sqlcode := TO_CHAR(sqlcode);
       p_sqlerrm := 'TBEN543 기존 데이터 DELETE 에러 -> ' || sqlerrm;
       P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
       RETURN;
	  END;

  /* 복직대상자 자가보험가입내역 복구년월, 지급상태 UPDATE */	  
  BEGIN
	   UPDATE TBEN542 A
          SET A.USE_MS_YM     = p_pay_ym
            , A.PAY_STS       = 'P'
            , A.CHKDATE       = SYSDATE
            , A.CHKID         = p_sabun
	    WHERE A.ENTER_CD      = p_enter_cd
          AND A.PAY_STS      <> 'F'
          AND F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 'AA'
          AND A.USE_M_YM IS NOT NULL
          AND A.USE_MS_YM IS NULL;
  EXCEPTION
    WHEN OTHERS THEN
       p_sqlcode := TO_CHAR(sqlcode);
       p_sqlerrm := 'TBEN542 복직 UPDATE 에러 -> ' || sqlerrm;
       P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
       RETURN;
   END;
   
   
  /* 당월퇴직자(재직상태:퇴직) 자가보험기준관리 지급중지로 UPDATE */
  BEGIN
     UPDATE TBEN542 A
       SET A.USE_E_YM      = p_pay_ym -- TO_CHAR(ADD_MONTHS(p_pay_ym || '01', 1), 'YYYYMM') 
         , A.PAY_STS       = 'F'
         , A.CHKDATE       = SYSDATE
         , A.CHKID         = p_sabun
     WHERE A.ENTER_CD      = p_enter_cd
      -- AND F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 'RA'
       -- 24.07.16 추가 (thrm151 이 아닌 thrm100 퇴직일자로 변경)
       AND EXISTS (SELECT 1
                     FROM THRM100 X
                    WHERE X.ENTER_CD = A.ENTER_CD 
                      AND X.SABUN = A.SABUN
                      AND SUBSTR(X.RET_YMD , 0, 6)  = p_pay_ym)  
       AND A.USE_E_YM IS NULL
       AND A.PAY_STS <> 'F';
    EXCEPTION
     WHEN OTHERS THEN
        p_sqlcode := TO_CHAR(sqlcode);
        p_sqlerrm := 'TBEN542 퇴직 UPDATE 에러 -> ' || sqlerrm;
        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
        RETURN;
  END;
    
   

    IF P_ENTER_CD = 'KS' THEN
        BEGIN
            INSERT INTO TBEN543 (ENTER_CD, SABUN, INS_COMP_CD, JOIN_YMD, PAY_YM, COM_AMT, OWN_AMT, CHKDATE, CHKID, MEMO)
            SELECT A.ENTER_CD
             , A.SABUN
             , A.INS_COMP_CD
             , A.JOIN_YMD
             , p_pay_ym AS PAY_YM
             /*, CASE WHEN A.D_YN  = 'Y' THEN B.COM_AMT_D
                ELSE B.COM_AMT_S END AS COM_AMT
             , CASE WHEN A.D_YN = 'Y' THEN B.OWN_AMT_D * (MONTHS_BETWEEN(TO_DATE(A.USE_MS_YM, 'YYYY-MM'), TO_DATE(A.USE_M_YM, 'YYYY-MM')))
               ELSE B.OWN_AMT_S * (MONTHS_BETWEEN(TO_DATE(A.USE_MS_YM, 'YYYY-MM'), TO_DATE(A.USE_M_YM, 'YYYY-MM'))) END AS OWN_AMT*/
             -- 20240206 미공제분+당월분으로 처리, 회사와 직원 동일한 금액으로 처리
             , CASE WHEN A.D_YN = 'Y' THEN B.COM_AMT_D * (MONTHS_BETWEEN(TO_DATE(A.USE_MS_YM, 'YYYY-MM'), TO_DATE(A.USE_M_YM, 'YYYY-MM'))+1)
               ELSE B.COM_AMT_S * (MONTHS_BETWEEN(TO_DATE(A.USE_MS_YM, 'YYYY-MM'), TO_DATE(A.USE_M_YM, 'YYYY-MM'))+1) END AS COM_AMT
             , CASE WHEN A.D_YN = 'Y' THEN B.OWN_AMT_D * (MONTHS_BETWEEN(TO_DATE(A.USE_MS_YM, 'YYYY-MM'), TO_DATE(A.USE_M_YM, 'YYYY-MM'))+1)
               ELSE B.OWN_AMT_S * (MONTHS_BETWEEN(TO_DATE(A.USE_MS_YM, 'YYYY-MM'), TO_DATE(A.USE_M_YM, 'YYYY-MM'))+1) END AS OWN_AMT
             , SYSDATE   AS CHKDATE
             , p_sabun AS CHKID
             , '복직' AS MEMO
          FROM TBEN542 A, TBEN540 B
         WHERE A.ENTER_CD       = p_enter_cd
           AND A.PAY_STS <> 'F'
           AND F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 'AA'
           AND A.USE_M_YM IS NOT NULL
           AND A.USE_MS_YM = p_pay_ym
           AND A.ENTER_CD       = B.ENTER_CD
           AND A.INS_COMP_CD    = B.INS_COMP_CD
           AND A.JOIN_YMD BETWEEN B.USE_SDATE AND B.USE_EDATE;
      EXCEPTION
        WHEN OTHERS THEN
        p_sqlcode := TO_CHAR(sqlcode);
        p_sqlerrm := 'TBEN543 복직 INSERT 에러 -> ' || sqlerrm;
        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
        RETURN;
      END;

    ELSE
  
        BEGIN
            INSERT INTO TBEN543 (ENTER_CD, SABUN, INS_COMP_CD, JOIN_YMD, PAY_YM, COM_AMT, OWN_AMT, CHKDATE, CHKID, MEMO)
            SELECT A.ENTER_CD
             , A.SABUN
             , A.INS_COMP_CD
             , A.JOIN_YMD
             , p_pay_ym AS PAY_YM
             , CASE WHEN A.D_YN  = 'Y' THEN B.COM_AMT_D
                ELSE B.COM_AMT_S END AS COM_AMT
             , CASE WHEN A.D_YN = 'Y' THEN B.OWN_AMT_D * (MONTHS_BETWEEN(TO_DATE(A.USE_MS_YM, 'YYYY-MM'), TO_DATE(A.USE_M_YM, 'YYYY-MM')))
               ELSE B.OWN_AMT_S * (MONTHS_BETWEEN(TO_DATE(A.USE_MS_YM, 'YYYY-MM'), TO_DATE(A.USE_M_YM, 'YYYY-MM'))) END AS OWN_AMT
             , SYSDATE   AS CHKDATE
             , p_sabun AS CHKID
             , '복직' AS MEMO
          FROM TBEN542 A, TBEN540 B
         WHERE A.ENTER_CD       = p_enter_cd
           AND A.PAY_STS <> 'F'
           AND F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 'AA'
           AND A.USE_M_YM IS NOT NULL
           AND A.USE_MS_YM = p_pay_ym
           AND A.ENTER_CD       = B.ENTER_CD
           AND A.INS_COMP_CD    = B.INS_COMP_CD
           --AND A.JOIN_YMD BETWEEN B.USE_SDATE AND B.USE_EDATE;
           -- 2024.08.16 [한진정보통신] 단체상해보험 급여 공제금액 확인 요청 : 단체상해는 매년 갱신되고, 갱신 시 주관사가 결정되고, 단가가 결정되므로 가입년도 기준 금액말고 해당 년도의 금액기준이 들어가도록.
		   AND p_pay_ym||'01' BETWEEN B.USE_SDATE AND B.USE_EDATE;
      EXCEPTION
        WHEN OTHERS THEN
        p_sqlcode := TO_CHAR(sqlcode);
        p_sqlerrm := 'TBEN543 복직 INSERT 에러 -> ' || sqlerrm;
        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
        RETURN;
      END;
      
    END IF;
    
    
   /* 재직중 대상자 생성 */
-- 20240912 개발 로직 운영 반영 주석 아래 로직으로 진행
--	BEGIN
--		INSERT INTO TBEN543 (ENTER_CD, SABUN, INS_COMP_CD, JOIN_YMD, PAY_YM, COM_AMT, OWN_AMT, CHKDATE, CHKID)
--			SELECT A.ENTER_CD
--		   , A.SABUN
--		   , A.INS_COMP_CD
--		   , A.JOIN_YMD
--		   , p_pay_ym AS PAY_YM
--		   , CASE WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.COM_AMT_S * 2 --급여마감 후 가입 첫달
--		   	    WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.COM_AMT_S --급여마감 후 가입 다음달
--		   	    WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.COM_AMT_S --첫달, 다음달
--		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.COM_AMT_D * 2 --급여마감 후 가입 첫달
--		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.COM_AMT_D --급여마감 후 가입 다음달
--		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.COM_AMT_D --첫달, 다음달
--		      ELSE B.COM_AMT_S END AS COM_AMT
--		    , CASE WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.OWN_AMT_S * 2 --급여마감 후 가입 첫달
--		   	    WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.OWN_AMT_S --급여마감 후 가입 다음달
--		   	    WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.OWN_AMT_S --첫달, 다음달
--		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.OWN_AMT_D * 2 --급여마감 후 가입 첫달
--		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.OWN_AMT_D --급여마감 후 가입 다음달
--		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.OWN_AMT_D --첫달, 다음달
--		      ELSE B.OWN_AMT_S END AS OWN_AMT
--		   , SYSDATE   AS CHKDATE
--		   , p_sabun AS CHKID
--		FROM TBEN542 A, TBEN540 B
--		WHERE A.ENTER_CD       = p_enter_cd
--	      AND (F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 'AA'
--		      OR ( F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) =  'CA'
--		  AND F_BEN_GET_IS_CA_YN(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 'Y'))
--		 --AND F_BEN_GET_ORD_DETAIL_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 1 ))
--		 -- AND F_COM_GET_WORK_YM(A.ENTER_CD, A.SABUN, TO_CHAR(SYSDATE, 'YYYYMMDD')) >= 1 -- 근속1개월 이상   
--		 AND A.PAY_STS        = 'P'
--		 AND A.USE_S_YM       <= p_pay_ym
--		 AND (A.USE_MS_YM <> p_pay_ym OR A.USE_MS_YM IS NULL)
--		 AND A.USE_E_YM IS NULL
--		 AND A.ENTER_CD       = B.ENTER_CD
--		 AND A.INS_COMP_CD    = B.INS_COMP_CD
--		 --AND A.JOIN_YMD BETWEEN B.USE_SDATE AND B.USE_EDATE;
--		 -- 2024.08.16 [한진정보통신] 단체상해보험 급여 공제금액 확인 요청 : 단체상해는 매년 갱신되고, 갱신 시 주관사가 결정되고, 단가가 결정되므로 가입년도 기준 금액말고 해당 년도의 금액기준이 들어가도록.
--		 AND p_pay_ym||'01' BETWEEN B.USE_SDATE AND B.USE_EDATE;
--	EXCEPTION
--  WHEN OTHERS THEN
--     p_sqlcode := TO_CHAR(sqlcode);
--     p_sqlerrm := 'TBEN543 재직 INSERT 에러 -> ' || sqlerrm;
--     P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
--     RETURN;
--  END;
	BEGIN
		INSERT INTO TBEN543 (ENTER_CD, SABUN, INS_COMP_CD, JOIN_YMD, PAY_YM, COM_AMT, OWN_AMT, CHKDATE, CHKID)
			SELECT T.ENTER_CD,T.SABUN,T.INS_COMP_CD,T.JOIN_YMD,T.PAY_YM
            ,CASE WHEN F_BEN_GET_IS_CHILD_YN(T.ENTER_CD,T.SABUN,TO_CHAR (SYSDATE, 'YYYYMMDD')) = 'Y' THEN NVL(T.COM_AMT,0) + NVL(T.OWN_AMT,0)
            ELSE T.COM_AMT END AS COM_AMT
            ,CASE WHEN F_BEN_GET_IS_CHILD_YN(T.ENTER_CD,T.SABUN,TO_CHAR (SYSDATE, 'YYYYMMDD')) = 'Y' THEN T.OWN_AMT *0
            ELSE T.OWN_AMT END AS OWN_AMT
            ,T.CHKDATE,T.CHKID FROM (
            SELECT A.ENTER_CD
		   , A.SABUN
		   , A.INS_COMP_CD
		   , A.JOIN_YMD
		   , p_pay_ym AS PAY_YM
		   , CASE
                WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.COM_AMT_S * 2 --급여마감 후 가입 첫달
		   	    WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.COM_AMT_S --급여마감 후 가입 다음달
		   	    WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.COM_AMT_S --첫달, 다음달
		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.COM_AMT_D * 2 --급여마감 후 가입 첫달
		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.COM_AMT_D --급여마감 후 가입 다음달
		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.COM_AMT_D --첫달, 다음달
		      ELSE B.COM_AMT_S END AS COM_AMT
		    , CASE
                WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.OWN_AMT_S * 2 --급여마감 후 가입 첫달
		   	    WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.OWN_AMT_S --급여마감 후 가입 다음달
		   	    WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.OWN_AMT_S --첫달, 다음달
		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.OWN_AMT_D * 2 --급여마감 후 가입 첫달
		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.OWN_AMT_D --급여마감 후 가입 다음달
		      	WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.OWN_AMT_D --첫달, 다음달
		      ELSE B.OWN_AMT_S END AS OWN_AMT
		   , SYSDATE   AS CHKDATE
		   , p_sabun AS CHKID
		FROM TBEN542 A, TBEN540 B
		WHERE A.ENTER_CD       = p_enter_cd
	      AND (
               F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 'AA'
		       OR ( F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) =  'CA' AND F_BEN_GET_IS_CA_YN(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD'), LV_BENEFIT_BIZ_CD) = 'Y' )
          )
		 --AND F_BEN_GET_ORD_DETAIL_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 1 ))
		 -- AND F_COM_GET_WORK_YM(A.ENTER_CD, A.SABUN, TO_CHAR(SYSDATE, 'YYYYMMDD')) >= 1 -- 근속1개월 이상   
		 AND A.PAY_STS        = 'P'
		 AND A.USE_S_YM       <= p_pay_ym
		 AND (A.USE_MS_YM <> p_pay_ym OR A.USE_MS_YM IS NULL)
		 AND A.USE_E_YM IS NULL
		 AND A.ENTER_CD       = B.ENTER_CD
		 AND A.INS_COMP_CD    = B.INS_COMP_CD
		 --AND A.JOIN_YMD BETWEEN B.USE_SDATE AND B.USE_EDATE;
		 -- 2024.08.16 [한진정보통신] 단체상해보험 급여 공제금액 확인 요청 : 단체상해는 매년 갱신되고, 갱신 시 주관사가 결정되고, 단가가 결정되므로 가입년도 기준 금액말고 해당 년도의 금액기준이 들어가도록.
		 AND p_pay_ym||'01' BETWEEN B.USE_SDATE AND B.USE_EDATE
         ) T
         ;
	EXCEPTION
  WHEN OTHERS THEN
     p_sqlcode := TO_CHAR(sqlcode);
     p_sqlerrm := 'TBEN543 재직 INSERT 에러 -> ' || sqlerrm;
     P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
     RETURN;
  END;
  
  
  
  /* 당월퇴직대상자 생성 */
  BEGIN
        INSERT INTO TBEN543 (ENTER_CD, SABUN, INS_COMP_CD, JOIN_YMD, PAY_YM, COM_AMT, OWN_AMT, CHKDATE, CHKID)
              SELECT A.ENTER_CD
           , A.SABUN
           , A.INS_COMP_CD
           , A.JOIN_YMD
           , p_pay_ym AS PAY_YM
           , CASE WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.COM_AMT_S * 2 --급여마감 후 가입 첫달
                WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.COM_AMT_S --급여마감 후 가입 다음달
                WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.COM_AMT_S --첫달, 다음달
                WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.COM_AMT_D * 2 --급여마감 후 가입 첫달
                WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.COM_AMT_D --급여마감 후 가입 다음달
                WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.COM_AMT_D --첫달, 다음달
              ELSE B.COM_AMT_S END AS COM_AMT
            , CASE WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.OWN_AMT_S * 2 --급여마감 후 가입 첫달
                WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.OWN_AMT_S --급여마감 후 가입 다음달
                WHEN A.D_YN = 'N' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.OWN_AMT_S --첫달, 다음달
                WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM = p_pay_ym THEN B.OWN_AMT_D * 2 --급여마감 후 가입 첫달
                WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) <> A.USE_S_YM AND A.USE_S_YM < p_pay_ym THEN B.OWN_AMT_D --급여마감 후 가입 다음달
                WHEN A.D_YN = 'Y' AND SUBSTR(A.JOIN_YMD, 0, 6) = A.USE_S_YM AND A.USE_S_YM <= p_pay_ym THEN B.OWN_AMT_D --첫달, 다음달
              ELSE B.OWN_AMT_S END AS OWN_AMT
           , SYSDATE   AS CHKDATE
           , p_sabun AS CHKID
        FROM TBEN542 A, TBEN540 B , THRM100 C 
        WHERE A.ENTER_CD = B.ENTER_CD
          AND A.INS_COMP_CD    = B.INS_COMP_CD
           --AND A.JOIN_YMD BETWEEN B.USE_SDATE AND B.USE_EDATE
          -- 2024.08.16 [한진정보통신] 단체상해보험 급여 공제금액 확인 요청 : 단체상해는 매년 갱신되고, 갱신 시 주관사가 결정되고, 단가가 결정되므로 가입년도 기준 금액말고 해당 년도의 금액기준이 들어가도록.
		   AND p_pay_ym||'01' BETWEEN B.USE_SDATE AND B.USE_EDATE
          AND A.SABUN = C.SABUN
          AND A.ENTER_CD       = p_enter_cd
         -- AND F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) IN ('RA') -- 당월퇴직자는 현재 재직상태로 판단 x
          AND F_COM_GET_WORK_YM(A.ENTER_CD, A.SABUN, TO_CHAR(SYSDATE, 'YYYYMMDD')) >= 1 -- 근속1개월 이상   
          AND A.PAY_STS        = 'F'
          AND A.USE_S_YM       <= p_pay_ym
          AND A.USE_E_YM        = p_pay_ym
          AND (A.USE_MS_YM <> p_pay_ym OR A.USE_MS_YM IS NULL)
          AND SUBSTR(C.RET_YMD, 0 , 6)  = p_pay_ym
          AND EXISTS ( SELECT 1
                         FROM THRM100 X
                        WHERE X.ENTER_CD = A.ENTER_CD 
                          AND X.SABUN = A.SABUN
                          AND SUBSTR(X.RET_YMD , 0, 6)  = p_pay_ym)  ;
    EXCEPTION
  WHEN OTHERS THEN
     p_sqlcode := TO_CHAR(sqlcode);
     p_sqlerrm := 'TBEN543 당월퇴직 INSERT 에러 -> ' || sqlerrm;
     P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
     RETURN;
  END;

-- 휴직자 중단 처리, 복리후생 휴직자 비대상 (CA이지만, 복리후생/상해보험 회사지원금 대상은 제외)
	BEGIN
		UPDATE TBEN542 A
	       SET A.USE_M_YM      = p_pay_ym
	         , A.USE_MS_YM     = ''
	 		 , A.PAY_STS       = 'S'
	     , A.CHKDATE = SYSDATE
	     , A.CHKID = p_sabun
	 WHERE A.ENTER_CD      = p_enter_cd
	   AND F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 'CA'
	   AND F_BEN_GET_IS_CA_YN(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD'), LV_BENEFIT_BIZ_CD) = 'N'
	   --AND F_BEN_GET_ORD_DETAIL_CD(A.ENTER_CD, A.SABUN, TO_CHAR (SYSDATE, 'YYYYMMDD')) = 0
	   AND A.PAY_STS <> 'F'
	   AND ((A.USE_M_YM IS NULL) OR (A.USE_M_YM IS NOT NULL AND A.USE_MS_YM IS NOT NULL AND A.PAY_STS = 'P'));
	EXCEPTION
  WHEN OTHERS THEN
     p_sqlcode := TO_CHAR(sqlcode);
     p_sqlerrm := 'TBEN542 휴직 UPDATE 에러 -> ' || sqlerrm;
     P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
     RETURN;
  END;
  
  
       
EXCEPTION
 WHEN OTHERS THEN
    p_sqlcode := TO_CHAR(sqlcode);
    p_sqlerrm := 'P_BEN_PREMIUM_PAY_CREATE 에러 -> ' || sqlerrm;
    P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
    RETURN;
END P_BEN_PREMIUM_PAY_CREATE;